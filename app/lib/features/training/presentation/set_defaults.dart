import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/session_view.dart';
import 'package:repforge/features/training/presentation/plan_format.dart';
import 'package:repforge/features/training/presentation/set_format.dart';

/// Text values for the fields of a set that is not logged yet. Empty means
/// "nothing to pre-fill". Loads are in kg (OQ-02 is open); durations are
/// `mm:ss`.
class SetDraft {
  const SetDraft({
    this.load = '',
    this.reps = '',
    this.duration = '',
    this.metres = '',
    this.heartRate = '',
  });

  /// The fields of a recorded set.
  factory SetDraft.fromData(SetData data) {
    String kg(LoadKg? l) =>
        l == null ? '' : formatNumber(l.value, maxDecimals: 2);
    return switch (data) {
      WeightedSet(:final load, :final reps) => SetDraft(
        load: kg(load),
        reps: '$reps',
      ),
      BodyweightSet(:final reps, :final addedLoad) => SetDraft(
        reps: '$reps',
        load: addedLoad == null || addedLoad.value == 0 ? '' : kg(addedLoad),
      ),
      AssistedSet(:final reps, :final assistance) => SetDraft(
        reps: '$reps',
        load: kg(assistance),
      ),
      TimedSet(:final duration, :final addedLoad) => SetDraft(
        duration: formatClock(duration),
        load: addedLoad == null || addedLoad.value == 0 ? '' : kg(addedLoad),
      ),
      DistanceSet(:final metres, :final duration) => SetDraft(
        metres: formatNumber(metres),
        duration: duration == null ? '' : formatClock(duration),
      ),
      CardioSet(:final duration, :final metres, :final averageHeartRate) =>
        SetDraft(
          duration: formatClock(duration),
          metres: metres == null ? '' : formatNumber(metres),
          heartRate: averageHeartRate == null ? '' : '$averageHeartRate',
        ),
    };
  }

  /// The plan row's targets (reps from the low end of the range).
  factory SetDraft.fromTarget(ExerciseType type, PlanExercise t) {
    final load = t.targetLoad == null
        ? ''
        : formatNumber(t.targetLoad!.value, maxDecimals: 2);
    final reps = t.repsMin == null ? '' : '${t.repsMin}';
    final duration = t.targetDuration == null
        ? ''
        : formatClock(t.targetDuration!);
    final metres = t.targetMetres == null ? '' : formatNumber(t.targetMetres!);
    return switch (type) {
      ExerciseType.weighted => SetDraft(load: load, reps: reps),
      ExerciseType.bodyweight => SetDraft(reps: reps, load: load),
      ExerciseType.assisted => SetDraft(reps: reps, load: load),
      ExerciseType.timed => SetDraft(duration: duration, load: load),
      ExerciseType.distance => SetDraft(metres: metres, duration: duration),
      ExerciseType.cardio => SetDraft(duration: duration, metres: metres),
    };
  }

  final String load;
  final String reps;
  final String duration;
  final String metres;
  final String heartRate;
}

/// The values the next-set row starts with (TRN-016(1), TRN-018): the
/// entry's last set when it has one, else the set at the same position of the
/// previous session, else the plan's targets. Warm-ups carry no weight over
/// to the first working set, so they are skipped when looking at the last set
/// of the entry.
SetDraft nextSetDraft({
  required ExerciseType type,
  required List<SessionSet> entrySets,
  required EntryPrefill? prefill,
}) {
  final own = [
    for (final s in entrySets)
      if (s.data.type == type && s.kind != SetKind.warmUp) s,
  ];
  if (own.isNotEmpty) return SetDraft.fromData(own.last.data);
  final previous = previousSetFor(type, own.length, prefill);
  if (previous != null) return SetDraft.fromData(previous.data);
  final target = prefill?.target;
  if (target != null) return SetDraft.fromTarget(type, target);
  return const SetDraft();
}

/// The set of the previous session that matches position [index] (the last
/// one when the previous session had fewer sets); null when there is none.
SessionSet? previousSetFor(
  ExerciseType type,
  int index,
  EntryPrefill? prefill,
) {
  final previous = [
    for (final s in prefill?.previous ?? const <SessionSet>[])
      if (s.data.type == type) s,
  ];
  if (previous.isEmpty) return null;
  return previous[index < previous.length ? index : previous.length - 1];
}

/// `Last: 80 kg × 5` (the previous-performance hint), or null.
String? previousHint(
  ExerciseType type,
  int index,
  EntryPrefill? prefill,
  UnitSystem units,
) {
  final s = previousSetFor(type, index, prefill);
  return s == null ? null : 'Last: ${formatSetData(s.data, units)}';
}

/// `Plan: 3 sets · 8–10 reps · 60 kg`, or null without a plan row.
String? planHint(EntryPrefill? prefill) {
  final t = prefill?.target;
  return t == null ? null : 'Plan: ${formatPlanTargets(t)}';
}
