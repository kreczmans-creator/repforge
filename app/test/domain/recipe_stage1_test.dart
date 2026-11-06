import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';

final _t = DateTime.utc(2026, 11);

// Chicken: 120 kcal, P 20, C 0, F 2 per 100 g (fibre unknown).
const _chicken = NutrientProfile(
  per100: ReferenceUnit.grams,
  per100Amounts: NutrientAmounts(kcal: 120, proteinG: 20, carbsG: 0, fatG: 2),
  provenance: DataProvenance.verified,
);
// Oats: 380 kcal, P 13, C 60, F 7, fibre 10 per 100 g.
const _oats = NutrientProfile(
  per100: ReferenceUnit.grams,
  per100Amounts: NutrientAmounts(
    kcal: 380,
    proteinG: 13,
    carbsG: 60,
    fatG: 7,
    fibreG: 10,
  ),
  provenance: DataProvenance.estimated,
);
// Turkey: 100 kcal, P 24 per 100 g.
const _turkey = NutrientProfile(
  per100: ReferenceUnit.grams,
  per100Amounts: NutrientAmounts(kcal: 100, proteinG: 24),
  provenance: DataProvenance.userEntered,
);

Quantity _g(double v) => Quantity.fromStored(v, ReferenceUnit.grams);

RecipeIngredient _ing(
  String id,
  NutrientProfile p,
  double grams, {
  List<RecipeSubstitute> subs = const [],
  String? foodId = 'food',
}) => RecipeIngredient(
  id: id,
  name: id,
  foodId: foodId,
  quantity: _g(grams),
  sortOrder: 0,
  per100: p,
  substitutes: subs,
);

Recipe _recipe({
  List<RecipeIngredient>? ingredients,
  double portions = 4,
  String name = 'Chilli',
  NutrientAmounts? declared,
  List<String> notes = const [],
  double? totalWeightG,
  double? portionWeightG,
  int? prep,
  int? cook,
}) => Recipe(
  id: 'r',
  name: name,
  category: 'dinner',
  portions: portions,
  ingredients: ingredients ?? [_ing('chicken', _chicken, 400)],
  declaredPerPortion: declared,
  ingredientNotes: notes,
  totalWeightG: totalWeightG,
  portionWeightG: portionWeightG,
  prepMinutes: prep,
  cookMinutes: cook,
  createdAt: _t,
  updatedAt: _t,
);

String? _errorField(Result<Recipe> r) => switch (r) {
  Err(:final error) => (error as ValidationError).field,
  Ok() => null,
};

