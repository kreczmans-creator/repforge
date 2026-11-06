import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/rest_alert_scheduler.dart';
import 'package:repforge/domain/training/training.dart';

import '../../../helpers/pump.dart';
import '../../../helpers/scrolling.dart';
import '../../../helpers/session_harness.dart';

WorkoutPlan _plan(DateTime at) => WorkoutPlan(
  id: 'plan',
  name: 'Leg day plan',
  createdAt: at.toUtc(),
  updatedAt: at.toUtc(),
  exercises: [
    PlanExercise(
      id: 'pe0',
      exerciseId: 'squat',
      sortOrder: 0,
      targetSets: 3,
      repsMin: 5,
      repsMax: 5,
      targetLoad: kg(75),
      restSeconds: 60,
    ),
  ],
);

void main() {
  late SessionHarness h;
  setUp(() async {
    h = SessionHarness();
    await h.seedExercises();
  });
  tearDown(() => h.db.close());

  testWidgets('full session: plan, pre-filled sets, rest timer, PR, finish, '
      'history, delete with undo, restore', (tester) async {
    await h.seed(
      pastSession(
        'past',
        started: DateTime(2026, 11, 3, 9),
        sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
      ),
    );
    await h.plans.upsert(_plan(h.now));
    await h.open(tester, location: RfRoutes.trainPlans);

    // Start from the plan; the previous performance wins over the target.
    await h.tap(tester, 'plan-start-plan');
    final session = await h.latest();
    final id = session.exercises.single.id;
    expect(h.textOf(tester, 'prev-hint-$id'), 'Last: 80 kg × 5');
    expect(h.fieldText(tester, 'newset-$id-load'), '80');

    // Set 1: one tap on the pre-filled row.
    h.taps = 0;
    await h.tap(tester, 'newset-log-$id');
    expect(h.taps, lessThanOrEqualTo(2));

    // The rest timer runs from the planned 60 s on the injected clock.
    expect(h.textOf(tester, 'rest-remaining'), '1:00');
    h.clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    expect(h.textOf(tester, 'rest-remaining'), '0:50');
    await h.tap(tester, 'rest-extend');
    expect(h.textOf(tester, 'rest-remaining'), '1:05');
    await h.tap(tester, 'rest-skip');
    expect(find.byKey(const Key('rest-timer-panel')), findsNothing);

    // Set 2: 82.5 x 5 beats the 80 x 5 best at five reps: PR.
    await h.enter(tester, 'newset-$id-load', '82.5');
    await h.tap(tester, 'newset-log-$id');
    final sets = (await h.sessions.byId(session.id))!.sets;
    final pr = sets.firstWhere((s) => s.data == weighted(82.5, 5));
    expect(find.byKey(Key('pr-badge-${pr.id}')), findsOneWidget);
    expect(h.textOf(tester, 'session-volume'), 'Volume: 812.5 kg');

    // Finish: the summary opens and the workout is in the history.
    await h.tap(tester, 'finish-session');
    expect(find.byKey(const Key('detail-title')), findsOneWidget);
    expect(find.byKey(Key('pr-badge-${pr.id}')), findsOneWidget);
    GoRouter.of(tester.element(find.byKey(const Key('detail-title'))))
        .go(RfRoutes.trainHistory);
    await h.settle(tester);
    expect(find.byKey(Key('history-session-${session.id}')), findsOneWidget);
    expect(find.byKey(const Key('history-session-past')), findsOneWidget);

    // Delete with confirmation, then Undo restores it.
    await h.tap(tester, 'history-session-${session.id}');
    await h.tap(tester, 'detail-delete');
    await h.tap(tester, 'delete-session-confirm');
    expect(find.byKey(Key('history-session-${session.id}')), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    await tester.tap(find.text('Undo'));
    await h.settle(tester);
    expect(find.byKey(Key('history-session-${session.id}')), findsOneWidget);
    expect((await h.sessions.byId(session.id))!.sets, hasLength(2));
    await tester.pump(const Duration(seconds: 15));
    await unmount(tester);
  });

  testWidgets('settings: default rest and the notifications switch', (
    tester,
  ) async {
    await h.open(tester, location: RfRoutes.settings);
    expect(h.fieldText(tester, 'default-rest'), '90');
    await h.enter(tester, 'default-rest', '120');
    await h.tap(tester, 'save-default-rest');
    expect((await h.settings.read()).defaultRestSeconds, 120);

    await h.enter(tester, 'default-rest', '4000');
    await h.tap(tester, 'save-default-rest');
    expect(find.text('Default rest must be 0–3600 seconds.'), findsOneWidget);
    expect((await h.settings.read()).defaultRestSeconds, 120);

    expect((await h.settings.read()).restTimerNotifications, isFalse);
    await h.tap(tester, 'rest-notifications-switch');
    expect((await h.settings.read()).restTimerNotifications, isTrue);
    await unmount(tester);
  });

  testWidgets('rest notification follows the session screen (ADR-0007)', (
    tester,
  ) async {
    await h.setSettings(
      (await h.settings.read()).copyWith(restTimerNotifications: true),
    );
    await h.plans.upsert(_plan(h.now));
    await h.open(tester, location: RfRoutes.trainPlans);
    await h.tap(tester, 'plan-start-plan');
    final id = (await h.latest()).exercises.single.id;

    await h.tap(tester, 'newset-log-$id');
    await h.settle(tester);
    // Nothing is scheduled in the foreground; the background schedules.
    expect(h.scheduler.scheduled, isEmpty);
    final binding = TestWidgetsFlutterBinding.instance;
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    // `inactive` counts as background but still draws frames (paused stops
    // them, so the buttons below could not be tapped).
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await h.settle(tester);
    expect(
      h.scheduler.scheduled['rest-timer'],
      h.now.add(const Duration(seconds: 60)),
    );
    await h.tap(tester, 'rest-extend');
    await h.settle(tester);
    expect(
      h.scheduler.scheduled['rest-timer'],
      h.now.add(const Duration(seconds: 75)),
    );
    await h.tap(tester, 'rest-pause');
    await h.settle(tester);
    expect(h.scheduler.scheduled, isEmpty);
    await h.tap(tester, 'rest-resume');
    await h.settle(tester);
    expect(h.scheduler.scheduled, hasLength(1));
    // Finishing the session skips the timer and cancels the alert.
    await h.tap(tester, 'finish-session');
    await h.settle(tester);
    expect(h.scheduler.scheduled, isEmpty);
    await unmount(tester);
  });

  testWidgets('revoked notification permission never blocks logging or the '
      'timer; re-granting schedules again (OQ-24)', (tester) async {
    await h.setSettings(
      (await h.settings.read()).copyWith(restTimerNotifications: true),
    );
    h.scheduler.permission = NotificationPermission.denied;
    await h.plans.upsert(_plan(h.now));
    await h.open(tester, location: RfRoutes.trainPlans);
    await h.tap(tester, 'plan-start-plan');
    final id = (await h.latest()).exercises.single.id;

    final binding = TestWidgetsFlutterBinding.instance;
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await h.settle(tester);
    await h.tap(tester, 'newset-log-$id');
    await h.settle(tester);
    expect((await h.latest()).sets, hasLength(1));
    expect(h.textOf(tester, 'rest-remaining'), '1:00');
    expect(h.scheduler.scheduled, isEmpty);
    expect(h.scheduler.of('schedule'), isEmpty);

    h.scheduler.permission = NotificationPermission.granted;
    await h.tap(tester, 'rest-extend');
    await h.settle(tester);
    expect(h.scheduler.scheduled, hasLength(1));
    await unmount(tester);
  });

  testWidgets('exercise history shows set kind and PR badges', (tester) async {
    await h.seed(
      pastSession(
        'a',
        started: DateTime(2026, 11, 1, 9),
        sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
      ),
    );
    await h.sessions.addSet(
      SessionSet(
        id: 'a-warm',
        sessionId: 'a',
        exerciseId: 'squat',
        exerciseOrder: 0,
        setOrder: 5,
        data: weighted(40, 10),
        completed: true,
        kind: SetKind.warmUp,
      ),
    );
    await h.open(tester, location: RfRoutes.trainExercise('squat'));
    expect(find.byKey(const Key('pr-badge-a-s0')), findsOneWidget);
    expect(find.byKey(const Key('pr-badge-a-warm')), findsNothing);
    expect(h.textOf(tester, 'history-kind-a-warm'), 'Warm-up');
    await unmount(tester);
  });

  group('layout at 360x690 with text scale 1.3', () {
    const size = Size(360, 690);

    void noOverflow(WidgetTester tester) {
      expect(tester.takeException(), isNull);
    }

    Future<void> expectTarget(WidgetTester tester, String key) async {
      final f = find.byKey(Key(key));
      if (f.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          f,
          200,
          scrollable: lastPageScrollable(),
        );
      }
      final s = tester.getSize(f);
      expect(s.height, greaterThanOrEqualTo(48), reason: key);
      expect(s.width, greaterThanOrEqualTo(48), reason: key);
    }

    testWidgets('session screen with sets, details and the rest timer', (
      tester,
    ) async {
      await h.seed(
        pastSession(
          'past',
          started: DateTime(2026, 11, 3, 9),
          sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
        ),
      );
      await h.setSettings(const AppSettings(exertionScale: ExertionScale.rir));
      await h.plans.upsert(_plan(h.now));
      await h.open(
        tester,
        location: RfRoutes.trainPlans,
        size: size,
        textScale: 1.3,
      );
      await h.tap(tester, 'plan-start-plan');
      noOverflow(tester);
      await expectTarget(tester, 'session-note-edit');
      final session = await h.latest();
      final id = session.exercises.single.id;
      await h.tap(tester, 'newset-details-$id');
      noOverflow(tester);
      await h.tap(tester, 'newset-log-$id');
      noOverflow(tester);
      final set = (await h.sessions.byId(session.id))!.sets.single;

      for (final key in [
        'newset-log-$id',
        'newset-details-$id',
        'set-edit-${set.id}',
        'set-delete-${set.id}',
        'entry-up-$id',
        'entry-menu-$id',
        'add-exercise',
        'finish-session',
        'rest-extend',
        'rest-skip',
        'rest-pause',
      ]) {
        await expectTarget(tester, key);
      }

      await h.tap(tester, 'set-edit-${set.id}');
      noOverflow(tester);
      await expectTarget(tester, 'editset-save');
      await h.tap(tester, 'editset-cancel');
      noOverflow(tester);
      await unmount(tester);
    });

    testWidgets('a cardio exercise row, history, detail, settings', (
      tester,
    ) async {
      await h.exercises.upsert(
        exercise('row', 'Rowing', type: ExerciseType.cardio, at: h.now),
      );
      await h.seed(
        pastSession(
          'a',
          started: DateTime(2026, 11, 1, 9),
          notes: List.filled(40, 'long note').join(' '),
          sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
        ),
      );
      await h.open(
        tester,
        location: RfRoutes.trainHistory,
        size: size,
        textScale: 1.3,
      );
      noOverflow(tester);
      await expectTarget(tester, 'history-repeat-a');
      await h.tap(tester, 'history-session-a');
      noOverflow(tester);
      for (final key in [
        'detail-edit-details',
        'detail-edit-sets',
        'detail-repeat',
        'detail-delete',
      ]) {
        await expectTarget(tester, key);
      }
      await h.tap(tester, 'detail-edit-sets');
      await h.tap(tester, 'add-exercise');
      await h.tap(tester, 'picker-exercise-row');
      noOverflow(tester);
      final row = (await h.latest()).exercises.last.id;
      // The cardio row has three fields: no overflow.
      expect(find.byKey(Key('newset-$row-hr')), findsOneWidget);
      await unmount(tester);

      await h.open(
        tester,
        location: RfRoutes.settings,
        size: size,
        textScale: 1.3,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('rest-notifications-switch')),
        300,
        scrollable: lastPageScrollable(),
      );
      await tester.pump();
      noOverflow(tester);
      await unmount(tester);
    });
  });
}
