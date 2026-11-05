import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/core/transactor.dart';
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
/// confirming, then records the created entry ids on the item.
///
/// The whole operation (re-reading the item, the eaten check, logging, the
/// prep-batch decrement and recording the entry ids) runs in ONE transaction:
/// it all happens or none of it does, and two concurrent calls on one item
/// are serialised so the second sees it eaten and logs nothing.
///
/// Refuses an item already marked eaten, an item planned for a day after
/// today (the diary's today, honouring the day-start setting), and an item
/// whose recipe, food or saved meal was deleted (`NotFoundError`).
///
/// Entries go on the item's planned day unless `logDay` is given.
final class MarkPlannedEaten {
  const MarkPlannedEaten({
    required this.plan,
    required this.recipes,
    required this.foods,
    required this.savedMeals,
    required this.logFood,
    required this.logRecipe,
    required this.logSavedMeal,
    required this.transactor,
    required this.todayKey,
  });

  final MealPlanRepository plan;
  final RecipeRepository recipes;
  final FoodRepository foods;
  final SavedMealRepository savedMeals;
  final LogFood logFood;
  final LogRecipe logRecipe;
  final LogSavedMeal logSavedMeal;
  final Transactor transactor;

  /// The diary's current day key (honours the day-start setting).
  final String Function() todayKey;

  Future<Result<List<FoodLogEntry>>> call(
    String itemId, {
    double? overrideQuantity,
    String? logDay,
    String? prepBatchId,
  }) async {
    try {
      return Ok(
        await transactor.run(
          () => _markEaten(
            itemId,
            overrideQuantity: overrideQuantity,
            logDay: logDay,
            prepBatchId: prepBatchId,
          ),
        ),
      );
    } on _Refused catch (r) {
      return Err(r.error);
    } on Exception catch (e) {
      return Err(StorageError('Could not mark the item as eaten.', cause: e));
    }
  }

  /// Runs inside the transaction. A refusal is thrown as [_Refused] so that
  /// anything already written (batch decrement, entries) is rolled back.
  Future<List<FoodLogEntry>> _markEaten(
    String itemId, {
    required double? overrideQuantity,
    required String? logDay,
    required String? prepBatchId,
  }) async {
    final item = await plan.byId(itemId);
    if (item == null) {
      throw const _Refused(
        NotFoundError('That planned item no longer exists.'),
      );
    }
    if (item.isEaten) {
      throw const _Refused(
        ValidationError(
          'This planned item is already marked as eaten.',
          field: PlanErrorField.alreadyEaten,
        ),
      );
    }
    if (item.day.compareTo(todayKey()) > 0) {
      throw const _Refused(
        ValidationError(
          'A planned meal can only be marked as eaten on or after its day.',
          field: PlanErrorField.day,
        ),
      );
    }
    final amount = overrideQuantity ?? item.quantity;
    if (!amount.isFinite || amount <= 0) {
      throw const _Refused(
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
          throw _Refused(_gone('recipe'));
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
        if (food == null) throw _Refused(_gone('food'));
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
        if (meal == null) throw _Refused(_gone('saved meal'));
        final scaled = _scaled(meal, amount);
        if (scaled case Err(:final error)) throw _Refused(error);
        logged = await logSavedMeal(
          meal: (scaled as Ok<SavedMeal>).value,
          slot: item.meal,
          day: day,
        );
    }
    if (logged case Err(:final error)) throw _Refused(error);
    final entries = (logged as Ok<List<FoodLogEntry>>).value;
    await plan.markEaten(item.id, [for (final e in entries) e.id]);
    return entries;
  }
}

/// A deliberate refusal raised inside the transaction so it rolls back.
final class _Refused implements Exception {
  const _Refused(this.error);
  final AppError error;
}

NotFoundError _gone(String what) => NotFoundError(
  'The planned $what no longer exists, so it cannot be logged.',
);

/// The saved meal with every item snapshot multiplied by [rawMultiplier]
/// (rounded to 0.01);
/// the unchanged meal when it is 1.
Result<SavedMeal> _scaled(SavedMeal meal, double rawMultiplier) {
  if (rawMultiplier == 1) return Ok(meal);
  // The multiplier is a portion count: 0.01 steps (spec §2.1).
  final m = Quantity.of(rawMultiplier, ReferenceUnit.portions);
  if (m case Err(:final error)) return Err(error);
  final multiplier = (m as Ok<Quantity>).value.amount;
  if (multiplier <= 0) {
    return const Err(
      ValidationError(
        'Enter an amount greater than zero.',
        field: PlanErrorField.quantity,
      ),
    );
  }
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
