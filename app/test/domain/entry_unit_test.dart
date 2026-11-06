import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/units/entry_unit.dart';
import 'package:repforge/domain/units/units.dart';

Quantity _ok(Result<Quantity> r) => (r as Ok<Quantity>).value;

void main() {
  group('EntryUnit (NUT-022, spec §2.3)', () {
    test('factors are exact: 1 kg = 1000 g, 1 l = 1000 ml, 1 mg = 0.001 g', () {
      expect(EntryUnit.kilograms.factor, 1000);
      expect(EntryUnit.litres.factor, 1000);
      expect(EntryUnit.milligrams.factor, 0.001);
      expect(EntryUnit.grams.factor, 1);
      expect(EntryUnit.millilitres.factor, 1);
    });

    test('each unit converts to its own reference basis only', () {
      expect(EntryUnit.kilograms.base, ReferenceUnit.grams);
      expect(EntryUnit.milligrams.base, ReferenceUnit.grams);
      expect(EntryUnit.litres.base, ReferenceUnit.millilitres);
      expect(_ok(EntryUnit.kilograms.toCanonical(1)).unit, ReferenceUnit.grams);
      expect(
        _ok(EntryUnit.litres.toCanonical(1)).unit,
        ReferenceUnit.millilitres,
      );
    });

    test('forBase offers the canonical unit first and no cross-basis unit', () {
      expect(EntryUnit.forBase(ReferenceUnit.grams), [
        EntryUnit.grams,
        EntryUnit.kilograms,
      ]);
      expect(EntryUnit.forBase(ReferenceUnit.grams, withMilligrams: true), [
        EntryUnit.grams,
        EntryUnit.kilograms,
        EntryUnit.milligrams,
      ]);
      expect(EntryUnit.forBase(ReferenceUnit.millilitres), [
        EntryUnit.millilitres,
        EntryUnit.litres,
      ]);
      expect(EntryUnit.forBase(ReferenceUnit.portions), isEmpty);
      expect(EntryUnit.canonicalFor(ReferenceUnit.grams), EntryUnit.grams);
      expect(
        EntryUnit.canonicalFor(ReferenceUnit.millilitres),
        EntryUnit.millilitres,
      );
      expect(EntryUnit.canonicalFor(ReferenceUnit.portions), isNull);
    });

    test('isCanonical is true only for g and ml', () {
      expect(EntryUnit.grams.isCanonical, isTrue);
      expect(EntryUnit.millilitres.isCanonical, isTrue);
      expect(EntryUnit.kilograms.isCanonical, isFalse);
      expect(EntryUnit.litres.isCanonical, isFalse);
      expect(EntryUnit.milligrams.isCanonical, isFalse);
    });

    test('entry decimals match the 0.1 g / 0.1 ml store (spec §2.1)', () {
      expect(EntryUnit.grams.decimals, 1);
      expect(EntryUnit.millilitres.decimals, 1);
      expect(EntryUnit.kilograms.decimals, 4);
      expect(EntryUnit.litres.decimals, 4);
      expect(EntryUnit.milligrams.decimals, 0);
    });

    test('rejects negative, NaN and infinite amounts like Quantity.of', () {
      for (final u in EntryUnit.values) {
        expect(u.toCanonical(-1), isA<Err<Quantity>>());
        expect(u.toCanonical(double.nan), isA<Err<Quantity>>());
        expect(u.toCanonical(double.infinity), isA<Err<Quantity>>());
      }
    });

    test('upper bound is the canonical bound: 100 kg is the largest mass', () {
      expect(_ok(EntryUnit.kilograms.toCanonical(100)).amount, 100000);
      expect(EntryUnit.kilograms.toCanonical(100.0001), isA<Err<Quantity>>());
      expect(EntryUnit.litres.toCanonical(100.0001), isA<Err<Quantity>>());
    });

    test('parse accepts plain decimals with . or , and nothing else', () {
      expect(_ok(EntryUnit.kilograms.parse('0.25')).amount, 250);
      expect(_ok(EntryUnit.kilograms.parse(' 0,25 ')).amount, 250);
      expect(_ok(EntryUnit.litres.parse('1')).amount, 1000);
      for (final bad in ['', ' ', '+1', '-1', '1e2', '1.', '.5', 'abc']) {
        expect(
          EntryUnit.kilograms.parse(bad),
          isA<Err<Quantity>>(),
          reason: bad,
        );
      }
    });

    test('fromCanonical refuses a mass↔volume conversion', () {
      final ml = Quantity.fromStored(250, ReferenceUnit.millilitres);
      expect(() => EntryUnit.kilograms.fromCanonical(ml), throwsArgumentError);
      expect(() => EntryUnit.grams.fromCanonical(ml), throwsArgumentError);
      final portions = Quantity.fromStored(1.5, ReferenceUnit.portions);
      expect(
        () => EntryUnit.grams.fromCanonical(portions),
        throwsArgumentError,
      );
    });
  });
}
