import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/scanning/barcode.dart';
import 'package:repforge/domain/scanning/barcode_scanner.dart';
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
  _FakeLookup({this.food, this.failure, this.foodFor});
  Food? food;
  Map<String, Food>? foodFor;
  LookupFailure? failure;
  final List<String> asked = [];

  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async =>
      const Ok([]);

  @override
  Future<Result<Food?>> byBarcode(String barcode) async {
    asked.add(barcode);
    if (failure != null) return Err(lookupError(failure!));
    if (foodFor != null) return Ok(foodFor![barcode]);
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

  group('UPC-E / EAN-8 ambiguity', () {
    // 02345659: valid EAN-8 and valid UPC-E (expansion 023456000059).
    const upcEKey = '0023456000059';
    const ean8Key = '0000002345659';

    test(
      'hardware format upcE finds a food stored under the expansion',
      () async {
        await foods.upsert(_food('upce', upcEKey));
        final online = _FakeLookup();
        final r = await useCase(online)('02345659', format: BarcodeFormat.upcE);
        final found = (r as Ok<BarcodeLookup>).value as BarcodeFound;
        expect(found.food.id, 'upce');
        expect(online.asked, isEmpty);
      },
    );

    test(
      'manual entry without a hint finds it via the alternative key',
      () async {
        await foods.upsert(_food('upce', upcEKey));
        final online = _FakeLookup();
        final r = await useCase(online)('02345659');
        expect(
          ((r as Ok<BarcodeLookup>).value as BarcodeFound).food.id,
          'upce',
        );
        expect(online.asked, isEmpty);
      },
    );

    test('a scanned code passes its format through', () async {
      await foods.upsert(_food('upce', upcEKey));
      final r = await useCase(_FakeLookup())
          .scanned(const ScannedCode('02345659', format: BarcodeFormat.upcE));
      expect(((r as Ok<BarcodeLookup>).value as BarcodeFound).food.id, 'upce');
    });

    test('the EAN-8 reading wins when both are stored and no hint', () async {
      await foods.upsert(_food('e8', ean8Key));
      await foods.upsert(_food('upce', upcEKey));
      final r = await useCase(_FakeLookup())('02345659');
      expect(((r as Ok<BarcodeLookup>).value as BarcodeFound).food.id, 'e8');
    });

    test(
      'online tries every candidate key in order, raw digits second',
      () async {
        final online = _FakeLookup();
        final r = await useCase(online)('02345659');
        expect((r as Ok<BarcodeLookup>).value, isA<BarcodeNotFound>());
        expect(online.asked, [ean8Key, '02345659', upcEKey]);
      },
    );

    test('hint upcE asks online only for the expansion key', () async {
      final online = _FakeLookup();
      await useCase(online)('02345659', format: BarcodeFormat.upcE);
      expect(online.asked, [upcEKey]);
    });

    test('an EAN-8 falls back to the raw 8 digits online and caches', () async {
      final online = _FakeLookup(
        foodFor: {'96385074': _food('off:8', '96385074')},
      );
      final r = await useCase(online)('96385074');
      final found = (r as Ok<BarcodeLookup>).value as BarcodeFound;
      expect(found.source, BarcodeLookupSource.online);
      expect(online.asked, ['0000096385074', '96385074']);
      expect(await foods.byBarcode('96385074'), isNotNull);
      final again = await useCase(_FakeLookup())('96385074');
      expect(
        ((again as Ok<BarcodeLookup>).value as BarcodeFound).source,
        BarcodeLookupSource.local,
      );
    });

    test('an online hit on the alternative key is cached', () async {
      final online = _FakeLookup(foodFor: {upcEKey: _food('off:u', upcEKey)});
      final r = await useCase(online)('02345659');
      expect(((r as Ok<BarcodeLookup>).value as BarcodeFound).food.id, 'off:u');
      expect(await foods.byBarcode(upcEKey), isNotNull);
    });
  });
}
