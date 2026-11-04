import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/planning/application/planning_providers.dart';
import 'package:repforge/features/recipes/application/recipe_providers.dart';

/// One planned item with its planned nutrition; [nutrition] is null when the
/// reference no longer exists (the item is unresolved, never zero).
final class PlannedLine {
  const PlannedLine({required this.item, required this.nutrition});

  final MealPlanItem item;
  final NutrientAmounts? nutrition;

  bool get resolved => nutrition != null;
}

/// What the plan screen shows for one day: the lines and the day summary
/// from `SummarisePlanDay` (same calculations as the log).
final class PlanDayView {
  const PlanDayView({required this.lines, required this.summary});

  final List<PlannedLine> lines;
  final PlanDaySummary summary;
}

/// The planned items of a day, resolved against recipes, foods and saved
/// meals. Recomputed when the plan, the recipes or the saved meals change.
// ignore: specify_nonobvious_property_types
final planDayViewProvider = FutureProvider.family<PlanDayView, String>((
  ref,
  day,
) async {
  final items = await ref.watch(planDayProvider(day).future);
  // Only to refresh when a recipe or saved meal is edited or deleted.
  await ref.watch(recipesProvider.future);
  await ref.watch(savedMealsProvider.future);
  final recipes = ref.read(recipeRepositoryProvider);
  final foods = ref.read(foodRepositoryProvider);
  final meals = ref.read(savedMealRepositoryProvider);
  final recipeMap = <String, Recipe>{};
  final foodMap = <String, Food>{};
  final mealMap = <String, SavedMeal>{};
  final lines = <PlannedLine>[];
  for (final item in items) {
    Recipe? recipe;
    Food? food;
    SavedMeal? meal;
    switch (item.kind) {
      case PlannedKind.recipe:
        recipe = await recipes.byId(item.refId);
        if (recipe != null) recipeMap[item.refId] = recipe;
      case PlannedKind.food:
        food = await foods.byId(item.refId);
        if (food != null) foodMap[item.refId] = food;
      case PlannedKind.savedMeal:
        meal = await meals.byId(item.refId);
        if (meal != null) mealMap[item.refId] = meal;
    }
    lines.add(
      PlannedLine(
        item: item,
        nutrition: plannedNutrition(
          item,
          recipe: recipe,
          food: food,
          savedMeal: meal,
        ),
      ),
    );
  }
  // The same pure calculation `SummarisePlanDay` runs, on the references
  // resolved above (one lookup per item, no second stream subscription).
  return PlanDayView(
    lines: lines,
    summary: summarisePlanDay(
      day,
      items,
      recipes: recipeMap,
      foods: foodMap,
      savedMeals: mealMap,
    ),
  );
});
