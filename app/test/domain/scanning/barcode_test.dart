import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/scanning/barcode.dart';

Barcode _ok(String input) => (validateBarcode(input) as Ok<Barcode>).value;
String _err(String input) =>
    ((validateBarcode(input) as Err<Barcode>).error as ValidationError).message;

void main() {
  group('validateBarcode', () {
    test('accepts a valid EAN-13 and keeps it as the lookup key', () {
      final b = _ok('3017624010701');
      expect(b.format, BarcodeFormat.ean13);
      expect(b.raw, '3017624010701');
      expect(b.lookupKey, '3017624010701');
      expect(_ok('4006381333931').format, BarcodeFormat.ean13);
    });

    test('rejects an EAN-13 with a wrong check digit', () {
      expect(_err('3017624010702'), 'That barcode is not valid.');
    });

    test('accepts a valid EAN-8 and pads the lookup key to 13 digits', () {
      final b = _ok('96385074');
      expect(b.format, BarcodeFormat.ean8);
      expect(b.lookupKey, '0000096385074');
    });

    test('accepts a valid UPC-A and pads the lookup key with one zero', () {
      final b = _ok('042100005264');
      expect(b.format, BarcodeFormat.upcA);
      expect(b.lookupKey, '0042100005264');
    });

    test('rejects a UPC-A with a wrong check digit', () {
      expect(_err('042100005265'), 'That barcode is not valid.');
    });

    test('classifies a valid UPC-E and looks it up as its UPC-A expansion', () {
      final b = _ok('04252614');
      expect(b.format, BarcodeFormat.upcE);
      expect(b.raw, '04252614');
      expect(b.lookupKey, '0042100005264');
    });

    test('expands UPC-E for each final-digit rule', () {
      expect(expandUpcE('04252614'), '042100005264'); // last digit 0-2
      expect(expandUpcE('01234513'), '012100003453'); // 0-2
      expect(expandUpcE('12345630'), '123400000560'); // 3
      expect(expandUpcE('02345647'), '023450000067'); // 4
      expect(expandUpcE('02345659'), '023456000059'); // 5-9
      expect(expandUpcE('22345659'), isNull);
    });

    test('rejects an 8-digit code that is neither EAN-8 nor UPC-E', () {
      expect(_err('96385075'), 'That barcode is not valid.');
      expect(_err('23456781'), 'That barcode is not valid.');
    });

    test('rejects letters', () {
      expect(_err('30176240107O1'), 'Enter 8, 12 or 13 digits.');
    });

    test('rejects seven digits', () {
      expect(_err('9638507'), 'Enter 8, 12 or 13 digits.');
    });

    test('trims surrounding whitespace but rejects inner whitespace', () {
      expect(_ok('  3017624010701\n').raw, '3017624010701');
      expect(_err('3017 624010701'), 'Enter 8, 12 or 13 digits.');
      expect(_err('   '), 'Enter 8, 12 or 13 digits.');
    });
  });

  group('validateBarcode format hint', () {
    // 02345659 expands to UPC-A 023456000059 and its EAN-8 check digit is
    // also correct, so the digits alone are ambiguous.
    Barcode hinted(String input, BarcodeFormat? hint) =>
        (validateBarcode(input, hint: hint) as Ok<Barcode>).value;

    test('upcE hint classifies an ambiguous code as UPC-E', () {
      final b = hinted('02345659', BarcodeFormat.upcE);
      expect(b.format, BarcodeFormat.upcE);
      expect(b.lookupKey, '0023456000059');
      expect(b.alternativeLookupKeys, isEmpty);
    });

    test('no hint keeps EAN-8 first and exposes the UPC-E expansion', () {
      final b = hinted('02345659', null);
      expect(b.format, BarcodeFormat.ean8);
      expect(b.lookupKey, '0000002345659');
      expect(b.alternativeLookupKeys, ['0023456000059']);
      expect(b.lookupKeys, ['0000002345659', '0023456000059']);
    });

    test('ean8 hint keeps EAN-8 without alternatives', () {
      final b = hinted('02345659', BarcodeFormat.ean8);
      expect(b.format, BarcodeFormat.ean8);
      expect(b.alternativeLookupKeys, isEmpty);
    });

    test('an unambiguous UPC-E is unchanged with or without a hint', () {
      for (final h in [null, BarcodeFormat.upcE]) {
        final b = hinted('04252614', h);
        expect(b.format, BarcodeFormat.upcE);
        expect(b.lookupKey, '0042100005264');
        expect(b.alternativeLookupKeys, isEmpty);
      }
    });

    test('an unambiguous EAN-8 has no alternative', () {
      expect(hinted('96385074', null).alternativeLookupKeys, isEmpty);
    });

    test('ean8 hint with a bad EAN-8 check digit is rejected', () {
      // 04252614 is a valid UPC-E but not a valid EAN-8.
      final r = validateBarcode('04252614', hint: BarcodeFormat.ean8);
      expect((r as Err<Barcode>).error, isA<ValidationError>());
    });

    test('upcE hint with an invalid UPC-A check digit is rejected', () {
      // 96385074 is a valid EAN-8 but not UPC-E (number system 9).
      final r = validateBarcode('96385074', hint: BarcodeFormat.upcE);
      expect((r as Err<Barcode>).error, isA<ValidationError>());
    });

    test('ean13 and upcA hints verify their check digits', () {
      expect(
        validateBarcode('3017624010701', hint: BarcodeFormat.ean13),
        isA<Ok<Barcode>>(),
      );
      expect(
        validateBarcode('3017624010702', hint: BarcodeFormat.ean13),
        isA<Err<Barcode>>(),
      );
      expect(
        validateBarcode('042100005264', hint: BarcodeFormat.upcA),
        isA<Ok<Barcode>>(),
      );
      expect(
        validateBarcode('042100005265', hint: BarcodeFormat.upcA),
        isA<Err<Barcode>>(),
      );
    });
  });
}
