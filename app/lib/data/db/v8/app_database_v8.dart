import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:repforge/data/db/migration/bootstrap_reference_v8.dart';
import 'package:repforge/data/db/migration/historical_steps.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:repforge/data/db/migration/v7_to_v8.dart';
import 'package:repforge/data/db/tables.dart';
import 'package:repforge/data/db/v8/tables_v8.dart';

export 'package:repforge/data/db/v8/tables_v8.dart';

part 'app_database_v8.g.dart';

/// Schema version 8 (WP 8 stage 3b-2): the definition only.
///
/// **Not connected to the app.** Nothing in `lib/app`, `lib/features` or
/// `lib/data/repositories` imports it (architecture test), and production
/// stays on `AppDatabase` at schema version 7 until the owner accepts stage
/// 3b and separately authorises the switch (D04 §7, 2026-11-06).
///
/// A new database gets every table, index and constraint of v8 and the
/// reference bootstrap ([BootstrapReferenceV8]).
///
/// Upgrading an existing database (sub-stage 3b-4) needs a
/// [V8MigrationConfig]: [RepforgeMigration] then runs the integrity
/// preflight, the frozen historical steps v1 → v7 ([HistoricalSteps]) and
/// the v7 → v8 step ([V7ToV8Migration]), each in its own transaction with
/// foreign keys off before it and verified on after it. Without a
/// configuration [migration] refuses every upgrade, so a plain
/// `AppDatabaseV8(executor)` can never change an existing file.
///
/// Unchanged tables are the v7 classes of `tables.dart`; `exercises` and
/// `session_sets` are the v8 classes of `tables_v8.dart`. The schema is
/// dumped to `drift_schemas/drift_schema_v8.json` (`docs/schema-v8.md`).
@DriftDatabase(
  tables: [
    Measurements,
    Foods,
    FoodServings,
    FoodLogEntries,
    SavedMeals,
    SavedMealItems,
    Recipes,
    RecipeIngredients,
    RecipeSubstitutes,
    MealPlanItems,
    PrepBatches,
    ExercisesV8,
    WorkoutPlans,
    PlanExercises,
    WorkoutSessions,
    SessionExercises,
    SessionSetsV8,
    ScheduledWorkouts,
    TrainingSplits,
    SplitDays,
    LegacyQuarantine,
    Goals,
    Settings,
    ContentProviders,
    CatalogueReleases,
    AnatomyNodes,
    MovementPatterns,
    EquipmentItems,
    ReferenceLabels,
    ExerciseTargets,
    ExercisePatterns,
    ExerciseEquipmentLinks,
    ExerciseNames,
    ExerciseUserState,
    ExerciseBlocks,
    MigrationRuns,
    MigrationReportCounts,
    MigrationReportEntries,
  ],
)
class AppDatabaseV8 extends _$AppDatabaseV8 {
  AppDatabaseV8(super.e, {this.migrationConfig, this.probe, this.phaseProbe});

  /// Inputs of the upgrade; null refuses every upgrade.
  final V8MigrationConfig? migrationConfig;

  /// Test seam: checkpoints of the step chain.
  @visibleForTesting
  final MigrationProbe? probe;

  /// Test seam: phases of the v7 → v8 step.
  @visibleForTesting
  final V8PhaseProbe? phaseProbe;

  @override
  int get schemaVersion => 8;

  Future<void> _create(Migrator m) async {
    await m.createAll();
    await BootstrapReferenceV8.insert(this);
  }

  @override
  MigrationStrategy get migration {
    final config = migrationConfig;
    if (config == null) {
      return MigrationStrategy(
        onCreate: _create,
        onUpgrade: (m, from, to) => throw UnsupportedError(
          'Schema v8 is not connected: no migration configuration was given '
          'for the v$from → v$to upgrade.',
        ),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
    }
    final v8 = V7ToV8Migration(config, phaseProbe: phaseProbe);
    final historical = HistoricalSteps(clock: config.clock).steps;
    final chain = RepforgeMigration(
      database: this,
      clock: config.clock,
      probe: probe,
      steps: (from, db) => from < 7 ? historical(from, db) : v8.steps(from, db),
      onCreate: _create,
      preflight: (from, to) => v8.preflight(this, from, to),
    );
    return MigrationStrategy(
      onCreate: _create,
      onUpgrade: (m, from, to) async {
        await chain.upgrade(from, to);
        await v8.completed();
      },
      beforeOpen: (details) async {
        await chain.strategy.beforeOpen!(details);
        // A run that committed but whose ledger entry was not cleared (the
        // process died in between) is forgotten here (Review B, M1).
        await v8.forgetCommittedRun(this);
      },
    );
  }
}
