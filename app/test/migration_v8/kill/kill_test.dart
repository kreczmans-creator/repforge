@Tags(['kill'])
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:repforge/data/db/migration/v7_to_v8.dart'
    show FileMigrationRunLedger;
import 'package:sqlite3/sqlite3.dart' show OpenMode, sqlite3;

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
/// Migrations: the historical chain (v1, v2, v5, v6 and orphan fixtures) and,
/// since 3b-4, the v7 → v8 migration (`v7to8`: fixtures v7, v7 orphans, a
/// v5 start through the historical steps and a derived v7 copy with
/// unreadable aliases and classification; its completed reference is the
/// in-process run of the same deterministic migration). Random kills run for
/// both, each on its own large-profile input.
///
/// Tag `kill`, skipped by default (`dart_test.yaml`). Run with
/// `flutter test --run-skipped --tags kill --concurrency=1
/// test/migration_v8/kill/`.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const suites = <(String, List<String>)>[
    (
      'historical',
      ['v1', 'v2', 'v5', 'v6', 'v2_orphans', 'v5_orphans', 'v6_orphans'],
    ),
    // 3b-4: the v7 → v8 migration from v7, v7 orphans and a v5 start that
    // runs the historical steps first; since the decision baseline also a
    // derived v7 input with unreadable aliases and classification
    // ([damagedV7Input]).
    ('v7to8', ['v7', 'v7_orphans', 'v5', damagedV7Key]),
  ];

  late KillChildBinary binary;

  // v7 → v8 references by (input file, run id): the state of an
  // uninterrupted in-process run that names its run `runId` (the kill
  // child names a new run `run-<pid>`; R-07 evidence across a real kill).
  final v8Keys = <String, String>{};
  final v8Digests = <String, StateDigest>{};
  Future<T> withRunId<T>(String runId, Future<T> Function() body) async {
    final previous = registryRunId;
    registryRunId = runId;
    try {
      return await body();
    } finally {
      registryRunId = previous;
    }
  }

  Future<String> v8RefKey(String path, String runId) async =>
      v8Keys['$path|$runId'] ??= await withFixtureCopy(
        path,
        (copy) => withRunId(runId, () async {
          expect(await runMigration(copy, v7ToV8Migration), isNull);
          return stateKeyOf(describeFile(copy));
        }),
      );

  Future<StateDigest> v8RefDigest(
    File start,
    Directory dir,
    String runId,
  ) async {
    final cached = v8Digests[runId];
    if (cached != null) return cached;
    final copy = copyDatabase(start.path, dir, name: 'ref_$runId.sqlite');
    try {
      await withRunId(runId, () async {
        expect(await runMigration(copy, v7ToV8Migration), isNull);
      });
      return v8Digests[runId] = stateDigest(copy);
    } finally {
      for (final f in [copy, File('${copy.path}.v8-run-ledger.json')]) {
        if (f.existsSync()) f.deleteSync();
      }
    }
  }

  /// The pending run id in the ledger next to [db], if any.
  Future<String?> pendingRunId(File db) async {
    final ledger = File('${db.path}.v8-run-ledger.json');
    if (!ledger.existsSync()) return null;
    return (await FileMigrationRunLedger(
      ledger,
    ).read(7, 8, db.resolveSymbolicLinksSync()))?.runId;
  }

  String? migrationRunIdOf(File db) {
    final raw = sqlite3.open(db.path, mode: OpenMode.readOnly);
    try {
      final rows = raw.select(
        "SELECT id FROM migration_runs WHERE trigger_kind = 'migration'",
      );
      return rows.isEmpty ? null : rows.single['id'] as String?;
    } finally {
      raw.close();
    }
  }

  final records = <Map<String, Object?>>[];
  final randomRecords = <Map<String, Object?>>[];
  final startedAt = DateTime.now().toUtc();

  setUpAll(() async {
    binary = await KillChildBinary.prepare();
  });

  tearDownAll(() {
    binary.dispose();
    final distinct = {
      for (final r in records)
        '${r['migration']} ${r['checkpoint']} ${r['mode']}',
    };
    final report = {
      'startedAt': startedAt.toIso8601String(),
      'migrations': {
        for (final (name, _) in suites)
          name: {
            'description': migrationUnderTest(name).description,
            'standIn': migrationUnderTest(name).standIn,
          },
      },
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

  for (final (name, fixtureKeys) in suites) {
    for (final key in fixtureKeys) {
      final migration = migrationUnderTest(name);
      final target = migration.targetVersion;
      final from = fixtureVersionOf(key);
      // Lazy: the derived input is built only when its group runs.
      late final path = key == damagedV7Key
          ? damagedV7Input()
          : fixturePath(from, orphans: key.endsWith('_orphans'));

      group('${name == 'historical' ? '' : '$name '}fixture_$key', () {
        late Map<int, String> refs;
        setUpAll(() async {
          refs = await referenceStates(
            path,
            from: from,
            target: min(target, 7),
          );
          // The completed reference: today's production v7 result for the
          // historical chain; for v8 the in-process run of the same
          // deterministic migration (its content is checked by
          // v8_all_paths_test.dart).
          await withFixtureCopy(path, (copy) async {
            if (target == 7) {
              expect(await openWithChain(copy), isNull);
              expectV7ProductionResult(describeFile(copy), key);
            } else {
              expect(await runMigration(copy, migration), isNull);
              final done = describeFile(copy);
              expect(done['userVersion'], target);
              expect(done['integrityCheck'], 'ok');
              refs[target] = stateKeyOf(done);
              if (key == damagedV7Key) {
                // The derived input exercises the unreadable-data blocks.
                final raw = sqlite3.open(copy.path, mode: OpenMode.readOnly);
                try {
                  expect(
                    {
                      for (final r in raw.select(
                        "SELECT exercise_id || ':' || reason AS k "
                        'FROM exercise_blocks',
                      ))
                        r['k'],
                    },
                    containsAll([
                      'ex-row:invalidAliases',
                      'ex-bench:invalidAliases',
                      'ex-squat:invalidClassification',
                      'ex-dup:invalidClassification',
                      'ex-unmapped-enums:invalidClassification',
                    ]),
                  );
                } finally {
                  raw.close();
                }
              }
            }
          });
        });

        for (final (step, stage) in chainCheckpoints(from, target)) {
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
                expect(
                  child.lines.first,
                  startsWith('$pidPrefix ${child.pid} '),
                );
                expect(
                  child.checkpoints,
                  [
                    for (final (s, st) in chainCheckpoints(from, target))
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
                final candidates = {
                  ...refs,
                  // A v8 state after a kill at the commit carries the killed
                  // process's run id.
                  if (target == 8) 8: await v8RefKey(path, 'run-${child.pid}'),
                };
                final matches = [
                  for (final e in candidates.entries)
                    if (e.value == state) e.key,
                ];
                expect(matches, [want], reason: 'exactly one reference state');
                // The killed process wrote its run id to the ledger before
                // the step's first write (every v7 → v8 checkpoint but
                // stepStarted, which comes before the step's code).
                final killedWroteLedger =
                    target == 8 &&
                    step == 7 &&
                    stage != MigrationStage.stepStarted;
                if (target == 8) {
                  expect(
                    await pendingRunId(db),
                    killedWroteLedger ? 'run-${child.pid}' : isNull,
                    reason: 'ledger after the kill',
                  );
                }
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
                expect(done, startsWith('$donePrefix uv=$target '));
                // The new process resumes at the recovered version (nothing to
                // do after a kill at the last commit).
                if (want < target) {
                  expect(rerun.checkpoints.first, '$want:stepStarted');
                } else {
                  expect(rerun.checkpoints, isEmpty);
                }
                expect(rerun.checkpointVersionViolations(), isEmpty);
                if (target == 7) {
                  expectV7ProductionResult(describeFile(db), key);
                } else {
                  // R-07 across a real SIGKILL: a run the killed process
                  // started is resumed with its id (or, killed at the
                  // commit, kept); otherwise the re-run's own id.
                  final runId = killedWroteLedger
                      ? 'run-${child.pid}'
                      : 'run-${rerun.pid}';
                  expect(migrationRunIdOf(db), runId);
                  expect(
                    stateKeyOf(describeFile(db)),
                    await v8RefKey(path, runId),
                  );
                  // The run ledger next to the file is gone: cleared after
                  // the commit, or (killed at the commit) by the re-run's
                  // open of the v8 database.
                  expect(
                    File('${db.path}.v8-run-ledger.json').existsSync(),
                    isFalse,
                  );
                }

                final again = await rerunMigration(db, migration);
                expect(again.wroteNothing, isTrue, reason: '${again.toJson()}');

                records.add({
                  'migration': name,
                  'fixture': key,
                  'checkpoint': id,
                  'mode': mode,
                  'exitCode': kill.exitCode,
                  'journal': journal.toJson(),
                  'recoveredVersion': want,
                  'matchedReference': 'v$want',
                  'recoveryRewroteFile': rewritten,
                  'rerunCheckpoints': rerun.checkpoints.length,
                  if (target == 8) ...{
                    'killedPid': child.pid,
                    'rerunPid': rerun.pid,
                    'finalRunId': migrationRunIdOf(db),
                    'runIdReusedFromKilledProcess': killedWroteLedger,
                  },
                  'final': target == 7
                      ? 'equals expected_v7_digests.json[$key] and '
                            'v7_strict_schema_3b3.json'
                      : 'equals the uninterrupted v$target reference',
                  'repeatWroteNothing': again.wroteNothing,
                });
              });
            });
          }
        }
      });
    }
  }

  // ---- Random-time kills during a large run ---------------------------------

  for (final migration in [historicalChain, v7ToV8Migration]) {
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
        expect(
          stateDigest(copy),
          migration.targetVersion == 8
              ? await v8RefDigest(start, dir, 'run-${child.pid}')
              : refs[migration.targetVersion],
        );
        for (final f in [copy, File('${copy.path}.v8-run-ledger.json')]) {
          if (f.existsSync()) f.deleteSync();
        }

        final rnd = Random(seed);
        for (var i = 0; i < kills; i++) {
          delaysMs.add(
            (calibrationMs * (0.02 + 0.93 * rnd.nextDouble())).round(),
          );
        }
        randomRecords.add({
          'migration': migration.name,
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
              final isV8 = migration.targetVersion == 8;
              final pending = isV8 ? await pendingRunId(db) : null;
              final candidates = {
                ...refs,
                if (isV8 && recovered.userVersion == 8)
                  8: await v8RefDigest(start, dir, 'run-${child.pid}'),
              };
              final matches = [
                for (final e in candidates.entries)
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
              String? finalRunId;
              if (isV8) {
                finalRunId = migrationRunIdOf(db);
                // Killed after its ledger write: the re-run resumed the
                // killed process's run id; else the re-run's own.
                expect(
                  finalRunId,
                  pending != null || version == 8
                      ? 'run-${child.pid}'
                      : 'run-${rerun.pid}',
                );
                expect(
                  stateDigest(db),
                  await v8RefDigest(start, dir, finalRunId!),
                );
                expect(
                  File('${db.path}.v8-run-ledger.json').existsSync(),
                  isFalse,
                );
              } else {
                expect(stateDigest(db), refs[migration.targetVersion]);
              }
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
                'migration': migration.name,
                'midTransaction': midTransaction,
                'kill': i + 1,
                'delayMs': delaysMs[i],
                'killed': kill.killed,
                'exitCode': kill.exitCode,
                'lastCheckpoint': seen.isEmpty ? null : seen.last,
                'journal': journal.toJson(),
                'recoveredVersion': version,
                'rerunMs': int.parse(done.split('ms=').last),
                if (isV8) ...{
                  'pendingRunIdAfterKill': pending,
                  'finalRunId': finalRunId,
                  'runIdReusedFromKilledProcess':
                      finalRunId == 'run-${child.pid}',
                },
                'final':
                    'equals the uninterrupted v${migration.targetVersion} '
                    'reference',
              });
            } finally {
              for (final f in [
                db,
                File('${db.path}-journal'),
                File('${db.path}.v8-run-ledger.json'),
              ]) {
                if (f.existsSync()) f.deleteSync();
              }
            }
          },
        );
      }

      test('enough of the random moments were real kills inside a step', () {
        final mine = randomRecords.where(
          (r) => r['migration'] == migration.name,
        );
        final real = mine.where((r) => r['killed'] == true).length;
        expect(real, greaterThanOrEqualTo(kills - 2));
        final mid = mine.where((r) => r['midTransaction'] == true);
        expect(mid.length, greaterThanOrEqualTo(kills ~/ 2));
        // ignore: avoid_print, the kill suite reports through the test log
        print('RANDOM_KILLS ${migration.name} ${jsonEncode(mine.toList())}');
      });
    });
  }
}

