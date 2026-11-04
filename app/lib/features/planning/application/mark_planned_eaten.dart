import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/nutrition/saved_meal_repository.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/recipes/recipe_repository.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/log_food.dart';
import 'package:repforge/features/nutrition/application/saved_meals.dart';
import 'package:repforge/features/recipes/application/log_recipe.dart';

/// Use case: mark a planned item as eaten (RCP-014(3)).
///
/// Creates the diary entries through the existing `LogFood`, `LogRecipe` and
/// `LogSavedMeal` use cases (no logging logic is duplicated) with the planned
/// quantity, or `overrideQuantity` when the user changed it before
/// confirming, then records the created entry ids on the item. Refuses an
/// item already marked eaten, so a second tap cannot log twice. When the
/// referenced recipe, food or saved meal was deleted, returns a
/// `NotFoundError` and logs nothing.
///
/// Entries go on the item's planned day unless `logDay` is given.
final class MarkPlannedEaten {
  const MarkPlannedEaten({
    required this.plan,
    required this.recipes,
    required this.foods,
    required this.savedMeals,
    required this.log,
    required this.logFood,
    required this.logRecipe,
    required this.logSavedMeal,
  });

  final MealPlanRepository plan;
  final RecipeRepository recipes;
  final FoodRepository foods;
  final SavedMealRepository savedMeals;
  final FoodLogRepository log;
  final LogFood logFood;
  final LogRecipe logRecipe;
  final LogSavedMeal logSavedMeal;

  Future<Result<List<FoodLogEntry>>> call(
    String itemId, {
    double? overrideQuantity,
    String? logDay,
    String? prepBatchId,
  }) async {
    try {
      final item = await plan.byId(itemId);
      if (item == null) {
        return const Err(NotFoundError('That planned item no longer exists.'));
      }
      if (item.isEaten) {
        return const Err(
          ValidationError(
            'This planned item is already marked as eaten.',
            field: PlanErrorField.alreadyEaten,
          ),
        );
      }
      final amount = overrideQuantity ?? item.quantity;
      if (!amount.isFinite || amount <= 0) {
        return const Err(
          ValidationError(
            'Enter an amount greater than zero.',
            field: PlanErrorField.quantity,
          ),
        );
      }
      final day = logDay ?? item.day;
      final Result<List<FoodLogEntry>> logged;
      switch (item.kind) {
        case PlannedKind.recipe:
          if (await recipes.byId(item.refId) == null) {
            return Err(_gone('recipe'));
          }
          final r = await logRecipe(
            recipeId: item.refId,
            meal: item.meal,
            day: day,
            portions: amount,
            prepBatchId: prepBatchId,
          );
          logged = switch (r) {
            Ok(:final value) => Ok([value]),
            Err(:final error) => Err(error),
          };
        case PlannedKind.food:
          final food = await foods.byId(item.refId);
          if (food == null) return Err(_gone('food'));
          final r = await logFood(
            food: food,
            amount: amount,
            meal: item.meal,
            day: day,
          );
          logged = switch (r) {
            Ok(:final value) => Ok([value]),
            Err(:final error) => Err(error),
          };
        case PlannedKind.savedMeal:
          final meal = await savedMeals.byId(item.refId);
          if (meal == null) return Err(_gone('saved meal'));
          final scaled = _scaled(meal, amount);
          if (scaled case Err(:final error)) return Err(error);
          logged = await logSavedMeal(
            meal: (scaled as Ok<SavedMeal>).value,
            slot: item.meal,
            day: day,
          );
      }
      if (logged case Err(:final error)) return Err(error);
      final entries = (logged as Ok<List<FoodLogEntry>>).value;
      try {
        await plan.markEaten(item.id, [for (final e in entries) e.id]);
      } on Exception {
        // Do not leave logged entries behind an item still shown as
        // uneaten (a retry would log twice).
        for (final e in entries) {
          await log.delete(e.id);
        }
        rethrow;
      }
      return Ok(entries);
    } on Exception catch (e) {
      return Err(StorageError('Could not mark the item as eaten.', cause: e));
    }
  }
}

NotFoundError _gone(String what) => NotFoundError(
  'The planned $what no longer exists, so it cannot be logged.',
);

/// The saved meal with every item snapshot multiplied by [multiplier];
/// the unchanged meal when it is 1.
Result<SavedMeal> _scaled(SavedMeal meal, double multiplier) {
  if (multiplier == 1) return Ok(meal);
  final items = <SavedMealItem>[];
  for (final i in meal.items) {
    final q = Quantity.of(i.quantity.amount * multiplier, i.quantity.unit);
    if (q case Err(:final error)) return Err(error);
    items.add(
      i.copyWith(
        quantity: (q as Ok<Quantity>).value,
        nutrients: i.nutrients.scaled(multiplier),
      ),
    );
  }
  return Ok(meal.copyWith(items: items));
}
