import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/release/release_format.dart';
import 'package:repforge/domain/library/release/release_hash.dart';
import 'package:repforge/domain/library/release/release_validator.dart';

import 'support/release_support.dart';

List<String> _codes(ReleaseValidation v) => [
  for (final f in v.findings) f.code,
];

void main() {
  late ApprovedReferenceSet reference;
  setUpAll(() => reference = approvedSet());

  ReleaseValidation validate(Map<String, Object?> map, {String? expected}) =>
      validateReleaseBytes(
        bytes: bytesOf(map),
        reference: reference,
        expectedContentHash: expected,
      );

  group('release 2 as shipped', () {
    test('is valid with zero errors and the exact-bytes hash', () {
      final bytes = release2Bytes();
      final v = validateReleaseBytes(
        bytes: bytes,
        reference: reference,
        expectedContentHash: releaseContentHash(bytes),
      );
      expect(v.errors, isEmpty);
      expect(v.isValid, isTrue);
      expect(v.contentHash, releaseContentHash(bytes));
      expect(v.report!.passed, isTrue);
      expect(v.report!.exerciseCount, 89);
      expect(v.report!.contentHash, releaseContentHash(bytes));
      expect(v.release!.document.exercises, hasLength(89));
    });

    test('the integrity report is the same on every run', () {
      final a = validateReleaseBytes(
        bytes: release2Bytes(),
        reference: reference,
      );
      final b = validateReleaseBytes(
        bytes: release2Bytes(),
        reference: reference,
      );
      expect(a.report!.toJsonString(), b.report!.toJsonString());
    });
  });

  group('all or nothing', () {
    test('a parse failure yields the parse findings and no release', () {
      final v = validateReleaseBytes(bytes: [0xff], reference: reference);
      expect(_codes(v), ['RF-001']);
      expect(v.release, isNull);
      expect(v.report, isNull);
      expect(v.isValid, isFalse);
    });

    test('a wrong content hash is refused (RF-010)', () {
      final v = validate(release2Map(), expected: 'a' * 64);
      expect(_codes(v), contains('RF-010'));
      expect(v.release, isNull);
    });

    test('a reference hash that differs from the approved file (RF-008)', () {
      final map = release2Map();
      ((map['reference']! as Map<String, Object?>)['equipment']!
              as Map<String, Object?>)['sha256'] =
          'b' * 64;
      final v = validate(map);
      expect(v.findings.where((f) => f.code == 'RF-008').map((f) => f.field), [
        'reference.equipment',
      ]);
      expect(v.release, isNull);
    });

    test('a reference file of another provider (RF-009)', () {
      final map = release2Map();
      (map['provider']! as Map<String, Object?>)['id'] = 'other';
      final v = validate(map);
      expect(v.findings.where((f) => f.code == 'RF-009'), hasLength(3));
      expect(v.isValid, isFalse);
    });

    test('an unknown anatomy node is refused with the full list', () {
      final map = release2Map();
      final ex = exercisesOf(map);
      (ex[0]['targets']! as List<Object?>).add({
        'node': 'noSuchNode',
        'role': 'secondary',
      });
      ex[1]['patterns'] = ['noSuchPattern'];
      ex[2]['equipment'] = [
        {'item': 'noSuchItem'},
      ];
      final v = validate(map);
      expect(v.isValid, isFalse);
      expect(v.release, isNull);
      final bySubject = {for (final f in v.errors) f.subjectId};
      expect(
        bySubject,
        containsAll([ex[0]['id'], ex[1]['id'], ex[2]['id']]),
        reason: 'every defect is reported, not only the first',
      );
    });

    test('format defects and catalogue defects are reported together', () {
      final map = release2Map();
      ((map['reference']! as Map<String, Object?>)['anatomy']!
              as Map<String, Object?>)['sha256'] =
          'c' * 64;
      exercisesOf(map)[0]['revision'] = 0;
      final v = validate(map, expected: 'd' * 64);
      expect(_codes(v), containsAll(['RF-008', 'RF-010', 'IC-103']));
    });

    test('a duplicate id and a duplicate normalised name (IC-102, IC-5xx)', () {
      final map = release2Map();
      final ex = exercisesOf(map);
      ex.add(Map<String, Object?>.of(ex[0]));
      map['exercises'] = ex;
      final v = validate(map);
      expect(_codes(v), contains('IC-102'));
      expect(v.isValid, isFalse);
    });

    test('a role override on a cardio item is refused (R-19, IC-315)', () {
      final map = release2Map();
      final skipping = exercisesOf(map)
          .firstWhere((e) => e['id'] == 'lib-skipping');
      skipping['equipment'] = [
        {'item': 'skippingRope', 'role': 'support', 'roleNote': 'Why not.'},
      ];
      final v = validate(map);
      expect(_codes(v), contains('IC-315'));
      expect(v.isValid, isFalse);
    });

    test('a missing laterality is an integrity error, not a parse error', () {
      final map = release2Map();
      exercisesOf(map)[0]['laterality'] = null;
      final v = validate(map);
      expect(v.report, isNotNull);
      expect(v.isValid, isFalse);
    });

    test('warnings and infos do not fail a release', () {
      final v = validateReleaseBytes(
        bytes: release2Bytes(),
        reference: reference,
      );
      expect(v.findings.every((f) => f.severity != Severity.error), isTrue);
      expect(v.isValid, isTrue);
    });
  });

  group('reference files', () {
    test('a file that is not supplied (RF-008)', () {
      final files = approvedReferenceBytes()
        ..remove(ReleaseReferenceName.ledger);
      final loaded = loadApprovedReferenceSet(files);
      expect(loaded.set, isNull);
      expect([for (final f in loaded.findings) f.code], ['RF-008']);
    });

    test('a file that is not JSON or not the expected shape (RF-011)', () {
      var files = approvedReferenceBytes()
        ..[ReleaseReferenceName.anatomy] = utf8.encode('nope');
      var loaded = loadApprovedReferenceSet(files);
      expect(loaded.set, isNull);
      expect([for (final f in loaded.findings) f.code], ['RF-011']);

      files = approvedReferenceBytes()
        ..[ReleaseReferenceName.equipment] = utf8.encode('{}')
        ..[ReleaseReferenceName.coverage] = utf8.encode('[]');
      loaded = loadApprovedReferenceSet(files);
      expect(loaded.set, isNull);
      expect(
        [for (final f in loaded.findings) f.field],
        ['reference.equipment', 'reference.coverage'],
      );
    });

    test('the approved files load with their hashes', () {
      expect(reference.hashes.keys, ReleaseReferenceName.values);
      expect(reference.anatomy.nodes, hasLength(126));
      expect(reference.patterns.nodes, hasLength(79));
      expect(reference.equipment.items, hasLength(33));
    });
  });

  group('against a previous release (IC-104, IC-105, IC-110, IC-111)', () {
    late ValidatedRelease previous;
    setUpAll(() {
      final map = subsetRelease(['lib-back-squat', 'lib-front-squat']);
      previous = validate(map).release!;
    });

    ReleaseValidation next(Map<String, Object?> map) => validateReleaseBytes(
      bytes: bytesOf(map),
      reference: reference,
      previous: previousCatalogueOf(previous),
    );

    test('the same release again is valid', () {
      final v = next(
        subsetRelease(['lib-back-squat', 'lib-front-squat'], release: 3),
      );
      expect(v.errors, isEmpty);
    });

    test('omitting an id without retiring it is refused (IC-110)', () {
      final v = next(subsetRelease(['lib-back-squat'], release: 3));
      expect(_codes(v), contains('IC-110'));
      expect(v.isValid, isFalse);
    });

    test('listing the id under retirements satisfies the guard', () {
      final map = subsetRelease(['lib-back-squat'], release: 3)
        ..['retirements'] = [
          {'id': 'lib-front-squat', 'reason': 'Merged.'},
        ];
      final v = next(map);
      expect(_codes(v), isNot(contains('IC-110')));
      expect(v.errors, isEmpty);
    });

    test('lowering a revision is refused (IC-104)', () {
      final map = subsetRelease([
        'lib-back-squat',
        'lib-front-squat',
      ], release: 3);
      exercisesOf(map)[0]['revision'] = 2;
      final first = validate(map).release!;
      final map2 = subsetRelease([
        'lib-back-squat',
        'lib-front-squat',
      ], release: 4);
      final v = validateReleaseBytes(
        bytes: bytesOf(map2),
        reference: reference,
        previous: previousCatalogueOf(first),
      );
      expect(_codes(v), contains('IC-104'));
    });

    test('a changed system field at the same revision is refused (IC-105)', () {
      final map = subsetRelease([
        'lib-back-squat',
        'lib-front-squat',
      ], release: 3);
      exercisesOf(map)[0]['difficulty'] = 'advanced';
      final v = next(map);
      expect(_codes(v), contains('IC-105'));
      expect(v.isValid, isFalse);
    });

    test('a changed field with a higher revision is valid', () {
      final map = subsetRelease([
        'lib-back-squat',
        'lib-front-squat',
      ], release: 3);
      exercisesOf(map)[0]
        ..['difficulty'] = 'advanced'
        ..['revision'] = 2;
      expect(next(map).errors, isEmpty);
    });

    test('a retired id returning as active is refused (IC-111)', () {
      final v = validateReleaseBytes(
        bytes: bytesOf(subsetRelease(['lib-back-squat'], release: 3)),
        reference: reference,
        retiredExerciseLedger: {const ExerciseId('lib-back-squat')},
      );
      expect(_codes(v), contains('IC-111'));
    });
  });

  test('tranche status in the file reaches the coverage checks', () {
    final base = validate(release2Map());
    final complete = validate(
      release2Map()..['tranches'] = {'5.1': 'complete'},
    );
    expect(base.report!.tranches, isEmpty);
    expect(complete.report!.tranches, {'5.1': 'complete'});
    expect(complete.errors.length, greaterThanOrEqualTo(base.errors.length));
  });
}
