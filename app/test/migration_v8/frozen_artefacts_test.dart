import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

import 'migration_digest.dart';

/// SHA-256 of `fixtures/MANIFEST.sha256` itself (the manifest cannot list
/// itself). Recorded in `docs/delivery-record/WP8.md`. Changing the
/// manifest means changing frozen evidence.
const manifestSha256 =
    '70ecff92a46dece32493f526482915b56fdd3bf1797f696a4b750d4100805a10';

/// Guards the frozen v8 migration evidence (WP 8 stage 3b-1): fixtures,
/// golden backups, the expected result of the current production migration
/// and restore, and the schema snapshots. Nothing here may be regenerated to
/// make a test pass; see `fixtures/README.md`.
void main() {
  // Every helper opens its own short-lived AppDatabase on a temp file.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Map<String, String> manifest() {
    final out = <String, String>{};
    for (final line in File(manifestPath).readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      final at = line.indexOf('  ');
      out[line.substring(at + 2)] = line.substring(0, at);
    }
    return out;
  }

  Map<String, Object?> expectedFile() =>
      jsonDecode(File(expectedDigestsPath).readAsStringSync())
          as Map<String, Object?>;

  /// The migration and restore expectations describe the v7 production
  /// gate. When production moves to schema 8 these groups cannot hold any
  /// more; see the hand-over section of `fixtures/README.md`.
  Future<void> requireV7Gate() async {
    final probe = AppDatabase(NativeDatabase.memory());
    final version = probe.schemaVersion;
    await probe.close();
    if (version != 7) {
      fail(
        'AppDatabase.schemaVersion is $version. The frozen expectations '
        '(expected_v7_digests.json) describe the schema v7 production '
        'migration and restore. Do not edit or regenerate them: keep them as '
        'the record of the v7 gate, add expected_v8_digests.json for the '
        'new migration, and move or retire this group (fixtures/README.md, '
        '"Hand-over to v8").',
      );
    }
  }

  group('manifest', () {
    test('MANIFEST.sha256 itself is pinned', () {
      expect(sha256OfFile(manifestPath), manifestSha256);
    });

    test('every frozen file has the recorded SHA-256', () {
      final recorded = manifest();
      expect(recorded, isNotEmpty);
      final changed = <String>[];
      for (final entry in recorded.entries) {
        final file = File(entry.key);
        if (!file.existsSync() || sha256OfFile(entry.key) != entry.value) {
          changed.add(entry.key);
        }
      }
      expect(changed, isEmpty, reason: 'frozen file(s) changed or missing');
    });

    test('lists every fixture, golden backup, digest file and schema', () {
      final recorded = manifest().keys.toSet();
      final expected = {
        for (final (_, p) in allFixtures()) p,
        for (final (_, p) in allGoldens()) p,
        expectedDigestsPath,
        for (var v = 1; v <= 7; v++) 'drift_schemas/drift_schema_v$v.json',
        for (var v = 1; v <= 7; v++)
          'test/data/generated_migrations/schema_v$v.dart',
      };
      expect(recorded, expected);
      // A file added to the evidence directory must be added to the manifest.
      final onDisk = Directory(fixturesDir)
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where(
            (p) =>
                p.endsWith('.sqlite') ||
                p.contains('/golden_') ||
                p.contains('/expected_'),
          );
      expect(recorded, containsAll(onDisk));
    });

    test('sha256 implementation matches the known test vectors', () {
      expect(
        sha256Hex(const <int>[]),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });
  });

  group('normaliseSql', () {
    test('ignores identifier quotes and spacing around operators', () {
      expect(
        normaliseSql('"completed" IN (0, 1)'),
        normaliseSql('completed IN (0, 1)'),
      );
      expect(
        normaliseSql('(energy_kcal IS NULL) = (energy_provenance IS NULL)'),
        normaliseSql('(energy_kcal IS NULL)=(energy_provenance IS NULL)'),
      );
      expect(
        normaliseSql('REFERENCES foods(id)ON DELETE CASCADE'),
        normaliseSql('REFERENCES foods (id) ON DELETE CASCADE'),
      );
    });

    test('still tells real differences apart', () {
      expect(
        normaliseSql('reps BETWEEN 1 AND 100'),
        isNot(normaliseSql('reps BETWEEN 1 AND 99')),
      );
      expect(normaliseSql('a <= b'), isNot(normaliseSql('a < b')));
    });
  });

  group('fixtures', () {
    for (final (key, path) in allFixtures()) {
      final orphans = key.endsWith('_orphans');
      final v = int.parse(key.substring(1).split('_').first);
      test('fixture_$key has user_version $v and the schema_v$v schema, '
          '${orphans ? "with" : "without"} foreign-key violations', () async {
        final db = sqlite3.open(path, mode: OpenMode.readOnly);
        try {
          expect(userVersion(db), v);
          expect(
            jsonEncode(describeSchema(db)),
            jsonEncode(await freshSchemaDescription(v)),
          );
          expect(integrityCheck(db), 'ok');
          if (orphans) {
            expect(foreignKeyViolations(db), isNotEmpty);
          } else {
            expect(foreignKeyViolations(db), isEmpty);
          }
        } finally {
          db.close();
        }
      });
    }
  });

  group('golden backups', () {
    for (final orphans in [false, true]) {
      for (final v in goldenFormat1Versions) {
        test('format 1 from v$v${orphans ? " (orphans)" : ""} is what the era '
            'exporter writes', () async {
          expect(eraTableOrder[v], await generatedTableOrder(v));
          final db = sqlite3.open(
            fixturePath(v, orphans: orphans),
            mode: OpenMode.readOnly,
          );
          try {
            expect(
              File(goldenFormat1Path(v, orphans: orphans)).readAsStringSync(),
              '${exportFormat1(db, v)}\n',
            );
          } finally {
            db.close();
          }
          final json = jsonDecode(
            File(goldenFormat1Path(v, orphans: orphans)).readAsStringSync(),
          ) as Map<String, Object?>;
          expect(json['formatVersion'], 1);
          expect(json['schemaVersion'], v);
          expect(json['app'], 'repforge');
        });
      }
    }

    group('written by the production exporter (schema v7 gate)', () {
      setUpAll(requireV7Gate);

      for (final orphans in [false, true]) {
        test('format 2 from v7${orphans ? " (orphans)" : ""}', () async {
          expect(
            File(goldenFormat2Path(orphans: orphans)).readAsStringSync(),
            '${await exportFormat2FromFixture(orphans: orphans)}\n',
          );
          final json = jsonDecode(
            File(goldenFormat2Path(orphans: orphans)).readAsStringSync(),
          ) as Map<String, Object?>;
          expect(json['formatVersion'], 2);
          expect(json['schemaVersion'], 7);
        });
      }

      test('settings-only backups hold rows only in settings', () {
        for (final (path, format) in [
          (goldenFormat1SettingsOnlyPath, 1),
          (goldenFormat2SettingsOnlyPath, 2),
        ]) {
          final json =
              jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
          expect(json['formatVersion'], format);
          final tables = json['tables']! as Map<String, Object?>;
          final filled = [
            for (final e in tables.entries)
              if ((e.value! as List).isNotEmpty) e.key,
          ];
          expect(filled, ['settings']);
          final keys = [
            for (final r in tables['settings']! as List)
              (r as Map<String, Object?>)['key'],
          ];
          expect(keys, containsAll(['units', 'exertionScale', 'mealLabels']));
          expect(keys, contains('seedExercisesVersion'));
        }
      });
    });
  });

  group('production restore (importJson) of every golden backup', () {
    setUpAll(requireV7Gate);
    final restores = expectedFile()['restores']! as Map<String, Object?>;

    for (final (key, path) in allGoldens()) {
      final orphans = key.endsWith('_orphans');
      test(
        '$key ${orphans ? "is rejected atomically" : "restores cleanly"}',
        () async {
          final want = restores[key]! as Map<String, Object?>;
          final got = await restoreOutcome(File(path).readAsStringSync());
          if (orphans) {
            // A foreign-key orphan fails the restore; nothing is changed.
            expect(got['restored'], isFalse);
            expect(got['failedOnForeignKey'], isTrue);
            expect(got['databaseUnchanged'], isTrue);
          } else {
            expect(got['restored'], isTrue);
            expect(got['foreignKeyViolations'], isEmpty);
          }
          expect(jsonEncode(got), jsonEncode(want));
        },
      );
    }
  });

  group('production migration to v7', () {
    setUpAll(requireV7Gate);
    final expected = expectedFile()['fixtures']! as Map<String, Object?>;
    final hashesBefore = {
      for (final (key, path) in allFixtures()) key: sha256OfFile(path),
    };
    final tempBefore = _tempEntries();

    for (final (key, path) in allFixtures()) {
      test('fixture_$key migrates to the recorded result', () async {
        final want = expected[key]! as Map<String, Object?>;
        final got = await migrateWithProduction(path);
        expect(got['migrated'], want['migrated'], reason: '${got['error']}');
        expect(got['userVersion'], want['userVersion']);
        expect(got['integrityCheck'], want['integrityCheck']);
        expect(
          got['foreignKeyViolationsBefore'],
          want['foreignKeyViolationsBefore'],
        );
        expect(got['foreignKeyViolations'], want['foreignKeyViolations']);
        expect(
          jsonEncode(got['schema']),
          jsonEncode(want['schema']),
          reason: 'schema after migration',
        );
        final gotTables = got['tables']! as Map<String, Object?>;
        final wantTables = want['tables']! as Map<String, Object?>;
        expect(gotTables.keys.toList(), wantTables.keys.toList());
        final different = <String>[];
        for (final t in wantTables.keys) {
          if (jsonEncode(gotTables[t]) != jsonEncode(wantTables[t])) {
            different.add(t);
          }
        }
        expect(different, isEmpty, reason: 'tables with different rows');
        if (!key.endsWith('_orphans')) {
          // A clean database stays clean through every upgrade path.
          expect(got['foreignKeyViolations'], isEmpty);
        }
      });
    }

    test('fixtures are untouched and no temporary file is left', () {
      for (final (key, path) in allFixtures()) {
        expect(sha256OfFile(path), hashesBefore[key]);
        // SQLite side files would show the fixture was opened for writing.
        expect(File('$path-journal').existsSync(), isFalse);
        expect(File('$path-wal').existsSync(), isFalse);
      }
      expect(_tempEntries().difference(tempBefore), isEmpty);
    });
  });
}

Set<String> _tempEntries() => {
  for (final e in Directory.systemTemp.listSync())
    if (e.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .last
        .startsWith(tempPrefix))
      e.path,
};
