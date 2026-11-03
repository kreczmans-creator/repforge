import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/create_custom_food.dart';
import 'package:repforge/features/nutrition/application/log_food.dart';

final _now = DateTime.utc(2026, 11, 3, 12);

Food _food({
  String id = 'f1',
  FoodSource source = FoodSource.userCreated,
  ReferenceUnit unit = ReferenceUnit.grams,
}) => Food(
  id: id,
  name: 'Chicken breast',
  brand: source == FoodSource.openFoodFacts ? 'Acme' : null,
  barcode: source == FoodSource.openFoodFacts ? '123' : null,
  profile: NutrientProfile(
    per100: unit,
    per100Amounts: const NutrientAmounts(
      kcal: 165,
      proteinG: 31,
      carbsG: 0,
      fatG: 3.6,
    ),
    provenance: source == FoodSource.openFoodFacts
        ? DataProvenance.crowdsourced
        : DataProvenance.userEntered,
  ),
  source: source,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late AppDatabase db;
  late DriftFoodRepository foods;
  late DriftFoodLogRepository log;
  var ids = 0;
  final clock = FixedClock(_now);

  setUp(() {
    db = AppDatabase.inMemory();
    foods = DriftFoodRepository(db, clock: clock);
    log = DriftFoodLogRepository(db, clock: clock);
    ids = 0;
  });
  tearDown(() => db.close());

  LogFood logFood() =>
      LogFood(foods: foods, log: log, clock: clock, newId: () => 'e${++ids}');

  group('LogFood', () {
    test('snapshots nutrients for the portion', () async {
      final r = await logFood()(
        food: _food(),
        amount: 150,
        meal: MealSlot.lunch,
        day: '2026-11-03',
      );
      final e = (r as Ok<FoodLogEntry>).value;
      expect(e.nutrients.proteinG, closeTo(46.5, 1e-9));
      expect(e.nutrients.kcal, closeTo(247.5, 1e-9));
      expect(e.quantity.label, '150 g');
      expect(e.provenance, DataProvenance.userEntered);
      expect((await log.watchDay('2026-11-03').first).single.id, 'e1');
    });

    test('caches an online food locally on first log only', () async {
      final f = _food(id: 'off:123', source: FoodSource.openFoodFacts);
      await logFood()(food: f, amount: 100, meal: MealSlot.snack, day: 'd');
      expect((await foods.byBarcode('123'))?.id, 'off:123');
      await logFood()(food: f, amount: 50, meal: MealSlot.snack, day: 'd');
      expect((await foods.search('chicken')).length, 1);
    });

    test('rejects zero and negative amounts', () async {
      final r0 = await logFood()(
        food: _food(),
        amount: 0,
        meal: MealSlot.lunch,
        day: 'd',
      );
      expect((r0 as Err<FoodLogEntry>).error, isA<ValidationError>());
      final rn = await logFood()(
        food: _food(),
        amount: -5,
        meal: MealSlot.lunch,
        day: 'd',
      );
      expect(rn, isA<Err<FoodLogEntry>>());
      expect(await log.watchDay('d').first, isEmpty);
    });

    test('name includes the brand when present', () async {
      final r = await logFood()(
        food: _food(id: 'off:1', source: FoodSource.openFoodFacts),
        amount: 100,
        meal: MealSlot.lunch,
        day: 'd',
      );
      expect((r as Ok<FoodLogEntry>).value.name, 'Chicken breast (Acme)');
    });
  });

  group('UpdateFoodLogEntry', () {
    test('rescales the snapshot and changes the meal', () async {
      final e = (await logFood()(
        food: _food(),
        amount: 100,
        meal: MealSlot.lunch,
        day: 'd',
      ) as Ok<FoodLogEntry>).value;
      final r = await UpdateFoodLogEntry(log: log, clock: clock)(
        e,
        amount: 200,
        meal: MealSlot.dinner,
      );
      final u = (r as Ok<FoodLogEntry>).value;
      expect(u.nutrients.proteinG, closeTo(62, 1e-9));
      expect(u.meal, MealSlot.dinner);
      final stored = (await log.watchDay('d').first).single;
      expect(stored.quantity.amount, 200);
      expect(stored.meal, MealSlot.dinner);
    });

    test('rejects a zero amount', () async {
      final e = (await logFood()(
        food: _food(),
        amount: 100,
        meal: MealSlot.lunch,
        day: 'd',
      ) as Ok<FoodLogEntry>).value;
      final r = await UpdateFoodLogEntry(log: log, clock: clock)(e, amount: 0);
      expect(r, isA<Err<FoodLogEntry>>());
    });
  });

  group('DeleteFoodLogEntry', () {
    test('removes the entry from the day', () async {
      final e = (await logFood()(
        food: _food(),
        amount: 100,
        meal: MealSlot.lunch,
        day: 'd',
      ) as Ok<FoodLogEntry>).value;
      await DeleteFoodLogEntry(log: log)(e.id);
      expect(await log.watchDay('d').first, isEmpty);
    });
  });

  group('CreateCustomFood', () {
    CreateCustomFood create() =>
        CreateCustomFood(foods: foods, clock: clock, newId: () => 'c${++ids}');

    test('creates a user food with servings', () async {
      final r = await create()(
        name: '  Greek yogurt ',
        per100: ReferenceUnit.grams,
        kcal: '59',
        proteinG: '10',
        carbsG: '3.6',
        fatG: '0.4',
        fibreG: '',
        brand: 'Fage',
        servings: const [(label: '1 pot', amount: '170')],
      );
      final f = (r as Ok<Food>).value;
      expect(f.name, 'Greek yogurt');
      expect(f.brand, 'Fage');
      expect(f.profile.provenance, DataProvenance.userEntered);
      expect(f.profile.per100Amounts.fibreG, isNull);
      expect(f.servings.single.quantity.amount, 170);
      expect((await foods.search('greek')).single.id, f.id);
    });

    test('reports the failing field', () async {
      final r = await create()(
        name: 'X',
        per100: ReferenceUnit.grams,
        kcal: '100',
        proteinG: '150',
        carbsG: '0',
        fatG: '0',
      );
      expect(((r as Err<Food>).error as ValidationError).field, 'proteinG');
      final r2 = await create()(
        name: '',
        per100: ReferenceUnit.grams,
        kcal: '1',
        proteinG: '1',
        carbsG: '1',
        fatG: '1',
      );
      expect(((r2 as Err<Food>).error as ValidationError).field, 'name');
      final r3 = await create()(
        name: 'Y',
        per100: ReferenceUnit.grams,
        kcal: '1',
        proteinG: '1',
        carbsG: '1',
        fatG: '1',
        servings: const [(label: 'slice', amount: '0')],
      );
      expect(((r3 as Err<Food>).error as ValidationError).field, 'servings');
    });
  });
}
