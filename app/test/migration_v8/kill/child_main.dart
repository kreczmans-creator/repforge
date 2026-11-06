import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import '../recovery/migration_under_test.dart';
import '../recovery/recovery_tools.dart';
import 'child_protocol.dart';

/// The process that the kill tests terminate with SIGKILL (WP 8 3b-6, WS5).
///
/// It opens a file database the way the app engine does
/// (`NativeDatabase.createInBackground`), which runs a registered
/// [MigrationUnderTest]. With `--stop-at` it blocks inside the migration at
/// that checkpoint after writing `READY`; the parent then kills it. Without
/// it, it runs to the end (the parent may kill it at a random moment).
///
/// Built by the parent with `dart build cli` (AOT, bundles the sqlite3 build
/// hook's library); `dart run` works as well. See `child_protocol.dart`.
Future<void> main(List<String> args) async {
  final Map<String, String> opts;
  try {
    opts = _parse(args);
  } on FormatException catch (e) {
    stderr.writeln('usage error: ${e.message}');
    exit(usageExitCode);
  }
  final migration = migrationUnderTest(opts['migration'] ?? 'historical');
  final file = File(opts['db'] ?? (throw ArgumentError('--db is required')));
  final stopAt = opts['stop-at'];
  final target = opts['target'] == null ? null : int.parse(opts['target']!);
  final foreground = opts.containsKey('foreground');
  final spill = opts.containsKey('spill');
  final maxBlock = Duration(
    seconds: int.parse(opts['max-block-seconds'] ?? '300'),
  );

  await _line(
    '$pidPrefix $pid sqlite=${sqlite3.version.libVersion} '
    'mode=${foreground ? 'foreground' : 'background'}',
  );

  late final GeneratedDatabase db;
  Future<String> userVersion() async {
    try {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      return '${row.read<int>('user_version')}';
    } on Object {
      return '?';
    }
  }

  Future<void> probe(MigrationCheckpoint c) async {
    final id = checkpointId(c.from, c.stage);
    await _line('$checkpointPrefix $id uv=${await userVersion()}');
    if (id == stopAt) {
      if (spill && c.stage != MigrationStage.committed) {
        await db.customStatement(_spillTable);
        await db.customStatement(_spillRows);
        await _line('$spilledPrefix $id');
      }
      await _line('$readyPrefix $id pid=$pid');
      await _blockUntilKilled(maxBlock);
    }
  }

  final setup = spill ? _smallCache : null;
  final executor = foreground
      ? NativeDatabase(file, setup: setup)
      : NativeDatabase.createInBackground(file, setup: setup);
  db = migration.open(executor, probe: probe, targetVersion: target);
  final watch = Stopwatch();
  try {
    await _line('$migratingPrefix ${migration.name} ${file.path}');
    watch.start();
    await db.customSelect('SELECT 1').get();
    watch.stop();
    await _line(
      '$donePrefix uv=${await userVersion()} ms=${watch.elapsedMilliseconds}',
    );
  } on Object catch (e) {
    await _line('$errorPrefix ${'$e'.split('\n').first}');
    await db.close();
    exit(errorExitCode);
  }
  await db.close();
  exit(doneExitCode);
}

/// `--spill`: a 10-page cache, and at the stop checkpoint ~256 pages of
/// scratch rows inside the step's open transaction. SQLite must spill dirty
/// pages (the step's work included) to the database file, after syncing a
/// journal with a valid header: the kill then leaves a hot journal that the
/// next open has to play back.
void _smallCache(Database raw) => raw.execute('PRAGMA cache_size = 10');

const _spillTable = 'CREATE TABLE ws5_force_spill (b BLOB)';
const _spillRows =
    'WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n '
    'WHERE i < 256) INSERT INTO ws5_force_spill SELECT zeroblob(3000) FROM n';

Future<void> _line(String line) async {
  stdout.writeln(line);
  await stdout.flush();
}

/// Blocks inside the open transaction. The kept [ReceivePort] holds the
/// process alive; after [max] the child gives up and exits by itself.
Future<void> _blockUntilKilled(Duration max) async {
  final keepAlive = ReceivePort();
  Timer(max, () {
    stderr.writeln('not killed within $max; exiting');
    exit(blockTimeoutExitCode);
  });
  await Completer<void>().future;
  keepAlive.close(); // never reached
}

Map<String, String> _parse(List<String> args) {
  const valued = {'migration', 'db', 'stop-at', 'target', 'max-block-seconds'};
  const flags = {'foreground', 'spill'};
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) throw FormatException('unexpected $a');
    final name = a.substring(2);
    if (flags.contains(name)) {
      out[name] = 'true';
    } else if (valued.contains(name)) {
      if (i + 1 >= args.length) throw FormatException('$a needs a value');
      out[name] = args[++i];
    } else {
      throw FormatException('unknown option $a');
    }
  }
  if (out['db'] == null) throw const FormatException('--db is required');
  return out;
}
