import 'dart:io';

import 'package:repforge/data/db/migration/bootstrap_reference_v8.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:repforge/data/db/migration/v7_to_v8.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/library/sha256_hex.dart';
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
///    (`MigrationUnderTest.inputVersion`: v7 for the v7 → v8 migration), in
///    `workDir`; this file is the restored start;
/// 2. `repetitions` (at least 3) normal runs, each on a fresh copy of the
///    start whose state digest is checked equal to the start's (identical
///    restored start), timed around the open that runs the migration, with
///    the time of every checkpoint and v8 phase on the way;
/// 3. one recovery/retry run: a fresh copy, a failure injected at
///    `recoveryPhase` inside the v7 → v8 step (default
///    [defaultV8RecoveryPhase], mid-step) or at the chain checkpoint
///    `recoveryAt`, the rolled-back state checked (previous version,
///    integrity ok, the state equal to the start when no step committed,
///    run id kept in the ledger), then a timed retry;
/// 4. every normal run and the retry must end in the same state;
/// 5. for the v7 → v8 migration, one seed run: a copy of the start with the
///    v7 setting `seedExercisesVersion` = 1 added, so the migration reads
///    the bundled seed bytes and records release 1 (R-30 option b).
///
/// The result records every field the owner's decision asks for: durations
/// per run and per phase, median and worst, database size before and after,
/// SQLite version, record counts (input and migrated, blocked exercises by
/// reason, report entries and counts reconciled), digests against the host
/// reference, outcome and errors. It says when the migration is a stand-in
/// and whether the run can be device evidence at all (`evidence`).
const timingHarnessVersion = 'ws5-timing/2';

/// Host reference digests of the D04 profile (`StateDigest.toString()`,
/// Linux host), by migration name: the restored start and the end state. A
/// device run that reports other values did not build or migrate the same
/// data. The `v7to8` entry (3b-4) starts from the v7 D04 profile
/// ([hostV7ProfileDigest]); its end state comes from the deterministic
/// registry configuration (fixed clock and run id).
const hostReferenceDigests = <String, ({String start, String end})>{
  'historical': (start: 'v5 e18285a1cb9d27d2', end: 'v7 cb68ca68ae2be071'),
  // End digest updated for the stage 3b decision baseline (2026-11-06):
  // nullable release counts and `applied_at_source`, the three unreadable-
  // data block reasons (the D04 profile's unmapped "traps" secondaries now
  // block), R-33 retained entries. Previously `v8 2f23e80e81fd7057`.
  'v7to8': (start: 'v7 602dbcd0601b46b7', end: 'v8 7fc53371acfa16d7'),
};

/// Host digest of the D04 profile built at v7 (the v7 → v8 input).
const hostV7ProfileDigest = 'v7 602dbcd0601b46b7';

/// Host end digest of the seed run on the D04 profile (`v7to8`): the start
/// plus `seedExercisesVersion` = 1 ([seedRunSettingUpdatedAt]), migrated
/// with the bundled seed whose hash is the pinned v7-era value (Linux host,
/// 2026-11-07; the same from the app engine and the calling isolate).
const hostSeedRunEndDigest = 'v8 63595160a687407b';

/// Where the recovery run of the v7 → v8 migration injects its failure by
/// default: inside the step, after the exercises are mapped, rebuilt and
/// linked and the sets classified, before the sets are rebuilt. About half
/// of the step's work is done and rolled back.
const V8MigrationPhase defaultV8RecoveryPhase = V8MigrationPhase.setsClassified;

/// `settings.updated_at` of the `seedExercisesVersion` row the seed run
/// adds (the release 1 record copies it as `applied_at`).
const seedRunSettingUpdatedAt = '2025-03-01T09:00:00.000Z';

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
String sqliteLibraryVersion() => _sqliteSelect('sqlite_version()');

/// SQLite source id of the library this process uses.
String sqliteLibrarySourceId() => _sqliteSelect('sqlite_source_id()');

String _sqliteSelect(String expression) {
  final db = sqlite3.openInMemory();
  try {
    return db.select('SELECT $expression AS v').first['v']! as String;
  } finally {
    db.close();
  }
}

/// Milliseconds with one decimal from microseconds.
double _ms(int micros) => (micros / 100).round() / 10;

