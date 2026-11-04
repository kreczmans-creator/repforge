import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/log_food.dart';
import 'package:repforge/features/recipes/application/log_recipe.dart';
import 'package:repforge/features/recipes/application/save_recipe.dart';

final _t = DateTime.utc(2026, 11, 4, 9);

// 100 kcal, P 20 per 100 g; carbs, fat, fibre unknown.
NutrientProfile _profile({DataProvenance p = DataProvenance.verified}) =>
    NutrientProfile(
      per100: ReferenceUnit.grams,
      per100Amounts: const NutrientAmounts(kcal: 100, proteinG: 20),
      provenance: p,
    );

RecipeIngredient _ing(
  String id,
  double grams, {
  DataProvenance p = DataProvenance.verified,
}) => RecipeIngredient(
  id: id,
  name: 'Chicken',
  foodId: 'chicken',
  quantity: Quantity.fromStored(grams, ReferenceUnit.grams),
  sortOrder: 0,
  per100: _profile(p: p),
);

/// 800 g at 100 kcal / 100 g = 800 kcal in 2 portions: 400 kcal and 80 g
/// protein per portion; W = 800 g.
Recipe _chilli({
  double grams = 800,
  DataProvenance p = DataProvenance.verified,
}) => Recipe(
  id: 'r1',
  name: 'Chilli con carne',
  category: 'dinner',
  portions: 2,
  ingredients: [_ing('i1', grams, p: p)],
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  late AppDatabase db;
  late DriftRecipeRepository recipes;
  late DriftFoodLogRepository log;
  late LogRecipe logRecipe;
  late SaveRecipe save;
  var ids = 0;
  final clock = FixedClock(_t);

  setUp(() {
    db = AppDatabase.inMemory();
    recipes = DriftRecipeRepository(db, clock: clock);
    log = DriftFoodLogRepository(db, clock: clock);
    ids = 0;
    logRecipe = LogRecipe(
      recipes: recipes,
      log: log,
      clock: clock,
      newId: () => 'e${++ids}',
    );
    save = SaveRecipe(recipes: recipes, clock: clock, newId: () => 'n${++ids}');
  });
  tearDown(() => db.close());

  Future<List<FoodLogEntry>> entries() =>
      log.forDays('2026-11-04', '2026-11-04');

  Future<FoodLogEntry> logPortions(double n) async => ((await logRecipe(
    recipeId: 'r1',
    meal: MealSlot.dinner,
    day: '2026-11-04',
    portions: n,
  )) as Ok<FoodLogEntry>).value;

  group('LogRecipe by portions (RCP-012)', () {
    setUp(() async {
      await save(_chilli());
    });

    test(
      'RCP-012(1) 1.5 portions at 400 kcal per portion adds 600 kcal',
      () async {
        final e = await logPortions(1.5);
        expect(e.nutrients.kcal, closeTo(600, 1e-9));
        expect(e.nutrients.proteinG, closeTo(120, 1e-9));
        expect((await entries()).single.nutrients.kcal, closeTo(600, 1e-9));
      },
    );

    test('RCP-012(2) the entry shows the recipe name and the portion count, '
        'and stores the snapshot', () async {
      final e = await logPortions(1.5);
      final stored = (await entries()).single;
      expect(stored.name, 'Chilli con carne');
      expect(stored.quantity.amount, 1.5);
      expect(stored.quantity.unit, ReferenceUnit.portions);
      expect(stored.quantity.label, '1.5 portions');
      expect(stored, e);
    });

    test('unknown nutrients stay null in the snapshot (spec 7.5)', () async {
      final e = await logPortions(1);
      expect(e.nutrients.carbsG, isNull);
      expect(e.nutrients.fibreG, isNull);
      expect(e.nutrients.proteinG, closeTo(80, 1e-9));
    });

    test('the entry carries the recipe provenance and id', () async {
      await save(_chilli(p: DataProvenance.estimated));
      final e = await logPortions(1);
      expect(e.provenance, DataProvenance.estimated);
      expect(e.recipeId, 'r1');
      expect(e.foodId, isNull);
      expect(e.meal, MealSlot.dinner);
      expect(e.day, '2026-11-04');
    });

    test('the count is rounded to 0.1 and the snapshot follows the rounded '
        'count', () async {
      final e = await logPortions(1.26);
      expect(e.quantity.amount, 1.3);
      expect(e.nutrients.kcal, closeTo(520, 1e-9));
    });

    test('an entry can be edited like any other: portions rescale the '
        'snapshot', () async {
      final e = await logPortions(1);
      final updated = await UpdateFoodLogEntry(log: log, clock: clock)(
        e,
        amount: 2,
      );
      final entry = (updated as Ok<FoodLogEntry>).value;
      expect(entry.quantity.label, '2 portions');
      expect(entry.nutrients.kcal, closeTo(800, 1e-9));
    });
  });

  group('LogRecipe by weight (RCP-012, spec 9.5)', () {
    test('E32: 450 g of a 1200 g recipe of 4 portions logs 450 kcal', () async {
      await save(
        _chilli(grams: 1200).copyWith(portions: 4, portionWeightG: 300),
      );
      final e = ((await logRecipe(
        recipeId: 'r1',
        meal: MealSlot.lunch,
        day: '2026-11-04',
        grams: 450,
      )) as Ok<FoodLogEntry>).value;
      expect(e.nutrients.kcal, closeTo(450, 1e-9));
      expect(e.quantity, Quantity.fromStored(450, ReferenceUnit.grams));
      expect(e.name, 'Chilli con carne');
      expect(e.recipeId, 'r1');
    });

    test('a recipe with no known weight cannot be logged by weight', () async {
      await save(
        _chilli().copyWith(
          ingredients: [
            _ing('i1', 800).copyWith(
              quantity: Quantity.fromStored(800, ReferenceUnit.millilitres),
              per100: const NutrientProfile(
                per100: ReferenceUnit.millilitres,
                per100Amounts: NutrientAmounts(kcal: 50),
                provenance: DataProvenance.verified,
              ),
            ),
          ],
        ),
      );
      final r = await logRecipe(
        recipeId: 'r1',
        meal: MealSlot.lunch,
        day: '2026-11-04',
        grams: 100,
      );
      expect((r as Err).error, isA<ValidationError>());
      // By portions still works for the same recipe.
      expect((await logPortions(1)).nutrients.kcal, closeTo(200, 1e-9));
    });
  });

  group('LogRecipe validation', () {
    setUp(() async {
      await save(_chilli());
    });

    test('exactly one of portions and grams', () async {
      for (final r in [
        await logRecipe(recipeId: 'r1', meal: MealSlot.lunch, day: 'd'),
        await logRecipe(
          recipeId: 'r1',
          meal: MealSlot.lunch,
          day: 'd',
          portions: 1,
          grams: 1,
        ),
      ]) {
        expect((r as Err).error, isA<ValidationError>());
      }
    });

    test('zero, negative and rounds-to-zero amounts are rejected', () async {
      for (final n in [0.0, -1.0, 0.04]) {
        final r = await logRecipe(
          recipeId: 'r1',
          meal: MealSlot.lunch,
          day: 'd',
          portions: n,
        );
        expect((r as Err).error, isA<ValidationError>(), reason: '$n');
      }
      expect(await entries(), isEmpty);
    });

    test('a missing or deleted recipe is NotFound; a recipe without '
        'nutrition cannot be logged', () async {
      final missing = await logRecipe(
        recipeId: 'nope',
        meal: MealSlot.lunch,
        day: 'd',
        portions: 1,
      );
      expect((missing as Err).error, isA<NotFoundError>());
      await recipes.upsert(
        _chilli().copyWith(id: 'bare', ingredients: const []),
      );
      final bare = await logRecipe(
        recipeId: 'bare',
        meal: MealSlot.lunch,
        day: 'd',
        portions: 1,
      );
      expect((bare as Err).error, isA<ValidationError>());
    });
  });

  group('Editing a recipe after logging (RCP-013)', () {
    test('RCP-013(1) earlier entries keep 400 kcal after the recipe changes '
        'to 450', () async {
      await save(_chilli());
      final before = await logPortions(1);
      expect(before.nutrients.kcal, closeTo(400, 1e-9));

      // 900 g in 2 portions = 450 kcal per portion.
      await save(_chilli(grams: 900));
      expect((await recipes.byId('r1'))!.perPortion!.kcal, closeTo(450, 1e-9));

      final stored = (await entries()).single;
      expect(stored.nutrients.kcal, closeTo(400, 1e-9));
      expect(stored, before);

      // A new entry uses the new value.
      final after = await logPortions(1);
      expect(after.nutrients.kcal, closeTo(450, 1e-9));
      expect(
        (await entries()).map((e) => e.nutrients.kcal),
        containsAll([400.0, 450.0]),
      );
    });

    test('RCP-013(2) entries keep the link to the recipe, also after the '
        'recipe is deleted', () async {
      await save(_chilli());
      final e = await logPortions(1);
      expect(e.recipeId, 'r1');
      await recipes.delete('r1');
      final stored = (await entries()).single;
      expect(stored.recipeId, 'r1');
      expect(stored.nutrients.kcal, closeTo(400, 1e-9));
    });
  });
}
