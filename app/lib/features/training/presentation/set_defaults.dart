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
    this.kind = SetKind.working,
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

  /// The kind the new row starts with: that of the previous-session set it
  /// was matched with (a warm-up row follows a previous warm-up).
  final SetKind kind;

  /// This draft with another [kind].
  SetDraft withKind(SetKind kind) => SetDraft(
    load: load,
    reps: reps,
    duration: duration,
    metres: metres,
    heartRate: heartRate,
    kind: kind,
  );
}

bool _isWarmUp(SessionSet s) => s.kind == SetKind.warmUp;

/// The previous-session set the next-set row matches (TRN-018, TRN-019), and
/// the kind the row takes from it. Warm-ups are matched with previous
/// warm-ups and working or failure sets with previous working or failure
/// sets, the position being counted per group: the next row is a warm-up
/// while the entry has no working set yet and fewer warm-ups than last time;
/// otherwise it is the next working set. A group the previous session did not
/// have matches nothing (null set, working kind), so skipping warm-ups today
/// does not shift the working sets onto last time's warm-ups.
({SessionSet? set, SetKind kind}) matchPrevious({
  required ExerciseType type,
  required List<SessionSet> entrySets,
  required EntryPrefill? prefill,
}) {
  final own = [
    for (final s in entrySets)
      if (s.data.type == type) s,
  ];
  final previous = [
    for (final s in prefill?.previous ?? const <SessionSet>[])
      if (s.data.type == type) s,
  ];
  final ownWarm = own.where(_isWarmUp).length;
  final ownWork = own.length - ownWarm;
  final prevWarm = previous.where(_isWarmUp).toList();
  final prevWork = previous.where((s) => !_isWarmUp(s)).toList();
  if (ownWork == 0 && ownWarm < prevWarm.length) {
    return (set: prevWarm[ownWarm], kind: SetKind.warmUp);
  }
  if (prevWork.isEmpty) return (set: null, kind: SetKind.working);
  final match =
      prevWork[ownWork < prevWork.length ? ownWork : prevWork.length - 1];
  // Only warm-up versus working carries over: a failure set is an outcome,
  // not a plan, so a matched failure set pre-fills a working row.
  return (set: match, kind: SetKind.working);
}

/// The values the next-set row starts with (TRN-016(1), TRN-018): the
/// matching set of the previous session for a warm-up row; for a working row
/// the entry's last working set when it has one, else the matching working
/// set of the previous session, else the plan's targets. Warm-ups carry no
/// weight over to the first working set. See [matchPrevious] for the
/// matching and the row's kind.
SetDraft nextSetDraft({
  required ExerciseType type,
  required List<SessionSet> entrySets,
  required EntryPrefill? prefill,
}) {
  final match = matchPrevious(
    type: type,
    entrySets: entrySets,
    prefill: prefill,
  );
  if (match.kind == SetKind.warmUp && match.set != null) {
    return SetDraft.fromData(match.set!.data).withKind(SetKind.warmUp);
  }
  final ownWork = [
    for (final s in entrySets)
      if (s.data.type == type && !_isWarmUp(s)) s,
  ];
  if (ownWork.isNotEmpty) {
    return SetDraft.fromData(ownWork.last.data).withKind(match.kind);
  }
  if (match.set != null) {
    return SetDraft.fromData(match.set!.data).withKind(match.kind);
  }
  final target = prefill?.target;
  if (target != null) return SetDraft.fromTarget(type, target);
  return const SetDraft();
}

/// `Last: 80 kg × 5` (the previous-performance hint for the next set), with
/// ` (warm-up)` appended when that set was a warm-up; null without a match.
/// It names the set [nextSetDraft] matches.
String? previousHint(
  ExerciseType type,
  List<SessionSet> entrySets,
  EntryPrefill? prefill,
  UnitSystem units,
) {
  final s = matchPrevious(
    type: type,
    entrySets: entrySets,
    prefill: prefill,
  ).set;
  if (s == null) return null;
  final warm = s.kind == SetKind.warmUp ? ' (warm-up)' : '';
  return 'Last: ${formatSetData(s.data, units)}$warm';
}

/// `Plan: 3 sets · 8–10 reps · 60 kg`, or null without a plan row.
String? planHint(EntryPrefill? prefill) {
  final t = prefill?.target;
  return t == null ? null : 'Plan: ${formatPlanTargets(t)}';
}