/// One timed open of a database that runs the migration.
final class _TimedRun {
  _TimedRun(this.error, this.micros, this.marks);

  final Object? error;
  final int micros;

  /// Checkpoints (`7:stepStarted`) and v8 phases (`v8.started`) with the
  /// time they were reached, in microseconds since the open began.
  final List<(String, int)> marks;

  int get ms => micros ~/ 1000;

  /// The run cut at each mark: each segment ends at the named mark; the
  /// last one (`closed`) covers the rest of the open, the first query and
  /// the close.
  List<({String until, int micros})> get segments {
    final out = <({String until, int micros})>[];
    var last = 0;
    for (final (label, at) in [...marks, ('closed', micros)]) {
      out.add((until: label, micros: at - last));
      last = at;
    }
    return out;
  }

  List<Map<String, Object?>> get phasesJson => [
    for (final s in segments) {'until': s.until, 'ms': _ms(s.micros)},
  ];
}

Future<_TimedRun> _timedRun(
  File file,
  MigrationUnderTest migration, {
  required bool background,
  MigrationProbe? fail,
  V8PhaseProbe? failPhase,
}) async {
  final marks = <(String, int)>[];
  final watch = Stopwatch()..start();
  final error = await runMigration(
    file,
    migration,
    background: background,
    probe: (c) async {
      marks.add((checkpointId(c.from, c.stage), watch.elapsedMicroseconds));
      if (fail != null) await fail(c);
    },
    phaseProbe: migration.runsV8Step
        ? (p) async {
            marks.add(('v8.${p.name}', watch.elapsedMicroseconds));
            if (failPhase != null) await failPhase(p);
          }
        : null,
  );
  watch.stop();
  return _TimedRun(error, watch.elapsedMicroseconds, marks);
}

