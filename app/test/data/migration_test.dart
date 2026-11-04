import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;
import 'generated_migrations/schema_v4.dart' as v4;
import 'generated_migrations/schema_v5.dart' as v5;

/// Every schema version must migrate to the current one without loss. Add a
/// case here for each new version (R-07: data loss from an untested
/// migration is the project's top data-integrity risk).
void main() {
  _v2ToV3();
  _v3ToV4();
  _v4ToV5();
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v1 weight_entries rows become measurements (site = weight)', () async {
    final schema = await verifier.schemaAt(1);
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb
        .into(oldDb.weightEntries)
        .insert(
          v1.WeightEntriesCompanion.insert(
            id: 'w1',
            recordedAt: '2026-11-01T08:00:00.000Z',
            weightKg: 82.4,
            note: const Value('morning'),
            createdAt: '2026-11-01T08:00:00.000Z',
            updatedAt: '2026-11-01T08:00:00.000Z',
          ),
        );
    await oldDb
        .into(oldDb.weightEntries)
        .insert(
          v1.WeightEntriesCompanion.insert(
            id: 'w2',
            recordedAt: '2026-11-02T08:00:00.000Z',
            weightKg: 81.9,
            createdAt: '2026-11-02T08:00:00.000Z',
            updatedAt: '2026-11-02T08:00:00.000Z',
            deletedAt: const Value('2026-11-03T00:00:00.000Z'),
          ),
        );
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);

    final migrated = v5.DatabaseAtV5(schema.newConnection());
    addTearDown(migrated.close);
    final rows = await (migrated.select(
      migrated.measurements,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    expect(rows.map((r) => r.id), ['w1', 'w2']);
    expect(rows.first.site, 'weight');
    expect(rows.first.value, 82.4);
    expect(rows.first.note, 'morning');
    expect(rows.first.recordedAt, '2026-11-01T08:00:00.000Z');
    expect(rows.last.deletedAt, '2026-11-03T00:00:00.000Z');
    expect(
      await migrated
          .customSelect(
            'SELECT name FROM sqlite_master '
            "WHERE type='table' AND name='weight_entries'",
          )
          .get(),
      isEmpty,
    );
  });
}

void _v2ToV3() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('schema v2 upgrades to v5 keeping existing rows', () async {
    final schema = await verifier.schemaAt(2);
    final oldDb = v2.DatabaseAtV2(schema.newConnection());
    await oldDb
        .into(oldDb.measurements)
        .insert(
          v2.MeasurementsCompanion.insert(
            id: 'm1',
            site: 'weight',
            value: 80.5,
            recordedAt: '2026-11-01T08:00:00.000Z',
            createdAt: '2026-11-01T08:00:00.000Z',
            updatedAt: '2026-11-01T08:00:00.000Z',
          ),
        );
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);

    final migrated = v5.DatabaseAtV5(schema.newConnection());
    addTearDown(migrated.close);
    expect(
      (await migrated.select(migrated.measurements).get()).single.id,
      'm1',
    );
    expect(await migrated.select(migrated.savedMeals).get(), isEmpty);
  });

  test('schema v1 upgrades straight to v5', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);
  });

  test('v2 upgrade can run again after a crash before user_version is '
      'recorded', () async {
    final schema = await verifier.schemaAt(2);
    final first = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(first, 5);
    await first.customStatement('PRAGMA user_version = 2');
    await first.close();

    final second = AppDatabase(schema.newConnection());
    addTearDown(second.close);
    expect(await second.select(second.savedMeals).get(), isEmpty);
    final version = await second
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 5);
  });

  test('v1 upgrade can run again after a crash before user_version is '
      'recorded', () async {
    // drift writes user_version after onUpgrade returns; a kill in that
    // window leaves the migrated schema with user_version still 1.
    final schema = await verifier.schemaAt(1);
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb
        .into(oldDb.weightEntries)
        .insert(
          v1.WeightEntriesCompanion.insert(
            id: 'w1',
            recordedAt: '2026-11-01T08:00:00.000Z',
            weightKg: 82.4,
            createdAt: '2026-11-01T08:00:00.000Z',
            updatedAt: '2026-11-01T08:00:00.000Z',
          ),
        );
    await oldDb.close();

    final first = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(first, 5);
    await first.customStatement('PRAGMA user_version = 1');
    await first.close();

    final second = AppDatabase(schema.newConnection());
    addTearDown(second.close);
    final rows = await second.select(second.measurements).get();
    expect(rows.map((r) => r.id), ['w1']);
    expect(await second.select(second.savedMeals).get(), isEmpty);
    final version = await second
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 5);
  });
}

