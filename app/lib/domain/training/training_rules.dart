import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';

/// Pure calculation rules for training data. Each has example-based tests.
abstract final class TrainingRules {
  /// RPE range and step (D04 TRN-020). Labels and messages are built from
  /// these, so the owner's decision on the exertion rule changes one place.
  static const rpeMin = 1;
  static const rpeMax = 10;
  static const rpeStep = 0.5;

  /// RIR range (whole numbers).
  static const rirMin = 0;
  static const rirMax = 5;

  /// `1–10` or `0–5`: the accepted range of [scale], for labels.
  static String exertionRange(ExertionScale scale) => switch (scale) {
    ExertionScale.rpe => '$rpeMin–$rpeMax',
    ExertionScale.rir => '$rirMin–$rirMax',
  };

  /// Tonnage in kg for sets where load × reps is meaningful: weighted sets,
  /// and bodyweight sets with added load (added load only; the body's own
  /// mass is not counted so volume is comparable across days). Assisted,
  /// timed, distance and cardio sets contribute zero.
  static double volumeKg(Iterable<SetData> sets) {
    var total = 0.0;
    for (final s in sets) {
      total += switch (s) {
        WeightedSet(:final load, :final reps) => load.value * reps,
        BodyweightSet(:final addedLoad, :final reps) =>
          (addedLoad?.value ?? 0) * reps,
        _ => 0,
      };
    }
    return total;
  }

  /// Estimated one-rep max (Epley): load × (1 + reps / 30), except that a
  /// single rep is the load itself. Defined for weighted sets with 1–12 reps
  /// (Epley is unreliable beyond that); null otherwise.
  static double? estimatedOneRepMax(SetData set) => switch (set) {
    WeightedSet(:final load, :final reps) when reps >= 1 && reps <= 12 =>
      reps == 1 ? load.value : load.value * (1 + reps / 30),
    _ => null,
  };

  /// Heaviest load lifted for at least [minReps] reps across [sets].
  static LoadKg? maxLoadFor(Iterable<SetData> sets, {int minReps = 1}) {
    LoadKg? best;
    for (final s in sets) {
      if (s case WeightedSet(:final load, :final reps) when reps >= minReps) {
        if (best == null || load.value > best.value) best = load;
      }
    }
    return best;
  }

  /// Epley score used for record comparison at any rep count (the 12-rep
  /// guard of [estimatedOneRepMax] is for display, not ranking).
  static double _prScore(WeightedSet s) =>
      s.reps == 1 ? s.load.value : s.load.value * (1 + s.reps / 30);

  /// True when [candidate] strictly beats every comparable set in [history]:
  /// Epley score for weighted sets, added load then reps for bodyweight, less
  /// assistance then
  /// more reps for assisted, duration for timed, distance for distance and
  /// cardio (a cardio set without distance is never a record). An empty
  /// history makes the first set a record. Ties are not records.
  static bool isPersonalRecord(SetData candidate, Iterable<SetData> history) {
    switch (candidate) {
      case WeightedSet():
        final c = _prScore(candidate);
        return history.whereType<WeightedSet>().every((h) => c > _prScore(h));
      case BodyweightSet(:final reps, :final addedLoad):
        // More added load wins; at equal added load, more reps wins.
        final load = addedLoad?.value ?? 0;
        return history.whereType<BodyweightSet>().every((h) {
          final hl = h.addedLoad?.value ?? 0;
          return load > hl || (load == hl && reps > h.reps);
        });
      case AssistedSet(:final reps, :final assistance):
        // Less assistance is better; more reps at equal assistance is better.
        return history.whereType<AssistedSet>().every(
          (h) =>
              assistance.value < h.assistance.value ||
              (assistance.value == h.assistance.value && reps > h.reps),
        );
      case TimedSet(:final duration):
        return history.whereType<TimedSet>().every(
          (h) => duration > h.duration,
        );
      case DistanceSet(:final metres):
        return history.whereType<DistanceSet>().every((h) => metres > h.metres);
      case CardioSet(:final metres):
        if (metres == null) return false;
        return history
            .whereType<CardioSet>()
            .map((h) => h.metres)
            .whereType<double>()
            .every((h) => metres > h);
    }
  }

  /// Validates a rep count (1–100).
  static bool validReps(int reps) => reps >= 1 && reps <= 100;

  /// Validates an exertion rating (D04 TRN-020): RPE 1–10 in steps of 0.5,
  /// RIR 0–5 in whole numbers.
  static bool validExertion(Exertion e) {
    final v = e.value;
    if (v.isNaN || v.isInfinite) return false;
    return switch (e.scale) {
      ExertionScale.rpe =>
        v / rpeStep == (v / rpeStep).roundToDouble() &&
            v >= rpeMin &&
            v <= rpeMax,
      ExertionScale.rir => v == v.roundToDouble() && v >= rirMin && v <= rirMax,
    };
  }
}
