/// Whether the app may post notifications (D04 PLT-007).
enum NotificationPermission {
  /// The user allowed notifications.
  granted,

  /// Not allowed: refused, blocked in system settings, or never asked. The
  /// app may ask again, but the OS may show no prompt once refused; the user
  /// can then only change it in system settings.
  denied,
}

/// Whether the OS lets the app deliver the rest notification at the exact end
/// time (Android exact alarms, ADR-0007). Read it fresh each time: the user
/// can change it in system settings at any moment.
enum ExactTiming {
  /// The OS currently allows exact alarms: delivery at the timer's end.
  available,

  /// Android 12+ without the exact-alarm grant: the notification may arrive
  /// late. The user can allow it via [RestAlertScheduler.requestExactTiming].
  unavailable,

  /// No separate grant exists or is needed here (iOS, desktop, no adapter):
  /// the app makes no claim about precise timing.
  notApplicable,
}

/// Schedules the rest-timer end notification for the time the app is in the
/// background (D04 TRN-022(2), ADR-0007). Flutter-free so the timer logic and
/// its tests need no platform.
///
/// The notification is only a convenience: the timer derives its state from
/// the wall clock, so nothing may depend on a notification arriving
/// (PLT-008(2)). Every method must complete without throwing; a failure is a
/// no-op (or [NotificationPermission.denied]) so logging a set never fails
/// because of an alert.
abstract interface class RestAlertScheduler {
  /// Current permission without prompting.
  Future<NotificationPermission> status();

  /// Asks the user for permission (PLT-007(1)); only called when the user
  /// turns the setting on.
  Future<NotificationPermission> request();

  /// Opens the system notification settings of this app. Returns whether a
  /// settings screen could be opened.
  Future<bool> openSettings();

  /// Whether exact delivery is possible right now, without prompting. A
  /// failure reads as [ExactTiming.unavailable] so precise timing is never
  /// claimed without proof.
  Future<ExactTiming> exactTimingStatus();

  /// Opens the system route where the user can allow exact alarms (Android
  /// "Alarms & reminders"). Completes when the user comes back; the outcome
  /// is read with [exactTimingStatus], not taken from this call. A no-op where
  /// the route does not exist.
  Future<void> requestExactTiming();

  /// Shows a notification at [endsAt]. Scheduling an [id] that is already
  /// scheduled replaces it.
  Future<void> schedule({
    required String id,
    required DateTime endsAt,
    required String title,
    required String body,
  });

  /// Cancels the scheduled notification [id] (and removes it if shown).
  Future<void> cancel(String id);

  /// Cancels every scheduled rest alert (PLT-007(2)).
  Future<void> cancelAll();
}

/// Scheduler used where no platform adapter is bound (desktop, web): nothing
/// can be scheduled and permission is never granted, so the setting stays off.
final class NoopRestAlertScheduler implements RestAlertScheduler {
  const NoopRestAlertScheduler();

  @override
  Future<NotificationPermission> status() async =>
      NotificationPermission.denied;

  @override
  Future<NotificationPermission> request() async =>
      NotificationPermission.denied;

  @override
  Future<bool> openSettings() async => false;

  @override
  Future<void> schedule({
    required String id,
    required DateTime endsAt,
    required String title,
    required String body,
  }) async {}

  @override
  Future<ExactTiming> exactTimingStatus() async => ExactTiming.notApplicable;

  @override
  Future<void> requestExactTiming() async {}

  @override
  Future<void> cancel(String id) async {}

  @override
  Future<void> cancelAll() async {}
}
