import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';

import '../../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9);

Recipe _recipe(String id, String name, String category, {bool fav = false}) =>
    Recipe(
      id: id,
      name: name,
      category: category,
      portions: 2,
      favourite: fav,
      ingredients: [
        RecipeIngredient(
          id: '$id-i',
          name: 'Beef',
          foodId: 'food-$id',
          quantity: Quantity.fromStored(800, ReferenceUnit.grams),
          sortOrder: 0,
          per100: const NutrientProfile(
            per100: ReferenceUnit.grams,
            per100Amounts: NutrientAmounts(kcal: 100, proteinG: 10),
            provenance: DataProvenance.userEntered,
          ),
        ),
      ],
      createdAt: _now.toUtc(),
      updatedAt: _now.toUtc(),
    );

void main() {
  late AppDatabase db;
  late DriftRecipeRepository recipes;
  setUp(() {
    db = AppDatabase.inMemory();
    recipes = DriftRecipeRepository(db, clock: FixedClock(_now));
  });
  tearDown(() => db.close());

  Future<void> open(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(_now)),
          minuteTickProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: RepForgeApp(router: createRouter(initialLocation: location)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('duplicating a recipe stores a non-favourite copy with a '
      'suffixed name and opens it', (tester) async {
    await recipes.upsert(_recipe('stew', 'Stew', 'Lunch', fav: true));
    await open(tester, RfRoutes.fuelRecipe('stew'));
    await tester.tap(find.byKey(const Key('recipe-duplicate')));
    await tester.pumpAndSettle();

    final all = await recipes.watchAll().first;
    expect(all.map((r) => r.name), ['Stew', 'Stew (copy)']);
    final copy = all.firstWhere((r) => r.name == 'Stew (copy)');
    expect(copy.id, isNot('stew'));
    expect(copy.favourite, isFalse);
    expect(copy.category, 'Lunch');
    expect(all.firstWhere((r) => r.id == 'stew').favourite, isTrue);
    // Navigated to the new recipe.
    expect(
      tester.widget<Text>(find.byKey(const Key('recipe-name'))).data,
      'Stew (copy)',
    );
    await unmount(tester);
  });

  testWidgets('the category filter narrows the recipe list and combines '
      'with text search', (tester) async {
    await recipes.upsert(_recipe('a', 'Alpha stew', 'Lunch'));
    await recipes.upsert(_recipe('b', 'Beta bake', 'Dinner'));
    await recipes.upsert(_recipe('c', 'Gamma stew', 'Dinner'));
    await open(tester, RfRoutes.fuelRecipes);
    expect(find.byKey(const Key('recipe-category-filter')), findsOneWidget);
    expect(find.byKey(const Key('recipe-a')), findsOneWidget);
    expect(find.byKey(const Key('recipe-b')), findsOneWidget);

    await tester.tap(find.byKey(const Key('category-Dinner')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recipe-a')), findsNothing);
    expect(find.byKey(const Key('recipe-b')), findsOneWidget);
    expect(find.byKey(const Key('recipe-c')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('recipe-search')), 'stew');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recipe-b')), findsNothing);
    expect(find.byKey(const Key('recipe-c')), findsOneWidget);

    // Tapping the selected chip clears the category again.
    await tester.tap(find.byKey(const Key('category-Dinner')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recipe-a')), findsOneWidget);
    await unmount(tester);
  });
}
