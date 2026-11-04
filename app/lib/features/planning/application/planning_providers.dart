import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/planning/application/mark_planned_eaten.dart';
import 'package:repforge/features/planning/application/plan_item.dart';
import 'package:repforge/features/planning/application/plan_summary.dart';
import 'package:repforge/features/planning/application/prep_batches.dart';
import 'package:repforge/features/recipes/application/recipe_providers.dart';

/// Planned items of one day (`YYYY-MM-DD`).
// ignore: specify_nonobvious_property_types
final planDayProvider = StreamProvider.family<List<MealPlanItem>, String>(
  (ref, day) => ref.watch(mealPlanRepositoryProvider).watchDay(day),
);

/// Planned items from the first to the second day, inclusive.
// ignore: specify_nonobvious_property_types
final planRangeProvider =
    StreamProvider.family<List<MealPlanItem>, ({String from, String to})>(
      (ref, r) =>
          ref.watch(mealPlanRepositoryProvider).watchRange(r.from, r.to),
    );

/// Batches with portions remaining.
final activePrepBatchesProvider = StreamProvider<List<PrepBatch>>(
  (ref) => ref.watch(prepBatchRepositoryProvider).watchActive(),
);

/// Batches of one recipe.
// ignore: specify_nonobvious_property_types
final prepBatchesForRecipeProvider =
    StreamProvider.family<List<PrepBatch>, String>(
      (ref, recipeId) =>
          ref.watch(prepBatchRepositoryProvider).watchForRecipe(recipeId),
    );

final planItemProvider = Provider<PlanItem>(
  (ref) => PlanItem(
    plan: ref.watch(mealPlanRepositoryProvider),
    recipes: ref.watch(recipeRepositoryProvider),
    foods: ref.watch(foodRepositoryProvider),
    savedMeals: ref.watch(savedMealRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final removePlannedItemProvider = Provider<RemovePlannedItem>(
  (ref) => RemovePlannedItem(plan: ref.watch(mealPlanRepositoryProvider)),
);

final summarisePlanDayProvider = Provider<SummarisePlanDay>(
  (ref) => SummarisePlanDay(
    plan: ref.watch(mealPlanRepositoryProvider),
    recipes: ref.watch(recipeRepositoryProvider),
    foods: ref.watch(foodRepositoryProvider),
    savedMeals: ref.watch(savedMealRepositoryProvider),
  ),
);

final markPlannedEatenProvider = Provider<MarkPlannedEaten>(
  (ref) => MarkPlannedEaten(
    plan: ref.watch(mealPlanRepositoryProvider),
    recipes: ref.watch(recipeRepositoryProvider),
    foods: ref.watch(foodRepositoryProvider),
    savedMeals: ref.watch(savedMealRepositoryProvider),
    log: ref.watch(foodLogRepositoryProvider),
    logFood: ref.watch(logFoodProvider),
    logRecipe: ref.watch(logRecipeProvider),
    logSavedMeal: ref.watch(logSavedMealProvider),
  ),
);

final recordPrepBatchProvider = Provider<RecordPrepBatch>(
  (ref) => RecordPrepBatch(
    batches: ref.watch(prepBatchRepositoryProvider),
    recipes: ref.watch(recipeRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final consumePrepPortionProvider = Provider<ConsumePrepPortion>(
  (ref) => ConsumePrepPortion(batches: ref.watch(prepBatchRepositoryProvider)),
);

final deletePrepBatchProvider = Provider<DeletePrepBatch>(
  (ref) => DeletePrepBatch(batches: ref.watch(prepBatchRepositoryProvider)),
);
