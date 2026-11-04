import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/recipes/application/import_legacy_recipes.dart';
import 'package:repforge/features/recipes/application/recipe_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;
  var ids = 0;

  setUp(() {
    db = AppDatabase.inMemory();
    ids = 0;
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(
          FixedClock(DateTime.utc(2026, 11, 4, 9)),
        ),
        idGeneratorProvider.overrideWithValue(() => 'id${++ids}'),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('the bundled starter recipes asset is registered and imports', () async {
    final expected =
        (jsonDecode(File('assets/seed/legacy_recipes.json').readAsStringSync())
                as Map<String, Object?>)['recipes']!
            as List<Object?>;
    final r = await container.read(importLegacyRecipesProvider).call();
    expect((r as Ok<LegacyImportSummary>).value.imported, expected.length);
    final all = await container.read(recipeRepositoryProvider).watchAll().first;
    expect(all, hasLength(expected.length));
    expect(
      all.map((x) => x.provenance),
      everyElement(DataProvenance.estimated),
    );
    expect(
      all.map((x) => x.freezing),
      everyElement(FreezingSuitability.unknown),
    );
  });

  test('the use-case providers are wired to the same repositories', () async {
    final saved = await container.read(saveRecipeProvider)(
      Recipe(
        id: 'r1',
        name: 'Oats',
        category: 'breakfast',
        portions: 1,
        ingredients: [
          RecipeIngredient(
            id: 'i1',
            name: 'Oats',
            foodId: 'oats',
            quantity: Quantity.fromStored(100, ReferenceUnit.grams),
            sortOrder: 0,
            per100: const NutrientProfile(
              per100: ReferenceUnit.grams,
              per100Amounts: NutrientAmounts(kcal: 380),
              provenance: DataProvenance.verified,
            ),
          ),
        ],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    expect(saved.isOk, isTrue);
    final seen = <List<Recipe>>[];
    container.listen(
      recipesProvider,
      (_, next) => next.whenData(seen.add),
      fireImmediately: true,
    );
    await pumpEventQueue();
    expect(seen.last, hasLength(1));
    expect((await container.read(toggleFavouriteProvider)('r1')).isOk, isTrue);
    final logged = await container.read(logRecipeProvider)(
      recipeId: 'r1',
      meal: MealSlot.breakfast,
      day: '2026-11-04',
      portions: 2,
    );
    expect((logged as Ok<FoodLogEntry>).value.nutrients.kcal, 760);
    expect((await container.read(deleteRecipeProvider)('r1')).isOk, isTrue);
    await pumpEventQueue();
    expect(seen.last, isEmpty);
  });
}
