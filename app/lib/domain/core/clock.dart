/// Source of the current time. Injected so use cases are testable.
abstract interface class Clock {
  DateTime now();
}

/// Wall-clock implementation used in production.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Fixed-time implementation for tests.
final class FixedClock implements Clock {
  const FixedClock(this.fixed);
  final DateTime fixed;

  @override
  DateTime now() => fixed;
}
