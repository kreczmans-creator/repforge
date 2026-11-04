import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/nutrition/saved_meal_repository.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/recipes/recipe_repository.dart';
import 'package:repforge/domain/recipes/recipes.dart';

/// Use case: planned energy and macros of a day (RCP-014(2)), using the same
/// calculations as the log. References are resolved fresh each time, so a
/// recipe edited after planning is reflected, and a deleted reference makes
/// the item "unresolved" (unknown nutrition) instead of inventing a value.
final class SummarisePlanDay {
  const SummarisePlanDay({
    required this.plan,
    required this.recipes,
    required this.foods,
    required this.savedMeals,
  });

  final MealPlanRepository plan;
  final RecipeRepository recipes;
  final FoodRepository foods;
  final SavedMealRepository savedMeals;

  Future<Result<PlanDaySummary>> call(String day) async {
    try {
      final items = await plan.watchDay(day).first;
      final recipeMap = <String, Recipe>{};
      final foodMap = <String, Food>{};
      final mealMap = <String, SavedMeal>{};
      for (final item in items) {
        switch (item.kind) {
          case PlannedKind.recipe:
            final r = await recipes.byId(item.refId);
            if (r != null) recipeMap[item.refId] = r;
          case PlannedKind.food:
            final f = await foods.byId(item.refId);
            if (f != null) foodMap[item.refId] = f;
          case PlannedKind.savedMeal:
            final m = await savedMeals.byId(item.refId);
            if (m != null) mealMap[item.refId] = m;
        }
      }
      return Ok(
        summarisePlanDay(
          day,
          items,
          recipes: recipeMap,
          foods: foodMap,
          savedMeals: mealMap,
        ),
      );
    } on Exception catch (e) {
      return Err(StorageError('Could not read the plan.', cause: e));
    }
  }
}
