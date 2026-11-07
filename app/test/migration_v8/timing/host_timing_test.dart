@Tags(['heavy'])
@Timeout(Duration(minutes: 20))
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import '../recovery/migration_registry.dart';
import '../recovery/recovery_tools.dart';
import '../recovery/v7_expectations.dart';
import 'timing_harness.dart';

/// WP 8 3b-9 (3B-ACC-01, WS5): host timing of the migration on the large
/// profile, at least three runs from an identical restored start plus a
/// recovery/retry run. Host figures are not device evidence: they show the
/// harness works and give a relative baseline. Device runs use
/// `integration_test/migration_v8_timing_test.dart` (`tool/device_timing.sh`).
///
/// Both registered migrations: the v7 → v8 migration (`v7to8`, from the v7
/// D04 profile; the code path the device harness runs: recovery at a mid-step
/// phase, the seed run, record counts and reconciled report) and the
/// historical chain (a stand-in, v5 → v7, kept as a second subject of the
/// harness); the JSON says which is a stand-in and that no host run is
/// device evidence. Writes `build/migration_v8_ws5/host_timing.json`.
/// `REPFORGE_TIMING_REPS` sets the repetitions (default 3, minimum 3).
///
/// Tag `heavy`, skipped by default.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final repetitions =
      int.tryParse(Platform.environment['REPFORGE_TIMING_REPS'] ?? '') ?? 3;
  final results = <String, Object?>{};

  tearDownAll(() {
    final f = writeWs5Report('host_timing', results);
    // ignore: avoid_print, the heavy suite reports through the test log
    print('HOST_TIMING_REPORT ${f.path}');
  });

  for (final migration in [v7ToV8Migration, historicalChain]) {
    for (final background in [true, false]) {
      final engine = background
          ? 'app engine (background isolate)'
          : 'calling isolate';
      test('timing, $engine: $repetitions runs + recovery/retry, '
          '${migration.name}', () async {
        await withWs5TempDir((dir) async {
          final result = await runTimingCampaign(
            workDir: dir,
            migration: migration,
            repetitions: repetitions,
            background: background,
            recordV7Profile: background,
            environment: {
              'host': true,
              'buildMode': 'flutter test (JIT, host)',
            },
            // ignore: avoid_print, progress in the test log
            log: (l) => print('timing: $l'),
          );
          results['${migration.name} '
                  '${background ? 'background' : 'foreground'}'] =
              result;
          final summary = {
            'migration': migration.name,
            'engine': result['engine'],
            'medianMs': result['medianMs'],
            'worstMs': result['worstMs'],
            'runs': [for (final r in result['runs']! as List) (r as Map)['ms']],
            'phaseMedianMs': result['phaseMedianMs'],
            'recovery': {
              for (final k in const [
                'injectedAt',
                'failedAttemptMs',
                'retryMs',
                'outcome',
              ])
                k: (result['recovery']! as Map)[k],
            },
            'seedRun': switch (result['seedRun']) {
              final Map<String, Object?> s => {
                'ms': s['ms'],
                'digest': s['digest'],
                'outcome': s['outcome'],
              },
              _ => null,
            },
            'endState': result['endState'],
            'standIn': result['standIn'],
          };
          // ignore: avoid_print, the heavy suite reports through the test log
          print('HOST_TIMING ${jsonEncode(summary)}');
          expect(result['outcome'], 'pass', reason: jsonEncode(result));
          expect(result['standIn'], migration.standIn);
          expect('${result['evidence']}', startsWith('not device evidence'));
          expect(result['failures'], isEmpty);
          // The pinned host digests: builder and migration are deterministic.
          final ref = result['hostReference']! as Map;
          expect(ref['startMatches'], isTrue, reason: '$ref');
          expect(ref['endMatches'], isTrue, reason: '$ref');
          if (migration.standIn) {
            expect(result['standInNote'], contains('STAND-IN'));
          } else {
            expect(result.containsKey('standInNote'), isFalse);
          }
          final runs = result['runs']! as List;
          expect(runs, hasLength(repetitions));
          expect(runs.map((r) => (r as Map)['digest']).toSet(), hasLength(1));
          final recovery = result['recovery']! as Map;
          expect(recovery['outcome'], 'recovered');
          final records = result['records']! as Map;
          if (migration.runsV8Step) {
            expect(recovery['injectedAt'], 'v8.${defaultV8RecoveryPhase.name}');
            expect(recovery['ledgerRunIdAfterFailure'], registryRunId);
            expect(recovery['ledgerLeftAfterRetry'], isFalse);
            expect(ref['seedRunEndMatches'], isTrue, reason: '$ref');
            final seed = result['seed']! as Map;
            expect(seed['matchesPin'], isTrue);
            expect(seed['readsByNormalRuns'], 0, reason: 'no seed setting');
            expect(seed['readsByRecoveryRuns'], 0, reason: 'no seed setting');
            expect(
              (result['seedRun']! as Map)['outcome'],
              startsWith('release 1 recorded'),
            );
            final migrated = records['migrated']! as Map;
            expect(migrated['exercises'], 5000);
            expect(migrated['sets'], 100000);
            expect((migrated['report']! as Map)['reconciled'], isTrue);
            // The 303 synthetic no-primary exercises take the blocked-record
            // path (IC-204).
            expect(
              (migrated['blockedExercisesByReason']! as Map)['noPrimaryTarget'],
              303,
            );
            expect(
              (result['phaseMedianMs']! as Map).keys,
              containsAll(<String>[
                '7:stepStarted',
                'v8.started',
                'v8.selfChecked',
                '7:committed',
                'closed',
              ]),
            );
          } else {
            expect(recovery['injectedAt'], '6:versionWritten');
          }
          expect(
            Directory(dir.path).listSync().whereType<File>().map((f) => f.path),
            [endsWith('timing_start.sqlite')],
            reason: 'only the restored start is left',
          );
        });
      });
    }
  }
}
