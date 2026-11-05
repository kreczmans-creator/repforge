/// Foreground alert at the end of a rest timer (D04 TRN-022(1)): a haptic or
/// sound cue while the app is in the foreground. Flutter-free so the timer
/// logic and its tests do not depend on a platform. The background
/// notification is a separate port added with ADR-0007 (stage 3b).
abstract interface class RestAlert {
  /// Signals that the rest has ended. Must not throw.
  Future<void> fire();
}
