import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/presentation/session_screen.dart';

import '../../../helpers/pump.dart';
import '../../../helpers/session_harness.dart';

void main() {
  late SessionHarness h;
  setUp(() async {
    h = SessionHarness();
    await h.seedExercises();
  });
  tearDown(() => h.db.close());

  WorkoutPlan plan(String id, String name) => WorkoutPlan(
    id: id,
    name: name,
    createdAt: h.now.toUtc(),
    updatedAt: h.now.toUtc(),
    exercises: [
      PlanExercise(
        id: 'pe-$id',
        exerciseId: 'squat',
        sortOrder: 0,
        targetSets: 3,
        repsMin: 5,
        repsMax: 5,
      ),
    ],
  );

  group('plan list actions', () {
    testWidgets('Duplicate adds a copy named (copy)', (tester) async {
      await h.plans.upsert(plan('p1', 'Upper A'));
      await h.open(tester, location: RfRoutes.trainPlans);
      await h.tap(tester, 'plan-duplicate-p1');
      final all = await h.plans.watchAll().first;
      expect(
        all.map((p) => p.name),
        containsAll(['Upper A', 'Upper A (copy)']),
      );
      final copy = all.firstWhere((p) => p.name == 'Upper A (copy)');
      expect(copy.exercises.single.exerciseId, 'squat');
      expect(copy.exercises.single.id, isNot('pe-p1'));
      expect(find.text('Upper A (copy)'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets(
      'Delete asks first; cancel keeps the plan, confirm removes it',
      (tester) async {
        await h.plans.upsert(plan('p1', 'Upper A'));
        await h.open(tester, location: RfRoutes.trainPlans);

        await h.tap(tester, 'plan-delete-p1');
        expect(find.byKey(const Key('plan-delete-confirm')), findsOneWidget);
        await h.tap(tester, 'confirm-cancel');
        expect(await h.plans.byId('p1'), isNotNull);

        await h.tap(tester, 'plan-delete-p1');
        await h.tap(tester, 'plan-delete-confirm');
        expect(await h.plans.byId('p1'), isNull);
        expect(find.text('Upper A'), findsNothing);
        await unmount(tester);
      },
    );
  });

  group('save session as plan', () {
    testWidgets('creates the plan and opens it in the editor', (tester) async {
      await h.seed(
        pastSession(
          's1',
          started: DateTime(2026, 11, 1, 9),
          sets: [
            (exerciseId: 'squat', kg: 100, reps: 5),
            (exerciseId: 'squat', kg: 100, reps: 8),
          ],
        ),
      );
      await h.open(tester, location: RfRoutes.trainHistoryDetail('s1'));
      await h.tap(tester, 'detail-save-as-plan');
      final all = await h.plans.watchAll().first;
      expect(all, hasLength(1));
      expect(all.single.name, 'Leg day');
      expect(all.single.exercises.single.targetSets, 2);
      expect(all.single.exercises.single.repsMin, 5);
      expect(all.single.exercises.single.repsMax, 8);
      // The plan editor is showing.
      expect(find.byKey(const Key('detail-save-as-plan')), findsNothing);
      await unmount(tester);
    });

    testWidgets('a workout without sets shows an error and stores no plan', (
      tester,
    ) async {
      await h.seed(pastSession('s1', started: DateTime(2026, 11, 1, 9)));
      await h.open(tester, location: RfRoutes.trainHistoryDetail('s1'));
      await h.tap(tester, 'detail-save-as-plan');
      expect(find.byType(SnackBar), findsOneWidget);
      expect(await h.plans.watchAll().first, isEmpty);
      await unmount(tester);
    });
  });

  group('session screen', () {
    WorkoutSession open0() => WorkoutSession(
      id: 's1',
      name: 'Today',
      startedAt: h.now.toUtc(),
      createdAt: h.now.toUtc(),
      updatedAt: h.now.toUtc(),
    );

    testWidgets('elapsed time ticks every second while unfinished', (
      tester,
    ) async {
      await h.seed(open0());
      await h.open(tester, location: RfRoutes.trainSession('s1'));
      expect(h.textOf(tester, 'session-elapsed'), '00:00');
      h.clock.advance(const Duration(seconds: 7));
      await tester.pump(const Duration(seconds: 1));
      expect(h.textOf(tester, 'session-elapsed'), '00:07');
      h.clock.advance(const Duration(minutes: 62));
      await tester.pump(const Duration(seconds: 1));
      expect(h.textOf(tester, 'session-elapsed'), '1:02:07');
      await unmount(tester);
    });

    testWidgets('elapsed time stops at the end of a finished workout', (
      tester,
    ) async {
      await h.seed(
        pastSession(
          's1',
          started: DateTime(2026, 11, 5, 8),
        ).copyWith(endedAt: DateTime(2026, 11, 5, 8, 12, 30).toUtc()),
      );
      await h.open(tester, location: RfRoutes.trainSession('s1'));
      expect(h.textOf(tester, 'session-elapsed'), '12:30');
      h.clock.advance(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 2));
      expect(h.textOf(tester, 'session-elapsed'), '12:30');
      await unmount(tester);
    });

    test('formatElapsed uses mm:ss, then h:mm:ss, never negative', () {
      expect(formatElapsed(const Duration(seconds: 59)), '00:59');
      expect(formatElapsed(const Duration(minutes: 61, seconds: 5)), '1:01:05');
      expect(formatElapsed(const Duration(seconds: -4)), '00:00');
    });

    testWidgets('dragging an exercise handle changes the stored order', (
      tester,
    ) async {
      await h.seed(open0());
      for (final (i, ex) in ['squat', 'bench', 'plank'].indexed) {
        await h.sessions.addExercise(
          SessionExercise(
            id: 'e$i',
            sessionId: 's1',
            exerciseId: ex,
            position: i,
          ),
        );
      }
      final semantics = tester.ensureSemantics();
      await h.open(tester, location: RfRoutes.trainSession('s1'));
      expect(
        find.bySemanticsLabel(RegExp('Drag to reorder Back squat')),
        findsOneWidget,
      );

      final from = tester.getCenter(find.byKey(const Key('entry-drag-e0')));
      final to = tester.getCenter(find.byKey(const Key('entry-drag-e1')));
      final g = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 100));
      final steps = ((to.dy - from.dy) / 20).ceil() + 4;
      for (var i = 1; i <= steps; i++) {
        await g.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await g.up();
      await h.settle(tester);

      final s = (await h.sessions.byId('s1'))!;
      expect(s.exercises.map((e) => e.exerciseId), ['bench', 'squat', 'plank']);
      semantics.dispose();
      await unmount(tester);
    });
  });
}
