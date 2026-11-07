import 'dart:convert';
import 'dart:io';

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
