import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/data/repositories/v8/drift_backup_repository_v8.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
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

/// A v8 database with every kind of v8 data: the format 2 v7 golden
/// restored (exercises, blocks, quarantine, report runs `rich-1`), plus rows
/// the golden cannot hold (attributes, a role override, a note without an
/// override, patterns, names, user state, labels, a release record).
Future<V8File> richV8(V8File v8) async {
  final r = await v8
      .repo(config: restoreConfig(newRunId: countingRestoreIds('rich')))
      .importJson(readGolden(digest.goldenFormat2Path()));
  if (r is! Ok) throw StateError('rich restore failed: $r');
  for (final sql in richRows) {
    await v8.db.customStatement(sql);
  }
  return v8;
}

/// Rows a v7 backup cannot hold.
final List<String> richRows = [
  _sql([
    'INSERT INTO movement_patterns (id, parent_id, sort_order, provider_id)',
    "VALUES ('mp-push', NULL, 10, 'repforge')",
  ]),
  _sql([
    'INSERT INTO movement_patterns (id, parent_id, sort_order, provider_id)',
    "VALUES ('mp-horizontal-push', 'mp-push', 10, 'repforge')",
  ]),
  _sql([
    'INSERT INTO reference_labels (kind, id, locale, label) VALUES',
    "('equipment', 'barbell', 'en-GB', 'Barbell')",
  ]),
  _sql([
    'INSERT INTO catalogue_releases (provider_id, "release", applied_at,',
    'content_hash_algorithm, content_hash_encoding, content_hash,',
    "inserted, updated, retired, app_version) VALUES ('repforge', 1,",
    "'$restoreStamp', 'sha256', 'hex-lower', '${'a' * 64}', 0, 0, 0, NULL)",
  ]),
  _sql([
    'INSERT INTO exercises (id, created_at, updated_at, deleted_at, name,',
    'type, category, aliases_json, search_key, copied_from_id, archived,',
    'source, provider_id, revision, mechanics, laterality, difficulty,',
    'retired_at, angle, arm_position, body_position, grip, grip_width,',
    'knee_position, stance) VALUES',
    "('ex-rich', '$restoreStamp', '$restoreStamp', NULL,",
    '\'Incline press\', \'weighted\', \'push\', \'["Incline"]\',',
    "'incline press incline', 'lib-deadlift', 0, 'user', NULL, NULL,",
    "'compound', 'bilateral', 'beginner', NULL, 'incline', 'besideBody',",
    "'lying', 'pronated', 'standard', 'bent', 'standard')",
  ]),
  _sql([
    'INSERT INTO exercise_targets (exercise_id, node_id, role, ordinal)',
    "VALUES ('ex-rich', 'chest', 'primary', 0),",
    "('ex-rich', 'frontDelts', 'secondary', 1)",
  ]),
  _sql([
    'INSERT INTO exercise_patterns (exercise_id, pattern_id, ordinal) VALUES',
    "('ex-rich', 'mp-horizontal-push', 0)",
  ]),
  _sql([
    'INSERT INTO exercise_equipment (exercise_id, equipment_id, ordinal,',
    "role_override, override_note) VALUES ('ex-rich', 'barbell', 0,",
    "'support', 'Racked: the bar is support here.'),",
    "('ex-rich', 'bench', 1, NULL, 'A note without an override (R-22).')",
  ]),
  _sql([
    'INSERT INTO exercise_names (exercise_id, locale, name, aliases_json)',
    "VALUES ('ex-rich', 'de-DE', 'Schrägbankdrücken',",
    '\'["Schrägbank"]\')',
  ]),
  _sql([
    'INSERT INTO exercise_user_state (exercise_id, favourite, hidden,',
    "last_used_at) VALUES ('ex-rich', 1, 0, '$restoreStamp'),",
    "('lib-deadlift', 0, 1, NULL)",
  ]),
];

String _sql(List<String> parts) => parts.join(' ');
