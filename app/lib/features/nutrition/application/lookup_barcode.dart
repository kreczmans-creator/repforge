import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/scanning/barcode.dart';
import 'package:repforge/domain/scanning/barcode_scanner.dart';

/// Where a found product came from.
enum BarcodeLookupSource { local, online }

/// Outcome of looking up a barcode that is valid.
sealed class BarcodeLookup {
  const BarcodeLookup();
}

/// The product is known, locally or online.
final class BarcodeFound extends BarcodeLookup {
  const BarcodeFound(this.food, {required this.source});
  final Food food;
  final BarcodeLookupSource source;
}

/// Neither the local database nor the online source knows the barcode.
final class BarcodeNotFound extends BarcodeLookup {
  const BarcodeNotFound(this.barcode);
  final Barcode barcode;
}

/// Finds a food by barcode (NUT-006), offline-first.
///
/// 1. Validate; a bad code is an `Err(ValidationError)`, nothing is looked up.
/// 2. Local database by the 13-digit key (then by the raw digits if they
///    differ, for foods saved before normalisation).
/// 3. Online lookup. A hit is cached with `FoodRepository.upsert`; this is the
///    "cached product table" of WP 6, so a re-scan works offline.
///
/// A lookup that fails passes its error through unchanged (the typed
/// `LookupFailure` survives: offline, rate-limited, unavailable). A failed or
/// empty lookup never creates a product.
final class LookupBarcode {
  const LookupBarcode({required this.foods, required this.lookup});

  final FoodRepository foods;
  final FoodLookupService lookup;

  /// Looks up [input]. [format] is the symbology the scanner hardware
  /// reported (null for manual entry); it disambiguates 8-digit codes.
  Future<Result<BarcodeLookup>> call(
    String input, {
    BarcodeFormat? format,
  }) async {
    final validated = validateBarcode(input, hint: format);
    final Barcode barcode;
    switch (validated) {
      case Err(:final error):
        return Err(error);
      case Ok(:final value):
        barcode = value;
    }

    // Every candidate key locally first (primary, then alternatives), then
    // the raw digits for foods saved before normalisation.
    final keys = barcode.lookupKeys;
    for (final key in [...keys, if (!keys.contains(barcode.raw)) barcode.raw]) {
      final local = await foods.byBarcode(key);
      if (local != null) {
        return Ok(BarcodeFound(local, source: BarcodeLookupSource.local));
      }
    }

    // Online, in order. Open Food Facts stores EAN-8 as 8 digits, so the
    // padded key is followed by the raw digits for an EAN-8. (Not verifiable
    // against the live service from the development proxy.)
    final onlineKeys = [
      keys.first,
      if (barcode.format == BarcodeFormat.ean8 && barcode.raw != keys.first)
        barcode.raw,
      ...keys.skip(1),
    ];
    for (final key in onlineKeys) {
      final online = await lookup.byBarcode(key);
      switch (online) {
        case Err(:final error):
          return Err(error);
        case Ok(value: null):
          continue;
        case Ok(:final value!):
          await foods.upsert(value);
          return Ok(BarcodeFound(value, source: BarcodeLookupSource.online));
      }
    }
    return Ok(BarcodeNotFound(barcode));
  }

  /// Looks up a scanned code, passing its reported symbology as the hint.
  Future<Result<BarcodeLookup>> scanned(ScannedCode code) =>
      call(code.raw, format: code.format);
}
