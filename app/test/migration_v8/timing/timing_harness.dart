import 'dart:io';

import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:sqlite3/sqlite3.dart';

import '../large/large_profile.dart';
import '../recovery/migration_registry.dart';
import '../recovery/recovery_tools.dart';

/// Migration timing harness (WP 8 3b-9, 3B-ACC-01 WS5), shared by the host
/// test (`host_timing_test.dart`) and the device harness
/// (`integration_test/migration_v8_timing_test.dart`). Plain Dart.
///
/// Procedure (D04 2026-11-06, device timing):
/// 1. build the large profile once, in the shape the migration starts from
///    (`MigrationUnderTest.inputVersion`), in `workDir`; this file is the
///    restored start;
/// 2. `repetitions` (at least 3) normal runs, each on a fresh copy of the
///    start whose state digest is checked equal to the start's (identical
///    restored start), timed around the open that runs the migration;
/// 3. one recovery/retry run: a fresh copy, a failure injected at
///    `recoveryAt` (default: the last step's version write, the most work
///    lost), the rolled-back state checked, then a timed retry;
/// 4. every normal run and the retry must end in the same state.
///
/// The result records median and worst duration, database size, SQLite
/// version, engine and outcome, and says when the migration is a stand-in.
const timingHarnessVersion = 'ws5-timing/1';

/// Host reference digests of the D04 profile (`StateDigest.toString()`,
/// Linux host, 2026-11-06), by migration name: the restored start and the
/// end state. A device run that reports other values did not build or
/// migrate the same data. The `v7to8` entry (3b-4) starts from the v7 D04
/// profile ([hostV7ProfileDigest]); its end state comes from the
/// deterministic registry configuration (fixed clock and run id).
const hostReferenceDigests = <String, ({String start, String end})>{
  'historical': (start: 'v5 e18285a1cb9d27d2', end: 'v7 cb68ca68ae2be071'),
  'v7to8': (start: 'v7 602dbcd0601b46b7', end: 'v8 2f23e80e81fd7057'),
};

/// Host digest of the D04 profile built at v7 (the v7 → v8 input).
const hostV7ProfileDigest = 'v7 602dbcd0601b46b7';

bool _isD04(LargeProfileSpec s) =>
    s.exercises == 5000 &&
    s.sets == 100000 &&
    s.noPrimary == 303 &&
    s.seed == largeProfileSeed;

