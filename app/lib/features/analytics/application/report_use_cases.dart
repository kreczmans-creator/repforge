import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/goal_progress.dart';
import 'package:repforge/domain/analytics/period_comparison.dart';
import 'package:repforge/domain/analytics/recomposition.dart';
import 'package:repforge/domain/analytics/weekly_report.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/features/analytics/application/analytics_guard.dart';
import 'package:repforge/features/analytics/application/body_use_cases.dart';
import 'package:repforge/features/analytics/application/nutrition_use_cases.dart';
import 'package:repforge/features/analytics/application/training_use_cases.dart';

/// Use case: the weekly summary of nutrition, training and body (GOL-007),
/// built from the other loaders. The sessions-per-week goal joins the
/// training section when `period` is a week.
final class LoadWeeklyReport {
  const LoadWeeklyReport({
    required this.nutrition,
    required this.training,
    required this.weight,
    required this.goals,
  });

  final LoadNutritionWeek nutrition;
  final LoadWeekTraining training;
  final LoadWeightSummary weight;
  final GoalRepository goals;

  Future<Result<WeeklyReport>> call(AnalyticsPeriod period) async {
    final n = await nutrition(period);
    final t = await training.loadWeek(period);
    final w = await weight(period);
    if (n case Err(:final error)) return Err(error);
    if (t case Err(:final error)) return Err(error);
    if (w case Err(:final error)) return Err(error);
    return await guardAnalytics(
      'Could not build the weekly summary.',
      () async {
        final week = okValue(t);
        GoalProgress? sessionsGoal;
        if (period.kind == AnalyticsPeriodKind.week) {
          for (final g in await goals.active()) {
            if (g.kind == GoalKind.sessionsPerWeek) {
              sessionsGoal = GoalProgress.sessionsPerWeek(goal: g, week: week);
              break;
            }
          }
        }
        return WeeklyReport.build(
          period: period,
          nutrition: okValue(n),
          training: week,
          weight: okValue(w),
          sessionsGoal: sessionsGoal,
        );
      },
    );
  }
}

/// Use case: `later` against `earlier` (default: the period before it) for
/// energy, protein, volume and weight (GOL-009).
final class LoadPeriodComparison {
  const LoadPeriodComparison({
    required this.nutrition,
    required this.training,
    required this.measurements,
    this.clock = const SystemClock(),
  });

  final LoadNutritionWeek nutrition;
  final LoadWeekTraining training;
  final MeasurementRepository measurements;

  /// Gives the current diary day, to mark a period in progress.
  final Clock clock;

  Future<Result<PeriodComparison>> call({
    required AnalyticsPeriod later,
    AnalyticsPeriod? earlier,
  }) async {
    final before = earlier ?? later.previous;
    final en = await nutrition(before);
    final ln = await nutrition(later);
    final et = await training.loadWeek(before);
    final lt = await training.loadWeek(later);
    if (en case Err(:final error)) return Err(error);
    if (ln case Err(:final error)) return Err(error);
    if (et case Err(:final error)) return Err(error);
    if (lt case Err(:final error)) return Err(error);
    return await guardAnalytics('Could not compare the periods.', () async {
      final from = before.from.isBefore(later.from) ? before : later;
      final to = before.to.isAfter(later.to) ? before : later;
      final weights = await measurements.readingsBetween(
        from.calendarStartInstant,
        to.calendarEndInstantExclusive,
        site: MeasurementSite.weight,
      );
      return PeriodComparison.build(
        earlierNutrition: okValue(en),
        laterNutrition: okValue(ln),
        earlierTraining: okValue(et),
        laterTraining: okValue(lt),
        weightReadings: weights,
        asOf: diaryDay(clock.now(), later.dayStartHour),
      );
    });
  }
}

/// Use case: weight trend, waist readings and the top-set weight of one
/// exercise on one date range (GOL-010).
final class LoadRecompositionSeries {
  const LoadRecompositionSeries({
    required this.measurements,
    required this.sessions,
  });

  final MeasurementRepository measurements;
  final WorkoutSessionRepository sessions;

  Future<Result<RecompositionSeries>> call({
    required AnalyticsPeriod period,
    String? exerciseId,
  }) => guardAnalytics('Could not read the recomposition data.', () async {
    final history = exerciseId == null
        ? const <ExerciseSessionHistory>[]
        : await sessions.sessionsForExercise(exerciseId);
    return RecompositionSeries.build(
      period: period,
      weightReadings: await weightReadingsFor(measurements, period),
      waistReadings: await measurements.readingsBetween(
        period.calendarStartInstant,
        period.calendarEndInstantExclusive,
        site: MeasurementSite.waist,
      ),
      strengthSessions: history,
      exerciseId: exerciseId,
    );
  });
}
