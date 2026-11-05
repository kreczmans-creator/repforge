import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/platform/fake_rest_alert_scheduler.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/rest_alert_scheduler.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/settings/presentation/settings_screen.dart';
import 'package:repforge/ui/theme.dart';

import '../../helpers/pump.dart';
import '../../helpers/scrolling.dart';

Widget _harness(AppDatabase db, [RestAlertScheduler? scheduler]) =>
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (scheduler != null)
          restAlertSchedulerProvider.overrideWithValue(scheduler),
        clockProvider.overrideWithValue(
          FixedClock(DateTime.utc(2026, 11, 3, 9)),
        ),
      ],
      child: MaterialApp(
        theme: rfTheme(Brightness.dark),
        home: const SettingsScreen(),
      ),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  testWidgets('saves targets as goals and persists them', (tester) async {
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('target-calories')), '2300');
    await tester.enterText(find.byKey(const Key('target-protein')), '170');
    await tester.ensureVisible(find.byKey(const Key('save-targets')));
    await tester.tap(find.byKey(const Key('save-targets')));
    await tester.pumpAndSettle();

    expect(find.text('Targets saved'), findsOneWidget);
    final goals = await DriftGoalRepositoryProbe(db).active();
    expect(goals[GoalKind.calories], 2300);
    expect(goals[GoalKind.protein], 170);
    await unmount(tester);
  });

  testWidgets('shows a field error for an invalid target', (tester) async {
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target-calories')), '100');
    await tester.ensureVisible(find.byKey(const Key('save-targets')));
    await tester.tap(find.byKey(const Key('save-targets')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Must be between 800 and 10000'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('changing units and theme persists settings', (tester) async {
    tester.view.physicalSize = const Size(600, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    Finder segment(String key, String label) =>
        find.descendant(of: find.byKey(Key(key)), matching: find.text(label));
    await tester.ensureVisible(find.byKey(const Key('units-choice')));
    await tester.tap(segment('units-choice', 'Imperial'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('theme-choice')));
    await tester.tap(segment('theme-choice', 'Light'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final s = await container.read(settingsRepositoryProvider).read();
    expect(s.units, UnitSystem.imperial);
    expect(s.theme, ThemePreference.light);
    await unmount(tester);
  });

  group('rest timer notifications switch (PLT-007)', () {
    Future<bool> stored() async => (await DriftSettingsRepository(
      db,
      clock: FixedClock(DateTime.utc(2026, 11, 3, 9)),
    ).read()).restTimerNotifications;

    Future<void> openAndScroll(
      WidgetTester tester,
      RestAlertScheduler s,
    ) async {
      await tester.pumpWidget(_harness(db, s));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('rest-notifications-switch')),
        300,
        scrollable: lastPageScrollable(),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('nothing is requested until the switch is turned on', (
      tester,
    ) async {
      final scheduler = FakeRestAlertScheduler();
      await openAndScroll(tester, scheduler);
      expect(scheduler.calls, isEmpty);
      await unmount(tester);
    });

    testWidgets('turning it on requests permission and saves when granted', (
      tester,
    ) async {
      final scheduler = FakeRestAlertScheduler();
      await openAndScroll(tester, scheduler);
      await tester.tap(find.byKey(const Key('rest-notifications-switch')));
      await tester.pumpAndSettle();
      expect(scheduler.of('request'), hasLength(1));
      expect(await stored(), isTrue);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('rest-notifications-switch')),
            )
            .value,
        isTrue,
      );
      await unmount(tester);
    });

    testWidgets('a refusal keeps it off, explains and offers settings', (
      tester,
    ) async {
      final scheduler = FakeRestAlertScheduler(
        permission: NotificationPermission.denied,
      );
      await openAndScroll(tester, scheduler);
      await tester.tap(find.byKey(const Key('rest-notifications-switch')));
      await tester.pumpAndSettle();
      expect(scheduler.of('request'), hasLength(1));
      expect(await stored(), isFalse);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('rest-notifications-switch')),
            )
            .value,
        isFalse,
      );
      expect(find.textContaining('Notifications are not allowed'), findsOne);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(scheduler.of('openSettings'), hasLength(1));
      await unmount(tester);
    });

    testWidgets('a failing platform counts as refused', (tester) async {
      final scheduler = FakeRestAlertScheduler(failing: true);
      await openAndScroll(tester, scheduler);
      await tester.tap(find.byKey(const Key('rest-notifications-switch')));
      await tester.pumpAndSettle();
      expect(await stored(), isFalse);
      await unmount(tester);
    });

    testWidgets('turning it off cancels every scheduled alert', (tester) async {
      final scheduler = FakeRestAlertScheduler();
      await openAndScroll(tester, scheduler);
      await tester.tap(find.byKey(const Key('rest-notifications-switch')));
      await tester.pumpAndSettle();
      scheduler.scheduled['rest-timer'] = DateTime(2030);
      await tester.tap(find.byKey(const Key('rest-notifications-switch')));
      await tester.pumpAndSettle();
      expect(scheduler.of('cancelAll'), hasLength(1));
      expect(scheduler.scheduled, isEmpty);
      expect(await stored(), isFalse);
      await unmount(tester);
    });

    testWidgets('a failing cancel does not block turning it off', (
      tester,
    ) async {
      final scheduler = FakeRestAlertScheduler();
      await openAndScroll(tester, scheduler);
      await tester.tap(find.byKey(const Key('rest-notifications-switch')));
      await tester.pumpAndSettle();
      scheduler.failing = true;
      await tester.tap(find.byKey(const Key('rest-notifications-switch')));
      await tester.pumpAndSettle();
      expect(await stored(), isFalse);
      await unmount(tester);
    });
  });
}

/// Reads active nutrition goals straight from the table for assertions.
final class DriftGoalRepositoryProbe {
  DriftGoalRepositoryProbe(this.db);
  final AppDatabase db;

  Future<Map<GoalKind, double>> active() async {
    final rows = await (db.select(
      db.goals,
    )..where((t) => t.active.equals(true))).get();
    final out = <GoalKind, double>{};
    for (final r in rows) {
      final k = GoalKind.values.asNameMap()[r.kind];
      if (k != null) out[k] = r.target;
    }
    return out;
  }
}
