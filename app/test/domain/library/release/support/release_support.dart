import 'dart:convert';
import 'dart:io';

import 'package:repforge/domain/library/release/reconciliation_planner.dart';
import 'package:repforge/domain/library/release/release_format.dart';
import 'package:repforge/domain/library/release/release_validator.dart';

const String referenceDir = '../docs/catalogue/reference';
const String release2Asset =
    'assets/catalogue/releases/repforge-release-2.json';

const Map<ReleaseReferenceName, String> referenceFileNames = {
  ReleaseReferenceName.anatomy: 'anatomy.json',
  ReleaseReferenceName.movementPatterns: 'movement-patterns.json',
  ReleaseReferenceName.equipment: 'equipment.json',
  ReleaseReferenceName.ledger: 'ledger.json',
  ReleaseReferenceName.coverage: 'coverage.json',
};

/// The exact bytes of the approved reference files.
Map<ReleaseReferenceName, List<int>> approvedReferenceBytes() => {
  for (final e in referenceFileNames.entries)
    e.key: File('$referenceDir/${e.value}').readAsBytesSync(),
};

/// The approved reference set, parsed from the files (throws on a defect:
/// the approved files are a precondition of every test that uses this).
ApprovedReferenceSet approvedSet() {
  final loaded = loadApprovedReferenceSet(approvedReferenceBytes());
  final set = loaded.set;
  if (set == null) {
    throw StateError('Approved reference data: ${loaded.findings}');
  }
  return set;
}

List<int> release2Bytes() => File(release2Asset).readAsBytesSync();

/// The shipped release as a mutable map.
Map<String, Object?> release2Map() =>
    jsonDecode(utf8.decode(release2Bytes()))! as Map<String, Object?>;

List<int> bytesOf(Map<String, Object?> release) =>
    utf8.encode(const JsonEncoder.withIndent('  ').convert(release));

List<Map<String, Object?>> exercisesOf(Map<String, Object?> release) =>
    (release['exercises']! as List<Object?>).cast<Map<String, Object?>>();

/// The shipped release reduced to the exercises in [ids] (in file order).
Map<String, Object?> subsetRelease(Iterable<String> ids, {int? release}) {
  final wanted = ids.toSet();
  final map = release2Map();
  map['exercises'] = [
    for (final e in exercisesOf(map))
      if (wanted.contains(e['id'])) e,
  ];
  if (release != null) map['release'] = release;
  return map;
}

/// A validated release made of [ids] from the shipped release, with the given
/// revisions (default 1), release number and retirements.
ValidatedRelease validatedSubset(
  Iterable<String> ids, {
  Map<String, int> revisions = const {},
  int release = 2,
  List<Map<String, Object?>> retirements = const [],
  void Function(Map<String, Object?> release)? edit,
}) {
  final map = subsetRelease(ids, release: release);
  for (final e in exercisesOf(map)) {
    // Unit tests of the planner start from revision 1 unless told otherwise.
    e['revision'] = revisions[e['id']] ?? 1;
  }
  map['retirements'] = retirements;
  edit?.call(map);
  final v = validateReleaseBytes(bytes: bytesOf(map), reference: approvedSet());
  if (!v.isValid) {
    throw StateError('Test release is invalid: ${v.errors}');
  }
  return v.release!;
}

/// Simulates applying [plan] to [snapshot] (test double of the future
/// reconciler; it is not production code and writes no database).
CatalogueStateSnapshot applyPlan(
  CatalogueStateSnapshot snapshot,
  ReconciliationPlan plan,
) {
  final entries = {for (final e in snapshot.exercises) e.id: e};
  for (final i in plan.inserts) {
    entries[i.id] = ExerciseStateEntry.system(
      i.id,
      revision: i.exercise.revision,
      providerId: plan.provider.id,
    );
  }
  for (final u in plan.updates) {
    entries[u.id] = ExerciseStateEntry.system(
      u.id,
      revision: u.toRevision,
      providerId: plan.provider.id,
    );
  }
  for (final r in plan.retirements) {
    final old = entries[r.id]!;
    entries[r.id] = ExerciseStateEntry.system(
      r.id,
      revision: old.revision,
      providerId: old.providerId,
      retired: true,
    );
  }
  return CatalogueStateSnapshot(
    exercises: entries.values,
    equipmentDefaultRoles: snapshot.equipmentDefaultRoles,
    latestAppliedRelease: {
      ...snapshot.latestAppliedRelease,
      if (plan.recordsRelease) plan.provider.id: plan.release.number,
    },
    appliedContentHashes: {
      ...snapshot.appliedContentHashes,
      if (plan.recordsRelease) plan.release: plan.contentHash,
    },
  );
}
