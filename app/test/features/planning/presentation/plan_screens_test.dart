import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/data/repositories/drift_meal_plan_repository.dart';
import 'package:repforge/data/repositories/drift_prep_batch_repository.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/data/repositories/drift_saved_meal_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/features/planning/application/planning_providers.dart';
import 'package:repforge/ui/components/rf_macro_bar.dart';
import 'package:repforge/ui/components/rf_text_field.dart';

import '../../../helpers/pump.dart';

// "Today" is 2026-11-04 (local); the window ends 2026-12-01.
final _now = DateTime(2026, 11, 4, 9);
const _today = '2026-11-04';
const _last = '2026-12-01';

final class _OnlineLookup implements FoodLookupService {
  _OnlineLookup(this.food);
  final Food food;

  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async =>
      Ok([food]);

  @override
  Future<Result<Food?>> byBarcode(String barcode) async => Ok(food);
}

final class _NoLookup implements FoodLookupService {
  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async =>
      const Ok([]);

  @override
  Future<Result<Food?>> byBarcode(String barcode) async => const Ok(null);
}

// Chilli: 800 g of chicken at 100 kcal / P 20 per 100 g (carbs, fat and
// fibre unknown), 2 portions: 400 kcal and P 80 per portion.
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
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

// Rice per 100 g: 130 kcal; 150 g = 195 kcal.
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
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

