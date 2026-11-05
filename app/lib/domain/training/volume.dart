import 'package:meta/meta.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show diaryDayKey;
import 'package:repforge/domain/training/training.dart';

/// Training volume of a group of sets by measure (D04 TRN-027): the kg volume
/// of weighted sets, and the own measures of the other types. Never mixed
/// into one number.
@immutable
class VolumeTotals {
  const VolumeTotals({
    this.loadKg = 0,
    this.reps = 0,
    this.seconds = 0,
    this.metres = 0,
    this.sets = 0,
  });

  /// Sum of load x repetitions of weighted sets, in kg.
  final double loadKg;

  /// Repetitions of bodyweight and assisted sets (weighted repetitions are in
  /// [loadKg]).
  final int reps;

  /// Seconds of timed and cardio sets.
  final int seconds;

  /// Metres of distance and cardio sets.
  final double metres;

  /// Number of sets counted.
  final int sets;

  static const zero = VolumeTotals();

  VolumeTotals operator +(VolumeTotals o) => VolumeTotals(
    loadKg: loadKg + o.loadKg,
    reps: reps + o.reps,
    seconds: seconds + o.seconds,
    metres: metres + o.metres,
    sets: sets + o.sets,
  );

  @override
  bool operator ==(Object other) =>
      other is VolumeTotals &&
      other.loadKg == loadKg &&
      other.reps == reps &&
      other.seconds == seconds &&
      other.metres == metres &&
      other.sets == sets;

  @override
  int get hashCode => Object.hash(loadKg, reps, seconds, metres, sets);

  @override
  String toString() =>
      'VolumeTotals(kg: $loadKg, reps: $reps, s: $seconds, m: $metres, '
      'sets: $sets)';
}

/// Volume attributed to a muscle group: the exercises that train it as
/// primary and, kept apart, those that train it as secondary (TRN-027(3)).
/// [secondary] is never added to [primary].
class MuscleVolume {
  const MuscleVolume({
    this.primary = VolumeTotals.zero,
    this.secondary = VolumeTotals.zero,
  });

  final VolumeTotals primary;
  final VolumeTotals secondary;
}

/// A week of volume: the week's first date (date-only, local) and its totals.
class WeekVolume {
  const WeekVolume({
    required this.weekStart,
    required this.total,
    required this.byExercise,
    required this.byMuscle,
  });

  final DateTime weekStart;
  final VolumeTotals total;
  final Map<String, VolumeTotals> byExercise;
  final Map<MuscleGroup, MuscleVolume> byMuscle;
}

/// Pure volume rules (D04 TRN-027, TRN-019).
///
/// Counted: completed working and failure sets. Warm-ups and sets not
/// completed are excluded. Weighted sets give load x repetitions in kg;
/// bodyweight and assisted sets give repetitions; timed sets seconds;
/// distance sets metres; cardio sets seconds and, when entered, metres. An
/// added load on a bodyweight or timed set is not volume (TRN-027(2)).
abstract final class VolumeRules {
  /// The volume of one set; [VolumeTotals.zero] when it is not counted.
  static VolumeTotals ofSet(SessionSet s) {
    if (!s.completed || s.kind == SetKind.warmUp) return VolumeTotals.zero;
    return switch (s.data) {
      WeightedSet(:final load, :final reps) => VolumeTotals(
        loadKg: load.value * reps,
        sets: 1,
      ),
      BodyweightSet(:final reps) => VolumeTotals(reps: reps, sets: 1),
      AssistedSet(:final reps) => VolumeTotals(reps: reps, sets: 1),
      TimedSet(:final duration) => VolumeTotals(
        seconds: duration.inSeconds,
        sets: 1,
      ),
      DistanceSet(:final metres) => VolumeTotals(metres: metres, sets: 1),
      CardioSet(:final duration, :final metres) => VolumeTotals(
        seconds: duration.inSeconds,
        metres: metres ?? 0,
        sets: 1,
      ),
    };
  }

  static VolumeTotals total(Iterable<SessionSet> sets) =>
      sets.fold(VolumeTotals.zero, (a, s) => a + ofSet(s));

  /// Volume per exercise id (an exercise with no counted set is absent).
  static Map<String, VolumeTotals> byExercise(Iterable<SessionSet> sets) {
    final out = <String, VolumeTotals>{};
    for (final s in sets) {
      final v = ofSet(s);
      if (v.sets == 0) continue;
      out[s.exerciseId] = (out[s.exerciseId] ?? VolumeTotals.zero) + v;
    }
    return out;
  }

  /// Volume of one session.
  static VolumeTotals ofSession(WorkoutSession session) => total(session.sets);

  /// Volume per muscle group: each counted set adds to the primary muscle of
  /// its exercise in full and, separately, to each secondary muscle. Sets of
  /// an exercise missing from [exercises] are not attributed.
  static Map<MuscleGroup, MuscleVolume> byMuscle(
    Iterable<SessionSet> sets,
    Map<String, Exercise> exercises,
  ) {
    final primary = <MuscleGroup, VolumeTotals>{};
    final secondary = <MuscleGroup, VolumeTotals>{};
    for (final s in sets) {
      final v = ofSet(s);
      final e = exercises[s.exerciseId];
      if (v.sets == 0 || e == null) continue;
      primary[e.primaryMuscle] =
          (primary[e.primaryMuscle] ?? VolumeTotals.zero) + v;
      for (final m in e.secondaryMuscles.toSet()) {
        secondary[m] = (secondary[m] ?? VolumeTotals.zero) + v;
      }
    }
    return {
      for (final m in {...primary.keys, ...secondary.keys})
        m: MuscleVolume(
          primary: primary[m] ?? VolumeTotals.zero,
          secondary: secondary[m] ?? VolumeTotals.zero,
        ),
    };
  }

  /// The first date (local, date-only) of the week [instant] falls in. The
  /// instant is first attributed to a diary day with [dayStartHour], the same
  /// rule as the nutrition diary (`diaryDayKey`), then the week runs from
  /// [weekStartDay] (1 Monday to 7 Sunday).
  static DateTime weekStart(
    DateTime instant, {
    int weekStartDay = 1,
    int dayStartHour = 0,
  }) {
    final day = DateTime.parse(diaryDayKey(instant, dayStartHour));
    final back = (day.weekday - weekStartDay + 7) % 7;
    return DateTime(day.year, day.month, day.day - back);
  }

  /// Volume per week over [sessions] (deleted sessions must not be passed),
  /// attributing each session, by its start, to one week. Ordered by week.
  static List<WeekVolume> byWeek(
    Iterable<WorkoutSession> sessions,
    Map<String, Exercise> exercises, {
    int weekStartDay = 1,
    int dayStartHour = 0,
  }) {
    final groups = <DateTime, List<SessionSet>>{};
    for (final s in sessions) {
      final w = weekStart(
        s.startedAt,
        weekStartDay: weekStartDay,
        dayStartHour: dayStartHour,
      );
      groups.putIfAbsent(w, () => []).addAll(s.sets);
    }
    final weeks = groups.keys.toList()..sort();
    return [
      for (final w in weeks)
        WeekVolume(
          weekStart: w,
          total: total(groups[w]!),
          byExercise: byExercise(groups[w]!),
          byMuscle: byMuscle(groups[w]!, exercises),
        ),
    ];
  }
}
