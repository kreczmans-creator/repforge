import 'package:meta/meta.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/training/volume.dart';

/// Resolves an exercise id to its name, or null when it cannot be found.
/// Analytics reads names only through this function so WP 8 stage 3d can swap
/// the lookup (plan section 11, risk "exercise port changes").
typedef ExerciseNameLookup = Future<String?> Function(String exerciseId);

/// Training over a period (TRN-027, GOL-005, GOL-007).
///
/// A session belongs to the period when the diary day of its start (the
/// day-start setting, as for nutrition) lies in it. A session counts as
/// completed when it has an end time ([WorkoutSession.endedAt]); D04 gives no
/// other definition (plan section 5.1, open question).
///
/// Volume follows [VolumeRules] unchanged: completed working and failure
/// sets, warm-ups excluded, kg only for weighted sets. It counts the
/// completed sets of every session that started in the period, including one
/// still in progress, as `GetWeeklyVolume` does.
@immutable
final class WeekTraining {
  const WeekTraining._({
    required this.period,
    required this.sessionsCompleted,
    required this.sessionsInProgress,
    required this.volume,
    required this.byExercise,
    required this.activeDays,
    required this.dayRule,
  });

  /// Builds the period from [sessions]. Sessions that start outside it are
  /// ignored. The day-start hour comes from [settings].
  factory WeekTraining.build({
    required AnalyticsPeriod period,
    required Iterable<WorkoutSession> sessions,
    required AppSettings settings,
  }) {
    final inPeriod = [
      for (final s in sessions)
        if (period.containsDay(diaryDay(s.startedAt, settings.dayStartHour))) s,
    ];
    final completed = inPeriod.where((s) => s.endedAt != null).toList();
    final allSets = [for (final s in inPeriod) ...s.sets];
    final days = <CalendarDate>{
      for (final s in completed) diaryDay(s.startedAt, settings.dayStartHour),
    }.toList()..sort();
    return WeekTraining._(
      period: period,
      sessionsCompleted: completed.length,
      sessionsInProgress: inPeriod.length - completed.length,
      volume: VolumeRules.total(allSets),
      byExercise: Map.unmodifiable(VolumeRules.byExercise(allSets)),
      activeDays: List.unmodifiable(days),
      dayRule: AnalyticsPeriod.dayRuleFor(settings.dayStartHour),
    );
  }

  final AnalyticsPeriod period;

  /// Sessions with an end time that started in the period.
  final int sessionsCompleted;

  /// Sessions that started in the period and have no end time.
  final int sessionsInProgress;

  /// Volume by measure (kg, repetitions, seconds, metres, sets).
  final VolumeTotals volume;

  /// Volume per exercise id; an exercise with no counted set is absent.
  final Map<String, VolumeTotals> byExercise;

  /// The diary days with at least one completed session, oldest first.
  final List<CalendarDate> activeDays;

  /// Which day boundary attributes sessions to days.
  final String dayRule;

  /// Completed working and failure sets of every type (warm-ups excluded).
  int get workingSets => volume.sets;

  /// Total kg volume. Not enough data only when nothing was recorded (no
  /// counted set). A period whose sets carry no load (bodyweight, timed)
  /// has a real total of 0 kg; its reps, seconds and metres are in
  /// [volume] (TRN-027(2)).
  Metric<double> get totalVolumeKg {
    if (volume.sets == 0) {
      return NotEnoughData(
        have: 0,
        need: 1,
        reason: 'No working set was recorded in ${period.label}.',
      );
    }
    return MetricValue(
      volume.loadKg,
      MetricBasis(
        period: period,
        sampleCount: volume.sets,
        sources: const ['completed working sets'],
        dayRule: dayRule,
      ),
    );
  }
}

/// How a measure compares with the previous session of the exercise
/// (TRN-028(2)). The vocabulary is fixed and descriptive (GOL-011).
enum TrendStatement {
  increased('increased'),
  level('level'),
  decreased('decreased'),
  firstSession('first session');

  TrendStatement(this.label);

  /// The text shown.
  final String label;

  /// The statement for [current] against [previous] (null: no earlier
  /// value).
  static TrendStatement compare(double current, double? previous) {
    if (previous == null) return firstSession;
    final diff = current - previous;
    if (diff.abs() < 1e-9) return level;
    return diff > 0 ? increased : decreased;
  }
}

/// One session of one exercise on the progress chart (TRN-028(1)): the
/// heaviest weighted working set and the session volume. No estimated 1RM
/// (plan decision 6c).
@immutable
final class ExerciseProgressPoint {
  const ExerciseProgressPoint({
    required this.sessionId,
    required this.startedAt,
    required this.date,
    required this.totals,
    this.topSetWeightKg,
    this.volumeKg,
    this.topSetStatement,
    this.volumeStatement,
  });

