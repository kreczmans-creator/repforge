/// Looks up an enum value by its name; null when [name] is not a string or
/// matches no value.
T? enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// Source of an exercise (ADR-0009 decision 1, OQ-21). Immutable after
/// creation.
enum ExerciseSource {
  /// From a content provider's catalogue release.
  system,

  /// Created in the app, including a custom copy of a system exercise.
  user,

  /// Brought in by a user from an external file, application or
  /// user-controlled source.
  imported,
}

/// Role of an anatomy target. Qualitative only: no percentages or activation
/// values are stored (ADR-0008 decision 3).
enum TargetRole { primary, secondary }

/// Mechanics (owner definition): two or more joints produce the main work
/// (`compound`) or one joint does (`isolation`). Empty for cardio and mobility
/// by owner decision (2026-11-05).
enum Mechanics { compound, isolation }

/// Laterality (owner definition).
enum Laterality {
  /// Both limbs do the same job at the same time.
  bilateral,

  /// One limb works while the other rests or supports, or the limbs do
  /// different jobs.
  unilateral,

  /// Limbs take turns without a break in the set.
  alternating,
}

/// Difficulty (owner definition): technical complexity, not load or fitness.
enum Difficulty { beginner, intermediate, advanced }

/// Relationship kinds (ADR-0008 decision 5). `progressionOf` is stored;
/// `regressionOf` is a derived view and is normalised on input
/// (quality-and-duplicates.md section 2, IC-400).
enum RelationshipKind {
  variationOf,
  progressionOf,
  regressionOf,
  alternativeTo,
  unilateralCounterpartOf;

  /// True for the kinds that are stored as written.
  bool get isStored => this != regressionOf;

  /// True for the kinds with no direction: stored once, ids in order.
  bool get isSymmetric =>
      this == alternativeTo || this == unilateralCounterpartOf;
}

/// Role of an equipment item in one exercise (`equipment.md` section 1): the
/// resistance or assistance comes from a `load` item; a `support` item only
/// holds the body or another item.
enum EquipmentRole { load, support }

/// Default role of an equipment item (`equipment.json`).
enum EquipmentDefaultRole { load, support, cardio, implement }

/// Equipment class of an item or an exercise (`equipment.md` section 5).
enum EquipmentClass {
  freeWeight,
  machine,
  cable,
  smithMachine,
  band,
  kettlebell,
  bodyweight,
  other,
}

/// Lifecycle of a reference id: retired ids stay in the data and are never
/// reused (`reference/ledger.json`).
enum ReferenceStatus { active, retired }

/// Section kinds of exercise content (ADR-0008 decision 6): a controlled
/// domain list stored as text, so a new kind needs no schema change.
abstract final class ContentSectionKinds {
  static const String setup = 'setup';
  static const String execution = 'execution';
  static const String breathing = 'breathing';
  static const String commonMistakes = 'commonMistakes';

  /// The four sections every system exercise carries (IC-210), in order.
  static const List<String> core = [
    setup,
    execution,
    breathing,
    commonMistakes,
  ];

  /// The controlled list. Extend it here (no schema change) for later kinds.
  static const Set<String> controlled = {
    setup,
    execution,
    breathing,
    commonMistakes,
  };

  /// Allowed item counts per section (IC-702): minimum and maximum.
  static const Map<String, (int, int)> itemCounts = {
    setup: (2, 5),
    execution: (3, 6),
    breathing: (1, 2),
    commonMistakes: (2, 4),
  };

  static bool isControlled(String kind) => controlled.contains(kind);
}

/// The locale every exercise has (ADR-0008 decision 7); identity is
/// locale-independent.
const String canonicalLocale = 'en-GB';
