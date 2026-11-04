import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/cache_food.dart';
import 'package:repforge/features/nutrition/application/create_custom_food.dart';

final _now = DateTime.utc(2026, 11, 4, 9);

Food _online({String name = 'Online oats'}) => Food(
  id: 'off-1',
  name: name,
  barcode: '123',
  source: FoodSource.openFoodFacts,
  profile: const NutrientProfile(
    per100: ReferenceUnit.grams,
    per100Amounts: NutrientAmounts(kcal: 380),
    provenance: DataProvenance.crowdsourced,
  ),
  createdAt: _now,
  updatedAt: _now,
);

final class _FailingFoods implements FoodRepository {
  @override
  Future<Food?> byId(String id) async => null;
  @override
  Future<void> upsert(Food food) => throw Exception('disk full');
  @override
  Stream<List<Food>> watchAll() => const Stream.empty();
  @override
  Future<Food?> byBarcode(String barcode) async => null;
  @override
  Future<List<Food>> search(String query, {int limit = 50}) async => [];
  @override
  Future<void> delete(String id) async {}
}

void main() {
  late AppDatabase db;
  late DriftFoodRepository foods;
  final clock = FixedClock(_now);

  setUp(() {
    db = AppDatabase.inMemory();
    foods = DriftFoodRepository(db, clock: clock);
  });
  tearDown(() => db.close());

  group('CacheFood', () {
    test('stores a food that is not local and returns it', () async {
      final r = await CacheFood(foods: foods)(_online());
      expect((r as Ok<Food>).value.id, 'off-1');
      expect((await foods.byId('off-1'))!.name, 'Online oats');
    });

    test('never duplicates: a second call returns the stored food', () async {
      final cache = CacheFood(foods: foods);
      await cache(_online());
      final again = await cache(_online(name: 'Renamed online'));
      // The stored record is kept as is, not overwritten.
      expect((again as Ok<Food>).value.name, 'Online oats');
      expect(await foods.watchAll().first, hasLength(1));
    });

    test('a failing save is a typed StorageError', () async {
      final r = await CacheFood(foods: _FailingFoods())(_online());
      expect((r as Err<Food>).error, isA<StorageError>());
    });
  });

  group('CreateCustomFood unit', () {
    test('portions is not a food reference unit', () async {
      final create = CreateCustomFood(
        foods: foods,
        clock: clock,
        newId: () => 'x',
      );
      final r = await create(
        name: 'Thing',
        per100: ReferenceUnit.portions,
        kcal: '100',
        proteinG: '',
        carbsG: '',
        fatG: '',
      );
      final error = (r as Err<Food>).error as ValidationError;
      expect(error.field, 'unit');
      expect(await foods.watchAll().first, isEmpty);
    });
  });
}
