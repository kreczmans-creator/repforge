import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/features/recipes/application/import_legacy_recipes.dart';

final String _json = jsonEncode({
  'source': 'test',
  'formatVersion': 1,
  'recipes': [
    {
      'id': 'starter-a',
      'name': 'Burrito',
      'category': 'Lunch',
      'description': 'Wrap',
      'portions': 8,
      'perPortion': {
        'kcal': 460.0,
        'proteinG': 43.0,
        'carbsG': 48.0,
        'fatG': 11.0,
      },
      'ingredientLines': ['1 kg chicken breast', '8 tortillas'],
      'methodSteps': ['Dice', 'Cook'],
      'legacyFreezerFriendly': true,
      'nutritionNote': 'Approximate starting estimate',
    },
    {
      'id': 'starter-b',
      'name': 'Porridge',
      'category': 'Breakfast',
      'description': '',
      'portions': 1,
      'perPortion': {
        'kcal': 300.0,
        'proteinG': 12.0,
        'carbsG': 50.0,
        'fatG': 6.0,
      },
      'ingredientLines': ['50 g oats'],
      'methodSteps': ['Heat'],
      'legacyFreezerFriendly': false,
      'nutritionNote': 'Planning estimate',
    },
  ],
});

void main() {
  late AppDatabase db;
  late DriftRecipeRepository recipes;
  late DriftSettingsRepository settings;
  var loads = 0;
  final clock = FixedClock(DateTime.utc(2026, 11, 4, 9));

  ImportLegacyRecipes importer([String? json]) => ImportLegacyRecipes(
    recipes: recipes,
    settings: settings,
    clock: clock,
    loadJson: () async {
      loads++;
      return json ?? _json;
    },
  );

  setUp(() {
    db = AppDatabase.inMemory();
    recipes = DriftRecipeRepository(db, clock: clock);
    settings = DriftSettingsRepository(db, clock: clock);
    loads = 0;
  });
  tearDown(() => db.close());

  test('imports each recipe with notes, steps, declared nutrition and the '
      'legacy note', () async {
    final r = await importer()();
    final summary = (r as Ok<LegacyImportSummary>).value;
    expect(summary.imported, 2);
    expect(summary.alreadyPresent, 0);

    final a = (await recipes.byId('starter-a'))!;
    expect(a.name, 'Burrito');
    expect(a.category, 'Lunch');
    expect(a.description, 'Wrap');
    expect(a.portions, 8);
    expect(a.ingredients, isEmpty);
    expect(a.ingredientNotes, ['1 kg chicken breast', '8 tortillas']);
    expect(a.cookSteps, ['Dice', 'Cook']);
    expect(a.prepSteps, isEmpty);
    expect(a.nutritionNote, 'Approximate starting estimate');
    expect(
      a.declaredPerPortion,
      const NutrientAmounts(kcal: 460, proteinG: 43, carbsG: 48, fatG: 11),
    );
    expect(a.declaredPerPortion!.fibreG, isNull);
    expect(a.perPortion, a.declaredPerPortion);
    expect(a.nutritionSource, RecipeNutritionSource.declared);
    expect(a.perPortionTotals!.unknownFibreCount, 1);
    expect(a.favourite, isFalse);
    expect(a.createdAt, clock.now());
  });

  test('provenance is estimated', () async {
    await importer()();
    for (final id in ['starter-a', 'starter-b']) {
      expect((await recipes.byId(id))!.provenance, DataProvenance.estimated);
    }
  });

  test(
    'freezing is unknown whatever the legacy flag said (decision 3)',
    () async {
      await importer()();
      expect(
        (await recipes.byId('starter-a'))!.freezing,
        FreezingSuitability.unknown,
      ); // legacy true
      expect(
        (await recipes.byId('starter-b'))!.freezing,
        FreezingSuitability.unknown,
      ); // legacy false
    },
  );

  test(
    'runs once: the version is recorded and a second run does nothing',
    () async {
      await importer()();
      expect(await settings.readSeedRecipesVersion(), 2);
      final again = (await importer()() as Ok<LegacyImportSummary>).value;
      expect(again.alreadyDone, isTrue);
      expect(again.imported, 0);
      expect(loads, 1); // the file was not even read
      expect(await recipes.watchAll().first, hasLength(2));
    },
  );

  test('a seed deleted by the user is never re-created', () async {
    await importer()();
    await recipes.delete('starter-a');
    // Even if the version marker is lost, the soft-deleted id is respected.
    await settings.saveSeedRecipesVersion(0);
    final r = (await importer()() as Ok<LegacyImportSummary>).value;
    expect(r.imported, 0);
    expect(r.alreadyPresent, 2);
    expect(await recipes.byId('starter-a'), isNull);
    expect((await recipes.watchAll().first).map((x) => x.id), ['starter-b']);
  });

  test('an existing recipe with the same id is not overwritten', () async {
    final mine = Recipe(
      id: 'starter-b',
      name: 'My porridge',
      category: 'Breakfast',
      portions: 1,
      ingredients: const [],
      ingredientNotes: const ['oats'],
      declaredPerPortion: const NutrientAmounts(kcal: 111),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await recipes.upsert(mine);
    final r = (await importer()() as Ok<LegacyImportSummary>).value;
    expect([r.imported, r.alreadyPresent], [1, 1]);
    expect((await recipes.byId('starter-b'))!.name, 'My porridge');
  });

  test('an unreadable or invalid file imports nothing and does not record '
      'the version', () async {
    for (final bad in [
      'not json',
      '[]',
      jsonEncode({'formatVersion': 2, 'recipes': <Object?>[]}),
      jsonEncode({'formatVersion': 1}),
      jsonEncode({
        'formatVersion': 1,
        'recipes': [
          {'id': 'x'},
        ],
      }),
    ]) {
      final r = await importer(bad)();
      expect((r as Err).error, isA<ValidationError>(), reason: bad);
    }
    expect(await recipes.watchAll().first, isEmpty);
    expect(await settings.readSeedRecipesVersion(), 0);
  });

  test('a recipe that fails validation rejects the whole file', () async {
    final doc = jsonDecode(_json) as Map<String, Object?>;
    ((doc['recipes']! as List<Object?>)[1]!
            as Map<String, Object?>)['portions'] =
        0;
    final r = await importer(jsonEncode(doc))();
    expect((r as Err).error, isA<ValidationError>());
    expect(await recipes.watchAll().first, isEmpty);
  });

  test('a load failure is a StorageError and records nothing', () async {
    final failing = ImportLegacyRecipes(
      recipes: recipes,
      settings: settings,
      clock: clock,
      loadJson: () async => throw Exception('asset missing'),
    );
    expect(((await failing()) as Err).error, isA<StorageError>());
    expect(await settings.readSeedRecipesVersion(), 0);
  });

  test('M6 a loader that throws an Error (missing asset) is a typed failure '
      'and records nothing', () async {
    final r = await ImportLegacyRecipes(
      recipes: recipes,
      settings: settings,
      clock: clock,
      loadJson: () async => throw FlutterError('Unable to load asset'),
    )();
    expect(r, isA<Err<LegacyImportSummary>>());
    expect((r as Err<LegacyImportSummary>).error, isA<StorageError>());
    expect(await recipes.watchAll().first, isEmpty);
    expect(await settings.readSeedRecipesVersion(), 0);
    // A later launch with the asset present still imports.
    expect(((await importer()()) as Ok<LegacyImportSummary>).value.imported, 2);
  });

  test('M6 a synchronous throw from the loader is also caught', () async {
    final r = await ImportLegacyRecipes(
      recipes: recipes,
      settings: settings,
      clock: clock,
      loadJson: () => throw StateError('boom'),
    )();
    expect(r.isErr, isTrue);
  });
}
