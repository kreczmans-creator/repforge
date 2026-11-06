import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:sqlite3/sqlite3.dart';

import '../harness_v7_db.dart';
import '../large/large_profile.dart';
import '../migration_digest.dart';
import '../timing/timing_harness.dart';
import 'migration_registry.dart';
import 'recovery_tools.dart';
import 'v7_expectations.dart';

/// WS5 (3B-ACC-01) shared recovery tools, in the normal suite (fast):
/// repeated migration writes nothing twice, failure injection leaves the
/// previous version and a retry completes (both engines), the crash window
/// completes, journal inspection, the state digest's sensitivity, and the
/// timing harness on the smoke profile.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final migration = historicalChain;

  group('repeated migration writes nothing twice', () {
    for (final (key, path) in allFixtures()) {
      test('fixture_$key: a second and third run change no byte', () async {
        await withWs5TempDir((dir) async {
          final db = copyDatabase(path, dir);
          expect(await runMigration(db, migration), isNull);
          expectV7ProductionResult(describeFile(db), key);
          final again = await rerunMigration(db, migration);
          expect(again.wroteNothing, isTrue, reason: '${again.toJson()}');
          final third = await rerunMigration(db, migration, background: true);
          expect(third.wroteNothing, isTrue, reason: '${third.toJson()}');
          expectV7ProductionResult(describeFile(db), key);
        });
      });
    }

    test('repeatMigration gives one digest for every run', () async {
      await withWs5TempDir((dir) async {
        final db = copyDatabase(fixturePath(2), dir);
        final digests = await repeatMigration(db, migration);
        expect(digests, hasLength(3));
        expect(digests.toSet(), hasLength(1));
        expect(digests.first.userVersion, 7);
      });
    });
  });

  group('failure injection', () {
    for (final background in [false, true]) {
      final engine = background ? 'background' : 'calling isolate';
      for (final (from, stage) in [
        (2, MigrationStage.stepStarted),
        (3, MigrationStage.workDone),
        (5, MigrationStage.versionWritten),
        (6, MigrationStage.committed),
      ]) {
        test(
          '$engine: failAt ${checkpointId(from, stage)} leaves '
          'v${versionAfterInterruption(from, stage)}; retry completes',
          () async {
            final refs = await referenceStates(fixturePath(2), from: 2);
            await withWs5TempDir((dir) async {
              final db = copyDatabase(fixturePath(2), dir);
              final error = await runMigration(
                db,
                migration,
                background: background,
                probe: failAt(from, stage),
              );
              expect(isInjectedFailure(error), isTrue, reason: '$error');
              if (!background) expect(error, isA<InjectedFailure>());
              final want = versionAfterInterruption(from, stage);
              expect(stateKeyOf(describeFile(db)), refs[want]);
              expect(await runMigration(db, migration), isNull);
              expectV7ProductionResult(describeFile(db), 'v2');
            });
          },
        );
      }
    }

    test('failAtIndex and failWhere hit the requested checkpoint', () async {
      await withWs5TempDir((dir) async {
        final db = copyDatabase(fixturePath(5), dir);
        final recorder = CheckpointRecorder();
        final error = await runMigration(
          db,
          migration,
          probe: combineProbes([recorder.probe, failAtIndex(5)]),
        );
        expect(error, isA<InjectedFailure>());
        expect(recorder.ids, [
          for (final (f, s) in chainCheckpoints(5, 7).take(6))
            checkpointId(f, s),
        ]);
        expect(stateDigest(db).userVersion, 6);

        final second = await runMigration(
          db,
          migration,
          probe: failWhere((c) => c.stage == MigrationStage.workDone),
        );
        expect((second! as InjectedFailure).checkpoint.from, 6);
        expect(stateDigest(db).userVersion, 6);
        expect(await runMigration(db, migration), isNull);
        expectV7ProductionResult(describeFile(db), 'v5');
      });
    });

    test('crash window: work committed, version reset; a re-run '
        'completes to the same state', () async {
      await withWs5TempDir((dir) async {
        final db = copyDatabase(fixturePath(6), dir);
        expect(await runMigration(db, migration), isNull);
        final done = stateDigest(db);
        setUserVersion(db, 6);
        expect(await runMigration(db, migration), isNull);
        expect(stateDigest(db), done);
        expectV7ProductionResult(describeFile(db), 'v6');
      });
    });
  });

  group('tools', () {
    test('checkpoint ids and chain checkpoints', () {
      expect(chainCheckpoints(5, 7), hasLength(8));
      expect(checkpointId(5, MigrationStage.workDone), '5:workDone');
      expect(parseCheckpointId('6:committed'), (6, MigrationStage.committed));
      expect(() => parseCheckpointId('6'), throwsFormatException);
      expect(versionAfterInterruption(4, MigrationStage.versionWritten), 4);
      expect(versionAfterInterruption(4, MigrationStage.committed), 5);
      expect(journalExpectedAfterKill(MigrationStage.stepStarted), isFalse);
      expect(journalExpectedAfterKill(MigrationStage.workDone), isTrue);
      expect(migrationUnderTest('historical'), same(historicalChain));
      expect(() => migrationUnderTest('nope'), throwsArgumentError);
      expect(median([3, 1, 2]), 2);
      expect(median([4, 1, 2, 3]), 2.5);
      expect(fnv64(''), 'cbf29ce484222325');
      expect(fnv64('a'), 'af63dc4c8601ec8c');
    });

    test('inspectJournal: absent, zero header, valid header', () async {
      await withWs5TempDir((dir) async {
        final db = File('${dir.path}/x.sqlite')..writeAsBytesSync([0]);
        expect(inspectJournal(db).exists, isFalse);
        final j = File('${db.path}-journal')
          ..writeAsBytesSync(List.filled(32, 0));
        expect(inspectJournal(db).exists, isTrue);
        expect(inspectJournal(db).isHot, isFalse);
        j.writeAsBytesSync([...journalMagic, ...List.filled(24, 0)]);
        expect(inspectJournal(db).isHot, isTrue);
        expect(inspectJournal(db).toJson()['bytes'], 32);
      });
    });

    test('the state digest sees one changed cell, a value type change and '
        'a schema change', () async {
      await withWs5TempDir((dir) async {
        final db = copyDatabase(fixturePath(7), dir);
        final base = stateDigest(db);
        expect(stateDigest(copyDatabase(db.path, dir, name: 'b.sqlite')), base);
        void exec(String sql) {
          final raw = sqlite3.open(db.path);
          try {
            raw.execute(sql);
          } finally {
            raw.close();
          }
        }

        exec("UPDATE settings SET value = value || '.' WHERE rowid = 1");
        final changed = stateDigest(db);
        expect(changed, isNot(base));
        expect(changed.schemaHash, base.schemaHash);
        exec(
          'UPDATE settings SET value = substr(value, 1, length(value) - 1) '
          'WHERE rowid = 1',
        );
        expect(stateDigest(db), base);
        // Same bytes, other storage type (a TEXT column keeps a BLOB).
        exec('UPDATE settings SET value = CAST(value AS BLOB) WHERE rowid = 1');
        expect(stateDigest(db), isNot(base));
        final db2 = copyDatabase(fixturePath(7), dir, name: 'c.sqlite');
        final raw = sqlite3.open(db2.path);
        try {
          raw.execute('CREATE INDEX ws5_extra ON settings (value)');
        } finally {
          raw.close();
        }
        expect(stateDigest(db2).schemaHash, isNot(base.schemaHash));
      });
    });
  });

  group('timing harness (smoke profile)', () {
    for (final background in [false, true]) {
      test(
        '3 runs + recovery/retry, ${background ? 'background' : 'calling '
                  'isolate'}: pass, stand-in stated',
        () async {
          await withWs5TempDir((dir) async {
            final result = await runTimingCampaign(
              workDir: dir,
              migration: migration,
              spec: const LargeProfileSpec.smoke(),
              background: background,
              recordV7Profile: false,
            );
            expect(result['outcome'], 'pass', reason: '$result');
            expect(result['standIn'], isTrue);
            expect('${result['standInNote']}', contains('STAND-IN'));
            expect(result['runs'], hasLength(3));
            expect(result['medianMs'], isA<double>());
            expect(result['sqliteVersion'], isNotEmpty);
            expect((result['recovery']! as Map)['outcome'], 'recovered');
          });
        },
      );
    }

    test('fewer than 3 repetitions are refused', () async {
      await expectLater(
        runTimingCampaign(
          workDir: Directory.systemTemp,
          migration: migration,
          repetitions: 2,
        ),
        throwsArgumentError,
      );
    });
  });

  test('no WS5 temporary directory is left behind', () {
    expect(
      Directory.systemTemp.listSync().where(
        (e) =>
            e.path.split(Platform.pathSeparator).last.startsWith(ws5TempPrefix),
      ),
      isEmpty,
    );
  });
}