// 300 + 120 = 420 kcal.
SavedMeal _combo() => SavedMeal(
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
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

void main() {
  late AppDatabase db;
  late DriftRecipeRepository recipes;
  late DriftFoodRepository foods;
  late DriftSavedMealRepository savedMeals;
  late DriftFoodLogRepository log;
  late DriftPrepBatchRepository batches;
  late DriftMealPlanRepository planRepo;
  final clock = FixedClock(_now);

  setUp(() async {
    db = AppDatabase.inMemory();
    recipes = DriftRecipeRepository(db, clock: clock);
    foods = DriftFoodRepository(db, clock: clock);
    savedMeals = DriftSavedMealRepository(db, clock: clock);
    log = DriftFoodLogRepository(db, clock: clock);
    batches = DriftPrepBatchRepository(db, clock: clock);
    planRepo = DriftMealPlanRepository(db, clock: clock);
    await recipes.upsert(_chilli());
    await foods.upsert(_rice());
    await savedMeals.upsert(_combo());
  });
  tearDown(() => db.close());

  Future<void> open(
    WidgetTester tester, {
    String location = RfRoutes.fuel,
    DateTime? at,
    FoodLookupService? lookup,
  }) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(at == null ? clock : FixedClock(at)),
          foodLookupServiceProvider.overrideWithValue(lookup ?? _NoLookup()),
          minuteTickProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: RepForgeApp(router: createRouter(initialLocation: location)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// First value of a drift stream (needs real time, see [settle]).
  Future<List<E>> firstOf<E>(
    WidgetTester tester,
    Stream<List<E>> stream,
  ) async => (await tester.runAsync(() => stream.first))!;

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(RepForgeApp)));

  /// `PlanItem` reads `watchDay(day).first`, which drift only completes in
  /// real time while the screen also listens to that day (fake time never
  /// advances it), so taps that call it let real time pass.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(
    WidgetTester tester,
    String key, {
    bool real = false,
  }) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f);
    await tester.tap(f);
    if (real) {
      await tester.pump(); // the button spins until the use case is done
      await settle(tester);
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<MealPlanItem> plan(
    WidgetTester tester, {
    required PlannedKind kind,
    required String refId,
    required double quantity,
    String day = _today,
    MealSlot meal = MealSlot.dinner,
  }) async {
    final r = await tester.runAsync(
      () => container(tester).read(planItemProvider)(
        day: day,
        meal: meal,
        kind: kind,
        refId: refId,
        quantity: quantity,
      ),
    );
    await tester.pumpAndSettle();
    return (r! as Ok<MealPlanItem>).value;
  }

  String kcalText(WidgetTester tester, String key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
      )
      .map((t) => t.data)
      .join('|');

  RfMacroBar bar(WidgetTester tester, String label) =>
      tester.widget<RfMacroBar>(
        find.byWidgetPredicate((w) => w is RfMacroBar && w.label == label),
      );

  testWidgets('plan today and today + 27; today + 28 is unreachable', (
    tester,
  ) async {
    await open(tester);
    await tapKey(tester, 'open-plan');
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Nothing planned.'), findsNWidgets(4));
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('plan-day-previous')))
          .onPressed,
      isNull,
    );

    // Recipe 1.5 portions (default 1 + one step) for Dinner today.
    await tapKey(tester, 'plan-add-dinner');
    await tapKey(tester, 'plan-add-recipe');
    await tapKey(tester, 'pick-recipe-r1');
    await tapKey(tester, 'plan-quantity-inc');
    await tapKey(tester, 'plan-submit', real: true);
    expect(find.text('Chilli'), findsOneWidget);
    expect(find.textContaining('1.5 portions'), findsOneWidget);
    expect(find.text('600 kcal'), findsWidgets);
    expect(kcalText(tester, 'plan-kcal'), contains('600'));

    // Walk to the last plannable day.
    for (var i = 0; i < 27; i++) {
      await tester.tap(find.byKey(const Key('plan-day-next')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Tue 1 Dec'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('plan-day-next')))
          .onPressed,
      isNull,
    );
    expect(find.text('Chilli'), findsNothing);

    // Food 150 g for Lunch on the last day, picked through the food search.
    await tapKey(tester, 'plan-add-lunch');
    await tapKey(tester, 'plan-add-food');
    await tester.enterText(find.byKey(const Key('food-query')), 'Rice');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('local-f1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plan-quantity')), '150');
    await tapKey(tester, 'plan-submit', real: true);
    expect(find.textContaining('150 g'), findsOneWidget);
    expect(find.text('195 kcal'), findsWidgets);

    final c = container(tester);
    expect(
      (await firstOf(tester, planRepo.watchDay(_last))).map((i) => i.name),
      ['Rice'],
    );
    expect(
      (await firstOf(tester, planRepo.watchDay(_today))).map((i) => i.name),
      ['Chilli'],
    );

    // Forcing today + 28 is refused and stores nothing.
    final forced = await tester.runAsync(
      () => c.read(planItemProvider)(
        day: '2026-12-02',
        meal: MealSlot.dinner,
        kind: PlannedKind.recipe,
        refId: 'r1',
        quantity: 1,
      ),
    );
    expect(forced, isA<Err<MealPlanItem>>());
    expect(await firstOf(tester, planRepo.watchDay('2026-12-02')), isEmpty);
    await unmount(tester);
  });

  testWidgets('plan day totals equal the diary totals once all is eaten', (
    tester,
  ) async {
    await open(tester);
    await tapKey(tester, 'open-plan');

    // Recipe 1.5 portions (600), food 150 g (195), saved meal x1 (420).
    await tapKey(tester, 'plan-add-dinner');
    await tapKey(tester, 'plan-add-recipe');
    await tapKey(tester, 'pick-recipe-r1');
    await tapKey(tester, 'plan-quantity-inc');
    await tapKey(tester, 'plan-submit', real: true);
    await tapKey(tester, 'plan-add-lunch');
    await tapKey(tester, 'plan-add-food');
    await tester.enterText(find.byKey(const Key('food-query')), 'Rice');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('local-f1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plan-quantity')), '150');
    await tapKey(tester, 'plan-submit', real: true);
    await tapKey(tester, 'plan-add-breakfast');
    await tapKey(tester, 'plan-add-saved-meal');
    await tapKey(tester, 'pick-saved-s1');
    await tapKey(tester, 'plan-submit', real: true);
    expect(find.textContaining('×1 saved meal'), findsOneWidget);
    expect(find.text('420 kcal'), findsWidgets);

    final planKcal = kcalText(tester, 'plan-kcal');
    expect(planKcal, contains('1215'));
    final planned = {
      for (final l in ['Protein', 'Carbs', 'Fat', 'Fibre'])
        l: (bar(tester, l).amount, bar(tester, l).unknownCount),
    };
    // Same semantics as the diary: carbs/fat/fibre are partly unknown.
    expect(bar(tester, 'Protein').amount, isNotNull);
    expect(bar(tester, 'Carbs').unknownCount, 1);
    expect(find.text('Verified'), findsNothing);
    expect(find.text('Estimate'), findsOneWidget); // weakest of the three
    expect(find.byKey(const Key('plan-unresolved')), findsNothing);

    final items = await firstOf(tester, planRepo.watchDay(_today));
    expect(items, hasLength(3));
    for (final i in items) {
      await tapKey(tester, 'plan-eat-${i.id}');
      expect(
        tester
            .widget<RfTextField>(find.byKey(const Key('eaten-quantity')))
            .controller!
            .text,
        isNotEmpty,
      );
      await tapKey(tester, 'eaten-confirm');
      expect(find.byKey(Key('plan-eaten-${i.id}')), findsOneWidget);
      expect(find.byKey(Key('plan-eat-${i.id}')), findsNothing);
    }
    expect(find.textContaining('Eaten'), findsNWidgets(3));
    expect(kcalText(tester, 'plan-kcal'), planKcal);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(kcalText(tester, 'fuel-kcal'), contains('1215'));
    for (final l in planned.keys) {
      expect(
        (bar(tester, l).amount, bar(tester, l).unknownCount),
        planned[l],
        reason: l,
      );
    }
    await unmount(tester);
  });

  testWidgets('mark eaten logs the edited amount and cannot repeat', (
    tester,
  ) async {
    await open(tester, location: RfRoutes.fuelPlan);
    final item = await plan(
      tester,
      kind: PlannedKind.recipe,
      refId: 'r1',
      quantity: 1,
    );
    await tapKey(tester, 'plan-eat-${item.id}');
    expect(
      tester
          .widget<RfTextField>(find.byKey(const Key('eaten-quantity')))
          .controller!
          .text,
      '1',
    );
    await tester.enterText(find.byKey(const Key('eaten-quantity')), '2');
    await tapKey(tester, 'eaten-confirm');

    final entries = await log.forDays(_today, _today);
    expect(entries, hasLength(1));
    expect(entries.single.quantity.amount, 2);
    expect(entries.single.nutrients.kcal, 800);
    expect(find.byKey(Key('plan-eaten-${item.id}')), findsOneWidget);
    expect(find.byKey(Key('plan-eat-${item.id}')), findsNothing);

    // A second mark (forced through the use case) is refused.
    final again = await container(tester)
        .read(markPlannedEatenProvider)(item.id);
    expect(
      ((again as Err).error as ValidationError).field,
      PlanErrorField.alreadyEaten,
    );
    expect(await log.forDays(_today, _today), hasLength(1));
    await unmount(tester);
  });

  testWidgets('a deleted recipe is noted and cannot be marked eaten', (
    tester,
  ) async {
    await open(tester, location: RfRoutes.fuelPlan);
    final item = await plan(
      tester,
      kind: PlannedKind.recipe,
      refId: 'r1',
      quantity: 1,
    );
    await plan(
      tester,
      kind: PlannedKind.food,
      refId: 'f1',
      quantity: 150,
      meal: MealSlot.lunch,
    );
    await recipes.delete('r1');
    await tester.pumpAndSettle();
    expect(find.text('1 planned item no longer exists'), findsOneWidget);
    expect(find.text('n/a'), findsWidgets);
    expect(kcalText(tester, 'plan-kcal'), contains('195'));

    await tapKey(tester, 'plan-eat-${item.id}');
    await tapKey(tester, 'eaten-confirm');
    expect(
      find.text('What was planned no longer exists, so it cannot be logged.'),
      findsOneWidget,
    );
    expect(await log.forDays(_today, _today), isEmpty);

    // The unresolved item can still be removed.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tapKey(tester, 'plan-remove-${item.id}');
    expect(find.byKey(const Key('plan-unresolved')), findsNothing);
    await unmount(tester);
  });

  testWidgets('record a batch, log from it, and refuse too many', (
    tester,
  ) async {
    await open(tester, location: RfRoutes.fuelRecipe('r1'));
    await tapKey(tester, 'record-batch');
    await tester.enterText(find.byKey(const Key('batch-portions')), '0');
    await tapKey(tester, 'batch-submit');
    expect(find.text('Enter the number of portions made.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('batch-portions')), '6');
    await tapKey(tester, 'batch-submit');
    expect(find.text('6 portions left'), findsOneWidget);
    final batch = (await firstOf(tester, batches.watchForRecipe('r1'))).single;

    // Log 1 portion from the batch.
    await tapKey(tester, 'recipe-log');
    expect(find.text('FROM PREPARED BATCH'), findsOneWidget);
    await tapKey(tester, 'log-batch-${batch.id}');
    await tapKey(tester, 'log-submit');
    expect(find.text('5 portions left'), findsOneWidget);
    expect(await log.forDays(_today, _today), hasLength(1));

    // Delete it.
    await tapKey(tester, 'batch-delete-${batch.id}');
    await tapKey(tester, 'batch-delete-confirm');
    expect(find.byKey(const Key('prep-batches')), findsNothing);
    await unmount(tester);
  });

  testWidgets('logging more than a batch holds is refused', (tester) async {
    await open(tester, location: RfRoutes.fuelRecipe('r1'));
    await tapKey(tester, 'record-batch');
    await tester.enterText(find.byKey(const Key('batch-portions')), '1');
    await tapKey(tester, 'batch-submit');
    expect(find.text('1 portion left'), findsOneWidget);
    final batch = (await firstOf(tester, batches.watchForRecipe('r1'))).single;

    await tapKey(tester, 'recipe-log');
    await tapKey(tester, 'log-batch-${batch.id}');
    await tester.enterText(find.byKey(const Key('log-portions')), '2');
    await tapKey(tester, 'log-submit');
    expect(
      find.text('Not enough portions remaining in this batch.'),
      findsOneWidget,
    );
    expect(await log.forDays(_today, _today), isEmpty);
    expect((await batches.byId(batch.id))!.portionsRemaining, 1);

    // Taking the last portion shows the batch as used up; it is then not
    // offered in the log sheet.
    await tester.enterText(find.byKey(const Key('log-portions')), '1');
    await tapKey(tester, 'log-submit');
    expect(find.text('used up'), findsOneWidget);
    await tapKey(tester, 'recipe-log');
    expect(find.text('FROM PREPARED BATCH'), findsNothing);
    await unmount(tester);
  });

  testWidgets('mark eaten can draw from a batch; prep list on the plan', (
    tester,
  ) async {
    await open(tester, location: RfRoutes.fuelPlan);
    final r = await container(tester)
        .read(recordPrepBatchProvider)(recipeId: 'r1', portionsMade: 3);
    final batch = (r as Ok<PrepBatch>).value;
    await tester.pumpAndSettle();
    expect(find.text('Chilli'), findsOneWidget); // in the prep list
    expect(find.text('3 portions left'), findsOneWidget);

    final item = await plan(
      tester,
      kind: PlannedKind.recipe,
      refId: 'r1',
      quantity: 2,
    );
    await tapKey(tester, 'plan-eat-${item.id}');
    await tapKey(tester, 'eaten-batch-${batch.id}');
    await tapKey(tester, 'eaten-confirm');
    expect((await batches.byId(batch.id))!.portionsRemaining, 1);
    expect(find.text('1 portion left'), findsOneWidget);

    // Another 2 planned portions from the 1 left: refused, nothing logged.
    final second = await plan(
      tester,
      kind: PlannedKind.recipe,
      refId: 'r1',
      quantity: 2,
      meal: MealSlot.lunch,
    );
    await tapKey(tester, 'plan-eat-${second.id}');
    await tapKey(tester, 'eaten-batch-${batch.id}');
    await tapKey(tester, 'eaten-confirm');
    expect(
      find.text('Not enough portions remaining in this batch.'),
      findsOneWidget,
    );
    expect(await log.forDays(_today, _today), hasLength(1));
    expect((await batches.byId(batch.id))!.portionsRemaining, 1);
    await unmount(tester);
  });

  testWidgets('an online food picked for the plan is cached and plannable', (
    tester,
  ) async {
    final off = Food(
      id: 'off-1',
      name: 'Online Oats',
      source: FoodSource.openFoodFacts,
      barcode: '123',
      profile: const NutrientProfile(
        per100: ReferenceUnit.grams,
        per100Amounts: NutrientAmounts(kcal: 370, proteinG: 13),
        provenance: DataProvenance.crowdsourced,
      ),
      createdAt: _now.toUtc(),
      updatedAt: _now.toUtc(),
    );
    await open(tester, location: RfRoutes.fuelPlan, lookup: _OnlineLookup(off));
    expect(await foods.byId('off-1'), isNull);
    await tapKey(tester, 'plan-add-lunch');
    await tapKey(tester, 'plan-add-food');
    await tester.enterText(find.byKey(const Key('food-query')), 'Oats');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tapKey(tester, 'online-off-1', real: true);
    await tester.enterText(find.byKey(const Key('plan-quantity')), '100');
    await tapKey(tester, 'plan-submit', real: true);
    expect(find.textContaining('That food no longer exists'), findsNothing);
    expect(find.text('Online Oats'), findsOneWidget);
    expect(find.text('370 kcal'), findsWidgets);
    expect(await tester.runAsync(() => foods.byId('off-1')), isNotNull);
    await unmount(tester);
  });

  testWidgets('the plan opens on the diary day, not the calendar day', (
    tester,
  ) async {
    // 01:00 on 5 Nov with a 04:00 day start is still the 4 Nov diary day.
    await DriftSettingsRepository(
      db,
      clock: clock,
    ).save(const AppSettings(dayStartHour: 4));
    await open(
      tester,
      location: RfRoutes.fuelPlan,
      at: DateTime(2026, 11, 5, 1),
    );
    final item = await plan(
      tester,
      kind: PlannedKind.recipe,
      refId: 'r1',
      quantity: 1,
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.byKey(Key('plan-item-${item.id}')), findsOneWidget);
    // The window ends 28 days after the diary day: 1 Dec, not 2 Dec.
    for (var i = 0; i < 27; i++) {
      await tester.tap(find.byKey(const Key('plan-day-next')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Tue 1 Dec'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a future-day item cannot be marked as eaten', (tester) async {
    await open(tester, location: RfRoutes.fuelPlan);
    final item = await plan(
      tester,
      kind: PlannedKind.recipe,
      refId: 'r1',
      quantity: 1,
      day: '2026-11-05',
    );
    expect(find.byKey(Key('plan-eat-${item.id}')), findsNothing);
    await tapKey(tester, 'plan-day-next');
    expect(find.byKey(Key('plan-item-${item.id}')), findsOneWidget);
    expect(find.byKey(Key('plan-eat-${item.id}')), findsNothing);
    expect(find.byKey(const Key('plan-future-note')), findsOneWidget);
    expect(find.byKey(Key('plan-remove-${item.id}')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the mark-eaten sheet limits portions to one decimal', (
    tester,
  ) async {
    await open(tester, location: RfRoutes.fuelPlan);
    final item = await plan(
      tester,
      kind: PlannedKind.recipe,
      refId: 'r1',
      quantity: 1,
    );
    await tapKey(tester, 'plan-eat-${item.id}');
    await tester.enterText(find.byKey(const Key('eaten-quantity')), '1.2');
    await tester.enterText(find.byKey(const Key('eaten-quantity')), '1.25');
    final text = tester
        .widget<RfTextField>(find.byKey(const Key('eaten-quantity')))
        .controller!
        .text;
    expect(text, '1.2');
    await unmount(tester);
  });
}
