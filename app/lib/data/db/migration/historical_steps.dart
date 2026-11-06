import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:repforge/data/db/migration/legacy_training_rows_v6.dart';
import 'package:repforge/data/db/migration/schema_versions.g.dart';
import 'package:repforge/domain/core/clock.dart';

/// One migration step: upgrades the database from the version it is given
/// and returns the version it reached. Produced by [HistoricalSteps.steps]
/// (drift's `migrationSteps`, generated in `schema_versions.g.dart`).
typedef MigrationStep = Future<int> Function(int from, GeneratedDatabase db);

/// The historical schema steps v1 → v7 (WP 8 stage 3b-3), written against
/// the frozen shapes `Schema2` .. `Schema7` of `schema_versions.g.dart`, never
/// against the live table classes of `tables.dart`.
///
/// Each step reproduces the data logic of today's production step in
/// `AppDatabase` (`_migrateV1ToV2` .. `_migrateV6ToV7`) statement for
/// statement, so the chain reaches today's v7 result exactly. Two
/// differences are intended:
/// - v1 → v2 creates the v2 shape (`Schema2`), not every current table; the
///   later steps then add what each version added.
/// - v5 → v6 rebuilds `exercises`, `plan_exercises` and `session_sets` into
///   the `Schema6` shapes. Production rebuilds them into the current
///   classes, which only works while it also lists every later column (the
///   hazard this stage removes).
///
/// The guards of the production steps stay (a column, table or index is
/// created only if missing; a rebuild runs only on the old shape). A
/// database that today's production left in its crash window (work
/// committed, `user_version` not yet written) therefore still completes.
///
/// No live data logic: the v5 → v6 mapping uses the frozen
/// [LegacyTrainingRowsV6] and the v6 → v7 backfill the frozen
/// [backfillSessionExercisesV7]. Production restore keeps its own copies.
///
/// Not connected to the app: production still migrates with `AppDatabase`.
final class HistoricalSteps {
  HistoricalSteps({required this.clock});

  /// Stamps `legacy_quarantine.quarantined_at`.
  final Clock clock;

  /// Every historical step, keyed by drift's generated dispatcher.
  MigrationStep get steps => migrationSteps(
    from1To2: from1To2,
    from2To3: from2To3,
    from3To4: from3To4,
    from4To5: from4To5,
    from5To6: from5To6,
    from6To7: from6To7,
  );

  /// v1 → v2: create the v2 tables and indexes, copy `weight_entries` into
  /// `measurements` as site = weight, drop `weight_entries`.
  Future<void> from1To2(Migrator m, Schema2 s) async {
    final db = m.database;
    for (final table in s.entities.whereType<TableInfo<Table, Object?>>()) {
      await m.createTable(table); // CREATE TABLE IF NOT EXISTS
    }
    await _createMissingIndexes(m, s.entities.whereType<Index>());
    if (await _entityExists(db, 'table', 'weight_entries')) {
      await db.customStatement('''
        INSERT INTO measurements
          (id, site, value, recorded_at, note, created_at, updated_at,
           deleted_at)
        SELECT id, 'weight', weight_kg, recorded_at, note, created_at,
               updated_at, deleted_at
        FROM weight_entries
      ''');
      await db.customStatement('DROP TABLE weight_entries');
    }
  }

  /// v2 → v3: saved meals (two tables, one index). Additive.
  Future<void> from2To3(Migrator m, Schema3 s) async {
    await m.createTable(s.savedMeals);
    await m.createTable(s.savedMealItems);
    await _createMissingIndexes(m, [s.idxSavedMealItemsMeal]);
  }

  /// v3 → v4: protein, carbs and fat become nullable on `foods`,
  /// `food_log_entries` and `saved_meal_items`. Each table is rebuilt into
  /// its v4 shape; every value is copied as it is.
  Future<void> from3To4(Migrator m, Schema4 s) async {
    await m.alterTable(TableMigration(s.foods));
    await m.alterTable(TableMigration(s.foodLogEntries));
    await m.alterTable(TableMigration(s.savedMealItems));
  }