  final String sessionId;
  final DateTime startedAt;

  /// The diary day of the session.
  final CalendarDate date;

  /// Heaviest load of a completed non-warm-up weighted set; null when the
  /// session had no such set.
  final double? topSetWeightKg;

  /// Sum of load times repetitions of the weighted working sets; null when
  /// the session had none.
  final double? volumeKg;

  /// All measures of the session by type.
  final VolumeTotals totals;

  /// Against the previous session that had a top set; null without one.
  final TrendStatement? topSetStatement;

  /// Against the previous session that had weighted volume; null without
  /// any.
  final TrendStatement? volumeStatement;
}

/// Progress of one exercise over its sessions (TRN-028).
@immutable
final class ExerciseProgress {
  const ExerciseProgress._(this.points);

  /// Builds the progress from the sessions of one exercise (any order, as
  /// `WorkoutSessionRepository.sessionsForExercise` returns them). A session
  /// with no counted set (for example only warm-ups) gives no point.
  factory ExerciseProgress.build(
    Iterable<ExerciseSessionHistory> sessions, {
    int dayStartHour = 0,
  }) {
    final ordered = sessions.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final points = <ExerciseProgressPoint>[];
    double? prevTop;
    double? prevVolume;
    for (final s in ordered) {
      final totals = VolumeRules.total(s.sets);
      if (totals.sets == 0) continue;
      double? top;
      for (final set in s.sets) {
        if (VolumeRules.ofSet(set).sets == 0) continue;
        final data = set.data;
        if (data is WeightedSet && (top == null || data.load.value > top)) {
          top = data.load.value;
        }
      }
      final volume = top == null ? null : totals.loadKg;
      points.add(
        ExerciseProgressPoint(
          sessionId: s.sessionId,
          startedAt: s.startedAt,
          date: diaryDay(s.startedAt, dayStartHour),
          topSetWeightKg: top,
          volumeKg: volume,
          totals: totals,
          topSetStatement: top == null
              ? null
              : TrendStatement.compare(top, prevTop),
          volumeStatement: volume == null
              ? null
              : TrendStatement.compare(volume, prevVolume),
        ),
      );
      if (top != null) prevTop = top;
      if (volume != null) prevVolume = volume;
    }
    return ExerciseProgress._(List.unmodifiable(points));
  }

  /// One point per session with counted sets, oldest first.
  final List<ExerciseProgressPoint> points;

  bool get isEmpty => points.isEmpty;

  /// The newest point; null without one.
  ExerciseProgressPoint? get latest => points.isEmpty ? null : points.last;
}

/// A personal record set in a period (TRN-026), derived from the recorded
/// history with `PersonalRecordRules`; nothing is stored. Assisted and cardio
/// sets have no record rule (plan decision 9a).
@immutable
final class RecordEvent {
  const RecordEvent({
    required this.exerciseId,
    required this.key,
    required this.value,
    required this.setId,
    required this.sessionId,
    required this.startedAt,
    required this.date,
  });

  final String exerciseId;
  final PrKey key;

  /// kg, seconds, metres or repetitions according to the measure.
  final double value;
  final String setId;
  final String sessionId;
  final DateTime startedAt;

  /// The diary day of the session.
  final CalendarDate date;
}

/// The records that were set inside [period] (all of them when it is null),
/// oldest first. Each record is judged against every earlier set of its
/// exercise, so [history] must hold the whole history of each exercise it
/// names, not only the period.
List<RecordEvent> recordEventsIn(
  Iterable<PerformedSet> history, {
  required int dayStartHour,
  AnalyticsPeriod? period,
}) {
  final byExercise = <String, List<PerformedSet>>{};
  for (final p in history) {
    (byExercise[p.set.exerciseId] ??= []).add(p);
  }
  final events = <RecordEvent>[];
  for (final entry in byExercise.entries) {
    final ids = PersonalRecordRules.recordSetIds(entry.value);
    for (final p in PersonalRecordRules.chronological(entry.value)) {
      if (!ids.contains(p.set.id)) continue;
      final slot = PersonalRecordRules.slotOf(p.set)!;
      final date = diaryDay(p.startedAt, dayStartHour);
      if (period != null && !period.containsDay(date)) continue;
      events.add(
        RecordEvent(
          exerciseId: entry.key,
          key: slot.key,
          value: slot.value,
          setId: p.set.id,
          sessionId: p.sessionId,
          startedAt: p.startedAt,
          date: date,
        ),
      );
    }
  }
  return events..sort((a, b) {
    final c = a.startedAt.compareTo(b.startedAt);
    return c != 0 ? c : a.setId.compareTo(b.setId);
  });
}
