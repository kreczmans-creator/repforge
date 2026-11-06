import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:sqlite3/sqlite3.dart';

import '../harness_v7_db.dart' show strictSchema;
import 'migration_registry.dart';

/// Shared recovery, failure-injection and repeated-migration tools (WP 8
/// 3B-ACC-01, WS5). Plain Dart: the kill child, the host tests and the
/// on-device timing harness all use them. Nothing here changes a frozen
/// file; every database it touches is a copy in a temporary directory.

/// Prefix of the temporary directories made by the WS5 tools (distinct from
/// the 3b-1 and 3b-3 prefixes, whose "no temp file left" checks must not see
/// them).
const ws5TempPrefix = 'repforge_v8_ws5_';

/// Runs [body] with a new temporary directory; deletes it afterwards.
Future<T> withWs5TempDir<T>(Future<T> Function(Directory dir) body) async {
  final dir = Directory.systemTemp.createTempSync(ws5TempPrefix);
  try {
    return await body(dir);
  } finally {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// Copies [source] to `<dir>/<name>` and returns the copy. Any journal next
/// to the target from an earlier run is removed first.
File copyDatabase(String source, Directory dir, {String name = 'db.sqlite'}) {
  final target = File('${dir.path}/$name');
  for (final suffix in const ['-journal', '-wal', '-shm']) {
    final f = File('${target.path}$suffix');
    if (f.existsSync()) f.deleteSync();
  }
  File(source).copySync(target.path);
  return target;
}

// ---- Failure injection ----------------------------------------------------

/// The error a failure-injection probe throws.
final class InjectedFailure implements Exception {
  const InjectedFailure(this.checkpoint);

  final MigrationCheckpoint checkpoint;

  @override
  String toString() => 'InjectedFailure at $checkpoint';
}

/// Whether [error] is an [InjectedFailure]. With the app engine
/// (`createInBackground`) the probe runs in the calling isolate but drift
/// reports the migration's error through its isolate channel, which wraps
/// it (`DriftRemoteException`); its text still names the failure.
bool isInjectedFailure(Object? error) =>
    error is InjectedFailure ||
    (error != null && '$error'.startsWith('InjectedFailure at '));

/// A probe that throws [InjectedFailure] at the [occurrence]-th checkpoint
/// matching [where] (1-based) and does nothing elsewhere.
MigrationProbe failWhere(
  bool Function(MigrationCheckpoint c) where, {
  int occurrence = 1,
}) {
  var seen = 0;
  return (c) async {
    if (where(c) && ++seen == occurrence) throw InjectedFailure(c);
  };
}

/// A probe that throws at the step starting from [from], at [stage].
MigrationProbe failAt(int from, MigrationStage stage) =>
    failWhere((c) => c.from == from && c.stage == stage);

/// A probe that throws at the [index]-th checkpoint of the run (0-based).
MigrationProbe failAtIndex(int index) {
  var i = 0;
  return (c) async {
    if (i++ == index) throw InjectedFailure(c);
  };
}

/// Calls every probe in order.
MigrationProbe combineProbes(List<MigrationProbe> probes) => (c) async {
  for (final p in probes) {
    await p(c);
  }
};

/// Records every checkpoint it sees.
final class CheckpointRecorder {
  final List<MigrationCheckpoint> seen = [];

  MigrationProbe get probe =>
      (c) async => seen.add(c);

  /// `from:stage` of every checkpoint seen (see [checkpointId]).
  List<String> get ids => [for (final c in seen) checkpointId(c.from, c.stage)];
}

/// Stable id of a checkpoint: `<from>:<stage>`, e.g. `5:workDone`.
String checkpointId(int from, MigrationStage stage) => '$from:${stage.name}';

/// Parses a [checkpointId].
(int, MigrationStage) parseCheckpointId(String id) {
  final parts = id.split(':');
  if (parts.length != 2) throw FormatException('checkpoint id', id);
  return (int.parse(parts[0]), MigrationStage.values.byName(parts[1]));
}

/// Every checkpoint a run from [from] to [to] passes, in order, for a chain
/// whose steps each advance one version (true of the historical steps and
/// of the planned v7 → v8 step).
List<(int, MigrationStage)> chainCheckpoints(int from, int to) => [
  for (var v = from; v < to; v++)
    for (final stage in MigrationStage.values) (v, stage),
];

/// Version the database holds after a kill (or failure) at [stage] of the
/// step starting from [from]: the step's version once it committed, the
/// previous version before that.
int versionAfterInterruption(int from, MigrationStage stage) =>
    stage == MigrationStage.committed ? from + 1 : from;

/// Whether a kill at [stage] leaves a rollback journal to recover: true
/// once the step has written inside its open transaction (journal mode
/// DELETE, the app default). At `stepStarted` drift's deferred `BEGIN` has
/// written nothing; after `committed` the journal is gone.
bool journalExpectedAfterKill(MigrationStage stage) =>
    stage == MigrationStage.workDone || stage == MigrationStage.versionWritten;

/// Simulates the crash window of a step that committed its work but not its
/// version: sets `user_version` to [version] outside any migration.
void setUserVersion(File file, int version) {
  final db = sqlite3.open(file.path);
  try {
    db.execute('PRAGMA user_version = $version');
  } finally {
    db.close();
  }
}

// ---- Journal --------------------------------------------------------------

/// Magic bytes at the start of a valid rollback journal header.
const journalMagic = [0xd9, 0xd5, 0x05, 0xf9, 0x20, 0xa1, 0x63, 0xd7];

/// What lies next to a database file after a crash, read without opening
/// the database (opening it would roll a hot journal back).
final class JournalInfo {
  const JournalInfo({
    required this.exists,
    required this.bytes,
    required this.hasHeader,
  });

  /// `<db>-journal` exists.
  final bool exists;

  /// Its size in bytes (0 if absent).
  final int bytes;

  /// It starts with the rollback-journal magic: SQLite treats it as hot
  /// (no process holds a lock any more) and rolls it back at the next open.
  final bool hasHeader;

  /// A hot journal: present, non-empty, valid header.
  bool get isHot => exists && bytes > 0 && hasHeader;

  Map<String, Object?> toJson() => {
    'exists': exists,
    'bytes': bytes,
    'header': hasHeader,
    'hot': isHot,
  };
}

/// Inspects `<file>-journal` without touching the database.
JournalInfo inspectJournal(File file) {
  final j = File('${file.path}-journal');
  if (!j.existsSync()) {
    return const JournalInfo(exists: false, bytes: 0, hasHeader: false);
  }
  final bytes = j.readAsBytesSync();
  var header = bytes.length >= journalMagic.length;
  for (var i = 0; header && i < journalMagic.length; i++) {
    header = bytes[i] == journalMagic[i];
  }
  return JournalInfo(exists: true, bytes: bytes.length, hasHeader: header);
}

// ---- Fast whole-state digest ---------------------------------------------

/// A digest of a whole database state that is cheap enough for the large
/// profile (100,000 sets): `user_version`, `integrity_check`, the strict
/// schema and, per table, the row count and a 64-bit FNV-1a hash over the
/// sorted, type-tagged rows (independent of rowid and physical order).
///
/// For the small frozen fixtures the 3b-1 digests (`describeFile`) stay the
/// reference; this one is for databases built by the WS5 tools. Two states
/// are equal only if every table and the schema are equal, so a state equal
/// to one of a set of reference states is never a mix of two of them.
@immutable
final class StateDigest {
  const StateDigest({
    required this.userVersion,
    required this.integrity,
    required this.foreignKeyViolations,
    required this.schemaHash,
    required this.tables,
  });

  final int userVersion;
  final String integrity;
  final int foreignKeyViolations;
  final String schemaHash;

  /// Table name to `<count>#<hash>`.
  final Map<String, String> tables;

  /// Everything but integrity and foreign keys: what "the same state" means.
  String get identity => jsonEncode({
    'userVersion': userVersion,
    'schema': schemaHash,
    'tables': tables,
  });

  Map<String, Object?> toJson() => {
    'userVersion': userVersion,
    'integrity': integrity,
    'foreignKeyViolations': foreignKeyViolations,
    'schemaHash': schemaHash,
    'tables': tables,
  };

  @override
  bool operator ==(Object other) =>
      other is StateDigest && other.identity == identity;

  @override
  int get hashCode => identity.hashCode;

  @override
  String toString() => 'v$userVersion ${fnv64(identity)}';
}

/// 0xcbf29ce484222325 (64-bit FNV offset basis; native ints only).
const int _fnvOffset = (0xcbf29ce4 << 32) | 0x84222325;
const _fnvPrime = 0x100000001b3;

/// 64-bit FNV-1a of the UTF-16 code units of [s], as 16 hex digits.
String fnv64(String s) => _hex(_fold(_fnvOffset, s));

int _fold(int h, String s) {
  var x = h;
  for (final c in s.codeUnits) {
    x = (x ^ c) * _fnvPrime;
  }
  return x;
}

String _hex(int h) =>
    (h >>> 32).toRadixString(16).padLeft(8, '0') +
    (h & 0xffffffff).toRadixString(16).padLeft(8, '0');

String _cell(Object? v) => switch (v) {
  null => 'N',
  final int i => 'i$i',
  final double d => 'r$d',
  final String s => 't${s.length}:$s',
  final Uint8List b => 'b${base64.encode(b)}',
  _ => 'x$v',
};

/// [StateDigest] of [file]. Opening it rolls back a hot journal first.
StateDigest stateDigest(File file) {
  final db = sqlite3.open(file.path);
  try {
    final tables = <String, String>{};
    for (final t in db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND (name NOT LIKE 'sqlite_%' OR name = 'sqlite_sequence') "
      'ORDER BY name',
    )) {
      final name = t['name']! as String;
      final rows = <String>[];
      final rs = db.select('SELECT * FROM "$name"');
      final cols = rs.columnNames;
      for (final r in rs.rows) {
        final b = StringBuffer();
        for (var i = 0; i < cols.length; i++) {
          b
            ..write(cols[i])
            ..write('=')
            ..write(_cell(r[i]))
            ..write(';');
        }
        rows.add(b.toString());
      }
      rows.sort();
      var h = _fnvOffset;
      for (final r in rows) {
        h = _fold(_fold(h, r), '\n');
      }
      tables[name] = '${rows.length}#${_hex(h)}';
    }
    return StateDigest(
      userVersion: db.select('PRAGMA user_version').first.values.first! as int,
      integrity: db
          .select('PRAGMA integrity_check')
          .map((r) => r.values.first)
          .join('; '),
      foreignKeyViolations: db.select('PRAGMA foreign_key_check').length,
      schemaHash: fnv64(strictSchema(db).join('\n')),
      tables: tables,
    );
  } finally {
    db.close();
  }
}

// ---- Repeated migration ---------------------------------------------------

/// What a repeated run of a migration did to an already migrated file.
final class RerunReport {
  const RerunReport({
    required this.error,
    required this.checkpoints,
    required this.digestBefore,
    required this.digestAfter,
    required this.bytesUnchanged,
  });

  final Object? error;

  /// Checkpoints the repeated run passed (none: no step ran).
  final List<String> checkpoints;
  final StateDigest digestBefore;
  final StateDigest digestAfter;

  /// The file's bytes are identical after the repeated run.
  final bool bytesUnchanged;

  /// No error, no step, equal digests and identical bytes: the repeated
  /// migration wrote nothing twice.
  bool get wroteNothing =>
      error == null &&
      checkpoints.isEmpty &&
      digestBefore == digestAfter &&
      bytesUnchanged;

  Map<String, Object?> toJson() => {
    'error': error?.toString(),
    'checkpoints': checkpoints,
    'digestBefore': digestBefore.toString(),
    'digestAfter': digestAfter.toString(),
    'bytesUnchanged': bytesUnchanged,
    'wroteNothing': wroteNothing,
  };
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Runs [migration] on [file] again (it should already be at the target)
/// and reports whether that run wrote anything.
Future<RerunReport> rerunMigration(
  File file,
  MigrationUnderTest migration, {
  bool background = false,
}) async {
  final before = stateDigest(file);
  final bytes = file.readAsBytesSync();
  final recorder = CheckpointRecorder();
  final error = await runMigration(
    file,
    migration,
    probe: recorder.probe,
    background: background,
  );
  return RerunReport(
    error: error,
    checkpoints: recorder.ids,
    digestBefore: before,
    digestAfter: stateDigest(file),
    bytesUnchanged: _sameBytes(bytes, file.readAsBytesSync()),
  );
}

/// Runs [migration] on [file] [times] times in a row; returns the digest
/// after each run. A migration that writes nothing twice gives the same
/// digest every time.
Future<List<StateDigest>> repeatMigration(
  File file,
  MigrationUnderTest migration, {
  int times = 3,
}) async {
  final out = <StateDigest>[];
  for (var i = 0; i < times; i++) {
    final error = await runMigration(file, migration);
    if (error != null) {
      throw StateError('run ${i + 1} of $times failed: $error');
    }
    out.add(stateDigest(file));
  }
  return out;
}
