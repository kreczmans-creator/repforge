import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/platform/fake_rest_alert_scheduler.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/features/training/application/rest_timer_controller.dart';

import '../../helpers/session_harness.dart';

/// ADR-0007: the notification at the timer's end time follows every timer
/// change and the `restTimerNotifications` setting (TRN-022(2), PLT-007).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late MutableClock clock;
  late FakeRestAlert alert;
  late FakeRestAlertScheduler scheduler;
  late ProviderContainer container;

  Future<void> setup({required bool enabled}) async {
    db = AppDatabase.inMemory();
    clock = MutableClock(DateTime(2026, 11, 5, 9));
    alert = FakeRestAlert();
    scheduler = FakeRestAlertScheduler();
    final settings = DriftSettingsRepository(
      db,
      clock: FixedClock(clock.now()),
    );
    await settings.save(
      (await settings.read()).copyWith(restTimerNotifications: enabled),
    );
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        restAlertProvider.overrideWithValue(alert),
        restAlertSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  RestTimerController ctl() => container.read(restTimerProvider.notifier);

  /// Lets the asynchronous settings read and the scheduler calls complete.
  Future<void> flush() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  DateTime? scheduledEnd() => scheduler.scheduled[restNotificationId];

  test('schedules at the end time when the setting is on', () async {
    await setup(enabled: true);
    ctl().start(defaultRestSeconds: 90);
    await flush();
    expect(scheduledEnd(), clock.now().add(const Duration(seconds: 90)));
    expect(scheduler.texts[restNotificationId], (
      restNotificationTitle,
      restNotificationBody,
    ));
    expect(scheduler.of('request'), isEmpty);
  });

  test('schedules nothing when the setting is off', () async {
    await setup(enabled: false);
    ctl().start(defaultRestSeconds: 90);
    await flush();
    ctl()
      ..extend()
      ..pause()
      ..resume()
      ..skip();
    await flush();
    expect(scheduler.calls, isEmpty);
    // The timer itself is unaffected.
    expect(container.read(restTimerProvider).timer.status.name, 'idle');
  });

  test('pause cancels, resume reschedules from the time left', () async {
    await setup(enabled: true);
    ctl().start(defaultRestSeconds: 60);
    await flush();
    clock.advance(const Duration(seconds: 20));
    ctl().pause();
    await flush();
    expect(scheduledEnd(), isNull);
    expect(scheduler.of('cancel'), hasLength(1));
    clock.advance(const Duration(minutes: 5));
    ctl().resume();
    await flush();
    expect(scheduledEnd(), clock.now().add(const Duration(seconds: 40)));
  });

  test('extend reschedules 15 s later', () async {
    await setup(enabled: true);
    ctl().start(defaultRestSeconds: 60);
    await flush();
    final first = scheduledEnd()!;
    ctl().extend();
    await flush();
    expect(scheduledEnd(), first.add(const Duration(seconds: 15)));
    expect(scheduler.scheduled, hasLength(1));
  });

  test('skip cancels', () async {
    await setup(enabled: true);
    ctl().start(defaultRestSeconds: 60);
    await flush();
    ctl().skip();
    await flush();
    expect(scheduledEnd(), isNull);
    expect(scheduler.of('cancel'), hasLength(1));
  });

  test('a new timer replaces the scheduled one; a 0 s rest cancels', () async {
    await setup(enabled: true);
    ctl().start(defaultRestSeconds: 60);
    await flush();
    clock.advance(const Duration(seconds: 5));
    ctl().start(defaultRestSeconds: 30);
    await flush();
    expect(scheduler.scheduled, hasLength(1));
    expect(scheduledEnd(), clock.now().add(const Duration(seconds: 30)));
    ctl().start(plannedRestSeconds: 0, defaultRestSeconds: 30);
    await flush();
    expect(scheduledEnd(), isNull);
  });

  test('finishing the session (skip) cancels; later changes do not '
      'reschedule', () async {
    await setup(enabled: true);
    ctl().start(defaultRestSeconds: 60);
    await flush();
    ctl().skip();
    await flush();
    ctl().check();
    await flush();
    expect(scheduler.scheduled, isEmpty);
  });

  test('at zero in the foreground the notification is dropped', () async {
    await setup(enabled: true);
    ctl().start(defaultRestSeconds: 30);
    await flush();
    clock.advance(const Duration(seconds: 30));
    ctl().check();
    await flush();
    expect(alert.fired, 1);
    expect(scheduledEnd(), isNull);
  });

  test('at zero in the background the notification is left alone', () async {
    await setup(enabled: true);
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    addTearDown(
      () => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    ctl().start(defaultRestSeconds: 30);
    await flush();
    clock.advance(const Duration(seconds: 30));
    ctl().check();
    await flush();
    expect(scheduledEnd(), isNotNull);
  });

  test('a failing scheduler never breaks the timer', () async {
    await setup(enabled: true);
    scheduler.failing = true;
    ctl().start(defaultRestSeconds: 30);
    await flush();
    ctl()
      ..extend()
      ..pause()
      ..skip();
    await flush();
    expect(container.read(restTimerProvider).timer.status.name, 'idle');
  });

  test(
    'turning the setting on mid-timer schedules at the next change',
    () async {
      await setup(enabled: false);
      ctl().start(defaultRestSeconds: 60);
      await flush();
      expect(scheduler.calls, isEmpty);
      final settings = DriftSettingsRepository(
        db,
        clock: FixedClock(clock.now()),
      );
      await settings.save(
        (await settings.read()).copyWith(restTimerNotifications: true),
      );
      ctl().extend();
      await flush();
      expect(scheduledEnd(), clock.now().add(const Duration(seconds: 75)));
    },
  );
}
