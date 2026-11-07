import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:repforge/data/db/migration/v7_to_v8.dart' show V7ToV8Migration;
import 'package:repforge/domain/library/sha256_hex.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../test/migration_v8/large/large_profile.dart';
import '../test/migration_v8/recovery/migration_registry.dart';
import '../test/migration_v8/timing/timing_harness.dart';

/// WP 8 3b-9 (3B-ACC-01, WS5): timing of the v7 → v8 migration on a real
/// device.
///
/// Full run (owner's devices, `tool/device_timing.sh`):
///   flutter drive --profile --driver=test_driver/integration_test.dart
///     --target=integration_test/migration_v8_timing_test.dart
///     --dart-define=RUN_V8_TIMING=true
///     --dart-define=DEVICE_MODEL=... --dart-define=DEVICE_OS=...
/// builds the v7 D04 profile (5,000 exercises, 100,000 sets, 303 exercises
/// without a primary target; the same deterministic builder as the host)
/// in a new directory under the app's cache directory, then runs the
/// registered v7 → v8 migration (`v7to8`: `AppDatabaseV8`, the integrity
/// preflight, the v7 → v8 step) through the app engine (a background
/// isolate, as `drift_flutter` opens the app database):
/// - at least 3 normal runs, each from a fresh copy of the same restored
///   start (state digest checked);
/// - a recovery/retry run: a failure injected inside the step at
///   `v8.setsClassified` (mid-step), the rolled-back state checked, then a
///   timed retry;
/// - a seed run: a copy of the start with `seedExercisesVersion` = 1, so the
///   migration reads the bundled seed (R-30) and records release 1.
/// The seed bytes come from the app's asset bundle (`rootBundle`), the same
/// bytes the app ships; their SHA-256 is checked against the pinned v7-era
/// hash. Nothing in `lib/` is wired for this: the test passes the bytes to
/// the registry's v8 configuration.
///
/// The result (device model and OS, SQLite version, record counts, database
/// size, durations per run and per phase, median and worst, digests against
/// the host reference, outcome and errors) goes out through
/// `IntegrationTestWidgetsFlutterBinding.reportData` (written by the driver
/// to `build/integration_response_data.json`) and as `V8_TIMING_JSON` log
/// lines.
///
/// Without `RUN_V8_TIMING=true` (CI's emulator job runs every file in
/// `integration_test/`) it runs the same procedure on the small smoke
/// profile, which takes seconds. A smoke or debug run is never device
/// evidence (`evidence` says why).
///
/// It never touches the app's database: everything happens in a new
/// directory under the cache directory; the test asserts that directory is
/// not inside the app support directory and that `repforge.sqlite` there
/// (and its journal or WAL files) is unchanged.
const _runFull = bool.fromEnvironment('RUN_V8_TIMING');
const _deviceModel = String.fromEnvironment('DEVICE_MODEL');
const _deviceOs = String.fromEnvironment('DEVICE_OS');

/// Repetitions (`--dart-define=V8_TIMING_REPS=n`, at least 3; default 3).
const _repetitionsDefine = String.fromEnvironment('V8_TIMING_REPS');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'v7→v8 migration timing '
    '(${_runFull ? 'FULL D04 profile' : 'smoke profile'})',
    timeout: const Timeout(Duration(minutes: 60)),
    (tester) async {
      // Errors are reported, not only thrown: reportData (written by the
      // driver also on failure) and the V8_TIMING_JSON log carry them.
      final Map<String, Object?> result;
      try {
        result = await _run();
      } on Object catch (e, stack) {
        final report = <String, Object?>{
          'outcome': 'ERROR',
          'error': '$e',
          'stack': '$stack'.split('\n').take(20).join('\n'),
          'migration': v7ToV8Migration.name,
          'standIn': v7ToV8Migration.standIn,
          'profile': _runFull ? 'D04 full' : 'smoke',
          'deviceModel': _deviceModel,
          'deviceOs': _deviceOs,
        };
        binding.reportData = {'v8_timing': report};
        _printChunked(jsonEncode(report));
        rethrow;
      }
      binding.reportData = {'v8_timing': result};
      _printChunked(jsonEncode(result));
      expect(result['migration'], 'v7to8');
      expect(result['standIn'], isFalse);
      expect((result['seed']! as Map)['matchesPin'], isTrue);
      expect(result['outcome'], 'pass', reason: '${result['failures']}');
    },
  );
}

