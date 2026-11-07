import 'package:repforge/domain/core/result.dart';

/// Runs [body] and turns any failure into a [StorageError] result, so a use
/// case never throws across the layer boundary (engineering standards
/// section 5). The original error is kept as the cause.
Future<Result<T>> guardAnalytics<T>(
  String message,
  Future<T> Function() body,
) async {
  try {
    return Ok(await body());
  } on Object catch (e) {
    return Err(StorageError(message, cause: e));
  }
}

/// The value of a result already known to be [Ok] (the caller returned the
/// [Err] case before).
T okValue<T>(Result<T> result) => (result as Ok<T>).value;
