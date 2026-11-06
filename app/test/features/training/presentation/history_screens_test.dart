import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/presentation/session_detail_screen.dart';

import '../../../helpers/pump.dart';
import '../../../helpers/session_harness.dart';

void main() {
  late SessionHarness h;
  setUp(() async {
    h = SessionHarness();
    await h.seedExercises();
  });
  tearDown(() => h.db.close());

  testWidgets('history lists 20 newest first, then more on scroll '
      '(TRN-025(2))', (tester) async {
    for (var i = 0; i < 25; i++) {
      await h.seed(
        pastSession(
          's$i',
          started: DateTime(2026, 10, 1, 9).add(Duration(days: i)),
          name: 'Workout $i',
          sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
        ),
      );
    }
    await h.open(
      tester,
      location: RfRoutes.trainHistory,
      size: const Size(390, 700),
    );
    expect(find.byKey(const Key('history-session-s24')), findsOneWidget);
    // Newest first.
    expect(
      tester.getTopLeft(find.byKey(const Key('history-session-s24'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('history-session-s23'))).dy,
      ),
    );
    expect(find.byKey(const Key('history-session-s5')), findsNothing);
    expect(h.textOf(tester, 'history-volume-s24'), 'Volume: 400 kg');

    await tester.dragUntilVisible(
      find.byKey(const Key('history-session-s5')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await h.settle(tester);
    await tester.dragUntilVisible(
      find.byKey(const Key('history-session-s0')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.byKey(const Key('history-session-s0')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the Show more button loads the next page', (tester) async {
    for (var i = 0; i < 22; i++) {
      await h.seed(
        pastSession(
          's$i',
          started: DateTime(2026, 10, 1, 9).add(Duration(days: i)),
        ),
      );
    }
    await h.open(tester, location: RfRoutes.trainHistory);
    expect(find.byKey(const Key('history-session-s0')), findsNothing);
    await h.tap(tester, 'history-load-more');
    expect(find.byKey(const Key('history-session-s0')), findsOneWidget);
    expect(find.byKey(const Key('history-load-more')), findsNothing);
    await unmount(tester);
  });

  testWidgets('an empty history says so', (tester) async {
    await h.open(tester, location: RfRoutes.trainHistory);
    expect(find.byKey(const Key('history-list-empty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('detail shows notes, kinds, exertion, PR and volume', (
    tester,
  ) async {
    await h.seed(
      pastSession(
        'a',
        started: DateTime(2026, 11, 1, 9),
        sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
      ),
    );
    final b = pastSession(
      'b',
      started: DateTime(2026, 11, 3, 9),
      notes: 'Felt strong',
    );
    await h.sessions.upsert(b);
    await h.sessions.addExercise(
      const SessionExercise(
        id: 'e-b',
        sessionId: 'b',
        exerciseId: 'squat',
        position: 0,
        note: 'Belt on',
      ),
    );
    await h.sessions.addSet(
      SessionSet(
        id: 'b-warm',
        sessionId: 'b',
        exerciseId: 'squat',
        exerciseOrder: 0,
        setOrder: 0,
        sessionExerciseId: 'e-b',
        data: weighted(40, 10),
        completed: true,
        kind: SetKind.warmUp,
      ),
    );
    await h.sessions.addSet(
      SessionSet(
        id: 'b-top',
        sessionId: 'b',
        exerciseId: 'squat',
        exerciseOrder: 0,
        setOrder: 1,
        sessionExerciseId: 'e-b',
        data: weighted(82.5, 5),
        completed: true,
        kind: SetKind.failure,
        exertion: const Exertion(scale: ExertionScale.rpe, value: 9.5),
      ),
    );
    await h.open(tester, location: RfRoutes.trainHistoryDetail('b'));
    expect(h.textOf(tester, 'detail-note'), 'Felt strong');
    expect(h.textOf(tester, 'detail-entry-note-e-b'), 'Belt on');
    expect(h.textOf(tester, 'detail-set-b-warm'), '40 kg × 10 · Warm-up');
    expect(
      h.textOf(tester, 'detail-set-b-top'),
      '82.5 kg × 5 · Failure · RPE 9.5',
    );
    expect(find.byKey(const Key('pr-badge-b-top')), findsOneWidget);
    expect(find.byKey(const Key('pr-badge-b-warm')), findsNothing);
    expect(h.textOf(tester, 'detail-volume'), 'Volume: 412.5 kg');
    expect(h.textOf(tester, 'detail-entry-volume-e-b'), 'Volume: 412.5 kg');
    await unmount(tester);
  });

  testWidgets('edit details: name and length', (tester) async {
    await h.seed(pastSession('a', started: DateTime(2026, 11, 1, 9)));
    await h.open(tester, location: RfRoutes.trainHistoryDetail('a'));
    await h.tap(tester, 'detail-edit-details');
    await h.enter(tester, 'details-name', 'Heavy legs');
    await h.enter(tester, 'details-minutes', '75');
    await h.tap(tester, 'details-save');
    final s = (await h.sessions.byId('a'))!;
    expect(s.name, 'Heavy legs');
    expect(s.endedAt!.difference(s.startedAt), const Duration(minutes: 75));
    expect(h.textOf(tester, 'detail-title'), 'Heavy legs');

    // An empty name is refused by the use case.
    await h.tap(tester, 'detail-edit-details');
    await h.enter(tester, 'details-name', '  ');
    await h.tap(tester, 'details-save');
    expect(find.text('Enter a name.'), findsOneWidget);
    expect((await h.sessions.byId('a'))!.name, 'Heavy legs');
    await unmount(tester);
  });

  testWidgets('delete asks, undo stays at least 10 s and restores', (
    tester,
  ) async {
    await h.plans.upsert(
      WorkoutPlan(
        id: 'plan',
        name: 'Plan',
        createdAt: h.now.toUtc(),
        updatedAt: h.now.toUtc(),
      ),
    );
    await h.seed(
      pastSession(
        'a',
        started: DateTime(2026, 11, 1, 9),
        planId: 'plan',
        sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
      ),
    );
    await h.scheduled.upsert(
      ScheduledWorkout(
        id: 'occ',
        planId: 'plan',
        day: DateTime(2026, 11),
        sourceDay: DateTime(2026, 11),
        origin: ScheduleOrigin.date,
        status: ScheduleStatus.done,
        sessionId: 'a',
        createdAt: h.now.toUtc(),
        updatedAt: h.now.toUtc(),
      ),
    );
    await h.open(tester, location: RfRoutes.trainHistory);
    await h.tap(tester, 'history-session-a');
    await h.tap(tester, 'detail-delete');
    await h.tap(tester, 'confirm-cancel');
    expect(await h.sessions.byId('a'), isNotNull);

    await h.tap(tester, 'detail-delete');
    await h.tap(tester, 'delete-session-confirm');
    expect(await h.sessions.byId('a'), isNull);
    expect(find.byKey(const Key('history-session-a')), findsNothing);
    final snack = tester.widget<SnackBar>(
      find.byKey(const Key('session-deleted-snackbar')),
    );
    expect(snack.duration, greaterThanOrEqualTo(const Duration(seconds: 10)));
    expect(snack.duration, sessionUndoWindow);

    // Still there 10 s later; Undo restores the workout and its link.
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(const Key('session-deleted-snackbar')), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await h.settle(tester);
    final restored = (await h.sessions.byId('a'))!;
    expect(restored.sets, hasLength(1));
    expect((await h.scheduled.byId('occ'))!.status, ScheduleStatus.done);
    expect(find.byKey(const Key('history-session-a')), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    await unmount(tester);
  });

  testWidgets('without Undo the snackbar goes away and the delete stands', (
    tester,
  ) async {
    await h.seed(pastSession('a', started: DateTime(2026, 11, 1, 9)));
    await h.open(tester, location: RfRoutes.trainHistoryDetail('a'));
    await h.tap(tester, 'detail-delete');
    await h.tap(tester, 'delete-session-confirm');
    // No page below the detail screen: it falls back to the history.
    expect(find.byKey(const Key('history-list-empty')), findsOneWidget);
    // The timer starts once the snackbar has animated in.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byKey(const Key('session-deleted-snackbar')), findsNothing);
    expect(await h.sessions.byId('a'), isNull);
    await unmount(tester);
  });

  testWidgets('edit sets opens the session screen; a missing id says so', (
    tester,
  ) async {
    await h.seed(
      pastSession(
        'a',
        started: DateTime(2026, 11, 1, 9),
        sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
      ),
    );
    await h.open(tester, location: RfRoutes.trainHistoryDetail('a'));
    await h.tap(tester, 'detail-edit-sets');
    expect(find.byKey(const Key('set-a-s0')), findsOneWidget);
    expect(find.byKey(const Key('finish-session')), findsNothing);
    await unmount(tester);

    await h.open(tester, location: RfRoutes.trainSession('nope'));
    expect(find.byKey(const Key('session-missing')), findsOneWidget);
    await unmount(tester);
    await h.open(tester, location: RfRoutes.trainHistoryDetail('nope'));
    expect(find.byKey(const Key('detail-missing')), findsOneWidget);
    await unmount(tester);
  });
}
