import 'package:meta/meta.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/value_equality.dart';
import 'package:repforge/domain/training/training.dart'
    show ExerciseCategory, ExerciseType;

/// One anatomy target of an exercise (ADR-0008 decision 3): a node, a
/// qualitative role and a position. A node appears at most once per exercise.
@immutable
final class ExerciseTarget extends ValueObject {
  const ExerciseTarget({
    required this.node,
    required this.role,
    required this.ordinal,
  });

  final AnatomyNodeId node;
  final TargetRole role;

  /// Position across all targets of the exercise, contiguous from 0 (IC-309).
  final int ordinal;

  bool get isPrimary => role == TargetRole.primary;

  @override
  List<Object?> get props => [node, role, ordinal];

  @override
  String toString() => '${role.name}:$node@$ordinal';
}

/// An equipment item an exercise needs, with an optional per-exercise role
/// override (`equipment.md` section 1, rule 5). The override needs a note.
@immutable
final class ExerciseEquipment extends ValueObject {
  const ExerciseEquipment(this.item, {this.roleOverride, this.overrideNote});

  final EquipmentItemId item;
  final EquipmentRole? roleOverride;
  final String? overrideNote;

  @override
  List<Object?> get props => [item, roleOverride, overrideNote];
}

/// A name and its aliases in one locale.
@immutable
final class LocalizedName extends ValueObject {
  const LocalizedName(this.name, {this.aliases = const []});

  final String name;
  final List<String> aliases;

  @override
  List<Object?> get props => [name, aliases];
}

/// Names and aliases by locale. `en-GB` is canonical and always present;
/// other locales go in here, never in a second exercise record (ADR-0008
/// decision 7).
@immutable
final class ExerciseNames extends ValueObject {
  ExerciseNames(Map<String, LocalizedName> byLocale)
    : byLocale = Map.unmodifiable(byLocale);

  /// Convenience for the canonical locale only.
  factory ExerciseNames.english(
    String name, {
    List<String> aliases = const [],
  }) => ExerciseNames({canonicalLocale: LocalizedName(name, aliases: aliases)});

  final Map<String, LocalizedName> byLocale;

  /// The canonical name; empty when the canonical locale is missing.
  String get name => byLocale[canonicalLocale]?.name ?? '';

  /// The canonical aliases.
  List<String> get aliases => byLocale[canonicalLocale]?.aliases ?? const [];

  @override
  List<Object?> get props => [byLocale];
}

/// Who wrote and who reviewed an exercise (IC-212).
@immutable
final class ExerciseProvenance extends ValueObject {
  const ExerciseProvenance({this.authoredBy, this.reviewedBy, this.sourceRef});

  final String? authoredBy;
  final String? reviewedBy;

  /// Record id in the provider's dataset, if any.
  final String? sourceRef;

  @override
  List<Object?> get props => [authoredBy, reviewedBy, sourceRef];
}

/// The catalogue exercise (ADR-0008, plan section 3): an Engineering Object
/// with a stable id, a source and provenance, classifications, anatomy
/// targets, equipment with roles, optional attributes and a lifecycle.
///
/// The value type does not enforce the catalogue rules: user and legacy data
/// must be representable so it can be reported on. The rules are in
/// `exercise_rules.dart`; see `validateExercise`.
@immutable
final class CatalogueExercise extends ValueObject {
  CatalogueExercise({
    required this.id,
    required this.names,
    required this.type,
    required this.category,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.providerId,
    this.revision,
    List<ExerciseTarget> targets = const [],
    List<MovementPatternId> patterns = const [],
    List<ExerciseEquipment> equipment = const [],
    this.mechanics,
    this.laterality,
    this.difficulty,
    Map<ExerciseAttribute, String> attributes = const {},
    this.retiredAt,
    this.copiedFromId,
    this.provenance = const ExerciseProvenance(),
  }) : targets = List.unmodifiable(targets),
       patterns = List.unmodifiable(patterns),
       equipment = List.unmodifiable(equipment),
       attributes = Map.unmodifiable(attributes);

  final ExerciseId id;
  final ExerciseNames names;

  /// Logging type (the six existing `ExerciseType` values).
  final ExerciseType type;

  /// The seven existing categories.
  final ExerciseCategory category;
  final ExerciseSource source;

  /// Set for system exercises; null for user and imported ones.
  final ProviderId? providerId;

  /// Catalogue revision of a system exercise (at least 1); null otherwise.
  final int? revision;
  final List<ExerciseTarget> targets;

  /// Ordered; the first is the primary pattern (IC-205).
  final List<MovementPatternId> patterns;
  final List<ExerciseEquipment> equipment;

  /// Empty for cardio and mobility by owner decision (2026-11-05).
  final Mechanics? mechanics;
  final Laterality? laterality;
  final Difficulty? difficulty;