  /// v4 → v5 (WP 7): `recipes` rebuilt into the v5 shape (portions REAL,
  /// method steps become cook steps, freezer flag 1 → `yes`, 0 → `unknown`);
  /// `recipe_ingredients` gets its serving columns; three new tables.
  Future<void> from4To5(Migrator m, Schema5 s) async {
    final db = m.database;
    if (!await _columnExists(db, 'recipes', 'cook_steps_json')) {
      final recipes = s.recipes;
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
    if (!await _columnExists(db, 'recipe_ingredients', 'serving_label')) {
      await m.addColumn(s.recipeIngredients, s.recipeIngredients.servingLabel);
      await m.addColumn(s.recipeIngredients, s.recipeIngredients.servingCount);
    }
    await m.createTable(s.recipeSubstitutes);
    await m.createTable(s.mealPlanItems);
    await m.createTable(s.prepBatches);
    await _createMissingIndexes(m, [
      s.idxRecipeSubstitutesIngredient,
      s.idxMealPlanItemsDay,
      s.idxPrepBatchesRecipe,
    ]);
  }

  /// v5 → v6 (WP 8): quarantine rows outside the new CHECKs (never
  /// clamped), rebuild `exercises`, `plan_exercises` and `session_sets` into
  /// the `Schema6` shapes, normalise legacy exercise text, create the split
  /// and quarantine tables. Same order and statements as production.
  Future<void> from5To6(Migrator m, Schema6 s) async {
    final db = m.database;
    await m.createTable(s.legacyQuarantine);
    if (!await _columnExists(db, 'session_sets', 'energy_kcal')) {
      await _quarantineLegacySets(db);
      await _quarantineLegacyPlanExercises(db);
      await m.alterTable(
        TableMigration(
          s.exercises,
          columnTransformer: {
            s.exercises.supplied: const CustomExpression<int>(
              'CASE WHEN is_custom = 1 THEN 0 ELSE 1 END',
            ),
          },
          newColumns: [
            s.exercises.aliasesJson,
            s.exercises.searchKey,
            s.exercises.copiedFromId,
          ],
        ),
      );
      await m.alterTable(
        TableMigration(
          s.planExercises,
          columnTransformer: {
            s.planExercises.repsMin: const CustomExpression<int>('target_reps'),
            s.planExercises.repsMax: const CustomExpression<int>('target_reps'),
          },
          newColumns: [s.planExercises.targetMetres],
        ),
      );
      await m.alterTable(
        TableMigration(
          s.sessionSets,
          newColumns: [
            s.sessionSets.energyKcal,
            s.sessionSets.energyProvenance,
          ],
        ),
      );
      await _normaliseExercisesV6(db);
    }
    await m.createTable(s.trainingSplits);
    await m.createTable(s.splitDays);
    await _createMissingIndexes(m, [s.idxSplitDaysSplit]);
  }

  /// v6 → v7 (WP 9): additive. `session_sets` gets `set_kind` (existing rows
  /// `working`) and `session_exercise_id`; two new tables; every set without
  /// an entry gets one ([backfillSessionExercisesV7]).
  Future<void> from6To7(Migrator m, Schema7 s) async {
    final db = m.database;
    await m.createTable(s.sessionExercises);
    await m.createTable(s.scheduledWorkouts);
    if (!await _columnExists(db, 'session_sets', 'set_kind')) {
      await m.addColumn(s.sessionSets, s.sessionSets.setKind);
    }
    if (!await _columnExists(db, 'session_sets', 'session_exercise_id')) {
      await m.addColumn(s.sessionSets, s.sessionSets.sessionExerciseId);
    }
    await _createMissingIndexes(m, [
      s.idxSessionExercisesSession,
      s.idxSessionSetsEntry,
      s.idxScheduledWorkoutsDay,
    ]);
    await backfillSessionExercisesV7(db);
  }

  /// Frozen copy of `AppDatabase.backfillSessionExercises` as of schema v7
  /// (same statements, same order). Production also uses its method when it
  /// restores a pre-v7 backup, so that method may change with v8; this copy
  /// must not. `historical_steps_test.dart` proves both give the same rows.
  ///
  /// Groups sets with no entry by (session, exercise_order, exercise); each
  /// group gets entry `legacy:<session>:<position>` at the next free
  /// position, in `exercise_order` then first-row order.
  static Future<void> backfillSessionExercisesV7(
    DatabaseConnectionUser db,
  ) async {
    final groups = await db
        .customSelect(
          'SELECT session_id, exercise_order, exercise_id, '
          'MIN(rowid) AS first_row '
          'FROM session_sets WHERE session_exercise_id IS NULL '
          'GROUP BY session_id, exercise_order, exercise_id '
          'ORDER BY session_id, exercise_order, first_row',
        )
        .get();
    for (final g in groups) {
      final sessionId = g.read<String>('session_id');
      final exerciseId = g.read<String>('exercise_id');
      final order = g.read<int>('exercise_order');
      final next = await db
          .customSelect(
            'SELECT COALESCE(MAX(position) + 1, 0) AS p '
            'FROM session_exercises WHERE session_id = ?',
            variables: [Variable.withString(sessionId)],
          )
          .getSingle();
      final position = next.read<int>('p');
      final entryId = 'legacy:$sessionId:$position';
      await db.customStatement(
        'INSERT INTO session_exercises (id, session_id, position, '
        'exercise_id) VALUES (?, ?, ?, ?)',
        [entryId, sessionId, position, exerciseId],
      );
      await db.customStatement(
        'UPDATE session_sets SET session_exercise_id = ? '
        'WHERE session_id = ? AND exercise_id = ? AND exercise_order = ? '
        'AND session_exercise_id IS NULL',
        [entryId, sessionId, exerciseId, order],
      );
    }
  }

  // ---- Helpers (copies of the private production helpers) -----------------

  static Future<bool> _entityExists(
    DatabaseConnectionUser db,
    String type,
    String name,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
          variables: [Variable.withString(type), Variable.withString(name)],
        )
        .get();
    return rows.isNotEmpty;
  }

