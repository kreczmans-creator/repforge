import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_backup_repository.dart';
import 'package:repforge/data/repositories/v8/backup_schema_v8.dart';
import 'package:repforge/data/repositories/v8/drift_backup_repository_v8.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/library/sha256_hex.dart';

import '../../migration_v8/migration_digest.dart' as digest;
import '../../migration_v8/v8_migration_support.dart' as mig;
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

    // Review H1: validateExercise on every exercise a format 3 restore
    // inserts, against the composed reference data.
    Future<void> accepts(
      String Function(Map<String, Object?> envelope) mutate,
    ) async {
      await inBackupTempDir((dir) async {
        final a = await richV8(await V8File.create(dir, 'a.sqlite'));
        final b = await richV8(await V8File.create(dir, 'b.sqlite'));
        try {
          final env = decode(await a.repo().exportJson());
          final result = await b.repo().importJson(mutate(env));
          expect(result, isA<Ok<Object?>>(), reason: '$result');
        } finally {
          await a.close();
          await b.close();
        }
      });
    }

    Map<String, Object?> exRichPrimary(Map<String, Object?> env) =>
        rowsOf(env, 'exercise_targets').firstWhere(
          (t) => t['exercise_id'] == 'ex-rich' && t['role'] == 'primary',
        );

    void dropPrimary(Map<String, Object?> env, String id) {
      (tablesOf(env)['exercise_targets']! as List).removeWhere(
        (t) => (t as Map)['exercise_id'] == id && t['role'] == 'primary',
      );
      var i = 0;
      for (final t in rowsOf(env, 'exercise_targets')) {
        if (t['exercise_id'] == id) t['ordinal'] = i++;
      }
    }

    Map<String, Object?> block(String id, {String? resolvedAt}) => {
      'exercise_id': id,
      'reason': 'noPrimaryTarget',
      'original_json': '{}',
      'blocked_at': restoreStamp,
      'resolved_at': resolvedAt,
    };

    test('H1 probe (a): a user exercise without a primary target and '
        'without a block row (IC-204)', () async {
      await rejects((env) {
        dropPrimary(env, 'ex-rich');
        return jsonEncode(env);
      }, allOf(contains('ex-rich'), contains('IC-204')));
    });

    test(
      'H1 probe (b): target ordinals that are not contiguous (IC-309)',
      () async {
        await rejects((env) {
          for (final t in rowsOf(env, 'exercise_targets')) {
            if (t['exercise_id'] == 'ex-rich' && t['role'] == 'secondary') {
              t['ordinal'] = 7;
            }
          }
          return jsonEncode(env);
        }, allOf(contains('ex-rich'), contains('IC-309')));
      },
    );

    test(
      'H1 probe (c): a target and its ancestor on one exercise (IC-303)',
      () async {
        await rejects((env) {
          final chest = rowsOf(
            env,
            'anatomy_nodes',
          ).firstWhere((n) => n['id'] == exRichPrimary(env)['node_id']);
          addRow(env, 'exercise_targets', {
            'exercise_id': 'ex-rich',
            'node_id': chest['parent_id'],
            'role': 'secondary',
            'ordinal': 2,
          });
          return jsonEncode(env);
        }, allOf(contains('ex-rich'), contains('IC-303')));
      },
    );

    test('H1 probe (d): a system exercise new to the device without targets '
        '(IC-204; a new system exercise needs a primary target)', () async {
      await rejects((env) {
        final copy = Map<String, Object?>.of(
          rowsOf(env, 'exercises').firstWhere((e) => e['id'] == 'lib-deadlift'),
        )..['id'] = 'lib-new-thing';
        addRow(env, 'exercises', copy);
        return jsonEncode(env);
      }, allOf(contains('lib-new-thing'), contains('IC-204')));
    });

    test('H1 exception: a user exercise with an unresolved noPrimaryTarget '
        'block row is valid as blocked; a resolved row, a system or an '
        'imported exercise is not excused', () async {
      await accepts((env) {
        dropPrimary(env, 'ex-rich');
        addRow(env, 'exercise_blocks', block('ex-rich'));
        return jsonEncode(env);
      });
      await rejects((env) {
        dropPrimary(env, 'ex-rich');
        addRow(
          env,
          'exercise_blocks',
          block('ex-rich', resolvedAt: restoreStamp),
        );
        return jsonEncode(env);
      }, contains('IC-204'));
      await rejects((env) {
        for (final e in rowsOf(env, 'exercises')) {
          if (e['id'] == 'ex-rich') e['source'] = 'imported';
        }
        dropPrimary(env, 'ex-rich');
        addRow(env, 'exercise_blocks', block('ex-rich'));
        return jsonEncode(env);
      }, allOf(contains('ex-rich'), contains('IC-204')));
      await rejects((env) {
        final copy = Map<String, Object?>.of(
          rowsOf(env, 'exercises').firstWhere((e) => e['id'] == 'lib-deadlift'),
        )..['id'] = 'lib-new-thing';
        addRow(env, 'exercises', copy);
        addRow(env, 'exercise_blocks', block('lib-new-thing'));
        return jsonEncode(env);
      }, allOf(contains('lib-new-thing'), contains('IC-204')));
    });

    test('H1: a type that is not a domain value is kept only on a user '
        'exercise (WS4 L9); an unreadable date is refused', () async {
      await accepts((env) {
        for (final e in rowsOf(env, 'exercises')) {
          if (e['id'] == 'ex-rich') e['type'] = 'stretching';
        }
        return jsonEncode(env);
      });
      await rejects((env) {
        for (final e in rowsOf(env, 'exercises')) {
          if (e['id'] == 'ex-rich') e['source'] = 'imported';
          if (e['id'] == 'ex-rich') e['type'] = 'stretching';
        }
        return jsonEncode(env);
      }, contains('not domain values'));
      await rejects((env) {
        for (final e in rowsOf(env, 'exercises')) {
          if (e['id'] == 'ex-rich') e['created_at'] = 'yesterday';
        }
        return jsonEncode(env);
      }, contains('is not a date-time'));
    });

    test(
      'H1: the completeness rules are not restore rules (B-15): release '
      '1 system exercises and a user name over 60 characters restore',
      () async {
        await accepts((env) {
          for (final e in rowsOf(env, 'exercises')) {
            if (e['id'] == 'ex-rich') e['name'] = 'N' * 80;
          }
          return jsonEncode(env);
        });
      },
    );
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

  group('a device migrated from v7 (3b-4)', () {
    test('restores the v7 backup of its own v7 data: the system exercises '
        'equal the device rows (no difference to report), user data is '
        'replaced, the migration report stays', () async {
      await inBackupTempDir((dir) async {
        final file = mig.copyFixture(digest.fixturePath(7), dir);
        expect(await mig.openV8(file), isNull);
        final v8 = await V8File.open(file);
        try {
          final migrationEntries = await v8.rows(
            "SELECT * FROM migration_report_entries WHERE run_id = 'run-1'",
          );
          expect(migrationEntries, isNotEmpty);
          final quarantineBefore = {
            for (final r in await v8.rows('SELECT * FROM legacy_quarantine'))
              r['id']: r,
          };
          final refBefore = v8.digests();
          final result = await v8.repo().importJson(
            readGolden(digest.goldenFormat2Path()),
          );
          expect(result, isA<Ok<Object?>>(), reason: '$result');
          final system = await v8.rows(
            "SELECT id FROM exercises WHERE source = 'system'",
          );
          expect(system, hasLength(12));
          // The device's lib-* rows equal the backup's mapped rows.
          expect(
            await v8.rows(
              'SELECT * FROM migration_report_entries WHERE run_id = '
              "'restore-1' AND rule = '$deviceWinsRule'",
            ),
            isEmpty,
          );
          expect(
            await v8.rows(
              "SELECT * FROM migration_report_entries WHERE run_id = 'run-1'",
            ),
            migrationEntries,
          );
          // Register B-03 (OPEN), made visible (review M2): legacy_quarantine
          // is replaced as user data, so the migration run's quarantine
          // links lose their rows. Of its 40 links, the 2 to the v7
          // quarantine rows (ids kept by the backup) still find the same
          // row; 38 dangle; none points to another row.
          final quarantineAfter = {
            for (final r in await v8.rows('SELECT * FROM legacy_quarantine'))
              r['id']: r,
          };
          var same = 0;
          var dangling = 0;
          var other = 0;
          for (final e in migrationEntries) {
            final id = e['quarantine_id'];
            if (id == null) continue;
            final now = quarantineAfter[id];
            if (now == null) {
              dangling++;
            } else if (jsonEncode(now) == jsonEncode(quarantineBefore[id])) {
              same++;
            } else {
              other++;
            }
          }
          expect(
            (same: same, dangling: dangling, other: other),
            (same: 2, dangling: 38, other: 0),
          );
          for (final t in referenceTables) {
            expect(
              tableDigest(v8.digests(), t),
              tableDigest(refBefore, t),
              reason: t,
            );
          }
          v8NoForeignKeyViolation(v8);
        } finally {
          await v8.close();
        }
      });
    });
  });

  group('review fixes (M1, M3, M4, L1)', () {
    test(
      'M1: a JSON boolean, array or object in an exertion column of a '
      'format 2 file is refused (ValidationError); preview never throws',
      () async {
        await inBackupTempDir((dir) async {
          final v8 = await V8File.create(dir);
          try {
            final before = v8.digests();
            for (final column in ['exertion_scale', 'exertion_value']) {
              for (final value in <Object>[
                true,
                <Object?>[],
                <String, Object?>{},
              ]) {
                final env = decode(readGolden(digest.goldenFormat2Path()));
                rowsOf(env, 'session_sets').first[column] = value;
                final json = jsonEncode(env);
                final preview = v8.repo().previewJson(json);
                expect(errorOf(preview), isA<ValidationError>());
                final error = errorOf(await v8.repo().importJson(json));
                expect(error, isA<ValidationError>(), reason: '$column $value');
                expect(error.message, contains('$column must be a text'));
              }
            }
            expect(v8.digests(), before);
          } finally {
            await v8.close();
          }
        });
      },
    );

    test('M3 (R-08): runs exported from a migrated device are merged with '
        'backup provenance; their produced fields stay as recorded', () async {
      await inBackupTempDir((dir) async {
        final file = mig.copyFixture(digest.fixturePath(7), dir);
        expect(await mig.openV8(file), isNull);
        final a = await V8File.open(file);
        final b = await V8File.create(dir, 'b.sqlite');
        try {
          final runs = await a.rows('SELECT * FROM migration_runs ORDER BY id');
          expect(runs.map((r) => r['id']), ['run-1', 'run-1:integrity']);
          expect(runs.every((r) => r['provenance_kind'] == 'device'), isTrue);
          final json = await a.repo().exportJson();
          expect(await b.repo().importJson(json), isA<Ok<Object?>>());
          final identity = 'sha256:${sha256Hex(utf8.encode(json))}';
          for (final run in runs) {
            final merged = (await b.rows(
              "SELECT * FROM migration_runs WHERE id = '${run['id']}'",
            )).single;
            expect(merged, {
              ...run,
              'provenance_kind': 'backup',
              'provenance_source': identity,
              'merged_at': restoreStamp,
            });
            expect(run['provenance_source'], mig.installLabel);
          }
          // Entries and counts of the merged runs are unchanged.
          for (final t in [
            'migration_report_entries',
            'migration_report_counts',
          ]) {
            expect(
              await b.rows(
                "SELECT * FROM $t WHERE run_id LIKE 'run-1%' ORDER BY rowid",
              ),
              await a.rows(
                "SELECT * FROM $t WHERE run_id LIKE 'run-1%' ORDER BY rowid",
              ),
              reason: t,
            );
          }
        } finally {
          await a.close();
          await b.close();
        }
      });
    });

    test('M4 (B-08): a format 3 file with only system exercises, reference '
        'and report rows is structurally empty', () async {
      await inBackupTempDir((dir) async {
        final a = await richV8(await V8File.create(dir, 'a.sqlite'));
        final b = await richV8(await V8File.create(dir, 'b.sqlite'));
        try {
          for (final t in schemaV8Tables) {
            if (t.kind == TableKind.user) {
              await a.db.customStatement('DELETE FROM "${t.name}"');
            }
          }
          await a.db.customStatement(
            "DELETE FROM exercises WHERE source <> 'system'",
          );
          final json = await a.repo().exportJson();
          final env = decode(json);
          expect(rowsOf(env, 'exercises'), hasLength(12));
          expect(rowsOf(env, 'migration_report_entries'), isNotEmpty);
          final before = b.digests();
          final error = errorOf(await b.repo().importJson(json));
          expect(error.message, contains('contains no records'));
          expect(errorOf(b.repo().previewJson(json)).message, error.message);
          expect(b.digests(), before);
        } finally {
          await a.close();
          await b.close();
        }
      });
    });

    test('L1 (B-05): acknowledged_at stays the device value both '
        'ways', () async {
      await inBackupTempDir((dir) async {
        final v8 = await richV8(await V8File.create(dir));
        try {
          final ids = [
            for (final r in await v8.rows(
              'SELECT event_id FROM migration_report_entries ORDER BY '
              'event_id LIMIT 2',
            ))
              r['event_id']! as String,
          ];
          Future<void> ack(String id, String? at) => v8.db.customStatement(
            'UPDATE migration_report_entries SET acknowledged_at = ? WHERE '
            'event_id = ?',
            [at, id],
          );
          await ack(ids[1], 'backup-ack');
          final json = await v8.repo().exportJson();
          await ack(ids[0], 'device-ack');
          await ack(ids[1], null);
          expect(await v8.repo().importJson(json), isA<Ok<Object?>>());
          final after = {
            for (final r in await v8.rows(
              'SELECT event_id, acknowledged_at FROM migration_report_entries',
            ))
              r['event_id']: r['acknowledged_at'],
          };
          expect(after[ids[0]], 'device-ack');
          expect(after[ids[1]], isNull);
        } finally {
          await v8.close();
        }
      });
    });

    test('L1 (safeguard A): foreign keys are off throughout phase 2', () async {
      await inBackupTempDir((dir) async {
        final a = await richV8(await V8File.create(dir, 'a.sqlite'));
        final b = await V8File.create(dir, 'b.sqlite');
        try {
          final seen = <RestorePhase, int>{};
          final result = await b
              .repo(
                phaseProbe: (p) async {
                  seen[p] =
                      (await b.rows('PRAGMA foreign_keys')).single.values.first!
                          as int;
                },
              )
              .importJson(await a.repo().exportJson());
          expect(result, isA<Ok<Object?>>());
          expect(seen.keys.toSet(), RestorePhase.values.toSet());
          expect(seen.values.toSet(), {0});
          expect(await b.foreignKeys(), 1);
        } finally {
          await a.close();
          await b.close();
        }
      });
    });

    test('L1: a difference in an owned table of a device-kept system '
        'exercise is reported per table', () async {
      await inBackupTempDir((dir) async {
        final v8 = await richV8(await V8File.create(dir));
        try {
          final env = decode(await v8.repo().exportJson());
          final targets = rowsOf(
            env,
            'exercise_targets',
          ).where((t) => t['exercise_id'] == 'lib-deadlift');
          addRow(env, 'exercise_targets', {
            'exercise_id': 'lib-deadlift',
            'node_id': 'calves',
            'role': 'secondary',
            'ordinal': targets.length,
          });
          final before = await v8.rows(
            "SELECT * FROM exercise_targets WHERE exercise_id = 'lib-deadlift'",
          );
          expect(
            await v8.repo().importJson(jsonEncode(env)),
            isA<Ok<Object?>>(),
          );
          expect(
            await v8.rows(
              'SELECT * FROM exercise_targets WHERE exercise_id = '
              "'lib-deadlift'",
            ),
            before,
          );
          final w = (await v8.rows(
            "SELECT * FROM migration_report_entries WHERE run_id = 'restore-1' "
            "AND record_id = 'lib-deadlift'",
          )).single;
          expect(w['field'], 'exercise_targets');
          expect(w['rule'], deviceWinsRule);
          expect(w['original_value'], contains('calves'));
          expect(w['resulting_value'], isNot(contains('calves')));
        } finally {
          await v8.close();
        }
      });
    });

    test('L1: the v8 mapping of a device-kept system exercise in a v7 backup '
        'writes no quarantine row', () async {
      final env = decode(readGolden(digest.goldenFormat2Path()));
      for (final e in rowsOf(env, 'exercises')) {
        if (e['id'] == 'lib-deadlift') {
          e['secondary_muscles_json'] = '["hamstrings","tail"]';
        }
      }
      final json = jsonEncode(env);
      const sql =
          'SELECT * FROM legacy_quarantine WHERE source_table = '
          "'exercises' AND row_id = 'lib-deadlift'";
      await inBackupTempDir((dir) async {
        final fresh = await V8File.create(dir, 'fresh.sqlite');
        final kept = await richV8(await V8File.create(dir, 'kept.sqlite'));
        try {
          // On a device without it, the value is quarantined.
          expect(await fresh.repo().importJson(json), isA<Ok<Object?>>());
          expect(await fresh.rows(sql), hasLength(1));
          // On a device that keeps it, nothing of the backup's row is used.
          expect(await kept.repo().importJson(json), isA<Ok<Object?>>());
          expect(await kept.rows(sql), isEmpty);
        } finally {
          await fresh.close();
          await kept.close();
        }
      });
    });

    test(
      'L1: a report count with the same key and another value rejects',
      () async {
        await inBackupTempDir((dir) async {
          final v8 = await richV8(await V8File.create(dir));
          try {
            final env = decode(await v8.repo().exportJson());
            // +1 on examined and migrated keeps the backup's own counts
            // reconciled, so only the merge sees the conflict.
            for (final c in rowsOf(env, 'migration_report_counts')) {
              if (c['run_id'] == 'rich-1' &&
                  c['source_table'] == 'exercises' &&
                  (c['code'] == 'examined' || c['code'] == 'migrated')) {
                c['record_count'] = (c['record_count']! as int) + 1;
              }
            }
            final before = v8.digests();
            final error = errorOf(await v8.repo().importJson(jsonEncode(env)));
            expect(error.message, contains('migration_report_counts'));
            expect(v8.digests(), before);
          } finally {
            await v8.close();
          }
        });
      },
    );

    for (final (phase, sql, cause) in [
      (
        RestorePhase.restoreReportWritten,
        'INSERT INTO food_servings (id, food_id, label, amount, unit, '
            "sort_order) VALUES ('fs-ghost', 'ghost-food', 'g', 1.0, 'g', 0)",
        'would break foreign keys',
      ),
      (
        RestorePhase.foreignKeysChecked,
        'INSERT INTO settings (key, value, updated_at) VALUES '
            "('injected', 'x', '$_stamp')",
        'self-check failed',
      ),
    ]) {
      test(
        'L1: the backstop that reports "$cause" aborts the restore',
        () async {
          await inBackupTempDir((dir) async {
            final a = await richV8(await V8File.create(dir, 'a.sqlite'));
            final b = await richV8(await V8File.create(dir, 'b.sqlite'));
            try {
              final before = b.digests();
              final result = await b
                  .repo(
                    phaseProbe: (p) async {
                      if (p == phase) await b.db.customStatement(sql);
                    },
                  )
                  .importJson(await a.repo().exportJson());
              final error = errorOf(result) as StorageError;
              expect('${error.cause}', contains(cause));
              expect(b.digests(), before);
              expect(await b.foreignKeys(), 1);
            } finally {
              await a.close();
              await b.close();
            }
          });
        },
      );
    }
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

    // The legacy path writes the bootstrap, the v6 and v8 quarantine rows,
    // the backfilled session entries and the mapping's report.
    for (final phase in [
      RestorePhase.referenceInserted,
      RestorePhase.exercisesInserted,
      RestorePhase.quarantineInserted,
      RestorePhase.sessionExercisesBackfilled,
      RestorePhase.restoreReportWritten,
      RestorePhase.selfChecked,
    ]) {
      test('a format 1 (schema v5) restore failing at ${phase.name} leaves '
          'the database unchanged', () async {
        await inBackupTempDir((dir) async {
          final v8 = await richV8(await V8File.create(dir));
          try {
            final json = readGolden(digest.goldenFormat1Path(5));
            final before = v8.digests();
            final result = await v8
                .repo(
                  phaseProbe: (p) async {
                    if (p == phase) throw StateError('injected at $p');
                  },
                )
                .importJson(json);
            expect(errorOf(result), isA<StorageError>());
            expect(v8.digests(), before);
            expect(await v8.foreignKeys(), 1);
            final ok = await v8.repo().importJson(json);
            expect(ok, isA<Ok<Object?>>(), reason: '$ok');
            expect(await v8.count('session_exercises'), 13);
          } finally {
            await v8.close();
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
