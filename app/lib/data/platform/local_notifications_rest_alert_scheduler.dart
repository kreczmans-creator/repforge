import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:repforge/domain/training/rest_alert_scheduler.dart';
import 'package:timezone/timezone.dart' as tz;

/// Stable positive 31-bit notification id for a string id (FNV-1a), because
/// the plugin identifies notifications by `int`.
@visibleForTesting
int notificationIdFor(String id) {
  var hash = 0x811c9dc5;
  for (final unit in id.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

/// [RestAlertScheduler] on top of `flutter_local_notifications` (ADR-0007).
///
/// This file is the only place that imports the notification plugin and
/// `timezone` (adapter boundary, ADR-0006 standing constraint).
///
/// - Initialised lazily on first use, and without asking for any permission
///   (PLT-007(1)): iOS prompts only from [request].
/// - Android 12+: exact scheduling when the OS says the app may schedule exact
///   alarms (`canScheduleExactNotifications`), otherwise an inexact alarm that
///   may arrive late. The exact-alarm settings screen is opened only from
///   [requestExactTiming], which the Settings screen calls after explaining
///   why (OQ-24). Below Android 12 the plugin reports exact as allowed.
/// - Every plugin failure is swallowed (permission `denied`, or a no-op): an
///   alert that cannot be scheduled must never break logging or the screen.
final class LocalNotificationsRestAlertScheduler implements RestAlertScheduler {
  /// Creates the adapter. [plugin] is injectable for tests.
  LocalNotificationsRestAlertScheduler({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Channel id and name shown in the Android notification settings.
  static const channelId = 'rest_timer';
  static const channelName = 'Rest timer';

  /// Monochrome status-bar icon: the drawable `res/drawable/ic_stat_rest.xml`
  /// (the plugin looks drawables up by name). It is only referenced by name
  /// at run time, so `res/raw/keep.xml` keeps it in release builds.
  static const smallIcon = 'ic_stat_rest';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _initialised;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Initialises the plugin once. Returns false when this platform has no
  /// support or initialisation failed (retried on the next call).
  Future<bool> _ensureInitialised() {
    if (!_isAndroid && !_isIos) return Future.value(false);
    return _initialised ??= _initialise().then((ok) {
      if (!ok) _initialised = null;
      return ok;
    });
  }

  Future<bool> _initialise() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(smallIcon),
          // No permission prompt at startup: the user is asked only when
          // they turn the setting on (PLT-007(1)).
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
      );
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: 'Alerts when a rest between sets is over.',
          importance: Importance.high,
        ),
      );
      return true;
    } on Object catch (e) {
      debugPrint('Rest alert init failed: $e');
      return false;
    }
  }

  @override
  Future<NotificationPermission> status() async {
    try {
      if (!await _ensureInitialised()) return NotificationPermission.denied;
      final bool? enabled;
      if (_isAndroid) {
        enabled = await _android?.areNotificationsEnabled();
      } else {
        enabled = (await _ios?.checkPermissions())?.isEnabled;
      }
      return (enabled ?? false)
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    } on Object catch (e) {
      debugPrint('Rest alert status failed: $e');
      return NotificationPermission.denied;
    }
  }

  @override
  Future<NotificationPermission> request() async {
    try {
      if (!await _ensureInitialised()) return NotificationPermission.denied;
      final bool? granted;
      if (_isAndroid) {
        granted = await _android?.requestNotificationsPermission();
      } else {
        granted = await _ios?.requestPermissions(alert: true, sound: true);
      }
      return (granted ?? false)
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    } on Object catch (e) {
      debugPrint('Rest alert permission request failed: $e');
      return NotificationPermission.denied;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      if (!await _ensureInitialised()) return false;
      final opened = _isAndroid
          ? await _android?.openAppNotificationSettings()
          : await _ios?.openAppNotificationSettings();
      return opened ?? false;
    } on Object catch (e) {
      debugPrint('Opening notification settings failed: $e');
      return false;
    }
  }

  @override
  Future<ExactTiming> exactTimingStatus() async {
    // Only Android has a separate exact-alarm grant; elsewhere the app makes
    // no precision claim.
    if (!_isAndroid) return ExactTiming.notApplicable;
    try {
      if (!await _ensureInitialised()) return ExactTiming.unavailable;
      return await _android?.canScheduleExactNotifications() ?? false
          ? ExactTiming.available
          : ExactTiming.unavailable;
    } on Object catch (e) {
      debugPrint('Rest alert exact status failed: $e');
      return ExactTiming.unavailable;
    }
  }

  @override
  Future<void> requestExactTiming() async {
    if (!_isAndroid) return;
    try {
      if (!await _ensureInitialised()) return;
      // Opens "Alarms & reminders" on Android 12+ when not allowed and
      // completes on return; returns at once when allowed or below Android
      // 12. The boolean is ignored: the caller reads exactTimingStatus().
      await _android?.requestExactAlarmsPermission();
    } on Object catch (e) {
      debugPrint('Opening exact alarm settings failed: $e');
    }
  }

  @override
  Future<void> schedule({
    required String id,
    required DateTime endsAt,
    required String title,
    required String body,
  }) async {
    try {
      if (!await _ensureInitialised()) return;
      // A time already reached is not scheduled (the plugin refuses it, and
      // the foreground alert covers the case).
      if (!endsAt.isAfter(DateTime.now())) return;
      // An absolute instant: UTC avoids needing the zone database or the
      // device zone name.
      final at = tz.TZDateTime.from(endsAt, tz.UTC);
      final nid = notificationIdFor(id);
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Alerts when a rest between sets is over.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      );
      final exact = _isAndroid && await _canScheduleExact();
      try {
        await _plugin.zonedSchedule(
          id: nid,
          title: title,
          body: body,
          scheduledDate: at,
          notificationDetails: details,
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } on Object catch (e) {
        if (!exact) rethrow;
        // Exact permission revoked between the check and the call.
        debugPrint('Exact rest alert refused, using inexact: $e');
        await _plugin.zonedSchedule(
          id: nid,
          title: title,
          body: body,
          scheduledDate: at,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } on Object catch (e) {
      debugPrint('Rest alert schedule failed: $e');
    }
  }

  Future<bool> _canScheduleExact() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> cancel(String id) async {
    try {
      if (!await _ensureInitialised()) return;
      await _plugin.cancel(id: notificationIdFor(id));
    } on Object catch (e) {
      debugPrint('Rest alert cancel failed: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      if (!await _ensureInitialised()) return;
      // Only this app's notifications exist, and rest alerts are the only
      // ones it schedules.
      await _plugin.cancelAll();
    } on Object catch (e) {
      debugPrint('Rest alert cancel-all failed: $e');
    }
  }
}