  /// Optional attributes; the values are validated against the vocabulary.
  final Map<ExerciseAttribute, String> attributes;

  /// Set when a release retired the exercise; it stays resolvable for history.
  final DateTime? retiredAt;

  /// For a custom copy: the exercise it was copied from.
  final ExerciseId? copiedFromId;
  final ExerciseProvenance provenance;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get name => names.name;
  List<String> get aliases => names.aliases;
  bool get isActive => retiredAt == null;
  bool get isSystem => source == ExerciseSource.system;

  List<ExerciseTarget> get primaryTargets => [
    for (final t in targets)
      if (t.isPrimary) t,
  ];

  List<ExerciseTarget> get secondaryTargets => [
    for (final t in targets)
      if (!t.isPrimary) t,
  ];

  /// The first pattern, or null when the exercise has none.
  MovementPatternId? get primaryPattern =>
      patterns.isEmpty ? null : patterns.first;

  /// Effective role of an equipment use in this exercise: the override,
  /// else the item's default (`support` stays support; load, cardio and
  /// implement are load).
  EquipmentRole effectiveRole(ExerciseEquipment use, EquipmentCatalogue items) {
    final override = use.roleOverride;
    if (override != null) return override;
    final defaultRole = items.item(use.item)?.defaultRole;
    return defaultRole == EquipmentDefaultRole.support
        ? EquipmentRole.support
        : EquipmentRole.load;
  }

  /// The load-role items (support items ignored, as in the near-duplicate
  /// signature and the equipment class).
  Set<EquipmentItemId> loadItems(EquipmentCatalogue items) => {
    for (final e in equipment)
      if (effectiveRole(e, items) == EquipmentRole.load) e.item,
  };

  CatalogueExercise copyWith({
    ExerciseId? id,
    ExerciseNames? names,
    ExerciseType? type,
    ExerciseCategory? category,
    ExerciseSource? source,
    Object? providerId = _unset,
    Object? revision = _unset,
    List<ExerciseTarget>? targets,
    List<MovementPatternId>? patterns,
    List<ExerciseEquipment>? equipment,
    Object? mechanics = _unset,
    Object? laterality = _unset,
    Object? difficulty = _unset,
    Map<ExerciseAttribute, String>? attributes,
    Object? retiredAt = _unset,
    Object? copiedFromId = _unset,
    ExerciseProvenance? provenance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CatalogueExercise(
    id: id ?? this.id,
    names: names ?? this.names,
    type: type ?? this.type,
    category: category ?? this.category,
    source: source ?? this.source,
    providerId: identical(providerId, _unset)
        ? this.providerId
        : providerId as ProviderId?,
    revision: identical(revision, _unset) ? this.revision : revision as int?,
    targets: targets ?? this.targets,
    patterns: patterns ?? this.patterns,
    equipment: equipment ?? this.equipment,
    mechanics: identical(mechanics, _unset)
        ? this.mechanics
        : mechanics as Mechanics?,
    laterality: identical(laterality, _unset)
        ? this.laterality
        : laterality as Laterality?,
    difficulty: identical(difficulty, _unset)
        ? this.difficulty
        : difficulty as Difficulty?,
    attributes: attributes ?? this.attributes,
    retiredAt: identical(retiredAt, _unset)
        ? this.retiredAt
        : retiredAt as DateTime?,
    copiedFromId: identical(copiedFromId, _unset)
        ? this.copiedFromId
        : copiedFromId as ExerciseId?,
    provenance: provenance ?? this.provenance,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    names,
    type,
    category,
    source,
    providerId,
    revision,
    targets,
    patterns,
    equipment,
    mechanics,
    laterality,
    difficulty,
    attributes,
    retiredAt,
    copiedFromId,
    provenance,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() => 'CatalogueExercise($id)';
}

const Object _unset = Object();

/// The class of an exercise for coverage and diversity (`equipment.md`
/// section 5): ignore support items; of the rest take the first class in the
/// order Smith machine, cable, machine, kettlebell, band, free weight, other;
/// with nothing left the class is bodyweight.
EquipmentClass equipmentClassOf(
  CatalogueExercise exercise,
  EquipmentCatalogue items,
) {
  const order = [
    EquipmentClass.smithMachine,
    EquipmentClass.cable,
    EquipmentClass.machine,
    EquipmentClass.kettlebell,
    EquipmentClass.band,
    EquipmentClass.freeWeight,
    EquipmentClass.other,
  ];
  final present = <EquipmentClass>{
    for (final use in exercise.equipment)
      if (exercise.effectiveRole(use, items) == EquipmentRole.load)
        ?items.item(use.item)?.equipmentClass,
  };
  for (final c in order) {
    if (present.contains(c)) return c;
  }
  return EquipmentClass.bodyweight;
}
