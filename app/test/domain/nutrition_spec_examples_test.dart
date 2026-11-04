// Executes the worked examples of docs/nutrition-calculation-spec.md §10
// (NUT-017). Test names carry the example ids. Expected values are copied
// from the specification table and must not be edited to fit the code.
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/external/open_food_facts_mapper.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/summaries.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/log_food.dart';

final _now = DateTime.utc(2026, 11, 4, 12);

Food _food(
  String id,
  String name,
  ReferenceUnit unit,
  NutrientAmounts amounts,
  DataProvenance provenance, {
  List<ServingSize> servings = const [],
}) => Food(
  id: id,
  name: name,
  profile: NutrientProfile(
    per100: unit,
    per100Amounts: amounts,
    provenance: provenance,
  ),
  source: FoodSource.userCreated,
  createdAt: _now,
  updatedAt: _now,
  servings: servings,
);

Quantity _q(double amount, ReferenceUnit unit) =>
    (Quantity.of(amount, unit) as Ok<Quantity>).value;

// Reference foods exactly as stated in specification §10.
final Food oats = _food(
  'oats',
  'Oats',
  ReferenceUnit.grams,
  const NutrientAmounts(
    kcal: 380,
    proteinG: 13,
    carbsG: 60,
    fatG: 7,
    fibreG: 10,
  ),
  DataProvenance.verified,
);
final Food milk = _food(
  'milk',
  'Milk',
  ReferenceUnit.millilitres,
  const NutrientAmounts(kcal: 64, proteinG: 3.4, carbsG: 4.8, fatG: 3.6),
  DataProvenance.crowdsourced,
);
final Food bread = _food(
  'bread',
  'Bread',
  ReferenceUnit.grams,
  const NutrientAmounts(kcal: 250, proteinG: 9, carbsG: 45, fatG: 3, fibreG: 6),
  DataProvenance.userEntered,
  servings: [
    ServingSize(label: '1 slice', quantity: _q(35, ReferenceUnit.grams)),
  ],
);
final Food chicken = _food(
  'chicken',
  'Chicken',
  ReferenceUnit.grams,
  const NutrientAmounts(kcal: 120, proteinG: 20, carbsG: 0, fatG: 2),
  DataProvenance.verified,
);

NutrientAmounts _for(Food f, double amount) {
  final r = f.profile.forQuantity(_q(amount, f.profile.per100));
  return (r as Ok<NutrientAmounts>).value;
}

RecipeIngredient _ing(String id, Food f, double amount) => RecipeIngredient(
  id: id,
  name: f.name,
  foodId: f.id,
  quantity: _q(amount, f.profile.per100),
  sortOrder: 0,
  per100: f.profile,
);

Recipe _recipe({
  required List<RecipeIngredient> ingredients,
  required double portions,
  NutrientAmounts? declared,
  List<String> notes = const [],
}) => Recipe(
  id: 'r',
  name: 'Recipe',
  category: 'dinner',
  portions: portions,
  ingredients: ingredients,
  createdAt: _now,
  updatedAt: _now,
  declaredPerPortion: declared,
  ingredientNotes: notes,
);

FoodLogEntry _entry(
  NutrientAmounts n, {
  String day = '2026-11-04',
  String id = 'e',
}) => FoodLogEntry(
  id: id,
  day: day,
  meal: MealSlot.lunch,
  name: 'x',
  quantity: _q(100, ReferenceUnit.grams),
  nutrients: n,
  provenance: DataProvenance.userEntered,
  loggedAt: _now,
  createdAt: _now,
  updatedAt: _now,
);

DailySummary _day(List<NutrientAmounts> items) => DailySummary.fromEntries(
  day: '2026-11-04',
  entries: [for (var i = 0; i < items.length; i++) _entry(items[i], id: 'e$i')],
  targets: DailyTargets.none,
);

Map<String, dynamic> _offProduct(Map<String, dynamic> nutriments) => {
  'code': '1234567890123',
  'product_name': 'Test product',
  'nutriments': nutriments,
};

