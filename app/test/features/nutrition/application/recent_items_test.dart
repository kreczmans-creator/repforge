import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/recent_items.dart';

final _t0 = DateTime.utc(2026, 11, 3, 9);

NutrientProfile _profile() => const NutrientProfile(
  per100: ReferenceUnit.grams,
  per100Amounts: NutrientAmounts(kcal: 100, proteinG: 10, carbsG: 5, fatG: 2),
  provenance: DataProvenance.userEntered,
);

Food _food(String id) => Food(
  id: id,
  name: 'Food $id',
  profile: _profile(),
  source: FoodSource.userCreated,
  createdAt: _t0,
  updatedAt: _t0,
);

Recipe _recipe(String id) => Recipe(
  id: id,
  name: 'Recipe $id',
  category: 'Dinner',
  portions: 2,
  ingredients: [
    RecipeIngredient(
      id: '$id-i',
      name: 'Beef',
      foodId: 'food-$id',
      quantity: Quantity.fromStored(400, ReferenceUnit.grams),
      sortOrder: 0,
      per100: _profile(),
    ),
  ],
  createdAt: _t0,
  updatedAt: _t0,
);

var _n = 0;
FoodLogEntry _entry({required int minute, String? foodId, String? recipeId}) {
  final at = _t0.add(Duration(minutes: minute));
  return FoodLogEntry(
    id: 'e${_n++}',
    day: '2026-11-03',
    meal: MealSlot.lunch,
    name: 'logged',
    quantity: Quantity.fromStored(100, ReferenceUnit.grams),
    nutrients: const NutrientAmounts(kcal: 100),
    provenance: DataProvenance.userEntered,
    loggedAt: at,
    createdAt: at,
    updatedAt: at,
    foodId: foodId,
    recipeId: recipeId,
  );
}

void main() {
  late AppDatabase db;
  late DriftFoodLogRepository log;
  late DriftFoodRepository foods;
  late DriftRecipeRepository recipes;
  late LoadRecentItems recent;

  setUp(() {
    db = AppDatabase.inMemory();
    final clock = FixedClock(_t0);
    log = DriftFoodLogRepository(db, clock: clock);
    foods = DriftFoodRepository(db, clock: clock);
    recipes = DriftRecipeRepository(db, clock: clock);
    recent = LoadRecentItems(log: log, foods: foods, recipes: recipes);
  });
  tearDown(() => db.close());

  Future<List<String>> names({int limit = 10}) async {
    final result = await recent(limit: limit);
    return [
      for (final i in (result as Ok<List<RecentItem>>).value)
        switch (i) {
          RecentFood(:final food) => 'food:${food.id}',
          RecentRecipe(:final recipe) => 'recipe:${recipe.id}',
        },
    ];
  }

  test('recent items list foods and recipes newest first', () async {
    await foods.upsert(_food('a'));
    await foods.upsert(_food('b'));
    await recipes.upsert(_recipe('r'));
    await log.insert(_entry(foodId: 'a', minute: 1));
    await log.insert(_entry(recipeId: 'r', minute: 2));
    await log.insert(_entry(foodId: 'b', minute: 3));
    expect(await names(), ['food:b', 'recipe:r', 'food:a']);
  });

  test('a source logged many times appears once at its latest time', () async {
    await foods.upsert(_food('a'));
    await foods.upsert(_food('b'));
    await log.insert(_entry(foodId: 'a', minute: 1));
    await log.insert(_entry(foodId: 'b', minute: 2));
    await log.insert(_entry(foodId: 'a', minute: 3));
    expect(await names(), ['food:a', 'food:b']);
  });

  test('recent items are limited to ten by default', () async {
    for (var i = 0; i < 12; i++) {
      await foods.upsert(_food('f$i'));
      await log.insert(_entry(foodId: 'f$i', minute: i));
    }
    final all = await names();
    expect(all, hasLength(10));
    expect(all.first, 'food:f11');
    expect(all.last, 'food:f2');
    expect(await names(limit: 3), ['food:f11', 'food:f10', 'food:f9']);
  });

  test('a deleted food or recipe is skipped and does not shorten the '
      'list', () async {
    await foods.upsert(_food('a'));
    await foods.upsert(_food('gone'));
    await recipes.upsert(_recipe('r'));
    await log.insert(_entry(foodId: 'a', minute: 1));
    await log.insert(_entry(recipeId: 'r', minute: 2));
    await log.insert(_entry(foodId: 'gone', minute: 3));
    await log.insert(_entry(foodId: 'never-existed', minute: 4));
    await foods.delete('gone');
    await recipes.delete('r');
    expect(await names(), ['food:a']);
  });

  test('deleted log entries and free-text entries are ignored', () async {
    await foods.upsert(_food('a'));
    final removed = _entry(foodId: 'a', minute: 5);
    await log.insert(removed);
    await log.delete(removed.id);
    await log.insert(_entry(minute: 6));
    expect(await names(), isEmpty);
  });
}
