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
@DriftDatabase(
  tables: [
    Measurements,
    Foods,
    FoodServings,
    FoodLogEntries,
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _migrateV1ToV2(m);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// v1 → v2: create every new table, copy weight_entries into measurements
  /// as site = weight, then drop the old table. Runs inside drift's upgrade
  /// transaction so a failure leaves v1 intact.
  Future<void> _migrateV1ToV2(Migrator m) async {
    for (final table in allTables) {
      await m.createTable(table);
    }
    await customStatement('''
      INSERT INTO measurements
        (id, site, value, recorded_at, note, created_at, updated_at, deleted_at)
      SELECT id, 'weight', weight_kg, recorded_at, note, created_at,
             updated_at, deleted_at
      FROM weight_entries
    ''');
    await customStatement('DROP TABLE weight_entries');
  }
}
