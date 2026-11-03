import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

/// Why an online food lookup failed.
sealed class LookupFailure {
  const LookupFailure();
}

/// No connectivity or the request timed out.
final class LookupOffline extends LookupFailure {
  const LookupOffline();
}

/// The service asked us to slow down (HTTP 429).
final class LookupRateLimited extends LookupFailure {
  const LookupRateLimited();
}

/// The service answered with an error or something that is not JSON.
final class LookupUnavailable extends LookupFailure {
  const LookupUnavailable(this.detail);
  final String detail;
}

/// A lookup target does not exist.
final class LookupNotFound extends LookupFailure {
  const LookupNotFound();
}

/// AppError is sealed, so a lookup failure travels as an [UnexpectedError]
/// whose `cause` is the typed [LookupFailure]. Build one with [lookupError].
UnexpectedError lookupError(LookupFailure failure, [String? message]) =>
    UnexpectedError(message ?? 'Food lookup failed.', cause: failure);

/// Extracts the [LookupFailure] from an error built with [lookupError].
LookupFailure? lookupFailureOf(AppError error) =>
    error is UnexpectedError && error.cause is LookupFailure
    ? error.cause! as LookupFailure
    : null;

/// Online food database lookup (search by text, find by barcode).
abstract interface class FoodLookupService {
  Future<Result<List<Food>>> search(String query, {int limit = 20});

  /// `Ok(null)` when the barcode is not known.
  Future<Result<Food?>> byBarcode(String barcode);
}
