import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../test/migration_v8/large/large_profile.dart';
import '../test/migration_v8/recovery/migration_registry.dart';
import '../test/migration_v8/timing/timing_harness.dart';

/// WP 8 3b-9 (3B-ACC-01, WS5): migration timing on a real device.
///
/// Full run (owner's devices, `tool/device_timing.sh`):
///   flutter drive --profile --driver=test_driver/integration_test.dart
///     --target=integration_test/migration_v8_timing_test.dart
///     --dart-define=RUN_V8_TIMING=true
///     --dart-define=DEVICE_MODEL=... --dart-define=DEVICE_OS=...
/// builds the D04 profile (5,000 exercises, 100,000 sets) in a temporary
/// directory on the device, runs the migration 3 times from an identical
/// restored start plus a recovery/retry run, and reports device model, OS
/// version, SQLite version, database size, median and worst duration and
/// outcome through `IntegrationTestWidgetsFlutterBinding.reportData`
/// (written by the driver to `build/integration_response_data.json`) and as
/// `V8_TIMING_JSON` log lines.
///
/// Without `RUN_V8_TIMING=true` (CI's emulator job runs every file in
/// `integration_test/`) it runs the same procedure on the small smoke
/// profile, which takes seconds.
///
/// It never touches the app's database: everything happens in a new
/// temporary directory; the test asserts that directory is not the app's
/// support directory and that `repforge.sqlite` there is unchanged.
///
/// Until the v7→v8 migration (3b-4) exists the migration is the historical
/// chain (stand-in); the result says so.
const _runFull = bool.fromEnvironment('RUN_V8_TIMING');
const _deviceModel = String.fromEnvironment('DEVICE_MODEL');
const _deviceOs = String.fromEnvironment('DEVICE_OS');

/// Repetitions (`--dart-define=V8_TIMING_REPS=n`, at least 3; default 3).
const _repetitionsDefine = String.fromEnvironment('V8_TIMING_REPS');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'v8 migration timing (${_runFull ? 'FULL D04 profile' : 'smoke profile'})',
    timeout: const Timeout(Duration(minutes: 60)),
    (tester) async {
      // The production database file (lib/data/db/open_database.dart).
      final support = await getApplicationSupportDirectory();
      final realDb = File('${support.path}/repforge.sqlite');
      final realBefore = _fingerprint(realDb);

      // SQLite cannot use /tmp on Android; the app engine (drift_flutter)
      // points it at the cache directory, so the harness does the same.
      final cache = await getTemporaryDirectory();
      sqlite3.tempDirectory = cache.path;

      final work = Directory(
        '${cache.path}/repforge_v8_timing_${DateTime.now().microsecondsSinceEpoch}',
      )..createSync(recursive: true);
      expect(
        _isWithin(work.path, support.path),
        isFalse,
        reason: 'the work directory must not be the app support directory',
      );
      expect(work.path, isNot(contains('repforge.sqlite')));

      try {
        final result = await runTimingCampaign(
          workDir: work,
          migration: historicalChain,
          spec: _runFull
              ? const LargeProfileSpec.d04()
              : const LargeProfileSpec.smoke(),
          repetitions: int.tryParse(_repetitionsDefine) ?? 3,
          recordV7Profile: _runFull,
          environment: {
            'device': true,
            'deviceModel': _deviceModel.isEmpty ? 'not given' : _deviceModel,
            'deviceOs': _deviceOs.isEmpty ? 'not given' : _deviceOs,
            'buildMode': kReleaseMode
                ? 'release'
                : (kProfileMode ? 'profile' : 'debug'),
            'profile': _runFull ? 'D04 full' : 'smoke',
            'workDirectory': work.path,
            'appDatabaseUntouched': realDb.path,
          },
          log: (l) => debugPrint('V8_TIMING $l'),
        );

        // The app's real database is exactly as it was.
        expect(_fingerprint(realDb), realBefore);
        expect(
          work
              .listSync(recursive: true)
              .map((e) => e.path)
              .where((p) => p.endsWith('repforge.sqlite')),
          isEmpty,
        );

        binding.reportData = {'v8_timing': result};
        _printChunked(jsonEncode(result));
        expect(result['outcome'], 'pass');
        expect(result['standIn'], isTrue);
      } finally {
        work.deleteSync(recursive: true);
      }
    },
  );
}

/// Existence, size and modification time of [f] (null fields if absent).
String _fingerprint(File f) => f.existsSync()
    ? '${f.lengthSync()} ${f.lastModifiedSync().toIso8601String()}'
    : 'absent';

bool _isWithin(String child, String parent) {
  final c = Directory(child).absolute.path;
  final p = Directory(parent).absolute.path;
  return c == p || c.startsWith(p.endsWith('/') ? p : '$p/');
}

/// Device logs cut long lines; the JSON goes out in numbered chunks that
/// `tool/device_timing.sh` puts back together.
void _printChunked(String json) {
  const size = 700;
  final n = (json.length / size).ceil();
  for (var i = 0; i < n; i++) {
    final end = (i + 1) * size < json.length ? (i + 1) * size : json.length;
    // ignore: avoid_print, the result must reach the device log verbatim
    print('V8_TIMING_JSON ${i + 1}/$n ${json.substring(i * size, end)}');
  }
}
