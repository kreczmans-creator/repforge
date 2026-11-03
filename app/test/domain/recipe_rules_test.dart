import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';

final _t = DateTime.utc(2026, 11);

NutrientProfile _profile(
  DataProvenance p, {
  ReferenceUnit u = ReferenceUnit.grams,
}) => NutrientProfile(
  per100: u,
  per100Amounts: const NutrientAmounts(
    kcal: 100,
    proteinG: 20,
    carbsG: 10,
    fatG: 5,
  ),
  provenance: p,
);

RecipeIngredient _ing(
  String id,
  double grams, {
  NutrientProfile? per100,
  ReferenceUnit unit = ReferenceUnit.grams,
}) => RecipeIngredient(
  id: id,
  name: id,
  quantity: Quantity.fromStored(grams, unit),
  sortOrder: 0,
  per100: per100,
);

Recipe _recipe(
  List<RecipeIngredient> ings, {
  int portions = 2,
  NutrientAmounts? declared,
}) => Recipe(
  id: 'r',
  name: 'R',
  category: 'c',
  portions: portions,
  ingredients: ings,
  methodSteps: const [],
  declaredPerPortion: declared,
  createdAt: _t,
  updatedAt: _t,
);

const _declared = NutrientAmounts(
  kcal: 400,
  proteinG: 30,
  carbsG: 20,
  fatG: 10,
);

void main() {
  group('RecipeIngredient.nutrients', () {
    test('null without per100 or with mismatched unit', () {
      expect(_ing('a', 100).nutrients, isNull);
      expect(
        _ing(
          'a',
          100,
          per100: _profile(
            DataProvenance.verified,
            u: ReferenceUnit.millilitres,
          ),
        ).nutrients,
        isNull,
      );
    });

    test('scales per100 by quantity', () {
      final n = _ing(
        'a',
        250,
        per100: _profile(DataProvenance.verified),
      ).nutrients!;
      expect(n.kcal, 250);
      expect(n.proteinG, 50);
    });
  });

  group('Recipe.perPortion', () {
    test('computed from ingredients when all calculable', () {
      final r = _recipe([
        _ing('a', 200, per100: _profile(DataProvenance.verified)),
        _ing('b', 100, per100: _profile(DataProvenance.verified)),
      ], declared: _declared);
      expect(r.nutritionSource, RecipeNutritionSource.computed);
      final p = r.perPortion!;
      expect(p.kcal, closeTo(150, 1e-9));
      expect(p.proteinG, closeTo(30, 1e-9));
    });

    test('falls back to declared when an ingredient is not calculable', () {
      final r = _recipe([
        _ing('a', 200, per100: _profile(DataProvenance.verified)),
        _ing('b', 100),
      ], declared: _declared);
      expect(r.nutritionSource, RecipeNutritionSource.declared);
      expect(r.perPortion, _declared);
    });

    test('no ingredients uses declared; null when none declared', () {
      expect(_recipe(const [], declared: _declared).perPortion, _declared);
      expect(_recipe(const []).perPortion, isNull);
    });

    test('zero portions yields null', () {
      final r = _recipe([
        _ing('a', 100, per100: _profile(DataProvenance.verified)),
      ], portions: 0);
      expect(r.perPortion, isNull);
    });
  });

  group('Recipe.provenance', () {
    test('verified when every ingredient is verified', () {
      final r = _recipe([
        _ing('a', 100, per100: _profile(DataProvenance.verified)),
      ]);
      expect(r.provenance, DataProvenance.verified);
    });

    test('userEntered when computed with a user-entered ingredient', () {
      final r = _recipe([
        _ing('a', 100, per100: _profile(DataProvenance.verified)),
        _ing('b', 100, per100: _profile(DataProvenance.userEntered)),
      ]);
      expect(r.provenance, DataProvenance.userEntered);
    });

    test('estimated when any calculable ingredient is estimated', () {
      final r = _recipe([
        _ing('a', 100, per100: _profile(DataProvenance.userEntered)),
        _ing('b', 100, per100: _profile(DataProvenance.estimated)),
      ]);
      expect(r.provenance, DataProvenance.estimated);
    });

    test('estimated when not all calculable', () {
      final r = _recipe([
        _ing('a', 100, per100: _profile(DataProvenance.verified)),
        _ing('b', 100),
      ]);
      expect(r.provenance, DataProvenance.estimated);
      expect(_recipe(const []).provenance, DataProvenance.estimated);
    });
  });

  group('Recipe.forPortions', () {
    test('scales per-portion nutrition', () {
      final r = _recipe(const [], declared: _declared);
      final n = r.forPortions(2.5)!;
      expect(n.kcal, 1000);
      expect(n.proteinG, 75);
      expect(n.fibreG, isNull);
    });

    test('null when no nutrition available', () {
      expect(_recipe(const []).forPortions(2), isNull);
    });
  });
}