  static Future<bool> _columnExists(
    DatabaseConnectionUser db,
    String table,
    String column,
  ) async {
    final rows = await db.customSelect('PRAGMA table_info("$table")').get();
    return rows.any((r) => r.read<String>('name') == column);
  }

  static Future<void> _createMissingIndexes(
    Migrator m,
    Iterable<Index> indexes,
  ) async {
    for (final index in indexes) {
      if (!await _entityExists(m.database, 'index', index.entityName)) {
        await m.createIndex(index);
      }
    }
  }

  Future<void> _quarantine(
    DatabaseConnectionUser db,
    String table,
    Map<String, Object?> original,
    String reason,
  ) => db.customStatement(
    'INSERT INTO legacy_quarantine '
    '(source_table, row_id, reason, original_json, quarantined_at) '
    'VALUES (?, ?, ?, ?, ?)',
    [
      table,
      (original['id'] ?? '').toString(),
      reason,
      jsonEncode(original),
      clock.now().toUtc().toIso8601String(),
    ],
  );

  Future<void> _quarantineLegacySets(DatabaseConnectionUser db) async {
    final rows = await db.customSelect('SELECT * FROM session_sets').get();
    for (final r in rows) {
      final fixed = LegacyTrainingRowsV6.sessionSet(r.data);
      if (fixed.unchanged) continue;
      await _quarantine(db, 'session_sets', r.data, fixed.reason);
      for (final column in fixed.nulledColumns) {
        await db.customStatement(
          'UPDATE session_sets SET "$column" = NULL WHERE id = ?',
          [r.data['id']],
        );
      }
    }
  }

  Future<void> _quarantineLegacyPlanExercises(DatabaseConnectionUser db) async {
    final rows = await db.customSelect('SELECT * FROM plan_exercises').get();
    for (final r in rows) {
      final fixed = LegacyTrainingRowsV6.planExercise(r.data);
      if (fixed.unchanged) continue;
      await _quarantine(db, 'plan_exercises', r.data, fixed.reason);
      if (fixed.row == null) {
        await db.customStatement('DELETE FROM plan_exercises WHERE id = ?', [
          r.data['id'],
        ]);
      }
      for (final column in fixed.nulledColumns) {
        await db.customStatement(
          'UPDATE plan_exercises SET "$column" = NULL WHERE id = ?',
          [r.data['id']],
        );
      }
    }
  }

  /// Rewrites legacy free-text enum values and computes `search_key` for
  /// every exercise row after the v6 rebuild.
  ///
  /// Production characteristic, reproduced on purpose: this runs after the
  /// rebuild, so a quarantined exercise's `original_json` is the rebuilt v6
  /// row (`supplied`, `aliases_json`, empty `search_key`), not the v5 row.
  /// Nothing is lost: `is_custom` is recoverable as NOT `supplied`, and the
  /// free text is still in the row, because the UPDATE below runs after the
  /// quarantine insert. `expected_v7_digests.json` records it. The 3b-4
  /// quarantine design must decide whether v8 keeps this form.
  Future<void> _normaliseExercisesV6(DatabaseConnectionUser db) async {
    final rows = await db.customSelect('SELECT * FROM exercises').get();
    for (final r in rows) {
      final mapped = LegacyTrainingRowsV6.exercise(r.data);
      final row = mapped.row;
      if (mapped.quarantineReason case final reason?) {
        await _quarantine(db, 'exercises', r.data, reason);
      }
      await db.customStatement(
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
