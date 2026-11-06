import 'dart:convert';
import 'dart:io';

import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/catalogue_records.dart';
import 'package:repforge/domain/library/coverage_spec.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/integrity_report.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/reference_parsers.dart';
import 'package:repforge/domain/library/reference_validation.dart';
import 'package:repforge/domain/training/training.dart'
    show ExerciseCategory, ExerciseType;

/// Where the approved specification lives, relative to `app/` (tests run from
/// there). The files are read only.
const String catalogueDir = '../docs/catalogue';

Object? readJson(String relative) =>
    jsonDecode(File('$catalogueDir/$relative').readAsStringSync());

T unwrap<T>(Result<T> r) => switch (r) {
  Ok<T>(:final value) => value,
  Err<T>(:final error) => throw StateError(
    'Unexpected error: ${error.message}',
  ),
};

/// The approved reference data, parsed from the files.
final class ApprovedReference {
  ApprovedReference._({
    required this.anatomy,
    required this.patterns,
    required this.equipment,
    required this.ledger,
    required this.coverage,
  });

  factory ApprovedReference.load() => ApprovedReference._(
    anatomy: unwrap(parseAnatomyReference(readJson('reference/anatomy.json'))),
    patterns: unwrap(
      parsePatternReference(readJson('reference/movement-patterns.json')),
    ),
    equipment: unwrap(
      parseEquipmentReference(readJson('reference/equipment.json')),
    ),
    ledger: unwrap(parseLedger(readJson('reference/ledger.json'))),
    coverage: unwrap(parseCoverageSpec(readJson('reference/coverage.json'))),
  );

  final AnatomyReference anatomy;
  final PatternReference patterns;
  final EquipmentReference equipment;
  final List<LedgerEntry> ledger;
  final CoverageSpec coverage;

  ReferenceData get data => ReferenceData(
    anatomy: AnatomyTree(anatomy.nodes),
    patterns: PatternTree(patterns.nodes),
    equipment: EquipmentCatalogue(equipment.items),
  );
}

/// Provider `repforge` as the registry holds it.
const ContentProvider repforgeProvider = ContentProvider(
  id: ProviderId.repforge,
  name: 'RepForge',
  licence: 'Original RepForge content',
  attribution: 'RepForge editorial',
);

final DateTime fixtureTime = DateTime.utc(2026, 11, 5);

/// The 89 seed exercises re-expressed with the approved release-2
/// classifications (`mapping-existing.json`): targets, patterns, equipment
/// with roles, mechanics, laterality, difficulty, attributes, aliases.
List<CatalogueExercise> release2Exercises() {
  final m = readJson('mapping-existing.json')! as Map<String, Object?>;
  final provenance =
      (m['seedProvenance']! as Map<String, Object?>)['authoredBy']! as String;
  return [
    for (final raw
        in (m['exercises']! as List<Object?>).cast<Map<String, Object?>>())
      _fromMapping(raw, provenance),
  ];
}

CatalogueExercise _fromMapping(Map<String, Object?> e, String author) {
  List<String> strings(String key) =>
      ((e[key] as List<Object?>?) ?? const []).cast<String>();
  final primary = strings('proposedPrimary');
  final secondary = strings('proposedSecondary');
  final roles = (e['equipmentRoles'] as Map<String, Object?>?) ?? const {};
  final aliases = [
    for (final a in strings('seedAliases'))
      if (!strings('aliasesRemove').contains(a)) a,
    ...strings('aliasesAdd'),
  ];
  final attrs = (e['attributes'] as Map<String, Object?>?) ?? const {};
  final flags = ((e['flags'] as List<Object?>?) ?? const [])
      .cast<Map<String, Object?>>();
  final roleNote = flags.isEmpty
      ? 'Role differs from the default.'
      : flags.first['text']! as String;
  return CatalogueExercise(
    id: ExerciseId(e['id']! as String),
    names: ExerciseNames.english(e['name']! as String, aliases: aliases),
    type: ExerciseType.values.byName(e['loggingType']! as String),
    category: ExerciseCategory.values.byName(e['category']! as String),
    source: ExerciseSource.system,
    providerId: ProviderId.repforge,
    revision: 1,
    targets: [
      for (var i = 0; i < primary.length; i++)
        ExerciseTarget(
          node: AnatomyNodeId(primary[i]),
          role: TargetRole.primary,
          ordinal: i,
        ),
      for (var i = 0; i < secondary.length; i++)
        ExerciseTarget(
          node: AnatomyNodeId(secondary[i]),
          role: TargetRole.secondary,
          ordinal: primary.length + i,
        ),
    ],
    patterns: [
      for (final p in strings('proposedPatterns')) MovementPatternId(p),
    ],
    equipment: [
      for (final item in strings('proposedEquipment'))
        ExerciseEquipment(
          EquipmentItemId(item),
          roleOverride: roles[item] == null
              ? null
              : EquipmentRole.values.byName(roles[item]! as String),
          overrideNote: roles[item] == null ? null : roleNote,
        ),
    ],
    mechanics: e['mechanics'] == null
        ? null
        : Mechanics.values.byName(e['mechanics']! as String),
    laterality: Laterality.values.byName(e['laterality']! as String),
    difficulty: Difficulty.values.byName(e['difficulty']! as String),
    attributes: {
      for (final a in attrs.entries)
        ExerciseAttribute.values.byName(a.key): a.value! as String,
    },
    provenance: ExerciseProvenance(authoredBy: author),
    createdAt: fixtureTime,
    updatedAt: fixtureTime,
  );
}