void expectAmounts(
  NutrientAmounts a, {
  required double kcal,
  double? p,
  double? c,
  double? f,
  double? fibre,
}) {
  expect(a.kcal, closeTo(kcal, 1e-9));
  for (final (actual, expected, label) in [
    (a.proteinG, p, 'protein'),
    (a.carbsG, c, 'carbs'),
    (a.fatG, f, 'fat'),
    (a.fibreG, fibre, 'fibre'),
  ]) {
    if (expected == null) {
      expect(actual, isNull, reason: '$label should be unknown');
    } else {
      expect(actual, isNotNull, reason: '$label should be known');
      expect(actual, closeTo(expected, 1e-9), reason: label);
    }
  }
}

void main() {
  group('NUT-017 worked examples', () {
    test('E01 150 g of oats scales every nutrient from per-100', () {
      expectAmounts(
        _for(oats, 150),
        kcal: 570,
        p: 19.5,
        c: 90,
        f: 10.5,
        fibre: 15,
      );
    });

    test('E02 250 ml of milk scales and keeps fibre unknown', () {
      expectAmounts(_for(milk, 250), kcal: 160, p: 8.5, c: 12, f: 9);
    });

    test('E03 100 ml of oats is a validation error', () {
      final r = oats.profile.forQuantity(_q(100, ReferenceUnit.millilitres));
      expect(r, isA<Err<NutrientAmounts>>());
      expect((r as Err<NutrientAmounts>).error, isA<ValidationError>());
    });

    group('with an in-memory database', () {
      late AppDatabase db;
      setUp(() => db = AppDatabase.inMemory());
      tearDown(() => db.close());

      test('E04 logging 0 g of oats is a validation error', () async {
        final clock = FixedClock(_now);
        final logFood = LogFood(
          foods: DriftFoodRepository(db, clock: clock),
          log: DriftFoodLogRepository(db, clock: clock),
          clock: clock,
          newId: () => 'e1',
        );
        final r = await logFood(
          food: oats,
          amount: 0,
          meal: MealSlot.breakfast,
          day: '2026-11-04',
        );
        expect(r, isA<Err<FoodLogEntry>>());
        final error = (r as Err<FoodLogEntry>).error;
        expect(error, isA<ValidationError>());
        expect(error.message, 'Enter an amount greater than zero.');
      });
    });

    test('E05 12.36 g entered is stored as 12.4 g', () {
      expect(_q(12.36, ReferenceUnit.grams).amount, 12.4);
    });

    test('E06 2 slices of bread are 70 g and 175 kcal', () {
      final grams = bread.servings.single.quantityFor(2).amount;
      expect(grams, 70);
      expectAmounts(
        _for(bread, grams),
        kcal: 175,
        p: 6.3,
        c: 31.5,
        f: 2.1,
        fibre: 4.2,
      );
    });

    test('E07 1.5 slices of bread store 131.25 kcal and display 131', () {
      final grams = bread.servings.single.quantityFor(1.5).amount;
      expect(grams, 52.5);
      final n = _for(bread, grams);
      expect(n.kcal, closeTo(131.25, 1e-9));
      expect(whole(n.kcal), '131');
    });

    test('E08 50 g of chicken halves per-100 and keeps fibre unknown', () {
      expectAmounts(_for(chicken, 50), kcal: 60, p: 10, c: 0, f: 1);
    });

    test('E09 a day of 200, 350 and 125 kcal totals 675 kcal', () {
      final s = _day([
        for (final k in [200.0, 350.0, 125.0]) NutrientAmounts(kcal: k),
      ]);
      expect(s.intake.kcal, closeTo(675, 1e-9));
    });

    test('E10 day protein 20, unknown, 11 is a known 31 g and 1 unknown', () {
      final s = _day(const [
        NutrientAmounts(kcal: 100, proteinG: 20),
        NutrientAmounts(kcal: 100),
        NutrientAmounts(kcal: 100, proteinG: 11),
      ]);
      expect(s.intake.proteinG, closeTo(31, 1e-9));
      expect(s.totals.unknownProteinCount, 1);
    });

    test('E11 a day whose entries all lack fibre has unknown fibre', () {
      final s = _day(const [
        NutrientAmounts(kcal: 100, proteinG: 1),
        NutrientAmounts(kcal: 200, proteinG: 2),
      ]);
      expect(s.intake.fibreG, isNull);
      expect(s.totals.unknownFibreCount, 2);
    });

    test('E12 an empty day is a known zero for every nutrient', () {
      final s = _day(const []);
      expectAmounts(s.intake, kcal: 0, p: 0, c: 0, f: 0, fibre: 0);
      expect(s.totals.unknownFibreCount, 0);
    });

    test('E13 energy stated only as 1674 kJ becomes 400.0956 kcal', () {
      final food = mapOffProduct(
        _offProduct({'energy-kj_100g': 1674}),
        now: _now,
      );
      expect(food, isNotNull);
      final kcal = food!.profile.per100Amounts.kcal;
      expect(kcal, closeTo(1674 / 4.184, 1e-9));
      expect(kcal, closeTo(400.0956, 1e-4));
      expect(whole(kcal), '400');
    });

    test('E14 100 kcal and 1000 kJ stated uses the stated kcal', () {
      final food = mapOffProduct(
        _offProduct({'energy-kcal_100g': 100, 'energy-kj_100g': 1000}),
        now: _now,
      );
      expect(food!.profile.per100Amounts.kcal, closeTo(100, 1e-9));
    });

    test('E15 stated 100 kcal with P, C, F 10 g is not recomputed', () {
      final food = mapOffProduct(
        _offProduct({
          'energy-kcal_100g': 100,
          'proteins_100g': 10,
          'carbohydrates_100g': 10,
          'fat_100g': 10,
        }),
        now: _now,
      );
      expect(food!.profile.per100Amounts.kcal, closeTo(100, 1e-9));
    });

    test('E16 50 g of a food with C 60 and fibre 8 gives C 30, fibre 4', () {
      final f = _food(
        'e16',
        'E16',
        ReferenceUnit.grams,
        const NutrientAmounts(kcal: 300, carbsG: 60, fibreG: 8),
        DataProvenance.userEntered,
      );
      final n = _for(f, 50);
      expect(n.carbsG, closeTo(30, 1e-9));
      expect(n.fibreG, closeTo(4, 1e-9));
    });

    test('E17 protein 101 g per 100 is a validation error', () {
      expect(
        validateNutrientsPer100(kcal: 100, proteinG: 101),
        isA<Err<NutrientAmounts>>(),
      );
    });

    test('E18 energy 901 kcal per 100 is a validation error', () {
      expect(validateNutrientsPer100(kcal: 901), isA<Err<NutrientAmounts>>());
    });

    test('E19 fat of -1 is a validation error', () {
      expect(
        validateNutrientsPer100(kcal: 100, fatG: -1),
        isA<Err<NutrientAmounts>>(),
      );
    });

    test('E20 blank macros with energy 300 are accepted as unknown', () {
      final r = validateNutrientsPer100(kcal: 300);
      expect(r, isA<Ok<NutrientAmounts>>());
      expectAmounts((r as Ok<NutrientAmounts>).value, kcal: 300);
    });

    test('E21 an explicit protein of 0 is a known zero', () {
      final r = validateNutrientsPer100(kcal: 100, proteinG: 0);
      final v = (r as Ok<NutrientAmounts>).value;
      expect(v.proteinG, 0);
      expect(v.proteinG, isNotNull);
    });

    test('E22 verified plus estimated is estimated', () {
      expect(
        weakestProvenance([DataProvenance.verified, DataProvenance.estimated]),
        DataProvenance.estimated,
      );
    });

    test('E23 verified plus crowdsourced is crowdsourced', () {
      expect(
        weakestProvenance([
          DataProvenance.verified,
          DataProvenance.crowdsourced,
        ]),
        DataProvenance.crowdsourced,
      );
    });

    test('E24 crowdsourced plus user-entered is user-entered', () {
      expect(
        weakestProvenance([
          DataProvenance.crowdsourced,
          DataProvenance.userEntered,
        ]),
        DataProvenance.userEntered,
      );
    });

    test('E25 all verified stays verified', () {
      expect(
        weakestProvenance([DataProvenance.verified, DataProvenance.verified]),
        DataProvenance.verified,
      );
    });

    test('E26 400 g of chicken in 4 portions gives P 20 g per portion', () {
      final r = _recipe(ingredients: [_ing('i1', chicken, 400)], portions: 4);
      expect(r.perPortion!.proteinG, closeTo(20, 1e-9));
    });

    test('E27 the same recipe in 5 portions gives P 16 g per portion', () {
      final r = _recipe(ingredients: [_ing('i1', chicken, 400)], portions: 5);
      expect(r.perPortion!.proteinG, closeTo(16, 1e-9));
    });

    test('E28 unknown fibre makes the snapshot null; partial view is 5 g', () {
      final r = _recipe(
        ingredients: [_ing('i1', oats, 100), _ing('i2', chicken, 100)],
        portions: 2,
      );
      final pp = r.perPortion!;
      expect(pp.kcal, closeTo(250, 1e-9));
      expect(pp.proteinG, closeTo(16.5, 1e-9));
      expect(pp.fibreG, isNull);

      // The recipe view shows the partial sum, labelled incomplete.
      final view = r.perPortionTotals!;
      expect(view.known.fibreG, closeTo(5, 1e-9));
      expect(view.unknownFibreCount, 1);
      expect(view.known.proteinG, closeTo(16.5, 1e-9));
      expect(view.unknownProteinCount, 0);
    });

    test('E29 an unlinked ingredient falls back to declared 460 kcal', () {
      const declared = NutrientAmounts(kcal: 460);
      final r = _recipe(
        ingredients: [
          _ing('i1', oats, 100),
          RecipeIngredient(
            id: 'i2',
            name: 'Pinch of something',
            quantity: _q(5, ReferenceUnit.grams),
            sortOrder: 1,
          ),
        ],
        portions: 2,
        declared: declared,
      );
      expect(r.nutritionSource, RecipeNutritionSource.declared);
      expect(r.perPortion!.kcal, closeTo(460, 1e-9));
      expect(r.provenance, DataProvenance.estimated);
    });

    test('E30 1.5 portions at 400 kcal per portion is 600 kcal', () {
      // Computed recipe whose per-portion energy is 400 kcal: 100 g of a
      // 400 kcal food in one portion.
      final f = _food(
        'e30',
        'E30',
        ReferenceUnit.grams,
        const NutrientAmounts(kcal: 400),
        DataProvenance.userEntered,
      );
      final computed = _recipe(ingredients: [_ing('i1', f, 100)], portions: 1);
      expect(computed.perPortion!.kcal, closeTo(400, 1e-9));
      expect(computed.forPortions(1.5)!.kcal, closeTo(600, 1e-9));
    });

    test('E31 scaling 4 to 6 portions gives chicken 600 g, per portion '
        'unchanged', () {
      final r = _recipe(ingredients: [_ing('i1', chicken, 400)], portions: 4);
      final scaled = (r.scaleToPortions(6) as Ok<Recipe>).value;
      expect(scaled.ingredients.single.quantity.amount, 600);
      expect(scaled.portions, 6);
      expect(scaled.perPortion!.proteinG, closeTo(20, 1e-9));
      expect(scaled.perPortion!.kcal, closeTo(r.perPortion!.kcal, 1e-9));
      // A view only: the original recipe is untouched.
      expect(r.ingredients.single.quantity.amount, 400);
      expect(r.portions, 4);
    });

    test('E32 recipe total 1200 g and portion 300 g is 4 portions; 450 g logs '
        '450 kcal', () {
      // 1200 g of a 100 kcal per 100 g food: total 1200 kcal, W = 1200 g.
      final f = _food(
        'e32',
        'E32',
        ReferenceUnit.grams,
        const NutrientAmounts(kcal: 100),
        DataProvenance.userEntered,
      );
      final base = _recipe(ingredients: [_ing('i1', f, 1200)], portions: 1);
      expect(base.effectiveTotalWeightG, 1200);
      final r = base.copyWith(
        portionWeightG: 300,
        portions: portionsByWeight(1200, 300)!,
      );
      expect(r.portions, 4);
      expect(r.derivedPortions, 4);
      expect(r.nutritionForWeight(450)!.kcal, closeTo(450, 1e-9));
      // 450 g is 450 / 300 = 1.5 portions, and the same energy.
      expect(r.portionsForWeight(450), closeTo(1.5, 1e-9));
      expect(r.nutritionForPortions(1.5)!.kcal, closeTo(450, 1e-9));
    });

    test('E33 week of 1000 kcal P 90 and 2000 kcal P unknown averages', () {
      final w = WeeklySummary.fromEntries(
        days: lastSevenDays(DateTime(2026, 11, 4)),
        entries: [
          _entry(
            const NutrientAmounts(kcal: 1000, proteinG: 90),
            day: '2026-11-03',
            id: 'a',
          ),
          _entry(const NutrientAmounts(kcal: 2000), id: 'b'),
        ],
      );
      final avg = w.averagePerLoggedDay!;
      expect(avg.kcal, closeTo(1500, 1e-9));
      expect(avg.proteinG, closeTo(90, 1e-9));
      expect(w.unknownDays(Nutrient.proteinG), 1);
    });

    test('E34 two logged days of seven average 2000 kcal', () {
      final w = WeeklySummary.fromEntries(
        days: lastSevenDays(DateTime(2026, 11, 4)),
        entries: [
          _entry(const NutrientAmounts(kcal: 1800), day: '2026-11-01', id: 'a'),
          _entry(const NutrientAmounts(kcal: 2200), id: 'b'),
        ],
      );
      expect(w.loggedDays, 2);
      expect(w.averagePerLoggedDay!.kcal, closeTo(2000, 1e-9));
    });

    test('E35 100 lb converts to 45.359237 kg for display', () {
      // GAP: no kg->g or l->ml conversion function exists in lib yet, so
      // 1 kg = 1000 g and 1 l = 1000 ml (spec §2.3) cannot be exercised
      // against real code; only the imperial display conversion is.
      expect(UnitConversion.lbToKg(100), closeTo(45.359237, 0.001));
    });

    test('E36 display rounding: 19.5, 2.25 and 131.25', () {
      expect(whole(19.5), '20');
      expect(formatNumber(2.25), '2.3');
      expect(formatNumber(131.25), '131.3');
    });

    test('E37 oats (verified) plus milk (crowdsourced) is crowdsourced', () {
      final r = _recipe(
        ingredients: [_ing('i1', oats, 100), _ing('i2', milk, 250)],
        portions: 2,
      );
      expect(r.provenance, DataProvenance.crowdsourced);
    });

    test(
      'E38 ingredient notes keep a linked recipe on its declared values',
      () {
        final r = _recipe(
          ingredients: [_ing('i1', oats, 100)],
          portions: 4,
          declared: const NutrientAmounts(kcal: 460),
          notes: const ['1 kg chicken breast', '8 tortillas', '2 tsp cumin'],
        );
        expect(r.nutritionSource, RecipeNutritionSource.declared);
        expect(r.perPortion!.kcal, closeTo(460, 1e-9));
        expect(r.provenance, DataProvenance.estimated);
      },
    );
  });
}
