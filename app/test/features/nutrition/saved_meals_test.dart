import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_saved_meal_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/saved_meals.dart';

final _now = DateTime.utc(2026, 11, 3, 12);

FoodLogEntry _entry(String id, double kcal) => FoodLogEntry(
  id: id,
  day: '2026-11-03',
  meal: MealSlot.lunch,
  name: 'Item $id',
  quantity: Quantity.fromStored(100, ReferenceUnit.grams),
  nutrients: NutrientAmounts(kcal: kcal, proteinG: 10, carbsG: 5, fatG: 2),
  provenance: DataProvenance.userEntered,
  loggedAt: _now,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late AppDatabase db;
  late DriftSavedMealRepository meals;
  late DriftFoodLogRepository log;
  var ids = 0;
  final clock = FixedClock(_now);

  setUp(() {
    db = AppDatabase.inMemory();
    meals = DriftSavedMealRepository(db, clock: clock);
    log = DriftFoodLogRepository(db, clock: clock);
    ids = 0;
  });
  tearDown(() => db.close());

  test('save then log copies the snapshots to a new day and slot', () async {
    final save = SaveMealFromEntries(
      savedMeals: meals,
      clock: clock,
      newId: () => 's${++ids}',
    );
    final saved = await save(
      name: 'Lunch box',
      entries: [_entry('a', 300), _entry('b', 200)],
      defaultMeal: MealSlot.lunch,
    );
    final meal = (saved as Ok<SavedMeal>).value;
    expect(meal.items.length, 2);
    expect(meal.totals.kcal, 500);

    final logIt = LogSavedMeal(
      log: log,
      clock: clock,
      newId: () => 'e${++ids}',
    );
    final r = await logIt(meal: meal, slot: MealSlot.dinner, day: '2026-11-05');
    final entries = (r as Ok<List<FoodLogEntry>>).value;
    expect(entries.length, 2);
    final stored = await log.watchDay('2026-11-05').first;
    expect(stored.map((e) => e.meal).toSet(), {MealSlot.dinner});
    expect(stored.map((e) => e.nutrients.kcal).reduce((a, b) => a + b), 500);
  });

  test('rejects an empty name or no entries', () async {
    final save = SaveMealFromEntries(
      savedMeals: meals,
      clock: clock,
      newId: () => 's${++ids}',
    );
    expect(
      await save(name: ' ', entries: [_entry('a', 1)]),
      isA<Err<SavedMeal>>(),
    );
    expect(await save(name: 'X', entries: const []), isA<Err<SavedMeal>>());
  });
}
