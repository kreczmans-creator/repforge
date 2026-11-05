import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/units/units.dart';

void main() {
  group('Quantity', () {
    test('rounds to 0.1', () {
      final q = Quantity.of(150.04, ReferenceUnit.grams);
      expect((q as Ok<Quantity>).value.amount, 150);
      final r = Quantity.of(12.36, ReferenceUnit.millilitres);
      expect((r as Ok<Quantity>).value.amount, 12.4);
    });

    test('portions round to 0.01; grams and ml stay at 0.1 (spec 2.1)', () {
      double portions(double v) =>
          (Quantity.of(v, ReferenceUnit.portions) as Ok<Quantity>).value.amount;
      double grams(double v) =>
          (Quantity.of(v, ReferenceUnit.grams) as Ok<Quantity>).value.amount;
      double ml(double v) => (Quantity.of(
        v,
        ReferenceUnit.millilitres,
      ) as Ok<Quantity>).value.amount;
      expect(portions(1.25), 1.25);
      expect(portions(1.234), 1.23);
      expect(portions(0.75), 0.75);
      expect(portions(0.01), 0.01);
      expect(grams(12.36), 12.4);
      expect(grams(1.25), 1.3);
      expect(ml(12.36), 12.4);
      expect(ReferenceUnit.portions.decimals, 2);
      expect(ReferenceUnit.grams.decimals, 1);
      expect(ReferenceUnit.millilitres.decimals, 1);
    });

    test('exact keeps the amount for every unit', () {
      for (final u in ReferenceUnit.values) {
        expect((Quantity.exact(1.234, u) as Ok<Quantity>).value.amount, 1.234);
      }
    });

    test('label shows no trailing-zero noise', () {
      String label(double v) =>
          (Quantity.of(v, ReferenceUnit.portions) as Ok<Quantity>).value.label;
      expect(label(1.25), '1.25 portions');
      expect(label(1.5), '1.5 portions');
      expect(label(2), '2 portions');
      expect(
        (Quantity.of(150, ReferenceUnit.grams) as Ok<Quantity>).value.label,
        '150 g',
      );
    });

    test('accepts zero and the upper bound', () {
      expect(Quantity.of(0, ReferenceUnit.grams).isOk, isTrue);
      expect(Quantity.of(100000, ReferenceUnit.grams).isOk, isTrue);
    });

    test('rejects negatives, NaN, infinity and > 100000', () {
      for (final v in [-0.1, double.nan, double.infinity, 100000.5]) {
        final r = Quantity.of(v, ReferenceUnit.grams);
        expect(r, isA<Err<Quantity>>(), reason: '$v');
        expect((r as Err<Quantity>).error, isA<ValidationError>());
      }
    });

    test('fromStored throws on corrupt values', () {
      expect(
        () => Quantity.fromStored(-1, ReferenceUnit.grams),
        throwsStateError,
      );
      expect(
        () => Quantity.fromStored(double.nan, ReferenceUnit.grams),
        throwsStateError,
      );
      expect(Quantity.fromStored(5, ReferenceUnit.grams).amount, 5);
    });

    test('labels and equality', () {
      expect(Quantity.fromStored(150, ReferenceUnit.grams).label, '150 g');
      expect(
        Quantity.fromStored(250, ReferenceUnit.millilitres).label,
        '250 ml',
      );
      expect(Quantity.fromStored(82.5, ReferenceUnit.grams).label, '82.5 g');
      expect(
        Quantity.fromStored(1, ReferenceUnit.grams),
        Quantity.fromStored(1, ReferenceUnit.grams),
      );
      expect(
        Quantity.fromStored(1, ReferenceUnit.grams),
        isNot(Quantity.fromStored(1, ReferenceUnit.millilitres)),
      );
    });
  });

  group('Centimetres', () {
    test('accepts bounds and rounds to 0.1', () {
      expect((Centimetres.of(10) as Ok<Centimetres>).value.value, 10);
      expect((Centimetres.of(300) as Ok<Centimetres>).value.value, 300);
      expect((Centimetres.of(85.26) as Ok<Centimetres>).value.value, 85.3);
    });

    test('rejects out of range, NaN and infinity', () {
      for (final v in [
        9.9,
        300.1,
        0.0,
        -5.0,
        400.0,
        double.nan,
        double.infinity,
      ]) {
        final r = Centimetres.of(v);
        expect(r, isA<Err<Centimetres>>(), reason: '$v');
        expect((r as Err<Centimetres>).error, isA<ValidationError>());
      }
    });

    test('9.96 rounds up into range', () {
      expect((Centimetres.of(9.96) as Ok<Centimetres>).value.value, 10);
    });

    test('fromStored throws on corrupt values; label has one decimal', () {
      expect(() => Centimetres.fromStored(5), throwsStateError);
      expect(() => Centimetres.fromStored(1000), throwsStateError);
      expect(Centimetres.fromStored(85).label, '85.0 cm');
    });
  });

  group('LoadKg', () {
    test('input accepts 0.25 steps and rejects anything else (TRN-002(2))', () {
      for (final v in [0, 0.25, 20, 20.25, 20.5, 62.5, 1000]) {
        expect((LoadKg.of(v.toDouble()) as Ok<LoadKg>).value.value, v);
      }
      for (final v in [20.1, 20.13, 20.4, 0.74, 80.1, 0.1, 1000.25]) {
        expect(LoadKg.of(v).isErr, isTrue, reason: '$v');
      }
    });

    test('float noise within 1e-9 is accepted', () {
      expect((LoadKg.of(0.1 + 0.15) as Ok<LoadKg>).value.value, 0.25);
      expect((LoadKg.of(80 + 1e-12) as Ok<LoadKg>).value.value, 80);
    });

    test('negative zero is zero; negatives are rejected', () {
      const negativeZero = -0.0;
      final zero = (LoadKg.of(negativeZero) as Ok<LoadKg>).value.value;
      expect(zero, 0);
      expect(zero.isNegative, isFalse);
      expect(LoadKg.of(-0.1).isErr, isTrue);
      expect(LoadKg.of(-0.25).isErr, isTrue);
    });

    test('stored values are read leniently', () {
      expect(LoadKg.fromStored(80.1).value, 80);
      expect(LoadKg.tryFromStored(20.13)!.value, 20.25);
      expect(LoadKg.tryFromStored(-1), isNull);
      expect(LoadKg.tryFromStored(double.nan), isNull);
    });

    test('accepts bounds', () {
      expect(LoadKg.of(0).isOk, isTrue);
      expect(LoadKg.of(1000).isOk, isTrue);
    });

    test('rejects out of range, NaN and infinity', () {
      for (final v in [-0.5, 1000.5, double.nan, double.negativeInfinity]) {
        final r = LoadKg.of(v);
        expect(r, isA<Err<LoadKg>>(), reason: '$v');
        expect((r as Err<LoadKg>).error, isA<ValidationError>());
      }
    });

    test('fromStored throws on corrupt values', () {
      expect(() => LoadKg.fromStored(-1), throwsStateError);
      expect(() => LoadKg.fromStored(2000), throwsStateError);
      expect(LoadKg.fromStored(60).value, 60);
    });

    test('labels', () {
      expect(LoadKg.fromStored(82.5).label, '82.5 kg');
      expect(LoadKg.fromStored(0.75).label, '0.75 kg');
      expect(LoadKg.fromStored(100).label, '100 kg');
    });
  });

  group('UnitConversion', () {
    test('known values', () {
      expect(UnitConversion.kgToLb(1), closeTo(2.2046, 1e-4));
      expect(UnitConversion.inToCm(1), closeTo(2.54, 1e-6));
      expect(UnitConversion.cmToIn(2.54), closeTo(1, 1e-6));
      expect(UnitConversion.lbToKg(2.2046226218), closeTo(1, 1e-9));
    });

    test('kg <-> lb and cm <-> in round trip', () {
      for (final v in [0.0, 1.0, 20.5, 82.4, 500.0]) {
        expect(
          UnitConversion.lbToKg(UnitConversion.kgToLb(v)),
          closeTo(v, 1e-6),
        );
        expect(
          UnitConversion.inToCm(UnitConversion.cmToIn(v)),
          closeTo(v, 1e-6),
        );
      }
    });
  });

  group('ReferenceUnit.portions', () {
    test('is a count of portions, not a measure', () {
      expect(ReferenceUnit.grams.isMeasure, isTrue);
      expect(ReferenceUnit.millilitres.isMeasure, isTrue);
      expect(ReferenceUnit.portions.isMeasure, isFalse);
      final q = Quantity.of(1.5, ReferenceUnit.portions);
      expect((q as Ok<Quantity>).value.label, '1.5 portions');
    });
  });
}
