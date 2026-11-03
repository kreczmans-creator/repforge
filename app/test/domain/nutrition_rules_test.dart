import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';

const _per100 = NutrientProfile(
  per100: ReferenceUnit.grams,
  per100Amounts: NutrientAmounts(kcal: 120, proteinG: 20, carbsG: 0, fatG: 4),
  provenance: DataProvenance.verified,
);

void main() {
  group('NutrientProfile.forQuantity', () {
    test('150 g of 20 g protein per 100 g is 30 g', () {
      final r = _per100.forQuantity(
        Quantity.fromStored(150, ReferenceUnit.grams),
      );
      final v = (r as Ok<NutrientAmounts>).value;
      expect(v.proteinG, closeTo(30, 1e-9));
      expect(v.kcal, closeTo(180, 1e-9));
      expect(v.fibreG, isNull);
    });

    test('wrong unit is a ValidationError', () {
      final r = _per100.forQuantity(
        Quantity.fromStored(150, ReferenceUnit.millilitres),
      );
      expect(r, isA<Err<NutrientAmounts>>());
      expect((r as Err<NutrientAmounts>).error, isA<ValidationError>());
    });
  });

  group('NutrientAmounts', () {
    test('sum of empty is zero', () {
      expect(NutrientAmounts.sum(const []), NutrientAmounts.zero);
    });

    test('adds fields; fibre null only when both null', () {
      const a = NutrientAmounts(kcal: 1, proteinG: 2, carbsG: 3, fatG: 4);
      const b = NutrientAmounts(
        kcal: 10,
        proteinG: 20,
        carbsG: 30,
        fatG: 40,
        fibreG: 5,
      );
      expect((a + a).fibreG, isNull);
      final s = a + b;
      expect(s.kcal, 11);
      expect(s.fatG, 44);
      expect(s.fibreG, 5);
      expect(NutrientAmounts.sum([a, b, b]).fibreG, 10);
    });

    test('scaled keeps null fibre and scales the rest', () {
      const a = NutrientAmounts(kcal: 10, proteinG: 2, carbsG: 4, fatG: 6);
      final s = a.scaled(0.5);
      expect(s.kcal, 5);
      expect(s.carbsG, 2);
      expect(s.fibreG, isNull);
      expect(
        const NutrientAmounts(
          kcal: 1,
          proteinG: 1,
          carbsG: 1,
          fatG: 1,
          fibreG: 3,
        ).scaled(2).fibreG,
        6,
      );
    });
  });

  group('validateNutrientsPer100', () {
    Result<NutrientAmounts> v({
      double kcal = 100,
      double p = 10,
      double c = 10,
      double f = 10,
      double? fibre,
    }) => validateNutrientsPer100(
      kcal: kcal,
      proteinG: p,
      carbsG: c,
      fatG: f,
      fibreG: fibre,
    );

    String? field(Result<NutrientAmounts> r) =>
        r is Err<NutrientAmounts> ? (r.error as ValidationError).field : null;

    test('accepts valid values including boundaries', () {
      expect(v().isOk, isTrue);
      expect(v(kcal: 900, p: 100, c: 100, f: 100, fibre: 100).isOk, isTrue);
      expect(v(kcal: 0, p: 0, c: 0, f: 0).isOk, isTrue);
    });

    test('rejects negatives', () {
      expect(field(v(kcal: -1)), 'kcal');
      expect(field(v(p: -0.1)), 'proteinG');
      expect(field(v(fibre: -1)), 'fibreG');
    });

    test('rejects NaN', () {
      expect(v(c: double.nan).isErr, isTrue);
    });

    test('rejects more than 100 g of a macro', () {
      expect(field(v(p: 100.1)), 'proteinG');
      expect(field(v(c: 101)), 'carbsG');
      expect(field(v(f: 101)), 'fatG');
      expect(field(v(fibre: 101)), 'fibreG');
    });

    test('rejects more than 900 kcal', () {
      expect(field(v(kcal: 900.1)), 'kcal');
    });
  });

  group('dayKey', () {
    test('zero-pads month and day', () {
      expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(dayKey(DateTime(2026, 11, 30)), '2026-11-30');
      expect(dayKey(DateTime(987, 3, 9)), '0987-03-09');
    });
  });
}