/// The timing procedure. Throws on a safety violation; returns the result,
/// whose `outcome` is `pass`, `FAIL` or `INCOMPLETE ...`.
Future<Map<String, Object?>> _run() async {
  // The production database file (lib/data/db/open_database.dart).
  final support = await getApplicationSupportDirectory();
  final realDb = File('${support.path}/repforge.sqlite');
  final realFiles = [
    for (final suffix in const ['', '-journal', '-wal', '-shm'])
      File('${realDb.path}$suffix'),
  ];
  final realBefore = [for (final f in realFiles) _fingerprint(f)];

  // SQLite cannot use /tmp on Android; the app engine (drift_flutter)
  // points it at the cache directory, so the harness does the same.
  final cache = await getTemporaryDirectory();
  sqlite3.tempDirectory = cache.path;

  // The bundled seed, exactly as the app ships it (R-10: the bytes, not a
  // re-serialisation). Loaded once; the migration's configuration gets it
  // through the registry (no production wiring).
  final asset = await rootBundle.load(registrySeedAsset);
  final seedBytes = Uint8List.sublistView(asset);
  registrySeedLoader = () async => seedBytes;
  registrySeedSource = 'rootBundle $registrySeedAsset (bundled asset)';
  final seedHash = sha256Hex(seedBytes);
  debugPrint(
    'V8_TIMING seed ${seedBytes.length} bytes, sha256 $seedHash, pinned '
    '${seedHash == V7ToV8Migration.v7SeedSha256 ? 'yes' : 'NO'}',
  );

  final stamp = DateTime.now().microsecondsSinceEpoch;
  final work = Directory('${cache.path}/repforge_v8_timing_$stamp');
  if (_isWithin(work.path, support.path) ||
      _isWithin(support.path, work.path) ||
      !_isWithin(work.path, cache.path) ||
      work.path.contains('repforge.sqlite')) {
    throw StateError(
      'unsafe work directory ${work.path} (app support: ${support.path}, '
      'cache: ${cache.path})',
    );
  }
  work.createSync(recursive: true);
  try {
    final result = await runTimingCampaign(
      workDir: work,
      migration: v7ToV8Migration,
      spec: _runFull
          ? const LargeProfileSpec.d04()
          : const LargeProfileSpec.smoke(),
      repetitions: int.tryParse(_repetitionsDefine) ?? 3,
      environment: {
        'device': true,
        'deviceModel': _deviceModel.isEmpty ? 'not given' : _deviceModel,
        'deviceOs': _deviceOs.isEmpty ? 'not given' : _deviceOs,
        'buildMode': kReleaseMode
            ? 'release'
            : (kProfileMode ? 'profile' : 'debug'),
        'profile': _runFull ? 'D04 full' : 'smoke',
        'workDirectory': work.path,
        'appSupportDirectory': support.path,
        'appDatabaseUntouched': realDb.path,
      },
      log: (l) => debugPrint('V8_TIMING $l'),
    );

    // The app's real database is exactly as it was.
    final realAfter = [for (final f in realFiles) _fingerprint(f)];
    if (!listEquals(realAfter, realBefore)) {
      throw StateError(
        'the app database ${realDb.path} changed: $realBefore → $realAfter',
      );
    }
    if (work
        .listSync(recursive: true)
        .any((e) => e.path.contains('repforge.sqlite'))) {
      throw StateError('a repforge.sqlite appeared in the work directory');
    }
    result['appDatabaseCheck'] =
        'unchanged (${realBefore.first}); work directory under the cache '
        'directory, outside the app support directory';
    // A full run without the device's model and OS is not evidence.
    if (_runFull &&
        (_deviceModel.isEmpty || _deviceOs.isEmpty) &&
        result['outcome'] == 'pass') {
      result['outcome'] =
          'INCOMPLETE: DEVICE_MODEL or DEVICE_OS not given '
          '(run through tool/device_timing.sh)';
    }
    return result;
  } finally {
    if (work.existsSync()) work.deleteSync(recursive: true);
  }
}

/// Existence, size and modification time of [f].
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
