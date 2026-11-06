import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:repforge/data/db/migration/v7_to_v8.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/library/integrity_preflight.dart';
import 'package:repforge/domain/library/legacy_v8_mapping.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

import 'harness_v7_db.dart' show strictSchema;
import 'migration_digest.dart' as digest;
import 'v8_migration_support.dart';

/// WP 8 sub-stage 3b-4: the v7 → v8 step on the owner's scenario table (D04
/// section 7, 2026-11-06, "3B-ACC-01") and the safeguards around it.
///
/// - clean v7 migrates; foreign keys are off inside the step and on after;
/// - a failed `quick_check` stays at v7 with no write (injected result, a
///   real damaged page, and the background-isolate connection);
/// - an exercise with no primary target or unknown equipment is blocked
///   individually, with one block per reason (R-01);
/// - a repeated equipment id keeps its first occurrence; every repeat is
///   reported with its position;
/// - invalid TRN-020 values are preserved in quarantine and reported;
/// - unknown reference data is never invented;
/// - a failure at every checkpoint leaves exactly v7 or exactly v8, and the
///   re-run reuses the run id (R-07);
/// - a repeated migration writes nothing twice;
/// - a new foreign-key violation or unresolved reference aborts the step;
///   pre-existing damage (TD-44) is reported and never blocks;
/// - release 1 hashes the exact bundled seed bytes (R-10);
/// - the OPEN visibility switch stays off and refuses to run when on.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final v7Fixture = digest.fixturePath(7);
  final v7OrphansFixture = digest.fixturePath(7, orphans: true);

  /// Every table of [file] as typed rows, for exact state comparison.
  Map<String, List<Map<String, String>>> stateOf(File file) {
    final s = DbState.read(file);
    return {
      for (final MapEntry(:key, :value) in s.tables.entries)
        key: [for (final r in value) typedRow(r, s.columns[key]!)],
    };
  }

  List<String> strictOf(File file) {
    final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      return strictSchema(raw);
    } finally {
      raw.close();
    }
  }

  late Map<String, List<Map<String, String>>> referenceV8;
  setUpAll(() async {
    referenceV8 = await inTempDir((dir) async {
      final f = copyFixture(v7Fixture, dir);
      expect(await openV8(f), isNull);
      return stateOf(f);
    });
  });

  group('clean v7', () {
    test(
      'migrates to v8; foreign keys off inside the step, on after open; '
      'the run id comes from the generator',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        final seen = <V8MigrationPhase, int>{};
        late AppDatabaseV8 db;
        db = AppDatabaseV8(
          NativeDatabase(
            f,
            // Keys on at connection setup: the chain still switches them off
            // before the step's transaction (safeguard A).
            setup: (d) => d.execute('PRAGMA foreign_keys = ON'),
          ),
          migrationConfig: testConfig(newRunId: () => 'run-clean'),
          phaseProbe: (p) async {
            final row = await db
                .customSelect('PRAGMA foreign_keys')
                .getSingle();
            seen[p] = row.read<int>('foreign_keys');
          },
        );
        await db.customSelect('SELECT 1').get();
        final keys = await db.customSelect('PRAGMA foreign_keys').getSingle();
        expect(keys.read<int>('foreign_keys'), 1);
        await db.close();
        expect(seen.keys, V8MigrationPhase.values);
        expect(seen.values.toSet(), {0});
        final s = DbState.read(f);
        expect(s.userVersion, 8);
        expect(s.rows('migration_runs').map((r) => r['id']), [
          'run-clean',
          'run-clean:integrity',
        ]);
      }),
    );

    test(
      'every exercise and set is examined; counts reconcile with the '
      'fixture',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        expect(await openV8(f), isNull);
        final c = storedCounts(DbState.read(f), 'run-1');
        expect(c['exercises|category|examined'], 26);
        expect(c['session_sets|category|examined'], 35);
        expect(c['legacy_quarantine|category|examined'], 2);
        expect(
          c['exercises|category|migrated']! +
              c['exercises|category|preserved']! +
              c['exercises|category|quarantinedOrUnresolved']! +
              c['exercises|category|rejectedOrBlocked']!,
          26,
        );
      }),
    );
  });

  group('failed quick_check stays at v7 and writes nothing', () {
    Future<void> expectStopped(
      File f,
      Object? error, {
      required List<int> bytesBefore,
      required MigrationRunLedger ledger,
    }) async {
      expect(error, isNotNull);
      final failure = findIntegrityPreflightFailure(error!);
      expect(failure, isNotNull, reason: '$error');
      expect(failure!.outcome.mayMigrate, isFalse);
      expect(failure.outcome.writesAllowed, isFalse);
      expect(failure.outcome.schemaVersion, 7);
      expect(failure.outcome.userMessage, contains('version 7'));
      expect(failure.outcome.diagnostics, isNotEmpty);
      expect(f.readAsBytesSync(), bytesBefore);
      expect(await ledger.read(7, 8, ledgerKeyOf(f)), isNull);
    }

    test(
      'injected failing result: stop, nothing written',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        final before = f.readAsBytesSync();
        final ledger = InMemoryMigrationRunLedger();
        final error = await openV8(
          f,
          config: testConfig(
            ledger: ledger,
            quickCheck: (_) async => QuickCheckRows(const [
              '*** in database main ***',
              'Tree 12 page 40: btreeInitPage() returns error code 11',
            ]),
          ),
        );
        await expectStopped(f, error, bytesBefore: before, ledger: ledger);
        expect(findIntegrityPreflightFailure(error!)!.outcome.diagnostics, [
          '*** in database main ***',
          'Tree 12 page 40: btreeInitPage() returns error code 11',
        ]);
      }),
    );

    test(
      'injected pragma error: stop, nothing written',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        final before = f.readAsBytesSync();
        final ledger = InMemoryMigrationRunLedger();
        final error = await openV8(
          f,
          config: testConfig(
            ledger: ledger,
            quickCheck: (_) async =>
                const QuickCheckError('database disk image is malformed'),
          ),
        );
        await expectStopped(f, error, bytesBefore: before, ledger: ledger);
      }),
    );

    /// A copy of the v7 fixture with the root page of `session_sets`
    /// overwritten: the file opens (page 1 is intact), `quick_check` fails.
    File corruptCopy(Directory dir) {
      final f = copyFixture(v7Fixture, dir);
      final raw = sqlite3.open(f.path, mode: OpenMode.readOnly);
      final int root;
      final int pageSize;
      try {
        root =
            raw
                    .select(
                      'SELECT rootpage FROM sqlite_master WHERE name = '
                      "'session_sets'",
                    )
                    .single['rootpage']!
                as int;
        pageSize = raw.select('PRAGMA page_size').single.values.first! as int;
      } finally {
        raw.close();
      }
      final bytes = f.readAsBytesSync();
      for (var i = 0; i < pageSize; i++) {
        bytes[(root - 1) * pageSize + i] = 0x5A;
      }
      f.writeAsBytesSync(bytes, flush: true);
      return f;
    }

    test(
      'a real damaged page: stop, file byte-identical',
      () => inTempDir((dir) async {
        final f = corruptCopy(dir);
        final before = f.readAsBytesSync();
        final ledger = InMemoryMigrationRunLedger();
        final error = await openV8(f, config: testConfig(ledger: ledger));
        await expectStopped(f, error, bytesBefore: before, ledger: ledger);
      }),
    );

    test(
      'a real damaged page on the background-isolate connection: the same '
      'typed stop',
      () => inTempDir((dir) async {
        final f = corruptCopy(dir);
        final before = f.readAsBytesSync();
        final ledger = InMemoryMigrationRunLedger();
        final db = AppDatabaseV8(
          NativeDatabase.createInBackground(f),
          migrationConfig: testConfig(ledger: ledger),
        );
        Object? error;
        try {
          await db.customSelect('SELECT 1').get();
        } on Object catch (e) {
          error = e;
        } finally {
          await db.close();
        }
        await expectStopped(f, error, bytesBefore: before, ledger: ledger);
      }),
    );

    test(
      'runQuickCheck reads ok on a sound file and reports a failing '
      'pragma as an error; unwrapRemoteError removes the '
      'DriftRemoteException of a background connection',
      () => inTempDir((dir) async {
        final db = AppDatabaseV8(
          NativeDatabase.createInBackground(File('${dir.path}/fresh.sqlite')),
        );
        Object? error;
        try {
          final rows = await runQuickCheck(db);
          expect((rows as QuickCheckRows).rows, ['ok']);
          try {
            await db.customSelect('SELECT * FROM no_such_table').get();
          } on Object catch (e) {
            error = e;
          }
        } finally {
          await db.close();
        }
        expect(error, isA<DriftRemoteException>());
        expect(unwrapRemoteError(error!), isA<SqliteException>());
        expect(unwrapRemoteError(error), isNot(isA<DriftRemoteException>()));
        final closed = await runQuickCheck(db);
        expect(closed, isA<QuickCheckError>());
        expect(
          evaluateIntegrityPreflight(
            schemaVersion: 7,
            result: closed,
          ).mayMigrate,
          isFalse,
        );
        final stop = IntegrityPreflightFailure(
          evaluateIntegrityPreflight(
            schemaVersion: 7,
            result: const QuickCheckError('x'),
          ),
        );
        expect(findIntegrityPreflightFailure(stop), same(stop));
        expect(findIntegrityPreflightFailure(StateError('x')), isNull);
        expect('$stop', contains('nothing was changed'));
      }),
    );
  });

  group('exercises', () {
    test(
      'no primary target and unknown equipment: blocked individually, one '
      'row per reason (R-01), history kept',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        expect(await openV8(f), isNull);
        final s = DbState.read(f);
        final blocks = [
          for (final r in s.rows('exercise_blocks'))
            '${r['exercise_id']}:${r['reason']}',
        ];
        expect(
          blocks,
          containsAll([
            'ex-rotator:noPrimaryTarget',
            'ex-rotator:unknownEquipment',
          ]),
        );
        expect(blocks, contains('ex-empty:noPrimaryTarget'));
        expect(blocks, contains('ex-garbage:invalidEquipment'));
        final rotator = s
            .rows('migration_report_entries')
            .where(
              (e) =>
                  e['record_id'] == 'ex-rotator' &&
                  e['disposition'] == 'blocked',
            )
            .map((e) => e['block_reason'])
            .toList();
        expect(rotator, ['noPrimaryTarget', 'unknownEquipment']);
        // Resolving one reason keeps the exercise blocked (R-01 predicate).
        final raw = sqlite3.open(f.path);
        try {
          raw.execute(
            'UPDATE exercise_blocks SET resolved_at = ? '
            "WHERE exercise_id = 'ex-rotator' AND reason = 'noPrimaryTarget'",
            ['2026-11-07T00:00:00.000Z'],
          );
          expect(
            raw.select(
              'SELECT 1 FROM exercise_blocks WHERE exercise_id = ? '
              'AND resolved_at IS NULL',
              ['ex-rotator'],
            ),
            isNotEmpty,
          );
        } finally {
          raw.close();
        }
        // The exercise row and every reference to it are kept.
        expect(s.byId('exercises'), contains('ex-rotator'));
        // R-06: the empty primary is the JSON string "", never null.
        final empty = s
            .rows('migration_report_entries')
            .firstWhere(
              (e) =>
                  e['record_id'] == 'ex-empty' &&
                  e['disposition'] == 'quarantined',
            );
        expect(empty['original_value'], '""');
      }),
    );

    test(
      'a repeated equipment id keeps the first occurrence; every repeat '
      'is reported with its position and id (ADR-0008 Q10)',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        final raw = sqlite3.open(f.path);
        raw.execute('UPDATE exercises SET equipment_json = ? WHERE id = ?', [
          '["barbell","bench","barbell","dumbbell","bench"]',
          'ex-bench',
        ]);
        raw.close();
        expect(await openV8(f), isNull);
        final s = DbState.read(f);
        expect(
          [
            for (final r in s.rows('exercise_equipment'))
              if (r['exercise_id'] == 'ex-bench')
                '${r['equipment_id']}@${r['ordinal']}',
          ],
          ['barbell@0', 'bench@1', 'dumbbell@2'],
        );
        final skipped = [
          for (final e in s.rows('migration_report_entries'))
            if (e['record_id'] == 'ex-bench' && e['field'] == 'equipment_json')
              [
                e['disposition'],
                e['position'],
                e['element'],
                e['rule'],
                e['category'],
              ].join('|'),
        ];
        expect(skipped..sort(), [
          'skipped|2|"barbell"|IC-307|migrated',
          'skipped|4|"bench"|IC-307|migrated',
        ]);
        // A list with only repeats migrates faithfully: no quarantine, no
        // block (ADR-0008 clarification 3).
        expect(
          s.rows('legacy_quarantine').where((r) => r['row_id'] == 'ex-bench'),
          isEmpty,
        );
        expect(
          s
              .rows('exercise_blocks')
              .where((r) => r['exercise_id'] == 'ex-bench'),
          isEmpty,
        );
      }),
    );

    test(
      'unknown reference data is never invented',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        expect(await openV8(f), isNull);
        final s = DbState.read(f);
        final nodes = {for (final r in s.rows('anatomy_nodes')) r['id']};
        final items = {for (final r in s.rows('equipment_items')) r['id']};
        expect(nodes, hasLength(31));
        expect(items, hasLength(21));
        for (final unknown in [
          'rotator cuff',
          'Neck',
          'traps',
          '',
          'Shoulders',
        ]) {
          expect(nodes, isNot(contains(unknown)));
        }
        for (final unknown in ['Dumbbells', 'None', 'Pulley', 'bodyweight']) {
          expect(items, isNot(contains(unknown)));
        }
        expect(
          s
              .rows('exercise_targets')
              .where(
                (r) =>
                    const {
                      'ex-rotator',
                      'ex-neck',
                      'ex-empty',
                    }.contains(r['exercise_id']) &&
                    r['role'] == 'primary',
              ),
          isEmpty,
        );
        // The originals are in quarantine, never dropped.
        final q = {
          for (final r in s.rows('legacy_quarantine'))
            if (r['source_table'] == 'exercises')
              '${r['row_id']}|${r['original_json']}',
        };
        expect(q, contains('ex-rotator|{"primary_muscle":"rotator cuff"}'));
        expect(
          q,
          contains(
            r'ex-rotator|{"equipment_json":"[\"Dumbbells\",\"None\",'
            r'\"Pulley\"]"}',
          ),
        );
      }),
    );
  });

  group('TRN-020', () {
    test(
      'invalid values are preserved in quarantine and reported; valid '
      'ones are kept as they are',
      () => inTempDir((dir) async {
        final v7 = DbState.read(File(v7Fixture));
        final f = copyFixture(v7Fixture, dir);
        expect(await openV8(f), isNull);
        final s = DbState.read(f);
        final sets = s.byId('session_sets');
        final quarantined = {
          for (final r in s.rows('legacy_quarantine'))
            if (r['source_table'] == 'session_sets' &&
                (r['reason']! as String).startsWith('TRN-020'))
              r['row_id']: r['original_json'],
        };
        var invalid = 0;
        for (final r in v7.rows('session_sets')) {
          final id = r['id']! as String;
          final scale = r['exertion_scale'];
          final value = r['exertion_value'];
          final ok = classifyLegacyExertion(
            setId: id,
            scale: scale,
            value: value,
          ).isValid;
          if (ok) {
            expect(typed(sets[id]!['exertion_scale']), typed(scale));
            expect(typed(sets[id]!['exertion_value']), typed(value));
            expect(quarantined, isNot(contains(id)));
          } else {
            invalid++;
            expect(sets[id]!['exertion_scale'], isNull);
            expect(sets[id]!['exertion_value'], isNull);
            expect(
              quarantined[id],
              encodeStoredRow({
                'exertion_scale': scale,
                'exertion_value': value,
              }),
            );
            final entries = s
                .rows('migration_report_entries')
                .where((e) => e['record_id'] == id)
                .toList();
            expect(entries.map((e) => e['field']).toSet(), {
              if (scale != null) 'exertion_scale',
              if (value != null) 'exertion_value',
            });
            for (final e in entries) {
              expect(e['disposition'], 'cleared');
              expect(e['rule'], 'TRN-020');
              expect(e['category'], 'quarantinedOrUnresolved');
              expect(e['resulting_value'], 'null');
              expect(e['quarantine_id'], isNotNull);
            }
          }
        }
        // set-exert-04 .. 07 and 11 .. 16: RPE 0, 0.5, 7.3, 9.75; RIR 2.5, 6;
        // scale borg; scale RPE; value without scale; scale without value.
        expect(invalid, 10);
        final raw = sqlite3.open(f.path);
        try {
          expect(
            () => raw.execute(
              'UPDATE session_sets SET exertion_value = 7.3 '
              "WHERE id = 'set-001'",
            ),
            throwsA(isA<SqliteException>()),
          );
        } finally {
          raw.close();
        }
      }),
    );
  });

  group('crash at every checkpoint leaves v7 or full v8; the re-run '
      'reuses the run id (R-07)', () {
    final points =
        <(String, bool Function(MigrationCheckpoint?, V8MigrationPhase?))>[
          for (final stage in MigrationStage.values)
            (
              'chain ${stage.name}',
              (c, p) => c != null && c.from == 7 && c.stage == stage,
            ),
          for (final phase in V8MigrationPhase.values)
            ('phase ${phase.name}', (c, p) => p == phase),
        ];
    for (final (name, at) in points) {
      test(
        name,
        () => inTempDir((dir) async {
          final f = copyFixture(v7Fixture, dir);
          final v7State = stateOf(f);
          final v7Strict = strictOf(f);
          final ledger = FileMigrationRunLedger(
            File('${dir.path}/ledger.json'),
          );
          final ids = countingRunIds();
          final error = await openV8(
            f,
            config: testConfig(ledger: ledger, newRunId: ids),
            probe: (c) async {
              if (at(c, null)) throw StateError('injected at $name');
            },
            phaseProbe: (p) async {
              if (at(null, p)) throw StateError('injected at $name');
            },
          );
          expect('$error', contains('injected at $name'));
          final committed = name == 'chain committed';
          if (committed) {
            expect(stateOf(f), referenceV8);
          } else {
            expect(DbState.read(f).userVersion, 7);
            expect(stateOf(f), v7State);
            expect(strictOf(f), v7Strict);
          }
          // A new process: a new ledger object on the same file.
          final again = await openV8(
            f,
            config: testConfig(
              ledger: FileMigrationRunLedger(File('${dir.path}/ledger.json')),
              newRunId: ids,
            ),
          );
          expect(again, isNull);
          // Everything equals an uninterrupted run with run id run-1: the
          // resumed run reused it (a run before the ledger write is the first
          // attempt and gets run-1 as well).
          expect(stateOf(f), referenceV8);
          // Cleared after the commit, or (killed between the commit and the
          // clear) at the next open of the v8 database (Review B, M1).
          expect(
            await FileMigrationRunLedger(File('${dir.path}/ledger.json'))
                .read(7, 8, ledgerKeyOf(f)),
            isNull,
          );
          expect(File('${dir.path}/ledger.json').existsSync(), isFalse);
        }),
      );
    }

    test(
      'a genuinely new attempt (ledger cleared) gets a new run id',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        final ledger = InMemoryMigrationRunLedger();
        final ids = countingRunIds();
        final error = await openV8(
          f,
          config: testConfig(ledger: ledger, newRunId: ids),
          phaseProbe: (p) async {
            if (p == V8MigrationPhase.reportWritten) {
              throw StateError('injected');
            }
          },
        );
        expect(error, isNotNull);
        expect((await ledger.read(7, 8, ledgerKeyOf(f)))!.runId, 'run-1');
        await ledger.clear(7, 8, ledgerKeyOf(f));
        expect(
          await openV8(
            f,
            config: testConfig(ledger: ledger, newRunId: ids),
          ),
          isNull,
        );
        final s = DbState.read(f);
        expect(s.rows('migration_runs').map((r) => r['id']), [
          'run-2',
          'run-2:integrity',
        ]);
        expect(await ledger.read(7, 8, ledgerKeyOf(f)), isNull);
      }),
    );
  });

  group('repeated migration writes nothing twice', () {
    test(
      'reopening a migrated database changes no byte',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        expect(await openV8(f), isNull);
        final bytes = f.readAsBytesSync();
        expect(await openV8(f), isNull);
        expect(f.readAsBytesSync(), bytes);
      }),
    );

    test(
      'a v8 database reported at version 7 runs the step again and writes '
      'nothing',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        expect(await openV8(f), isNull);
        final state = stateOf(f);
        final raw = sqlite3.open(f.path)..execute('PRAGMA user_version = 7');
        raw.close();
        expect(
          await openV8(f, config: testConfig(newRunId: () => 'run-other')),
          isNull,
        );
        expect(stateOf(f), state);
        expect(DbState.read(f).userVersion, 8);
      }),
    );

    test(
      'the same input and run id give identical entries; another run id '
      'gives other event ids (R-07)',
      () => inTempDir((dir) async {
        Future<List<Map<String, Object?>>> run(
          String name,
          String runId,
        ) async {
          final f = copyFixture(v7Fixture, dir, '$name.sqlite');
          expect(
            await openV8(f, config: testConfig(newRunId: () => runId)),
            isNull,
          );
          return DbState.read(f).rows('migration_report_entries');
        }

        final a = await run('a', 'run-x');
        final b = await run('b', 'run-x');
        final c = await run('c', 'run-y');
        expect(b, a);
        expect(c.length, a.length);
        expect(
          {for (final e in c) e['event_id']}
              .intersection({for (final e in a) e['event_id']}),
          isEmpty,
        );
        List<String> withoutIds(List<Map<String, Object?>> es) => [
          for (final e in es)
            jsonEncode({
              for (final MapEntry(:key, :value) in e.entries)
                if (key != 'event_id' && key != 'run_id') key: value,
            }),
        ]..sort();
        expect(withoutIds(c), withoutIds(a));
      }),
    );
  });

  group('foreign keys (safeguard A)', () {
    Future<Object?> injectAt(File f, V8MigrationPhase phase, String sql) async {
      late AppDatabaseV8 db;
      db = AppDatabaseV8(
        NativeDatabase(f),
        migrationConfig: testConfig(),
        phaseProbe: (p) async {
          if (p == phase) await db.customStatement(sql);
        },
      );
      try {
        await db.customSelect('SELECT 1').get();
        return null;
      } on Object catch (e) {
        return e;
      } finally {
        await db.close();
      }
    }

    test(
      'a new violation in a new table aborts and rolls back',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        final before = stateOf(f);
        final error = await injectAt(
          f,
          V8MigrationPhase.reportWritten,
          'INSERT INTO exercise_targets VALUES '
          "('ghost-exercise', 'chest', 'primary', 0)",
        );
        expect(error, isA<V8MigrationFailure>());
        final failure = error! as V8MigrationFailure;
        expect(failure.kind, V8MigrationFailureKind.newIntegrityViolation);
        expect(failure.details.single, contains('exercise_targets'));
        expect(stateOf(f), before);
        expect(DbState.read(f).userVersion, 7);
      }),
    );

    test(
      'a new violation outside the targeted tables is caught by the broader '
      'review against the whole-database baseline',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        final before = stateOf(f);
        final error = await injectAt(
          f,
          V8MigrationPhase.setsRebuilt,
          "UPDATE food_servings SET food_id = 'ghost-food' "
          'WHERE id = (SELECT min(id) FROM food_servings)',
        );
        expect(error, isA<V8MigrationFailure>());
        final failure = error! as V8MigrationFailure;
        expect(failure.kind, V8MigrationFailureKind.newIntegrityViolation);
        expect(failure.details.single, contains('food_servings'));
        expect(stateOf(f), before);
      }),
    );

    test(
      'a failed self-check (row count, provenance, stored entries) aborts '
      'and rolls back',
      () => inTempDir((dir) async {
        for (final (name, sql) in [
          ('count', "DELETE FROM exercises WHERE id = 'ex-bench'"),
          (
            'entries',
            'DELETE FROM migration_report_entries WHERE rowid = '
                '(SELECT min(rowid) FROM migration_report_entries)',
          ),
          (
            'provenance',
            "UPDATE exercises SET source = 'imported' "
                "WHERE id = 'ex-row'",
          ),
        ]) {
          final f = copyFixture(v7Fixture, dir, '$name.sqlite');
          final before = stateOf(f);
          final error = await injectAt(
            f,
            V8MigrationPhase.foreignKeysChecked,
            sql,
          );
          expect(error, isA<V8MigrationFailure>(), reason: name);
          expect(
            (error! as V8MigrationFailure).kind,
            V8MigrationFailureKind.selfCheckFailed,
            reason: name,
          );
          expect(stateOf(f), before, reason: name);
        }
      }),
    );

    test(
      'a new unresolved exercise reference aborts and rolls back',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        final before = stateOf(f);
        final error = await injectAt(
          f,
          V8MigrationPhase.setsRebuilt,
          "UPDATE plan_exercises SET exercise_id = 'ghost' "
          'WHERE id = (SELECT min(id) FROM plan_exercises)',
        );
        expect(error, isA<V8MigrationFailure>());
        expect(
          (error! as V8MigrationFailure).details.single,
          contains('IC-902'),
        );
        expect(stateOf(f), before);
      }),
    );

    test(
      'pre-existing damage (orphans, TD-44) is reported in the integrity '
      'run and never blocks',
      () => inTempDir((dir) async {
        for (final (fixture, name) in [
          (v7OrphansFixture, 'v7o'),
          (digest.fixturePath(6, orphans: true), 'v6o'),
        ]) {
          final f = copyFixture(fixture, dir, '$name.sqlite');
          final v7 = await v7Copy(fixture, dir);
          final before = findingsOfFile(v7);
          expect(before, isNotEmpty);
          expect(await openV8(f), isNull);
          final s = DbState.read(f);
          expect(s.userVersion, 8);
          final reported = {
            for (final e in s.rows('migration_report_entries'))
              if (e['run_id'] == 'run-1:integrity')
                [
                  e['source_table'],
                  e['record_id'],
                  e['field'],
                  e['rule'],
                ].join('|'),
          };
          expect(reported, {
            for (final f in before.values)
              '${f.table}|${f.recordId}|${f.column}|${f.rule}',
          });
          // TD-44: the v6 → v7 backfill gave a set with a missing session a
          // session_exercises row; its own foreign key does not resolve.
          // (The v7 orphan fixture never ran that step.)
          expect(
            reported.where(
              (k) =>
                  k.startsWith('session_exercises|legacy:') &&
                  k.endsWith('|session_id|foreign_key_check'),
            ),
            name == 'v6o' ? isNotEmpty : isEmpty,
            reason: name,
          );
          expect(findingKeys(f), before.keys.toSet());
          v7.deleteSync();
        }
      }),
    );
  });

  group('release 1 (plan section 6 step 9; R-10)', () {
    test(
      'hashes the exact bundled seed bytes, not a re-serialised form',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        expect(await openV8(f), isNull);
        final row = DbState.read(f).rows('catalogue_releases').single;
        expect(row['content_hash'], digest.sha256OfFile(seedPath));
        expect(row['content_hash_algorithm'], 'sha256');
        expect(row['content_hash_encoding'], 'hex-lower');
        final reserialised = digest.sha256OfString(
          jsonEncode(jsonDecode(File(seedPath).readAsStringSync())),
        );
        expect(row['content_hash'], isNot(reserialised));
        // The bytes given are hashed as they are.
        final g = copyFixture(v7Fixture, dir, 'g.sqlite');
        final changed = Uint8List.fromList([...seedBytes(), 0x0A]);
        expect(
          await openV8(
            g,
            config: testConfig(loadSeedBytes: () async => changed),
          ),
          isNull,
        );
        expect(
          DbState.read(g).rows('catalogue_releases').single['content_hash'],
          digest.sha256Hex(changed),
        );
      }),
    );

    test(
      'not recorded when the v7 seed was never applied',
      () => inTempDir((dir) async {
        for (final value in [null, '0', 'x']) {
          final f = copyFixture(v7Fixture, dir, 'seed_$value.sqlite');
          final raw = sqlite3.open(f.path);
          if (value == null) {
            raw.execute(
              "DELETE FROM settings WHERE key = 'seedExercisesVersion'",
            );
          } else {
            raw.execute(
              'UPDATE settings SET value = ? '
              "WHERE key = 'seedExercisesVersion'",
              [value],
            );
          }
          raw.close();
          var loaded = false;
          expect(
            await openV8(
              f,
              config: testConfig(
                loadSeedBytes: () async {
                  loaded = true;
                  return seedBytes();
                },
              ),
            ),
            isNull,
          );
          expect(DbState.read(f).rows('catalogue_releases'), isEmpty);
          expect(loaded, isFalse);
        }
      }),
    );
  });

  group('report', () {
    test(
      'quarantine rows from before v8 are listed (plan section 6 step 7)',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        expect(await openV8(f), isNull);
        final entries =
            DbState.read(f)
                .rows('migration_report_entries')
                .where((e) => e['source_table'] == 'legacy_quarantine')
                .toList()
              ..sort(
                (a, b) => '${a['record_id']}'.compareTo('${b['record_id']}'),
              );
        expect(
          [
            for (final e in entries)
              [
                e['record_id'],
                e['quarantine_id'],
                e['exercise_id'],
                e['disposition'],
                e['rule'],
                e['category'],
              ].join('|'),
          ],
          [
            '1|1|null|quarantined|WP8-D3|quarantinedOrUnresolved',
            '2|2|ex-old|quarantined|WP8-D3|quarantinedOrUnresolved',
          ],
        );
        expect(
          entries.first['original_value'],
          jsonEncode('{"id":"set-old-1","reps":0}'),
        );
        expect(entries.first['reason'], contains('session_sets'));
        expect(entries.first['reason'], contains('set-old-1'));
      }),
    );
  });

  group('the OPEN visibility switch (WS4 H1, L9)', () {
    test('defaults to off', () {
      expect(testConfig().mappingOptions.blockInvalidSecondaryTargets, isFalse);
    });

    test(
      'switched on, the step refuses before any write',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        final bytes = f.readAsBytesSync();
        final ledger = InMemoryMigrationRunLedger();
        final error = await openV8(
          f,
          config: testConfig(
            ledger: ledger,
            options: const LegacyMappingOptions(
              blockInvalidSecondaryTargets: true,
            ),
          ),
        );
        expect(error, isA<V8MigrationFailure>());
        expect(
          (error! as V8MigrationFailure).kind,
          V8MigrationFailureKind.unsupportedOption,
        );
        expect(f.readAsBytesSync(), bytes);
        expect(await ledger.read(7, 8, ledgerKeyOf(f)), isNull);
      }),
    );
  });

  group('run ledger (R-07, R-32; Review B M1, L1 to L3)', () {
    Future<Object?> failAt(
      File f,
      V8MigrationConfig config,
      V8MigrationPhase phase,
    ) => openV8(
      f,
      config: config,
      phaseProbe: (p) async {
        if (p == phase) throw StateError('injected at ${p.name}');
      },
    );

    List<Object?> runsOf(File f) => [
      for (final r in DbState.read(f).rows('migration_runs'))
        if (r['trigger_kind'] == 'migration') '${r['id']}@${r['generated_at']}',
    ];

    test(
      'the file ledger: entries per database, survives a new instance, '
      'deleted when empty, no temporary file left',
      () => inTempDir((dir) async {
        final file = File('${dir.path}/l.json');
        PendingMigrationRun run(String id, String db) => PendingMigrationRun(
          runId: id,
          generatedAt: v8Stamp,
          database: db,
          fingerprint: 'f',
          appVersion: appVersion,
        );
        await FileMigrationRunLedger(file).write(7, 8, run('r1', '/a'));
        await FileMigrationRunLedger(file).write(7, 8, run('r2', '/b'));
        expect(
          await FileMigrationRunLedger(file).read(7, 8, '/a'),
          run('r1', '/a'),
        );
        expect(
          await FileMigrationRunLedger(file).read(7, 8, '/b'),
          run('r2', '/b'),
        );
        expect(await FileMigrationRunLedger(file).read(8, 9, '/a'), isNull);
        await FileMigrationRunLedger(file).write(7, 8, run('r3', '/a'));
        expect(
          (await FileMigrationRunLedger(file).read(7, 8, '/a'))!.runId,
          'r3',
        );
        await FileMigrationRunLedger(file).clear(7, 8, '/a');
        expect(await FileMigrationRunLedger(file).read(7, 8, '/a'), isNull);
        expect(file.existsSync(), isTrue);
        await FileMigrationRunLedger(file).clear(7, 8, '/b');
        expect(file.existsSync(), isFalse);
        expect(dir.listSync(), isEmpty, reason: 'no temporary file left');
        expect(
          run(
            'r',
            '/a',
          ).binds(database: '/a', fingerprint: 'f', appVersion: appVersion),
          isTrue,
        );
        for (final (d, fp, v) in [
          ('/b', 'f', appVersion),
          ('/a', 'g', appVersion),
          ('/a', 'f', '9.9.9'),
        ]) {
          expect(
            run('r', '/a').binds(database: d, fingerprint: fp, appVersion: v),
            isFalse,
          );
        }
      }),
    );

    test(
      'P1: two databases, one ledger: each resumes its own run id',
      () => inTempDir((dir) async {
        final ledger = FileMigrationRunLedger(File('${dir.path}/ledger.json'));
        final ids = countingRunIds();
        final a = copyFixture(v7Fixture, dir, 'a.sqlite');
        final b = copyFixture(v7OrphansFixture, dir, 'b.sqlite');
        expect(
          await failAt(
            a,
            testConfig(ledger: ledger, newRunId: ids),
            V8MigrationPhase.reportWritten,
          ),
          isNotNull,
        );
        expect(
          await openV8(
            b,
            config: testConfig(ledger: ledger, newRunId: ids),
          ),
          isNull,
        );
        expect(
          await openV8(
            a,
            config: testConfig(ledger: ledger, newRunId: ids),
          ),
          isNull,
        );
        expect(runsOf(a), ['run-1@$v8Stamp']);
        expect(runsOf(b), ['run-2@$v8Stamp']);
        expect(File('${dir.path}/ledger.json').existsSync(), isFalse);
      }),
    );

    test(
      'P2: killed after the commit, before the clear; then another '
      'database: a new run id; the stale entry goes at the next v8 open',
      () => inTempDir((dir) async {
        final ledgerFile = File('${dir.path}/ledger.json');
        final ids = countingRunIds();
        final a = copyFixture(v7Fixture, dir, 'a.sqlite');
        final error = await openV8(
          a,
          config: testConfig(
            ledger: FileMigrationRunLedger(ledgerFile),
            newRunId: ids,
          ),
          probe: (c) async {
            if (c.from == 7 && c.stage == MigrationStage.committed) {
              throw StateError('killed after commit');
            }
          },
        );
        expect('$error', contains('killed after commit'));
        expect(DbState.read(a).userVersion, 8);
        expect(
          await FileMigrationRunLedger(ledgerFile).read(7, 8, ledgerKeyOf(a)),
          isNotNull,
          reason: 'stale entry left by the kill',
        );
        // Another v7 database (same content, other file), later clock and
        // app version: a genuinely new attempt.
        final b = copyFixture(v7Fixture, dir, 'b.sqlite');
        expect(
          await openV8(
            b,
            config: testConfig(
              ledger: FileMigrationRunLedger(ledgerFile),
              newRunId: ids,
              clock: FixedClock(DateTime.utc(2027, 3)),
              version: '0.9.0',
            ),
          ),
          isNull,
        );
        expect(runsOf(b), ['run-2@2027-03-01T00:00:00.000Z']);
        final ea = {
          for (final r in DbState.read(a).rows('migration_report_entries'))
            r['event_id'],
        };
        final eb = {
          for (final r in DbState.read(b).rows('migration_report_entries'))
            r['event_id'],
        };
        expect(ea.intersection(eb), isEmpty);
        // The next open of a (v8) clears its committed run's entry.
        expect(
          await openV8(
            a,
            config: testConfig(ledger: FileMigrationRunLedger(ledgerFile)),
          ),
          isNull,
        );
        expect(ledgerFile.existsSync(), isFalse);
        expect(runsOf(a), ['run-1@$v8Stamp']);
      }),
    );

    test(
      'the same path with other content, or another app version, is a new '
      'attempt',
      () => inTempDir((dir) async {
        final ledger = InMemoryMigrationRunLedger();
        final ids = countingRunIds();
        final f = copyFixture(v7Fixture, dir);
        expect(
          await failAt(
            f,
            testConfig(ledger: ledger, newRunId: ids),
            V8MigrationPhase.exercisesRebuilt,
          ),
          isNotNull,
        );
        // Replaced in place by another v7 database.
        File(v7OrphansFixture).copySync(f.path);
        expect(
          await failAt(
            f,
            testConfig(ledger: ledger, newRunId: ids),
            V8MigrationPhase.exercisesRebuilt,
          ),
          isNotNull,
        );
        expect((await ledger.read(7, 8, ledgerKeyOf(f)))!.runId, 'run-2');
        // Same file, another app version.
        expect(
          await openV8(
            f,
            config: testConfig(ledger: ledger, newRunId: ids, version: '0.8.1'),
          ),
          isNull,
        );
        expect(runsOf(f), ['run-3@$v8Stamp']);
      }),
    );

    test(
      'L3: a resumed run with a later clock keeps the first generated_at',
      () => inTempDir((dir) async {
        final ledger = InMemoryMigrationRunLedger();
        final f = copyFixture(v7Fixture, dir);
        expect(
          await failAt(
            f,
            testConfig(ledger: ledger),
            V8MigrationPhase.selfChecked,
          ),
          isNotNull,
        );
        expect(
          await openV8(
            f,
            config: testConfig(
              ledger: ledger,
              newRunId: () => 'never-used',
              clock: FixedClock(DateTime.utc(2027, 1, 2, 3)),
            ),
          ),
          isNull,
        );
        final s = DbState.read(f);
        expect(runsOf(f), ['run-1@$v8Stamp']);
        expect(
          {
            for (final r in s.rows('legacy_quarantine').skip(2))
              r['quarantined_at'],
            for (final r in s.rows('exercise_blocks')) r['blocked_at'],
          },
          {v8Stamp},
        );
      }),
    );

    test(
      'L1: an unreadable or foreign ledger stops the upgrade with a typed '
      'failure and a recovery route; the database is unchanged',
      () => inTempDir((dir) async {
        for (final content in [
          '{"scheme":"repforge.migrationRunLedger/2","ru',
          '{"scheme":"other","runs":{}}',
          '[1,2]',
        ]) {
          final ledgerFile = File('${dir.path}/ledger.json')
            ..writeAsStringSync(content);
          final f = copyFixture(v7Fixture, dir);
          final bytes = f.readAsBytesSync();
          final error = await openV8(
            f,
            config: testConfig(ledger: FileMigrationRunLedger(ledgerFile)),
          );
          expect(error, isA<MigrationRunLedgerFailure>(), reason: content);
          final failure = error! as MigrationRunLedgerFailure;
          expect(failure.location, ledgerFile.path);
          expect(failure.recoveryRoute, contains('Move it'));
          expect('$failure', contains('not changed'));
          expect(f.readAsBytesSync(), bytes);
          expect(DbState.read(f).userVersion, 7);
          // The recovery route: move the ledger aside, open again.
          ledgerFile.renameSync('${dir.path}/ledger.aside');
          expect(
            await openV8(
              f,
              config: testConfig(ledger: FileMigrationRunLedger(ledgerFile)),
            ),
            isNull,
          );
          expect(DbState.read(f).userVersion, 8);
          File('${dir.path}/ledger.aside').deleteSync();
        }
      }),
    );

    test(
      'L2: a ledger that cannot clear after the commit does not fail the '
      'open; the entry is cleared at the next open',
      () => inTempDir((dir) async {
        final ledger = _ClearFailsOnce();
        final f = copyFixture(v7Fixture, dir);
        expect(await openV8(f, config: testConfig(ledger: ledger)), isNull);
        expect(DbState.read(f).userVersion, 8);
        expect(ledger.clearFailures, 2, reason: 'after commit and at open');
        expect(await ledger.read(7, 8, ledgerKeyOf(f)), isNotNull);
        expect(await openV8(f, config: testConfig(ledger: ledger)), isNull);
        expect(await ledger.read(7, 8, ledgerKeyOf(f)), isNull);
      }),
    );

    test(
      'N1: an open of a v8 database never fingerprints the file, also when '
      'it clears a stale entry',
      () => inTempDir((dir) async {
        var reads = 0;
        String counting(File file) {
          reads++;
          return V7ToV8Migration.fileFingerprint(file);
        }

        final ledgerFile = File('${dir.path}/ledger.json');
        V8MigrationConfig config() => testConfig(
          ledger: FileMigrationRunLedger(ledgerFile),
          fingerprint: counting,
        );
        final f = copyFixture(v7Fixture, dir);
        final error = await openV8(
          f,
          config: config(),
          probe: (c) async {
            if (c.from == 7 && c.stage == MigrationStage.committed) {
              throw StateError('killed after commit');
            }
          },
        );
        expect('$error', contains('killed after commit'));
        expect(reads, 1, reason: 'once, at the start of the step');
        expect(ledgerFile.existsSync(), isTrue, reason: 'stale entry');
        expect(await openV8(f, config: config()), isNull);
        expect(ledgerFile.existsSync(), isFalse, reason: 'stale entry cleared');
        expect(await openV8(f, config: config()), isNull);
        expect(reads, 1, reason: 'no v8 open read the file');
      }),
    );

    test(
      'N2: an in-memory database never reuses a run id and never touches '
      'the ledger',
      () => inTempDir((dir) async {
        final ledger = _CountingLedger();
        final ids = countingRunIds();
        for (var attempt = 1; attempt <= 2; attempt++) {
          final src = sqlite3.open(v7Fixture, mode: OpenMode.readOnly);
          final mem = sqlite3.openInMemory();
          await src.backup(mem, nPage: -1).drain<void>();
          src.close();
          final db = AppDatabaseV8(
            NativeDatabase.opened(mem),
            migrationConfig: testConfig(ledger: ledger, newRunId: ids),
          );
          await db.customSelect('SELECT 1').get();
          final runs = await db
              .customSelect(
                'SELECT id FROM migration_runs WHERE trigger_kind = '
                "'migration'",
              )
              .get();
          expect(runs.single.read<String>('id'), 'run-$attempt');
          await db.close();
        }
        expect(ledger.calls, 0);
      }),
    );

    test(
      'N7: temporary files left by an earlier crash are removed on the next '
      'write',
      () => inTempDir((dir) async {
        final file = File('${dir.path}/l.json');
        final stale = File('${file.path}.4242.1700000000000000.tmp')
          ..writeAsStringSync('{"partial');
        final other = File('${dir.path}/unrelated.tmp')..writeAsStringSync('x');
        await FileMigrationRunLedger(file).write(
          7,
          8,
          const PendingMigrationRun(
            runId: 'r',
            generatedAt: v8Stamp,
            database: '/a',
            fingerprint: 'f',
            appVersion: appVersion,
          ),
        );
        expect(stale.existsSync(), isFalse);
        expect(other.existsSync(), isTrue);
        expect(dir.listSync().map((e) => e.uri.pathSegments.last).toSet(), {
          'l.json',
          'unrelated.tmp',
        });
      }),
    );
  });

  test('N5: the v8-only entities are Schema8 minus the frozen Schema7', () {
    final db = AppDatabaseV8(NativeDatabase.memory());
    addTearDown(db.close);
    expect(V7ToV8Migration.v8OnlyEntityNames(db), {
      'content_providers',
      'catalogue_releases',
      'anatomy_nodes',
      'movement_patterns',
      'equipment_items',
      'reference_labels',
      'exercise_targets',
      'exercise_patterns',
      'exercise_equipment',
      'exercise_names',
      'exercise_user_state',
      'exercise_blocks',
      'migration_runs',
      'migration_report_counts',
      'migration_report_entries',
      'idx_exercise_targets_node',
      'idx_exercise_patterns_pattern',
      'idx_exercise_equipment_equipment',
      'idx_migration_report_entries_run',
      'idx_migration_report_entries_record',
    });
  });

  group('self-checks and unexpected states (Review B L4, L6)', () {
    test(
      'L4: mapping lists that disagree with the events fail the '
      'affectedByTable self-check',
      () => inTempDir((dir) async {
        for (final (name, mapper) in <(String, LegacyExerciseMapper)>[
          (
            'quarantine list dropped',
            (row, {options = const LegacyMappingOptions()}) {
              final m = mapLegacyExercise(row, options: options);
              return LegacyExerciseMapping(
                id: m.id,
                source: m.source,
                providerId: m.providerId,
                revision: m.revision,
                targets: m.targets,
                equipment: m.equipment,
                blocks: m.blocks,
                events: m.events,
                quarantine: const [],
              );
            },
          ),
          (
            'block list dropped',
            (row, {options = const LegacyMappingOptions()}) {
              final m = mapLegacyExercise(row, options: options);
              return LegacyExerciseMapping(
                id: m.id,
                source: m.source,
                providerId: m.providerId,
                revision: m.revision,
                targets: m.targets,
                equipment: m.equipment,
                blocks: const [],
                events: m.events,
                quarantine: m.quarantine,
              );
            },
          ),
        ]) {
          final f = copyFixture(v7Fixture, dir, '${name.length}.sqlite');
          final bytes = f.readAsBytesSync();
          final error = await openV8(
            f,
            config: testConfig(mapExercise: mapper),
          );
          expect(error, isA<V8MigrationFailure>(), reason: name);
          final failure = error! as V8MigrationFailure;
          expect(failure.kind, V8MigrationFailureKind.selfCheckFailed);
          expect(failure.details.join(), contains('independent input'));
          expect(f.readAsBytesSync(), bytes, reason: name);
        }
      }),
    );

    test(
      'L6: a v7 database that already holds a v8 table or index is refused',
      () => inTempDir((dir) async {
        for (final (name, sql) in [
          ('table', 'CREATE TABLE anatomy_nodes (id TEXT PRIMARY KEY)'),
          (
            'index',
            'CREATE INDEX idx_exercise_equipment_equipment ON exercises (name)',
          ),
        ]) {
          final f = copyFixture(v7Fixture, dir, '$name.sqlite');
          final raw = sqlite3.open(f.path)..execute(sql);
          raw.close();
          final bytes = f.readAsBytesSync();
          final error = await openV8(f);
          expect(error, isA<V8MigrationFailure>(), reason: name);
          final failure = error! as V8MigrationFailure;
          expect(failure.kind, V8MigrationFailureKind.unexpectedState);
          expect(failure.details.single, contains('v8 entities'));
          expect(f.readAsBytesSync(), bytes);
        }
      }),
    );
  });

  group('pre-existing findings keyed by record (Review B M2)', () {
    test(
      'a new unresolved reference in a column that already has baseline '
      'damage aborts',
      () => inTempDir((dir) async {
        final f = await v7Copy(v7OrphansFixture, dir);
        final pre = findingsOfFile(f).values
            .where((x) => x.table == 'session_sets' && x.rule == 'IC-901');
        expect(pre, isNotEmpty, reason: 'baseline damage in that column');
        final before = stateOf(f);
        late AppDatabaseV8 db;
        db = AppDatabaseV8(
          NativeDatabase(f),
          migrationConfig: testConfig(),
          phaseProbe: (p) async {
            if (p == V8MigrationPhase.setsRebuilt) {
              await db.customStatement(
                "UPDATE session_sets SET exercise_id = 'ghost-2' "
                'WHERE id = (SELECT min(id) FROM session_sets WHERE '
                'exercise_id IN (SELECT id FROM exercises))',
              );
            }
          },
        );
        Object? error;
        try {
          await db.customSelect('SELECT 1').get();
        } on Object catch (e) {
          error = e;
        } finally {
          await db.close();
        }
        expect(error, isA<V8MigrationFailure>());
        final failure = error! as V8MigrationFailure;
        expect(failure.kind, V8MigrationFailureKind.newIntegrityViolation);
        expect(failure.details.single, contains('ghost-2'));
        expect(stateOf(f), before);
      }),
    );

    test(
      'two pre-existing findings in one column are both reported',
      () => inTempDir((dir) async {
        final f = copyFixture(v7Fixture, dir);
        final raw = sqlite3.open(f.path);
        final ids = [
          for (final r in raw.select(
            'SELECT id FROM session_sets ORDER BY id LIMIT 2',
          ))
            r['id']! as String,
        ];
        for (final (i, id) in ids.indexed) {
          raw.execute('UPDATE session_sets SET exercise_id = ? WHERE id = ?', [
            'gone-$i',
            id,
          ]);
        }
        raw.close();
        expect(await openV8(f), isNull);
        final reported = [
          for (final e in DbState.read(f).rows('migration_report_entries'))
            if (e['run_id'] == 'run-1:integrity' &&
                e['source_table'] == 'session_sets' &&
                e['field'] == 'exercise_id')
              '${e['record_id']}|${e['original_value']}|${e['rule']}',
        ]..sort();
        expect(reported, [
          '${ids[0]}|"gone-0"|IC-901',
          '${ids[1]}|"gone-1"|IC-901',
        ]);
      }),
    );
  });

  test(
    'a plain AppDatabaseV8 still refuses to upgrade (not connected)',
    () => inTempDir((dir) async {
      final f = copyFixture(v7Fixture, dir);
      final bytes = f.readAsBytesSync();
      final db = AppDatabaseV8(NativeDatabase(f));
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(isA<UnsupportedError>()),
      );
      await db.close();
      expect(f.readAsBytesSync(), bytes);
    }),
  );

  test(
    'a v8 database without a v8 run but in the v8 shape is refused',
    () => inTempDir((dir) async {
      final f = copyFixture(v7Fixture, dir);
      expect(await openV8(f), isNull);
      final raw = sqlite3.open(f.path)
        ..execute('DELETE FROM migration_report_counts')
        ..execute('DELETE FROM migration_report_entries')
        ..execute('DELETE FROM migration_runs')
        ..execute('PRAGMA user_version = 7');
      raw.close();
      final error = await openV8(f);
      expect(error, isA<V8MigrationFailure>());
      expect(
        (error! as V8MigrationFailure).kind,
        V8MigrationFailureKind.unexpectedState,
      );
    }),
  );

  test('ReportAction and BlockReason names used by the step are the stored '
      'v8 values', () {
    expect([for (final r in BlockReason.values) r.name].take(3), [
      'noPrimaryTarget',
      'unknownEquipment',
      'invalidEquipment',
    ]);
  });
}

