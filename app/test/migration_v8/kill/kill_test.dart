@Tags(['kill'])
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';

import '../harness_v7_db.dart';
import '../large/large_profile.dart';
import '../migration_digest.dart';
import '../recovery/migration_registry.dart';
import '../recovery/recovery_tools.dart';
import '../recovery/v7_expectations.dart';
import 'child_protocol.dart';
import 'kill_harness.dart';

/// WP 8 3b-6 (3B-ACC-01, WS5): real process kills during the migration.
///
/// A separate OS process (`child_main.dart`, built with `dart build cli`)
/// opens a copy of a database the way the app engine does and runs the
/// migration. The test kills it with SIGKILL and checks:
/// 1. the exit code is the SIGKILL code (-9);
/// 2. the journal next to the file: present and non-empty after a kill
///    inside a step that has written; with `--spill` (work forced into the
///    database file) a HOT journal with a valid header; none after a kill at
///    `stepStarted` or after `committed`;
/// 3. reopened, the state equals exactly ONE reference state: the previous
///    version, or the completed version after `committed` (never a mix);
///    with `--spill` the reopen rewrote the file (the journal was played
///    back);
/// 4. a new process runs the chain to the end, and the result equals the
///    frozen `expected_v7_digests.json` and `v7_strict_schema_3b3.json`;
/// 5. one more run writes nothing (same digest, same bytes, no step).
///
/// Deterministic kills: every checkpoint of every historical step on the
/// clean v1, v2, v5, v6 fixtures and the v2, v5, v6 orphan fixtures. Random
/// kills: 20 seeded moments during the large run (the v5-shaped large
/// profile through v5 → v7).
///
/// Stand-in: until the v7 → v8 migration (3b-4) exists, the migration under
/// test is the historical chain. 3b-4 registers its migration in
/// `migrationsUnderTest` and adds its fixtures and references here.
///
/// Tag `kill`, skipped by default (`dart_test.yaml`). Run with
/// `flutter test --run-skipped --tags kill --concurrency=1
/// test/migration_v8/kill/`.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final migration = historicalChain;

  late KillChildBinary binary;
  final records = <Map<String, Object?>>[];
  final randomRecords = <Map<String, Object?>>[];
  final startedAt = DateTime.now().toUtc();

  setUpAll(() async {
    binary = await KillChildBinary.prepare();
  });

  tearDownAll(() {
    binary.dispose();
    final distinct = {
      for (final r in records) '${r['checkpoint']} ${r['mode']}',
    };
    final report = {
      'startedAt': startedAt.toIso8601String(),
      'migration': migration.description,
      'standIn': migration.standIn,
      'childBuild': binary.mode,
      'platform': Platform.operatingSystemVersion,
      'deterministicKills': records.length,
      'distinctCheckpointModes': distinct.length,
      'distinctCheckpointModeList': distinct.toList()..sort(),
      'randomKills': randomRecords.where((r) => r['killed'] == true).length,
      'deterministic': records,
      'random': randomRecords,
    };
    final file = writeWs5Report('kill_report', report);
    // ignore: avoid_print, the kill suite reports through the test log
    print(
      'KILL_REPORT ${file.path} deterministic=${records.length} '
      'distinct=${distinct.length} random=${report['randomKills']}',
    );
  });

  // ---- Deterministic kill points -------------------------------------------

  const fixtureKeys = [
    'v1',
    'v2',
    'v5',
    'v6',
    'v2_orphans',
    'v5_orphans',
    'v6_orphans',
  ];

  for (final key in fixtureKeys) {
    final from = fixtureVersionOf(key);
    final path = fixturePath(from, orphans: key.endsWith('_orphans'));

    group('fixture_$key', () {
      late Map<int, String> refs;
      setUpAll(() async {
        refs = await referenceStates(path, from: from);
        // The completed reference is today's production v7 result.
        await withFixtureCopy(path, (copy) async {
          expect(await openWithChain(copy), isNull);
          expectV7ProductionResult(describeFile(copy), key);
        });
      });

      for (final (step, stage) in chainCheckpoints(from, 7)) {
        final id = checkpointId(step, stage);
        for (final spill in [
          false,
          if (journalExpectedAfterKill(stage)) true,
        ]) {
          final mode = spill ? 'spill' : 'app';
          test('SIGKILL at $id ($mode)', () async {
            await withWs5TempDir((dir) async {
              final db = copyDatabase(path, dir);
              final child = await binary.start([
                '--migration',
                migration.name,
                '--db',
                db.path,
                '--stop-at',
                id,
                if (spill) '--spill',
                '--max-block-seconds',
                '120',
              ]);
              addTearDown(child.ensureDead);
              final ready = await child.waitFor(readyPrefix);
              expect(ready, '$readyPrefix $id pid=${child.pid}');
              expect(child.lines.first, startsWith('$pidPrefix ${child.pid} '));
              expect(
                child.checkpoints,
                [
                  for (final (s, st) in chainCheckpoints(from, 7))
                    checkpointId(s, st),
                ].sublist(0, child.checkpoints.length),
              );
              expect(child.checkpoints.last, id);
              expect(
                child.checkpointVersionViolations(),
                isEmpty,
                reason: 'user_version at each checkpoint',
              );

              final kill = await child.sigkill();
              expect(kill.killed, isTrue);
              expect(kill.exitCode, sigkillExitCode);

              final journal = inspectJournal(db);
              if (journalExpectedAfterKill(stage)) {
                expect(journal.exists, isTrue, reason: 'journal');
                expect(journal.bytes, greaterThan(0));
                if (spill) expect(journal.isHot, isTrue, reason: 'hot');
              } else {
                expect(journal.isHot, isFalse);
              }
              final bytesAfterKill = sha256Hex(db.readAsBytesSync());

              final recovered = describeFile(db);
              // A hot journal is played back and deleted. A journal without
              // a valid header (the step's pages never reached the database
              // file) is not hot: SQLite ignores it and the next write
              // transaction replaces it.
              expect(inspectJournal(db).isHot, isFalse);
              if (journal.isHot) {
                expect(File('${db.path}-journal').existsSync(), isFalse);
              }
              final want = versionAfterInterruption(step, stage);
              expect(recovered['userVersion'], want);
              expect(recovered['integrityCheck'], 'ok');
              final state = stateKeyOf(recovered);
              final matches = [
                for (final e in refs.entries)
                  if (e.value == state) e.key,
              ];
              expect(matches, [want], reason: 'exactly one reference state');
              final rewritten =
                  sha256Hex(db.readAsBytesSync()) != bytesAfterKill;
              // The reopen changes the file exactly when it plays a hot
              // journal back.
              expect(rewritten, journal.isHot, reason: 'journal played back');

              final rerun = await binary.start([
                '--migration',
                migration.name,
                '--db',
                db.path,
              ]);
              addTearDown(rerun.ensureDead);
              final done = await rerun.waitFor(
                donePrefix,
                timeout: const Duration(minutes: 2),
              );
              expect(await rerun.process.exitCode, doneExitCode);
              expect(done, startsWith('$donePrefix uv=7 '));
              // The new process resumes at the recovered version (nothing to
              // do after a kill at the last commit).
              if (want < 7) {
                expect(rerun.checkpoints.first, '$want:stepStarted');
              } else {
                expect(rerun.checkpoints, isEmpty);
              }
              expect(rerun.checkpointVersionViolations(), isEmpty);
              expectV7ProductionResult(describeFile(db), key);

              final again = await rerunMigration(db, migration);
              expect(again.wroteNothing, isTrue, reason: '${again.toJson()}');

              records.add({
                'fixture': key,
                'checkpoint': id,
                'mode': mode,
                'exitCode': kill.exitCode,
                'journal': journal.toJson(),
                'recoveredVersion': want,
                'matchedReference': 'v$want',
                'recoveryRewroteFile': rewritten,
                'rerunCheckpoints': rerun.checkpoints.length,
                'final':
                    'equals expected_v7_digests.json[$key] and '
                    'v7_strict_schema_3b3.json',
                'repeatWroteNothing': again.wroteNothing,
              });
            });
          });
        }
      }
    });
  }

  // ---- Random-time kills during a large run ---------------------------------

  group('random-time kills during a large run '
      '(v${migration.inputVersion} profile, ${migration.name})', () {
    const kills = 20;
    const seed = 20261106;
    late Directory dir;
    late File start;
    late Map<int, StateDigest> refs;
    late int calibrationMs;
    final delaysMs = <int>[];

    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync(ws5TempPrefix);
      start = File('${dir.path}/large_input.sqlite');
      await buildLargeProfile(start.path, version: migration.inputVersion);
      refs = {migration.inputVersion: stateDigest(start)};
      for (
        var target = migration.inputVersion + 1;
        target <= migration.targetVersion;
        target++
      ) {
        final copy = copyDatabase(start.path, dir, name: 'ref$target.sqlite');
        expect(
          await runMigration(copy, migration, targetVersion: target),
          isNull,
        );
        refs[target] = stateDigest(copy);
        copy.deleteSync();
      }
      final complete = refs[migration.targetVersion]!;
      expect(complete.integrity, 'ok');
      expect(complete.userVersion, migration.targetVersion);

      // Calibration: an uninterrupted run in a child process. It must end
      // in the same state as the in-process run (and so is a cross-process
      // determinism check).
      final copy = copyDatabase(start.path, dir, name: 'calibration.sqlite');
      final child = await binary.start([
        '--migration',
        migration.name,
        '--db',
        copy.path,
      ]);
      addTearDown(child.ensureDead);
      final done = await child.waitFor(
        donePrefix,
        timeout: const Duration(minutes: 5),
      );
      expect(await child.process.exitCode, doneExitCode);
      calibrationMs = int.parse(done.split('ms=').last);
      expect(
        child.checkpoints,
        hasLength(4 * (migration.targetVersion - migration.inputVersion)),
      );
      expect(child.checkpointVersionViolations(), isEmpty);
      expect(stateDigest(copy), refs[migration.targetVersion]);
      copy.deleteSync();

      final rnd = Random(seed);
      for (var i = 0; i < kills; i++) {
        delaysMs.add(
          (calibrationMs * (0.02 + 0.93 * rnd.nextDouble())).round(),
        );
      }
      randomRecords.add({
        'calibrationMs': calibrationMs,
        'seed': seed,
        'references': {
          for (final e in refs.entries) 'v${e.key}': e.value.toString(),
        },
      });
    });

    tearDownAll(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    for (var i = 0; i < kills; i++) {
      test(
        'random kill #${i + 1}',
        timeout: const Timeout(Duration(minutes: 10)),
        () async {
          final db = copyDatabase(start.path, dir, name: 'kill$i.sqlite');
          try {
            final child = await binary.start([
              '--migration',
              migration.name,
              '--db',
              db.path,
            ]);
            addTearDown(child.ensureDead);
            await child.waitFor(migratingPrefix);
            await Future<void>.delayed(Duration(milliseconds: delaysMs[i]));
            final kill = await child.sigkill();
            final journal = inspectJournal(db);
            final seen = child.checkpoints;
            expect(
              child.checkpointVersionViolations(),
              isEmpty,
              reason: 'user_version at each checkpoint before the kill',
            );
            final committed = [
              for (final cp in seen)
                if (parseCheckpointId(cp) case (
                  final f,
                  MigrationStage.committed,
                ))
                  f + 1,
            ];
            final recovered = stateDigest(db);
            expect(recovered.integrity, 'ok');
            final matches = [
              for (final e in refs.entries)
                if (e.value == recovered) e.key,
            ];
            expect(matches, hasLength(1), reason: 'exactly one reference');
            final version = matches.single;
            expect(recovered.userVersion, version);
            if (committed.isNotEmpty) {
              expect(version, greaterThanOrEqualTo(committed.last));
            }
            if (kill.killed) {
              expect(kill.exitCode, sigkillExitCode);
            } else {
              expect(kill.exitCode, doneExitCode); // finished before the kill
            }

            final rerun = await binary.start([
              '--migration',
              migration.name,
              '--db',
              db.path,
            ]);
            addTearDown(rerun.ensureDead);
            final done = await rerun.waitFor(
              donePrefix,
              timeout: const Duration(minutes: 5),
            );
            expect(await rerun.process.exitCode, doneExitCode);
            expect(stateDigest(db), refs[migration.targetVersion]);
            expect(rerun.checkpointVersionViolations(), isEmpty);
            if (version < migration.targetVersion) {
              expect(rerun.checkpoints.first, '$version:stepStarted');
            } else {
              expect(rerun.checkpoints, isEmpty);
            }

            // Inside a step's transaction: the child was killed, it had not
            // reported the step's commit, and a journal was left behind.
            final midTransaction =
                kill.killed &&
                journal.exists &&
                seen.isNotEmpty &&
                !seen.last.endsWith(':committed');

            randomRecords.add({
              'midTransaction': midTransaction,
              'kill': i + 1,
              'delayMs': delaysMs[i],
              'killed': kill.killed,
              'exitCode': kill.exitCode,
              'lastCheckpoint': seen.isEmpty ? null : seen.last,
              'journal': journal.toJson(),
              'recoveredVersion': version,
              'rerunMs': int.parse(done.split('ms=').last),
              'final': 'equals the uninterrupted v7 reference',
            });
          } finally {
            for (final f in [db, File('${db.path}-journal')]) {
              if (f.existsSync()) f.deleteSync();
            }
          }
        },
      );
    }

    test('enough of the random moments were real kills inside a step', () {
      final real = randomRecords.where((r) => r['killed'] == true).length;
      expect(real, greaterThanOrEqualTo(kills - 2));
      final mid = randomRecords.where((r) => r['midTransaction'] == true);
      expect(mid.length, greaterThanOrEqualTo(kills ~/ 2));
      // ignore: avoid_print, the kill suite reports through the test log
      print('RANDOM_KILLS ${jsonEncode(randomRecords)}');
    });
  });
}
