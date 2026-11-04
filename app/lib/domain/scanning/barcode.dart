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
    this.alternativeLookupKeys = const [],
  });

  /// The digits as scanned or typed (trimmed).
  final String raw;

  /// The digits normalised to 13 with leading zeros, the form Open Food
  /// Facts uses. UPC-E is expanded to UPC-A first.
  final String lookupKey;

  /// The symbology [raw] was classified as.
  final BarcodeFormat format;

  /// Other 13-digit keys the same digits may be stored under. Only set for an
  /// 8-digit code read without a format hint that is valid both as EAN-8 and
  /// as UPC-E: [lookupKey] is then the EAN-8 key and this holds the UPC-E
  /// expansion key.
  final List<String> alternativeLookupKeys;

  /// Every key to try, [lookupKey] first.
  List<String> get lookupKeys => [lookupKey, ...alternativeLookupKeys];

  @override
  bool operator ==(Object other) =>
      other is Barcode &&
      other.raw == raw &&
      other.lookupKey == lookupKey &&
      other.format == format &&
      _listEquals(other.alternativeLookupKeys, alternativeLookupKeys);

  @override
  int get hashCode => Object.hash(
    raw,
    lookupKey,
    format,
    Object.hashAll(alternativeLookupKeys),
  );

  @override
  String toString() => 'Barcode($raw, $format)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Validates [input] as an EAN-13, EAN-8, UPC-A or UPC-E code.
///
/// Surrounding whitespace is trimmed. Anything but 8, 12 or 13 digits is
/// rejected, as is a wrong modulo-10 check digit.
///
/// [hint] is the symbology the scanner hardware reported. When it fits the
/// digit count it is authoritative: `upcE` expands and verifies as UPC-E,
/// `ean8` verifies as EAN-8. A hint that does not fit the length is ignored.
/// Without a hint, eight digits are read as EAN-8 when the check digit fits,
/// otherwise as UPC-E (number system 0 or 1); when both readings are valid
/// the UPC-E expansion key is exposed in [Barcode.alternativeLookupKeys].
Result<Barcode> validateBarcode(String input, {BarcodeFormat? hint}) {
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
      final expanded = expandUpcE(raw);
      final upcEKey = expanded != null && _hasValidCheckDigit(expanded)
          ? expanded.padLeft(13, '0')
          : null;
      final ean8Valid = _hasValidCheckDigit(raw);
      Barcode asUpcE(String key) =>
          Barcode(raw: raw, lookupKey: key, format: BarcodeFormat.upcE);
      Barcode asEan8({List<String> alternatives = const []}) => Barcode(
        raw: raw,
        lookupKey: raw.padLeft(13, '0'),
        format: BarcodeFormat.ean8,
        alternativeLookupKeys: alternatives,
      );
      if (hint == BarcodeFormat.upcE) {
        return upcEKey != null ? Ok(asUpcE(upcEKey)) : const Err(invalid);
      }
      if (hint == BarcodeFormat.ean8) {
        return ean8Valid ? Ok(asEan8()) : const Err(invalid);
      }
      if (ean8Valid) {
        return Ok(asEan8(alternatives: [?upcEKey]));
      }
      return upcEKey != null ? Ok(asUpcE(upcEKey)) : const Err(invalid);
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