void main() {
  group('validateRecipe (RCP-001, RCP-002, RCP-004, RCP-008)', () {
    test('a complete recipe is accepted unchanged', () {
      final r = _recipe(prep: 0, cook: 1440);
      expect((validateRecipe(r) as Ok<Recipe>).value, r);
    });

    test('RCP-001(1) a name is required', () {
      expect(_errorField(validateRecipe(_recipe(name: ''))), 'name');
      expect(_errorField(validateRecipe(_recipe(name: '   '))), 'name');
    });

    test('RCP-001(1) portions below 1 are rejected, 1 and 2.5 accepted', () {
      for (final p in [0.0, 0.5, -1.0, double.nan, double.infinity]) {
        expect(
          _errorField(validateRecipe(_recipe(portions: p))),
          'portions',
          reason: '$p',
        );
      }
      expect(validateRecipe(_recipe(portions: 1)).isOk, isTrue);
      expect(validateRecipe(_recipe(portions: 2.5)).isOk, isTrue);
    });

    test('RCP-001(1) at least one ingredient is required', () {
      expect(
        _errorField(validateRecipe(_recipe(ingredients: const []))),
        'ingredients',
      );
    });

    test('ingredient notes count only when the nutrition is declared '
        '(decision 4)', () {
      final notesOnly = _recipe(ingredients: const [], notes: ['2 eggs']);
      expect(_errorField(validateRecipe(notesOnly)), 'ingredients');
      final declared = notesOnly.copyWith(
        declaredPerPortion: const NutrientAmounts(kcal: 460),
      );
      expect(validateRecipe(declared).isOk, isTrue);
      // Blank notes do not count.
      expect(
        validateRecipe(declared.copyWith(ingredientNotes: [' '])).isOk,
        isFalse,
      );
    });

    test('RCP-002(2) an ingredient without a quantity is rejected', () {
      final zero = _recipe(ingredients: [_ing('chicken', _chicken, 0)]);
      expect(_errorField(validateRecipe(zero)), 'quantity');
    });

    test('RCP-002(2) a quantity in the other unit is rejected', () {
      final ml = _ing(
        'milk',
        _chicken,
        100,
      ).copyWith(quantity: Quantity.fromStored(100, ReferenceUnit.millilitres));
      expect(
        _errorField(validateRecipe(_recipe(ingredients: [ml]))),
        'quantity',
      );
      final portions = _ing('x', _chicken, 1).copyWith(
        quantity: Quantity.fromStored(1, ReferenceUnit.portions),
        per100: null,
      );
      expect(
        _errorField(validateRecipe(_recipe(ingredients: [portions]))),
        'quantity',
      );
    });

    test('RCP-002 an ingredient must reference a food (decision 4)', () {
      final unlinked = _ing('x', _chicken, 100, foodId: null);
      expect(
        _errorField(validateRecipe(_recipe(ingredients: [unlinked]))),
        'ingredients',
      );
    });

    test('RCP-002(1) a serving entry keeps the canonical grams', () {
      final bread = _ing(
        'bread',
        _chicken,
        70,
      ).copyWith(servingLabel: 'slice', servingCount: 2);
      expect(validateRecipe(_recipe(ingredients: [bread])).isOk, isTrue);
      expect(bread.quantity, _g(70));
      expect(
        _errorField(
          validateRecipe(
            _recipe(ingredients: [bread.copyWith(servingCount: 0)]),
          ),
        ),
        'quantity',
      );
    });

    test('RCP-004(1) minutes are 0-1440, optional', () {
      expect(validateRecipe(_recipe()).isOk, isTrue);
      expect(validateRecipe(_recipe(prep: 0, cook: 0)).isOk, isTrue);
      expect(validateRecipe(_recipe(prep: 1440)).isOk, isTrue);
      expect(_errorField(validateRecipe(_recipe(prep: 1441))), 'prepMinutes');
      expect(_errorField(validateRecipe(_recipe(prep: -1))), 'prepMinutes');
      expect(_errorField(validateRecipe(_recipe(cook: 1441))), 'cookMinutes');
      expect(_errorField(validateRecipe(_recipe(cook: -5))), 'cookMinutes');
    });

    test('RCP-004(2) total time is prep plus cook', () {
      expect(_recipe(prep: 15, cook: 45).totalMinutes, 60);
      expect(_recipe(prep: 15).totalMinutes, 15);
      expect(_recipe(cook: 30).totalMinutes, 30);
      expect(_recipe().totalMinutes, isNull);
    });

    test('RCP-008(2) total and portion weight must be above 0 when set', () {
      expect(
        _errorField(validateRecipe(_recipe(portionWeightG: 0))),
        'portionWeightG',
      );
      expect(
        _errorField(validateRecipe(_recipe(totalWeightG: -3))),
        'totalWeightG',
      );
      expect(
        validateRecipe(_recipe(totalWeightG: 900, portionWeightG: 300)).isOk,
        isTrue,
      );
    });

    test('substitutes need a name and a quantity in their own unit', () {
      RecipeSubstitute sub({String name = 'Turkey', Quantity? q}) =>
          RecipeSubstitute(name: name, quantity: q ?? _g(400), per100: _turkey);
      Recipe withSub(RecipeSubstitute s) => _recipe(
        ingredients: [
          _ing('chicken', _chicken, 400, subs: [s]),
        ],
      );
      expect(validateRecipe(withSub(sub())).isOk, isTrue);
      expect(_errorField(validateRecipe(withSub(sub(name: ' ')))), 'name');
      expect(_errorField(validateRecipe(withSub(sub(q: _g(0))))), 'quantity');
      expect(
        _errorField(
          validateRecipe(
            withSub(
              sub(q: Quantity.fromStored(100, ReferenceUnit.millilitres)),
            ),
          ),
        ),
        'quantity',
      );
    });
  });

  group('per portion (RCP-006, RCP-007)', () {
    test('RCP-006(1) 400 g chicken in 4 portions is 20 g protein', () {
      expect(_recipe().perPortion!.proteinG, closeTo(20, 1e-9));
      expect(_recipe().perPortion!.kcal, closeTo(120, 1e-9));
    });

    test('RCP-006(2) changing a quantity updates per-portion at once', () {
      final r = _recipe();
      final more = r.copyWith(ingredients: [_ing('chicken', _chicken, 600)]);
      expect(more.perPortion!.proteinG, closeTo(30, 1e-9));
      expect(more.perPortion!.kcal, closeTo(180, 1e-9));
    });

    test('RCP-007(1) one estimated ingredient labels the recipe estimated', () {
      final r = _recipe(
        ingredients: [_ing('chicken', _chicken, 100), _ing('oats', _oats, 100)],
      );
      expect(r.provenance, DataProvenance.estimated);
    });

    test('RCP-007(2) null fibre: snapshot unknown, view partial and '
        'incomplete', () {
      final r = _recipe(
        ingredients: [_ing('oats', _oats, 100), _ing('chicken', _chicken, 100)],
        portions: 2,
      );
      expect(r.perPortion!.fibreG, isNull);
      final view = r.perPortionTotals!;
      // Hand calculation: fibre 10 g from oats only, / 2 portions = 5 g.
      expect(view.known.fibreG, closeTo(5, 1e-9));
      expect(view.unknownFibreCount, 1);
      expect(view.isComplete, isFalse);
      // Protein: (13 + 20) / 2 = 16.5, known in both.
      expect(view.known.proteinG, closeTo(16.5, 1e-9));
      expect(view.unknownProteinCount, 0);
      expect(view.known.kcal, closeTo(250, 1e-9));
    });

    test('perPortionTotals is complete when every nutrient is known', () {
      final r = _recipe(ingredients: [_ing('oats', _oats, 200)], portions: 2);
      expect(r.perPortionTotals!.isComplete, isTrue);
      expect(r.perPortionTotals!.known.fibreG, closeTo(10, 1e-9));
    });

    test('perPortionTotals of a declared recipe counts the unknown fibre', () {
      final r = _recipe(
        ingredients: const [],
        notes: ['x'],
        declared: const NutrientAmounts(
          kcal: 460,
          proteinG: 43,
          carbsG: 48,
          fatG: 11,
        ),
      );
      final view = r.perPortionTotals!;
      expect(view.known.kcal, 460);
      expect(view.unknownFibreCount, 1);
      expect(view.unknownProteinCount, 0);
      expect(r.provenance, DataProvenance.estimated);
    });

    test('perPortionTotals is null without nutrition or portions', () {
      expect(_recipe(ingredients: const []).perPortionTotals, isNull);
      expect(_recipe(portions: 0).perPortionTotals, isNull);
    });
  });

  group('portions and weight (RCP-008)', () {
    test('RCP-008(1) 4 to 5 portions divides the total by 5', () {
      final five = _recipe(portions: 5);
      expect(five.perPortion!.proteinG, closeTo(16, 1e-9));
      expect(five.perPortion!.kcal, closeTo(96, 1e-9));
    });

    test('effective total weight: explicit, else sum when all in g', () {
      expect(_recipe().effectiveTotalWeightG, 400);
      expect(_recipe(totalWeightG: 350).effectiveTotalWeightG, 350);
      final mixed = _recipe(
        ingredients: [
          _ing('chicken', _chicken, 100),
          _ing('milk', _chicken, 200).copyWith(
            quantity: Quantity.fromStored(200, ReferenceUnit.millilitres),
          ),
        ],
      );
      expect(mixed.effectiveTotalWeightG, isNull);
      expect(mixed.copyWith(totalWeightG: 280).effectiveTotalWeightG, 280);
      expect(_recipe(ingredients: const []).effectiveTotalWeightG, isNull);
    });

    test('RCP-008(2) portions derive from weight, fractions kept', () {
      final r = _recipe(totalWeightG: 1000, portionWeightG: 300);
      expect(r.derivedPortions, closeTo(10 / 3, 1e-9));
      expect(_recipe(portionWeightG: 100).derivedPortions, 4); // W = 400
      expect(_recipe().derivedPortions, isNull);
      expect(portionsByWeight(1200, 300), 4);
      expect(portionsByWeight(1200, 0), isNull);
      expect(portionsByWeight(null, 300), isNull);
    });

    test('nutrition for weight uses total x grams / W', () {
      // Total protein 80 g, W 400 g: 100 g carries 20 g.
      final r = _recipe();
      expect(r.nutritionForWeight(100)!.proteinG, closeTo(20, 1e-9));
      expect(r.nutritionForWeight(100)!.kcal, closeTo(120, 1e-9));
      expect(r.portionsForWeight(100), closeTo(1, 1e-9));
      expect(_recipe(ingredients: const []).nutritionForWeight(100), isNull);
      expect(_recipe(ingredients: const []).portionsForWeight(100), isNull);
    });

    test('nutrition for weight keeps an incomplete nutrient unknown', () {
      final r = _recipe(
        ingredients: [_ing('oats', _oats, 100), _ing('chicken', _chicken, 100)],
        portions: 2,
      );
      final n = r.nutritionForWeight(100)!; // half of the 200 g total
      expect(n.kcal, closeTo(250, 1e-9));
      expect(n.fibreG, isNull);
    });

    test('nutrition for portions is per portion x n', () {
      expect(_recipe().nutritionForPortions(2.5)!.kcal, closeTo(300, 1e-9));
      expect(_recipe().forPortions(2)!.proteinG, closeTo(40, 1e-9));
    });
  });

  group('scaling (RCP-009)', () {
    test('RCP-009(1) 4 to 6 portions multiplies each quantity by 1.5', () {
      final r = _recipe(
        ingredients: [_ing('chicken', _chicken, 400), _ing('oats', _oats, 50)],
      );
      final scaled = (r.scaleToPortions(6) as Ok<Recipe>).value;
      expect(scaled.ingredients.map((i) => i.quantity.amount), [600, 75]);
      expect(scaled.portions, 6);
      expect(scaled.perPortion!.kcal, closeTo(r.perPortion!.kcal, 1e-9));
      expect(
        scaled.perPortion!.proteinG,
        closeTo(r.perPortion!.proteinG!, 1e-9),
      );
    });

    test('RCP-009(2) scaling does not change the original recipe', () {
      final r = _recipe();
      Recipe scaledCopy() => (r.scaleToPortions(6) as Ok<Recipe>).value;
      scaledCopy();
      expect(r.ingredients.single.quantity.amount, 400);
      expect(r.portions, 4);
      expect(identical(scaledCopy(), r), isFalse);
    });

    test('scale to weight: 400 g to 600 g is factor 1.5', () {
      final r = _recipe(totalWeightG: 400);
      final scaled = (r.scaleToWeight(600) as Ok<Recipe>).value;
      expect(scaled.ingredients.single.quantity.amount, 600);
      expect(scaled.portions, 6);
      expect(scaled.totalWeightG, 600);
      expect(scaled.perPortion!.proteinG, closeTo(20, 1e-9));
    });

    test('scaling also scales substitutes and serving counts', () {
      final r = _recipe(
        ingredients: [
          _ing(
            'chicken',
            _chicken,
            400,
            subs: [
              RecipeSubstitute(
                name: 'Turkey',
                quantity: _g(400),
                per100: _turkey,
              ),
            ],
          ).copyWith(servingLabel: 'fillet', servingCount: 2),
        ],
      );
      final scaled = (r.scaledBy(0.5) as Ok<Recipe>).value;
      final i = scaled.ingredients.single;
      expect(i.quantity.amount, 200);
      expect(i.servingCount, 1);
      expect(i.substitutes.single.quantity.amount, 200);
    });

    test('scaled views keep per-portion values exactly (spec 9.4)', () {
      // 333 g / 7 is not a multiple of 0.1, so rounding would change the
      // per-portion values.
      final r = _recipe(
        ingredients: [_ing('chicken', _chicken, 333)],
        portions: 3,
      );
      final scaled = (r.scaledBy(1 / 7) as Ok<Recipe>).value;
      expect(scaled.ingredients.single.quantity.amount, closeTo(333 / 7, 1e-9));
      expect(scaled.perPortion!.kcal, closeTo(r.perPortion!.kcal, 1e-9));
      expect(
        scaled.perPortion!.proteinG,
        closeTo(r.perPortion!.proteinG!, 1e-9),
      );
    });

    test('invalid targets are errors', () {
      final r = _recipe();
      expect(r.scaledBy(0).isErr, isTrue);
      expect(r.scaledBy(-1).isErr, isTrue);
      expect(r.scaledBy(double.nan).isErr, isTrue);
      expect(r.scaleToPortions(0).isErr, isTrue);
      expect(r.scaledBy(1000000000).isErr, isTrue); // quantity out of range
      expect(r.copyWith(portions: 0).scaleToPortions(2).isErr, isTrue);
      expect(_recipe(ingredients: const []).scaleToWeight(100).isErr, isTrue);
    });
  });

  group('substitutions (RCP-010)', () {
    final turkey = RecipeSubstitute(
      name: 'Turkey mince',
      foodId: 'turkey',
      quantity: _g(500),
      per100: _turkey,
    );
    Recipe base() => _recipe(
      ingredients: [
        _ing('chicken', _chicken, 400, subs: [turkey]),
        _ing('oats', _oats, 100),
      ],
      portions: 2,
    );

    test('RCP-010(1) an ingredient carries alternatives with quantities', () {
      final r = base();
      expect(r.ingredients.first.substitutes.single.quantity, _g(500));
      expect(r.ingredients.first.substitutes.single.nutrients!.kcal, 500);
    });

    test('RCP-010(2) selecting a substitute recalculates that view', () {
      final view = (base().withSubstitution('chicken', 0) as Ok<Recipe>).value;
      final i = view.ingredients.first;
      expect(
        [i.id, i.name, i.foodId, i.quantity],
        ['chicken', 'Turkey mince', 'turkey', _g(500)],
      );
      // Original: chicken 480 kcal + oats 380 = 860 / 2 = 430.
      // Substitute: turkey 500 + oats 380 = 880 / 2 = 440.
      expect(base().perPortion!.kcal, closeTo(430, 1e-9));
      expect(view.perPortion!.kcal, closeTo(440, 1e-9));
      expect(view.perPortion!.proteinG, closeTo((120 + 13) / 2, 1e-9));
      // The substitute is unknown for carbs, so the snapshot is unknown.
      expect(view.perPortion!.carbsG, isNull);
      expect(base().perPortion!.carbsG, isNotNull);
    });

    test('RCP-010(2) the kcal per portion difference against the original', () {
      expect(base().kcalPerPortionDelta('chicken', 0), closeTo(10, 1e-9));
      expect(base().kcalPerPortionDelta('chicken', 3), isNull);
      expect(base().kcalPerPortionDelta('nope', 0), isNull);
      expect(base().withSubstitution('nope', 0).isErr, isTrue);
      expect(base().withSubstitution('chicken', -1).isErr, isTrue);
    });

    test('a substitution is a view: the recipe is unchanged', () {
      final r = base()..withSubstitution('chicken', 0);
      expect(r.ingredients.first.name, 'chicken');
    });

    test('delta is null for a declared recipe', () {
      final r = _recipe(
        ingredients: [
          _ing('chicken', _chicken, 100, subs: [turkey]).copyWith(per100: null),
        ],
        declared: const NutrientAmounts(kcal: 300),
      );
      expect(r.kcalPerPortionDelta('chicken', 0), isNull);
    });
  });
}
