/// Outcome of an application use case: either a value or a typed error.
///
/// Use cases never throw across a layer boundary; they return a [Result].
sealed class Result<T> {
  const Result();

  /// Convenience constructor for a successful outcome.
  const factory Result.ok(T value) = Ok<T>;

  /// Convenience constructor for a failed outcome.
  const factory Result.err(AppError error) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// Folds both branches into a single value.
  R fold<R>(R Function(T value) onOk, R Function(AppError error) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final error) => onErr(error),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error);
  final AppError error;
}

/// Closed set of application errors. The UI maps these to user text in one
/// place; no raw exception strings reach the screen.
sealed class AppError {
  const AppError(this.message);

  /// Developer-facing description. Not shown verbatim to users.
  final String message;
}

/// Input failed validation. [field] names the offending input when known.
///
/// A multi-field form can fail on several inputs at once: [fieldErrors] then
/// maps every offending field to its message, and [field]/[message] describe
/// the first one.
final class ValidationError extends AppError {
  const ValidationError(
    super.message, {
    this.field,
    this.fieldErrors = const {},
  });
  final String? field;
  final Map<String, String> fieldErrors;
}

/// The persistence layer failed.
final class StorageError extends AppError {
  const StorageError(super.message, {this.cause});
  final Object? cause;
}

/// A requested record does not exist.
final class NotFoundError extends AppError {
  const NotFoundError(super.message);
}

/// Anything not covered above. Should be rare; logged, never swallowed.
final class UnexpectedError extends AppError {
  const UnexpectedError(super.message, {this.cause});
  final Object? cause;
}
