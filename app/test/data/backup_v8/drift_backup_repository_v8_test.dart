import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_backup_repository.dart';
import 'package:repforge/data/repositories/v8/drift_backup_repository_v8.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/migration_report.dart';

import '../../migration_v8/migration_digest.dart' as digest;
import 'backup_v8_support.dart';

/// WP 8 sub-stage 3b-7: backup format 3 and the restore contract
/// (`docs/backup-format-3.md`).
void main() {
  Map<String, Object?> decode(String json) =>
      jsonDecode(json) as Map<String, Object?>;
  Map<String, Object?> tablesOf(Map<String, Object?> envelope) =>
      envelope['tables']! as Map<String, Object?>;
  List<Map<String, Object?>> rowsOf(
    Map<String, Object?> envelope,
    String t,
  ) => [
    for (final r in tablesOf(envelope)[t]! as List) r as Map<String, Object?>,
  ];
  void addRow(
    Map<String, Object?> envelope,
    String t,
    Map<String, Object?> r,
  ) => (tablesOf(envelope)[t]! as List).add(r);

  AppError errorOf(Result<Object?> r) => switch (r) {
    Ok() => throw StateError('expected an error, got Ok'),
    Err(:final error) => error,
  };

  group('format 3 export', () {
    test('the envelope states format 3, schema 8, the app version, the '
        'export time, the release log and every v8 table', () async {
      await inBackupTempDir((dir) async {
        final v8 = await richV8(await V8File.create(dir));
        try {
          final env = decode(await v8.repo().exportJson());
          expect(env['app'], 'repforge');
          expect(env['formatVersion'], 3);
          expect(env['schemaVersion'], 8);
          expect(env['appVersion'], restoreAppVersion);
          expect(env['exportedAt'], restoreStamp);
          expect(env['releaseLog'], [
            {
              'providerId': 'repforge',
              'release': 1,
              'contentHashAlgorithm': 'sha256',
              'contentHashEncoding': 'hex-lower',
              'contentHash': 'a' * 64,
            },
          ]);
          final names = (await v8.rows(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name "
            "NOT LIKE 'sqlite_%'",
          )).map((r) => r['name']).toSet();
          expect(tablesOf(env).keys.toSet(), names);
          for (final t in names) {
            expect(
              (tablesOf(env)[t]! as List).length,
              await v8.count(t! as String),
              reason: '$t',
            );
          }
        } finally {
          await v8.close();
        }
      });
    });

    test('round trip: a format 3 backup restored into a fresh v8 database '
        'gives equal digests for every table; report history is merged '
        'with backup provenance', () async {
      await inBackupTempDir((dir) async {
        final a = await richV8(await V8File.create(dir, 'a.sqlite'));
        final b = await V8File.create(dir, 'b.sqlite');
        try {
          final json = await a.repo().exportJson();
          final r = await b.repo().importJson(json);
          expect(r, isA<Ok<Object?>>(), reason: '$r');
          final da = a.digests();
          final db = b.digests();
          for (final t in da.keys) {
            if (reportTables.contains(t)) continue;
            expect(tableDigest(db, t), tableDigest(da, t), reason: t);
          }
          // Report history: every entry and count of A, unchanged, plus the
          // restore run's own rows.
          Future<Set<String>> rowsOfTable(V8File f, String t) async => {
            for (final r in await f.rows('SELECT * FROM "$t"')) jsonEncode(r),
          };
          final restoreRun = {
            for (final r in await b.rows(
              'SELECT * FROM migration_report_entries WHERE run_id = '
              "'restore-1'",
            ))
              jsonEncode(r),
          };
          expect(
            (await rowsOfTable(
              b,
              'migration_report_entries',
            )).difference(restoreRun),
            await rowsOfTable(a, 'migration_report_entries'),
          );
          final aRuns = await a.rows('SELECT * FROM migration_runs');
          final bRuns = {
            for (final r in await b.rows('SELECT * FROM migration_runs'))
              r['id']: r,
          };
          final identity = (await b.rows(
            'SELECT provenance_source FROM migration_runs WHERE id = '
            "'restore-1'",
          )).single['provenance_source'];
          for (final run in aRuns) {
            final merged = bRuns[run['id']]!;
            for (final c in [
              'trigger_kind',
              'from_version',
              'to_version',
              'generated_at',
              'app_version',
            ]) {
              expect(merged[c], run[c], reason: '${run['id']} $c');
            }
            if (run['provenance_kind'] == 'device') {
              expect(merged['provenance_kind'], 'backup');
              expect(merged['provenance_source'], identity);
              expect(merged['merged_at'], restoreStamp);
            } else {
              // A run already merged from a backup keeps its provenance.
              expect(merged['provenance_source'], run['provenance_source']);
              expect(merged['merged_at'], run['merged_at']);
            }
          }
          expect(bRuns.length, aRuns.length + 1);
          v8NoForeignKeyViolation(b);
        } finally {
          await a.close();
          await b.close();
        }
      });
    });

    test(
      'restoring a backup of the same device changes no table except the '
      'restore run; repeated restores never duplicate report history',
      () async {
        await inBackupTempDir((dir) async {
          final v8 = await richV8(await V8File.create(dir));
          try {
            final json = await v8.repo().exportJson();
            final before = v8.digests();
            final entriesBefore = await v8.count('migration_report_entries');
            final runBefore = await v8.rows(
              "SELECT * FROM migration_runs WHERE id = 'rich-1'",
            );
            final repo = v8.repo();
            for (var i = 1; i <= 3; i++) {
              final r = await repo.importJson(json);
              expect(r, isA<Ok<Object?>>(), reason: '$r');
              final after = v8.digests();
              for (final t in before.keys) {
                if (reportTables.contains(t)) continue;
                expect(
                  tableDigest(after, t),
                  tableDigest(before, t),
                  reason: t,
                );
              }
              // Only the new restore runs' rows were added.
              final restoreEntries =
                  (await v8.rows(
                        'SELECT count(*) AS c FROM migration_report_entries '
                        "WHERE run_id LIKE 'restore-%'",
                      )).single['c']!
                      as int;
              expect(
                await v8.count('migration_report_entries'),
                entriesBefore + restoreEntries,
              );
              expect(
                (await v8.rows(
                  'SELECT id FROM migration_runs WHERE trigger_kind = '
                  "'restore' AND id LIKE 'restore-%'",
                )).length,
                i,
              );
            }
            // Runs already on the device keep their row unchanged.
            expect(
              await v8.rows("SELECT * FROM migration_runs WHERE id = 'rich-1'"),
              runBefore,
            );
          } finally {
            await v8.close();
          }
        });
      },
    );
  });

  group('restore rejects atomically, nothing changed', () {
    Future<void> rejects(
      String Function(Map<String, Object?> envelope) mutate,
      Matcher message,
    ) async {
      await inBackupTempDir((dir) async {
        final a = await richV8(await V8File.create(dir, 'a.sqlite'));
        final b = await richV8(await V8File.create(dir, 'b.sqlite'));
        try {
          final env = decode(await a.repo().exportJson());
          final json = mutate(env);
          final before = b.digests();
          final repo = b.repo();
          final preview = repo.previewJson(json);
          final result = await repo.importJson(json);
          final error = errorOf(result);
          expect(error, isA<ValidationError>());
          expect(error.message, message);
          expect(error.message, contains('Nothing was changed'));
          expect(b.digests(), before);
          expect(await b.foreignKeys(), 1);
          // A phase 1a error is also the preview's error.
          if (preview is Err<BackupPreview>) {
            expect(preview.error.message, error.message);
          }
        } finally {
          await a.close();
          await b.close();
        }
      });
    }

    test('a conflicting default role (R-20, ADR-0008 E Q8)', () async {
      await rejects((env) {
        for (final r in rowsOf(env, 'equipment_items')) {
          if (r['id'] == 'barbell') r['default_role'] = 'support';
        }
        return jsonEncode(env);
      }, allOf(contains('barbell'), contains('R-20')));
    });

    test('other conflicting immutable reference content: a node parent, a '
        'release hash, a provider of a system exercise', () async {
      await rejects((env) {
        for (final r in rowsOf(env, 'anatomy_nodes')) {
          if (r['id'] == 'chest') r['parent_id'] = 'regionBack';
        }
        return jsonEncode(env);
      }, contains('anatomy_nodes chest: parent_id'));
      await rejects((env) {
        for (final r in rowsOf(env, 'catalogue_releases')) {
          r['content_hash'] = 'b' * 64;
        }
        env['releaseLog'] = [
          for (final r in rowsOf(env, 'catalogue_releases'))
            {
              'providerId': r['provider_id'],
              'release': r['release'],
              'contentHashAlgorithm': r['content_hash_algorithm'],
              'contentHashEncoding': r['content_hash_encoding'],
              'contentHash': r['content_hash'],
            },
        ];
        return jsonEncode(env);
      }, contains('content_hash'));
      await rejects((env) {
        for (final r in rowsOf(env, 'exercises')) {
          if (r['id'] == 'lib-deadlift') r['source'] = 'user';
          if (r['id'] == 'lib-deadlift') r['provider_id'] = null;
          if (r['id'] == 'lib-deadlift') r['revision'] = null;
        }
        return jsonEncode(env);
      }, contains('exercises lib-deadlift: source'));
    });

    test('an invalid IC-315 override (R-19): on a cardio item, and with a '
        'note that is only Unicode white space', () async {
      await rejects((env) {
        addRow(env, 'exercise_equipment', {
          'exercise_id': 'ex-rich',
          'equipment_id': 'treadmill',
          'ordinal': 2,
          'role_override': 'support',
          'override_note': 'A note.',
        });
        return jsonEncode(env);
      }, allOf(contains('treadmill'), contains('IC-315')));
      // U+00A0 passes the SQL trim of the CHECK, not the domain's trim.
      await rejects((env) {
        for (final r in rowsOf(env, 'exercise_equipment')) {
          if (r['exercise_id'] == 'ex-rich' && r['equipment_id'] == 'barbell') {
            r['override_note'] = ' ';
          }
        }
        return jsonEncode(env);
      }, allOf(contains('needs a note'), contains('IC-315')));
    });

    test('invalid v8 values in a format 3 file are rejected, never '
        'quarantined (ADR-0008 E Q15)', () async {
      await rejects((env) {
        rowsOf(env, 'session_sets').first
          ..['exertion_scale'] = 'rpe'
          ..['exertion_value'] = 7.3;
        return jsonEncode(env);
      }, contains('TRN-020'));
      await rejects((env) {
        rowsOf(env, 'exercises').first['grip'] = 'hook';
        return jsonEncode(env);
      }, contains('grip'));
      await rejects((env) {
        rowsOf(env, 'exercises').first['source'] = 'system';
        rowsOf(env, 'exercises').first['provider_id'] = null;
        return jsonEncode(env);
      }, contains("source <> 'system'"));
      await rejects((env) {
        rowsOf(env, 'exercise_blocks').first['reason'] =
            'invalidSecondaryTarget';
        return jsonEncode(env);
      }, contains('reason'));
      await rejects((env) {
        rowsOf(env, 'measurements').first['value'] = '70';
        return jsonEncode(env);
      }, contains('value must be real'));
    });

    test('structure: unknown or missing tables, unknown columns, non-object '
        'rows, duplicate keys, a wrong release log', () async {
      await rejects((env) {
        tablesOf(env)['nonsense'] = [];
        return jsonEncode(env);
      }, contains('unknown table "nonsense"'));
      await rejects((env) {
        tablesOf(env).remove('exercise_names');
        return jsonEncode(env);
      }, contains('missing table "exercise_names"'));
      await rejects((env) {
        rowsOf(env, 'goals').first['colour'] = 'red';
        return jsonEncode(env);
      }, contains('unknown column "colour"'));
      await rejects((env) {
        (tablesOf(env)['settings']! as List).add(3);
        return jsonEncode(env);
      }, contains('is not an object'));
      await rejects((env) {
        final s = rowsOf(env, 'settings');
        (tablesOf(env)['settings']! as List).add(Map.of(s.first));
        return jsonEncode(env);
      }, contains('appears twice'));
      await rejects((env) {
        env['releaseLog'] = [];
        return jsonEncode(env);
      }, contains('release log'));
      await rejects((env) {
        env.remove('appVersion');
        return jsonEncode(env);
      }, contains('app version'));
      await rejects((env) {
        env['schemaVersion'] = 7;
        return jsonEncode(env);
      }, contains('schema version 8'));
    });

    test('report history: a tampered event id, counts that do not '
        'reconcile, the same event id with other content, the same run id '
        'with other content', () async {
      await rejects((env) {
        rowsOf(env, 'migration_report_entries').first['event_id'] = 'f' * 64;
        return jsonEncode(env);
      }, contains('event id does not match'));
      await rejects((env) {
        final c = rowsOf(env, 'migration_report_counts').firstWhere(
          (c) => c['dimension'] == 'category' && c['code'] == 'examined',
        );
        c['record_count'] = (c['record_count']! as int) + 1;
        return jsonEncode(env);
      }, contains('outcomes sum'));
      await rejects((env) {
        rowsOf(env, 'migration_report_entries').first['reason'] = 'Edited.';
        return jsonEncode(env);
      }, contains('same event id, other content'));
      await rejects((env) {
        rowsOf(env, 'migration_runs').first['app_version'] = '9.9.9';
        return jsonEncode(env);
      }, contains('app_version'));
    });

    test('a foreign key to reference data that exists neither in the backup '
        'nor on the device', () async {
      await rejects((env) {
        rowsOf(
          env,
          'exercise_targets',
        ).firstWhere((t) => t['exercise_id'] == 'ex-rich')['node_id'] = 'tail';
        return jsonEncode(env);
      }, contains('no anatomy_nodes row'));
    });
  });

  group('reference and catalogue data: device wins, missing rows inserted '
      '(D04 "Restore conflicts")', () {
    test('a missing reference row is inserted; existing rows are never '
        'overwritten, a mutable difference is reported', () async {
      await inBackupTempDir((dir) async {
        final a = await richV8(await V8File.create(dir, 'a.sqlite'));
        final b = await V8File.create(dir, 'b.sqlite');
        try {
          final env = decode(await a.repo().exportJson());
          addRow(env, 'equipment_items', {
            'id': 'sled',
            'sort_order': 220,
            'default_role': 'load',
            'provider_id': 'repforge',
          });
          for (final r in rowsOf(env, 'equipment_items')) {
            if (r['id'] == 'bench') r['sort_order'] = 999;
          }
          final before = b.digests();
          final r = await b.repo().importJson(jsonEncode(env));
          expect(r, isA<Ok<Object?>>(), reason: '$r');
          final items = {
            for (final row in await b.rows('SELECT * FROM equipment_items'))
              row['id']: row,
          };
          expect(items['sled']!['default_role'], 'load');
          expect(items['bench']!['sort_order'], 90);
          expect(items.length, 22);
          for (final t in ['content_providers', 'anatomy_nodes']) {
            // A fresh device and the backup hold the same bootstrap rows.
            expect(tableDigest(b.digests(), t), tableDigest(before, t));
          }
          final warning = (await b.rows(
            'SELECT * FROM migration_report_entries WHERE run_id = '
            "'restore-1' AND source_table = 'equipment_items'",
          )).single;
          expect(warning['record_id'], 'bench');
          expect(warning['field'], 'sort_order');
          expect(warning['original_value'], '999');
          expect(warning['resulting_value'], '90');
          expect(warning['disposition'], 'retained');
          expect(warning['category'], 'warningForReview');
          expect(warning['rule'], deviceWinsRule);
        } finally {
          await a.close();
          await b.close();
        }
      });
    });

    test('a system exercise on the device wins; its differences are '
        'reported; a v7 backup restores onto a migrated device', () async {
      await inBackupTempDir((dir) async {
        final v8 = await richV8(await V8File.create(dir));
        try {
          // The user archived a supplied exercise after the v7 backup.
          await v8.db.customStatement(
            "UPDATE exercises SET archived = 1 WHERE id = 'lib-deadlift'",
          );
          final r = await v8.repo().importJson(
            readGolden(digest.goldenFormat2Path()),
          );
          expect(r, isA<Ok<Object?>>(), reason: '$r');
          final row = (await v8.rows(
            "SELECT archived FROM exercises WHERE id = 'lib-deadlift'",
          )).single;
          expect(row['archived'], 1);
          final w = (await v8.rows(
            'SELECT * FROM migration_report_entries WHERE run_id = '
            "'restore-1' AND record_id = 'lib-deadlift'",
          )).single;
          expect(w['field'], 'archived');
          expect(w['original_value'], '0');
          expect(w['resulting_value'], '1');
          expect(w['category'], 'warningForReview');
          // User exercises were replaced: the extra one is gone.
          expect(
            await v8.rows("SELECT id FROM exercises WHERE id = 'ex-rich'"),
            isEmpty,
          );
          v8NoForeignKeyViolation(v8);
        } finally {
          await v8.close();
        }
      });
    });
  });

  group('empty, unknown and newer backups', () {
    test('a structurally empty backup is rejected (WP 10 D3); a fresh v8 '
        'export (reference rows only) is empty too', () async {
      await inBackupTempDir((dir) async {
        final v8 = await richV8(await V8File.create(dir));
        final fresh = await V8File.create(dir, 'fresh.sqlite');
        try {
          final settingsOnly = decode(
            readGolden(digest.goldenFormat2SettingsOnlyPath),
          );
          (tablesOf(settingsOnly)['settings']! as List).clear();
          final before = v8.digests();
          for (final json in [
            jsonEncode(settingsOnly),
            await fresh.repo().exportJson(),
            jsonEncode({
              'app': 'repforge',
              'formatVersion': 2,
              'tables': <String, Object?>{},
            }),
          ]) {
            final error = errorOf(await v8.repo().importJson(json));
            expect(error.message, contains('contains no records'));
            expect(errorOf(v8.repo().previewJson(json)).message, error.message);
          }
          expect(v8.digests(), before);
        } finally {
          await v8.close();
          await fresh.close();
        }
      });
    });

    test('unknown and newer formats are rejected', () async {
      await inBackupTempDir((dir) async {
        final v8 = await V8File.create(dir);
        try {
          final before = v8.digests();
          for (final (format, text) in [
            (0, 'unknown format'),
            (-1, 'unknown format'),
            (4, 'newer version'),
            ('3', 'newer version'),
          ]) {
            final json = jsonEncode({
              'app': 'repforge',
              'formatVersion': format,
              'schemaVersion': 8,
              'tables': {
                'settings': [
                  {'key': 'k', 'value': 'v', 'updated_at': restoreStamp},
                ],
              },
            });
            expect(
              errorOf(await v8.repo().importJson(json)).message,
              contains(text),
              reason: '$format',
            );
          }
          for (final json in ['not json', '[]', '{"app":"other"}']) {
            expect(await v8.repo().importJson(json), isA<Err<Object?>>());
          }
          // Format and schema version must pair.
          final f2 = decode(readGolden(digest.goldenFormat2SettingsOnlyPath));
          f2['schemaVersion'] = 8;
          expect(
            errorOf(await v8.repo().importJson(jsonEncode(f2))).message,
            contains('cannot state schema version 8'),
          );
          expect(v8.digests(), before);
        } finally {
          await v8.close();
        }
      });
    });

    test('the production v7 repository refuses a format 3 file and changes '
        'nothing', () async {
      await inBackupTempDir((dir) async {
        final v8 = await richV8(await V8File.create(dir));
        final app = AppDatabase(NativeDatabase.memory());
        try {
          final json = await v8.repo().exportJson();
          final production = DriftBackupRepository(app, clock: restoreClock);
          await production.importJson(
            readGolden(digest.goldenFormat2SettingsOnlyPath),
          );
          final before = await production.exportJson();
          final preview = production.previewJson(json);
          expect(errorOf(preview).message, contains('newer version'));
          final result = await production.importJson(json);
          expect(errorOf(result), isA<ValidationError>());
          expect(errorOf(result).message, contains('newer version'));
          expect(await production.exportJson(), before);
          expect(DriftBackupRepository.formatVersion, 2);
          expect(app.schemaVersion, 7);
        } finally {
          await app.close();
          await v8.close();
        }
      });
    });
  });

  group('atomicity and run ids', () {
    for (final phase in RestorePhase.values) {
      test('a failure at ${phase.name} leaves the database unchanged and '
          'keys on', () async {
        await inBackupTempDir((dir) async {
          final a = await richV8(await V8File.create(dir, 'a.sqlite'));
          final b = await V8File.create(dir, 'b.sqlite');
          try {
            // Data of its own (a v5 backup's custom exercises would be
            // system exercises here and conflict with the backup's).
            await b
                .repo(config: restoreConfig(newRunId: () => 'first'))
                .importJson(readGolden(digest.goldenFormat2SettingsOnlyPath));
            await b.db.customStatement(_sentinelMeasurement);
            final json = await a.repo().exportJson();
            final before = b.digests();
            final result = await b
                .repo(
                  phaseProbe: (p) async {
                    if (p == phase) throw StateError('injected at $p');
                  },
                )
                .importJson(json);
            final error = errorOf(result);
            expect(error, isA<StorageError>());
            expect(error.message, 'Restore failed; nothing was changed.');
            expect('${(error as StorageError).cause}', contains('injected'));
            expect(b.digests(), before);
            expect(await b.foreignKeys(), 1);
            // The same restore then succeeds.
            expect(await b.repo().importJson(json), isA<Ok<Object?>>());
          } finally {
            await a.close();
            await b.close();
          }
        });
      });
    }

    test(
      'a database error inside the transaction rolls back everything',
      () async {
        await inBackupTempDir((dir) async {
          final v8 = await richV8(await V8File.create(dir));
          try {
            final json = await v8.repo().exportJson();
            final before = v8.digests();
            final result = await v8
                .repo(
                  phaseProbe: (p) async {
                    if (p == RestorePhase.userDataInserted) {
                      // A row that breaks a constraint the mirror cannot see.
                      await v8.db.customStatement(
                        'INSERT INTO settings (key, value, updated_at) VALUES '
                        "('units', 'x', 'y')",
                      );
                    }
                  },
                )
                .importJson(json);
            expect(errorOf(result), isA<StorageError>());
            expect(v8.digests(), before);
            expect(await v8.foreignKeys(), 1);
          } finally {
            await v8.close();
          }
        });
      },
    );

    test('every restore gets a new run id; an id already recorded is '
        'refused before any write; no migration ledger is involved', () async {
      await inBackupTempDir((dir) async {
        final v8 = await V8File.create(dir);
        try {
          final json = readGolden(digest.goldenFormat2Path());
          final repo = v8.repo();
          expect(await repo.importJson(json), isA<Ok<Object?>>());
          expect(await repo.importJson(json), isA<Ok<Object?>>());
          expect(
            (await v8.rows(
              "SELECT id FROM migration_runs WHERE trigger_kind = 'restore' "
              'ORDER BY id',
            )).map((r) => r['id']),
            ['restore-1', 'restore-2'],
          );
          final before = v8.digests();
          final again = await v8
              .repo(config: restoreConfig(newRunId: () => 'restore-1'))
              .importJson(json);
          expect(errorOf(again), isA<StorageError>());
          expect(v8.digests(), before);
        } finally {
          await v8.close();
        }
      });
    });

    test(
      'the restore report reconciles and a re-export validates it',
      () async {
        await inBackupTempDir((dir) async {
          final v8 = await V8File.create(dir);
          try {
            for (final (_, path) in digest.allGoldens()) {
              if (path.contains('orphans')) continue;
              await v8
                  .repo(
                    config: restoreConfig(
                      newRunId: countingRestoreIds(path.split('/').last),
                    ),
                  )
                  .importJson(readGolden(path));
            }
            // The export passes the format 3 validation: event ids, counts.
            final json = await v8.repo().exportJson();
            expect(v8.repo().previewJson(json), isA<Ok<BackupPreview>>());
            final counts = await v8.rows(
              'SELECT run_id, source_table, dimension, code, record_count '
              'FROM migration_report_counts',
            );
            final entries = await v8.rows(
              'SELECT run_id, source_table, disposition FROM '
              'migration_report_entries',
            );
            for (final c in counts) {
              if (c['dimension'] != 'disposition') continue;
              final n = entries
                  .where(
                    (e) =>
                        e['run_id'] == c['run_id'] &&
                        e['source_table'] == c['source_table'] &&
                        e['disposition'] == c['code'],
                  )
                  .length;
              expect(c['record_count'], n, reason: '$c');
            }
            expect(
              entries.where((e) => e['disposition'] == 'blocked'),
              isNotEmpty,
            );
            expect(ReportAction.values.map((a) => a.name), contains('blocked'));
          } finally {
            await v8.close();
          }
        });
      },
    );
  });
}

void v8NoForeignKeyViolation(V8File f) => f.readOnly((db) {
  expect(digest.foreignKeyViolations(db), isEmpty);
  expect(digest.integrityCheck(db), 'ok');
});

const String _stamp = restoreStamp;

const _sentinelMeasurement =
    'INSERT INTO measurements (id, created_at, updated_at, site, value, '
    "recorded_at) VALUES ('sentinel', '$_stamp', '$_stamp', 'weight', 70.0, "
    "'$_stamp')";
