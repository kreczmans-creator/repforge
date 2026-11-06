import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_backup_repository.dart';
import 'package:repforge/data/repositories/v8/backup_restore_plan_v8.dart';
import 'package:repforge/data/repositories/v8/drift_backup_repository_v8.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/sha256_hex.dart';

import '../../migration_v8/migration_digest.dart' as digest;
import '../../migration_v8/v8_migration_support.dart' as mig;
import 'backup_v8_support.dart';

/// WP 8 sub-stage 3b-7: every frozen golden backup (format 1 of schema v2 to
/// v7, format 2 of v7, settings-only, and the orphan variants) restored into
/// schema v8.
///
/// The expectation for a clean golden is computed **independently of the
/// restore code**: the golden is restored with the production v7
/// `DriftBackupRepository` (the v7 restore contract) into a v7 file, which
/// the v7 → v8 migration then upgrades (3b-4, the same mapping rules). The
/// v8 restore must give exactly that database, except for what is a restore
/// and not a migration: the run ids and their provenance, and release 1
/// (register B-07). The frozen goldens are read, never written.
void main() {
  final clean = [
    for (final (key, path) in digest.allGoldens())
      if (!key.contains('orphans')) (key, path),
  ];
  final orphans = [
    for (final (key, path) in digest.allGoldens())
      if (key.contains('orphans')) (key, path),
  ];

  test('all 16 frozen goldens are covered', () {
    expect(clean.length + orphans.length, 16);
    expect(orphans.length, 7);
  });

  group('clean goldens restore into v8 exactly as production restore + '
      'the v7 -> v8 migration', () {
    for (final (key, path) in clean) {
      test(key, () async {
        await inBackupTempDir((dir) async {
          final json = readGolden(path);
          final expected = await _productionThenMigration(json, dir);

          final v8 = await V8File.create(dir, 'restored.sqlite');
          try {
            final refBefore = v8.digests();
            final result = await v8.repo().importJson(json);
            expect(result, isA<Ok<Object?>>(), reason: '$result');
            expect(await v8.foreignKeys(), 1);
            final after = v8.digests();
            // Reference tables: not changed by a v7 backup (bootstrap rows
            // already on the device win); the release log may gain release
            // 1 (B-07, checked below).
            for (final t in referenceTables) {
              if (t == 'catalogue_releases') continue;
              expect(
                tableDigest(after, t),
                tableDigest(refBefore, t),
                reason: t,
              );
            }
            v8.readOnly((db) {
              expect(digest.foreignKeyViolations(db), isEmpty);
              expect(digest.integrityCheck(db), 'ok');
            });
          } finally {
            await v8.close();
          }
          final actual = mig.DbState.read(File('${dir.path}/restored.sqlite'));

          // Every user, exercise and reference table equals the oracle.
          for (final table in expected.tables.keys) {
            if (reportTables.contains(table)) {
              continue;
            }
            expect(
              _normalised(table, actual.rows(table)),
              _normalised(table, expected.rows(table)),
              reason: table,
            );
          }
          expect(actual.columns, expected.columns);

          // Release 1 follows the migration's rule (B-07 / R-30 option b,
          // decided): the bundled seed matches the v7-era hash, so a backup
          // whose seed was applied records it, counts NULL, source stated.
          final seeded = actual
              .rows('settings')
              .any(
                (r) =>
                    r['key'] == 'seedExercisesVersion' &&
                    (int.tryParse('${r['value']}') ?? 0) >= 1,
              );
          expect(actual.rows('catalogue_releases'), hasLength(seeded ? 1 : 0));
          for (final r in actual.rows('catalogue_releases')) {
            expect(r['inserted'], isNull);
            expect(r['updated'], isNull);
            expect(r['retired'], isNull);
            expect(r['applied_at_source'], 'seedExercisesVersion.updated_at');
          }

          // The restore run equals the migration run, entries and counts.
          final runs = actual.rows('migration_runs');
          final restoreRun = runs.singleWhere((r) => r['id'] == 'restore-1');
          expect(restoreRun['trigger_kind'], 'restore');
          expect(restoreRun['provenance_kind'], 'backup');
          expect(
            restoreRun['provenance_source'],
            'sha256:${sha256Hex(utf8.encode(json))}',
          );
          expect(restoreRun['merged_at'], restoreStamp);
          expect(restoreRun['generated_at'], restoreStamp);
          expect(restoreRun['app_version'], restoreAppVersion);
          expect(restoreRun['to_version'], 8);
          expect(
            restoreRun['from_version'],
            (jsonDecode(json) as Map)['schemaVersion'],
          );
          expect(_entries(actual, 'restore-1'), _entries(expected, 'run-1'));
          expect(_counts(actual, 'restore-1'), _counts(expected, 'run-1'));
          // Unresolved exercise references: the migration's integrity run
          // and the restore's (only written when there is a finding).
          expect(
            _entries(actual, 'restore-1:integrity'),
            _entries(expected, 'run-1:integrity'),
          );
          expect(runs.map((r) => r['id']).toSet(), {
            'restore-1',
            if (_entries(expected, 'run-1:integrity').isNotEmpty)
              'restore-1:integrity',
          });
        });
      });
    }
  });

  group('orphan goldens are rejected as a whole, as production rejects '
      'them (atomic, nothing changed)', () {
    for (final (key, path) in orphans) {
      test(key, () async {
        await inBackupTempDir((dir) async {
          final v8 = await V8File.create(dir);
          try {
            await v8.db.customStatement(
              'INSERT INTO measurements (id, created_at, updated_at, site, '
              "value, recorded_at) VALUES ('sentinel', '$restoreStamp', "
              "'$restoreStamp', 'weight', 70.0, '$restoreStamp')",
            );
            final before = v8.digests();
            final result = await v8.repo().importJson(readGolden(path));
            final error = (result as Err<Object?>).error;
            expect(error, isA<ValidationError>());
            expect(error.message, contains('parent record is missing'));
            expect(error.message, contains('Nothing was changed'));
            expect(v8.digests(), before);
            expect(await v8.foreignKeys(), 1);
            // The production v7 restore rejects the same file.
            final outcome = await digest.restoreOutcome(readGolden(path));
            expect(outcome['restored'], isFalse);
          } finally {
            await v8.close();
          }
        });
      });
    }
  });

  test('settings-only goldens are accepted; their preview counts only '
      'settings', () async {
    await inBackupTempDir((dir) async {
      final v8 = await V8File.create(dir);
      try {
        final repo = v8.repo();
        for (final path in [
          digest.goldenFormat1SettingsOnlyPath,
          digest.goldenFormat2SettingsOnlyPath,
        ]) {
          final json = readGolden(path);
          final preview = repo.previewJson(json);
          final counts = (preview as Ok<BackupPreview>).value.rowCounts;
          expect(counts.values.fold(0, (a, b) => a + b), counts['settings']);
          final result = await repo.importJson(json);
          expect(result, isA<Ok<Object?>>(), reason: _describe(result));
          final tables = (jsonDecode(json) as Map)['tables'] as Map;
          expect(
            await v8.count('settings'),
            (tables['settings'] as List).length,
          );
        }
      } finally {
        await v8.close();
      }
    });
  });

  test('preview counts equal what production preview counts for every '
      'golden', () async {
    final app = AppDatabase(NativeDatabase.memory());
    await inBackupTempDir((dir) async {
      final v8 = await V8File.create(dir);
      try {
        final production = DriftBackupRepository(
          app,
          clock: FixedClock(DateTime.parse(digest.goldenExportedAt)),
        );
        for (final (key, path) in clean) {
          final json = readGolden(path);
          final p7 = (production.previewJson(json) as Ok<BackupPreview>).value;
          final p8 = (v8.repo().previewJson(json) as Ok<BackupPreview>).value;
          expect(p8.formatVersion, p7.formatVersion, reason: key);
          expect(p8.exportedAt, p7.exportedAt, reason: key);
          final c7 = {
            for (final MapEntry(:key, :value) in p7.rowCounts.entries)
              if (value != 0) key: value,
          };
          final c8 = {
            for (final MapEntry(:key, :value) in p8.rowCounts.entries)
              if (value != 0) key: value,
          };
          expect(c8, c7, reason: key);
        }
      } finally {
        await v8.close();
        await app.close();
      }
    });
  });

  test('every clean golden onto a device migrated from each fixture '
      '(63 combinations) restores; in the 12 combinations where an id is a '
      'system exercise on the device and a user exercise in the backup, '
      'field-level ownership decides (B-01, decided)', () async {
    final classified = <String>{};
    for (final fv in digest.fixtureVersions) {
      for (final (key, path) in clean) {
        await inBackupTempDir((dir) async {
          final file = mig.copyFixture(digest.fixturePath(fv), dir);
          expect(await mig.openV8(file), isNull);
          final v8 = await V8File.open(file);
          try {
            final deviceRows = {
              for (final r in await v8.rows('SELECT * FROM exercises'))
                r['id']: r,
            };
            final json = readGolden(path);
            final result = await v8.repo().importJson(json);
            expect(result, isA<Ok<Object?>>(), reason: '$fv $key $result');
            v8.readOnly(
              (db) => expect(digest.foreignKeyViolations(db), isEmpty),
            );
            expect(await v8.foreignKeys(), 1);
            final backup = {
              for (final r in planRestore(json).exercises) r.id: r.row,
            };
            final after = {
              for (final r in await v8.rows('SELECT * FROM exercises'))
                r['id']: r,
            };
            for (final MapEntry(key: id, value: device) in deviceRows.entries) {
              final b = backup[id];
              if (device['source'] != 'system' || b == null) continue;
              // A system exercise on the device: its catalogue fields stay,
              // its user fields (archived, deleted_at) come from the backup.
              final now = after[id]!;
              for (final c in device.keys) {
                expect(
                  now[c],
                  userOwnedExerciseColumns.contains(c) ? b[c] : device[c],
                  reason: '$fv $key $id.$c',
                );
              }
              if (b['source'] != 'system') {
                classified.add('v$fv <- $key');
                // The classification difference is reported, never a
                // rejection.
                final w = await v8.rows(
                  'SELECT * FROM migration_report_entries WHERE run_id = '
                  "'restore-1' AND record_id = '$id' AND field = 'source'",
                );
                expect(w, hasLength(1), reason: '$fv $key $id');
                expect(w.single['original_value'], '"user"');
                expect(w.single['resulting_value'], '"system"');
                expect(w.single['rule'], deviceWinsRule);
              }
            }
          } finally {
            await v8.close();
          }
        });
      }
    }
    // Fixtures v2 to v5 hold the custom exercises as pre-v6 rows with
    // is_custom 0, which the v6 step maps to supplied (system); the v6 and
    // v7 era goldens hold the same ids as user exercises.
    expect(classified, {
      for (final v in [2, 3, 4, 5])
        for (final g in ['format1_v6', 'format1_v7', 'format2_v7']) 'v$v <- $g',
    });
  });

  test('every clean golden plans without error and its report events are '
      'the mapping events (pure phase 1)', () {
    for (final (key, path) in clean) {
      final plan = planRestore(readGolden(path));
      expect(plan.isLegacy, isTrue, reason: key);
      expect(
        plan.backupIdentity,
        'sha256:${digest.sha256OfFile(path)}',
        reason: key,
      );
    }
  });
}

