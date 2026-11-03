import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/nutrition_mappers.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));
final _t = DateTime.utc(2026, 11, 1, 8);

Food _food(
  String id,
  String name, {
  String? brand,
  String? barcode,
  double? fibre,
  List<ServingSize> servings = const [],
  ReferenceUnit unit = ReferenceUnit.grams,
}) => Food(
  id: id,
  name: name,
  brand: brand,
  barcode: barcode,
  profile: NutrientProfile(
    per100: unit,
    per100Amounts: NutrientAmounts(
      kcal: 165,
      proteinG: 31,
      carbsG: 0,
      fatG: 3.6,
      fibreG: fibre,
    ),
    provenance: DataProvenance.verified,
  ),
  source: FoodSource.openFoodFacts,
  createdAt: _t,
  updatedAt: _t,
  servings: servings,
);

void main() {
  late AppDatabase db;
  late DriftFoodRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftFoodRepository(db, clock: _clock);
  });
  tearDown(() => db.close());

  test('normaliseSearchKey lower-cases and strips diacritics', () {
    expect(
      normaliseSearchKey('Crème Fraîche ÀÉÎÕÜ Ñandú'),
      'creme fraiche aeiou nandu',
    );
  });

  test('upsert and byId round-trip the full entity with servings', () async {
    final food = _food(
      'f1',
      'Chicken breast',
      brand: 'Farm',
      barcode: '123',
      fibre: 0.5,
      servings: [
        ServingSize(
          label: '1 fillet',
          quantity: Quantity.fromStored(120, ReferenceUnit.grams),
        ),
        ServingSize(
          label: '1 slice',
          quantity: Quantity.fromStored(35.5, ReferenceUnit.grams),
        ),
      ],
    );
    await repo.upsert(food);
    expect(await repo.byId('f1'), food);
  });

  test('round-trips nullable fields and millilitre foods', () async {
    final food = _food('f2', 'Milk', unit: ReferenceUnit.millilitres);
    await repo.upsert(food);
    final read = await repo.byId('f2');
    expect(read, food);
    expect(read!.brand, isNull);
    expect(read.profile.per100Amounts.fibreG, isNull);
  });

  test('upsert again replaces servings', () async {
    final s = ServingSize(
      label: 'cup',
      quantity: Quantity.fromStored(240, ReferenceUnit.grams),
    );
    await repo.upsert(_food('f1', 'Oats', servings: [s, s]));
    await repo.upsert(_food('f1', 'Oats', servings: [s]));
    expect((await repo.byId('f1'))!.servings, [s]);
    expect(await db.select(db.foodServings).get(), hasLength(1));
  });

  test('search is case and diacritic insensitive, partial', () async {
    await repo.upsert(_food('a', 'Crème fraîche'));
    await repo.upsert(_food('b', 'Chicken breast'));
    await repo.upsert(_food('c', 'Rice', brand: 'Uncle Bén'));
    expect((await repo.search('creme')).map((f) => f.id), ['a']);
    expect((await repo.search('CHICK')).map((f) => f.id), ['b']);
    expect((await repo.search('uncle ben')).map((f) => f.id), ['c']);
    expect((await repo.search('c')).map((f) => f.name), [
      'Chicken breast',
      'Crème fraîche',
      'Rice',
    ]);
    expect(await repo.search('zzz'), isEmpty);
  });

  test('search escapes wildcards and honours limit', () async {
    await repo.upsert(_food('a', '100% juice'));
    await repo.upsert(_food('b', 'plain'));
    await repo.upsert(_food('c', 'plum'));
    expect((await repo.search('%')).map((f) => f.id), ['a']);
    expect(await repo.search('_'), isEmpty);
    expect(await repo.search('pl', limit: 1), hasLength(1));
  });

  test('byBarcode finds a food', () async {
    await repo.upsert(_food('a', 'Bar', barcode: '5000'));
    expect((await repo.byBarcode('5000'))?.id, 'a');
    expect(await repo.byBarcode('nope'), isNull);
  });

  test('delete soft-deletes, hides and is idempotent', () async {
    await repo.upsert(_food('a', 'Bar', barcode: '5000'));
    await repo.delete('a');
    expect(await repo.byId('a'), isNull);
    expect(await repo.byBarcode('5000'), isNull);
    expect(await repo.search('bar'), isEmpty);
    expect(await repo.watchAll().first, isEmpty);
    final first = (await db.select(db.foods).get()).single;
    expect(first.deletedAt, _clock.now());
    await repo.delete('a');
    final second = (await db.select(db.foods).get()).single;
    expect(second.updatedAt, first.updatedAt);
  });

  test('watchAll emits on insert', () async {
    final emissions = <List<String>>[];
    final sub = repo.watchAll().listen(
      (l) => emissions.add([for (final f in l) f.id]),
    );
    await pumpEventQueue();
    await repo.upsert(_food('b', 'Banana'));
    await pumpEventQueue();
    await repo.upsert(_food('a', 'Apple'));
    await pumpEventQueue();
    await sub.cancel();
    expect(emissions.first, isEmpty);
    expect(emissions.last, ['a', 'b']);
  });

  test('skips a row that fails validation', () async {
    await repo.upsert(_food('ok', 'Good'));
    await db
        .into(db.foods)
        .insert(
          FoodsCompanion.insert(
            id: 'bad',
            name: 'Bad',
            per100Unit: 'grams',
            kcal: 5000,
            proteinG: 1,
            carbsG: 1,
            fatG: 1,
            provenance: 'verified',
            source: 'seed',
            searchKey: 'bad',
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    expect((await repo.watchAll().first).map((f) => f.id), ['ok']);
    expect(await repo.byId('bad'), isNull);
  });
}
