import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_saved_meal_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/units/units.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));
final _t = DateTime.utc(2026, 11, 1, 8);

SavedMealItem _full(String id, int order) => SavedMealItem(
  id: id,
  name: 'Oats $id',
  foodId: 'food-$id',
  quantity: Quantity.fromStored(80, ReferenceUnit.grams),
  nutrients: const NutrientAmounts(
    kcal: 300,
    proteinG: 10,
    carbsG: 50,
    fatG: 6,
    fibreG: 8,
  ),
  provenance: DataProvenance.crowdsourced,
  sortOrder: order,
);

SavedMealItem _minimal(String id, int order) => SavedMealItem(
  id: id,
  name: 'Milk $id',
  quantity: Quantity.fromStored(250, ReferenceUnit.millilitres),
  nutrients: const NutrientAmounts(kcal: 120, proteinG: 8, carbsG: 12, fatG: 4),
  provenance: DataProvenance.userEntered,
  sortOrder: order,
  recipeId: 'rcp-$id',
);

SavedMeal _meal(
  String id,
  String name, {
  List<SavedMealItem>? items,
  MealSlot? slot = MealSlot.breakfast,
}) => SavedMeal(
  id: id,
  name: name,
  defaultMeal: slot,
  items: items ?? [_full('$id-1', 0), _minimal('$id-2', 1)],
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  late AppDatabase db;
  late DriftSavedMealRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftSavedMealRepository(db, clock: _clock);
  });
  tearDown(() => db.close());

  test('upsert and byId round-trip with two items', () async {
    final m = _meal('m1', 'Breakfast');
    await repo.upsert(m);
    final read = await repo.byId('m1');
    expect(read, m);
    expect(read!.items.first.recipeId, isNull);
    expect(read.items.last.foodId, isNull);
    expect(read.items.last.nutrients.fibreG, isNull);
  });

  test('null defaultMeal round-trips and items keep sortOrder', () async {
    final m = _meal(
      'm1',
      'Any',
      slot: null,
      items: [_full('b', 1), _minimal('a', 0)],
    );
    await repo.upsert(m);
    final read = (await repo.byId('m1'))!;
    expect(read.defaultMeal, isNull);
    expect(read.items.map((i) => i.id), ['a', 'b']);
  });

  test('totals sums item nutrients', () {
    final t = _meal('m1', 'A').totals;
    expect(t.kcal, 420);
    expect(t.proteinG, 18);
    expect(t.carbsG, 62);
    expect(t.fatG, 10);
    expect(t.fibreG, 8);
    expect(_meal('m2', 'B', items: const []).totals, NutrientAmounts.zero);
  });

  test(
    'watchAll emits on insert and on child change, ordered by name',
    () async {
      final emissions = <List<int>>[];
      final names = <List<String>>[];
      final sub = repo.watchAll().listen((l) {
        emissions.add([for (final m in l) m.items.length]);
        names.add([for (final m in l) m.name]);
      });
      await pumpEventQueue();
      await repo.upsert(_meal('b', 'Beta'));
      await pumpEventQueue();
      await repo.upsert(_meal('a', 'Alpha'));
      await pumpEventQueue();
      expect(names.last, ['Alpha', 'Beta']);
      await db
          .into(db.savedMealItems)
          .insert(
            SavedMealItemsCompanion.insert(
              id: 'extra',
              savedMealId: 'a',
              name: 'Extra',
              amount: 10,
              unit: 'grams',
              sortOrder: 5,
              kcal: 1,
              proteinG: 0,
              carbsG: 0,
              fatG: 0,
              provenance: 'verified',
            ),
          );
      await pumpEventQueue();
      await sub.cancel();
      expect(emissions.first, isEmpty);
      expect(emissions.last, [3, 2]);
    },
  );

  test('upsert replaces items', () async {
    await repo.upsert(_meal('m1', 'Breakfast'));
    final updated = _meal('m1', 'Breakfast v2', items: [_minimal('x', 0)]);
    await repo.upsert(updated);
    expect(await repo.byId('m1'), updated);
    expect(await db.select(db.savedMealItems).get(), hasLength(1));
    expect(await db.select(db.savedMeals).get(), hasLength(1));
  });

  test('delete soft-deletes, hides and is idempotent', () async {
    await repo.upsert(_meal('m1', 'A'));
    await repo.delete('m1');
    expect(await repo.byId('m1'), isNull);
    expect(await repo.watchAll().first, isEmpty);
    final first = (await db.select(db.savedMeals).get()).single;
    expect(first.deletedAt, _clock.now());
    await repo.delete('m1');
    final second = (await db.select(db.savedMeals).get()).single;
    expect(second.updatedAt, first.updatedAt);
    expect(second.deletedAt, first.deletedAt);
  });

  test('skips bad item rows but keeps the meal', () async {
    await repo.upsert(_meal('m1', 'A', items: [_full('ok', 0)]));
    SavedMealItemsCompanion bad(String id, String unit, String prov) =>
        SavedMealItemsCompanion.insert(
          id: id,
          savedMealId: 'm1',
          name: 'Bad',
          amount: 1,
          unit: unit,
          sortOrder: 9,
          kcal: 1,
          proteinG: 0,
          carbsG: 0,
          fatG: 0,
          provenance: prov,
          fibreG: const Value(null),
        );
    await db.into(db.savedMealItems).insert(bad('bad-unit', 'oz', 'verified'));
    await db
        .into(db.savedMealItems)
        .insert(bad('bad-prov', 'grams', 'guessed'));
    final read = (await repo.byId('m1'))!;
    expect(read.items.map((i) => i.id), ['ok']);
    expect((await repo.watchAll().first).single.items, hasLength(1));
  });
}
