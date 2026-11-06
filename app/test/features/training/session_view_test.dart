import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/session_view.dart';

import '../../helpers/session_harness.dart';

void main() {
  late SessionHarness h;
  late LoadSessionView load;
  setUp(() async {
    h = SessionHarness();
    await h.seedExercises();
    load = LoadSessionView(
      sessions: h.sessions,
      exercises: h.exercises,
      plans: h.plans,
    );
  });
  tearDown(() => h.db.close());

  Future<SessionView?> view(String id) async =>
      (await load(id) as Ok<SessionView?>).value;

  test('a missing or deleted session is null', () async {
    expect(await view('nope'), isNull);
    await h.seed(pastSession('a', started: DateTime(2026, 11, 1, 9)));
    await h.sessions.delete('a');
    expect(await view('a'), isNull);
  });

  test(
    'previous performance excludes the session itself and later ones',
    () async {
      await h.seed(
        pastSession(
          'old',
          started: DateTime(2026, 11, 1, 9),
          sets: [(exerciseId: 'squat', kg: 80, reps: 5)],
        ),
      );
      await h.seed(
        pastSession(
          'cur',
          started: DateTime(2026, 11, 3, 9),
          sets: [(exerciseId: 'squat', kg: 90, reps: 3)],
        ),
      );
      await h.seed(
        pastSession(
          'later',
          started: DateTime(2026, 11, 4, 9),
          sets: [(exerciseId: 'squat', kg: 100, reps: 1)],
        ),
      );
      final v = (await view('cur'))!;
      final entry = v.session.exercises.single;
      expect(v.prefill[entry.id]!.previous.single.data, weighted(80, 5));
      // Personal records are derived across the whole history.
      expect(v.recordSetIds, containsAll(['old-s0', 'cur-s0', 'later-s0']));
    },
  );

  test('the k-th entry of an exercise takes the k-th plan row', () async {
    await h.plans.upsert(
      WorkoutPlan(
        id: 'p',
        name: 'Plan',
        createdAt: h.now.toUtc(),
        updatedAt: h.now.toUtc(),
        exercises: [
          PlanExercise(
            id: 'r1',
            exerciseId: 'squat',
            sortOrder: 0,
            targetSets: 3,
            repsMin: 5,
            repsMax: 5,
            targetLoad: kg(100),
          ),
          PlanExercise(
            id: 'r2',
            exerciseId: 'squat',
            sortOrder: 1,
            targetSets: 2,
            repsMin: 10,
            repsMax: 12,
            targetLoad: kg(60),
          ),
        ],
      ),
    );
    await h.sessions.upsert(
      WorkoutSession(
        id: 's',
        name: 'S',
        planId: 'p',
        startedAt: h.now.toUtc(),
        createdAt: h.now.toUtc(),
        updatedAt: h.now.toUtc(),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await h.sessions.addExercise(
        SessionExercise(
          id: 'e$i',
          sessionId: 's',
          exerciseId: 'squat',
          position: i,
        ),
      );
    }
    final v = (await view('s'))!;
    expect(v.prefill['e0']!.target!.id, 'r1');
    expect(v.prefill['e1']!.target!.id, 'r2');
    expect(v.prefill['e2']!.target, isNull);
  });

  test('a deleted exercise is absent from the exercise map', () async {
    await h.sessions.upsert(
      WorkoutSession(
        id: 's',
        name: 'S',
        startedAt: h.now.toUtc(),
        createdAt: h.now.toUtc(),
        updatedAt: h.now.toUtc(),
      ),
    );
    await h.sessions.addExercise(
      const SessionExercise(
        id: 'e0',
        sessionId: 's',
        exerciseId: 'gone',
        position: 0,
      ),
    );
    final v = (await view('s'))!;
    expect(v.exercises, isEmpty);
    expect(v.setsOf('e0'), isEmpty);
  });
}
