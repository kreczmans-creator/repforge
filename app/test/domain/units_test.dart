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
    test('rounds to 0.25 steps', () {
      expect((LoadKg.of(20.1) as Ok<LoadKg>).value.value, 20);
      expect((LoadKg.of(20.13) as Ok<LoadKg>).value.value, 20.25);
      expect((LoadKg.of(20.4) as Ok<LoadKg>).value.value, 20.5);
      expect((LoadKg.of(0.74) as Ok<LoadKg>).value.value, 0.75);
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
}
