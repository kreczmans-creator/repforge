import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_backup_repository.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';

final _t = DateTime.utc(2026, 11, 1, 8);

const _tableNames = [
  'measurements',
  'foods',
  'food_servings',
  'food_log_entries',
  'saved_meals',
  'saved_meal_items',
  'recipes',
  'recipe_ingredients',
  'recipe_substitutes',
  'meal_plan_items',
  'prep_batches',
  'exercises',
  'workout_plans',
  'plan_exercises',
  'workout_sessions',
  'session_exercises',
  'session_sets',
  'scheduled_workouts',
  'training_splits',
  'split_days',
  'legacy_quarantine',
  'goals',
  'settings',
];

Future<void> _seed(AppDatabase db, {String suffix = ''}) async {
  await db
      .into(db.measurements)
      .insert(
        MeasurementsCompanion.insert(
          id: 'm$suffix',
          site: 'weight',
          value: 80.5,
          recordedAt: _t,
          createdAt: _t,
          updatedAt: _t,
        ),
      );
  await db
      .into(db.foods)
      .insert(
        FoodsCompanion.insert(
          id: 'f$suffix',
          name: 'Chicken',
          per100Unit: 'grams',
          kcal: 165,
          proteinG: const Value(31),
          carbsG: const Value(0),
          fatG: const Value(3.6),
          provenance: 'verified',
          source: 'openFoodFacts',
          searchKey: 'chicken',
          createdAt: _t,
          updatedAt: _t,
        ),
      );
  await db
      .into(db.foodServings)
      .insert(
        FoodServingsCompanion.insert(
          id: 'fs$suffix',
          foodId: 'f$suffix',
          label: '1 breast',
          amount: 120,
          unit: 'grams',
          sortOrder: 0,
        ),
      );
  await db
      .into(db.goals)
      .insert(
        GoalsCompanion.insert(
          id: 'g$suffix',
          kind: 'calories',
          target: 2400,
          startDate: _t,
          createdAt: _t,
          updatedAt: _t,
        ),
      );
  await db
      .into(db.settings)
      .insert(
        SettingsCompanion.insert(
          key: 'theme$suffix',
          value: 'light',
          updatedAt: _t,
        ),
      );
  await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          id: 's$suffix',
          name: 'Push',
          startedAt: _t,
          createdAt: _t,
          updatedAt: _t,
        ),
      );
  await db
      .into(db.sessionExercises)
      .insert(
        SessionExercisesCompanion.insert(
          id: 'se$suffix',
          sessionId: 's$suffix',
          position: 0,
          exerciseId: 'bench',
          note: const Value('felt strong'),
        ),
      );
  await db
      .into(db.scheduledWorkouts)
      .insert(
        ScheduledWorkoutsCompanion.insert(
          id: 'sw$suffix',
          day: '2026-11-02',
          sourceDay: '2026-11-02',
          planId: 'p$suffix',
          origin: 'weekday',
          status: 'planned',
          createdAt: _t,
          updatedAt: _t,
        ),
      );
  await db
      .into(db.sessionSets)
      .insert(
        SessionSetsCompanion.insert(
          id: 'ss$suffix',
          sessionId: 's$suffix',
          sessionExerciseId: Value('se$suffix'),
          exerciseId: 'bench',
          exerciseOrder: 0,
          setOrder: 0,
          type: 'weightReps',
        ),
      );
  await db
      .into(db.recipes)
      .insert(
        RecipesCompanion.insert(
          id: 'r$suffix',
          name: 'Chilli',
          category: 'dinner',
          portions: 2.5,
          freezing: const Value('yes'),
          prepStepsJson: const Value('["Chop"]'),
          cookStepsJson: const Value('["Cook"]'),
          totalWeightG: const Value(900),
          portionWeightG: const Value(360),
          ingredientNotesJson: const Value('["1 tin beans"]'),
          createdAt: _t,
          updatedAt: _t,
        ),
      );
  await db
      .into(db.recipeIngredients)
      .insert(
        RecipeIngredientsCompanion.insert(
          id: 'ri$suffix',
          recipeId: 'r$suffix',
          name: 'Mince',
          amount: 400,
          unit: 'grams',
          sortOrder: 0,
          servingLabel: const Value('pack'),
          servingCount: const Value(0.8),
        ),
      );
  await db
      .into(db.recipeSubstitutes)
      .insert(
        RecipeSubstitutesCompanion.insert(
          id: 'rs$suffix',
          recipeIngredientId: 'ri$suffix',
          sortOrder: 0,
          name: 'Turkey mince',
          amount: 400,
          unit: 'grams',
          kcal: 140,
          provenance: 'verified',
        ),
      );
  await db
      .into(db.mealPlanItems)
      .insert(
        MealPlanItemsCompanion.insert(
          id: 'mp$suffix',
          day: '2026-11-05',
          meal: 'dinner',
          kind: 'recipe',
          refId: 'r$suffix',
          name: 'Chilli',
          amount: 1.5,
          unit: 'portion',
          sortOrder: 0,
          createdAt: _t,
          updatedAt: _t,
        ),
      );
  await db
      .into(db.prepBatches)
      .insert(
        PrepBatchesCompanion.insert(
          id: 'pb$suffix',
          recipeId: 'r$suffix',
          preparedAt: _t,
          portionsMade: 6,
          portionsRemaining: 4,
          createdAt: _t,
          updatedAt: _t,
        ),
      );
}

