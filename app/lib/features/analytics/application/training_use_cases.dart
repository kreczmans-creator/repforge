import 'package:meta/meta.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/features/analytics/application/analytics_guard.dart';

/// Shown for an exercise whose name cannot be resolved (for example one that
/// was deleted); history keeps the sets.
const String unknownExerciseName = 'Unnamed exercise';

/// A training week with the names and records a screen needs.
@immutable
final class WeekTrainingView {
  const WeekTrainingView({
    required this.week,
    required this.exerciseNames,
    required this.recordEvents,
  });

  final WeekTraining week;

  /// Name per exercise id for every exercise in [week] or [recordEvents].
  final Map<String, String> exerciseNames;

  /// Records set during the period (TRN-026).
  final List<RecordEvent> recordEvents;
}

/// Use case: training of a period (TRN-027, GOL-005, GOL-007). Loads only the
/// sessions that start in the period (with a one-day margin that the domain
/// then filters by the day-start rule) and, for record events, the history
/// of the exercises trained in it.
final class LoadWeekTraining {
  const LoadWeekTraining({
    required this.sessions,
    required this.settings,
    required this.exerciseName,
  });

  final WorkoutSessionRepository sessions;
  final SettingsRepository settings;
  final ExerciseNameLookup exerciseName;

  /// The aggregate only: no names, no records.
  Future<Result<WeekTraining>> loadWeek(AnalyticsPeriod period) =>
      guardAnalytics('Could not read the training summary.', () async {
        final s = await _settingsFor(period);
        return WeekTraining.build(
          period: period,
          sessions: await _sessionsOf(period),
          settings: s,
        );
      });

  Future<Result<WeekTrainingView>> call(AnalyticsPeriod period) =>
      guardAnalytics('Could not read the training summary.', () async {
        final s = await _settingsFor(period);
        final list = await _sessionsOf(period);
        final week = WeekTraining.build(
          period: period,
          sessions: list,
          settings: s,
        );
        final inPeriod = [
          for (final x in list)
            if (period.containsInstant(x.startedAt)) x,
        ];
        final exerciseIds = {
          for (final x in inPeriod) ...x.sets.map((e) => e.exerciseId),
        };
        final history = <PerformedSet>[];
        for (final id in exerciseIds) {
          history.addAll(await sessions.performedSets(id));
        }
        final events = recordEventsIn(
          history,
          dayStartHour: s.dayStartHour,
          period: period,
        );
        final names = <String, String>{};
        for (final id in {...week.byExercise.keys, ...exerciseIds}) {
          names[id] = await exerciseName(id) ?? unknownExerciseName;
        }
        return WeekTrainingView(
          week: week,
          exerciseNames: Map.unmodifiable(names),
          recordEvents: events,
        );
      });

  /// The settings with the period's day-start hour, so the period and the
  /// session attribution use one value (the period was built from the same
  /// setting).
  Future<AppSettings> _settingsFor(AnalyticsPeriod period) async =>
      (await settings.read()).copyWith(dayStartHour: period.dayStartHour);

  Future<List<WorkoutSession>> _sessionsOf(AnalyticsPeriod period) =>
      sessions.sessionsBetween(
        DateTime(period.from.year, period.from.month, period.from.day - 1),
        DateTime(period.to.year, period.to.month, period.to.day + 2),
      );
}

/// One exercise's progress with its name and all-time records (TRN-026,
/// TRN-028).
@immutable
final class ExerciseProgressView {
  const ExerciseProgressView({
    required this.exerciseId,
    required this.exerciseName,
    required this.progress,
    required this.recordEvents,
  });

  final String exerciseId;
  final String exerciseName;
  final ExerciseProgress progress;

  /// Every record set for this exercise, oldest first.
  final List<RecordEvent> recordEvents;
}

/// Use case: progressive overload of one exercise (TRN-028). Reads that
/// exercise's history only; an archived or deleted exercise keeps its
/// history.
final class LoadExerciseProgress {
  const LoadExerciseProgress({
    required this.sessions,
    required this.settings,
    required this.exerciseName,
  });

  final WorkoutSessionRepository sessions;
  final SettingsRepository settings;
  final ExerciseNameLookup exerciseName;

  Future<Result<ExerciseProgressView>> call(String exerciseId) =>
      guardAnalytics('Could not read the exercise progress.', () async {
        final s = await settings.read();
        final history = await sessions.sessionsForExercise(exerciseId);
        final performed = await sessions.performedSets(exerciseId);
        return ExerciseProgressView(
          exerciseId: exerciseId,
          exerciseName: await exerciseName(exerciseId) ?? unknownExerciseName,
          progress: ExerciseProgress.build(
            history,
            dayStartHour: s.dayStartHour,
          ),
          recordEvents: recordEventsIn(performed, dayStartHour: s.dayStartHour),
        );
      });
}