/// Runs the timing procedure and returns the result (JSON-ready).
///
/// [environment] is merged into the result as `environment` (device model,
/// OS, build mode: the caller knows them; `device: true` marks a device
/// run). [background] opens the files the way the app engine does.
/// [recordV7Profile] also builds the v7 profile and records its facts when
/// the input is not v7 (the stand-in case). [seedRun] adds the seed run
/// (v7 → v8 migration only). [log] receives progress lines.
///
/// [adjustStart] is a test seam: it changes the start file after it is
/// built, before its digest is taken (the result then no longer matches a
/// host reference).
Future<Map<String, Object?>> runTimingCampaign({
  required Directory workDir,
  required MigrationUnderTest migration,
  LargeProfileSpec spec = const LargeProfileSpec.d04(),
  int repetitions = 3,
  bool background = true,
  (int, MigrationStage)? recoveryAt,
  V8MigrationPhase? recoveryPhase,
  bool recordV7Profile = true,
  bool seedRun = true,
  void Function(File start)? adjustStart,
  Map<String, Object?> environment = const {},
  void Function(String line)? log,
}) async {
  if (repetitions < 3) {
    throw ArgumentError.value(repetitions, 'repetitions', 'at least 3');
  }
  if (recoveryAt != null && recoveryPhase != null) {
    throw ArgumentError('recoveryAt or recoveryPhase, not both');
  }
  if (recoveryPhase != null && !migration.runsV8Step) {
    throw ArgumentError.value(
      recoveryPhase,
      'recoveryPhase',
      '${migration.name} has no v8 phases',
    );
  }
  void say(String s) => log?.call(s);
  final phase =
      recoveryPhase ??
      (recoveryAt == null && migration.runsV8Step
          ? defaultV8RecoveryPhase
          : null);
  final at =
      recoveryAt ??
      (migration.targetVersion - 1, MigrationStage.versionWritten);
  final startedAt = DateTime.now().toUtc();

  // The seed the migration would read (R-30): through the registry's
  // loader, so the device's asset bundle on a device.
  Map<String, Object?>? seed;
  if (migration.runsV8Step) {
    final bytes = await registrySeedLoader();
    final hash = sha256Hex(bytes);
    seed = {
      'source': registrySeedSource,
      'bytes': bytes.length,
      'sha256': hash,
      'pinnedV7Sha256': V7ToV8Migration.v7SeedSha256,
      'matchesPin': hash == V7ToV8Migration.v7SeedSha256,
    };
  }

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
  adjustStart?.call(start);
  final startDigest = stateDigest(start);
  final inputRecords = {
    ...recordSummary(start),
    if (migration.inputVersion == 7) 'measured': measureV7Profile(start.path),
  };
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

  final seedLoadsBefore = registrySeedLoads;
  final runs = <Map<String, Object?>>[];
  final timed = <_TimedRun>[];
  StateDigest? endState;
  Map<String, Object?>? endRecords;
  for (var i = 1; i <= repetitions; i++) {
    final copy = copyDatabase(start.path, workDir, name: 'timing_run.sqlite');
    final restored = stateDigest(copy);
    if (restored != startDigest) {
      throw StateError('run $i: the restored start differs from the start');
    }
    final t = await _timedRun(copy, migration, background: background);
    timed.add(t);
    final after = stateDigest(copy);
    final ok =
        t.error == null &&
        after.userVersion == migration.targetVersion &&
        after.integrity == 'ok';
    runs.add({
      'run': i,
      'ms': t.ms,
      'bytesAfter': copy.lengthSync(),
      'outcome': ok ? 'migrated' : 'failed: ${t.error ?? after.integrity}',
      'userVersion': after.userVersion,
      'digest': after.toString(),
      'phases': t.phasesJson,
    });
    say('run $i: ${t.ms} ms, ${runs.last['outcome']}');
    if (endState == null) {
      endState = after;
      endRecords = recordSummary(copy);
    } else if (after != endState) {
      runs.last['outcome'] = 'different end state';
    }
  }

  final seedReadsByNormalRuns = registrySeedLoads - seedLoadsBefore;

  // Recovery/retry: injected failure, rolled-back state, timed retry.
  final seedLoadsBeforeRecovery = registrySeedLoads;
  final copy = copyDatabase(start.path, workDir, name: 'timing_run.sqlite');
  final failed = await _timedRun(
    copy,
    migration,
    background: background,
    fail: phase == null ? failAt(at.$1, at.$2) : null,
    failPhase: phase == null ? null : failAtPhase(phase),
  );
  final afterFailure = stateDigest(copy);
  final expectedAfterFailure = phase == null
      ? versionAfterInterruption(at.$1, at.$2)
      : migration.targetVersion - 1;
  final ledgerKey = copy.resolveSymbolicLinksSync();
  final pending = migration.runsV8Step
      ? (await SidecarRunLedger().read(7, 8, ledgerKey))?.runId
      : null;
  final retry = await _timedRun(copy, migration, background: background);
  final afterRetry = stateDigest(copy);
  final ledgerAfterRetry = File('$ledgerKey.v8-run-ledger.json').existsSync();
  final recovered =
      isInjectedFailure(failed.error) &&
      afterFailure.userVersion == expectedAfterFailure &&
      afterFailure.integrity == 'ok' &&
      // Nothing committed: the state is exactly the start's.
      (expectedAfterFailure != migration.inputVersion ||
          afterFailure == startDigest) &&
      retry.error == null &&
      afterRetry == endState &&
      (!migration.runsV8Step ||
          (pending == registryRunId && !ledgerAfterRetry));
  final recovery = {
    'injectedAt': phase == null
        ? checkpointId(at.$1, at.$2)
        : 'v8.${phase.name}',
    'failedAttemptMs': failed.ms,
    'failure': failed.error?.toString(),
    'failureType': failed.error?.runtimeType.toString(),
    'versionAfterFailure': afterFailure.userVersion,
    'expectedVersionAfterFailure': expectedAfterFailure,
    'integrityAfterFailure': afterFailure.integrity,
    'stateAfterFailureEqualsStart': afterFailure == startDigest,
    if (migration.runsV8Step) ...{
      'ledgerRunIdAfterFailure': pending,
      'expectedLedgerRunId': registryRunId,
      'ledgerLeftAfterRetry': ledgerAfterRetry,
    },
    'retryMs': retry.ms,
    'retryError': retry.error?.toString(),
    'retryEqualsNormalRuns': afterRetry == endState,
    'failedAttemptPhases': failed.phasesJson,
    'retryPhases': retry.phasesJson,
    'outcome': recovered ? 'recovered' : 'NOT recovered',
  };
  say('recovery: ${recovery['outcome']} (retry ${recovery['retryMs']} ms)');
  final seedReadsByRecoveryRuns = registrySeedLoads - seedLoadsBeforeRecovery;

  // Seed run (v7 → v8 only): the start plus the applied-seed setting.
  Map<String, Object?>? seedResult;
  if (seedRun && migration.runsV8Step) {
    final f = copyDatabase(start.path, workDir, name: 'timing_seed.sqlite');
    final raw = sqlite3.open(f.path);
    try {
      raw.execute(
        'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)',
        [V7ToV8Migration.seedExercisesVersionKey, '1', seedRunSettingUpdatedAt],
      );
    } finally {
      raw.close();
    }
    final loads = registrySeedLoads;
    final t = await _timedRun(f, migration, background: background);
    final reads = registrySeedLoads - loads;
    final after = stateDigest(f);
    final db = sqlite3.open(f.path, mode: OpenMode.readOnly);
    final List<Map<String, Object?>> releases;
    final int r30;
    try {
      releases = [
        for (final r in db.select(
          'SELECT provider_id, "release", applied_at, applied_at_source, '
          'content_hash, inserted, updated, retired FROM catalogue_releases '
          'ORDER BY provider_id, "release"',
        ))
          Map.of(r),
      ];
      r30 =
          db.select(
                'SELECT count(*) AS c FROM migration_report_entries '
                'WHERE rule = ?',
                [MigrationRuleCodes.release1],
              ).first['c']!
              as int;
    } finally {
      db.close();
    }
    final recorded = releases.where(
      (r) =>
          r['provider_id'] == BootstrapReferenceV8.providerId &&
          r['release'] == 1 &&
          r['content_hash'] == V7ToV8Migration.v7SeedSha256 &&
          r['applied_at'] == seedRunSettingUpdatedAt,
    );
    final ok =
        t.error == null &&
        after.userVersion == migration.targetVersion &&
        after.integrity == 'ok' &&
        reads == 1 &&
        recorded.length == 1 &&
        r30 == 0;
    seedResult = {
      'setting':
          '${V7ToV8Migration.seedExercisesVersionKey} = 1, updated_at '
          '$seedRunSettingUpdatedAt (added to a copy of the start)',
      'ms': t.ms,
      'error': t.error?.toString(),
      'seedReads': reads,
      'catalogueReleases': releases,
      'r30WarningEntries': r30,
      'digest': after.toString(),
      'bytesAfter': f.lengthSync(),
      'phases': t.phasesJson,
      'outcome': ok
          ? 'release 1 recorded with the pinned hash'
          : 'FAIL: release 1 not recorded as expected',
    };
    say('seed run: ${t.ms} ms, ${seedResult['outcome']}');
  }
  // Only the restored start stays (copies, journals, ledgers removed).
  for (final e in workDir.listSync()) {
    if (e.path != start.path) e.deleteSync(recursive: true);
  }

  final durations = [for (final r in runs) r['ms']! as int];
  final phaseMedians = <String, double>{};
  for (final s in timed.first.segments) {
    final values = [
      for (final t in timed)
        for (final x in t.segments)
          if (x.until == s.until) x.micros,
    ];
    phaseMedians[s.until] = _ms(median(values).round());
  }
  final hostReference = _hostReference(
    migration,
    spec,
    startDigest,
    endState,
    seedResult,
  );

  final failures = <String>[
    for (final r in runs)
      if (r['outcome'] != 'migrated') 'run ${r['run']}: ${r['outcome']}',
  ];
  if (!recovered) failures.add('recovery/retry: NOT recovered');
  // The profile holds no `seedExercisesVersion` setting: its runs must not
  // read the seed, so they time the same work on every device. Only the
  // seed run reads it.
  if (migration.runsV8Step) {
    if (seedReadsByNormalRuns != 0) {
      failures.add(
        'the normal runs read the seed $seedReadsByNormalRuns times '
        '(expected 0: the profile holds no seedExercisesVersion setting)',
      );
    }
    if (seedReadsByRecoveryRuns != 0) {
      failures.add(
        'the recovery runs read the seed $seedReadsByRecoveryRuns times '
        '(expected 0: the profile holds no seedExercisesVersion setting)',
      );
    }
  }
  if (seed != null && seed['matchesPin'] != true) {
    failures.add(
      'the bundled seed hashes to ${seed['sha256']}, not the pinned v7-era '
      'hash ${V7ToV8Migration.v7SeedSha256}',
    );
  }
  if (seedResult != null && !'${seedResult['outcome']}'.startsWith('release')) {
    failures.add('seed run: ${seedResult['outcome']}');
  }
  if (endRecords?['report'] case {'reconciled': false, 'problems': final p}) {
    failures.add('report does not reconcile: $p');
  }
  if (hostReference != null) {
    if (hostReference['startMatches'] != true) {
      failures.add(
        'start digest $startDigest differs from the host reference '
        '${hostReference['start']}',
      );
    }
    if (hostReference['endMatches'] != true) {
      failures.add(
        'end digest $endState differs from the host reference '
        '${hostReference['end']}',
      );
    }
    if (hostReference['seedRunEndMatches'] == false) {
      failures.add(
        'seed run digest ${seedResult?['digest']} differs from the host '
        'reference ${hostReference['seedRunEnd']}',
      );
    }
  }

  return {
    'harness': timingHarnessVersion,
    'startedAt': startedAt.toIso8601String(),
    'migration': migration.name,
    'migrationDescription': migration.description,
    'standIn': migration.standIn,
    if (migration.standIn)
      'standInNote':
          'STAND-IN: these figures time the historical chain '
          'v${migration.inputVersion}→v${migration.targetVersion} on the '
          'same profile, not the v7→v8 migration. They are not v8 '
          'migration timings and not 3b-9 evidence.',
    'evidence': _evidence(migration, spec, environment),
    'environment': {
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'processors': Platform.numberOfProcessors,
      'dartVersion': Platform.version.split(' ').first,
      ...environment,
    },
    'sqliteVersion': sqliteLibraryVersion(),
    'sqliteSourceId': sqliteLibrarySourceId(),
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
          'migration (3b-4), not part of a v7 database; see records.migrated',
    },
    'seed': ?(seed == null
        ? null
        : {
            ...seed,
            'readsByNormalRuns': seedReadsByNormalRuns,
            'readsByRecoveryRuns': seedReadsByRecoveryRuns,
          }),
    'records': {'input': inputRecords, 'migrated': endRecords},
    'repetitions': repetitions,
    'runs': runs,
    'medianMs': median(durations),
    'worstMs': durations.reduce((a, b) => a > b ? a : b),
    'bestMs': durations.reduce((a, b) => a < b ? a : b),
    'phaseMedianMs': phaseMedians,
    'dbBytesBefore': facts.bytes,
    'dbBytesAfter': runs.last['bytesAfter'],
    'endState': endState.toString(),
    'hostReference': ?hostReference,
    'recovery': recovery,
    'seedRun': ?seedResult,
    'failures': failures,
    'outcome': failures.isEmpty ? 'pass' : 'FAIL',
  };
}

