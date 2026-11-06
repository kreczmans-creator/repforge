@Tags(['heavy'])
@Timeout(Duration(minutes: 10))
library;

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../harness_v7_db.dart';
import '../recovery/migration_under_test.dart';
import '../recovery/recovery_tools.dart';
import '../recovery/v7_expectations.dart';
import 'large_profile.dart';

/// WP 8 3b-9 (3B-ACC-01, WS5): the large realistic profile.
///
/// - The D04 profile (5,000 exercises, 100,000 sets) is built through the
///   frozen v7 schema; its schema equals the frozen production v7 record.
/// - Every profile element is measured on the file, not assumed: 303
///   exercises without a mappable primary, unknown and duplicate equipment,
///   invalid TRN-020 values, supplied exercises, loose references.
/// - Building is deterministic (same seed, same state).
/// - The v5 variant holds the same rows and migrates through the historical
///   chain to v7 (the stand-in input of the timing and random kill runs).
///
/// Tag `heavy`, skipped by default.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final report = <String, Object?>{};

  tearDownAll(() {
    final f = writeWs5Report('large_profile', report);
    // ignore: avoid_print, the heavy suite reports through the test log
    print('LARGE_PROFILE_REPORT ${f.path}');
  });

  for (final (label, spec) in const [
    ('d04', LargeProfileSpec.d04()),
    ('smoke', LargeProfileSpec.smoke()),
  ]) {
    test('$label profile at v7: exact elements, frozen v7 schema, '
        'deterministic', () async {
      await withWs5TempDir((dir) async {
        final a = '${dir.path}/a.sqlite';
        final facts = await buildLargeProfile(a, spec: spec);
        final measured = measureV7Profile(a);
        expect(measured, {
          'exercises': spec.exercises,
          'sets': spec.sets,
          'noPrimary': spec.noPrimary,
          'unknownEquipment': spec.unknownEquipment,
          'duplicateEquipment': spec.duplicateEquipment,
          'invalidExertion': spec.invalidExertion,
          'supplied': spec.supplied,
          'setsWithMissingExercise': measured['setsWithMissingExercise'],
          'setsWithoutEntry': 0,
          'foreignKeyViolations': 0,
        });
        expect(
          measured['setsWithMissingExercise'],
          greaterThan(0),
          reason: 'loose references present',
        );
        final db = sqlite3.open(a, mode: OpenMode.readOnly);
        try {
          expect(
            strictOnly(strictSchemaRecord(db)),
            frozenStrictRecord('fresh'),
          );
          expect(db.select('PRAGMA user_version').first.values.first, 7);
        } finally {
          db.close();
        }
        final digest = stateDigest(File(a));
        expect(digest.integrity, 'ok');
        for (final t in facts.counts.keys) {
          if (t == 'legacy_quarantine') continue;
          expect(facts.counts[t], greaterThan(0), reason: '$t has rows');
        }

        final b = '${dir.path}/b.sqlite';
        await buildLargeProfile(b, spec: spec);
        expect(stateDigest(File(b)), digest, reason: 'deterministic');

        report['${label}_v7'] = {
          ...facts.toJson(),
          'measured': measured,
          'digest': digest.toString(),
        };
      });
    });

    test('$label profile at v5: same rows, migrates to v7 through the '
        'historical chain', () async {
      await withWs5TempDir((dir) async {
        final v7 = '${dir.path}/v7.sqlite';
        final v7Facts = await buildLargeProfile(v7, spec: spec);
        final v5 = File('${dir.path}/v5.sqlite');
        final v5Facts = await buildLargeProfile(
          v5.path,
          spec: spec,
          version: 5,
        );
        for (final t in v5Facts.counts.keys) {
          expect(v5Facts.counts[t], v7Facts.counts[t], reason: t);
        }
        expect(stateDigest(v5).userVersion, 5);

        final watch = Stopwatch()..start();
        expect(await runMigration(v5, historicalChain), isNull);
        watch.stop();
        final migrated = stateDigest(v5);
        expect(migrated.userVersion, 7);
        expect(migrated.integrity, 'ok');
        expect(migrated.foreignKeyViolations, 0);
        final db = sqlite3.open(v5.path, mode: OpenMode.readOnly);
        try {
          expect(
            strictOnly(strictSchemaRecord(db)),
            frozenStrictRecord('fresh'),
          );
          int count(String t) =>
              db.select('SELECT count(*) AS c FROM "$t"').first['c']! as int;
          expect(count('session_sets'), spec.sets);
          expect(count('exercises'), spec.exercises);
          expect(
            db
                .select(
                  'SELECT count(*) AS c FROM session_sets '
                  'WHERE session_exercise_id IS NULL',
                )
                .first['c'],
            0,
          );
          report['${label}_v5'] = {
            ...v5Facts.toJson(),
            'migratedToV7': {
              'ms': watch.elapsedMilliseconds,
              'bytes': v5.lengthSync(),
              'digest': migrated.toString(),
              'legacyQuarantineRows': count('legacy_quarantine'),
              'sessionExercises': count('session_exercises'),
            },
          };
        } finally {
          db.close();
        }
      });
    });
  }
}
