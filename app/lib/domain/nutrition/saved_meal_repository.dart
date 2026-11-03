import 'package:repforge/domain/nutrition/saved_meal.dart';

abstract interface class SavedMealRepository {
  /// Live meals, ordered by name.
  Stream<List<SavedMeal>> watchAll();
  Future<SavedMeal?> byId(String id);

  /// Inserts or replaces the meal and all of its items.
  Future<void> upsert(SavedMeal meal);

  /// Soft delete; idempotent.
  Future<void> delete(String id);
}
