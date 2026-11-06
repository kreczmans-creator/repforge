@Tags(['trial'])
@Timeout(Duration(minutes: 30))
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_backup_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:sqlite3/sqlite3.dart';

import 'trial_fixture.dart';
import 'trial_harness.dart';
import 'trial_migration.dart';

/// FROZEN EVIDENCE for the WP 8 stage 3b decision (plan section 17.1). Valid
/// only while `schemaVersion` is 7; do not extend it into the real v8
/// migration tests. Not part of the default run: run it with
/// `flutter test --concurrency=1 --run-skipped --tags trial
/// test/migration_trial/`. Results print as `TRIAL_RESULT` lines and are
/// written to `trial_results.json` in the temporary directory.
const _runs = 5;

void main() {
  late Directory tmp;
  late String fixturePath;
  late FixtureFacts facts;
  late Pre pre;
  final results = <String, Object?>{};

  void record(String key, Object? value) {
    results[key] = value;
    // ignore: avoid_print, the trial reports through the test log
    print('TRIAL_RESULT ${jsonEncode({key: value})}');
  }

  String copyFixture(String name) {
    final p = '${tmp.path}/$name.sqlite';
    File(fixturePath).copySync(p);
    return p;
  }

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('repforge_trial_');
    fixturePath = '${tmp.path}/v7_fixture.sqlite';
    final sw = Stopwatch()..start();
    facts = await buildV7Fixture(fixturePath);
    final build = sw.elapsedMilliseconds;
    pre = Pre(fixturePath);
    record('environment', {
      'os': Platform.operatingSystemVersion,
      'dart': Platform.version.split(' ').first,
      'processors': Platform.numberOfProcessors,
      'sqlite_version': facts.sqliteVersion,
      'fixture_bytes': facts.bytes,
      'fixture_build_ms': build,
      'fixture_counts': facts.counts,
      'invalid_exertion_sets': pre.invalidSets,
      'tmp': tmp.path,
    });
    record('fixture_stats', fixtureStats(fixturePath));
  });

  tearDownAll(() {
    File('${tmp.path}/trial_results.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
    // ignore: avoid_print, the trial reports through the test log
    print('TRIAL_FILE ${tmp.path}/trial_results.json');
  });

  group('timing, equality, constraints', () {
    for (final c in configs) {
      test(c.label, () async {
        final times = <int>[];
        final laps = <String, List<int>>{};
        Verification? last;
        for (var i = 0; i < _runs; i++) {
          final path = copyFixture('run');
          final plan = TrialPlan(exercises: c.exercises, trn020: c.trn020);
          final (ms, error) = await runMigration(path, plan);
          expect(error, isNull, reason: 'migration must succeed');
          times.add(ms);
          plan.laps.forEach((k, v) => (laps[k] ??= []).add(v));
          expect(plan.keysAfterOpen, isTrue, reason: 'keys restored');
          last = verifyMigrated(path, pre, c);
          expect(last.failures, isEmpty, reason: '${c.label} run $i');
          if (i < _runs - 1) File(path).deleteSync();
        }
        // Constraint enforcement on the last migrated file.
        final path = '${tmp.path}/run.sqlite';
        final out = <String, Object?>{
          'runs_ms': times,
          'median_ms': median(times),
          'min_ms': times.reduce((a, b) => a < b ? a : b),
          'max_ms': times.reduce((a, b) => a > b ? a : b),
          'median_laps_ms': {
            for (final e in laps.entries) e.key: median(e.value),
          },
          'verification': last!.facts,
          'report': {
            'exercise_values_quarantined':
                last.facts['quarantined_exercise_values'],
            'sets_cleared': last.facts['quarantined_sets'],
          },
        };
        if (c.exercises != ExercisesOption.none) {
          final r = tryStatements(path, exerciseViolations());
          out['exercise_violations_rejected'] = '${r.rejected}/${r.total}';
          out['exercise_violations_accepted'] = r.accepted;
          out['cascade_targets_removed_for_ex_0100'] = cascadeCheck(path);
          expect(r.accepted, isEmpty);
          // Shape equals a freshly created v8 table.
          final fresh = '${tmp.path}/fresh.sqlite';
          if (File(fresh).existsSync()) File(fresh).deleteSync();
          final fdb = openTrial(fresh, TrialPlan());
          await fdb.createFresh();
          await fdb.close();
          final a = sqlite3.open(path);
          final b = sqlite3.open(fresh);
          out['exercises_shape_equals_fresh_v8'] =
              shapeOf(
                a,
                'exercises',
              ).difference(shapeOf(b, 'exercises')).isEmpty &&
              shapeOf(
                b,
                'exercises',
              ).difference(shapeOf(a, 'exercises')).isEmpty;
          String createSql(Database d) =>
              (d
                          .select(
                            "SELECT sql FROM sqlite_master WHERE name = 'exercises'",
                          )
                          .first['sql']!
                      as String)
                  .replaceAll(RegExp(r'\s+'), ' ');
          out['exercises_create_sql'] = createSql(a);
          out['exercises_create_sql_equals_fresh'] =
              createSql(a) == createSql(b);
          out['exercises_column_order'] = columnsOf(a, 'exercises');
          out['fresh_column_order'] = columnsOf(b, 'exercises');
          a.close();
          b.close();
        }
        final bad = tryStatements(path, exertionViolations());
        final good = tryStatements(path, exertionValid_());
        out['exertion_violations_rejected'] = '${bad.rejected}/${bad.total}';
        out['exertion_valid_accepted'] =
            '${good.total - good.rejected}/${good.total}';
        record(c.label, out);
        if (c.trn020 != Trn020Option.none) {
          expect(bad.accepted, isEmpty);
          expect(good.rejected, 0);
        }
      });
    }
  });

  group('fixture', () {
    test(
      'fixture schema equals AppDatabase createAll (sqlite_master)',
      () async {
        final prodPath = '${tmp.path}/prod_empty.sqlite';
        final prod = AppDatabase(NativeDatabase(File(prodPath)));
        await prod.customSelect('SELECT 1').get();
        await prod.close();
        List<String> master(String path) {
          final db = sqlite3.open(path);
          final rows = [
            for (final r in db.select(
              "SELECT type, name, tbl_name, sql FROM sqlite_master "
              "WHERE name NOT LIKE 'sqlite_%'",
            ))
              [
                r['type'],
                r['name'],
                r['tbl_name'],
                '${r['sql']}'.replaceAll(RegExp(r'[\s"]+'), ''),
              ].join('|'),
          ]..sort();
          db.close();
          return rows;
        }

        final a = master(fixturePath);
        final b = master(prodPath);
        final onlyFixture = a.toSet().difference(b.toSet()).toList();
        final onlyProd = b.toSet().difference(a.toSet()).toList();
        record('fixture_schema_vs_createAll', {
          'entities_fixture': a.length,
          'entities_production': b.length,
          'only_in_fixture': onlyFixture,
          'only_in_production': onlyProd,
        });
        expect(onlyFixture, isEmpty);
        expect(onlyProd, isEmpty);
      },
    );
  });

  group('interleaved timing', () {
    test('warm-up, then rotating order, 7 rounds', () async {
      final cs = configs.sublist(0, 5); // A, B3, T-A, T-B, T-C
      final times = {for (final c in cs) c.label: <int>[]};
      for (var round = 0; round < 8; round++) {
        final order = [
          ...cs.sublist(round % cs.length),
          ...cs.sublist(0, round % cs.length),
        ];
        for (final c in order) {
          final path = copyFixture('inter');
          final (ms, error) = await runMigration(
            path,
            TrialPlan(exercises: c.exercises, trn020: c.trn020),
          );
          expect(error, isNull);
          if (round > 0) times[c.label]!.add(ms); // round 0 is warm-up
        }
      }
      final out = <String, Object?>{
        for (final e in times.entries)
          e.key: {
            'runs_ms': e.value,
            'median_ms': median(e.value),
            'min_ms': e.value.reduce((a, b) => a < b ? a : b),
            'max_ms': e.value.reduce((a, b) => a > b ? a : b),
          },
      };
      record('interleaved_timing', out);
    });
  });

  group('extra checks', () {
    test(
      'default connection (keys off at open) gives the same timing',
      () async {
        final out = <String, Object?>{};
        for (final c in [configs[0], configs[1]]) {
          final times = <int>[];
          for (var i = 0; i < 3; i++) {
            final path = copyFixture('defkeys');
            final plan = TrialPlan(exercises: c.exercises);
            final (ms, error) = await runMigration(
              path,
              plan,
              keysOnAtOpen: false,
            );
            expect(error, isNull);
            expect(plan.keysAtStart, isFalse);
            expect(plan.keysAfterOpen, isTrue);
            expect(verifyMigrated(path, pre, c).failures, isEmpty);
            times.add(ms);
          }
          out[c.label] = {'runs_ms': times, 'median_ms': median(times)};
        }
        record('timing_default_connection_keys_off', out);
      },
    );

    test('negative control: the verifier detects a changed value', () async {
      final path = copyFixture('control');
      final c = configs[0];
      final (_, error) = await runMigration(
        path,
        TrialPlan(exercises: c.exercises),
      );
      expect(error, isNull);
      expect(verifyMigrated(path, pre, c).failures, isEmpty);
      final db = sqlite3.open(path)
        ..execute(
          "UPDATE exercises SET name = name || 'x' WHERE id = 'ex-0042'",
        )
        ..execute('UPDATE session_sets SET reps = reps + 1 WHERE id = ?', [
          'set-77',
        ])
        ..execute("DELETE FROM exercise_targets WHERE exercise_id = 'ex-0042'");
      db.close();
      final bad = verifyMigrated(path, pre, c).failures;
      record(
        'negative_control_failures',
        bad.map((f) => f.split(':').first).toList(),
      );
      expect(bad.length, greaterThanOrEqualTo(3));
    });

    test('B3 limitations: what ALTER TABLE cannot express', () async {
      final path = copyFixture('limits');
      final db = sqlite3.open(path);
      final out = <String, String>{};
      String attempt(String sql) {
        db.execute('SAVEPOINT t');
        try {
          db.execute(sql);
          return 'accepted';
        } on SqliteException catch (e) {
          return 'rejected: ${e.message}';
        } finally {
          db.execute('ROLLBACK TO t');
          db.execute('RELEASE t');
        }
      }

      const trn020 =
          'ALTER TABLE session_sets ADD CONSTRAINT trn020 CHECK '
          "(exertion_scale IN ('rpe', 'rir'))";
      out['ADD CONSTRAINT CHECK while legacy rows violate it'] = attempt(
        trn020,
      );
      out['ADD CONSTRAINT CHECK when no row violates it'] = () {
        db.execute('SAVEPOINT t3');
        db.execute(
          'UPDATE session_sets SET exertion_scale = NULL, '
          'exertion_value = NULL',
        );
        final r = attempt(trn020);
        db.execute('ROLLBACK TO t3');
        db.execute('RELEASE t3');
        return r;
      }();
      out['ALTER COLUMN SET NOT NULL while NULLs exist'] = attempt(
        'ALTER TABLE session_sets ALTER COLUMN reps SET NOT NULL',
      );
      out['DROP CONSTRAINT of an unnamed v7 CHECK'] = attempt(
        'ALTER TABLE session_sets DROP CONSTRAINT exertion_value_check',
      );
      out['ADD COLUMN NOT NULL without a default'] = attempt(
        'ALTER TABLE exercises ADD COLUMN x TEXT NOT NULL',
      );
      out['ADD COLUMN NOT NULL with a constant default and CHECK'] = attempt(
        "ALTER TABLE exercises ADD COLUMN x TEXT NOT NULL DEFAULT 'a' "
        "CHECK (x IN ('a', 'b'))",
      );
      out['ADD COLUMN whose CHECK fails for the default on existing rows'] =
          attempt(
            "ALTER TABLE exercises ADD COLUMN x TEXT NOT NULL DEFAULT 'a' "
            "CHECK (x = 'b')",
          );
      out['DROP COLUMN that is the primary key'] = attempt(
        'ALTER TABLE exercises DROP COLUMN id',
      );
      db.execute('CREATE INDEX trial_idx_muscle ON exercises (primary_muscle)');
      out['DROP COLUMN used by an index'] = attempt(
        'ALTER TABLE exercises DROP COLUMN primary_muscle',
      );
      db.execute('DROP INDEX trial_idx_muscle');
      out['DROP COLUMN referenced by a CHECK on another column'] = attempt(
        'ALTER TABLE session_sets DROP COLUMN energy_kcal',
      );
      out['DROP COLUMN with its own column CHECK (supplied)'] = attempt(
        'ALTER TABLE exercises DROP COLUMN supplied',
      );
      for (final (label, body) in [
        (
          'trigger body uses the column',
          'AFTER UPDATE ON exercises '
              'BEGIN SELECT NEW.primary_muscle; END',
        ),
        (
          'trigger UPDATE OF list names the column',
          'AFTER UPDATE OF primary_muscle ON exercises BEGIN SELECT 1; END',
        ),
      ]) {
        out['DROP COLUMN: $label'] = () {
          db.execute('SAVEPOINT t2');
          db.execute('CREATE TRIGGER trial_trg $body');
          String r;
          try {
            db.execute('ALTER TABLE exercises DROP COLUMN primary_muscle');
            r = 'drop accepted';
            try {
              db.execute('UPDATE exercises SET archived = archived');
              r = '$r; later UPDATE works';
            } on SqliteException catch (e) {
              r = '$r; later UPDATE fails: ${e.message}';
            }
          } on SqliteException catch (e) {
            r = 'drop rejected: ${e.message}';
          }
          db.execute('ROLLBACK TO t2');
          db.execute('RELEASE t2');
          return r;
        }();
      }
      db.close();
      record('b3_limitations', out);
    });
  });

  const combos = [
    ('A + T-A', ExercisesOption.rebuild, Trn020Option.rebuild),
    ('B3 + T-B', ExercisesOption.alterColumns, Trn020Option.triggers),
    ('B3 + T-C', ExercisesOption.alterColumns, Trn020Option.alterConstraint),
  ];

  void expectFullyV7(String path, List<String> notes, String what) {
    final db = sqlite3.open(path);
    try {
      final version = db.select('PRAGMA user_version').first.values.first;
      final integrity = db.select('PRAGMA integrity_check').first.values.first;
      expect(version, 7, reason: '$what user_version');
      expect(integrity, 'ok');
      expect(userTables(db), pre.tables, reason: '$what table list');
      expect(digestAll(db), pre.all, reason: '$what row hashes');
      notes.add(
        '$what: fully v7 (version 7, all ${pre.tables.length} tables equal, '
        'integrity ok)',
      );
    } finally {
      db.close();
    }
  }

  group('crash recovery', () {
    for (final (label, ex, trn) in combos) {
      final cfg = Config(label, ex, trn);

      test('$label: throw inside the transaction after the copy', () async {
        final notes = <String>[];
        final path = copyFixture('crash1');
        final (_, error) = await runMigration(
          path,
          TrialPlan(exercises: ex, trn020: trn, crash: CrashPoint.afterRebuild),
        );
        expect(error, isA<SimulatedCrash>());
        expectFullyV7(path, notes, 'after crash');
        final (_, rerunError) = await runMigration(
          path,
          TrialPlan(exercises: ex, trn020: trn),
        );
        expect(rerunError, isNull);
        expect(verifyMigrated(path, pre, cfg).failures, isEmpty);
        notes.add(
          're-run: fully v8, values equal, integrity ok, fk check empty',
        );
        record('crash1 $label', notes);
      });

      test('$label: throw inside the TRN-020 step', () async {
        final notes = <String>[];
        final path = copyFixture('crash1b');
        final (_, error) = await runMigration(
          path,
          TrialPlan(exercises: ex, trn020: trn, crash: CrashPoint.insideTrn020),
        );
        expect(error, isA<SimulatedCrash>());
        expectFullyV7(path, notes, 'after crash inside TRN-020');
        final (_, rerunError) = await runMigration(
          path,
          TrialPlan(exercises: ex, trn020: trn),
        );
        expect(rerunError, isNull);
        expect(verifyMigrated(path, pre, cfg).failures, isEmpty);
        notes.add('re-run: fully v8, values equal');
        record('crash1b $label', notes);
      });

      test('$label: crash after commit, before user_version', () async {
        final notes = <String>[];
        final path = copyFixture('crash2');
        final (_, error) = await runMigration(
          path,
          TrialPlan(
            exercises: ex,
            trn020: trn,
            crash: CrashPoint.beforeUserVersion,
          ),
        );
        expect(error, isA<SimulatedCrash>());
        var db = sqlite3.open(path);
        final versionAfter = db
            .select('PRAGMA user_version')
            .first
            .values
            .first;
        final hasOld = columnsOf(db, 'exercises').contains('primary_muscle');
        db.close();
        expect(versionAfter, 7);
        expect(hasOld, isFalse, reason: 'the committed shape is v8');
        notes.add(
          'after crash: user_version 7 with v8 shape (committed, '
          'version not written)',
        );
        final (_, rerunError) = await runMigration(
          path,
          TrialPlan(exercises: ex, trn020: trn),
        );
        expect(rerunError, isNull);
        expect(verifyMigrated(path, pre, cfg).failures, isEmpty);
        db = sqlite3.open(path);
        final targets = db
            .select('SELECT count(*) AS c FROM exercise_targets')
            .first['c'];
        db.close();
        notes.add(
          're-run: guarded steps skipped, user_version 8, values '
          'equal, targets $targets (no duplicates), integrity ok',
        );
        record('crash2 $label', notes);
      });

      test(
        '$label: user_version written inside the transaction (M3)',
        () async {
          final notes = <String>[];
          // Crash after the pragma, before commit: version rolls back too.
          var path = copyFixture('crash4');
          var (_, error) = await runMigration(
            path,
            TrialPlan(
              exercises: ex,
              trn020: trn,
              writeVersionInTransaction: true,
              crash: CrashPoint.afterVersionInTransaction,
            ),
          );
          expect(error, isA<SimulatedCrash>());
          expectFullyV7(path, notes, 'crash after PRAGMA user_version = 8');
          // Crash after commit: version and shape are both v8; no re-run.
          path = copyFixture('crash5');
          (_, error) = await runMigration(
            path,
            TrialPlan(
              exercises: ex,
              trn020: trn,
              writeVersionInTransaction: true,
              crash: CrashPoint.beforeUserVersion,
            ),
          );
          expect(error, isA<SimulatedCrash>());
          final reopen = TrialPlan(exercises: ex, trn020: trn);
          final (_, e2) = await runMigration(path, reopen);
          expect(e2, isNull);
          expect(reopen.laps, isEmpty, reason: 'no upgrade ran on re-open');
          expect(verifyMigrated(path, pre, cfg).failures, isEmpty);
          notes.add(
            'crash after commit: version 8 and v8 shape together; '
            're-open runs no migration; values equal',
          );
          record('crash_user_version_in_tx $label', notes);
        },
      );

      test(
        '$label: hot journal copied mid-transaction (process-kill model)',
        () async {
          final notes = <String>[];
          final path = copyFixture('crash3');
          final snap = '${tmp.path}/crash3_snapshot.sqlite';
          for (final f in [snap, '$snap-journal']) {
            if (File(f).existsSync()) File(f).deleteSync();
          }
          var journalBytes = -1;
          final (_, error) = await runMigration(
            path,
            TrialPlan(
              exercises: ex,
              trn020: trn,
              crash: CrashPoint.afterRebuild,
              midTransaction: () async {
                File(path).copySync(snap);
                final j = File('$path-journal');
                if (j.existsSync()) {
                  j.copySync('$snap-journal');
                  journalBytes = j.lengthSync();
                }
              },
            ),
            cachePages: 16,
          );
          expect(error, isA<SimulatedCrash>());
          expect(journalBytes, greaterThan(0), reason: 'a hot journal existed');
          expect(
            File(snap).readAsBytesSync().length ==
                    File(fixturePath).lengthSync() &&
                _sameBytes(File(snap), File(fixturePath)),
            isFalse,
            reason: 'the snapshot differs from the fixture before recovery',
          );
          notes.add(
            'snapshot differs from the fixture before recovery; '
            '$journalBytes journal bytes',
          );
          expectFullyV7(snap, notes, 'recovered snapshot');
          expect(File('$snap-journal').existsSync(), isFalse);
          final (_, rerunError) = await runMigration(
            snap,
            TrialPlan(exercises: ex, trn020: trn),
          );
          expect(rerunError, isNull);
          expect(verifyMigrated(snap, pre, cfg).failures, isEmpty);
          notes.add('re-run on the recovered snapshot: fully v8, values equal');
          record('crash3 $label', notes);
        },
      );
    }
  });

  group('foreign-key check (safeguard A, M2)', () {
    for (final (label, ex, trn) in combos.take(2)) {
      test('$label: an injected violation aborts and rolls back', () async {
        final notes = <String>[];
        final path = copyFixture('fk1');
        final (_, error) = await runMigration(
          path,
          TrialPlan(exercises: ex, trn020: trn, injectFkViolation: true),
        );
        expect(error.toString(), contains('foreign_key_check'));
        expectFullyV7(path, notes, 'after the failed check');
        final (_, rerunError) = await runMigration(
          path,
          TrialPlan(exercises: ex, trn020: trn),
        );
        expect(rerunError, isNull);
        expect(
          verifyMigrated(path, pre, Config(label, ex, trn)).failures,
          isEmpty,
        );
        notes.add('re-run without the violation: fully v8');
        record('fk_injected $label', notes);
      });
    }

    test(
      'a pre-existing orphan locks the user out unless the check is scoped',
      () async {
        final out = <String, Object?>{};
        const ex = ExercisesOption.rebuild;
        const trn = Trn020Option.rebuild;
        for (final scoped in [false, true]) {
          final path = copyFixture('fk2');
          final raw = sqlite3.open(path)
            ..execute(
              'INSERT INTO session_exercises (id, session_id, position, '
              "exercise_id) VALUES ('orphan-se', 'ws-missing', 0, 'ex-0001')",
            );
          raw.close();
          final (_, error) = await runMigration(
            path,
            TrialPlan(
              exercises: ex,
              trn020: trn,
              fkScope: scoped
                  ? const ['exercises', 'exercise_targets', 'session_sets']
                  : null,
            ),
          );
          final check = sqlite3.open(path);
          out[scoped
              ? 'scoped to rebuilt and new tables'
              : 'whole database'] = {
            'migration': error == null ? 'succeeded' : 'failed: $error',
            'user_version': check
                .select('PRAGMA user_version')
                .first
                .values
                .first,
            'orphans_left_in_database': check
                .select('PRAGMA foreign_key_check')
                .length,
          };
          check.close();
          if (!scoped) {
            expect(error.toString(), contains('foreign_key_check'));
          } else {
            expect(error, isNull);
          }
        }
        record('fk_preexisting_orphan', out);
      },
    );
  });

  group('backup compatibility', () {
    test('a v7 backup (format 2) restored into each v8 shape', () async {
      // Export with the production repository from the v7 fixture.
      final src = copyFixture('backup_src');
      final prod = AppDatabase(NativeDatabase(File(src)));
      final json = await DriftBackupRepository(
        prod,
        clock: FixedClock(DateTime.utc(2026, 11, 6)),
      ).exportJson();
      await prod.close();
      final backup = jsonDecode(json) as Map<String, Object?>;
      final tables = backup['tables']! as Map<String, Object?>;
      final out = <String, Object?>{
        'backup_format': backup['formatVersion'],
        'backup_bytes': json.length,
        'exercise_rows_in_backup': (tables['exercises']! as List).length,
        'supplied_in_backup': (tables['exercises']! as List)
            .where((r) => (r! as Map)['supplied'] == 1)
            .length,
        'sets_with_legacy_exertion_in_backup': (tables['session_sets']! as List)
            .where((r) {
              final m = r! as Map;
              return !exertionValid(m['exertion_scale'], m['exertion_value']);
            })
            .length,
      };
      for (final c in [
        configs[0],
        configs[1],
        configs[5],
        configs[6],
        configs[7],
      ]) {
        final path = copyFixture('backup_dst');
        final (_, error) = await runMigration(
          path,
          TrialPlan(exercises: c.exercises, trn020: c.trn020),
        );
        expect(error, isNull);
        final db = sqlite3.open(path)..execute('PRAGMA foreign_keys = ON');
        int count(String sql) => db.select(sql).first.values.first! as int;
        final nodesBefore = count('SELECT count(*) FROM anatomy_nodes');
        String outcome;
        // Same algorithm as DriftBackupRepository.importJson: delete every
        // table of the current schema (new v8 tables included), then insert
        // each row with the columns the table still has.
        db.execute('BEGIN');
        try {
          for (final t in [
            'exercise_targets',
            'anatomy_nodes',
            ...tables.keys.toList().reversed,
          ]) {
            db.execute('DELETE FROM "$t"');
          }
          for (final e in tables.entries) {
            final allowed = columnsOf(db, e.key).toSet();
            for (final row in (e.value! as List).cast<Map<String, Object?>>()) {
              final cols = [
                for (final k in row.keys)
                  if (allowed.contains(k)) k,
              ];
              db.execute(
                'INSERT INTO "${e.key}" (${cols.map((c) => '"$c"').join(',')}) '
                'VALUES (${List.filled(cols.length, '?').join(',')})',
                [for (final k in cols) row[k]],
              );
            }
          }
          db.execute('COMMIT');
          outcome = 'restore succeeded';
        } on SqliteException catch (e) {
          db.execute('ROLLBACK');
          outcome = 'restore failed and rolled back: ${e.message}';
        }
        out[c.label] = {
          'outcome': outcome,
          'exercises': count('SELECT count(*) FROM exercises'),
          'session_sets': count('SELECT count(*) FROM session_sets'),
          'exercise_targets': count('SELECT count(*) FROM exercise_targets'),
          'anatomy_nodes_before': nodesBefore,
          'anatomy_nodes_after': count('SELECT count(*) FROM anatomy_nodes'),
          'source_system': count(
            "SELECT count(*) FROM exercises WHERE source = 'system'",
          ),
          'integrity': db.select('PRAGMA integrity_check').first.values.first,
          'fk_violations': db.select('PRAGMA foreign_key_check').length,
        };
        db.close();
      }
      record('backup', out);
      for (final label in [configs[0].label, configs[1].label]) {
        final r = out[label]! as Map<String, Object?>;
        expect(r['outcome'], 'restore succeeded', reason: label);
        expect(r['exercise_targets'], 0, reason: label);
        expect(r['source_system'], 0, reason: label);
        expect(r['anatomy_nodes_before'], 19, reason: label);
        expect(r['anatomy_nodes_after'], 0, reason: label);
      }
      for (final c in [configs[5], configs[6], configs[7]]) {
        final r = out[c.label]! as Map<String, Object?>;
        expect(
          r['outcome'].toString(),
          startsWith('restore failed and rolled back'),
          reason: c.label,
        );
        expect(r['anatomy_nodes_after'], 19, reason: c.label);
        expect(r['exercise_targets'], 11908, reason: c.label);
        expect(r['session_sets'], 100000, reason: c.label);
      }
    });
  });
}

bool _sameBytes(File a, File b) {
  final x = a.readAsBytesSync();
  final y = b.readAsBytesSync();
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}