Map<String, Object?> _decode(String json) =>
    jsonDecode(json) as Map<String, Object?>;

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));

void main() {
  group('DriftBackupRepository (in-memory)', () {
    late AppDatabase db;
    late DriftBackupRepository repo;

    setUp(() {
      db = AppDatabase.inMemory();
      repo = DriftBackupRepository(db, clock: _clock);
    });
    tearDown(() => db.close());

    Future<List<String>> measurementIds() async => [
      for (final r in await db.select(db.measurements).get()) r.id,
    ];

    test('export has the envelope and every table', () async {
      await _seed(db);
      final doc = _decode(await repo.exportJson());

      expect(doc['app'], 'repforge');
      expect(doc['formatVersion'], 1);
      expect(doc['schemaVersion'], 7);
      expect(DateTime.tryParse(doc['exportedAt']! as String), isNotNull);
      final tables = doc['tables']! as Map<String, Object?>;
      expect(tables.keys, containsAll(_tableNames));
      expect(tables.keys, hasLength(_tableNames.length));
      for (final name in [
        'measurements',
        'foods',
        'food_servings',
        'goals',
        'settings',
        'workout_sessions',
        'session_exercises',
        'scheduled_workouts',
        'session_sets',
        'recipes',
        'recipe_ingredients',
        'recipe_substitutes',
        'meal_plan_items',
        'prep_batches',
      ]) {
        expect(tables[name], hasLength(1), reason: name);
      }
    });

    test('export then import into a fresh database round-trips', () async {
      await _seed(db);
      final json = await repo.exportJson();

      final fresh = AppDatabase.inMemory();
      addTearDown(fresh.close);
      final freshRepo = DriftBackupRepository(fresh, clock: _clock);
      final result = await freshRepo.importJson(json);

      expect(result, isA<Ok<BackupSummary>>());
      final summary = (result as Ok<BackupSummary>).value;
      expect(summary.formatVersion, 1);
      expect(summary.rowCounts['measurements'], 1);
      expect(summary.rowCounts['session_sets'], 1);

      final again = _decode(await freshRepo.exportJson());
      expect(again['tables'], _decode(json)['tables']);
      expect((await fresh.select(fresh.measurements).get()).single.value, 80.5);
      // Recipe data added in schema v5 survives.
      final recipe = (await fresh.select(fresh.recipes).get()).single;
      expect(recipe.portions, 2.5);
      expect(recipe.freezing, 'yes');
      expect(recipe.cookStepsJson, '["Cook"]');
      expect(recipe.totalWeightG, 900);
      final ing = (await fresh.select(fresh.recipeIngredients).get()).single;
      expect([ing.servingLabel, ing.servingCount], ['pack', 0.8]);
      expect(
        (await fresh.select(fresh.recipeSubstitutes).get()).single.name,
        'Turkey mince',
      );
      expect(
        (await fresh.select(fresh.mealPlanItems).get()).single.unit,
        'portion',
      );
      expect(
        (await fresh.select(fresh.prepBatches).get()).single.portionsRemaining,
        4,
      );
    });

    test('a schema v4 backup restores its recipe: method steps become cook '
        'steps and the freezer flag maps', () async {
      Map<String, Object?> v4Recipe(String id, int freezer) => {
        'id': id,
        'name': 'Old $id',
        'category': 'dinner',
        'description': '',
        'portions': 4,
        'prep_minutes': null,
        'cook_minutes': 30,
        'storage': null,
        'freezer_friendly': freezer,
        'reheating': null,
        'favourite': 0,
        'method_steps_json': '["Simmer"]',
        'declared_kcal': null,
        'declared_protein_g': null,
        'declared_carbs_g': null,
        'declared_fat_g': null,
        'declared_fibre_g': null,
        'nutrition_note': null,
        'created_at': '2026-11-01T08:00:00.000Z',
        'updated_at': '2026-11-01T08:00:00.000Z',
        'deleted_at': null,
      };
      final result = await repo.importJson(
        jsonEncode({
          'app': 'repforge',
          'formatVersion': 1,
          'schemaVersion': 4,
          'tables': {
            'recipes': [v4Recipe('a', 1), v4Recipe('b', 0)],
          },
        }),
      );
      expect(result.isOk, isTrue);
      final rows = await (db.select(
        db.recipes,
      )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
      expect(rows.map((r) => r.cookStepsJson), ['["Simmer"]', '["Simmer"]']);
      expect(rows.map((r) => r.freezing), ['yes', 'unknown']);
      expect(rows.first.portions, 4.0);
      expect(rows.first.prepStepsJson, '[]');
    });

    test('a schema v5 backup maps taxonomy labels and synonyms and '
        'quarantines unmatched values like the migration (M4)', () async {
      const ts = '2026-11-01T08:00:00.000Z';
      Map<String, Object?> ex(
        String id, {
        required String category,
        required String primary,
        required String secondary,
        required String equipment,
      }) => {
        'id': id,
        'created_at': ts,
        'updated_at': ts,
        'deleted_at': null,
        'name': id,
        'type': 'weighted',
        'category': category,
        'primary_muscle': primary,
        'secondary_muscles_json': secondary,
        'equipment_json': equipment,
        'is_custom': 1,
        'archived': 0,
      };
      final result = await repo.importJson(
        jsonEncode({
          'app': 'repforge',
          'formatVersion': 1,
          'schemaVersion': 5,
          'tables': {
            'exercises': [
              ex(
                'labels',
                category: 'Full body',
                primary: 'Quads',
                secondary: '["Hams"]',
                equipment: '["Dumbbells","Cable station"]',
              ),
              ex(
                'optional',
                category: 'push',
                primary: 'chest',
                secondary: '["Tentacles","triceps"]',
                equipment: '["Flux capacitor"]',
              ),
              ex(
                'required',
                category: 'Hybrid',
                primary: 'chest',
                secondary: '[]',
                equipment: '[]',
              ),
            ],
          },
        }),
      );
      expect(result.isOk, isTrue);
      final rows = {
        for (final e in await db.select(db.exercises).get()) e.id: e,
      };
      expect(rows['labels']!.category, 'fullBody');
      expect(rows['labels']!.primaryMuscle, 'quadriceps');
      expect(rows['labels']!.secondaryMusclesJson, '["hamstrings"]');
      expect(rows['labels']!.equipmentJson, '["dumbbell","cable"]');
      expect(rows['optional']!.secondaryMusclesJson, '["triceps"]');
      expect(rows['optional']!.equipmentJson, '[]');
      expect(rows['required']!.category, 'Hybrid');
      final q = {
        for (final r in await db.select(db.legacyQuarantine).get()) r.rowId: r,
      };
      expect(q.keys, unorderedEquals(['optional', 'required']));
      expect(q['optional']!.reason, contains('Tentacles'));
      expect(q['required']!.reason, contains('category "Hybrid"'));
      expect(q['required']!.sourceTable, 'exercises');
    });

    test('a schema v5 backup restores its training rows: supplied from '
        'is_custom, taxonomy names, target_reps as a range', () async {
      const ts = '2026-11-01T08:00:00.000Z';
      final result = await repo.importJson(
        jsonEncode({
          'app': 'repforge',
          'formatVersion': 1,
          'schemaVersion': 5,
          'tables': {
            'exercises': [
              {
                'id': 'lib',
                'created_at': ts,
                'updated_at': ts,
                'deleted_at': null,
                'name': 'Écarté',
                'type': 'weighted',
                'category': 'Push',
                'primary_muscle': 'front delts',
                'secondary_muscles_json': '["Triceps"]',
                'equipment_json': '["bench"]',
                'is_custom': 0,
                'archived': 0,
              },
              {
                'id': 'mine',
                'created_at': ts,
                'updated_at': ts,
                'deleted_at': null,
                'name': 'Mine',
                'type': 'timed',
                'category': 'core',
                'primary_muscle': 'abs',
                'secondary_muscles_json': '[]',
                'equipment_json': '[]',
                'is_custom': 1,
                'archived': 1,
              },
            ],
            'workout_plans': [
              {
                'id': 'p',
                'created_at': ts,
                'updated_at': ts,
                'deleted_at': null,
                'name': 'Push',
                'split': null,
                'scheduled_weekdays_json': '[]',
                'archived': 0,
              },
            ],
            'plan_exercises': [
              {
                'id': 'ok',
                'plan_id': 'p',
                'exercise_id': 'lib',
                'sort_order': 0,
                'target_sets': 3,
                'target_reps': 8,
                'target_load_kg': 60.0,
                'target_duration_sec': null,
                'rest_seconds': 120,
              },
              {
                'id': 'bad-reps',
                'plan_id': 'p',
                'exercise_id': 'lib',
                'sort_order': 1,
                'target_sets': 3,
                'target_reps': 500,
                'target_load_kg': null,
                'target_duration_sec': null,
                'rest_seconds': null,
              },
              {
                'id': 'bad-sets',
                'plan_id': 'p',
                'exercise_id': 'lib',
                'sort_order': 2,
                'target_sets': 0,
                'target_reps': 8,
                'target_load_kg': null,
                'target_duration_sec': null,
                'rest_seconds': null,
              },
            ],
            'workout_sessions': [
              {
                'id': 's',
                'created_at': ts,
                'updated_at': ts,
                'deleted_at': null,
                'name': 'S',
                'plan_id': null,
                'started_at': ts,
                'ended_at': null,
                'notes': '',
              },
            ],
            'session_sets': [
              {
                'id': 'good',
                'session_id': 's',
                'exercise_id': 'lib',
                'exercise_order': 0,
                'set_order': 0,
                'type': 'weighted',
                'load_kg': 80.0,
                'reps': 5,
                'completed': 1,
              },
              {
                'id': 'bad',
                'session_id': 's',
                'exercise_id': 'lib',
                'exercise_order': 0,
                'set_order': 1,
                'type': 'weighted',
                'load_kg': 80.0,
                'reps': 0,
                'average_heart_rate': 500,
                'completed': 1,
              },
            ],
          },
        }),
      );
      expect(result.isOk, isTrue);

      final ex = {for (final e in await db.select(db.exercises).get()) e.id: e};
      expect([ex['lib']!.supplied, ex['mine']!.supplied], [true, false]);
      expect(ex['lib']!.category, 'push');
      expect(ex['lib']!.primaryMuscle, 'frontDelts');
      expect(ex['lib']!.secondaryMusclesJson, '["triceps"]');
      expect(ex['lib']!.searchKey, 'ecarte');
      expect(ex['lib']!.aliasesJson, '[]');
      expect(ex['mine']!.archived, isTrue);

      final plans = {
        for (final p in await db.select(db.planExercises).get()) p.id: p,
      };
      expect(plans.keys, unorderedEquals(['ok', 'bad-reps']));
      expect([plans['ok']!.repsMin, plans['ok']!.repsMax], [8, 8]);
      expect(plans['ok']!.targetLoadKg, 60);
      expect(
        [plans['bad-reps']!.repsMin, plans['bad-reps']!.repsMax],
        [null, null],
      );

      final sets = {
        for (final s in await db.select(db.sessionSets).get()) s.id: s,
      };
      expect(sets['good']!.reps, 5);
      expect([sets['bad']!.reps, sets['bad']!.averageHeartRate], [null, null]);
      expect(sets['bad']!.loadKg, 80);
      // Pre-v7 sets get an exercise entry and the kind working.
      expect(
        [sets['good']!.setKind, sets['bad']!.setKind],
        ['working', 'working'],
      );
      final entries = await db.select(db.sessionExercises).get();
      expect(entries.map((e) => (e.id, e.sessionId, e.position)), [
        ('legacy:s:0', 's', 0),
      ]);
      expect(sets['good']!.sessionExerciseId, 'legacy:s:0');
      expect(sets['bad']!.sessionExerciseId, 'legacy:s:0');

      // Nothing is lost silently: the originals are kept.
      final q = {
        for (final r in await db.select(db.legacyQuarantine).get()) r.rowId: r,
      };
      expect(q.keys, unorderedEquals(['bad-reps', 'bad-sets', 'bad']));
      expect(
        (jsonDecode(q['bad-sets']!.originalJson) as Map)['target_sets'],
        0,
      );
    });

    test('a v6 backup (no session_exercises) restores with entries made '
        'from its sets, exercise_order untouched', () async {
      const ts = '2026-11-01T08:00:00.000Z';
      Map<String, Object?> set(String id, String ex, int order, int n) => {
        'id': id,
        'session_id': 's',
        'exercise_id': ex,
        'exercise_order': order,
        'set_order': n,
        'type': 'weighted',
        'load_kg': 80.0,
        'reps': 5,
        'energy_kcal': null,
        'energy_provenance': null,
        'completed': 1,
      };
      final result = await repo.importJson(
        jsonEncode({
          'app': 'repforge',
          'formatVersion': 1,
          'schemaVersion': 6,
          'tables': {
            'workout_sessions': [
              {
                'id': 's',
                'created_at': ts,
                'updated_at': ts,
                'deleted_at': null,
                'name': 'S',
                'plan_id': null,
                'started_at': ts,
                'ended_at': null,
                'notes': '',
              },
            ],
            'session_sets': [
              set('a', 'bench', 2, 0),
              set('b', 'bench', 2, 1),
              set('c', 'squat', 5, 0),
            ],
          },
        }),
      );
      expect(result.isOk, isTrue);
      final entries = await db.select(db.sessionExercises).get()
        ..sort((a, b) => a.position.compareTo(b.position));
      expect(entries.map((e) => (e.exerciseId, e.position)), [
        ('bench', 0),
        ('squat', 1),
      ]);
      final sets = {
        for (final x in await db.select(db.sessionSets).get()) x.id: x,
      };
      expect(sets['a']!.sessionExerciseId, entries[0].id);
      expect(sets['b']!.sessionExerciseId, entries[0].id);
      expect(sets['c']!.sessionExerciseId, entries[1].id);
      expect(
        [sets['a']!.exerciseOrder, sets['c']!.exerciseOrder],
        [2, 5],
        reason: 'stored exercise_order is not rewritten',
      );
    });

    test('a v7 backup keeps set kinds, entries, notes and scheduled '
        'workouts, and no entry is invented', () async {
      await _seed(db);
      await db.customStatement(
        "UPDATE session_sets SET set_kind = 'failure' WHERE id = 'ss'",
      );
      final json = await repo.exportJson();
      await db.customStatement('DELETE FROM scheduled_workouts');
      await db.customStatement('DELETE FROM session_exercises');
      expect((await repo.importJson(json)).isOk, isTrue);
      expect(await db.select(db.sessionExercises).get(), hasLength(1));
      expect(
        (await db.select(db.sessionExercises).get()).single.note,
        'felt strong',
      );
      expect(await db.select(db.scheduledWorkouts).get(), hasLength(1));
      expect((await db.select(db.sessionSets).get()).single.setKind, 'failure');
    });

    test('a v6 backup round-trips splits, aliases and cardio energy', () async {
      await _seed(db);
      await db.customStatement(
        'INSERT INTO exercises (id, created_at, updated_at, name, type, '
        'category, primary_muscle, secondary_muscles_json, equipment_json, '
        "aliases_json, search_key, supplied, copied_from_id) VALUES ('c', "
        "'2026-11-01T08:00:00.000Z', '2026-11-01T08:00:00.000Z', 'Copy', "
        "'weighted', 'push', 'chest', '[]', '[]', '[\"Alias\"]', "
        "'copy alias', 0, 'lib')",
      );
      await db.customStatement(
        'INSERT INTO session_sets (id, session_id, exercise_id, '
        'exercise_order, set_order, type, duration_sec, energy_kcal, '
        "energy_provenance) VALUES ('e1', 's', 'run', 0, 5, 'cardio', 600, "
        "150.5, 'userEntered')",
      );
      await db.customStatement(
        'INSERT INTO training_splits (id, created_at, updated_at, name, '
        "cycle_days) VALUES ('sp', '2026-11-01T08:00:00.000Z', "
        "'2026-11-01T08:00:00.000Z', 'U/L', 2)",
      );
      await db.customStatement(
        'INSERT INTO split_days (id, split_id, day_index, plan_id) VALUES '
        "('sp:0', 'sp', 0, 'p1'), ('sp:1', 'sp', 1, NULL)",
      );
      final json = await repo.exportJson();
      await db.customStatement('DELETE FROM training_splits');
      await db.customStatement('DELETE FROM session_sets');
      await db.customStatement('DELETE FROM exercises');

      expect((await repo.importJson(json)).isOk, isTrue);
      final c = await (db.select(
        db.exercises,
      )..where((e) => e.id.equals('c'))).getSingle();
      expect(
        [c.aliasesJson, c.searchKey, c.supplied, c.copiedFromId],
        ['["Alias"]', 'copy alias', false, 'lib'],
      );
      final e1 = await (db.select(
        db.sessionSets,
      )..where((s) => s.id.equals('e1'))).getSingle();
      expect([e1.energyKcal, e1.energyProvenance], [150.5, 'userEntered']);
      expect(await db.select(db.trainingSplits).get(), hasLength(1));
      expect(
        (await db.select(db.splitDays).get()).map((d) => d.planId).toSet(),
        {'p1', null},
      );
      expect(await db.select(db.legacyQuarantine).get(), isEmpty);
    });

    test('import replaces existing rows', () async {
      await _seed(db);
      final json = await repo.exportJson();

      await db.delete(db.measurements).go();
      await db
          .into(db.measurements)
          .insert(
            MeasurementsCompanion.insert(
              id: 'other',
              site: 'waist',
              value: 90,
              recordedAt: _t,
              createdAt: _t,
              updatedAt: _t,
            ),
          );
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'extra',
              kind: 'protein',
              target: 1,
              startDate: _t,
              createdAt: _t,
              updatedAt: _t,
            ),
          );

      final result = await repo.importJson(json);
      expect(result.isOk, isTrue);
      expect(await measurementIds(), ['m']);
      expect((await db.select(db.goals).get()).map((g) => g.id), ['g']);
    });

    test('invalid JSON returns ValidationError and keeps data', () async {
      await _seed(db);
      final r = await repo.importJson('{not json');
      expect((r as Err).error, isA<ValidationError>());
      expect(await measurementIds(), ['m']);
    });

    test('non-object JSON and foreign app return ValidationError', () async {
      await _seed(db);
      for (final json in [
        '[1,2]',
        '"hello"',
        jsonEncode({
          'app': 'other',
          'formatVersion': 1,
          'tables': <String, Object?>{},
        }),
        jsonEncode({'formatVersion': 1, 'tables': <String, Object?>{}}),
      ]) {
        final r = await repo.importJson(json);
        expect((r as Err).error, isA<ValidationError>(), reason: json);
      }
      expect(await measurementIds(), ['m']);
    });

    test('newer or non-integer formatVersion is refused', () async {
      await _seed(db);
      for (final v in [2, '1', null]) {
        final r = await repo.importJson(
          jsonEncode({
            'app': 'repforge',
            'formatVersion': v,
            'tables': <String, Object?>{},
          }),
        );
        expect((r as Err).error, isA<ValidationError>(), reason: '$v');
      }
      expect(await measurementIds(), ['m']);
    });

    test('missing tables map returns ValidationError', () async {
      await _seed(db);
      final r = await repo.importJson(
        jsonEncode({'app': 'repforge', 'formatVersion': 1}),
      );
      expect((r as Err).error, isA<ValidationError>());
      expect(await measurementIds(), ['m']);
    });

    test(
      'rows violating the schema fail with StorageError and roll back',
      () async {
        await _seed(db);
        final doc = _decode(await repo.exportJson());
        final tables = doc['tables']! as Map<String, Object?>;
        // Valid measurement first so rollback is observable, then a second row
        // missing the NOT NULL `value` column.
        tables['measurements'] = [
          {
            'id': 'new1',
            'site': 'waist',
            'value': 90.0,
            'recorded_at': 1,
            'note': null,
            'created_at': 1,
            'updated_at': 1,
            'deleted_at': null,
          },
          {'id': 'new2', 'site': 'waist'},
        ];

        final r = await repo.importJson(jsonEncode(doc));
        expect((r as Err).error, isA<StorageError>());
        expect(await measurementIds(), ['m']);
        expect(await db.select(db.foods).get(), hasLength(1));
        expect(await db.select(db.sessionSets).get(), hasLength(1));
      },
    );

    test('unknown tables and non-list rows are ignored', () async {
      await _seed(db);
      final r = await repo.importJson(
        jsonEncode({
          'app': 'repforge',
          'formatVersion': 1,
          'tables': {'mystery': <Object?>[], 'goals': 'nope'},
        }),
      );
      expect(r.isOk, isTrue);
      expect(await measurementIds(), isEmpty);
    });
  });
}