/// The integrity input for release 2: approved reference data and the 89
/// exercises, provider `repforge`, no relationships and no content.
IntegrityInput release2Input(
  ApprovedReference ref, {
  IntegrityOptions options = const IntegrityOptions(),
  bool withLedger = true,
  bool withCoverage = true,
}) => IntegrityInput(
  anatomy: ref.anatomy.nodes,
  patterns: ref.patterns.nodes,
  equipment: ref.equipment.items,
  exercises: release2Exercises(),
  providers: const [repforgeProvider],
  release: const ReleaseId(ProviderId.repforge, 2),
  contentHash: 'sha256:test',
  ledger: withLedger ? ref.ledger : null,
  coverage: withCoverage ? ref.coverage : null,
  options: options,
);

/// Short constructors for tests.
AnatomyNodeId node(String v) => AnatomyNodeId(v);
ExerciseId xid(String v) => ExerciseId(v);

ExerciseTarget primary(String node, int ordinal) => ExerciseTarget(
  node: AnatomyNodeId(node),
  role: TargetRole.primary,
  ordinal: ordinal,
);

ExerciseTarget secondary(String node, int ordinal) => ExerciseTarget(
  node: AnatomyNodeId(node),
  role: TargetRole.secondary,
  ordinal: ordinal,
);

/// A complete, valid system exercise (a barbell bench press) that tests
/// modify through named arguments.
CatalogueExercise exercise(
  String id, {
  String? name,
  List<String> aliases = const ['Test alias'],
  ExerciseSource source = ExerciseSource.system,
  ExerciseCategory category = ExerciseCategory.push,
  ExerciseType type = ExerciseType.weighted,
  List<ExerciseTarget>? targets,
  List<String> patterns = const ['horizontalPush'],
  List<ExerciseEquipment>? equipment,
  Object? mechanics = Mechanics.compound,
  Object? laterality = Laterality.bilateral,
  Object? difficulty = Difficulty.beginner,
  Map<ExerciseAttribute, String> attributes = const {},
  DateTime? retiredAt,
  int revision = 1,
  ExerciseId? copiedFromId,
  String? author = 'Test editor',
}) {
  final system = source == ExerciseSource.system;
  return CatalogueExercise(
    id: xid(id),
    names: ExerciseNames.english(
      name ?? 'Test ${id.replaceFirst('lib-', '')}',
      aliases: aliases,
    ),
    type: type,
    category: category,
    source: source,
    providerId: system ? ProviderId.repforge : null,
    revision: system ? revision : null,
    targets: targets ?? [primary('chest', 0), secondary('triceps', 1)],
    patterns: [for (final p in patterns) MovementPatternId(p)],
    equipment:
        equipment ??
        const [
          ExerciseEquipment(EquipmentItemId('barbell')),
          ExerciseEquipment(EquipmentItemId('bench')),
        ],
    mechanics: mechanics as Mechanics?,
    laterality: laterality as Laterality?,
    difficulty: difficulty as Difficulty?,
    attributes: attributes,
    retiredAt: retiredAt,
    copiedFromId: copiedFromId,
    provenance: ExerciseProvenance(authoredBy: author),
    createdAt: fixtureTime,
    updatedAt: fixtureTime,
  );
}

extension FindingList on Iterable<Finding> {
  List<String> get codes => [for (final f in this) f.code];
  Iterable<Finding> withCode(String code) => where((f) => f.code == code);
}

/// Retired copies of reference entries, for the retired-reference tests.
abstract final class AnatomyNodeAs {
  static AnatomyNode retired(AnatomyNode n) => AnatomyNode(
    id: n.id,
    parentId: n.parentId,
    level: n.level,
    sort: n.sort,
    labels: n.labels,
    nonAnatomical: n.nonAnatomical,
    status: ReferenceStatus.retired,
  );
}

abstract final class PatternAs {
  static MovementPattern retired(MovementPattern p) => MovementPattern(
    id: p.id,
    parentId: p.parentId,
    level: p.level,
    sort: p.sort,
    labels: p.labels,
    relatedCategories: p.relatedCategories,
    status: ReferenceStatus.retired,
  );
}

abstract final class ItemAs {
  static EquipmentItem retired(EquipmentItem i) => EquipmentItem(
    id: i.id,
    sort: i.sort,
    labels: i.labels,
    equipmentClass: i.equipmentClass,
    defaultRole: i.defaultRole,
    existing: i.existing,
    status: ReferenceStatus.retired,
  );
}

ReferenceData referenceOf(
  List<AnatomyNode> nodes,
  List<MovementPattern> patterns,
  List<EquipmentItem> items,
) => ReferenceData(
  anatomy: AnatomyTree(nodes),
  patterns: PatternTree(patterns),
  equipment: EquipmentCatalogue(items),
);
