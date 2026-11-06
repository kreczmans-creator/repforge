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
/// Until 3b-4 exists the migration is the historical chain (stand-in); the
/// JSON says so. Writes `build/migration_v8_ws5/host_timing.json`.
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

  for (final background in [true, false]) {
    final engine = background
        ? 'app engine (background isolate)'
        : 'calling isolate';
    test('timing, $engine: $repetitions runs + recovery/retry, '
        '${historicalChain.name}', () async {
      await withWs5TempDir((dir) async {
        final result = await runTimingCampaign(
          workDir: dir,
          migration: historicalChain,
          repetitions: repetitions,
          background: background,
          recordV7Profile: background,
          environment: {'host': true, 'buildMode': 'flutter test (JIT, host)'},
          // ignore: avoid_print, progress in the test log
          log: (l) => print('timing: $l'),
        );
        results[background ? 'background' : 'foreground'] = result;
        // ignore: avoid_print, the heavy suite reports through the test log
        print(
          'HOST_TIMING ${jsonEncode({
            'engine': result['engine'],
            'medianMs': result['medianMs'],
            'worstMs': result['worstMs'],
            'runs': [for (final r in result['runs']! as List) (r as Map)['ms']],
            'recovery': result['recovery'],
            'standIn': result['standIn'],
          })}',
        );
        expect(result['outcome'], 'pass', reason: jsonEncode(result));
        expect(result['standIn'], isTrue);
        // The pinned host digests: builder and migration are deterministic.
        final ref = result['hostReference']! as Map;
        expect(ref['startMatches'], isTrue, reason: '$ref');
        expect(ref['endMatches'], isTrue, reason: '$ref');
        expect(result['standInNote'], contains('STAND-IN'));
        final runs = result['runs']! as List;
        expect(runs, hasLength(repetitions));
        expect(runs.map((r) => (r as Map)['digest']).toSet(), hasLength(1));
        expect((result['recovery']! as Map)['outcome'], 'recovered');
        expect(
          Directory(dir.path).listSync().whereType<File>().map((f) => f.path),
          [endsWith('timing_start.sqlite')],
          reason: 'only the restored start is left',
        );
      });
    });
  }
}
