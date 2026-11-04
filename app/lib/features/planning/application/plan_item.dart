import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal_repository.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/recipes/recipe_repository.dart';
import 'package:repforge/domain/units/units.dart';

final _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Parses `YYYY-MM-DD` strictly (rejects 2026-02-30); null when invalid.
DateTime? parsePlanDay(String day) {
  if (!_dayPattern.hasMatch(day)) return null;
  final p = day.split('-').map(int.parse).toList();
  final d = DateTime.utc(p[0], p[1], p[2]);
  return d.year == p[0] && d.month == p[1] && d.day == p[2] ? d : null;
}

/// True when [day] is from today to today + 27 (28 days, RCP-014(1)).
bool isInPlanWindow(String day, DateTime now) {
  final d = parsePlanDay(day);
  if (d == null) return false;
  final today = DateTime.utc(now.year, now.month, now.day);
  final offset = d.difference(today).inDays;
  return offset >= 0 && offset < planWindowDays;
}

/// Use case: add an item to the meal plan, or (with `id`) change the day,
/// meal or quantity of a planned item (RCP-014(1)).
///
/// The referenced recipe, food or saved meal must exist; its name and the
/// quantity unit are taken from it (portions for a recipe, the food's
/// reference unit g/ml, a multiplier for a saved meal). An item that has been
/// marked as eaten cannot be changed.
final class PlanItem {
  const PlanItem({
    required this.plan,
    required this.recipes,
    required this.foods,
    required this.savedMeals,
    required this.clock,
    required this.newId,
  });

  final MealPlanRepository plan;
  final RecipeRepository recipes;
  final FoodRepository foods;
  final SavedMealRepository savedMeals;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<MealPlanItem>> call({
    required String day,
    required MealSlot meal,
    required PlannedKind kind,
    required String refId,
    required double quantity,
    String? id,
  }) async {
    final now = clock.now();
    if (!isInPlanWindow(day, now)) {
      return const Err(
        ValidationError(
          'Plan a day from today to $planWindowDays days ahead.',
          field: PlanErrorField.day,
        ),
      );
    }
    try {
      final String name;
      final ReferenceUnit unit;
      switch (kind) {
        case PlannedKind.recipe:
          final r = await recipes.byId(refId);
          if (r == null) return Err(_missing('recipe'));
          name = r.name;
          unit = ReferenceUnit.portions;
        case PlannedKind.food:
          final f = await foods.byId(refId);
          if (f == null) return Err(_missing('food'));
          name = f.brand == null || f.brand!.isEmpty
              ? f.name
              : '${f.name} (${f.brand})';
          unit = f.profile.per100;
        case PlannedKind.savedMeal:
          final m = await savedMeals.byId(refId);
          if (m == null) return Err(_missing('saved meal'));
          name = m.name;
          unit = ReferenceUnit.portions;
      }
      final q = Quantity.of(quantity, unit);
      if (q case Err(:final error)) return Err(error);
      final rounded = (q as Ok<Quantity>).value.amount;
      if (rounded == 0) {
        return const Err(
          ValidationError(
            'Enter an amount greater than zero.',
            field: PlanErrorField.quantity,
          ),
        );
      }
      final stamp = now.toUtc();
      MealPlanItem item;
      if (id == null) {
        final sameSlot = await plan.watchDay(day).first;
        item = MealPlanItem(
          id: newId(),
          day: day,
          meal: meal,
          kind: kind,
          refId: refId,
          name: name,
          quantity: rounded,
          unit: unit,
          sortOrder: sameSlot.length,
          createdAt: stamp,
          updatedAt: stamp,
        );
      } else {
        final existing = await plan.byId(id);
        if (existing == null) {
          return const Err(
            NotFoundError('That planned item no longer exists.'),
          );
        }
        if (existing.isEaten) return const Err(_alreadyEaten);
        item = MealPlanItem(
          id: existing.id,
          day: day,
          meal: meal,
          kind: kind,
          refId: refId,
          name: name,
          quantity: rounded,
          unit: unit,
          sortOrder: existing.sortOrder,
          createdAt: existing.createdAt,
          updatedAt: stamp,
        );
      }
      await plan.upsert(item);
      return Ok(item);
    } on Exception catch (e) {
      return Err(StorageError('Could not plan the item.', cause: e));
    }
  }
}

const _alreadyEaten = ValidationError(
  'This planned item is already marked as eaten.',
  field: PlanErrorField.alreadyEaten,
);

NotFoundError _missing(String what) =>
    NotFoundError('That $what no longer exists.');

/// Use case: remove an item from the plan (soft delete).
final class RemovePlannedItem {
  const RemovePlannedItem({required this.plan});

  final MealPlanRepository plan;

  Future<Result<void>> call(String id) async {
    try {
      await plan.delete(id);
    } on Exception catch (e) {
      return Err(StorageError('Could not remove the item.', cause: e));
    }
    return const Ok(null);
  }
}
