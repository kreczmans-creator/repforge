import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';

import '../../../helpers/pump.dart';
import '../../../helpers/session_harness.dart';

WorkoutPlan _plan(
  DateTime at, {
  String id = 'plan',
  int? rest,
  List<String> exerciseIds = const ['squat'],
}) => WorkoutPlan(
  id: id,
  name: 'Leg day plan',
  createdAt: at.toUtc(),
  updatedAt: at.toUtc(),
  exercises: [
    for (var i = 0; i < exerciseIds.length; i++)
      PlanExercise(
        id: 'pe$i',
        exerciseId: exerciseIds[i],
        sortOrder: i,
        targetSets: 3,
        repsMin: 8,
        repsMax: 10,
        targetLoad: kg(60),
        restSeconds: rest,
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

  Future<String> startFromPlan(WidgetTester tester) async {
    await h.plans.upsert(_plan(h.now));
    await h.open(tester, location: RfRoutes.trainPlans);
    await h.tap(tester, 'plan-start-plan');
    return (await h.latest()).id;
  }

  group('starting a session (TRN-016)', () {
    testWidgets('empty from the Train tab, then add an exercise', (
      tester,
    ) async {
      await h.open(tester);
      await h.tap(tester, 'start-empty-session');
      expect(find.byKey(const Key('session-no-exercises')), findsOneWidget);
      final s = await h.latest();
      expect(s.exercises, isEmpty);

      await h.tap(tester, 'add-exercise');
      await h.tap(tester, 'picker-exercise-squat');
      expect(
        find.byKey(Key('entry-name-${(await h.latest()).exercises.single.id}')),
        findsOneWidget,
      );
      expect(find.text('Back squat'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('from a plan pre-fills targets and shows skipped exercises', (
      tester,
    ) async {
      await h.plans.upsert(_plan(h.now, exerciseIds: ['squat', 'old']));
      await h.open(tester, location: RfRoutes.trainPlans);
      await h.tap(tester, 'plan-start-plan');
      final s = await h.latest();
      expect(s.planId, 'plan');
      expect(s.exercises, hasLength(1));
      expect(find.byKey(const Key('start-warnings')), findsOneWidget);
      expect(
        find.text('Old press is archived and was left out.'),
        findsOneWidget,
      );
      final id = s.exercises.single.id;
      expect(h.fieldText(tester, 'newset-$id-load'), '60');
      expect(h.fieldText(tester, 'newset-$id-reps'), '8');
      expect(find.byKey(Key('plan-hint-$id')), findsOneWidget);
      await h.tap(tester, 'start-warnings-dismiss');
      expect(find.byKey(const Key('start-warnings')), findsNothing);
      await unmount(tester);
    });

    testWidgets('from a scheduled occurrence links it', (tester) async {
      await h.plans.upsert(_plan(h.now));
      await h.scheduled.upsert(
        ScheduledWorkout(
          id: 'occ',
          planId: 'plan',
          day: DateTime(2026, 11, 5),
          sourceDay: DateTime(2026, 11, 5),
          origin: ScheduleOrigin.date,
          status: ScheduleStatus.planned,
          createdAt: h.now.toUtc(),
          updatedAt: h.now.toUtc(),
        ),
      );
      await h.open(tester, location: RfRoutes.trainSchedule);
      await h.tap(tester, 'schedule-start-occ');
      final s = await h.latest();
      final occ = await h.scheduled.byId('occ');
      expect(occ!.status, ScheduleStatus.done);
      expect(occ.sessionId, s.id);
      expect(find.byKey(const Key('session-title')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('from a past session copies its exercises', (tester) async {
      await h.seed(
        pastSession(
          'past',
          started: DateTime(2026, 11, 3, 9),
          sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
        ),
      );
      await h.open(tester, location: RfRoutes.trainHistory);
      await h.tap(tester, 'history-repeat-past');
      final s = await h.latest();
      expect(s.id, isNot('past'));
      expect(s.exercises.map((e) => e.exerciseId), ['squat']);
      expect(s.sets, isEmpty);
      await unmount(tester);
    });

    testWidgets('the Train tab offers to continue an unfinished workout', (
      tester,
    ) async {
      await h.open(tester);
      expect(find.byKey(const Key('continue-session')), findsNothing);
      await h.tap(tester, 'start-empty-session');
      // Back to the Train tab.
      await tester.pageBack();
      await h.settle(tester);
      expect(find.byKey(const Key('continue-session')), findsOneWidget);
      await h.tap(tester, 'continue-session');
      expect(find.byKey(const Key('session-title')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('logging sets', () {
    testWidgets(
      'a pre-filled set is confirmed in at most 2 taps (TRN-018(1), UXD-008)',
      (tester) async {
        await h.seed(
          pastSession(
            'past',
            started: DateTime(2026, 11, 3, 9),
            sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
          ),
        );
        await startFromPlan(tester);
        final s = await h.latest();
        final id = s.exercises.single.id;

        // The hint and the pre-fill come from the previous session.
        expect(h.textOf(tester, 'prev-hint-$id'), 'Last: 80 kg × 5');
        expect(h.fieldText(tester, 'newset-$id-load'), '80');
        expect(h.fieldText(tester, 'newset-$id-reps'), '5');

        h.taps = 0;
        await h.tap(tester, 'newset-log-$id');
        expect(h.taps, lessThanOrEqualTo(2));
        expect(h.taps, 1);

        final stored = (await h.sessions.byId(s.id))!.sets.single;
        expect(stored.data, weighted(80, 5));
        expect(stored.kind, SetKind.working);
        expect(find.byKey(Key('set-text-${stored.id}')), findsOneWidget);
        // The next row starts from the set just logged.
        expect(h.fieldText(tester, 'newset-$id-load'), '80');
        await unmount(tester);
      },
    );

    testWidgets('the weight field of an edited set has a numeric keyboard '
        'and focus (TRN-018(2))', (tester) async {
      await startFromPlan(tester);
      final s = await h.latest();
      final id = s.exercises.single.id;
      await h.tap(tester, 'newset-log-$id');
      final set = (await h.sessions.byId(s.id))!.sets.single;
      await h.tap(tester, 'set-edit-${set.id}');

      final field = find.descendant(
        of: find.byKey(const Key('editset-load')),
        matching: find.byType(EditableText),
      );
      final editable = tester.widget<EditableText>(field);
      expect(editable.focusNode.hasFocus, isTrue);
      expect(
        editable.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      await unmount(tester);
    });

    testWidgets('typed values, kind and exertion on the settings scale '
        '(TRN-019, TRN-020)', (tester) async {
      await h.setSettings(const AppSettings(exertionScale: ExertionScale.rir));
      await startFromPlan(tester);
      final s = await h.latest();
      final id = s.exercises.single.id;
      await h.tap(tester, 'newset-details-$id');
      expect(find.text('RIR (0–5)'), findsOneWidget);
      await h.enter(tester, 'newset-$id-load', '100');
      await h.enter(tester, 'newset-$id-reps', '3');
      await h.tap(tester, 'newset-$id-kind-failure');
      await h.enter(tester, 'newset-$id-exertion', '1');
      await h.enter(tester, 'newset-$id-rest', '120');
      await h.tap(tester, 'newset-log-$id');

      final set = (await h.sessions.byId(s.id))!.sets.single;
      expect(set.data, weighted(100, 3));
      expect(set.kind, SetKind.failure);
      expect(set.exertion, const Exertion(scale: ExertionScale.rir, value: 1));
      expect(set.restSeconds, 120);
      expect(
        h.textOf(tester, 'set-details-${set.id}'),
        'Failure · RIR 1 · rest 120 s',
      );
      await unmount(tester);
    });

    testWidgets('invalid values are rejected by the use case and not stored', (
      tester,
    ) async {
      await startFromPlan(tester);
      final s = await h.latest();
      final id = s.exercises.single.id;
      // A load off the 0.25 kg grid is rejected, never rounded.
      await h.enter(tester, 'newset-$id-load', '80.1');
      await h.tap(tester, 'newset-log-$id');
      expect(find.text('Load must be in steps of 0.25 kg.'), findsOneWidget);
      await h.enter(tester, 'newset-$id-load', '80');
      // RPE 11 is out of range: validated through TrainingRules.validExertion.
      await h.tap(tester, 'newset-details-$id');
      await h.enter(tester, 'newset-$id-exertion', '11');
      await h.tap(tester, 'newset-log-$id');
      expect(find.text('RPE must be 1 to 10 in half steps.'), findsOneWidget);
      await h.enter(tester, 'newset-$id-exertion', '');
      await h.enter(tester, 'newset-$id-reps', '0');
      await h.tap(tester, 'newset-log-$id');
      expect(find.text('Repetitions must be 1 to 100.'), findsOneWidget);
      expect((await h.sessions.byId(s.id))!.sets, isEmpty);
      await unmount(tester);
    });

    testWidgets('edit keeps the stored exertion scale; delete asks first', (
      tester,
    ) async {
      await h.setSettings(const AppSettings(exertionScale: ExertionScale.rir));
      final s = WorkoutSession(
        id: 'live',
        name: 'Live',
        startedAt: h.now.toUtc(),
        createdAt: h.now.toUtc(),
        updatedAt: h.now.toUtc(),
      );
      await h.sessions.upsert(s);
      // A set recorded earlier on the RPE scale.
      await h.sessions.addSet(
        SessionSet(
          id: 'old-set',
          sessionId: s.id,
          exerciseId: 'squat',
          exerciseOrder: 0,
          setOrder: 0,
          data: weighted(70, 5),
          completed: true,
          exertion: const Exertion(scale: ExertionScale.rpe, value: 8),
        ),
      );
      await h.open(tester, location: RfRoutes.trainSession(s.id));
      await h.tap(tester, 'set-edit-old-set');
      expect(find.text('RPE (1–10)'), findsOneWidget);
      await h.enter(tester, 'editset-reps', '6');
      await h.tap(tester, 'editset-save');
      final edited = (await h.sessions.byId(s.id))!.sets.single;
      expect(edited.data, weighted(70, 6));
      expect(
        edited.exertion,
        const Exertion(scale: ExertionScale.rpe, value: 8),
      );

      await h.tap(tester, 'set-delete-old-set');
      await h.tap(tester, 'confirm-cancel');
      expect((await h.sessions.byId(s.id))!.sets, hasLength(1));
      await h.tap(tester, 'set-delete-old-set');
      await h.tap(tester, 'delete-set-confirm');
      expect((await h.sessions.byId(s.id))!.sets, isEmpty);
      await unmount(tester);
    });

    testWidgets('a timed exercise has its own fields', (tester) async {
      await h.plans.upsert(
        WorkoutPlan(
          id: 'p2',
          name: 'Core',
          createdAt: h.now.toUtc(),
          updatedAt: h.now.toUtc(),
          exercises: const [
            PlanExercise(
              id: 'x',
              exerciseId: 'plank',
              sortOrder: 0,
              targetSets: 2,
              targetDuration: Duration(seconds: 45),
            ),
          ],
        ),
      );
      await h.open(tester, location: RfRoutes.trainPlans);
      await h.tap(tester, 'plan-start-p2');
      final s = await h.latest();
      final id = s.exercises.single.id;
      expect(h.fieldText(tester, 'newset-$id-duration'), '0:45');
      await h.tap(tester, 'newset-log-$id');
      expect(
        (await h.sessions.byId(s.id))!.sets.single.data,
        const SetData.timed(duration: Duration(seconds: 45)),
      );
      await unmount(tester);
    });
  });

  group('personal records and volume (TRN-026, TRN-027)', () {
    testWidgets('PR badge: 82.5 x 5 after 80 x 5, removed by delete', (
      tester,
    ) async {
      await h.seed(
        pastSession(
          'past',
          started: DateTime(2026, 11, 3, 9),
          sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
        ),
      );
      await startFromPlan(tester);
      final s = await h.latest();
      final id = s.exercises.single.id;
      await h.tap(tester, 'newset-log-$id'); // 80 x 5: a tie, not a PR.
      final first = (await h.sessions.byId(s.id))!.sets.single;
      expect(find.byKey(Key('pr-badge-${first.id}')), findsNothing);

      await h.enter(tester, 'newset-$id-load', '82.5');
      await h.tap(tester, 'newset-log-$id');
      final sets = [...(await h.sessions.byId(s.id))!.sets]
        ..sort((a, b) => a.setOrder.compareTo(b.setOrder));
      final pr = sets.last;
      expect(pr.data, weighted(82.5, 5));
      expect(find.byKey(Key('pr-badge-${pr.id}')), findsOneWidget);

      await h.tap(tester, 'set-delete-${pr.id}');
      await h.tap(tester, 'delete-set-confirm');
      expect(find.byKey(Key('pr-badge-${pr.id}')), findsNothing);

      // Editing a set that was a PR so that it no longer is removes it too.
      await h.enter(tester, 'newset-$id-load', '82.5');
      await h.tap(tester, 'newset-log-$id');
      final again = (await h.sessions.byId(s.id))!.sets
          .firstWhere((x) => x.data == weighted(82.5, 5));
      expect(find.byKey(Key('pr-badge-${again.id}')), findsOneWidget);
      await h.tap(tester, 'set-edit-${again.id}');
      await h.enter(tester, 'editset-load', '77.5');
      await h.tap(tester, 'editset-save');
      expect(find.byKey(Key('pr-badge-${again.id}')), findsNothing);
      await unmount(tester);
    });

    testWidgets('volume per exercise and per workout', (tester) async {
      await startFromPlan(tester);
      final s = await h.latest();
      final id = s.exercises.single.id;
      await h.enter(tester, 'newset-$id-load', '80');
      await h.enter(tester, 'newset-$id-reps', '5');
      await h.tap(tester, 'newset-log-$id');
      await h.enter(tester, 'newset-$id-reps', '4');
      await h.tap(tester, 'newset-log-$id');
      expect(h.textOf(tester, 'entry-volume-$id'), 'Volume: 720 kg');
      expect(h.textOf(tester, 'session-volume'), 'Volume: 720 kg');
      // A warm-up does not count.
      await h.tap(tester, 'newset-details-$id');
      await h.tap(tester, 'newset-$id-kind-warmUp');
      await h.enter(tester, 'newset-$id-load', '40');
      await h.tap(tester, 'newset-log-$id');
      expect(h.textOf(tester, 'session-volume'), 'Volume: 720 kg');
      await unmount(tester);
    });
  });

  group('exercises in a session (TRN-017, TRN-023)', () {
    testWidgets('add, reorder, replace, remove with confirmation', (
      tester,
    ) async {
      await h.open(tester);
      await h.tap(tester, 'start-empty-session');
      await h.tap(tester, 'add-exercise');
      await h.tap(tester, 'picker-exercise-squat');
      await h.tap(tester, 'add-exercise');
      await h.tap(tester, 'picker-exercise-bench');
      var s = await h.latest();
      final squat = s.exercises[0].id;
      final bench = s.exercises[1].id;
      expect(s.exercises.map((e) => e.exerciseId), ['squat', 'bench']);

      await h.tap(tester, 'entry-up-$bench');
      s = (await h.sessions.byId(s.id))!;
      expect(s.exercises.map((e) => e.exerciseId), ['bench', 'squat']);

      // Log a set on squat, then replace squat: the set stays with squat.
      await h.enter(tester, 'newset-$squat-load', '100');
      await h.enter(tester, 'newset-$squat-reps', '5');
      await h.tap(tester, 'newset-log-$squat');
      await h.tap(tester, 'entry-menu-$squat');
      await h.tap(tester, 'entry-menu-replace-$squat');
      await h.tap(tester, 'picker-exercise-plank');
      s = (await h.sessions.byId(s.id))!;
      expect(s.exercises.map((e) => e.exerciseId), ['bench', 'squat', 'plank']);
      expect(s.sets.single.exerciseId, 'squat');

      // Removing an entry with sets asks first.
      await h.tap(tester, 'entry-menu-$squat');
      await h.tap(tester, 'entry-menu-remove-$squat');
      expect(find.text('Remove Back squat?'), findsOneWidget);
      await h.tap(tester, 'confirm-cancel');
      expect((await h.sessions.byId(s.id))!.sets, hasLength(1));
      await h.tap(tester, 'entry-menu-$squat');
      await h.tap(tester, 'entry-menu-remove-$squat');
      await h.tap(tester, 'remove-confirm');
      s = (await h.sessions.byId(s.id))!;
      expect(s.exercises.map((e) => e.exerciseId), ['bench', 'plank']);
      expect(s.sets, isEmpty);

      // Removing an entry without sets does not ask.
      await h.tap(tester, 'entry-menu-$bench');
      await h.tap(tester, 'entry-menu-remove-$bench');
      expect(find.byKey(const Key('remove-confirm')), findsNothing);
      expect((await h.sessions.byId(s.id))!.exercises, hasLength(1));
      await unmount(tester);
    });

    testWidgets('notes of at least 2000 characters on session and exercise', (
      tester,
    ) async {
      await startFromPlan(tester);
      final s = await h.latest();
      final id = s.exercises.single.id;
      final long = List.filled(2500, 'a').join();
      await h.tap(tester, 'session-note-edit');
      await h.enter(tester, 'session-note-field', long);
      await h.tap(tester, 'session-note-save');
      expect((await h.sessions.byId(s.id))!.notes, long);
      expect(h.textOf(tester, 'session-note-text'), long);

      await h.tap(tester, 'entry-menu-$id');
      await h.tap(tester, 'entry-menu-note-$id');
      await h.enter(tester, 'entry-note-field', long);
      await h.tap(tester, 'entry-note-save');
      expect((await h.sessions.byId(s.id))!.exercises.single.note, long);
      expect(h.textOf(tester, 'entry-note-text-$id'), long);
      await unmount(tester);
    });

    testWidgets('a note over the limit is refused with a message', (
      tester,
    ) async {
      await startFromPlan(tester);
      await h.tap(tester, 'session-note-edit');
      await h.enter(
        tester,
        'session-note-field',
        List.filled(4001, 'b').join(),
      );
      await h.tap(tester, 'session-note-save');
      expect(find.textContaining('at most 4000 characters'), findsOneWidget);
      expect((await h.sessions.byId((await h.latest()).id))!.notes, '');
      await unmount(tester);
    });
  });

  group('rest timer (TRN-021, TRN-022(1))', () {
    testWidgets(
      'counts down on the injected clock, pause, +15 s, skip, alert',
      (tester) async {
        await h.plans.upsert(_plan(h.now, rest: 60));
        await h.open(tester, location: RfRoutes.trainPlans);
        await h.tap(tester, 'plan-start-plan');
        final id = (await h.latest()).exercises.single.id;
        expect(find.byKey(const Key('rest-timer-panel')), findsNothing);

        await h.tap(tester, 'newset-log-$id');
        // The planned rest (60 s) wins over the default (90 s).
        expect(h.textOf(tester, 'rest-remaining'), '1:00');

        h.clock.advance(const Duration(seconds: 20));
        await tester.pump(const Duration(seconds: 20));
        expect(h.textOf(tester, 'rest-remaining'), '0:40');

        await h.tap(tester, 'rest-pause');
        h.clock.advance(const Duration(seconds: 30));
        await tester.pump(const Duration(seconds: 30));
        expect(h.textOf(tester, 'rest-remaining'), '0:40');
        await h.tap(tester, 'rest-resume');
        await h.tap(tester, 'rest-extend');
        expect(h.textOf(tester, 'rest-remaining'), '0:55');

        // Reaching zero fires the foreground alert once.
        h.clock.advance(const Duration(seconds: 55));
        await tester.pump(const Duration(seconds: 55));
        expect(h.alert.fired, 1);
        expect(h.textOf(tester, 'rest-remaining'), 'Rest over');
        await tester.pump(const Duration(seconds: 5));
        expect(h.alert.fired, 1);

        await h.tap(tester, 'rest-skip');
        expect(find.byKey(const Key('rest-timer-panel')), findsNothing);
        await unmount(tester);
      },
    );

    testWidgets('uses the default rest from settings; skip stops it', (
      tester,
    ) async {
      await h.setSettings(const AppSettings(defaultRestSeconds: 45));
      await startFromPlan(tester);
      final id = (await h.latest()).exercises.single.id;
      await h.tap(tester, 'newset-log-$id');
      expect(h.textOf(tester, 'rest-remaining'), '0:45');
      await h.tap(tester, 'rest-skip');
      h.clock.advance(const Duration(minutes: 5));
      await tester.pump(const Duration(minutes: 5));
      expect(h.alert.fired, 0);
      await unmount(tester);
    });

    testWidgets('state derives from the clock: a late look shows it over', (
      tester,
    ) async {
      await startFromPlan(tester);
      final id = (await h.latest()).exercises.single.id;
      await h.tap(tester, 'newset-log-$id');
      expect(h.textOf(tester, 'rest-remaining'), '1:30');
      // The app was away for 2 minutes: no tick happened in between.
      h.clock.advance(const Duration(minutes: 2));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      expect(h.textOf(tester, 'rest-remaining'), 'Rest over');
      expect(h.alert.fired, 1);
      expect(find.byKey(const Key('rest-over-for')), findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('finishing a workout shows it in the history', (tester) async {
    await startFromPlan(tester);
    final s = await h.latest();
    final id = s.exercises.single.id;
    await h.enter(tester, 'newset-$id-load', '80');
    await h.tap(tester, 'newset-log-$id');
    await h.tap(tester, 'finish-session');
    expect((await h.sessions.byId(s.id))!.endedAt, isNotNull);
    expect(find.byKey(const Key('detail-title')), findsOneWidget);
    expect(find.byKey(const Key('rest-timer-panel')), findsNothing);
    await unmount(tester);
  });
}
