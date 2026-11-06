import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import '../harness_v7_db.dart';

/// Opens [executor] with a database whose migration strategy runs a
/// migration up to [targetVersion] (null: the migration's own target),
/// reporting every checkpoint to [probe].
typedef OpenMigratingDatabase = GeneratedDatabase Function(
  QueryExecutor executor, {
  MigrationProbe? probe,
  int? targetVersion,
});

/// A migration that the recovery, kill and timing harnesses (WP 8 3b-6,
/// 3b-9; WS5) run. Plain Dart (no Flutter), so the kill child process and
/// the on-device harness use the same definition as the host tests.
///
/// Today only [historicalChain] exists (v1 → v7, `RepforgeMigration` with
/// `HistoricalSteps`). The v7 → v8 migration (3b-4) is added as a second
/// entry of [migrationsUnderTest]: its [open] returns the v8 harness
/// database, whose `RepforgeMigration` gets the historical steps plus the
/// v7 → v8 step. Nothing else in the harnesses changes.
final class MigrationUnderTest {
  const MigrationUnderTest({
    required this.name,
    required this.targetVersion,
    required this.description,
    required this.standIn,
    required this.open,
  });

  /// Registry key; the kill child receives it as `--migration`.
  final String name;

  /// Version a complete run reaches.
  final int targetVersion;

  /// One line for reports.
  final String description;

  /// True while this migration only stands in for the v7 → v8 migration
  /// (3b-4 not written yet). Every report says so.
  final bool standIn;

  final OpenMigratingDatabase open;
}

/// The historical chain v1 → v7 on the frozen shapes, exactly as the 3b-3
/// tests run it ([HarnessV7Database]: frozen v7 snapshot classes,
/// [RepforgeMigration] with the historical steps, fixed clock).
final historicalChain = MigrationUnderTest(
  name: 'historical',
  targetVersion: 7,
  description:
      'historical chain v1→v7 (RepforgeMigration + HistoricalSteps), '
      'stand-in until the v7→v8 migration (3b-4) exists',
  standIn: true,
  open: (executor, {probe, targetVersion}) => HarnessV7Database(
    executor,
    probe: probe,
    targetVersion: targetVersion ?? 7,
  ),
);

/// Every migration the harnesses know, by [MigrationUnderTest.name].
/// 3b-4 adds its v7 → v8 entry here.
final migrationsUnderTest = <String, MigrationUnderTest>{
  historicalChain.name: historicalChain,
};

/// The migration registered as [name]; throws if there is none.
MigrationUnderTest migrationUnderTest(String name) =>
    migrationsUnderTest[name] ??
    (throw ArgumentError.value(
      name,
      'name',
      'unknown migration (known: ${migrationsUnderTest.keys.join(', ')})',
    ));

/// Opens [file] with [migration] (which runs it), closes the database and
/// returns the error, if any.
///
/// [background] opens the file the way the app engine does
/// (`NativeDatabase.createInBackground`, which drift_flutter's
/// `createBackgroundConnection` wraps): the database runs in a background
/// isolate and [probe] in the calling one. [foreignKeysOnAtSetup] switches
/// keys on when the connection opens, before the migration.
Future<Object?> runMigration(
  File file,
  MigrationUnderTest migration, {
  MigrationProbe? probe,
  int? targetVersion,
  bool background = false,
  bool foreignKeysOnAtSetup = false,
}) async {
  final setup = foreignKeysOnAtSetup ? _foreignKeysOn : null;
  final executor = background
      ? NativeDatabase.createInBackground(file, setup: setup)
      : NativeDatabase(file, setup: setup);
  final db = migration.open(
    executor,
    probe: probe,
    targetVersion: targetVersion,
  );
  try {
    await db.customSelect('SELECT 1').get();
    return null;
  } on Object catch (e) {
    return e;
  } finally {
    await db.close();
  }
}

/// Top level, so it can be sent to the background isolate.
void _foreignKeysOn(Database raw) => raw.execute('PRAGMA foreign_keys = ON');
