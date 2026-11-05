import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/training/rest_timer.dart';
import 'package:repforge/features/training/application/haptic_rest_alert.dart';
import 'package:repforge/features/training/application/rest_timer_controller.dart';

import '../../helpers/session_harness.dart';

void main() {
  hapticTests();
  late MutableClock clock;
  late FakeRestAlert alert;
  late ProviderContainer container;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
    clock = MutableClock(DateTime(2026, 11, 5, 9));
    alert = FakeRestAlert();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        restAlertProvider.overrideWithValue(alert),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  RestTimerController ctl() => container.read(restTimerProvider.notifier);
  RestTimerState state() => container.read(restTimerProvider);

  test('starts from the planned rest, else the default', () {
    ctl().start(plannedRestSeconds: 60, defaultRestSeconds: 90);
    expect(state().timer.remaining(clock.now()), const Duration(seconds: 60));
    ctl().start(defaultRestSeconds: 90);
    expect(state().timer.remaining(clock.now()), const Duration(seconds: 90));
  });

  test('a rest of 0 s starts no timer', () {
    ctl().start(plannedRestSeconds: 0, defaultRestSeconds: 90);
    expect(state().timer.status, RestTimerStatus.idle);
  });

  test('pause, resume and +15 s follow the clock', () {
    ctl().start(defaultRestSeconds: 60);
    clock.advance(const Duration(seconds: 10));
    ctl().pause();
    clock.advance(const Duration(minutes: 5));
    expect(state().timer.remaining(clock.now()), const Duration(seconds: 50));
    ctl().resume();
    ctl().extend();
    expect(state().timer.remaining(clock.now()), const Duration(seconds: 65));
  });

  test('the alert fires once at zero and not after skip', () {
    ctl().start(defaultRestSeconds: 30);
    clock.advance(const Duration(seconds: 29));
    ctl().check();
    expect(alert.fired, 0);
    clock.advance(const Duration(seconds: 1));
    ctl()
      ..check()
      ..check();
    expect(alert.fired, 1);
    expect(state().alerted, isTrue);
    // Extending a finished timer restarts it and re-arms the alert.
    ctl().extend();
    expect(state().alerted, isFalse);
    ctl().skip();
    clock.advance(const Duration(minutes: 5));
    ctl().check();
    expect(alert.fired, 1);
  });
}

void hapticTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the default alert uses haptics and the system sound only', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await const HapticRestAlert().fire();
    expect(calls, ['HapticFeedback.vibrate', 'SystemSound.play']);
  });

  test('a failing platform call never throws', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => throw PlatformException(code: 'no'),
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await const HapticRestAlert().fire();
  });
}
