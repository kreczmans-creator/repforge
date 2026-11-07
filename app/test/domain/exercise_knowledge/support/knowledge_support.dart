import 'dart:convert';
import 'dart:io';

import 'package:repforge/data/catalogue/bundled_exercise_knowledge_source.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge_source.dart';

/// The shipped knowledge release, read from the repository (tests run from
/// `app/`).
const String release3Asset = BundledExerciseKnowledgeSource.releaseAsset;

List<int> release3Bytes() => File(release3Asset).readAsBytesSync();

Map<String, Object?> release3Map() =>
    jsonDecode(utf8.decode(release3Bytes()))! as Map<String, Object?>;

List<Map<String, Object?>> exercisesIn(Map<String, Object?> release) =>
    (release['exercises']! as List<Object?>).cast<Map<String, Object?>>();

Map<ReleaseReferenceName, List<int>> shippedReferenceBytes() => {
  for (final MapEntry(:key, :value)
      in BundledExerciseKnowledgeSource.referenceAssets.entries)
    key: File(value).readAsBytesSync(),
};

/// The knowledge catalogue built from the shipped files, as the app builds it.
KnowledgeCatalogue shippedCatalogue() {
  final r = loadKnowledgeCatalogue(
    KnowledgeBundle(
      release: release3Bytes(),
      reference: shippedReferenceBytes(),
    ),
  );
  return (r as Ok<KnowledgeCatalogue>).value;
}

/// A bundle reader backed by the repository files (no asset bundle, no
/// network): the data path of the app with the bundle replaced by disk.
Future<List<int>> readFromRepository(String key) async =>
    File(key).readAsBytesSync();

/// The production adapter over the repository files.
BundledExerciseKnowledgeSource repositorySource() =>
    BundledExerciseKnowledgeSource(readBytes: readFromRepository);