/// Median of [values] (mean of the two middle values for an even count).
double median(List<int> values) {
  final s = [...values]..sort();
  final n = s.length;
  if (n == 0) throw ArgumentError('no values');
  return n.isOdd ? s[n ~/ 2].toDouble() : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// SQLite version of the library this process uses.
String sqliteLibraryVersion() {
  final db = sqlite3.openInMemory();
  try {
    return db.select('SELECT sqlite_version() AS v').first['v']! as String;
  } finally {
    db.close();
  }
}

/// Runs the timing procedure and returns the result (JSON-ready).
///
/// [environment] is merged into the result as `environment` (device model,
/// OS, build mode: the caller knows them). [background] opens the files the
/// way the app engine does. [recordV7Profile] also builds the v7 profile and
/// records its facts when the input is not v7 (the stand-in case), so the
/// size of the real v8 input is on record. [log] receives progress lines.
Future<Map<String, Object?>> runTimingCampaign({
  required Directory workDir,
  required MigrationUnderTest migration,
  LargeProfileSpec spec = const LargeProfileSpec.d04(),
  int repetitions = 3,
  bool background = true,
  (int, MigrationStage)? recoveryAt,
  bool recordV7Profile = true,
  Map<String, Object?> environment = const {},
  void Function(String line)? log,
}) async {
  if (repetitions < 3) {
    throw ArgumentError.value(repetitions, 'repetitions', 'at least 3');
  }
  void say(String s) => log?.call(s);
  final at =
      recoveryAt ??
      (migration.targetVersion - 1, MigrationStage.versionWritten);
  final startedAt = DateTime.now().toUtc();

  final start = File('${workDir.path}/timing_start.sqlite');
  say(
    'building the v${migration.inputVersion} profile (${spec.exercises} '
    'exercises, ${spec.sets} sets)',
  );
  final facts = await buildLargeProfile(
    start.path,
    spec: spec,
    version: migration.inputVersion,
  );
  final startDigest = stateDigest(start);
  Map<String, Object?>? v7Facts;
  if (recordV7Profile && migration.inputVersion != 7) {
    final v7 = File('${workDir.path}/timing_v7_profile.sqlite');
    v7Facts = {
      ...(await buildLargeProfile(v7.path, spec: spec)).toJson(),
      'digest': stateDigest(v7).toString(),
      if (_isD04(spec)) 'hostDigest': hostV7ProfileDigest,
    };
    v7.deleteSync();
  }

  final runs = <Map<String, Object?>>[];
  StateDigest? endState;
  final run = File('${workDir.path}/timing_run.sqlite');
  for (var i = 1; i <= repetitions; i++) {
    final copy = copyDatabase(start.path, workDir, name: 'timing_run.sqlite');
    final restored = stateDigest(copy);
    if (restored != startDigest) {
      throw StateError('run $i: the restored start differs from the start');
    }
    final watch = Stopwatch()..start();
    final error = await runMigration(copy, migration, background: background);
    watch.stop();
    final after = stateDigest(copy);
    final ok =
        error == null &&
        after.userVersion == migration.targetVersion &&
        after.integrity == 'ok';
    runs.add({
      'run': i,
      'ms': watch.elapsedMilliseconds,
      'bytesAfter': copy.lengthSync(),
      'outcome': ok ? 'migrated' : 'failed: ${error ?? after.integrity}',
      'userVersion': after.userVersion,
      'digest': after.toString(),
    });
    say('run $i: ${watch.elapsedMilliseconds} ms, ${runs.last['outcome']}');
    endState ??= after;
    if (after != endState) {
      runs.last['outcome'] = 'different end state';
    }
  }

  // Recovery/retry: injected failure, rolled-back state, timed retry.
  final copy = copyDatabase(start.path, workDir, name: 'timing_run.sqlite');
  final failWatch = Stopwatch()..start();
  final failure = await runMigration(
    copy,
    migration,
    background: background,
    probe: failAt(at.$1, at.$2),
  );
  failWatch.stop();
  final afterFailure = stateDigest(copy);
  final expectedAfterFailure = versionAfterInterruption(at.$1, at.$2);
  final retryWatch = Stopwatch()..start();
  final retryError = await runMigration(
    copy,
    migration,
    background: background,
  );
  retryWatch.stop();
  final afterRetry = stateDigest(copy);
  final recovery = {
    'injectedAt': checkpointId(at.$1, at.$2),
    'failedAttemptMs': failWatch.elapsedMilliseconds,
    'failure': failure?.toString(),
    'failureType': failure?.runtimeType.toString(),
    'versionAfterFailure': afterFailure.userVersion,
    'expectedVersionAfterFailure': expectedAfterFailure,
    'integrityAfterFailure': afterFailure.integrity,
    'retryMs': retryWatch.elapsedMilliseconds,
    'retryError': retryError?.toString(),
    'retryEqualsNormalRuns': afterRetry == endState,
    'outcome':
        isInjectedFailure(failure) &&
            afterFailure.userVersion == expectedAfterFailure &&
            afterFailure.integrity == 'ok' &&
            retryError == null &&
            afterRetry == endState
        ? 'recovered'
        : 'NOT recovered',
  };
  say('recovery: ${recovery['outcome']} (retry ${recovery['retryMs']} ms)');
  for (final f in [copy, run, File('${copy.path}-journal')]) {
    if (f.existsSync()) f.deleteSync();
  }

  final durations = [for (final r in runs) r['ms']! as int];
  final allMigrated = runs.every((r) => r['outcome'] == 'migrated');
  return {
    'harness': timingHarnessVersion,
    'startedAt': startedAt.toIso8601String(),
    'migration': migration.name,
    'migrationDescription': migration.description,
    'standIn': migration.standIn,
    if (migration.standIn)
      'standInNote':
          'STAND-IN: the v7→v8 migration (3b-4) is not written yet; these '
          'figures time the historical chain '
          'v${migration.inputVersion}→v${migration.targetVersion} '
          'on the same profile. They are not '
          'v8 migration timings.',
    'environment': {
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'processors': Platform.numberOfProcessors,
      'dartVersion': Platform.version.split(' ').first,
      ...environment,
    },
    'sqliteVersion': sqliteLibraryVersion(),
    'engine': background
        ? 'NativeDatabase.createInBackground (app engine)'
        : 'NativeDatabase (calling isolate)',
    'journalMode': 'delete (SQLite default; the app does not change it)',
    'profile': {
      'spec': spec.toJson(),
      'input': facts.toJson(),
      'startDigest': startDigest.toString(),
      'v7Profile': ?v7Facts,
      'notInV7Profile':
          'reference bootstrap and migration report: written by the v7→v8 '
          'migration (3b-4), not part of a v7 database',
    },
    'repetitions': repetitions,
    'runs': runs,
    'medianMs': median(durations),
    'worstMs': durations.reduce((a, b) => a > b ? a : b),
    'bestMs': durations.reduce((a, b) => a < b ? a : b),
    'dbBytesBefore': facts.bytes,
    'dbBytesAfter': runs.last['bytesAfter'],
    'endState': endState.toString(),
    'hostReference': ?_hostReference(migration, spec, startDigest, endState),
    'recovery': recovery,
    'outcome': allMigrated && recovery['outcome'] == 'recovered'
        ? 'pass'
        : 'FAIL',
  };
}

Map<String, Object?>? _hostReference(
  MigrationUnderTest migration,
  LargeProfileSpec spec,
  StateDigest start,
  StateDigest? end,
) {
  final ref = hostReferenceDigests[migration.name];
  if (ref == null || !_isD04(spec)) return null;
  return {
    'start': ref.start,
    'end': ref.end,
    'startMatches': start.toString() == ref.start,
    'endMatches': end.toString() == ref.end,
  };
}