String _evidence(
  MigrationUnderTest migration,
  LargeProfileSpec spec,
  Map<String, Object?> environment,
) {
  if (migration.standIn) {
    return 'not device evidence: stand-in (${migration.name}), not the '
        'v7→v8 migration';
  }
  if (environment['device'] != true) {
    return 'not device evidence: host run (relative baseline only)';
  }
  if (environment['buildMode'] != 'profile') {
    return 'not device evidence: ${environment['buildMode']} build '
        '(device timings need profile mode)';
  }
  if (!_isD04(spec)) return 'not device evidence: smoke profile';
  return 'device run of the v7→v8 migration on the D04 profile: 3b-9 '
      'evidence only once the owner records it with the device '
      'specifications and accepts it';
}

Map<String, Object?>? _hostReference(
  MigrationUnderTest migration,
  LargeProfileSpec spec,
  StateDigest start,
  StateDigest? end,
  Map<String, Object?>? seedResult,
) {
  final ref = hostReferenceDigests[migration.name];
  if (ref == null || !_isD04(spec)) return null;
  return {
    'start': ref.start,
    'end': ref.end,
    'startMatches': start.toString() == ref.start,
    'endMatches': end.toString() == ref.end,
    if (seedResult != null) ...{
      'seedRunEnd': hostSeedRunEndDigest,
      'seedRunEndMatches': seedResult['digest'] == hostSeedRunEndDigest,
    },
  };
}

