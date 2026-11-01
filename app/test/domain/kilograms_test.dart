import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/units/kilograms.dart';

void main() {
  group('Kilograms.of', () {
    test('accepts values inside the range and rounds to 0.1 kg', () {
      final r = Kilograms.of(82.44);
      expect(r, isA<Ok<Kilograms>>());
      expect((r as Ok<Kilograms>).value.value, 82.4);
      expect(r.value.label, '82.4 kg');
    });

    test('accepts the boundaries 20.0 and 500.0', () {
      expect(Kilograms.of(20), isA<Ok<Kilograms>>());
      expect(Kilograms.of(500), isA<Ok<Kilograms>>());
    });

    test('rejects values below 20.0 kg', () {
      final r = Kilograms.of(19.94);
      expect(r, isA<Err<Kilograms>>());
      expect((r as Err<Kilograms>).error, isA<ValidationError>());
      expect((r.error as ValidationError).field, 'weightKg');
    });

    test('rejects values above 500.0 kg', () {
      expect(Kilograms.of(500.05), isA<Err<Kilograms>>());
    });

    test('rejects NaN and infinity', () {
      expect(Kilograms.of(double.nan), isA<Err<Kilograms>>());
      expect(Kilograms.of(double.infinity), isA<Err<Kilograms>>());
    });
  });

  group('Kilograms.parse', () {
    test('parses a plain decimal', () {
      expect((Kilograms.parse('82.4') as Ok<Kilograms>).value.value, 82.4);
    });

    test('accepts a comma decimal separator and surrounding spaces', () {
      expect((Kilograms.parse(' 82,4 ') as Ok<Kilograms>).value.value, 82.4);
    });

    test('rejects empty text with a field-specific message', () {
      final r = Kilograms.parse('   ') as Err<Kilograms>;
      expect(r.error.message, 'Enter a weight in kg.');
    });

    test('rejects non-numeric text', () {
      expect(Kilograms.parse('eighty'), isA<Err<Kilograms>>());
    });
  });

  test('equality is by value', () {
    expect(
      (Kilograms.of(80) as Ok<Kilograms>).value,
      equals((Kilograms.of(80) as Ok<Kilograms>).value),
    );
    expect(
      (Kilograms.of(80) as Ok<Kilograms>).value,
      (Kilograms.of(80.04) as Ok<Kilograms>).value,
    );
  });

  test('fromStored throws on a corrupt value', () {
    expect(() => Kilograms.fromStored(5), throwsStateError);
  });
}
