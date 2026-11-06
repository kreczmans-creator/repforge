import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart' as v7;
import 'package:repforge/data/db/drift_transactor.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_scheduled_workout_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/data/repositories/v8/drift_library_repository_v8.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/features/training/application/session_use_cases.dart';

import 'v8_library_support.dart';
import 'wp9_v8_adapters.dart';

/// WP 8 sub-stage 3b-8 contract test (D04 §7, 2026-11-06, "3b check scope":
/// "Blocked exercises cannot be selected for new work through the use
/// cases"; "no change to accepted WP 9 behaviour").
///
/// The **real, unchanged** WP 9 use cases (`StartSessionFromPlan`,
/// `StartSessionFromPast`, `AddSessionExercise`) run against a database
/// migrated to v8 by the real 3b-4 step, through test adapters of the WP 9
/// ports (`wp9_v8_adapters.dart`). The same use cases also run with the
/// production v7 repositories on the same data before migration, and both
/// outcomes are compared.
void main() {
  late V8LibraryHarness h;
  late Wp9OverV8 wp9;
  late Directory v7Dir;
  late v7.AppDatabase v7db;

  setUp(() async {
    h = await V8LibraryHarness.open();
    wp9 = Wp9OverV8(h.db, h.library);
    v7Dir = Directory.systemTemp.createTempSync('repforge_v8_3b8_v7_');
    final copy = V8LibraryFixture.v7Template().copySync(
      '${v7Dir.path}/v7.sqlite',
    );
    v7db = v7.AppDatabase(NativeDatabase(copy));
  });
  tearDown(() async {
    await wp9.dispose();
    await h.close();
    await v7db.close();
    v7Dir.deleteSync(recursive: true);
  });
  tearDownAll(V8LibraryFixture.dispose);

  T ok<T>(Result<T> r) => switch (r) {
    Ok(:final value) => value,
    Err(:final error) => fail('expected Ok, got ${error.message}'),
  };

  String Function() counter([String prefix = 'wp9']) {
    var n = 0;
    return () => '$prefix-${++n}';
  }

  ({
    ExerciseRepository exercises,
    WorkoutPlanRepository plans,
    WorkoutSessionRepository sessions,
    ScheduledWorkoutRepository scheduled,
    DriftTransactor transactor,
  })
  v7Ports() => (
    exercises: DriftExerciseRepository(v7db, clock: V8LibraryFixture.clock),
    plans: DriftWorkoutPlanRepository(v7db, clock: V8LibraryFixture.clock),
    sessions: DriftWorkoutSessionRepository(
      v7db,
      clock: V8LibraryFixture.clock,
    ),
    scheduled: DriftScheduledWorkoutRepository(v7db),
    transactor: DriftTransactor(v7db),
  );

  Future<Result<StartedSession>> startOnV8([String prefix = 'wp9']) =>
      StartSessionFromPlan(
        plans: wp9.plans,
        sessions: wp9.sessions,
        exercises: wp9.exercises,
        scheduled: wp9.scheduled,
        transactor: wp9.transactor,
        clock: V8LibraryFixture.clock,
        newId: counter(prefix),
      )(
        planId: V8LibraryFixture.planId,
        scheduledWorkoutId: V8LibraryFixture.scheduledId,
      );

  Future<Result<StartedSession>> startOnV7() {
    final p = v7Ports();
    return StartSessionFromPlan(
      plans: p.plans,
      sessions: p.sessions,
      exercises: p.exercises,
      scheduled: p.scheduled,
      transactor: p.transactor,
      clock: V8LibraryFixture.clock,
      newId: counter(),
    )(
      planId: V8LibraryFixture.planId,
      scheduledWorkoutId: V8LibraryFixture.scheduledId,
    );
  }

  final blockedInPlan = {
    for (final id in V8LibraryFixture.planOrder)
      if (V8LibraryFixture.blocked.containsKey(id)) id,
  };

  /// A comparable view of a started session.
  List<Object?> view(StartedSession s) => [
    s.session.id,
    s.session.name,
    s.session.planId,
    s.session.startedAt,
    [
      for (final e in s.session.exercises) [e.id, e.exerciseId, e.position],
    ],
    [
      for (final w in s.warnings) [w.exerciseId, w.exerciseName, w.reason],
    ],
    [
      for (final p in s.prefill)
        [
          p.sessionExerciseId,
          p.exerciseId,
          p.targetSets,
          p.repsMin,
          p.repsMax,
          p.targetLoadKg,
          p.targetDuration,
          p.targetMetres,
          p.restSeconds,
          p.previous,
        ],
    ],
  ];

  group('StartSessionFromPlan on v8', () {
    test('skips every blocked exercise and writes nothing for it', () async {
      expect(blockedInPlan, {'ex-rotator', 'ex-empty', 'ex-garbage'});
      final before = await h.dump();
      final legacyCounts = {
        for (final id in blockedInPlan)
          id: (
            await h.countFor('session_exercises', id),
            await h.countFor('session_sets', id),
            await h.countFor('plan_exercises', id),
          ),
      };
      final started = ok(await startOnV8());
      expect(
        [for (final e in started.session.exercises) e.exerciseId],
        [
          for (final id in V8LibraryFixture.planOrder)
            if (!blockedInPlan.contains(id)) id,
        ],
      );
      expect(
        [for (final w in started.warnings) w.exerciseId],
        ['ex-rotator', 'ex-empty', 'ex-garbage'],
      );
      expect(
        started.warnings.every((w) => w.reason == StartSkipReason.missing),
        isTrue,
      );
      expect(
        started.prefill.map((p) => p.exerciseId),
        isNot(anyElement(isIn(blockedInPlan))),
      );
      // Nothing was written for a blocked exercise.
      for (final id in blockedInPlan) {
        expect(
          (
            await h.countFor('session_exercises', id),
            await h.countFor('session_sets', id),
            await h.countFor('plan_exercises', id),
          ),
          legacyCounts[id],
          reason: id,
        );
      }
      // The only writes: the session, one entry per usable plan exercise,
      // and the scheduled workout marked done. Nothing else changed.
      final after = await h.dump();
      for (final table in after.keys) {
        if (const {
          'workout_sessions',
          'session_exercises',
          'scheduled_workouts',
        }.contains(table)) {
          continue;
        }
        expect(after[table], before[table], reason: table);
      }
      expect(
        after['workout_sessions']!.length,
        before['workout_sessions']!.length + 1,
      );
      expect(
        after['session_exercises']!.length,
        before['session_exercises']!.length + 4,
      );
      expect(after['session_sets'], before['session_sets']);
      final sw = await wp9.scheduled.byId(V8LibraryFixture.scheduledId);
      expect(sw!.status, ScheduleStatus.done);
      expect(sw.sessionId, started.session.id);
      // The blocked exercises stay blocked and their plan entries stay.
      for (final id in blockedInPlan) {
        expect((await h.library.availability(id))!.isBlocked, isTrue);
      }
    });

    test('WP 9 behaves exactly as on the same v7 data otherwise', () async {
      final onV7 = ok(await startOnV7());
      final onV8 = ok(await startOnV8());
      expect(view(onV8), view(onV7));
      // v7 hides the same exercises (its mapper cannot read them), so the
      // warnings are the same too.
      expect(onV7.warnings.map((w) => w.exerciseId), blockedInPlan.toList());
      // The stored rows of the new session are identical.
      Future<List<Map<String, Object?>>> v8Rows(String sql) async => [
        for (final r
            in await h.db
                .customSelect(sql, variables: [Variable(onV8.session.id)])
                .get())
          r.data,
      ];
      Future<List<Map<String, Object?>>> v7Rows(String sql) async => [
        for (final r
            in await v7db
                .customSelect(sql, variables: [Variable(onV7.session.id)])
                .get())
          r.data,
      ];
      for (final sql in const [
        'SELECT * FROM workout_sessions WHERE id = ?',
        'SELECT * FROM session_exercises WHERE session_id = ? ORDER BY id',
        'SELECT * FROM scheduled_workouts WHERE session_id = ?',
      ]) {
        expect(await v8Rows(sql), await v7Rows(sql), reason: sql);
      }
    });

    test('once corrected, the exercise enters new work again', () async {
      ok(
        await h.library.correctBlockedReason(
          'ex-rotator',
          BlockReason.unknownEquipment,
          const AddEquipmentCorrection([
            ExerciseEquipment(EquipmentItemId('dumbbell')),
          ]),
        ),
      );
      // One of two reasons resolved: still skipped (R-01).
      final stillSkipped = ok(await startOnV8());
      expect(
        stillSkipped.session.exercises.map((e) => e.exerciseId),
        isNot(contains('ex-rotator')),
      );
      ok(
        await h.library.correctBlockedReason(
          'ex-rotator',
          BlockReason.noPrimaryTarget,
          const AddTargetsCorrection([
            (node: AnatomyNodeId('rearDelts'), role: TargetRole.primary),
          ]),
        ),
      );
      // A new planned occurrence for the second start.
      await h.db.customStatement(
        "UPDATE scheduled_workouts SET status = 'planned', session_id = NULL "
        'WHERE id = ?',
        [V8LibraryFixture.scheduledId],
      );
      final included = ok(await startOnV8('again'));
      expect(
        included.session.exercises.map((e) => e.exerciseId),
        contains('ex-rotator'),
      );
      // Its legacy history is the previous performance: history kept.
      final prefill = included.prefill.firstWhere(
        (p) => p.exerciseId == 'ex-rotator',
      );
      expect(prefill.previous.map((s) => s.id), ['set-leg-1', 'set-leg-2']);
    });
  });

  group('other WP 9 paths into new work', () {
    test('StartSessionFromPast skips blocked exercises of a past session '
        'and writes nothing for them', () async {
      final before = {
        for (final id in ['ex-rotator', 'ex-empty'])
          id: await h.countFor('session_exercises', id),
      };
      final started = ok(
        await StartSessionFromPast(
          sessions: wp9.sessions,
          exercises: wp9.exercises,
          transactor: wp9.transactor,
          clock: V8LibraryFixture.clock,
          newId: counter(),
        )(pastSessionId: V8LibraryFixture.legacySession),
      );
      expect(started.session.exercises, isEmpty);
      expect(
        [for (final w in started.warnings) w.exerciseId],
        ['ex-rotator', 'ex-empty'],
      );
      for (final id in before.keys) {
        expect(await h.countFor('session_exercises', id), before[id]);
      }
    });

    test('AddSessionExercise refuses a blocked exercise and writes '
        'nothing; a usable one is added as before', () async {
      final add = AddSessionExercise(
        sessions: wp9.sessions,
        exercises: wp9.exercises,
        newId: counter(),
      );
      final before = await h.dump();
      for (final id in V8LibraryFixture.blocked.keys) {
        final r = await add(sessionId: 'sess-01', exerciseId: id);
        expect(r, isA<Err<SessionExercise>>(), reason: id);
        expect((r as Err<SessionExercise>).error, isA<NotFoundError>());
      }
      expect(await h.dump(), before);
      final added = ok(await add(sessionId: 'sess-01', exerciseId: 'ex-row'));
      expect(added.exerciseId, 'ex-row');
      expect(
        await h.countFor('session_exercises', 'ex-row'),
        before['session_exercises']!
                .where((r) => r.contains('"exercise_id":"text:ex-row"'))
                .length +
            1,
      );
    });

    test('the adapter search offers no blocked exercise', () async {
      final ids = {
        for (final e in await wp9.exercises.search(const ExerciseQuery())) e.id,
      };
      expect(ids.intersection(V8LibraryFixture.blocked.keys.toSet()), isEmpty);
      expect(ids, containsAll(['ex-bench', 'ex-row', 'lib-back-squat']));
    });
  });
}
