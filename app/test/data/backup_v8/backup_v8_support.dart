import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/data/repositories/v8/drift_backup_repository_v8.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../migration_v8/migration_digest.dart' as digest;

/// Test support for WP 8 sub-stage 3b-7 (backup format 3, restore of
/// formats 1 to 3 into schema v8).

const backupTempPrefix = 'repforge_v8_3b7_';

/// The restore clock: the same instant as the 3b-4 tests, so blocks and
/// quarantine rows are stamped exactly as the migration stamps them.
final restoreClock = FixedClock(DateTime.utc(2026, 11, 6, 12));
const restoreStamp = '2026-11-06T12:00:00.000Z';

const restoreAppVersion = '0.8.0-test';
const restoreInstallLabel = 'install-3b7-test';

/// `restore-1`, `restore-2`, ...
String Function() countingRestoreIds([String prefix = 'restore']) {
  var n = 0;
  return () => '$prefix-${++n}';
}

BackupV8Config restoreConfig({
  String Function()? newRunId,
  Clock? clock,
  String appVersion = restoreAppVersion,
}) => BackupV8Config(
  clock: clock ?? restoreClock,
  appVersion: appVersion,
  installLabel: restoreInstallLabel,
  newRunId: newRunId ?? countingRestoreIds(),
);

/// A temporary directory deleted after [body].
Future<T> inBackupTempDir<T>(Future<T> Function(Directory dir) body) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final dir = Directory.systemTemp.createTempSync(backupTempPrefix);
  try {
    return await body(dir);
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// A fresh v8 database file (created with the bootstrap) and its
/// connection; [close] closes it.
final class V8File {
  V8File._(this.file, this.db);

  static Future<V8File> create(Directory dir, [String name = 'v8.sqlite']) =>
      open(File('${dir.path}/$name'));

  static Future<V8File> open(File file) async {
    final db = AppDatabaseV8(NativeDatabase(file));
    await db.customSelect('SELECT 1').get();
    return V8File._(file, db);
  }

  final File file;
  final AppDatabaseV8 db;

  DriftBackupRepositoryV8 repo({
    BackupV8Config? config,
    RestorePhaseProbe? phaseProbe,
  }) => DriftBackupRepositoryV8(
    db,
    config: config ?? restoreConfig(),
    phaseProbe: phaseProbe,
  );

  /// Per-table digests of every table (`sqlite_sequence` included), read on
  /// a second read-only connection.
  Map<String, Object?> digests() => readOnly(digest.tableDigests);

  T readOnly<T>(T Function(Database db) read) {
    final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      return read(raw);
    } finally {
      raw.close();
    }
  }

  Future<List<Map<String, Object?>>> rows(String sql) async => [
    for (final r in await db.customSelect(sql).get()) r.data,
  ];

  Future<int> count(String table) async =>
      (await rows('SELECT count(*) AS c FROM "$table"')).single['c']! as int;

  Future<int> foreignKeys() async =>
      (await rows('PRAGMA foreign_keys')).single.values.first! as int;

  Future<void> close() => db.close();
}

/// Digest of [table] only (rows, sha256).
String tableDigest(Map<String, Object?> digests, String table) =>
    jsonEncode(digests[table]);

/// The reference and catalogue tables (never deleted by a restore).
const referenceTables = [
  'content_providers',
  'anatomy_nodes',
  'movement_patterns',
  'equipment_items',
  'reference_labels',
  'catalogue_releases',
];

/// The report tables (merged by a restore).
const reportTables = [
  'migration_runs',
  'migration_report_counts',
  'migration_report_entries',
];

String readGolden(String path) => File(path).readAsStringSync();
