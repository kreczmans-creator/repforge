import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/release/release_hash.dart';
import 'package:repforge/domain/library/release/release_parser.dart';
import 'package:repforge/domain/library/release/release_validator.dart';

import '../../tool/build_release_2.dart';
import '../domain/library/release/support/release_support.dart';

/// The release-2 data file is derived from `mapping-existing.json`: it is the
/// exact output of the generator, and it validates against the bundled
/// reference copies.
void main() {
  late Map<String, Object?> mapping;
  setUpAll(() {
    mapping =
        jsonDecode(File(mappingPath).readAsStringSync())!
            as Map<String, Object?>;
  });

  test('the shipped release is byte-identical to a fresh generation', () {
    final generated = buildRelease2FromFiles();
    final shipped = File(releaseAssetPath).readAsStringSync();
    expect(shipped, generated);
    expect(
      releaseContentHash(File(releaseAssetPath).readAsBytesSync()),
      releaseContentHash(utf8.encode(generated)),
    );
  });

  test('generation is deterministic', () {
    expect(buildRelease2FromFiles(), buildRelease2FromFiles());
  });

  test('the bundled reference copies give the same bytes as the docs', () {
    final fromAssets = buildRelease2(mapping, {
      for (final s in referenceSections)
        s.file: releaseContentHash(
          File('assets/catalogue/reference/${s.file}').readAsBytesSync(),
        ),
    });
    expect(fromAssets, File(releaseAssetPath).readAsStringSync());
  });

  test('all 89 ids of the mapping are kept, in mapping order, revision 1', () {
    final ids = [
      for (final e in (mapping['exercises']! as List<Object?>))
        (e! as Map<String, Object?>)['id']! as String,
    ];
    expect(ids, hasLength(89));
    final doc = parseReleaseBytes(release2Bytes()).document!;
    expect([for (final e in doc.exercises) e.id.value], ids);
    expect(doc.exercises.every((e) => e.revision == 1), isTrue);
  });

  test('the ids equal those of the release-1 seed file', () {
    final seed =
        jsonDecode(
              File('assets/seed/exercise_library.json').readAsStringSync(),
            )!
            as Map<String, Object?>;
    final seedIds = {
      for (final e in (seed['exercises']! as List<Object?>))
        (e! as Map<String, Object?>)['id']! as String,
    };
    final doc = parseReleaseBytes(release2Bytes()).document!;
    expect({for (final e in doc.exercises) e.id.value}, seedIds);
  });

  test('instructions are not written yet: no content, media or '
      'relationships', () {
    final doc = parseReleaseBytes(release2Bytes()).document!;
    expect(doc.content, isEmpty);
    expect(doc.media, isEmpty);
    expect(doc.relationships, isEmpty);
    expect(doc.retirements, isEmpty);
  });

  test('classifications come from the mapping, not from the seed fields', () {
    final doc = parseReleaseBytes(release2Bytes()).document!;
    final byId = {for (final e in doc.exercises) e.id.value: e};
    for (final raw in (mapping['exercises']! as List<Object?>)) {
      final m = raw! as Map<String, Object?>;
      final e = byId[m['id']]!;
      expect(e.names.name, m['name']);
      expect([
        for (final t in e.primaryTargets) t.node.value,
      ], m['proposedPrimary']);
      expect([
        for (final t in e.secondaryTargets) t.node.value,
      ], m['proposedSecondary']);
      expect([for (final p in e.patterns) p.value], m['proposedPatterns']);
      expect([
        for (final q in e.equipment) q.item.value,
      ], m['proposedEquipment']);
      expect(e.mechanics?.name, m['mechanics']);
      expect(e.laterality?.name, m['laterality']);
      expect(e.difficulty?.name, m['difficulty']);
      expect(e.type.name, m['loggingType']);
      expect(e.category.name, m['category']);
      final removed = (m['aliasesRemove'] as List<Object?>?) ?? const [];
      expect(e.aliases.any(removed.contains), isFalse);
      for (final a in (m['aliasesAdd'] as List<Object?>?) ?? const []) {
        expect(e.aliases, contains(a));
      }
    }
  });

  test('release 2 validates against the bundled reference copies with zero '
      'errors', () {
    final files = {
      for (final e in referenceFileNames.entries)
        e.key: File('assets/catalogue/reference/${e.value}').readAsBytesSync(),
    };
    final loaded = loadApprovedReferenceSet(files);
    expect(loaded.findings, isEmpty);
    final v = validateReleaseBytes(
      bytes: release2Bytes(),
      reference: loaded.set!,
    );
    expect(v.errors, isEmpty);
    expect(v.report!.passed, isTrue);
  });
}
