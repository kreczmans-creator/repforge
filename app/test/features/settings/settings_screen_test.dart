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
      // Opening only reads the state; it never prompts or opens a screen.
      expect(scheduler.of('request'), isEmpty);
      expect(scheduler.of('openSettings'), isEmpty);
      expect(scheduler.of('requestExactTiming'), isEmpty);
      expect(scheduler.of('schedule'), isEmpty);
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

  group('rest alerts: exact timing and permission lifecycle (OQ-24)', () {
    late FakeRestAlertScheduler scheduler;

    Future<bool> stored() async => (await DriftSettingsRepository(
      db,
      clock: FixedClock(DateTime.utc(2026, 11, 3, 9)),
    ).read()).restTimerNotifications;

    Future<void> open(WidgetTester tester, {bool preferenceOn = false}) async {
      if (preferenceOn) {
        final repo = DriftSettingsRepository(
          db,
          clock: FixedClock(DateTime.utc(2026, 11, 3, 9)),
        );
        await repo.save(
          (await repo.read()).copyWith(restTimerNotifications: true),
        );
      }
      await tester.pumpWidget(_harness(db, scheduler));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('rest-notifications-switch')),
        300,
        scrollable: lastPageScrollable(),
      );
      await tester.pumpAndSettle();
    }

    Future<void> toggle(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('rest-notifications-switch')));
      await tester.pumpAndSettle();
    }

    String status(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('rest-alerts-status'))).data!;

    // The real binding checks transitions, so walk the path an OS does.
    Future<void> awayAndBack(WidgetTester tester) async {
      final b = TestWidgetsFlutterBinding.instance;
      [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ].forEach(b.handleAppLifecycleStateChanged);
      await tester.pumpAndSettle();
    }

    setUp(() => scheduler = FakeRestAlertScheduler());

    testWidgets('exact available: enabling shows no prompt, precise label', (
      tester,
    ) async {
      await open(tester);
      expect(status(tester), 'Off');
      await toggle(tester);
      expect(find.byKey(const Key('exact-timing-dialog')), findsNothing);
      expect(scheduler.of('requestExactTiming'), isEmpty);
      expect(await stored(), isTrue);
      expect(status(tester), contains('precise timing'));
      expect(find.byKey(const Key('rest-alerts-allow-exact')), findsNothing);
      await unmount(tester);
    });

    testWidgets('exact unavailable: explains, Not now keeps inexact and says '
        'timing may be delayed', (tester) async {
      scheduler.exactTiming = ExactTiming.unavailable;
      await open(tester);
      await toggle(tester);
      expect(find.byKey(const Key('exact-timing-dialog')), findsOneWidget);
      expect(find.textContaining('more reliably'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exact-timing-not-now')));
      await tester.pumpAndSettle();
      expect(scheduler.of('requestExactTiming'), isEmpty);
      expect(await stored(), isTrue);
      expect(status(tester), contains('may be delayed'));
      expect(status(tester), isNot(contains('precise timing:')));
      expect(find.byKey(const Key('rest-alerts-allow-exact')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Allow precise timing opens the route; return with the grant '
        'shows precise', (tester) async {
      scheduler
        ..exactTiming = ExactTiming.unavailable
        ..exactGrantedByRequest = true;
      await open(tester);
      await toggle(tester);
      await tester.tap(find.byKey(const Key('exact-timing-allow')));
      await tester.pumpAndSettle();
      expect(scheduler.of('requestExactTiming'), hasLength(1));
      expect(status(tester), contains('precise timing'));
      expect(find.byKey(const Key('rest-alerts-allow-exact')), findsNothing);
      await unmount(tester);
    });

    testWidgets('return from settings without the grant stays delayed; a '
        'later resume after granting there turns precise', (tester) async {
      scheduler.exactTiming = ExactTiming.unavailable;
      await open(tester);
      await toggle(tester);
      await tester.tap(find.byKey(const Key('exact-timing-allow')));
      await tester.pumpAndSettle();
      expect(scheduler.of('requestExactTiming'), hasLength(1));
      expect(status(tester), contains('may be delayed'));
      await awayAndBack(tester);
      expect(status(tester), contains('may be delayed'));
      // The user grants it later in system settings and comes back.
      scheduler.exactTiming = ExactTiming.available;
      await awayAndBack(tester);
      expect(status(tester), contains('precise timing'));
      await unmount(tester);
    });

    testWidgets('the delayed state offers the route again; revoking exact '
        'access later is shown on resume', (tester) async {
      await open(tester);
      await toggle(tester);
      expect(status(tester), contains('precise timing'));
      scheduler.exactTiming = ExactTiming.unavailable;
      await awayAndBack(tester);
      expect(status(tester), contains('may be delayed'));
      scheduler.exactGrantedByRequest = true;
      await tester.tap(find.byKey(const Key('rest-alerts-allow-exact')));
      await tester.pumpAndSettle();
      expect(scheduler.of('requestExactTiming'), hasLength(1));
      expect(status(tester), contains('precise timing'));
      await unmount(tester);
    });

    testWidgets('notification permission denied: stays off and explains', (
      tester,
    ) async {
      scheduler.permission = NotificationPermission.denied;
      await open(tester);
      await toggle(tester);
      expect(await stored(), isFalse);
      expect(find.byKey(const Key('exact-timing-dialog')), findsNothing);
      expect(find.byKey(const Key('rest-notifications-denied')), findsOne);
      expect(status(tester), 'Off');
      await unmount(tester);
    });

    testWidgets('revoked while on: shown as blocked, never as on; re-granting '
        'works again without re-toggling', (tester) async {
      await open(tester, preferenceOn: true);
      expect(status(tester), contains('precise timing'));
      scheduler.permission = NotificationPermission.denied;
      await awayAndBack(tester);
      expect(status(tester), startsWith('Blocked'));
      expect(status(tester), isNot(startsWith('On')));
      expect(find.byKey(const Key('rest-alerts-allow-exact')), findsNothing);
      await tester.tap(find.byKey(const Key('rest-alerts-open-settings')));
      await tester.pumpAndSettle();
      expect(scheduler.of('openSettings'), hasLength(1));
      // The stored preference is kept, so allowing it again is enough.
      expect(await stored(), isTrue);
      scheduler.permission = NotificationPermission.granted;
      await awayAndBack(tester);
      expect(status(tester), contains('precise timing'));
      expect(scheduler.of('request'), isEmpty);
      await unmount(tester);
    });

    testWidgets('re-enabling after turning off asks and explains again', (
      tester,
    ) async {
      scheduler.exactTiming = ExactTiming.unavailable;
      await open(tester);
      await toggle(tester);
      await tester.tap(find.byKey(const Key('exact-timing-not-now')));
      await tester.pumpAndSettle();
      await toggle(tester);
      expect(await stored(), isFalse);
      expect(status(tester), 'Off');
      await toggle(tester);
      expect(find.byKey(const Key('exact-timing-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('exact-timing-not-now')));
      await tester.pumpAndSettle();
      await unmount(tester);
    });

    testWidgets('iOS-like: no precision claim at all', (tester) async {
      scheduler.exactTiming = ExactTiming.notApplicable;
      await open(tester);
      await toggle(tester);
      expect(status(tester), 'On');
      expect(find.byKey(const Key('exact-timing-dialog')), findsNothing);
      await unmount(tester);
    });

    testWidgets('a failing platform is shown as blocked and never precise', (
      tester,
    ) async {
      scheduler.failing = true;
      await open(tester, preferenceOn: true);
      expect(status(tester), startsWith('Blocked'));
      expect(status(tester), isNot(contains('precise')));
      await unmount(tester);
    });
  });

  testWidgets('offers the owner actions workspace', (tester) async {
    tester.view.physicalSize = const Size(600, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-owner-actions')), findsOneWidget);
    expect(find.text('Owner Actions & Delivery Blockers'), findsOneWidget);
    await unmount(tester);
  });
  group('implied energy (GOL-002)', () {
    Future<void> type(WidgetTester tester, Map<String, String> values) async {
      for (final e in values.entries) {
        await tester.enterText(find.byKey(Key('target-${e.key}')), e.value);
      }
      await tester.pumpAndSettle();
    }

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_harness(db));
      await tester.pumpAndSettle();
    }

    testWidgets('shows protein x4 + carbs x4 + fat x9', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('implied-energy')), findsNothing);
      await type(tester, {'protein': '150', 'carbs': '250', 'fat': '70'});
      expect(find.text('Implied energy: 2230 kcal'), findsOneWidget);
      // No calorie target: no warning.
      expect(find.byKey(const Key('implied-energy-warning')), findsNothing);
      await unmount(tester);
    });

    testWidgets('no warning at exactly 10 %, warning above it', (tester) async {
      await open(tester);
      // 2200 kcal implied against 2000: exactly +10 %.
      await type(tester, {
        'calories': '2000',
        'protein': '150',
        'carbs': '400',
      });
      expect(find.text('Implied energy: 2200 kcal'), findsOneWidget);
      expect(find.byKey(const Key('implied-energy-warning')), findsNothing);
      // One more gram of fat: 2209 kcal, above 10 %.
      await type(tester, {'fat': '1'});
      expect(find.byKey(const Key('implied-energy-warning')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('no warning at exactly -10 %, warning below it', (
      tester,
    ) async {
      await open(tester);
      await type(tester, {
        'calories': '2000',
        'protein': '150',
        'carbs': '300',
      });
      expect(find.text('Implied energy: 1800 kcal'), findsOneWidget);
      expect(find.byKey(const Key('implied-energy-warning')), findsNothing);
      await type(tester, {'protein': '149'});
      expect(find.byKey(const Key('implied-energy-warning')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the warning never blocks saving', (tester) async {
      await open(tester);
      await type(tester, {
        'calories': '2000',
        'protein': '300',
        'carbs': '300',
      });
      expect(find.byKey(const Key('implied-energy-warning')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('save-targets')));
      await tester.tap(find.byKey(const Key('save-targets')));
      await tester.pumpAndSettle();
      expect(find.text('Targets saved'), findsOneWidget);
      final goals = await DriftGoalRepositoryProbe(db).active();
      expect(goals[GoalKind.calories], 2000);
      expect(goals[GoalKind.protein], 300);
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
