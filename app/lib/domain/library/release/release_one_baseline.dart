import 'dart:convert';

import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/integrity_report.dart';
import 'package:repforge/domain/library/legacy_v8_mapping.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/training/training.dart'
    show ExerciseCategory, ExerciseType;

/// "Release 1" of provider `repforge` as a migrated v7 device holds it: the
/// seed file (format 1) passed through the 3a v7 to v8 mapping
/// (`mapLegacyExercise`): system, provider `repforge`, revision 1, targets and
/// equipment as the mapping produces them (no roles), no patterns, no
/// mechanics, laterality, difficulty or attributes.
///
/// It is the "previous catalogue" for release 2 (IC-104, IC-105, IC-110).
/// Every problem is a finding (code `RF-013`); the list is set when none.
({PreviousCatalogue? previous, List<Finding> findings}) releaseOneBaseline(
  String seedJson,
) {
  Finding bad(String message) => Finding(
    code: 'RF-013',
    severity: Severity.error,
    message: 'The seed file is not usable as release 1: $message',
  );
  final Object? root;
  try {
    root = jsonDecode(seedJson);
  } on FormatException catch (e) {
    return (previous: null, findings: [bad('not JSON (${e.message}).')]);
  }
  final list = root is Map<String, Object?> ? root['exercises'] : null;
  if (list is! List<Object?>) {
    return (previous: null, findings: [bad('no exercises list.')]);
  }
  final stamp = DateTime.utc(1970);
  final out = <CatalogueExercise>[];
  for (final raw in list) {
    if (raw is! Map<String, Object?>) {
      return (previous: null, findings: [bad('an entry is not an object.')]);
    }
    final id = raw['id'];
    final name = raw['name'];
    final type = ExerciseType.values.asNameMap()[raw['type']];
    final category = ExerciseCategory.values.asNameMap()[raw['category']];
    if (id is! String || name is! String || type == null || category == null) {
      return (previous: null, findings: [bad('entry $id is malformed.')]);
    }
    final mapped = mapLegacyExercise(
      LegacyExerciseRow(
        id: id,
        primaryMuscle: raw['primaryMuscle'],
        secondaryMusclesJson: jsonEncode(raw['secondaryMuscles'] ?? const []),
        equipmentJson: jsonEncode(raw['equipment'] ?? const []),
        supplied: 1,
      ),
    );
    final aliases = [
      for (final a in (raw['aliases'] as List<Object?>?) ?? const []) '$a',
    ];
    out.add(
      CatalogueExercise(
        id: ExerciseId(id),
        names: ExerciseNames.english(name, aliases: aliases),
        type: type,
        category: category,
        source: mapped.source,
        providerId: mapped.providerId,
        revision: mapped.revision,
        targets: mapped.targets,
        equipment: [
          for (final e in mapped.equipment) ExerciseEquipment(e.item),
        ],
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
  }
  return (previous: PreviousCatalogue(exercises: out), findings: const []);
}
