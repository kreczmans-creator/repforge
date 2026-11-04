import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:repforge/data/db/tables.dart';

export 'package:repforge/data/db/tables.dart';

part 'app_database.g.dart';

/// The application's SQLite database.
///
/// Schema history (snapshots under `drift_schemas/`, migration tests under
/// `test/data/migration_test.dart`):
/// 1. `weight_entries` (WP 1).
/// 2. WP 3: `measurements` replaces `weight_entries` (rows migrated with
///    site = weight); adds foods, food_log_entries, recipes,
///    recipe_ingredients, exercises, workout_plans, plan_exercises,
///    workout_sessions, session_sets, goals, settings.
/// 3. WP 5: saved_meals, saved_meal_items.
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
    Exercises,
    WorkoutPlans,
    PlanExercises,
    WorkoutSessions,
    SessionSets,
    Goals,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Private in-memory database for tests.
  AppDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Creates the full current schema (createAll) plus the data move, so
        // no later step is needed on this path.
        await _migrateV1ToV2(m);
        return;
      }
      if (from < 3) {
        await _migrateV2ToV3(m);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// v1 → v2: create every current entity (tables and indexes), copy
  /// weight_entries into measurements as site = weight, then drop the old
  /// table. Wrapped in an explicit transaction so an interruption leaves v1
  /// intact. drift records the new user_version only after this step
  /// returns, so the step can run again after a crash in that window: every
  /// statement is guarded so a re-run is a no-op (idempotent).
  Future<void> _migrateV1ToV2(Migrator m) => transaction(() async {
    for (final table in allTables) {
      await m.createTable(table); // CREATE TABLE IF NOT EXISTS
    }
    for (final index in allSchemaEntities.whereType<Index>()) {
      if (!await _schemaEntityExists('index', index.entityName)) {
        await m.createIndex(index);
      }
    }
    if (await _schemaEntityExists('table', 'weight_entries')) {
      await customStatement('''
        INSERT INTO measurements
          (id, site, value, recorded_at, note, created_at, updated_at,
           deleted_at)
        SELECT id, 'weight', weight_kg, recorded_at, note, created_at,
               updated_at, deleted_at
        FROM weight_entries
      ''');
      await customStatement('DROP TABLE weight_entries');
    }
  });

  Future<bool> _schemaEntityExists(String type, String name) async {
    final rows = await customSelect(
      'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
      variables: [Variable.withString(type), Variable.withString(name)],
    ).get();
    return rows.isNotEmpty;
  }

  /// v2 → v3: saved meals (two tables and one index). Additive only, and
  /// guarded like v1 → v2 so a re-run after a crash before `user_version`
  /// is written is a no-op (WP 5 audit D4).
  Future<void> _migrateV2ToV3(Migrator m) => transaction(() async {
    await m.createTable(savedMeals); // IF NOT EXISTS
    await m.createTable(savedMealItems);
    if (!await _schemaEntityExists('index', idxSavedMealItemsMeal.entityName)) {
      await m.createIndex(idxSavedMealItemsMeal);
    }
  });
}
