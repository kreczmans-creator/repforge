import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';

/// Retail barcode symbologies the app reads (PLT-002).
enum BarcodeFormat { ean13, ean8, upcA, upcE }

/// A validated retail barcode (NUT-006).
///
/// Build one with [validateBarcode]; the constructor does not validate.
@immutable
final class Barcode {
  const Barcode({
    required this.raw,
    required this.lookupKey,
    required this.format,
  });

  /// The digits as scanned or typed (trimmed).
  final String raw;

  /// The digits normalised to 13 with leading zeros, the form Open Food
  /// Facts uses. UPC-E is expanded to UPC-A first.
  final String lookupKey;

  /// The symbology [raw] was classified as.
  final BarcodeFormat format;

  @override
  bool operator ==(Object other) =>
      other is Barcode &&
      other.raw == raw &&
      other.lookupKey == lookupKey &&
      other.format == format;

  @override
  int get hashCode => Object.hash(raw, lookupKey, format);

  @override
  String toString() => 'Barcode($raw, $format)';
}

/// Validates [input] as an EAN-13, EAN-8, UPC-A or UPC-E code.
///
/// Surrounding whitespace is trimmed. Anything but 8, 12 or 13 digits is
/// rejected, as is a wrong modulo-10 check digit. Eight digits are read as
/// EAN-8 when the check digit fits, otherwise as UPC-E (number system 0 or 1)
/// when its expansion to UPC-A has a valid check digit.
Result<Barcode> validateBarcode(String input) {
  final raw = input.trim();
  if (!RegExp(r'^\d+$').hasMatch(raw) ||
      (raw.length != 8 && raw.length != 12 && raw.length != 13)) {
    return const Err(ValidationError('Enter 8, 12 or 13 digits.'));
  }
  const invalid = ValidationError('That barcode is not valid.');
  switch (raw.length) {
    case 13:
      return _hasValidCheckDigit(raw)
          ? Ok(Barcode(raw: raw, lookupKey: raw, format: BarcodeFormat.ean13))
          : const Err(invalid);
    case 12:
      return _hasValidCheckDigit(raw)
          ? Ok(
              Barcode(
                raw: raw,
                lookupKey: raw.padLeft(13, '0'),
                format: BarcodeFormat.upcA,
              ),
            )
          : const Err(invalid);
    default:
      if (_hasValidCheckDigit(raw)) {
        return Ok(
          Barcode(
            raw: raw,
            lookupKey: raw.padLeft(13, '0'),
            format: BarcodeFormat.ean8,
          ),
        );
      }
      final expanded = expandUpcE(raw);
      if (expanded != null && _hasValidCheckDigit(expanded)) {
        return Ok(
          Barcode(
            raw: raw,
            lookupKey: expanded.padLeft(13, '0'),
            format: BarcodeFormat.upcE,
          ),
        );
      }
      return const Err(invalid);
  }
}

/// Expands an 8-digit UPC-E code to its 12-digit UPC-A equivalent, or `null`
/// when the number system digit is not 0 or 1. The check digit is carried
/// over unchanged; it is not validated here.
String? expandUpcE(String upcE) {
  if (upcE.length != 8 || (upcE[0] != '0' && upcE[0] != '1')) return null;
  final n = upcE[0];
  final d = upcE.substring(1, 7);
  final check = upcE[7];
  final body = switch (d[5]) {
    '0' ||
    '1' ||
    '2' => '$n${d.substring(0, 2)}${d[5]}0000${d.substring(2, 5)}',
    '3' => '$n${d.substring(0, 3)}00000${d.substring(3, 5)}',
    '4' => '$n${d.substring(0, 4)}00000${d[4]}',
    _ => '$n${d.substring(0, 5)}0000${d[5]}',
  };
  return '$body$check';
}

/// GS1 modulo-10 check: weights 3,1,3,... from the digit left of the check
/// digit, moving left.
bool _hasValidCheckDigit(String digits) {
  var sum = 0;
  for (var i = digits.length - 2, w = 3; i >= 0; i--, w = 4 - w) {
    sum += (digits.codeUnitAt(i) - 0x30) * w;
  }
  return (10 - sum % 10) % 10 == digits.codeUnitAt(digits.length - 1) - 0x30;
}
