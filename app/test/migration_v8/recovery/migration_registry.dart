import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:repforge/data/db/migration/v7_to_v8.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import '../harness_v7_db.dart';

/// Opens [executor] with a database whose migration strategy runs a
/// migration up to [targetVersion] (null: the migration's own target),
/// reporting every checkpoint to [probe] and, for a migration that runs the
/// v7 → v8 step ([MigrationUnderTest.runsV8Step]), every internal phase of
/// that step to [phaseProbe] (ignored otherwise).
typedef OpenMigratingDatabase = GeneratedDatabase Function(
  QueryExecutor executor, {
  MigrationProbe? probe,
  int? targetVersion,
  V8PhaseProbe? phaseProbe,
});

/// A migration that the recovery, kill and timing harnesses (WP 8 3b-6,
/// 3b-9; WS5) run. Plain Dart (no Flutter), so the kill child process and
/// the on-device harness use the same definition as the host tests.
///
/// [historicalChain] (v1 → v7, `RepforgeMigration` with `HistoricalSteps`)
/// and, since 3b-4, [v7ToV8Migration] (`AppDatabaseV8`, whose
/// `RepforgeMigration` gets the historical steps plus the v7 → v8 step).
final class MigrationUnderTest {
  const MigrationUnderTest({
    required this.name,
    required this.targetVersion,
    required this.inputVersion,
    required this.description,
    required this.standIn,
    required this.open,
    this.runsV8Step = false,
  });

  /// Registry key; the kill child receives it as `--migration`.
  final String name;

  /// Version a complete run reaches.
  final int targetVersion;

  /// Schema version of the large profile a timing or random kill run
  /// starts from (`buildLargeProfile(version:)`): 7 for the v7 → v8
  /// migration; 5 for the historical stand-in, whose v5 → v7 run rebuilds
  /// the large tables.
  final int inputVersion;

  /// One line for reports.
  final String description;

  /// True when timing this migration only stands in for timing the v7 → v8
  /// migration: the historical chain. Every timing report says so; its
  /// figures are never v8 timings or 3b-9 evidence. The device harness
  /// times [v7ToV8Migration], which is not a stand-in.
  final bool standIn;

  /// True when a complete run executes the v7 → v8 step: its internal
  /// phases can be observed and failed (`phaseProbe`), it may read the
  /// bundled seed (R-30) and it writes the v8 report.
  final bool runsV8Step;

  final OpenMigratingDatabase open;
}

/// The historical chain v1 → v7 on the frozen shapes, exactly as the 3b-3
/// tests run it ([HarnessV7Database]: frozen v7 snapshot classes,
/// [RepforgeMigration] with the historical steps, fixed clock).
final historicalChain = MigrationUnderTest(
  name: 'historical',
  targetVersion: 7,
  inputVersion: 5,
  description:
      'historical chain v1→v7 (RepforgeMigration + HistoricalSteps); as a '
      'timing subject only a stand-in, never v7→v8 timing evidence',
  standIn: true,
  open: (executor, {probe, targetVersion, phaseProbe}) => HarnessV7Database(
    executor,
    probe: probe,
    targetVersion: targetVersion ?? 7,
  ),
);

/// The v7 → v8 migration (3b-4): `AppDatabaseV8`, whose
/// `RepforgeMigration` runs the `quick_check` preflight, the historical
/// steps and the v7 → v8 step. A target below 8 runs the historical chain
/// only (reference states of a v1..v6 start); its steps are the same.
///
/// The configuration is deterministic, so every process (the host test, a
/// device) reaches the same v8 state: the fixed harness clock, the run id
/// [registryRunId] (`run-1`; the kill child sets `run-<pid>`, so a test can
/// tell which process's run id survived a kill) and a run ledger next to
/// the database file ([SidecarRunLedger]). The seed bytes come from
/// [registrySeedLoader]: on the host the file
/// `assets/seed/exercise_library.json` relative to the working directory
/// (`app/`); on a device the bundled asset, which the device harness
/// installs. Only a database whose seed was applied (setting
/// `seedExercisesVersion` ≥ 1, R-30) reads them.
final v7ToV8Migration = MigrationUnderTest(
  name: 'v7to8',
  targetVersion: 8,
  inputVersion: 7,
  description:
      'v7→v8 migration (3b-4): AppDatabaseV8, RepforgeMigration + '
      'HistoricalSteps + V7ToV8Migration',
  standIn: false,
  runsV8Step: true,
  open: (executor, {probe, targetVersion, phaseProbe}) =>
      targetVersion != null && targetVersion < 8
      ? HarnessV7Database(executor, probe: probe, targetVersion: targetVersion)
      : AppDatabaseV8(
          executor,
          migrationConfig: registryV8Config,
          probe: probe,
          phaseProbe: phaseProbe,
        ),
);

/// The run id a new v7 → v8 run of [registryV8Config] gets.
String registryRunId = 'run-1';

/// The deterministic v8 configuration of [v7ToV8Migration].
final registryV8Config = V8MigrationConfig(
  clock: harnessClock,
  appVersion: '0.8.0-ws5',
  installLabel: 'ws5-registry',
  loadSeedBytes: () {
    registrySeedLoads++;
    return registrySeedLoader();
  },
  runLedger: SidecarRunLedger(),
  newRunId: () => registryRunId,
);

/// Path of the bundled seed (pubspec `assets/seed/`), relative to `app/`
/// and as an asset key.
const registrySeedAsset = 'assets/seed/exercise_library.json';

/// Reads the exact bundled seed bytes for [registryV8Config]. The default
/// reads [registrySeedAsset] from the working directory (host tests run in
/// `app/`). The device harness, which has no such file, replaces it with
/// the asset bundle (`rootBundle`) before any run; nothing in `lib/`
/// changes for that.
Future<List<int>> Function() registrySeedLoader = () async =>
    File(registrySeedAsset).readAsBytesSync();

/// Where [registrySeedLoader] reads from (reported by the timing harness).
String registrySeedSource = 'file $registrySeedAsset (working directory)';

/// How many times a migration through [registryV8Config] asked for the seed
/// bytes (a v7 database without the `seedExercisesVersion` setting never
/// does).
int registrySeedLoads = 0;

/// A run ledger per database file: `<database>.v8-run-ledger.json` next to
/// it (deleted when empty); in memory for an in-memory database.
final class SidecarRunLedger implements MigrationRunLedger {
  final InMemoryMigrationRunLedger _memory = InMemoryMigrationRunLedger();

  MigrationRunLedger _for(String database) => database.isEmpty
      ? _memory
      : FileMigrationRunLedger(File('$database.v8-run-ledger.json'));

  @override
  Future<PendingMigrationRun?> read(int from, int to, String database) =>
      _for(database).read(from, to, database);

  @override
  Future<void> write(int from, int to, PendingMigrationRun run) =>
      _for(run.database).write(from, to, run);

  @override
  Future<void> clear(int from, int to, String database) =>
      _for(database).clear(from, to, database);
}

/// Every migration the harnesses know, by [MigrationUnderTest.name].
final migrationsUnderTest = <String, MigrationUnderTest>{
  historicalChain.name: historicalChain,
  v7ToV8Migration.name: v7ToV8Migration,
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
/// [phaseProbe] observes the v7 → v8 step's phases (see
/// [MigrationUnderTest.runsV8Step]).
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
  V8PhaseProbe? phaseProbe,
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
    phaseProbe: phaseProbe,
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
