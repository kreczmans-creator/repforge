import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/scanning/barcode.dart';

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

  Future<Result<BarcodeLookup>> call(String input) async {
    final validated = validateBarcode(input);
    final Barcode barcode;
    switch (validated) {
      case Err(:final error):
        return Err(error);
      case Ok(:final value):
        barcode = value;
    }

    var local = await foods.byBarcode(barcode.lookupKey);
    if (local == null && barcode.raw != barcode.lookupKey) {
      local = await foods.byBarcode(barcode.raw);
    }
    if (local != null) {
      return Ok(BarcodeFound(local, source: BarcodeLookupSource.local));
    }

    final online = await lookup.byBarcode(barcode.lookupKey);
    switch (online) {
      case Err(:final error):
        return Err(error);
      case Ok(value: null):
        return Ok(BarcodeNotFound(barcode));
      case Ok(:final value!):
        await foods.upsert(value);
        return Ok(BarcodeFound(value, source: BarcodeLookupSource.online));
    }
  }
}
