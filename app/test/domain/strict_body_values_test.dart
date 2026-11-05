import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

/// BCM-001(1) and BCM-002(1): typed values are rejected, never rounded.
void main() {
  group('Kilograms.of is strict', () {
    test('accepts 20.0, 80.1 and 500.0', () {
      for (final v in [20.0, 80.1, 500.0]) {
        expect(Kilograms.of(v), isA<Ok<Kilograms>>(), reason: '$v');
      }
      expect((Kilograms.of(80.1) as Ok<Kilograms>).value.value, 80.1);
    });

    test('rejects out-of-range 19.9 and 500.1', () {
      for (final v in [19.9, 500.1, 0.0, -1.0, 1000.0]) {
        expect(Kilograms.of(v), isA<Err<Kilograms>>(), reason: '$v');
      }
    });

    test('rejects off-step 80.05, 80.15, 82.44 and boundary spill-over', () {
      for (final v in [80.05, 80.15, 82.44, 19.95, 19.96, 500.04, 80.01]) {
        final r = Kilograms.of(v);
        expect(r, isA<Err<Kilograms>>(), reason: '$v');
        expect(
          ((r as Err<Kilograms>).error as ValidationError).field,
          isNotNull,
        );
      }
    });

    test('tolerates floating-point noise but never rounds', () {
      expect((Kilograms.of(0.1 + 0.7 + 80) as Ok<Kilograms>).value.value, 80.8);
      expect((Kilograms.of(80.1 + 1e-12) as Ok<Kilograms>).value.value, 80.1);
    });

    test('rejects NaN and infinity', () {
      expect(Kilograms.of(double.nan), isA<Err<Kilograms>>());
      expect(Kilograms.of(double.infinity), isA<Err<Kilograms>>());
    });

    test('parse rejects off-step text', () {
      expect(Kilograms.parse('80.05'), isA<Err<Kilograms>>());
      expect(Kilograms.parse('80,15'), isA<Err<Kilograms>>());
      expect((Kilograms.parse('80,1') as Ok<Kilograms>).value.value, 80.1);
    });
  });

  group('Centimetres.of is strict', () {
    test('accepts 10.0, 85.1 and 300.0', () {
      for (final v in [10.0, 85.1, 300.0]) {
        expect(Centimetres.of(v), isA<Ok<Centimetres>>(), reason: '$v');
      }
    });

    test('rejects out-of-range 9.9 and 300.1', () {
      for (final v in [9.9, 300.1, 0.0, -5.0]) {
        expect(Centimetres.of(v), isA<Err<Centimetres>>(), reason: '$v');
      }
    });

    test('rejects off-step 85.05, 85.26, 9.96', () {
      for (final v in [85.05, 85.15, 85.26, 9.96, 10.04, 300.05]) {
        expect(Centimetres.of(v), isA<Err<Centimetres>>(), reason: '$v');
      }
    });

    test('tolerates floating-point noise', () {
      expect(
        (Centimetres.of(0.1 + 0.2 + 85) as Ok<Centimetres>).value.value,
        85.3,
      );
    });
  });

  group('typed text is a plain decimal (F6)', () {
    test('exponent, sign, special and malformed forms are rejected', () {
      for (final t in [
        '1e2',
        '8e1',
        '+80',
        '-80',
        'NaN',
        'Infinity',
        '80.',
        '.5',
        '0x50',
        '1 000',
        '8 0',
        '80..1',
        '80,1,2',
        '٨٠',
      ]) {
        expect(Kilograms.parse(t).isErr, isTrue, reason: 'kg "$t"');
        expect(Centimetres.parse(t).isErr, isTrue, reason: 'cm "$t"');
      }
    });

    test('plain decimals with a dot or comma, trimmed, are accepted', () {
      for (final (t, v) in [('80', 80.0), (' 80,1 ', 80.1), ('80.1', 80.1)]) {
        expect((Kilograms.parse(t) as Ok<Kilograms>).value.value, v);
        expect((Centimetres.parse(t) as Ok<Centimetres>).value.value, v);
      }
    });

    test('an off-step plain decimal is still an off-step error', () {
      final e = (Kilograms.parse('80.05') as Err<Kilograms>).error;
      expect(e.message, contains('0.1 kg'));
    });
  });
}