/// Record counts of the database [file] (read only): rows per table and,
/// for a v8 database, exercises and sets, blocked exercises by reason,
/// catalogue releases and the migration report per run, reconciled
/// (outcomes sum to the records examined; entries per action equal the
/// stored count).
Map<String, Object?> recordSummary(File file) {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    final rowCounts = <String, int>{
      for (final t in db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      ))
        t['name']! as String:
            db.select('SELECT count(*) AS c FROM "${t['name']}"').first['c']!
                as int,
    };
    final out = <String, Object?>{
      'exercises': rowCounts['exercises'],
      'sets': rowCounts['session_sets'],
      'legacyQuarantine': rowCounts['legacy_quarantine'],
      'rowCounts': rowCounts,
    };
    if (rowCounts.containsKey('exercise_blocks')) {
      Map<String, int> byReason(String what) => {
        for (final r in db.select(
          'SELECT reason, $what AS c FROM exercise_blocks '
          'WHERE resolved_at IS NULL GROUP BY reason ORDER BY reason',
        ))
          r['reason']! as String: r['c']! as int,
      };
      out['blockedExercises'] =
          db
                  .select(
                    'SELECT count(DISTINCT exercise_id) AS c FROM '
                    'exercise_blocks WHERE resolved_at IS NULL',
                  )
                  .first['c']!
              as int;
      out['blockedExercisesByReason'] = byReason('count(DISTINCT exercise_id)');
      out['blockRowsByReason'] = byReason('count(*)');
    }
    if (rowCounts.containsKey('catalogue_releases')) {
      out['catalogueReleases'] = rowCounts['catalogue_releases'];
      out['referenceBootstrap'] = {
        for (final t in const [
          'content_providers',
          'anatomy_nodes',
          'movement_patterns',
          'equipment_items',
          'reference_labels',
        ])
          t: rowCounts[t],
      };
    }
    if (rowCounts.containsKey('migration_runs')) {
      out['report'] = _reportSummary(db);
    }
    return out;
  } finally {
    db.close();
  }
}

