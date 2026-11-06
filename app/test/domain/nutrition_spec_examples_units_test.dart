// Calculation specification §10 worked examples E42–E49 (revision 1.4,
// proposed): the §2.3 entry-unit rules that had no code before WP 15.
// E01–E41 live in nutrition_spec_examples_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/entry_unit.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';

Quantity _ok(Result<Quantity> r) => (r as Ok<Quantity>).value;

/// Milk from §10: 64 kcal, P 3.4, C 4.8, F 3.6 per 100 ml, fibre unknown.
const _milk = NutrientProfile(
  per100: ReferenceUnit.millilitres,
  per100Amounts: NutrientAmounts(
    kcal: 64,
    proteinG: 3.4,
    carbsG: 4.8,
    fatG: 3.6,
  ),
  provenance: DataProvenance.crowdsourced,
);

void main() {
  group('spec §10 E42–E49 (§2.3 entry units)', () {
    test('E42 0.25 kg is stored as 250 g and shown as "250 g"', () {
      final q = _ok(EntryUnit.kilograms.toCanonical(0.25));
      expect(q.amount, 250);
      expect(q.unit, ReferenceUnit.grams);
      expect(q.label, '250 g');
      expect(EntryUnit.kilograms.fromCanonical(q), 0.25);
    });

    test('E43 1 kg = 1000 g and 1 l = 1000 ml exactly', () {
      expect(_ok(EntryUnit.kilograms.toCanonical(1)).amount, 1000.0);
      expect(_ok(EntryUnit.litres.toCanonical(1)).amount, 1000.0);
      expect(
        _ok(EntryUnit.litres.toCanonical(1)).unit,
        ReferenceUnit.millilitres,
      );
    });

    test('E44 1.2345 kg keeps its fourth decimal: 1234.5 g', () {
      expect(_ok(EntryUnit.kilograms.toCanonical(1.2345)).amount, 1234.5);
      expect(_ok(EntryUnit.litres.toCanonical(0.0001)).amount, 0.1);
    });

    test('E45 a fifth kg decimal cannot be typed; via the API it rounds', () {
      // Entry fields limit kg to EntryUnit.kilograms.decimals (4) places.
      expect(EntryUnit.kilograms.decimals, 4);
      // 1.23456 kg = 1234.56 g → 0.1 g step → 1234.6 g (spec §2.1).
      expect(_ok(EntryUnit.kilograms.toCanonical(1.23456)).amount, 1234.6);
    });

    test('E46 mg entry is coarse: 250 mg → 0.3 g, 500 mg → 0.5 g', () {
      // 0.25 g is an exact binary tie and rounds away from zero (§2.1).
      expect(_ok(EntryUnit.milligrams.toCanonical(250)).amount, 0.3);
      expect(_ok(EntryUnit.milligrams.toCanonical(500)).amount, 0.5);
      expect(_ok(EntryUnit.milligrams.toCanonical(1000)).amount, 1.0);
    });

    test('E47 0.5 l of Milk is 500 ml → 320 kcal, P 17, fibre unknown', () {
      final q = _ok(EntryUnit.litres.toCanonical(0.5));
      expect(q.amount, 500);
      final n = (_milk.forQuantity(q) as Ok<NutrientAmounts>).value;
      expect(n.kcal, 320);
      expect(n.proteinG, 17);
      expect(n.carbsG, 24);
      expect(n.fatG, 18);
      expect(n.fibreG, isNull);
    });

    test('E48 a food measured per 100 ml offers no mass unit (no density)', () {
      final offered = EntryUnit.forBase(_milk.per100);
      expect(offered, [EntryUnit.millilitres, EntryUnit.litres]);
      expect(offered, isNot(contains(EntryUnit.kilograms)));
      expect(offered, isNot(contains(EntryUnit.grams)));
    });

    test('E49 round trip g → kg → g is within 0.001', () {
      for (final grams in [250.0, 0.1, 1234.5, 99999.9]) {
        final stored = Quantity.fromStored(grams, ReferenceUnit.grams);
        final inKg = EntryUnit.kilograms.fromCanonical(stored);
        final back = _ok(EntryUnit.kilograms.toCanonical(inKg));
        expect(back.amount, closeTo(grams, 0.001), reason: '$grams g');
      }
      // Displayed kg uses the entry precision: 1234.5 g → "1.2345 kg".
      final kg = EntryUnit.kilograms.fromCanonical(
        Quantity.fromStored(1234.5, ReferenceUnit.grams),
      );
      expect(formatNumber(kg, maxDecimals: 4), '1.2345');
    });
  });
}
