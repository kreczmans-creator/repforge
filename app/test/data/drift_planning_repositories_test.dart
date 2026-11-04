import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_meal_plan_repository.dart';
import 'package:repforge/data/repositories/drift_prep_batch_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/domain/units/units.dart';

final _t = DateTime.utc(2026, 11, 1, 8);
final _later = DateTime.utc(2026, 11, 3, 12);

MealPlanItem _item(
  String id, {
  String day = '2026-11-05',
  int order = 0,
  PlannedKind kind = PlannedKind.recipe,
}) => MealPlanItem(
  id: id,
  day: day,
  meal: MealSlot.dinner,
  kind: kind,
  refId: 'ref-$id',
  name: 'Item $id',
  quantity: 1.5,
  unit: ReferenceUnit.portions,
  sortOrder: order,
  createdAt: _t,
  updatedAt: _t,
);

PrepBatch _batch(String id, double remaining, {String recipe = 'r1'}) =>
    PrepBatch(
      id: id,
      recipeId: recipe,
      preparedAt: _t,
      portionsMade: 6,
      portionsRemaining: remaining,
      createdAt: _t,
      updatedAt: _t,
    );

void main() {
  late AppDatabase db;
  late DriftMealPlanRepository plan;
  late DriftPrepBatchRepository batches;

  setUp(() {
    db = AppDatabase.inMemory();
    plan = DriftMealPlanRepository(db, clock: FixedClock(_later));
    batches = DriftPrepBatchRepository(db, clock: FixedClock(_later));
  });
  tearDown(() => db.close());

  group('DriftMealPlanRepository', () {
    test('round-trips an item, stamping updatedAt with the clock', () async {
      await plan.upsert(_item('a'));
      final got = (await plan.byId('a'))!;
      expect(got, _item('a').copyWith(updatedAt: _later));
      expect(got.createdAt, _t);
      expect(got.isEaten, isFalse);
    });

    test('upsert replaces; watchDay orders by sort order', () async {
      await plan.upsert(_item('a', order: 1));
      await plan.upsert(_item('b'));
      await plan.upsert(_item('a', order: 1).copyWith(quantity: 3));
      final day = await plan.watchDay('2026-11-05').first;
      expect(day.map((i) => i.id), ['b', 'a']);
      expect(day.last.quantity, 3);
    });

    test('watchRange is inclusive and ordered by day', () async {
      await plan.upsert(_item('a', day: '2026-11-07'));
      await plan.upsert(_item('b'));
      await plan.upsert(_item('c', day: '2026-11-09'));
      final r = await plan.watchRange('2026-11-05', '2026-11-07').first;
      expect(r.map((i) => i.id), ['b', 'a']);
    });

    test('soft delete hides the item, keeps the row, stays deleted', () async {
      await plan.upsert(_item('a'));
      await plan.delete('a');
      await plan.delete('a');
      expect(await plan.byId('a'), isNull);
      expect(await plan.watchDay('2026-11-05').first, isEmpty);
      final row = (await db.select(db.mealPlanItems).get()).single;
      expect(row.deletedAt, _later);
      await plan.upsert(_item('a'));
      expect(await plan.byId('a'), isNull);
    });

    test('markEaten stores one or several entry ids', () async {
      await plan.upsert(_item('a'));
      await plan.markEaten('a', ['e1', 'e2']);
      final got = (await plan.byId('a'))!;
      expect(got.eatenEntryIds, ['e1', 'e2']);
      expect(got.isEaten, isTrue);
      expect(got.updatedAt, _later);
    });

    test('rows with an unknown kind or unit are skipped', () async {
      await plan.upsert(_item('good'));
      await db.customUpdate(
        "UPDATE meal_plan_items SET kind = 'weird' WHERE id = 'good'",
        updates: {db.mealPlanItems},
      );
      await plan.upsert(_item('ok2'));
      final day = await plan.watchDay('2026-11-05').first;
      expect(day.map((i) => i.id), ['ok2']);
      await db.customUpdate(
        "UPDATE meal_plan_items SET unit = 'cups' WHERE id = 'ok2'",
        updates: {db.mealPlanItems},
      );
      expect(await plan.watchDay('2026-11-05').first, isEmpty);
    });
  });

  group('DriftPrepBatchRepository', () {
    setUp(() async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
    });

    test('round-trips a batch', () async {
      await batches.upsert(_batch('a', 4));
      expect(
        await batches.byId('a'),
        _batch('a', 4).copyWith(updatedAt: _later),
      );
    });

    test('watchActive excludes empty and deleted batches', () async {
      await batches.upsert(_batch('a', 4));
      await batches.upsert(_batch('b', 0));
      await batches.upsert(_batch('c', 2));
      await batches.delete('c');
      expect((await batches.watchActive().first).map((b) => b.id), ['a']);
      expect(
        (await batches.watchForRecipe('r1').first).map((b) => b.id).toSet(),
        {'a', 'b'},
      );
      expect(await batches.watchForRecipe('other').first, isEmpty);
    });

    test(
      'consume decrements, alongside runs in the same transaction',
      () async {
        await batches.upsert(_batch('a', 6));
        var ran = false;
        final out = await batches.consume(
          'a',
          1,
          alongside: () async {
            ran = true;
          },
        );
        expect(out, ConsumeOutcome.consumed);
        expect(ran, isTrue);
        expect((await batches.byId('a'))!.portionsRemaining, 5);
      },
    );

    test('alongside failure rolls the decrement back and rethrows', () async {
      await batches.upsert(_batch('a', 6));
      await expectLater(
        batches.consume('a', 1, alongside: () async => throw Exception('x')),
        throwsException,
      );
      expect((await batches.byId('a'))!.portionsRemaining, 6);
    });

    test('insufficient and missing batches change nothing', () async {
      await batches.upsert(_batch('a', 1));
      var ran = false;
      Future<void> mark() async => ran = true;
      expect(
        await batches.consume('a', 2, alongside: mark),
        ConsumeOutcome.insufficient,
      );
      expect(
        await batches.consume('zzz', 1, alongside: mark),
        ConsumeOutcome.notFound,
      );
      expect(ran, isFalse);
      expect((await batches.byId('a'))!.portionsRemaining, 1);
    });

    test('the database refuses a negative count (check constraint)', () async {
      await batches.upsert(_batch('a', 1));
      await expectLater(
        db.customStatement(
          "UPDATE prep_batches SET portions_remaining = -1 WHERE id = 'a'",
        ),
        throwsA(isA<Object>()),
      );
    });
  });
}
