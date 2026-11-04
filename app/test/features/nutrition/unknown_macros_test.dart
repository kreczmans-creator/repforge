import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/external/open_food_facts_mapper.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/create_custom_food.dart';
import 'package:repforge/features/nutrition/application/log_food.dart';

final _now = DateTime.utc(2026, 11, 3, 12);
const _day = '2026-11-03';

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

  Food energyOnly() => mapOffProduct({
    'code': '1',
    'product_name': 'A',
    'nutriments': {'energy-kcal_100g': 10},
  }, now: _now)!;

  Food chicken() => Food(
    id: 'f1',
    name: 'Chicken',
    profile: const NutrientProfile(
      per100: ReferenceUnit.grams,
      per100Amounts: NutrientAmounts(
        kcal: 165,
        proteinG: 31,
        carbsG: 0,
        fatG: 3.6,
      ),
      provenance: DataProvenance.userEntered,
    ),
    source: FoodSource.userCreated,
    createdAt: _now,
    updatedAt: _now,
  );

  DailySummary summary(List<FoodLogEntry> entries) => DailySummary.fromEntries(
    day: _day,
    entries: entries,
    targets: DailyTargets.none,
  );

  group('logging a food with unknown macros', () {
    test('keeps the day protein total unchanged and counts one unknown entry '
        'while the unknown macros persist as null', () async {
      await logFood()(
        food: chicken(),
        amount: 100,
        meal: MealSlot.lunch,
        day: _day,
      );
      final before = summary(await log.forDays(_day, _day));

      final r = await logFood()(
        food: energyOnly(),
        amount: 200,
        meal: MealSlot.snack,
        day: _day,
      );
      final entry = (r as Ok<FoodLogEntry>).value;
      expect(entry.nutrients.kcal, 20);
      expect(entry.nutrients.proteinG, isNull);

      final stored = await log.forDays(_day, _day);
      final after = summary(stored);
      expect(after.totals.known.proteinG, before.totals.known.proteinG);
      expect(after.totals.known.proteinG, 31);
      expect(before.totals.unknownProteinCount, 0);
      expect(after.totals.unknownProteinCount, 1);
      expect(after.totals.unknownCarbsCount, 1);
      expect(after.totals.unknownFatCount, 1);
      expect(
        stored.firstWhere((e) => e.id == entry.id).nutrients.proteinG,
        isNull,
      );
    });

    test('a day with only unknown protein has a null protein total', () async {
      await logFood()(
        food: energyOnly(),
        amount: 100,
        meal: MealSlot.snack,
        day: _day,
      );
      final s = summary(await log.forDays(_day, _day));
      expect(s.totals.known.proteinG, isNull);
      expect(s.totals.unknownProteinCount, 1);
    });
  });

  group('UpdateFoodLogEntry', () {
    test('rescaling an entry preserves null macros', () async {
      final logged = (await logFood()(
        food: energyOnly(),
        amount: 100,
        meal: MealSlot.snack,
        day: _day,
      ) as Ok<FoodLogEntry>).value;
      final update = UpdateFoodLogEntry(log: log, clock: clock);
      final r = await update(logged, amount: 250);
      final updated = (r as Ok<FoodLogEntry>).value;
      expect(updated.nutrients.kcal, closeTo(25, 1e-9));
      expect(updated.nutrients.proteinG, isNull);
      final stored = (await log.forDays(_day, _day)).single;
      expect(stored.nutrients.kcal, closeTo(25, 1e-9));
      expect(stored.nutrients.proteinG, isNull);
      expect(stored.nutrients.carbsG, isNull);
      expect(stored.nutrients.fatG, isNull);
    });
  });

  group('CreateCustomFood unknown macros', () {
    CreateCustomFood create() =>
        CreateCustomFood(foods: foods, clock: clock, newId: () => 'c${++ids}');

    test('blank macros save as null and read back as null', () async {
      final r = await create()(
        name: 'Mystery bar',
        per100: ReferenceUnit.grams,
        kcal: '400',
        proteinG: '',
        carbsG: '  ',
        fatG: '',
      );
      final f = (r as Ok<Food>).value;
      expect(f.profile.per100Amounts.kcal, 400);
      expect(f.profile.per100Amounts.proteinG, isNull);
      expect(f.profile.per100Amounts.carbsG, isNull);
      expect(f.profile.per100Amounts.fatG, isNull);
      final stored = (await foods.byId(f.id))!;
      expect(stored.profile.per100Amounts.proteinG, isNull);
      expect(stored.profile.per100Amounts.fatG, isNull);
    });

    test('a typed zero stays zero', () async {
      final r = await create()(
        name: 'Oil',
        per100: ReferenceUnit.grams,
        kcal: '900',
        proteinG: '0',
        carbsG: '',
        fatG: '100',
      );
      final a = (r as Ok<Food>).value.profile.per100Amounts;
      expect(a.proteinG, 0);
      expect(a.carbsG, isNull);
      expect(a.fatG, 100);
    });

    test(
      'non-numeric macro text is a validation error for that field',
      () async {
        final r = await create()(
          name: 'X',
          per100: ReferenceUnit.grams,
          kcal: '100',
          proteinG: '',
          carbsG: 'abc',
          fatG: '',
        );
        expect(((r as Err<Food>).error as ValidationError).field, 'carbsG');
      },
    );

    test('energy is still required', () async {
      final r = await create()(
        name: 'X',
        per100: ReferenceUnit.grams,
        kcal: '',
        proteinG: '1',
        carbsG: '1',
        fatG: '1',
      );
      expect(((r as Err<Food>).error as ValidationError).field, 'kcal');
    });
  });
}
