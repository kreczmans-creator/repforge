import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:repforge/data/db/legacy_training_rows.dart';
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
/// 5. WP 7: recipes get real portions, separate prep and cook steps, a
///    freezing enum, total and portion weight and ingredient notes;
///    recipe_ingredients get a serving label and count; new recipe_substitutes,
///    meal_plan_items and prep_batches.
/// 6. WP 8: exercises get aliases, search key, `supplied` (replaces
///    `is_custom`) and `copied_from_id`; session_sets get cardio energy with
///    provenance; plan_exercises get a rep range and a distance target;
///    new training_splits, split_days and legacy_quarantine; CHECK
///    constraints on the training tables (TD-25).
/// 7. WP 9: session_sets get `set_kind` and `session_exercise_id`; new
///    session_exercises (ordered exercises of a session, with notes) and
///    scheduled_workouts. Additive only.
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
    Exercises,
    WorkoutPlans,
    PlanExercises,
    WorkoutSessions,
    SessionExercises,
    SessionSets,
    ScheduledWorkouts,
    TrainingSplits,
    SplitDays,
    LegacyQuarantine,
    Goals,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Private in-memory database for tests.
  AppDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 7;

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
      if (from < 5) {
        await _migrateV4ToV5(m);
      }
      if (from < 6) {
        await _migrateV5ToV6(m);
      }
      if (from < 7) {
        await _migrateV6ToV7(m);
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

  Future<bool> _columnExists(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info("$table")').get();
    return rows.any((r) => r.read<String>('name') == column);
  }

  /// v4 → v5 (WP 7). All inside one transaction, with foreign keys off
  /// around it (dropping `recipes` with keys on would cascade-delete
  /// `recipe_ingredients`):
  /// - `recipes` is rebuilt with [Migrator.alterTable]: `portions` becomes
  ///   REAL; `method_steps_json` moves into `cook_steps_json` (a v4 recipe
  ///   has one step list, which was the method, i.e. the cooking steps);
  ///   `prep_steps_json` starts as `[]`; `freezer_friendly` becomes
  ///   `freezing`.
  /// - `recipe_ingredients` gets `serving_label` and `serving_count`.
  /// - `recipe_substitutes`, `meal_plan_items` and `prep_batches` are
  ///   created with their indexes (the plan and prep tables are used by a
  ///   later stage; one migration creates all of v5).
  ///
  /// Freezer flag: in v4 `freezer_friendly` was a plain boolean defaulting to
  /// false, so FALSE meant "not stated", not "not suitable". Mapping 0 to
  /// `no` would assert a safety claim the user never made (D04 RCP-005,
  /// OQ-13). Hence 1 → 'yes' and 0 → 'unknown'.
  ///
  /// Idempotent: each part is guarded by what already exists (a recipes
  /// table that has `cook_steps_json` is already v5), so a re-run after a
  /// crash before `user_version` is written changes nothing.
  Future<void> _migrateV4ToV5(Migrator m) => exclusively(() async {
    final keysOn = (await customSelect(
      'PRAGMA foreign_keys',
    ).getSingle()).read<bool>('foreign_keys');
    if (keysOn) await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        if (!await _columnExists('recipes', 'cook_steps_json')) {
          await m.alterTable(
            TableMigration(
              recipes,
              columnTransformer: {
                recipes.portions: const CustomExpression<double>(
                  'CAST(portions AS REAL)',
                ),
                recipes.cookStepsJson: const CustomExpression<String>(
                  'method_steps_json',
                ),
                recipes.freezing: const CustomExpression<String>(
                  'CASE WHEN freezer_friendly = 1 '
                  "THEN 'yes' ELSE 'unknown' END",
                ),
              },
              newColumns: [
                recipes.prepStepsJson,
                recipes.totalWeightG,
                recipes.portionWeightG,
                recipes.ingredientNotesJson,
              ],
            ),
          );
        }
        if (!await _columnExists('recipe_ingredients', 'serving_label')) {
          await m.addColumn(recipeIngredients, recipeIngredients.servingLabel);
          await m.addColumn(recipeIngredients, recipeIngredients.servingCount);
        }
        await m.createTable(recipeSubstitutes); // IF NOT EXISTS
        await m.createTable(mealPlanItems);
        await m.createTable(prepBatches);
        for (final index in [
          idxRecipeSubstitutesIngredient,
          idxMealPlanItemsDay,
          idxPrepBatchesRecipe,
        ]) {
          if (!await _schemaEntityExists('index', index.entityName)) {
            await m.createIndex(index);
          }
        }
      });
    } finally {
      if (keysOn) await customStatement('PRAGMA foreign_keys = ON');
    }
  });

  /// v5 → v6 (WP 8). One transaction with foreign keys off (rebuilding a
  /// table with keys on would cascade-delete children):
  /// - rows that would violate a new CHECK constraint are dealt with first
  ///   (see [LegacyTrainingRows]: an out-of-range nullable value becomes NULL,
  ///   a row with an out-of-range NOT NULL value is removed; the complete
  ///   original is kept in `legacy_quarantine`; nothing is clamped);
  /// - `exercises` is rebuilt: `supplied` = NOT `is_custom`, `is_custom`
  ///   dropped, new `aliases_json`, `search_key`, `copied_from_id`; free-text
  ///   type, category, muscle and equipment values that match a taxonomy
  ///   identifier, label or listed synonym ignoring case and spaces are
  ///   rewritten to the identifier; an unmatched secondary muscle or
  ///   equipment item is dropped, an unmatched type, category or primary
  ///   muscle is kept as it is, and in both cases the original row is copied
  ///   to `legacy_quarantine` with the reason;
  /// - `plan_exercises` is rebuilt: `target_reps` is copied into `reps_min`
  ///   and `reps_max`; new `target_metres`; CHECK constraints;
  /// - `session_sets` is rebuilt: new `energy_kcal`, `energy_provenance`;
  ///   CHECK constraints (a timed set's added load reuses `load_kg`);
  /// - `training_splits`, `split_days`, `legacy_quarantine` are created.
  ///
  /// Idempotent: the rebuilds run only while `session_sets` has no
  /// `energy_kcal` column, tables and indexes are created if missing, so a
  /// re-run after a crash before `user_version` is written changes nothing.
  Future<void> _migrateV5ToV6(Migrator m) => exclusively(() async {
    final keysOn = (await customSelect(
      'PRAGMA foreign_keys',
    ).getSingle()).read<bool>('foreign_keys');
    if (keysOn) await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        await m.createTable(legacyQuarantine); // IF NOT EXISTS
        if (!await _columnExists('session_sets', 'energy_kcal')) {
          await _quarantineLegacySets();
          await _quarantineLegacyPlanExercises();
          await m.alterTable(
            TableMigration(
              exercises,
              columnTransformer: {
                exercises.supplied: const CustomExpression<bool>(
                  'CASE WHEN is_custom = 1 THEN 0 ELSE 1 END',
                ),
              },
              newColumns: [
                exercises.aliasesJson,
                exercises.searchKey,
                exercises.copiedFromId,
              ],
            ),
          );
          await m.alterTable(
            TableMigration(
              planExercises,
              columnTransformer: {
                planExercises.repsMin: const CustomExpression<int>(
                  'target_reps',
                ),
                planExercises.repsMax: const CustomExpression<int>(
                  'target_reps',
                ),
              },
              newColumns: [planExercises.targetMetres],
            ),
          );
          await m.alterTable(
            TableMigration(
              sessionSets,
              columnTransformer: {
                sessionSets.setKind: const CustomExpression<String>(
                  "'working'",
                ),
              },
              // drift copies into the CURRENT table shape, so the two v7
              // columns (default `working` and null) must be listed here
              // too; their values are not read from the old table. This
              // changes no v6 behaviour; the v7 step then finds them.
              newColumns: [
                sessionSets.energyKcal,
                sessionSets.energyProvenance,
                sessionSets.setKind,
                sessionSets.sessionExerciseId,
              ],
            ),
          );
          await _normaliseExercisesV6();
        }
        await m.createTable(trainingSplits);
        await m.createTable(splitDays);
        for (final index in [idxSplitDaysSplit]) {
          if (!await _schemaEntityExists('index', index.entityName)) {
            await m.createIndex(index);
          }
        }
      });
    } finally {
      if (keysOn) await customStatement('PRAGMA foreign_keys = ON');
    }
  });

  /// v6 → v7 (WP 9). Additive only; no existing value is changed:
  /// - `session_sets` gets `set_kind` (existing rows `working`) and
  ///   `session_exercise_id` (nullable);
  /// - `session_exercises` and `scheduled_workouts` are created with their
  ///   indexes;
  /// - every set without an entry is given one by
  ///   [backfillSessionExercises].
  ///
  /// Idempotent: columns, tables and indexes are created only if missing and
  /// the backfill touches only sets that still have no entry, so a re-run
  /// after a crash before `user_version` is written changes nothing. One
  /// transaction; no table is rebuilt, so foreign keys can stay on.
  Future<void> _migrateV6ToV7(Migrator m) => transaction(() async {
    await m.createTable(sessionExercises); // IF NOT EXISTS
    await m.createTable(scheduledWorkouts);
    if (!await _columnExists('session_sets', 'set_kind')) {
      await m.addColumn(sessionSets, sessionSets.setKind);
    }
    if (!await _columnExists('session_sets', 'session_exercise_id')) {
      await m.addColumn(sessionSets, sessionSets.sessionExerciseId);
    }
    for (final index in [
      idxSessionExercisesSession,
      idxSessionSetsEntry,
      idxScheduledWorkoutsDay,
    ]) {
      if (!await _schemaEntityExists('index', index.entityName)) {
        await m.createIndex(index);
      }
    }
    await backfillSessionExercises();
  });

  /// Gives every set that has no `session_exercise_id` an entry (schema v7).
  /// Used by the v6 → v7 migration and by restoring a backup made before v7.
  ///
  /// Sets are grouped by (session, exercise_order, exercise) and every group
  /// gets its own new entry (id `legacy:<session>:<position>`) at the next
  /// free position, groups taken in `exercise_order` then first-row order, so
  /// the existing order is kept, two exercises that shared an
  /// `exercise_order` get distinct positions, and the same exercise at two
  /// orders (A, B, A) becomes two entries (a session may hold an exercise
  /// more than once). `exercise_order` and every other existing set value stay
  /// as they are. Safe to run again: it only touches sets with no entry.
  Future<void> backfillSessionExercises() async {
    final groups = await customSelect(
      'SELECT session_id, exercise_order, exercise_id, '
      'MIN(rowid) AS first_row '
      'FROM session_sets WHERE session_exercise_id IS NULL '
      'GROUP BY session_id, exercise_order, exercise_id '
      'ORDER BY session_id, exercise_order, first_row',
    ).get();
    for (final g in groups) {
      final sessionId = g.read<String>('session_id');
      final exerciseId = g.read<String>('exercise_id');
      final order = g.read<int>('exercise_order');
      final next = await customSelect(
        'SELECT COALESCE(MAX(position) + 1, 0) AS p '
        'FROM session_exercises WHERE session_id = ?',
        variables: [Variable.withString(sessionId)],
      ).getSingle();
      final position = next.read<int>('p');
      final entryId = 'legacy:$sessionId:$position';
      await customStatement(
        'INSERT INTO session_exercises (id, session_id, position, '
        'exercise_id) VALUES (?, ?, ?, ?)',
        [entryId, sessionId, position, exerciseId],
      );
      await customStatement(
        'UPDATE session_sets SET session_exercise_id = ? '
        'WHERE session_id = ? AND exercise_id = ? AND exercise_order = ? '
        'AND session_exercise_id IS NULL',
        [entryId, sessionId, exerciseId, order],
      );
    }
  }

  Future<void> _quarantine(
    String table,
    Map<String, Object?> original,
    String reason,
  ) => customStatement(
    'INSERT INTO legacy_quarantine '
    '(source_table, row_id, reason, original_json, quarantined_at) '
    'VALUES (?, ?, ?, ?, ?)',
    [
      table,
      (original['id'] ?? '').toString(),
      reason,
      jsonEncode(original),
      DateTime.now().toUtc().toIso8601String(),
    ],
  );

  Future<void> _quarantineLegacySets() async {
    final rows = await customSelect('SELECT * FROM session_sets').get();
    for (final r in rows) {
      final fixed = LegacyTrainingRows.sessionSet(r.data);
      if (fixed.unchanged) continue;
      await _quarantine('session_sets', r.data, fixed.reason);
      for (final column in fixed.nulledColumns) {
        await customStatement(
          'UPDATE session_sets SET "$column" = NULL WHERE id = ?',
          [r.data['id']],
        );
      }
    }
  }

  Future<void> _quarantineLegacyPlanExercises() async {
    final rows = await customSelect('SELECT * FROM plan_exercises').get();
    for (final r in rows) {
      final fixed = LegacyTrainingRows.planExercise(r.data);
      if (fixed.unchanged) continue;
      await _quarantine('plan_exercises', r.data, fixed.reason);
      if (fixed.row == null) {
        await customStatement('DELETE FROM plan_exercises WHERE id = ?', [
          r.data['id'],
        ]);
      }
      for (final column in fixed.nulledColumns) {
        await customStatement(
          'UPDATE plan_exercises SET "$column" = NULL WHERE id = ?',
          [r.data['id']],
        );
      }
    }
  }

  /// Rewrites legacy free-text enum values and computes `search_key` for
  /// every exercise row after the v6 rebuild.
  Future<void> _normaliseExercisesV6() async {
    final rows = await customSelect('SELECT * FROM exercises').get();
    for (final r in rows) {
      final mapped = LegacyTrainingRows.exercise(r.data);
      final row = mapped.row;
      if (mapped.quarantineReason case final reason?) {
        await _quarantine('exercises', r.data, reason);
      }
      await customStatement(
        'UPDATE exercises SET type = ?, category = ?, primary_muscle = ?, '
        'secondary_muscles_json = ?, equipment_json = ?, search_key = ? '
        'WHERE id = ?',
        [
          row['type'],
          row['category'],
          row['primary_muscle'],
          row['secondary_muscles_json'],
          row['equipment_json'],
          row['search_key'],
          row['id'],
        ],
      );
    }
  }
}
