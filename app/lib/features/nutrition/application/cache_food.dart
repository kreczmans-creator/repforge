import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

/// Use case: make sure a food shown from an online lookup exists locally
/// (NUT-005), so a recipe ingredient or a plan item can reference it by id.
///
/// A food already stored under that id is returned as stored and never
/// overwritten or duplicated; otherwise it is saved first (the same caching
/// `LogFood` does when it logs an online food). Fails with a `StorageError`
/// when the local save fails.
final class CacheFood {
  const CacheFood({required this.foods});

  final FoodRepository foods;

  Future<Result<Food>> call(Food food) async {
    try {
      final stored = await foods.byId(food.id);
      if (stored != null) return Ok(stored);
      await foods.upsert(food);
      return Ok(await foods.byId(food.id) ?? food);
    } on Exception catch (e) {
      return Err(StorageError('Could not save the food.', cause: e));
    }
  }
}
