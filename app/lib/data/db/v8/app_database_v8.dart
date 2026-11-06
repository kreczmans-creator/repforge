import 'package:drift/drift.dart';
import 'package:repforge/data/db/migration/bootstrap_reference_v8.dart';
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
/// reference bootstrap ([BootstrapReferenceV8]). Upgrading an existing
/// database is sub-stage 3b-4 (the v7 → v8 step on the frozen historical
/// chain); until then [migration] refuses every upgrade, so this class can
/// never change an existing file.
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
  AppDatabaseV8(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await BootstrapReferenceV8.insert(this);
    },
    onUpgrade: (m, from, to) => throw UnsupportedError(
      'Schema v8 is not connected: the v$from → v$to migration is WP 8 '
      'sub-stage 3b-4.',
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
