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
}
