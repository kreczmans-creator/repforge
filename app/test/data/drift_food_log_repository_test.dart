import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));

FoodLogEntry _entry(
  String id,
  String day,
  DateTime loggedAt, {
  MealSlot meal = MealSlot.lunch,
  double? fibre,
  String? foodId,
  String? recipeId,
}) => FoodLogEntry(
  id: id,
  day: day,
  meal: meal,
  name: 'Item $id',
  foodId: foodId,
  recipeId: recipeId,
  quantity: Quantity.fromStored(150, ReferenceUnit.grams),
  nutrients: NutrientAmounts(
    kcal: 200,
    proteinG: 30,
    carbsG: 10,
    fatG: 5,
    fibreG: fibre,
  ),
  provenance: DataProvenance.userEntered,
  loggedAt: loggedAt,
  createdAt: loggedAt,
  updatedAt: loggedAt,
);

void main() {
  _insertAllTests();
  late AppDatabase db;
  late DriftFoodLogRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftFoodLogRepository(db, clock: _clock);
  });
  tearDown(() => db.close());

  test('insert and read back full entity incl. nullable fields', () async {
    final t = DateTime.utc(2026, 11, 1, 8);
    final a = _entry('a', '2026-11-01', t, fibre: 2.5, foodId: 'f');
    final b = _entry(
      'b',
      '2026-11-01',
      t.add(const Duration(hours: 1)),
      meal: MealSlot.snack,
      recipeId: 'r',
    );
    await repo.insert(a);
    await repo.insert(b);
    final got = await repo.forDays('2026-11-01', '2026-11-01');
    expect(got, containsAll([a, b]));
    expect(got.firstWhere((e) => e.id == 'b').nutrients.fibreG, isNull);
  });

  test('watchDay orders by loggedAt descending and filters by day', () async {
    final t = DateTime.utc(2026, 11, 1, 8);
    await repo.insert(_entry('early', '2026-11-01', t));
    await repo.insert(
      _entry('late', '2026-11-01', t.add(const Duration(hours: 5))),
    );
    await repo.insert(_entry('other', '2026-11-02', t));
    final day = await repo.watchDay('2026-11-01').first;
    expect(day.map((e) => e.id), ['late', 'early']);
  });

  test('watchDay emits on insert', () async {
    final emissions = <int>[];
    final sub = repo
        .watchDay('2026-11-01')
        .listen((l) => emissions.add(l.length));
    await pumpEventQueue();
    await repo.insert(_entry('a', '2026-11-01', DateTime.utc(2026, 11, 1, 8)));
    await pumpEventQueue();
    await sub.cancel();
    expect(emissions, [0, 1]);
  });

  test('forDays is inclusive on both ends', () async {
    final t = DateTime.utc(2026, 11, 1, 8);
    for (final d in ['2026-10-31', '2026-11-01', '2026-11-02', '2026-11-03']) {
      await repo.insert(_entry(d, d, t));
    }
    final got = await repo.forDays('2026-11-01', '2026-11-02');
    expect(got.map((e) => e.day).toSet(), {'2026-11-01', '2026-11-02'});
  });

  test('update changes fields and stamps updatedAt', () async {
    final t = DateTime.utc(2026, 11, 1, 8);
    await repo.insert(_entry('a', '2026-11-01', t));
    await repo.update(_entry('a', '2026-11-01', t, meal: MealSlot.dinner));
    final got = (await repo.forDays('2026-11-01', '2026-11-01')).single;
    expect(got.meal, MealSlot.dinner);
    expect(got.updatedAt, _clock.now());
    expect(got.createdAt, t);
  });

  test('delete soft-deletes, hides and is idempotent', () async {
    final t = DateTime.utc(2026, 11, 1, 8);
    await repo.insert(_entry('a', '2026-11-01', t));
    await repo.delete('a');
    expect(await repo.watchDay('2026-11-01').first, isEmpty);
    expect(await repo.forDays('2026-11-01', '2026-11-01'), isEmpty);
    final first = (await db.select(db.foodLogEntries).get()).single;
    expect(first.deletedAt, _clock.now());
    await repo.delete('a');
    final second = (await db.select(db.foodLogEntries).get()).single;
    expect(second.updatedAt, first.updatedAt);
  });

  test('skips rows with an unknown meal', () async {
    final t = DateTime.utc(2026, 11, 1, 8);
    await repo.insert(_entry('ok', '2026-11-01', t));
    await db
        .into(db.foodLogEntries)
        .insert(
          FoodLogEntriesCompanion.insert(
            id: 'bad',
            day: '2026-11-01',
            meal: 'brunch',
            name: 'x',
            amount: 1,
            unit: 'grams',
            kcal: 1,
            proteinG: 1,
            carbsG: 1,
            fatG: 1,
            provenance: 'verified',
            loggedAt: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
    expect((await repo.watchDay('2026-11-01').first).map((e) => e.id), ['ok']);
  });
}

void _insertAllTests() {
  group('DriftFoodLogRepository.insertAll', () {
    late AppDatabase db;
    late DriftFoodLogRepository repo;
    setUp(() {
      db = AppDatabase.inMemory();
      repo = DriftFoodLogRepository(db, clock: _clock);
    });
    tearDown(() => db.close());

    FoodLogEntry e(String id) => FoodLogEntry(
      id: id,
      day: '2026-11-03',
      meal: MealSlot.lunch,
      name: id,
      quantity: Quantity.fromStored(100, ReferenceUnit.grams),
      nutrients: const NutrientAmounts(
        kcal: 1,
        proteinG: 1,
        carbsG: 1,
        fatG: 1,
      ),
      provenance: DataProvenance.userEntered,
      loggedAt: _clock.now(),
      createdAt: _clock.now(),
      updatedAt: _clock.now(),
    );

    test('inserts every entry', () async {
      await repo.insertAll([e('a'), e('b'), e('c')]);
      expect((await repo.watchDay('2026-11-03').first).length, 3);
    });

    test('is all-or-nothing when one row is invalid', () async {
      await repo.insert(e('a'));
      await expectLater(
        repo.insertAll([e('b'), e('a')]), // duplicate primary key
        throwsA(anything),
      );
      expect((await repo.watchDay('2026-11-03').first).map((x) => x.id), ['a']);
    });
  });
}