String _describe(Result<Object?> r) => switch (r) {
  Ok() => 'ok',
  Err(:final error) =>
    '${error.message} ${error is StorageError ? error.cause : ''}',
};

/// The oracle: production v7 restore into a fresh v7 file, then the v7 → v8
/// migration of that file (run id `run-1`, the same clock).
Future<mig.DbState> _productionThenMigration(String json, Directory dir) async {
  final file = File('${dir.path}/oracle.sqlite');
  final app = AppDatabase(NativeDatabase(file));
  try {
    final r = await DriftBackupRepository(
      app,
      clock: restoreClock,
    ).importJson(json);
    expect(r, isA<Ok<Object?>>(), reason: 'production restore: $r');
  } finally {
    await app.close();
  }
  final error = await mig.openV8(file);
  expect(error, isNull, reason: 'migration: $error');
  return mig.DbState.read(file);
}

final _isoUtc = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$');

/// Rows as typed cells; the wall-clock stamp production restore writes on a
/// pre-v6 quarantine row is the only value normalised (as in the frozen
/// digests).
List<Map<String, String>> _normalised(
  String table,
  List<Map<String, Object?>> rows,
) => [
  for (final r in rows)
    {
      for (final MapEntry(:key, :value) in r.entries)
        key:
            table == 'legacy_quarantine' &&
                key == 'quarantined_at' &&
                value is String &&
                _isoUtc.hasMatch(value) &&
                !value.startsWith(digest.fixtureQuarantineStampPrefix)
            ? '<stamp>'
            : mig.typed(value),
    },
];

/// Entries of [runId] without their run-derived ids, sorted.
List<String> _entries(mig.DbState s, String runId) => [
  for (final r in s.rows('migration_report_entries'))
    if (r['run_id'] == runId)
      jsonEncode([
        for (final c in [
          'source_table',
          'record_id',
          'exercise_id',
          'field',
          'position',
          'original_value',
          'resulting_value',
          'element',
          'disposition',
          'block_reason',
          'rule',
          'reason',
          'category',
          'quarantine_id',
          'acknowledged_at',
        ])
          r[c],
      ]),
]..sort();

List<String> _counts(mig.DbState s, String runId) => [
  for (final r in s.rows('migration_report_counts'))
    if (r['run_id'] == runId)
      [
        r['source_table'],
        r['dimension'],
        r['code'],
        r['record_count'],
      ].join('|'),
]..sort();
