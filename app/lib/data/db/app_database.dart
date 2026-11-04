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
/// 4. WP 5 audit D1: protein, carbs and fat become nullable on foods,
///    food_log_entries and saved_meal_items (unknown is never stored as 0).
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
  int get schemaVersion => 4;

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
      if (from < 4) {
        await _migrateV3ToV4(m);
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

  /// v3 → v4: protein, carbs and fat become nullable on `foods`,
  /// `food_log_entries` and `saved_meal_items`. SQLite cannot drop NOT NULL,
  /// so each table is rebuilt with [Migrator.alterTable] (create new, copy
  /// every row, drop, rename; indexes are recreated). Existing values are
  /// copied as they are. Idempotent: rebuilding a table that already has the
  /// v4 shape copies the same rows into the same shape, so a re-run after a
  /// crash before `user_version` is written is safe.
  ///
  /// Foreign keys are switched off for the whole step (the pragma is a no-op
  /// inside a transaction, so it is set outside it): dropping `foods` with
  /// keys on would cascade-delete `food_servings`. They are restored after
  /// the transaction commits.
  Future<void> _migrateV3ToV4(Migrator m) => exclusively(() async {
    final keysOn = (await customSelect(
      'PRAGMA foreign_keys',
    ).getSingle()).read<bool>('foreign_keys');
    if (keysOn) await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        await m.alterTable(TableMigration(foods));
        await m.alterTable(TableMigration(foodLogEntries));
        await m.alterTable(TableMigration(savedMealItems));
      });
    } finally {
      if (keysOn) await customStatement('PRAGMA foreign_keys = ON');
    }
  });
}