Map<String, Object?> _reportSummary(Database db) {
  final problems = <String>[];
  final runs = <Map<String, Object?>>[];
  for (final run in db.select(
    'SELECT id, trigger_kind, from_version, to_version FROM migration_runs '
    'ORDER BY id',
  )) {
    final id = run['id']! as String;
    final counts = <String, Map<String, Map<String, int>>>{};
    for (final r in db.select(
      'SELECT source_table, dimension, code, record_count FROM '
      'migration_report_counts WHERE run_id = ?',
      [id],
    )) {
      counts
              .putIfAbsent(r['source_table']! as String, () => {})
              .putIfAbsent(r['dimension']! as String, () => {})[r['code']!
              as String] =
          r['record_count']! as int;
    }
    final entries = <String, Map<String, int>>{};
    var total = 0;
    for (final r in db.select(
      'SELECT source_table, disposition, count(*) AS c FROM '
      'migration_report_entries WHERE run_id = ? '
      'GROUP BY source_table, disposition',
      [id],
    )) {
      final n = r['c']! as int;
      total += n;
      entries.putIfAbsent(
        r['source_table']! as String,
        () => {},
      )[r['disposition']! as String] = n;
    }
    for (final MapEntry(key: table, value: dims) in counts.entries) {
      final category = dims['category'] ?? const {};
      final examined = category['examined'] ?? 0;
      final outcomes = [
        for (final o in ReportCategory.outcomes) category[o.code] ?? 0,
      ].fold(0, (a, b) => a + b);
      if (outcomes != examined) {
        problems.add('$id $table: outcomes $outcomes, examined $examined');
      }
      for (final a in ReportAction.values) {
        final stored = dims['disposition']?[a.name] ?? 0;
        final listed = entries[table]?[a.name] ?? 0;
        if (stored != listed) {
          problems.add('$id $table ${a.name}: $listed entries, count $stored');
        }
      }
    }
    for (final table in entries.keys) {
      if (!counts.containsKey(table)) {
        problems.add('$id $table: entries without counts');
      }
    }
    runs.add({
      'id': id,
      'triggerKind': run['trigger_kind'],
      'from': run['from_version'],
      'to': run['to_version'],
      'entries': total,
      'entriesByTable': entries,
      'counts': counts,
    });
  }
  return {
    'runs': runs,
    'entries': [for (final r in runs) r['entries']! as int]
        .fold<int>(0, (a, b) => a + b),
    'reconciled': problems.isEmpty,
    'problems': problems,
  };
}
