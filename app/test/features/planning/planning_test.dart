import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/data/repositories/drift_meal_plan_repository.dart';
import 'package:repforge/data/repositories/drift_prep_batch_repository.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/data/repositories/drift_saved_meal_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/log_food.dart';
import 'package:repforge/features/nutrition/application/saved_meals.dart';
import 'package:repforge/features/planning/application/mark_planned_eaten.dart';
import 'package:repforge/features/planning/application/plan_item.dart';
import 'package:repforge/features/planning/application/plan_summary.dart';
import 'package:repforge/features/planning/application/prep_batches.dart';
import 'package:repforge/features/recipes/application/log_recipe.dart';

// "Today" is 2026-11-04; the 28-day window ends 2026-12-01.
final _now = DateTime.utc(2026, 11, 4, 9);
const _today = '2026-11-04';

// Chilli: 800 g of chicken at 100 kcal / P 20 per 100 g (carbs, fat, fibre
// unknown), 2 portions: per portion 400 kcal, P 80. 1.5 portions = 600 / 120.
Recipe _chilli() => Recipe(
  id: 'r1',
  name: 'Chilli',
  category: 'dinner',
  portions: 2,
  ingredients: [
    RecipeIngredient(
      id: 'i1',
      name: 'Chicken',
      foodId: 'chicken',
      quantity: Quantity.fromStored(800, ReferenceUnit.grams),
      sortOrder: 0,
      per100: const NutrientProfile(
        per100: ReferenceUnit.grams,
        per100Amounts: NutrientAmounts(kcal: 100, proteinG: 20),
        provenance: DataProvenance.verified,
      ),
    ),
  ],
  createdAt: _now,
  updatedAt: _now,
);

// Rice per 100 g: 130 kcal, P 2.7, C 28, F 0.3, fibre unknown.
// 150 g = 195 kcal, P 4.05, C 42, F 0.45.
Food _rice() => Food(
  id: 'f1',
  name: 'Rice',
  source: FoodSource.userCreated,
  profile: const NutrientProfile(
    per100: ReferenceUnit.grams,
    per100Amounts: NutrientAmounts(
      kcal: 130,
      proteinG: 2.7,
      carbsG: 28,
      fatG: 0.3,
    ),
    provenance: DataProvenance.userEntered,
  ),
  createdAt: _now,
  updatedAt: _now,
);

