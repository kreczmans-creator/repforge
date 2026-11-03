import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/nutrition/saved_meal_repository.dart';

/// Use case: save a set of diary entries as a named meal (NUT-013).
final class SaveMealFromEntries {
  const SaveMealFromEntries({
    required this.savedMeals,
    required this.clock,
    required this.newId,
  });

  final SavedMealRepository savedMeals;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<SavedMeal>> call({
    required String name,
    required List<FoodLogEntry> entries,
    MealSlot? defaultMeal,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(ValidationError('Enter a meal name.', field: 'name'));
    }
    if (entries.isEmpty) {
      return const Err(
        ValidationError('Log at least one item first.', field: 'entries'),
      );
    }
    final now = clock.now().toUtc();
    final meal = SavedMeal(
      id: newId(),
      name: trimmed,
      defaultMeal: defaultMeal,
      items: [
        for (var i = 0; i < entries.length; i++)
          SavedMealItem(
            id: newId(),
            name: entries[i].name,
            quantity: entries[i].quantity,
            nutrients: entries[i].nutrients,
            provenance: entries[i].provenance,
            sortOrder: i,
            foodId: entries[i].foodId,
            recipeId: entries[i].recipeId,
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    try {
      await savedMeals.upsert(meal);
    } on Exception catch (e) {
      return Err(StorageError('Could not save the meal.', cause: e));
    }
    return Ok(meal);
  }
}

/// Use case: delete a saved meal.
final class DeleteSavedMeal {
  const DeleteSavedMeal({required this.savedMeals});

  final SavedMealRepository savedMeals;

  Future<Result<void>> call(String id) async {
    try {
      await savedMeals.delete(id);
    } on Exception catch (e) {
      return Err(StorageError('Could not delete the meal.', cause: e));
    }
    return const Ok(null);
  }
}

/// Use case: log every item of a saved meal in one action. Snapshots are
/// copied as stored (the saved amounts), so editing a food later does not
/// change what gets logged.
final class LogSavedMeal {
  const LogSavedMeal({
    required this.log,
    required this.clock,
    required this.newId,
  });

  final FoodLogRepository log;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<List<FoodLogEntry>>> call({
    required SavedMeal meal,
    required MealSlot slot,
    required String day,
  }) async {
    if (meal.items.isEmpty) {
      return const Err(
        ValidationError('This saved meal has no items.', field: 'items'),
      );
    }
    final now = clock.now().toUtc();
    final entries = [
      for (final i in meal.items)
        FoodLogEntry(
          id: newId(),
          day: day,
          meal: slot,
          name: i.name,
          foodId: i.foodId,
          recipeId: i.recipeId,
          quantity: i.quantity,
          nutrients: i.nutrients,
          provenance: i.provenance,
          loggedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
    ];
    try {
      await log.insertAll(entries);
    } on Exception catch (e) {
      return Err(StorageError('Could not log the meal.', cause: e));
    }
    return Ok(entries);
  }
}
