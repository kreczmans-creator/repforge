import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/platform/local_notifications_rest_alert_scheduler.dart';
import 'package:repforge/domain/training/rest_alert_scheduler.dart';

/// The adapter against a mocked plugin channel (no device): lazy
/// initialisation without a permission prompt, permission mapping, exact vs
/// inexact scheduling, and failures turned into safe results.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;
  late Object? Function(MethodCall) handler;

  setUp(() {
    calls = [];
    // On a device the generated plugin registrant does this.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    handler = (call) => switch (call.method) {
      'initialize' => true,
      'areNotificationsEnabled' => true,
      'requestNotificationsPermission' => true,
      'canScheduleExactNotifications' => true,
      'openAppNotificationSettings' => true,
      _ => null,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<String> names() => [for (final c in calls) c.method];

  test('notification ids are stable, positive 31-bit', () {
    expect(notificationIdFor('rest-timer'), notificationIdFor('rest-timer'));
    expect(notificationIdFor('a'), isNot(notificationIdFor('b')));
    expect(notificationIdFor('rest-timer'), inInclusiveRange(0, 0x7fffffff));
  });

  test('construction and nothing else touches the plugin', () {
    LocalNotificationsRestAlertScheduler();
    expect(calls, isEmpty);
  });

  test(
    'status initialises lazily once, creates the channel, no prompt',
    () async {
      final s = LocalNotificationsRestAlertScheduler();
      expect(await s.status(), NotificationPermission.granted);
      expect(await s.status(), NotificationPermission.granted);
      expect(names().where((n) => n == 'initialize'), hasLength(1));
      expect(names(), contains('createNotificationChannel'));
      expect(names(), isNot(contains('requestNotificationsPermission')));
      final channelCall = calls.firstWhere(
        (c) => c.method == 'createNotificationChannel',
      );
      expect((channelCall.arguments as Map)['name'], 'Rest timer');
    },
  );

  test(
    'uses the monochrome notification icon, not the launcher icon',
    () async {
      await LocalNotificationsRestAlertScheduler().status();
      final init = calls.firstWhere((c) => c.method == 'initialize');
      final icon = (init.arguments as Map)['defaultIcon'];
      expect(icon, LocalNotificationsRestAlertScheduler.smallIcon);
      expect(icon, isNot(contains('ic_launcher')));
    },
  );

  test('request maps granted and refused', () async {
    final s = LocalNotificationsRestAlertScheduler();
    expect(await s.request(), NotificationPermission.granted);
    handler = (call) =>
        call.method == 'requestNotificationsPermission' ? false : null;
    expect(await s.request(), NotificationPermission.denied);
  });

  test('a throwing plugin yields denied, false and no throw', () async {
    handler = (call) => throw PlatformException(code: 'boom');
    final s = LocalNotificationsRestAlertScheduler();
    expect(await s.status(), NotificationPermission.denied);
    expect(await s.request(), NotificationPermission.denied);
    expect(await s.openSettings(), isFalse);
    await s.schedule(
      id: 'x',
      endsAt: DateTime.now().add(const Duration(minutes: 1)),
      title: 't',
      body: 'b',
    );
    await s.cancel('x');
    await s.cancelAll();
  });

  test('schedules exact when allowed, inexact otherwise', () async {
    final s = LocalNotificationsRestAlertScheduler();
    final at = DateTime.now().add(const Duration(minutes: 2));
    await s.schedule(id: 'rest-timer', endsAt: at, title: 't', body: 'b');
    var scheduled = calls.lastWhere((c) => c.method == 'zonedSchedule');
    var specifics = (scheduled.arguments as Map)['platformSpecifics'] as Map;
    expect(specifics['scheduleMode'], 'exactAllowWhileIdle');

    calls.clear();
    handler = (call) =>
        call.method == 'canScheduleExactNotifications' ? false : null;
    await s.schedule(id: 'rest-timer', endsAt: at, title: 't', body: 'b');
    scheduled = calls.lastWhere((c) => c.method == 'zonedSchedule');
    specifics = (scheduled.arguments as Map)['platformSpecifics'] as Map;
    expect(specifics['scheduleMode'], 'inexactAllowWhileIdle');
  });

  test('a time in the past is not scheduled; cancel and cancelAll reach '
      'the plugin', () async {
    final s = LocalNotificationsRestAlertScheduler();
    await s.schedule(
      id: 'rest-timer',
      endsAt: DateTime.now().subtract(const Duration(seconds: 1)),
      title: 't',
      body: 'b',
    );
    expect(names(), isNot(contains('zonedSchedule')));
    await s.cancel('rest-timer');
    await s.cancelAll();
    expect(names(), containsAll(['cancel', 'cancelAll']));
  });

  test('unsupported platforms are safe no-ops', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final s = LocalNotificationsRestAlertScheduler();
    expect(await s.status(), NotificationPermission.denied);
    expect(await s.openSettings(), isFalse);
    await s.cancelAll();
    expect(calls, isEmpty);
  });
}