/// Key of the derived v7 input of the `v7to8` kills.
const damagedV7Key = 'v7_damaged';

/// The frozen v7 fixture with unreadable data added to a **derived copy**
/// (the frozen file is never changed; review DB L3, decision baseline
/// 2026-11-06): unreadable `aliases_json` (not JSON; a non-string element)
/// and unreadable classification (a `type` in another case, an unknown
/// `category`), besides the fixture's own `ex-unmapped-enums`. Rebuilt
/// deterministically on every run under [ws5ReportDir].
String damagedV7Input() {
  final f = File('${ws5ReportDir().path}/inputs/fixture_$damagedV7Key.sqlite');
  f.parent.createSync(recursive: true);
  for (final x in [f, File('${f.path}-journal')]) {
    if (x.existsSync()) x.deleteSync();
  }
  File(fixturePath(7)).copySync(f.path);
  final db = sqlite3.open(f.path);
  try {
    for (final (column, value, id) in const [
      ('aliases_json', 'not json', 'ex-row'),
      ('aliases_json', '["Bench",2]', 'ex-bench'),
      ('type', 'Weighted', 'ex-squat'),
      ('category', 'Stretching', 'ex-dup'),
    ]) {
      db.execute('UPDATE exercises SET $column = ? WHERE id = ?', [value, id]);
      if (db.updatedRows != 1) throw StateError('no exercise $id');
    }
  } finally {
    db.close();
  }
  return f.path;
}
