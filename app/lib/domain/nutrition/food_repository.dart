import 'package:repforge/domain/nutrition/nutrition.dart';

abstract interface class FoodRepository {
  Stream<List<Food>> watchAll();
  Future<Food?> byId(String id);
  Future<Food?> byBarcode(String barcode);

  /// Case- and diacritic-insensitive partial match on name and brand.
  Future<List<Food>> search(String query, {int limit = 50});
  Future<void> upsert(Food food);
  Future<void> delete(String id);
}

abstract interface class FoodLogRepository {
  Stream<List<FoodLogEntry>> watchDay(String day);
  Future<List<FoodLogEntry>> forDays(String fromDay, String toDay);
  Future<void> insert(FoodLogEntry entry);

  /// Inserts all entries atomically (all or none).
  Future<void> insertAll(List<FoodLogEntry> entries);
  Future<void> update(FoodLogEntry entry);
  Future<void> delete(String id);

  /// The foods and recipes most recently logged, newest first, one row per
  /// distinct source (NUT-014). Entries that carry neither a food id nor a
  /// recipe id are ignored. Reads live (not deleted) entries only; it does
  /// not check that the source still exists.
  Future<List<RecentLogSource>> recentSources({int limit = 50});
}

/// A food or a recipe that was logged, with when it was last logged.
final class RecentLogSource {
  const RecentLogSource({required this.loggedAt, this.foodId, this.recipeId})
    : assert(
        (foodId == null) != (recipeId == null),
        'exactly one of foodId and recipeId',
      );

  final String? foodId;
  final String? recipeId;
  final DateTime loggedAt;
}
