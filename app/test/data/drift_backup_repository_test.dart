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
  'session_sets',
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
      .into(db.sessionSets)
      .insert(
        SessionSetsCompanion.insert(
          id: 'ss$suffix',
          sessionId: 's$suffix',
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
      expect(doc['schemaVersion'], 5);
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
