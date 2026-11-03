import 'package:repforge/domain/core/result.dart';

/// Single place that turns an [AppError] into user-facing text.
String userMessageFor(AppError error) => switch (error) {
  ValidationError(:final message) => message,
  StorageError() => 'Something went wrong saving your data. Please try again.',
  NotFoundError() => 'That record no longer exists.',
  UnexpectedError() => 'Something unexpected happened. Please try again.',
};
