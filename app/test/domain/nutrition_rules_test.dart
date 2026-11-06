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

  group('unknown nutrients', () {
    const known = NutrientAmounts(kcal: 100, proteinG: 10, carbsG: 20, fatG: 5);
    const unknown = NutrientAmounts(kcal: 50);

    test('scaling keeps unknown values unknown', () {
      final s = unknown.scaled(2);
      expect(s.kcal, 100);
      expect(s.proteinG, isNull);
      expect(s.carbsG, isNull);
      expect(s.fatG, isNull);
      expect(s.fibreG, isNull);
    });

    test('adding sums the known values and null only when none is known', () {
      final s = known + unknown;
      expect(s.kcal, 150);
      expect(s.proteinG, 10);
      expect(s.fibreG, isNull);
      final u = unknown + unknown;
      expect(u.proteinG, isNull);
      expect(u.carbsG, isNull);
    });

    test('sum of only-unknown items is unknown, not zero', () {
      final s = NutrientAmounts.sum(const [unknown, unknown]);
      expect(s.kcal, 100);
      expect(s.proteinG, isNull);
    });

    test('totals report the known sum and the unknown count per nutrient', () {
      const withFibre = NutrientAmounts(
        kcal: 1,
        proteinG: 1,
        carbsG: 1,
        fatG: 1,
        fibreG: 3,
      );
      final t = NutrientTotals.of(const [known, unknown, withFibre]);
      expect(t.known.proteinG, 11);
      expect(t.known.fibreG, 3);
      expect(t.unknownProteinCount, 1);
      expect(t.unknownCarbsCount, 1);
      expect(t.unknownFatCount, 1);
      expect(t.unknownFibreCount, 2);
      expect(t.unknownCount(Nutrient.fibreG), 2);
      expect(t.inputCount, 3);
      expect(t.isComplete, isFalse);
    });

    test('totals of nothing are zero with no unknowns', () {
      final t = NutrientTotals.of(const []);
      expect(t.known, NutrientAmounts.zero);
      expect(t.isComplete, isTrue);
      expect(t, NutrientTotals.empty);
    });

    test('combining totals adds known values and unknown counts', () {
      final a = NutrientTotals.of(const [known, unknown]);
      final b = NutrientTotals.of(const [unknown]);
      final c = NutrientTotals.combine([a, b]);
      expect(c.known.proteinG, 10);
      expect(c.unknownProteinCount, 2);
      expect(c.inputCount, 3);
    });

    test('validation accepts null macros', () {
      final r = validateNutrientsPer100(kcal: 100);
      final v = (r as Ok<NutrientAmounts>).value;
      expect(v.proteinG, isNull);
      expect(v.carbsG, isNull);
      expect(v.fatG, isNull);
    });

    test('validation still rejects negative or oversized macros', () {
      final neg = validateNutrientsPer100(kcal: 100, proteinG: -1);
      expect(((neg as Err).error as ValidationError).field, 'proteinG');
      final big = validateNutrientsPer100(kcal: 100, fatG: 101);
      expect(((big as Err).error as ValidationError).field, 'fatG');
      final negKcal = validateNutrientsPer100(kcal: -1);
      expect(negKcal, isA<Err<NutrientAmounts>>());
    });

    test('forQuantity keeps unknown macros unknown', () {
      const profile = NutrientProfile(
        per100: ReferenceUnit.grams,
        per100Amounts: NutrientAmounts(kcal: 10),
        provenance: DataProvenance.crowdsourced,
      );
      final v = (profile.forQuantity(
        Quantity.fromStored(200, ReferenceUnit.grams),
      ) as Ok<NutrientAmounts>).value;
      expect(v.kcal, 20);
      expect(v.proteinG, isNull);
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

  group('diaryDayKey (day start across midnight)', () {
    test('with a 04:00 start 02:30 still belongs to the previous day', () {
      expect(diaryDayKey(DateTime(2026, 11, 5, 2, 30), 4), '2026-11-04');
      expect(diaryDayKey(DateTime(2026, 11, 5, 3, 59), 4), '2026-11-04');
    });

    test('from 04:00 the new day starts', () {
      expect(diaryDayKey(DateTime(2026, 11, 5, 4), 4), '2026-11-05');
      expect(diaryDayKey(DateTime(2026, 11, 5, 23, 59), 4), '2026-11-05');
    });

    test('midnight start equals the plain local date; month boundary', () {
      expect(diaryDayKey(DateTime(2026, 11, 5, 0, 1), 0), '2026-11-05');
      expect(diaryDayKey(DateTime(2026, 12, 1, 1), 4), '2026-11-30');
    });

    test('a UTC instant is read in local time', () {
      final utc = DateTime.utc(2026, 11, 5, 2, 30);
      expect(
        diaryDayKey(utc, 4),
        dayKey(utc.toLocal().subtract(const Duration(hours: 4))),
      );
    });
  });

  group('ServingSize.quantityFor', () {
    final slice = ServingSize(
      label: 'slice',
      quantity: Quantity.fromStored(35, ReferenceUnit.grams),
    );

    test('count x serving, rounded to 0.1 (spec 2.1)', () {
      expect(slice.quantityFor(2).amount, 70);
      expect(slice.quantityFor(1.5).amount, 52.5);
      expect(slice.quantityFor(0.3).amount, 10.5);
      final odd = ServingSize(
        label: 'x',
        quantity: Quantity.fromStored(33.4, ReferenceUnit.grams),
      );
      expect(odd.quantityFor(1.5).amount, 50.1);
      expect(slice.quantityFor(2).unit, ReferenceUnit.grams);
    });

    test('an invalid count gives a zero quantity', () {
      expect(slice.quantityFor(-1).amount, 0);
      expect(slice.quantityFor(double.nan).amount, 0);
    });
  });
}
