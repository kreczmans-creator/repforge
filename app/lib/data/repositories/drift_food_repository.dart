import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/nutrition_mappers.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

/// drift-backed [FoodRepository] over `foods` and `food_servings`.
final class DriftFoodRepository implements FoodRepository {
  DriftFoodRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  Future<List<Food>> _hydrate(List<FoodRow> rows) async {
    if (rows.isEmpty) return const [];
    final servings = await (_db.select(
      _db.foodServings,
    )..where((s) => s.foodId.isIn(rows.map((r) => r.id)))).get();
    final byFood = <String, List<FoodServingRow>>{};
    for (final s in servings) {
      byFood.putIfAbsent(s.foodId, () => []).add(s);
    }
    return [
      for (final row in rows) ?foodFromRow(row, byFood[row.id] ?? const []),
    ];
  }

  @override
  Stream<List<Food>> watchAll() {
    final query = _db.select(_db.foods)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    // Join-free: re-hydrate whenever foods or servings change.
    return _db
        .customSelect('SELECT 1', readsFrom: {_db.foods, _db.foodServings})
        .watch()
        .asyncMap((_) async {
          final rows = await query.get();
          return await _hydrate(rows);
        });
  }

  @override
  Future<Food?> byId(String id) async {
    final rows = await (_db.select(
      _db.foods,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).get();
    return (await _hydrate(rows)).firstOrNull;
  }

  @override
  Future<Food?> byBarcode(String barcode) async {
    final rows =
        await (_db.select(_db.foods)
              ..where((t) => t.barcode.equals(barcode) & t.deletedAt.isNull())
              ..limit(1))
            .get();
    return (await _hydrate(rows)).firstOrNull;
  }

  @override
  Future<List<Food>> search(String query, {int limit = 50}) async {
    final q = normaliseSearchKey(query.trim());
    final escaped = q
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows =
        await (_db.select(_db.foods)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.searchKey.like('%$escaped%', escapeChar: r'\'),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.name)])
              ..limit(limit))
            .get();
    return await _hydrate(rows);
  }

  @override
  Future<void> upsert(Food food) => _db.transaction(() async {
    await _db.into(_db.foods).insertOnConflictUpdate(foodToRow(food));
    await (_db.delete(
      _db.foodServings,
    )..where((s) => s.foodId.equals(food.id))).go();
    await _db.batch((b) => b.insertAll(_db.foodServings, servingRows(food)));
  });

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    await (_db.update(_db.foods)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .write(FoodsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }
}
