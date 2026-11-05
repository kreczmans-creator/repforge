import 'package:meta/meta.dart';
import 'package:repforge/domain/training/training.dart';

/// A completed set with the moment of its session, the input of the PR and
/// volume rules.
class PerformedSet {
  /// [createdAt] is when the session was created; it breaks a tie between
  /// sessions with the same [startedAt] (the earlier-created one came first).
  /// When omitted it equals [startedAt].
  const PerformedSet({
    required this.sessionId,
    required this.startedAt,
    required this.set,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? startedAt;

  final String sessionId;
  final DateTime startedAt;
  final DateTime createdAt;
  final SessionSet set;
}

/// What a personal record measures (TRN-026).
enum PrMeasure {
  /// Heaviest load at an exact repetition count, 1 to 12 (weighted).
  heaviestAtReps,

  /// Longest duration (timed).
  longestDuration,

  /// Longest distance (distance).
  longestDistance,

  /// Most repetitions (bodyweight).
  mostReps,
}

/// Highest repetition count that has its own weighted record.
const maxPrReps = 12;

/// One record slot: a measure and, for [PrMeasure.heaviestAtReps], the
/// repetition count.
@immutable
class PrKey {
  const PrKey(this.measure, [this.reps]);

  final PrMeasure measure;
  final int? reps;

  @override
  bool operator ==(Object other) =>
      other is PrKey && other.measure == measure && other.reps == reps;

  @override
  int get hashCode => Object.hash(measure, reps);

  @override
  String toString() => 'PrKey($measure, $reps)';
}

/// The record in one slot and the set that holds it. [value] is kg, seconds,
/// metres or repetitions according to the measure.
class PersonalRecord {
  const PersonalRecord({
    required this.key,
    required this.value,
    required this.setId,
    required this.sessionId,
    required this.startedAt,
  });

  final PrKey key;
  final double value;
  final String setId;
  final String sessionId;
  final DateTime startedAt;
}

/// Pure personal-record rules (D04 TRN-026, TRN-019). Records are derived
/// from the recorded history every time and never stored, so editing or
/// deleting a set changes them with no bookkeeping (TRN-024(1)).
///
/// Definitions:
/// - weighted: heaviest load at each exact repetition count 1 to 12;
/// - timed: longest duration (an added load is ignored);
/// - distance: longest distance;
/// - bodyweight: most repetitions (an added load is ignored: assumption, D04
///   says "most repetitions" only);
/// - assisted and cardio: no record is defined (D04 lists none; recorded as
///   a gap rather than invented).
///
/// Only completed working and failure sets count; warm-ups never do. A set is
/// a record when it strictly beats every earlier set in its slot, the first
/// set in a slot included; a tie is not a record. "Earlier" is chronological:
/// session start, then session creation time, then session id, then exercise
/// order, then set order.
abstract final class PersonalRecordRules {
  /// The slot and value [set] competes in, or null when it competes in none
  /// (warm-up, not completed, a type without a record, more than 12 reps).
  static ({PrKey key, double value})? slotOf(SessionSet set) {
    if (!set.completed || set.kind == SetKind.warmUp) return null;
    return switch (set.data) {
      WeightedSet(:final load, :final reps)
          when reps >= 1 && reps <= maxPrReps =>
        (key: PrKey(PrMeasure.heaviestAtReps, reps), value: load.value),
      BodyweightSet(:final reps) => (
        key: const PrKey(PrMeasure.mostReps),
        value: reps.toDouble(),
      ),
      TimedSet(:final duration) => (
        key: const PrKey(PrMeasure.longestDuration),
        value: duration.inSeconds.toDouble(),
      ),
      DistanceSet(:final metres) => (
        key: const PrKey(PrMeasure.longestDistance),
        value: metres,
      ),
      _ => null,
    };
  }

  /// [history] in chronological order (a new list).
  static List<PerformedSet> chronological(Iterable<PerformedSet> history) =>
      [...history]..sort((a, b) {
        var c = a.startedAt.compareTo(b.startedAt);
        if (c != 0) return c;
        c = a.createdAt.compareTo(b.createdAt);
        if (c != 0) return c;
        c = a.sessionId.compareTo(b.sessionId);
        if (c != 0) return c;
        c = a.set.exerciseOrder.compareTo(b.set.exerciseOrder);
        if (c != 0) return c;
        return a.set.setOrder.compareTo(b.set.setOrder);
      });

  /// Ids of the sets that were a record when they were recorded, judged
  /// against the sets before them in [history] (all of one exercise).
  static Set<String> recordSetIds(Iterable<PerformedSet> history) {
    final best = <PrKey, double>{};
    final out = <String>{};
    for (final p in chronological(history)) {
      final slot = slotOf(p.set);
      if (slot == null) continue;
      final current = best[slot.key];
      if (current == null || slot.value > current) {
        best[slot.key] = slot.value;
        out.add(p.set.id);
      }
    }
    return out;
  }

  /// True when the set [setId] was a record at the time it was recorded.
  static bool isRecordWhenRecorded(
    Iterable<PerformedSet> history,
    String setId,
  ) => recordSetIds(history).contains(setId);

  /// The slots the set [setId] set a record in (a set is in one slot, so at
  /// most one key); empty when it is not a record.
  static List<PrKey> recordKeysOfSet(
    Iterable<PerformedSet> history,
    String setId,
  ) {
    final p = history.where((h) => h.set.id == setId).firstOrNull;
    if (p == null || !isRecordWhenRecorded(history, setId)) return const [];
    final slot = slotOf(p.set);
    return slot == null ? const [] : [slot.key];
  }

  /// The standing record of every slot in [history]: the best value, held by
  /// the earliest set that reached it.
  static Map<PrKey, PersonalRecord> currentRecords(
    Iterable<PerformedSet> history,
  ) {
    final out = <PrKey, PersonalRecord>{};
    for (final p in chronological(history)) {
      final slot = slotOf(p.set);
      if (slot == null) continue;
      final current = out[slot.key];
      if (current == null || slot.value > current.value) {
        out[slot.key] = PersonalRecord(
          key: slot.key,
          value: slot.value,
          setId: p.set.id,
          sessionId: p.sessionId,
          startedAt: p.startedAt,
        );
      }
    }
    return out;
  }
}
