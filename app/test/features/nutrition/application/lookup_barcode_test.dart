import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/lookup_barcode.dart';

final _now = DateTime(2026, 11, 3, 9);

Food _food(String id, String barcode, {FoodSource? source}) => Food(
  id: id,
  name: 'Hazelnut spread',
  barcode: barcode,
  profile: const NutrientProfile(
    per100: ReferenceUnit.grams,
    per100Amounts: NutrientAmounts(kcal: 539, proteinG: 6.3),
    provenance: DataProvenance.crowdsourced,
  ),
  source: source ?? FoodSource.openFoodFacts,
  createdAt: _now,
  updatedAt: _now,
);

final class _FakeLookup implements FoodLookupService {
  _FakeLookup({this.food, this.failure});
  Food? food;
  LookupFailure? failure;
  final List<String> asked = [];

  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async =>
      const Ok([]);

  @override
  Future<Result<Food?>> byBarcode(String barcode) async {
    asked.add(barcode);
    if (failure != null) return Err(lookupError(failure!));
    return Ok(food);
  }
}

void main() {
  late AppDatabase db;
  late DriftFoodRepository foods;
  setUp(() {
    db = AppDatabase.inMemory();
    foods = DriftFoodRepository(db, clock: FixedClock(_now));
  });
  tearDown(() => db.close());

  LookupBarcode useCase(_FakeLookup l) =>
      LookupBarcode(foods: foods, lookup: l);

  test('local hit is returned without calling the online service', () async {
    await foods.upsert(_food('local-1', '3017624010701'));
    final online = _FakeLookup(food: _food('off:1', '3017624010701'));
    final r = await useCase(online)('3017624010701');
    final found = (r as Ok<BarcodeLookup>).value as BarcodeFound;
    expect(found.source, BarcodeLookupSource.local);
    expect(found.food.id, 'local-1');
    expect(online.asked, isEmpty);
  });

  test('online hit is cached and then found locally while offline', () async {
    final online = _FakeLookup(food: _food('off:1', '3017624010701'));
    final first = await useCase(online)('3017624010701');
    expect(
      ((first as Ok<BarcodeLookup>).value as BarcodeFound).source,
      BarcodeLookupSource.online,
    );
    expect(await foods.byBarcode('3017624010701'), isNotNull);

    final offline = _FakeLookup(failure: const LookupOffline());
    final second = await useCase(offline)('3017624010701');
    final found = (second as Ok<BarcodeLookup>).value as BarcodeFound;
    expect(found.source, BarcodeLookupSource.local);
    expect(offline.asked, isEmpty);
  });

  test('unknown barcode is not found and nothing is stored', () async {
    final r = await useCase(_FakeLookup())('3017624010701');
    final nf = (r as Ok<BarcodeLookup>).value as BarcodeNotFound;
    expect(nf.barcode.lookupKey, '3017624010701');
    expect(await foods.byBarcode('3017624010701'), isNull);
    expect(await foods.search('Hazelnut'), isEmpty);
  });

  test('offline failure passes through typed and writes nothing', () async {
    final r = await useCase(_FakeLookup(failure: const LookupOffline()))(
      '3017624010701',
    );
    final error = (r as Err<BarcodeLookup>).error;
    expect(lookupFailureOf(error), isA<LookupOffline>());
    expect(await foods.search('Hazelnut'), isEmpty);
  });

  test('rate limiting and unavailability stay distinguishable', () async {
    final limited = await useCase(
      _FakeLookup(failure: const LookupRateLimited()),
    )('3017624010701');
    expect(
      lookupFailureOf((limited as Err<BarcodeLookup>).error),
      isA<LookupRateLimited>(),
    );
    final down = await useCase(
      _FakeLookup(failure: const LookupUnavailable('500')),
    )('3017624010701');
    expect(
      lookupFailureOf((down as Err<BarcodeLookup>).error),
      isA<LookupUnavailable>(),
    );
  });

  test('invalid input is a validation error and does not look up', () async {
    final online = _FakeLookup();
    final r = await useCase(online)('3017624010702');
    expect((r as Err<BarcodeLookup>).error, isA<ValidationError>());
    expect(online.asked, isEmpty);
  });

  test('a 12-digit UPC-A is found under its 13-digit key', () async {
    await foods.upsert(_food('local-2', '0042100005264'));
    final online = _FakeLookup();
    final r = await useCase(online)('042100005264');
    final found = (r as Ok<BarcodeLookup>).value as BarcodeFound;
    expect(found.food.id, 'local-2');
    expect(online.asked, isEmpty);
  });

  test('online lookup uses the 13-digit key for a UPC-A', () async {
    final online = _FakeLookup();
    await useCase(online)('042100005264');
    expect(online.asked, ['0042100005264']);
  });

  test('a food stored under the raw digits is still found', () async {
    await foods.upsert(_food('legacy', '042100005264'));
    final r = await useCase(_FakeLookup())('042100005264');
    expect(((r as Ok<BarcodeLookup>).value as BarcodeFound).food.id, 'legacy');
  });
}