void _v3ToV4() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  const t = '2026-11-01T08:00:00.000Z';

  Future<void> insertV3Rows(v3.DatabaseAtV3 old) async {
    await old
        .into(old.foods)
        .insert(
          v3.FoodsCompanion.insert(
            id: 'f1',
            name: 'Oats',
            per100Unit: 'grams',
            kcal: 370,
            proteinG: 13,
            carbsG: 60,
            fatG: 7,
            fibreG: const Value(10),
            provenance: 'userEntered',
            source: 'userCreated',
            searchKey: 'oats',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await old
        .into(old.foodServings)
        .insert(
          v3.FoodServingsCompanion.insert(
            id: 'f1:0',
            foodId: 'f1',
            label: 'bowl',
            amount: 40,
            unit: 'grams',
            sortOrder: 0,
          ),
        );
    await old
        .into(old.foodLogEntries)
        .insert(
          v3.FoodLogEntriesCompanion.insert(
            id: 'e1',
            day: '2026-11-01',
            meal: 'breakfast',
            name: 'Oats',
            amount: 40,
            unit: 'grams',
            kcal: 148,
            proteinG: 5.2,
            carbsG: 24,
            fatG: 2.8,
            provenance: 'userEntered',
            loggedAt: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
    await old
        .into(old.savedMeals)
        .insert(
          v3.SavedMealsCompanion.insert(
            id: 'sm1',
            name: 'Usual',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await old
        .into(old.savedMealItems)
        .insert(
          v3.SavedMealItemsCompanion.insert(
            id: 'i1',
            savedMealId: 'sm1',
            name: 'Oats',
            amount: 40,
            unit: 'grams',
            sortOrder: 0,
            kcal: 148,
            proteinG: 5.2,
            carbsG: 24,
            fatG: 2.8,
            provenance: 'userEntered',
          ),
        );
  }

  Future<void> expectRowsKept(v5.DatabaseAtV5 db) async {
    final food = (await db.select(db.foods).get()).single;
    expect(
      [food.id, food.proteinG, food.carbsG, food.fatG, food.fibreG],
      ['f1', 13, 60, 7, 10],
    );
    expect((await db.select(db.foodServings).get()).single.id, 'f1:0');
    final entry = (await db.select(db.foodLogEntries).get()).single;
    expect([entry.id, entry.kcal, entry.proteinG], ['e1', 148, 5.2]);
    final item = (await db.select(db.savedMealItems).get()).single;
    expect([item.id, item.carbsG, item.fatG], ['i1', 24, 2.8]);
  }

  test('v3 upgrade to v4 keeps a food, a log entry and a saved-meal item, '
      'and allows unknown macros afterwards', () async {
    final schema = await verifier.schemaAt(3);
    final oldDb = v3.DatabaseAtV3(schema.newConnection());
    await insertV3Rows(oldDb);
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);

    final migrated = v5.DatabaseAtV5(schema.newConnection());
    addTearDown(migrated.close);
    await expectRowsKept(migrated);

    await migrated
        .into(migrated.foodLogEntries)
        .insert(
          v5.FoodLogEntriesCompanion.insert(
            id: 'e2',
            day: '2026-11-01',
            meal: 'snack',
            name: 'Mystery',
            amount: 100,
            unit: 'grams',
            kcal: 100,
            provenance: 'crowdsourced',
            loggedAt: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
    final e2 = await (migrated.select(
      migrated.foodLogEntries,
    )..where((r) => r.id.equals('e2'))).getSingle();
    expect(e2.proteinG, isNull);
  });

  test('v3 upgrade can run again after a crash before user_version is '
      'recorded', () async {
    final schema = await verifier.schemaAt(3);
    final oldDb = v3.DatabaseAtV3(schema.newConnection());
    await insertV3Rows(oldDb);
    await oldDb.close();

    final first = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(first, 5);
    await first.customStatement('PRAGMA user_version = 3');
    await first.close();

    final second = AppDatabase(schema.newConnection());
    addTearDown(second.close);
    expect((await second.select(second.foods).get()).single.id, 'f1');
    expect((await second.select(second.foodServings).get()).single.id, 'f1:0');
    expect((await second.select(second.foodLogEntries).get()).single.id, 'e1');
    expect((await second.select(second.savedMealItems).get()).single.id, 'i1');
    final version = await second
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 5);
  });
}

void _v4ToV5() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  const t = '2026-11-01T08:00:00.000Z';

  Future<void> insertV4Recipes(v4.DatabaseAtV4 old) async {
    await old
        .into(old.recipes)
        .insert(
          v4.RecipesCompanion.insert(
            id: 'r1',
            name: 'Chilli',
            category: 'dinner',
            portions: 4,
            methodStepsJson: jsonEncode(['Brown the mince', 'Simmer']),
            freezerFriendly: const Value(1),
            favourite: const Value(1),
            prepMinutes: const Value(15),
            cookMinutes: const Value(45),
            storage: const Value('Fridge 3 days'),
            reheating: const Value('Hob'),
            declaredKcal: const Value(450),
            declaredProteinG: const Value(30),
            nutritionNote: const Value('est'),
            createdAt: t,
            updatedAt: t,
          ),
        );
    await old
        .into(old.recipes)
        .insert(
          v4.RecipesCompanion.insert(
            id: 'r2',
            name: 'Plain',
            category: 'lunch',
            portions: 1,
            methodStepsJson: '[]',
            createdAt: t,
            updatedAt: t,
            deletedAt: const Value(t),
          ),
        );
    await old
        .into(old.recipeIngredients)
        .insert(
          v4.RecipeIngredientsCompanion.insert(
            id: 'i1',
            recipeId: 'r1',
            name: 'Mince',
            foodId: const Value('f1'),
            amount: 500,
            unit: 'grams',
            sortOrder: 0,
            kcal: const Value(250),
            proteinG: const Value(20),
            provenance: const Value('verified'),
          ),
        );
  }

  Future<void> expectRecipesMigrated(v5.DatabaseAtV5 db) async {
    final rows = await (db.select(
      db.recipes,
    )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
    expect(rows.map((r) => r.id), ['r1', 'r2']);
    final r1 = rows.first;
    expect(r1.portions, 4.0);
    expect(r1.portions, isA<double>());
    // The v4 method becomes the cooking steps; there are no prep steps.
    expect(jsonDecode(r1.cookStepsJson), ['Brown the mince', 'Simmer']);
    expect(r1.prepStepsJson, '[]');
    // true -> yes; false meant "not stated" -> unknown (never "no").
    expect(r1.freezing, 'yes');
    expect(rows.last.freezing, 'unknown');
    expect(r1.totalWeightG, isNull);
    expect(r1.portionWeightG, isNull);
    expect(r1.ingredientNotesJson, '[]');
    expect(
      [r1.favourite, r1.prepMinutes, r1.cookMinutes, r1.storage, r1.reheating],
      [1, 15, 45, 'Fridge 3 days', 'Hob'],
    );
    expect(
      [r1.declaredKcal, r1.declaredProteinG, r1.nutritionNote],
      [450, 30, 'est'],
    );
    expect(rows.last.deletedAt, t);
    // The ingredient survives the rebuild of recipes (no cascade delete).
    final ing = (await db.select(db.recipeIngredients).get()).single;
    expect(
      [ing.id, ing.recipeId, ing.amount, ing.kcal],
      ['i1', 'r1', 500, 250],
    );
    expect(ing.servingLabel, isNull);
    expect(ing.servingCount, isNull);
    expect(await db.select(db.recipeSubstitutes).get(), isEmpty);
    expect(await db.select(db.mealPlanItems).get(), isEmpty);
    expect(await db.select(db.prepBatches).get(), isEmpty);
  }

  test('v4 upgrade to v5 keeps recipes and ingredients: method becomes cook '
      'steps, freezer flag maps, portions become real', () async {
    final schema = await verifier.schemaAt(4);
    final oldDb = v4.DatabaseAtV4(schema.newConnection());
    await insertV4Recipes(oldDb);
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);

    final migrated = v5.DatabaseAtV5(schema.newConnection());
    addTearDown(migrated.close);
    await expectRecipesMigrated(migrated);

    // Fractional portions are now storable.
    await migrated.customStatement(
      "UPDATE recipes SET portions = 2.5 WHERE id = 'r1'",
    );
    expect((await migrated.select(migrated.recipes).get()).first.portions, 2.5);
  });

  test('v4 upgrade can run again after a crash before user_version is '
      'recorded', () async {
    final schema = await verifier.schemaAt(4);
    final oldDb = v4.DatabaseAtV4(schema.newConnection());
    await insertV4Recipes(oldDb);
    await oldDb.close();

    final first = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(first, 5);
    // Add data that only exists in v5 so a re-run would show lost columns.
    await first.customStatement(
      'UPDATE recipes SET total_weight_g = 900, '
      "ingredient_notes_json = '[\"a\"]' WHERE id = 'r1'",
    );
    await first.customStatement(
      "UPDATE recipe_ingredients SET serving_label = 'cup', serving_count = 2 "
      "WHERE id = 'i1'",
    );
    await first.customStatement('PRAGMA user_version = 4');
    await first.close();

    final second = AppDatabase(schema.newConnection());
    addTearDown(second.close);
    final r1 = await (second.select(
      second.recipes,
    )..where((r) => r.id.equals('r1'))).getSingle();
    expect(jsonDecode(r1.cookStepsJson), ['Brown the mince', 'Simmer']);
    expect(r1.freezing, 'yes');
    expect(r1.totalWeightG, 900);
    expect(r1.ingredientNotesJson, '["a"]');
    final ing = (await second.select(second.recipeIngredients).get()).single;
    expect([ing.servingLabel, ing.servingCount], ['cup', 2]);
    final version = await second
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 5);
  });

  test('prep batches refuse negative portions remaining', () async {
    final schema = await verifier.schemaAt(4);
    final oldDb = v4.DatabaseAtV4(schema.newConnection());
    await insertV4Recipes(oldDb);
    await oldDb.close();
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);
    final migrated = v5.DatabaseAtV5(schema.newConnection());
    addTearDown(migrated.close);
    Future<void> batch(double remaining) => migrated
        .into(migrated.prepBatches)
        .insert(
          v5.PrepBatchesCompanion.insert(
            id: 'b$remaining',
            recipeId: 'r1',
            preparedAt: t,
            portionsMade: 6,
            portionsRemaining: remaining,
            createdAt: t,
            updatedAt: t,
          ),
        );
    await batch(0);
    await expectLater(batch(-1), throwsA(anything));
  });
}
