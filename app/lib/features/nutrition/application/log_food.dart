import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';

/// Use case: log a portion of a food to the diary (NUT-001..004, NUT-010).
///
/// The nutrient snapshot is computed here from the food's per-100 profile and
/// the portion, so later edits to the food never change history. Foods that
/// came from an online lookup are cached locally on first log so repeat
/// lookups work offline (NUT-005).
final class LogFood {
  const LogFood({
    required this.foods,
    required this.log,
    required this.clock,
    required this.newId,
  });

  final FoodRepository foods;
  final FoodLogRepository log;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<FoodLogEntry>> call({
    required Food food,
    required double amount,
    required MealSlot meal,
    required String day,
    DateTime? loggedAt,
  }) async {
    final quantity = Quantity.of(amount, food.profile.per100);
    if (quantity case Err(:final error)) return Err(error);
    final q = (quantity as Ok<Quantity>).value;
    if (q.amount == 0) {
      return const Err(
        ValidationError(
          'Enter an amount greater than zero.',
          field: 'quantity',
        ),
      );
    }
    final nutrients = food.profile.forQuantity(q);
    if (nutrients case Err(:final error)) return Err(error);
    final now = clock.now().toUtc();
    final entry = FoodLogEntry(
      id: newId(),
      day: day,
      meal: meal,
      name: food.brand == null || food.brand!.isEmpty
          ? food.name
          : '${food.name} (${food.brand})',
      foodId: food.id,
      quantity: q,
      nutrients: (nutrients as Ok<NutrientAmounts>).value,
      provenance: food.profile.provenance,
      loggedAt: (loggedAt ?? now).toUtc(),
      createdAt: now,
      updatedAt: now,
    );
    try {
      if (food.source == FoodSource.openFoodFacts &&
          await foods.byId(food.id) == null) {
        await foods.upsert(food);
      }
      await log.insert(entry);
    } on Exception catch (e) {
      return Err(StorageError('Could not log the food.', cause: e));
    }
    return Ok(entry);
  }
}

/// Use case: change the portion or meal of an existing entry. The snapshot
/// is rescaled from the entry's own per-quantity nutrients, so it works even
/// when the original food record no longer exists.
final class UpdateFoodLogEntry {
  const UpdateFoodLogEntry({required this.log, required this.clock});

  final FoodLogRepository log;
  final Clock clock;

  Future<Result<FoodLogEntry>> call(
    FoodLogEntry entry, {
    double? amount,
    MealSlot? meal,
  }) async {
    var next = entry;
    if (amount != null) {
      final q = Quantity.of(amount, entry.quantity.unit);
      if (q case Err(:final error)) return Err(error);
      final quantity = (q as Ok<Quantity>).value;
      if (quantity.amount == 0 || entry.quantity.amount == 0) {
        return const Err(
          ValidationError(
            'Enter an amount greater than zero.',
            field: 'quantity',
          ),
        );
      }
      final factor = quantity.amount / entry.quantity.amount;
      next = next.copyWith(
        quantity: quantity,
        nutrients: entry.nutrients.scaled(factor),
      );
    }
    if (meal != null) next = next.copyWith(meal: meal);
    next = next.copyWith(updatedAt: clock.now().toUtc());
    try {
      await log.update(next);
    } on Exception catch (e) {
      return Err(StorageError('Could not update the entry.', cause: e));
    }
    return Ok(next);
  }
}

/// Use case: delete a diary entry.
final class DeleteFoodLogEntry {
  const DeleteFoodLogEntry({required this.log});

  final FoodLogRepository log;

  Future<Result<void>> call(String id) async {
    try {
      await log.delete(id);
    } on Exception catch (e) {
      return Err(StorageError('Could not delete the entry.', cause: e));
    }
    return const Ok(null);
  }
}
