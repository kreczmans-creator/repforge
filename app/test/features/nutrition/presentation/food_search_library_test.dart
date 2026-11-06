import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/data/repositories/drift_saved_meal_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';

import '../../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9);

final class _NoLookup implements FoodLookupService {
  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async =>
      const Ok([]);

  @override
  Future<Result<Food?>> byBarcode(String barcode) async => const Ok(null);
}

NutrientProfile _profile() => const NutrientProfile(
  per100: ReferenceUnit.grams,
  per100Amounts: NutrientAmounts(kcal: 100, proteinG: 10, carbsG: 5, fatG: 2),
  provenance: DataProvenance.userEntered,
);

Food _food() => Food(
  id: 'oats',
  name: 'Oats',
  profile: _profile(),
  source: FoodSource.userCreated,
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

Recipe _stew() => Recipe(
  id: 'stew',
  name: 'Stew',
  category: 'Lunch',
  portions: 2,
  ingredients: [
    RecipeIngredient(
      id: 'beef',
      name: 'Beef',
      foodId: 'food-beef',
      quantity: Quantity.fromStored(800, ReferenceUnit.grams),
      sortOrder: 0,
      per100: _profile(),
    ),
  ],
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

SavedMeal _meal() => SavedMeal(
  id: 'm1',
  name: 'Usual breakfast',
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
  items: [
    SavedMealItem(
      id: 'm1-0',
      name: 'Toast',
      quantity: Quantity.fromStored(100, ReferenceUnit.grams),
      nutrients: const NutrientAmounts(kcal: 250),
      provenance: DataProvenance.userEntered,
      sortOrder: 0,
    ),
  ],
);

FoodLogEntry _logged({String? foodId, String? recipeId}) => FoodLogEntry(
  id: 'old',
  day: '2026-11-02',
  meal: MealSlot.lunch,
  name: foodId != null ? 'Oats' : 'Stew',
  quantity: Quantity.fromStored(100, ReferenceUnit.grams),
  nutrients: const NutrientAmounts(kcal: 100),
  provenance: DataProvenance.userEntered,
  loggedAt: _now.toUtc(),
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
  foodId: foodId,
  recipeId: recipeId,
);

void main() {
  late AppDatabase db;
  late DriftFoodLogRepository log;
  setUp(() {
    db = AppDatabase.inMemory();
    log = DriftFoodLogRepository(db, clock: FixedClock(_now));
  });
  tearDown(() => db.close());

  Future<void> open(
    WidgetTester tester, {
    String location = RfRoutes.fuelSearch,
  }) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(_now)),
          foodLookupServiceProvider.overrideWithValue(_NoLookup()),
          minuteTickProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: RepForgeApp(router: createRouter(initialLocation: location)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('picking a recipe from the library logs it and returns to '
      'Fuel', (tester) async {
    await DriftRecipeRepository(db, clock: FixedClock(_now)).upsert(_stew());
    await open(tester);
    await tapKey(tester, 'search-pick-recipe');
    expect(find.text('Choose a recipe'), findsOneWidget);
    await tapKey(tester, 'recipe-stew');
    expect(find.byKey(const Key('log-submit')), findsOneWidget);
    await tapKey(tester, 'log-submit');
    expect(find.byKey(const Key('log-food')), findsOneWidget);
    expect(find.byKey(const Key('food-query')), findsNothing);
    final entries = await log.forDays('2026-11-03', '2026-11-03');
    expect(entries.single.recipeId, 'stew');
    await unmount(tester);
  });

  testWidgets('picking a saved meal from the library logs it and returns '
      'to Fuel', (tester) async {
    await DriftSavedMealRepository(db, clock: FixedClock(_now)).upsert(_meal());
    await open(tester);
    await tapKey(tester, 'search-pick-saved-meal');
    expect(find.text('Choose a saved meal'), findsOneWidget);
    await tapKey(tester, 'log-meal-m1');
    expect(find.byKey(const Key('log-food')), findsOneWidget);
    expect(find.byKey(const Key('food-query')), findsNothing);
    final entries = await log.forDays('2026-11-03', '2026-11-03');
    expect(entries.map((e) => e.name), ['Toast']);
    await unmount(tester);
  });

  testWidgets('the recent section lists logged foods and recipes and opens '
      'the matching sheet', (tester) async {
    await DriftFoodRepository(db, clock: FixedClock(_now)).upsert(_food());
    await DriftRecipeRepository(db, clock: FixedClock(_now)).upsert(_stew());
    await log.insert(_logged(foodId: 'oats'));
    await log.insert(_logged(recipeId: 'stew').copyWith(id: 'old2'));
    await open(tester);
    expect(find.byKey(const Key('search-recent')), findsOneWidget);
    expect(find.byKey(const Key('recent-food-oats')), findsOneWidget);
    expect(find.byKey(const Key('recent-recipe-stew')), findsOneWidget);

    await tapKey(tester, 'recent-recipe-stew');
    expect(find.byKey(const Key('log-submit')), findsOneWidget);
    expect(find.byKey(const Key('log-portions')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await tester.pumpAndSettle();

    await tapKey(tester, 'recent-food-oats');
    expect(find.byKey(const Key('log-portions')), findsNothing);
    expect(find.text('Oats'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('the recent section is absent when nothing was logged', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('search-recent')), findsNothing);
    expect(find.byKey(const Key('search-pick-recipe')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the recent list refreshes after logging from the search '
      'screen', (tester) async {
    await DriftFoodRepository(db, clock: FixedClock(_now)).upsert(_food());
    await open(tester);
    expect(find.byKey(const Key('search-recent')), findsNothing);
    await log.insert(_logged(foodId: 'oats'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-recent')), findsOneWidget);
    expect(find.byKey(const Key('recent-food-oats')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('cancelling a library pick with back returns to search '
      'without popping', (tester) async {
    await DriftRecipeRepository(db, clock: FixedClock(_now)).upsert(_stew());
    await open(tester);
    await tapKey(tester, 'search-pick-recipe');
    expect(find.text('Choose a recipe'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Choose a recipe'), findsNothing);
    expect(find.byKey(const Key('food-query')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the pick-from-library row and recents are hidden in pickOnly '
      'mode', (tester) async {
    await DriftFoodRepository(db, clock: FixedClock(_now)).upsert(_food());
    await log.insert(_logged(foodId: 'oats'));
    await open(tester, location: '${RfRoutes.fuelSearch}?pick=1');
    expect(find.byKey(const Key('food-query')), findsOneWidget);
    expect(find.byKey(const Key('search-pick-recipe')), findsNothing);
    expect(find.byKey(const Key('search-pick-saved-meal')), findsNothing);
    expect(find.byKey(const Key('search-recent')), findsNothing);
    await unmount(tester);
  });
}