// Saved meal: A 300 kcal P10 C50 F6 fibre 8 (crowdsourced) + B 120 kcal P8
// C12 F4 fibre unknown (estimated) = 420 / P18 / C62 / F10 / fibre 8.
SavedMeal _meal() => SavedMeal(
  id: 's1',
  name: 'Breakfast combo',
  items: [
    SavedMealItem(
      id: 'a',
      name: 'Oats',
      quantity: Quantity.fromStored(80, ReferenceUnit.grams),
      nutrients: const NutrientAmounts(
        kcal: 300,
        proteinG: 10,
        carbsG: 50,
        fatG: 6,
        fibreG: 8,
      ),
      provenance: DataProvenance.crowdsourced,
      sortOrder: 0,
    ),
    SavedMealItem(
      id: 'b',
      name: 'Milk',
      quantity: Quantity.fromStored(250, ReferenceUnit.millilitres),
      nutrients: const NutrientAmounts(
        kcal: 120,
        proteinG: 8,
        carbsG: 12,
        fatG: 4,
      ),
      provenance: DataProvenance.estimated,
      sortOrder: 1,
    ),
  ],
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late AppDatabase db;
  late DriftRecipeRepository recipes;
  late DriftFoodRepository foods;
  late DriftSavedMealRepository savedMeals;
  late DriftFoodLogRepository log;
  late DriftMealPlanRepository plan;
  late DriftPrepBatchRepository batches;
  late PlanItem planItem;
  late MarkPlannedEaten markEaten;
  late SummarisePlanDay summarise;
  late RecordPrepBatch recordBatch;
  late ConsumePrepPortion consume;
  final clock = FixedClock(_now);
  var ids = 0;
  String newId() => 'id${++ids}';

  setUp(() async {
    db = AppDatabase.inMemory();
    ids = 0;
    recipes = DriftRecipeRepository(db, clock: clock);
    foods = DriftFoodRepository(db, clock: clock);
    savedMeals = DriftSavedMealRepository(db, clock: clock);
    log = DriftFoodLogRepository(db, clock: clock);
    plan = DriftMealPlanRepository(db, clock: clock);
    batches = DriftPrepBatchRepository(db, clock: clock);
    await recipes.upsert(_chilli());
    await foods.upsert(_rice());
    await savedMeals.upsert(_meal());
    planItem = PlanItem(
      plan: plan,
      recipes: recipes,
      foods: foods,
      savedMeals: savedMeals,
      clock: clock,
      newId: newId,
    );
    final logRecipe = LogRecipe(
      recipes: recipes,
      log: log,
      clock: clock,
      newId: newId,
      prepBatches: batches,
    );
    markEaten = MarkPlannedEaten(
      plan: plan,
      recipes: recipes,
      foods: foods,
      savedMeals: savedMeals,
      log: log,
      logFood: LogFood(foods: foods, log: log, clock: clock, newId: newId),
      logRecipe: logRecipe,
      logSavedMeal: LogSavedMeal(log: log, clock: clock, newId: newId),
    );
    summarise = SummarisePlanDay(
      plan: plan,
      recipes: recipes,
      foods: foods,
      savedMeals: savedMeals,
    );
    recordBatch = RecordPrepBatch(
      batches: batches,
      recipes: recipes,
      clock: clock,
      newId: newId,
    );
    consume = ConsumePrepPortion(batches: batches);
  });
  tearDown(() => db.close());

  Future<Result<MealPlanItem>> planRecipe(String day, [double q = 1.5]) =>
      planItem(
        day: day,
        meal: MealSlot.dinner,
        kind: PlannedKind.recipe,
        refId: 'r1',
        quantity: q,
      );

  MealPlanItem ok(Result<MealPlanItem> r) => (r as Ok<MealPlanItem>).value;

  Future<List<FoodLogEntry>> logged() => log.forDays(_today, '2026-12-31');

  group('28-day window (RCP-014(1))', () {
    test('today and today + 27 are accepted', () async {
      expect((await planRecipe(_today)).isOk, isTrue);
      expect((await planRecipe('2026-12-01')).isOk, isTrue);
    });

    test('today + 28 and yesterday are rejected, nothing stored', () async {
      for (final day in ['2026-12-02', '2026-11-03']) {
        final r = await planRecipe(day);
        expect(r, isA<Err<MealPlanItem>>());
        expect(
          ((r as Err<MealPlanItem>).error as ValidationError).field,
          PlanErrorField.day,
        );
      }
      expect(await plan.watchRange('2026-01-01', '2027-01-01').first, isEmpty);
    });

    test('malformed or impossible dates are rejected', () async {
      for (final day in ['2026-11-4', '2026-02-30', 'tomorrow', '']) {
        expect((await planRecipe(day)).isErr, isTrue, reason: day);
      }
    });

    test('the window follows the clock', () {
      expect(isInPlanWindow('2026-12-01', DateTime(2026, 11, 4)), isTrue);
      expect(isInPlanWindow('2026-12-01', DateTime(2026, 11, 5)), isTrue);
      expect(isInPlanWindow('2026-12-02', DateTime(2026, 11, 5)), isTrue);
      expect(isInPlanWindow('2026-12-02', DateTime(2026, 11, 4)), isFalse);
    });

    test('zero quantity, missing reference are typed errors', () async {
      expect((await planRecipe(_today, 0)).isErr, isTrue);
      final r = await planItem(
        day: _today,
        meal: MealSlot.lunch,
        kind: PlannedKind.food,
        refId: 'nope',
        quantity: 100,
      );
      expect((r as Err<MealPlanItem>).error, isA<NotFoundError>());
    });

    test('item takes name and unit from the reference', () async {
      final food = ok(
        await planItem(
          day: _today,
          meal: MealSlot.lunch,
          kind: PlannedKind.food,
          refId: 'f1',
          quantity: 150,
        ),
      );
      expect(food.name, 'Rice');
      expect(food.unit, ReferenceUnit.grams);
      final recipe = ok(await planRecipe(_today));
      expect(recipe.unit, ReferenceUnit.portions);
      expect(recipe.name, 'Chilli');
    });

    test('editing moves the item and keeps its identity', () async {
      final item = ok(await planRecipe(_today));
      final moved = ok(
        await planItem(
          id: item.id,
          day: '2026-11-06',
          meal: MealSlot.lunch,
          kind: PlannedKind.recipe,
          refId: 'r1',
          quantity: 2,
        ),
      );
      expect(moved.id, item.id);
      expect((await plan.byId(item.id))!.day, '2026-11-06');
      expect((await plan.byId(item.id))!.quantity, 2);
    });
  });

  group('plan-day totals equal the log (RCP-014(2))', () {
    Future<void> planThree() async {
      ok(await planRecipe(_today));
      ok(
        await planItem(
          day: _today,
          meal: MealSlot.lunch,
          kind: PlannedKind.food,
          refId: 'f1',
          quantity: 150,
        ),
      );
      ok(
        await planItem(
          day: _today,
          meal: MealSlot.breakfast,
          kind: PlannedKind.savedMeal,
          refId: 's1',
          quantity: 1,
        ),
      );
    }

    test('hand-calculated planned totals', () async {
      await planThree();
      final s = ((await summarise(_today)) as Ok<PlanDaySummary>).value;
      final k = s.totals.known;
      expect(k.kcal, closeTo(1215, 1e-9)); // 600 + 195 + 420
      expect(k.proteinG, closeTo(142.05, 1e-9)); // 120 + 4.05 + 18
      expect(k.carbsG, closeTo(104, 1e-9)); // 42 + 62, recipe unknown
      expect(k.fatG, closeTo(10.45, 1e-9)); // 0.45 + 10, recipe unknown
      expect(k.fibreG, closeTo(8, 1e-9)); // only oats knows fibre
      expect(s.totals.unknownCarbsCount, 1);
      expect(s.totals.unknownFatCount, 1);
      expect(s.totals.unknownFibreCount, 3); // recipe, rice, milk
      expect(s.totals.unknownProteinCount, 0);
      expect(s.provenance, DataProvenance.estimated); // weakest of the four
      expect(s.itemCount, 3);
      expect(s.unresolvedCount, 0);
    });

    test('the same items logged give identical totals', () async {
      await planThree();
      final planned = ((await summarise(_today)) as Ok<PlanDaySummary>).value;
      for (final item in await plan.watchDay(_today).first) {
        expect((await markEaten(item.id)).isOk, isTrue);
      }
      final entries = await logged();
      expect(entries, hasLength(4)); // recipe, rice, two saved-meal items
      final fromLog = NutrientTotals.of(entries.map((e) => e.nutrients));
      expect(planned.totals, fromLog);
      expect(
        weakestProvenance(entries.map((e) => e.provenance)),
        planned.provenance,
      );
    });

    test('saved meal multiplier scales every snapshot', () {
      final item = MealPlanItem(
        id: 'x',
        day: _today,
        meal: MealSlot.lunch,
        kind: PlannedKind.savedMeal,
        refId: 's1',
        name: 'Breakfast combo',
        quantity: 2,
        unit: ReferenceUnit.portions,
        sortOrder: 0,
        createdAt: _now,
        updatedAt: _now,
      );
      final n = plannedNutrition(item, savedMeal: _meal())!;
      expect(n.kcal, 840);
      expect(n.proteinG, 36);
      expect(n.fibreG, 16);
    });

    test('a deleted reference counts as unknown, nothing invented', () async {
      await planThree();
      await recipes.delete('r1');
      await foods.delete('f1');
      final s = ((await summarise(_today)) as Ok<PlanDaySummary>).value;
      expect(s.unresolvedCount, 2);
      expect(s.itemCount, 3);
      expect(s.totals.known.kcal, closeTo(420, 1e-9)); // saved meal only
      expect(s.provenance, DataProvenance.estimated);
    });

    test('an empty day has empty totals and no provenance', () async {
      final s = ((await summarise('2026-11-10')) as Ok<PlanDaySummary>).value;
      expect(s.totals, NutrientTotals.empty);
      expect(s.provenance, isNull);
    });
  });

  group('MarkPlannedEaten (RCP-014(3))', () {
    test('logs a recipe with the planned portions and records ids', () async {
      final item = ok(await planRecipe(_today));
      final entries =
          ((await markEaten(item.id)) as Ok<List<FoodLogEntry>>).value;
      expect(entries.single.quantity.amount, 1.5);
      expect(entries.single.nutrients.kcal, closeTo(600, 1e-9));
      expect(entries.single.meal, MealSlot.dinner);
      expect(entries.single.day, _today);
      expect(entries.single.recipeId, 'r1');
      final stored = (await plan.byId(item.id))!;
      expect(stored.isEaten, isTrue);
      expect(stored.eatenEntryIds, [entries.single.id]);
      expect(await logged(), hasLength(1));
    });

    test('an override quantity replaces the planned one', () async {
      final item = ok(await planRecipe(_today));
      final entries = ((await markEaten(
        item.id,
        overrideQuantity: 1,
      )) as Ok<List<FoodLogEntry>>).value;
      expect(entries.single.quantity.amount, 1);
      expect(entries.single.nutrients.kcal, closeTo(400, 1e-9));
    });

    test('food: planned 150 g logs 195 kcal', () async {
      final item = ok(
        await planItem(
          day: _today,
          meal: MealSlot.lunch,
          kind: PlannedKind.food,
          refId: 'f1',
          quantity: 150,
        ),
      );
      final e =
          ((await markEaten(item.id)) as Ok<List<FoodLogEntry>>).value.single;
      expect(e.quantity.label, '150 g');
      expect(e.nutrients.kcal, closeTo(195, 1e-9));
    });

    test('saved meal: x1 logs both items, x2 override doubles them', () async {
      final a = ok(
        await planItem(
          day: _today,
          meal: MealSlot.breakfast,
          kind: PlannedKind.savedMeal,
          refId: 's1',
          quantity: 1,
        ),
      );
      final one = ((await markEaten(a.id)) as Ok<List<FoodLogEntry>>).value;
      expect(one.map((e) => e.nutrients.kcal), [300, 120]);
      expect((await plan.byId(a.id))!.eatenEntryIds, hasLength(2));

      final b = ok(
        await planItem(
          day: _today,
          meal: MealSlot.breakfast,
          kind: PlannedKind.savedMeal,
          refId: 's1',
          quantity: 1,
        ),
      );
      final two = ((await markEaten(
        b.id,
        overrideQuantity: 2,
      )) as Ok<List<FoodLogEntry>>).value;
      expect(two.map((e) => e.nutrients.kcal), [600, 240]);
      expect(two.first.quantity.amount, 160);
    });

    test('a second mark is refused and logs nothing more', () async {
      final item = ok(await planRecipe(_today));
      await markEaten(item.id);
      final again = await markEaten(item.id);
      final error = (again as Err<List<FoodLogEntry>>).error;
      expect(error, isA<ValidationError>());
      expect((error as ValidationError).field, PlanErrorField.alreadyEaten);
      expect(await logged(), hasLength(1));
    });

    test('an eaten item cannot be edited', () async {
      final item = ok(await planRecipe(_today));
      await markEaten(item.id);
      final r = await planItem(
        id: item.id,
        day: _today,
        meal: MealSlot.dinner,
        kind: PlannedKind.recipe,
        refId: 'r1',
        quantity: 3,
      );
      expect(
        ((r as Err<MealPlanItem>).error as ValidationError).field,
        PlanErrorField.alreadyEaten,
      );
    });

    test('deleted reference: typed NotFound, nothing logged', () async {
      final r = ok(await planRecipe(_today));
      final f = ok(
        await planItem(
          day: _today,
          meal: MealSlot.lunch,
          kind: PlannedKind.food,
          refId: 'f1',
          quantity: 100,
        ),
      );
      final s = ok(
        await planItem(
          day: _today,
          meal: MealSlot.snack,
          kind: PlannedKind.savedMeal,
          refId: 's1',
          quantity: 1,
        ),
      );
      await recipes.delete('r1');
      await foods.delete('f1');
      await savedMeals.delete('s1');
      for (final item in [r, f, s]) {
        final res = await markEaten(item.id);
        expect((res as Err<List<FoodLogEntry>>).error, isA<NotFoundError>());
        expect((await plan.byId(item.id))!.isEaten, isFalse);
      }
      expect(await logged(), isEmpty);
    });

    test('invalid override and unknown item are refused', () async {
      final item = ok(await planRecipe(_today));
      expect((await markEaten(item.id, overrideQuantity: 0)).isErr, isTrue);
      expect((await markEaten('missing')).isErr, isTrue);
      expect(await logged(), isEmpty);
    });

    test('a removed item cannot be marked eaten', () async {
      final item = ok(await planRecipe(_today));
      await RemovePlannedItem(plan: plan)(item.id);
      expect((await markEaten(item.id)).isErr, isTrue);
      expect(await plan.watchDay(_today).first, isEmpty);
    });
  });

  group('prep batches (RCP-015)', () {
    Future<PrepBatch> record(double n) async => ((await recordBatch(
      recipeId: 'r1',
      portionsMade: n,
    )) as Ok<PrepBatch>).value;

    test('recording 6 portions leaves 6 remaining', () async {
      final b = await record(6);
      expect(b.portionsMade, 6);
      expect(b.portionsRemaining, 6);
      expect((await batches.byId(b.id))!.portionsRemaining, 6);
    });

    test('rejects zero portions and an unknown recipe', () async {
      expect((await recordBatch(recipeId: 'r1', portionsMade: 0)).isErr, true);
      final r = await recordBatch(recipeId: 'nope', portionsMade: 4);
      expect((r as Err<PrepBatch>).error, isA<NotFoundError>());
    });

    test('consume 1 leaves 5; consume to 0; 1 from 0 is refused', () async {
      final b = await record(6);
      final after = ((await consume(b.id, 1)) as Ok<PrepBatch>).value;
      expect(after.portionsRemaining, 5);
      expect(((await consume(b.id, 5)) as Ok<PrepBatch>).value.isEmpty, true);
      final refused = await consume(b.id, 1);
      final error = (refused as Err<PrepBatch>).error as ValidationError;
      expect(error.field, prepInsufficientField);
      expect((await batches.byId(b.id))!.portionsRemaining, 0);
    });

    test('partial portions are allowed and never go negative', () async {
      final b = await record(1);
      expect(
        ((await consume(b.id, 0.5)) as Ok<PrepBatch>).value.portionsRemaining,
        0.5,
      );
      expect((await consume(b.id, 0.6)).isErr, isTrue);
      expect(
        ((await consume(b.id, 0.5)) as Ok<PrepBatch>).value.portionsRemaining,
        0,
      );
    });

    test(
      '0.1 steps do not drift (10 x 0.1 from 1 reaches exactly 0)',
      () async {
        final b = await record(1);
        for (var i = 0; i < 10; i++) {
          expect((await consume(b.id, 0.1)).isOk, isTrue, reason: 'step $i');
        }
        expect((await batches.byId(b.id))!.portionsRemaining, 0);
      },
    );

    test('unknown batch is NotFound; non-positive amounts refused', () async {
      expect(
        ((await consume('nope', 1)) as Err<PrepBatch>).error,
        isA<NotFoundError>(),
      );
      final b = await record(2);
      expect((await consume(b.id, 0)).isErr, isTrue);
    });

    test('active list hides empty batches', () async {
      final a = await record(2);
      final b = await record(1);
      await consume(b.id, 1);
      final active = await batches.watchActive().first;
      expect(active.map((x) => x.id), [a.id]);
      expect(await batches.watchForRecipe('r1').first, hasLength(2));
    });
  });
}