/// A ledger whose clear fails twice (after the commit and at the open that
/// follows it), then works.
final class _ClearFailsOnce implements MigrationRunLedger {
  final InMemoryMigrationRunLedger _inner = InMemoryMigrationRunLedger();
  int clearFailures = 0;

  @override
  Future<PendingMigrationRun?> read(int from, int to, String database) =>
      _inner.read(from, to, database);

  @override
  Future<void> write(int from, int to, PendingMigrationRun run) =>
      _inner.write(from, to, run);

  @override
  Future<void> clear(int from, int to, String database) async {
    if (clearFailures < 2) {
      clearFailures++;
      throw const FileSystemException('injected clear failure');
    }
    await _inner.clear(from, to, database);
  }
}

/// A ledger that counts every call.
final class _CountingLedger implements MigrationRunLedger {
  final InMemoryMigrationRunLedger _inner = InMemoryMigrationRunLedger();
  int calls = 0;

  @override
  Future<PendingMigrationRun?> read(int from, int to, String database) {
    calls++;
    return _inner.read(from, to, database);
  }

  @override
  Future<void> write(int from, int to, PendingMigrationRun run) {
    calls++;
    return _inner.write(from, to, run);
  }

  @override
  Future<void> clear(int from, int to, String database) {
    calls++;
    return _inner.clear(from, to, database);
  }
}
