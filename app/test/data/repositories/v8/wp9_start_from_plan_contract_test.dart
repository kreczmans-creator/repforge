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
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/exercise_use_cases.dart';
import 'package:repforge/features/training/application/plan_use_cases.dart';
import 'package:repforge/features/training/application/record_set.dart';
import 'package:repforge/features/training/application/session_use_cases.dart';

import 'v8_library_support.dart';
import 'wp9_v8_adapters.dart';

/// WP 8 sub-stage 3b-8 contract test (D04 §7, 2026-11-06, "3b check scope":
/// "Blocked exercises cannot be selected for new work through the use
/// cases"; "no change to accepted WP 9 behaviour").
///
/// The **real, unchanged** WP 9 use cases (`StartSessionFromPlan`,
/// `StartSessionFromPast`, `AddSessionExercise`, `SavePlan`, `RecordSet`,
/// `ReplaceSessionExercise`, `CopySuppliedExercise`) run against a database
/// migrated to v8 by the real 3b-4 step: exercises through the
/// production-side `V8ExerciseReadPort`, plans, sessions and schedules
/// through the production WP 9 repositories (`wp9_v8_adapters.dart`). The
/// same use cases also run with the production v7 repositories on the same
/// data before migration, and both outcomes are compared.
void main() {
  late V8LibraryHarness h;
  late Wp9OverV8 wp9;
  late Directory v7Dir;
  late v7.AppDatabase v7db;

  setUp(() async {
    h = await V8LibraryHarness.open();
    wp9 = Wp9OverV8.open(h.file, h.library, V8LibraryFixture.clock);
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

  AppError err<T>(Result<T> r) => switch (r) {
    Ok() => fail('expected Err'),
    Err(:final error) => error,
  };

  /// A comparable form of a result: the value, or the error's type and
  /// message.
  Object? outcome<T>(Result<T> r, [Object? Function(T)? view]) => switch (r) {
    Ok(:final value) => ['ok', if (view == null) value else view(value)],
    Err(:final error) => ['err', error.runtimeType, error.message],
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

  /// Runs [statement] on both databases (v7 and v8 hold the same rows).
  Future<void> onBoth(String statement, [List<Object?> args = const []]) async {
    await v7db.customStatement(statement, args);
    await h.db.customStatement(statement, args);
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

  /// Rows of [sql] on v8 ([v8] true) or on the v7 copy.
  Future<List<Map<String, Object?>>> rowsOn(
    String sql,
    List<String> args, {
    required bool v8,
  }) async {
    final vars = [for (final a in args) Variable<String>(a)];
    final rows = v8
        ? await h.db.customSelect(sql, variables: vars).get()
        : await v7db.customSelect(sql, variables: vars).get();
    return [for (final r in rows) r.data];
  }

  group('StartSessionFromPlan', () {
    test('skips every blocked exercise and writes nothing for it', () async {
      expect(blockedInPlan, {'ex-rotator', 'ex-empty', 'ex-garbage'});
      final before = await h.dump();
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
      // The only writes: the session, one entry per usable plan exercise,
      // and the scheduled workout marked done. Nothing for a blocked one.
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
      for (final id in blockedInPlan) {
        expect(
          after['session_exercises']!
              .where((r) => r.contains('"exercise_id":"text:$id"'))
              .length,
          before['session_exercises']!
              .where((r) => r.contains('"exercise_id":"text:$id"'))
              .length,
          reason: id,
        );
        expect((await h.library.availability(id))!.isBlocked, isTrue);
      }
      final sw = await wp9.scheduled.byId(V8LibraryFixture.scheduledId);
      expect(sw!.status, ScheduleStatus.done);
      expect(sw.sessionId, started.session.id);
    });

    test('behaves exactly as on the same v7 data otherwise, archived '
        'exercises included', () async {
      // Archive one usable plan exercise on both sides (TRN-012(2)).
      await onBoth("UPDATE exercises SET archived = 1 WHERE id = 'ex-squat'");
      final onV7 = ok(await startOnV7());
      final onV8 = ok(await startOnV8());
      expect(view(onV8), view(onV7));
      expect(onV7.warnings.map((w) => (w.exerciseId, w.reason)), [
        ('ex-rotator', StartSkipReason.missing),
        ('ex-empty', StartSkipReason.missing),
        ('ex-squat', StartSkipReason.archived),
        ('ex-garbage', StartSkipReason.missing),
      ]);
      for (final sql in const [
        'SELECT * FROM workout_sessions WHERE id = ?',
        'SELECT * FROM session_exercises WHERE session_id = ? ORDER BY id',
        'SELECT * FROM scheduled_workouts WHERE session_id = ?',
      ]) {
        expect(
          await rowsOn(sql, [onV8.session.id], v8: true),
          await rowsOn(sql, [onV7.session.id], v8: false),
          reason: sql,
        );
      }
    });

    test('a retired exercise is not refused in an existing plan (ADR-0009: '
        'hidden from discovery only; R-C8)', () async {
      await h.db.customStatement(
        "UPDATE exercises SET retired_at = ? WHERE id = 'lib-back-squat'",
        [V8LibraryFixture.now.toIso8601String()],
      );
      final started = ok(await startOnV8());
      expect(
        started.session.exercises.map((e) => e.exerciseId),
        contains('lib-back-squat'),
      );
      expect(
        started.warnings.map((w) => w.exerciseId),
        isNot(contains('lib-back-squat')),
      );
      // Hidden from discovery.
      expect(
        (await wp9.exercises.search(const ExerciseQuery())).map((e) => e.id),
        isNot(contains('lib-back-squat')),
      );
    });

    test('once every reason is corrected, the exercise enters new work; '
        'one corrected reason of two is not enough (R-01)', () async {
      ok(
        await h.library.correctBlockedReason(
          'ex-rotator',
          BlockReason.unknownEquipment,
          const SetEquipmentCorrection([
            ExerciseEquipment(EquipmentItemId('dumbbell')),
            ExerciseEquipment(EquipmentItemId('cable')),
          ]),
        ),
      );
      final stillSkipped = ok(await startOnV8());
      expect(
        stillSkipped.session.exercises.map((e) => e.exerciseId),
        isNot(contains('ex-rotator')),
      );
      ok(
        await h.library.correctBlockedReason(
          'ex-rotator',
          BlockReason.noPrimaryTarget,
          const SetTargetsCorrection([
            (node: AnatomyNodeId('rearDelts'), role: TargetRole.primary),
          ]),
        ),
      );
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
        'nothing; a usable one is added as on v7', () async {
      final before = await h.dump();
      for (final id in V8LibraryFixture.blocked.keys) {
        final r = await AddSessionExercise(
          sessions: wp9.sessions,
          exercises: wp9.exercises,
          newId: counter(),
        )(sessionId: 'sess-01', exerciseId: id);
        expect(err(r), isA<NotFoundError>(), reason: id);
      }
      expect(await h.dump(), before);
      final onV8 = await AddSessionExercise(
        sessions: wp9.sessions,
        exercises: wp9.exercises,
        newId: counter(),
      )(sessionId: 'sess-01', exerciseId: 'ex-row');
      final p = v7Ports();
      final onV7 = await AddSessionExercise(
        sessions: p.sessions,
        exercises: p.exercises,
        newId: counter(),
      )(sessionId: 'sess-01', exerciseId: 'ex-row');
      expect(outcome(onV8), outcome(onV7));
    });

    test('SavePlan: a blocked exercise cannot be added to a plan; archived '
        'and already-listed rules (TD-42) are as on v7', () async {
      SavePlan saveOn({required bool v8, String prefix = 'wp9'}) {
        final p = v7Ports();
        return SavePlan(
          plans: v8 ? wp9.plans : p.plans,
          exercises: v8 ? wp9.exercises : p.exercises,
          clock: V8LibraryFixture.clock,
          newId: counter(prefix),
        );
      }

      PlanExercise pe(String exerciseId) => PlanExercise(
        id: '',
        exerciseId: exerciseId,
        sortOrder: 0,
        targetSets: 3,
        repsMin: 8,
        repsMax: 10,
      );

      // A new plan with a blocked exercise: refused, nothing written.
      for (final id in V8LibraryFixture.blocked.keys) {
        final before = await h.dump();
        final r = await saveOn(v8: true)(
          name: 'New',
          planExercises: [pe('ex-bench'), pe(id)],
        );
        expect(err(r), isA<NotFoundError>(), reason: id);
        expect(await h.dump(), before, reason: id);
      }
      final blockedOnV7 = await saveOn(v8: false)(
        name: 'New',
        planExercises: [pe('ex-bench'), pe('ex-rotator')],
      );
      expect(err(blockedOnV7), isA<NotFoundError>());

      // Re-saving a plan that already lists blocked exercises is refused
      // on both sides (v7 cannot read them either; register C-2).
      final existing = (await wp9.plans.byId(V8LibraryFixture.planId))!;
      final resave8 = await saveOn(v8: true)(
        id: existing.id,
        name: 'Renamed',
        planExercises: existing.exercises,
      );
      final resave7 = await saveOn(v8: false)(
        id: existing.id,
        name: 'Renamed',
        planExercises: existing.exercises,
      );
      expect(outcome(resave8), outcome(resave7));

      // TD-42 with an archived exercise: kept when already listed, refused
      // when newly added; identical on both sides.
      Object? viewPlan(WorkoutPlan p) => [
        p.id,
        p.name,
        p.archived,
        [
          for (final e in p.exercises) [e.id, e.exerciseId, e.sortOrder],
        ],
      ];
      final created = [
        for (final v8 in [true, false])
          ok(
            await saveOn(v8: v8)(
              name: 'Archive check',
              planExercises: [pe('ex-bench'), pe('ex-squat')],
            ),
          ),
      ];
      expect(viewPlan(created[0]), viewPlan(created[1]));
      await onBoth("UPDATE exercises SET archived = 1 WHERE id = 'ex-squat'");
      for (final v8 in [true, false]) {
        expect(
          outcome(
            await saveOn(v8: v8)(
              id: created[0].id,
              name: 'Archive check renamed',
              planExercises: created[0].exercises,
            ),
            viewPlan,
          ),
          ['ok', viewPlan(created[0].copyWith(name: 'Archive check renamed'))],
          reason: 'v8: $v8',
        );
        expect(
          err(
            await saveOn(v8: v8)(name: 'New', planExercises: [pe('ex-squat')]),
          ),
          isA<ValidationError>(),
          reason: 'v8: $v8',
        );
      }

      // A retired exercise is not refused (R-C8).
      await h.db.customStatement(
        "UPDATE exercises SET retired_at = ? WHERE id = 'lib-back-squat'",
        [V8LibraryFixture.now.toIso8601String()],
      );
      ok(
        await saveOn(v8: true, prefix: 'retired')(
          name: 'With retired',
          planExercises: [pe('lib-back-squat')],
        ),
      );
    });

    test('RecordSet: no set for a blocked exercise, even on its legacy '
        'entry; a usable one is recorded as on v7', () async {
      final data = SetData.weighted(load: LoadKg.fromStored(20), reps: 10);
      final before = await h.dump();
      final blocked =
          await RecordSet(
            exercises: wp9.exercises,
            sessions: wp9.sessions,
            newId: counter(),
          )(
            sessionId: V8LibraryFixture.legacySession,
            sessionExerciseId: 'se-leg-1', // ex-rotator
            data: data,
          );
      expect(err(blocked), isA<NotFoundError>());
      expect(await h.dump(), before);
      final p = v7Ports();
      final blockedOnV7 =
          await RecordSet(
            exercises: p.exercises,
            sessions: p.sessions,
            newId: counter(),
          )(
            sessionId: V8LibraryFixture.legacySession,
            sessionExerciseId: 'se-leg-1',
            data: data,
          );
      expect(outcome(blocked), outcome(blockedOnV7));
      final onV8 = await RecordSet(
        exercises: wp9.exercises,
        sessions: wp9.sessions,
        newId: counter(),
      )(sessionId: 'sess-01', sessionExerciseId: 'se-02', data: data);
      final onV7 = await RecordSet(
        exercises: p.exercises,
        sessions: p.sessions,
        newId: counter(),
      )(sessionId: 'sess-01', sessionExerciseId: 'se-02', data: data);
      expect(outcome(onV8), outcome(onV7));
      const sql = 'SELECT * FROM session_sets WHERE id = ?';
      expect(
        await rowsOn(sql, ['wp9-1'], v8: true),
        await rowsOn(sql, ['wp9-1'], v8: false),
      );
    });

    test('ReplaceSessionExercise: never with a blocked exercise; otherwise '
        'as on v7', () async {
      final before = await h.dump();
      for (final id in V8LibraryFixture.blocked.keys) {
        final r = await ReplaceSessionExercise(
          sessions: wp9.sessions,
          exercises: wp9.exercises,
          transactor: wp9.transactor,
          newId: counter(),
        )(sessionId: 'sess-01', sessionExerciseId: 'se-02', newExerciseId: id);
        expect(err(r), isA<NotFoundError>(), reason: id);
      }
      expect(await h.dump(), before);
      final p = v7Ports();
      final onV8 =
          await ReplaceSessionExercise(
            sessions: wp9.sessions,
            exercises: wp9.exercises,
            transactor: wp9.transactor,
            newId: counter(),
          )(
            sessionId: 'sess-01',
            sessionExerciseId: 'se-02',
            newExerciseId: 'ex-squat',
          );
      final onV7 =
          await ReplaceSessionExercise(
            sessions: p.sessions,
            exercises: p.exercises,
            transactor: p.transactor,
            newId: counter(),
          )(
            sessionId: 'sess-01',
            sessionExerciseId: 'se-02',
            newExerciseId: 'ex-squat',
          );
      expect(outcome(onV8), outcome(onV7));
      const sql =
          'SELECT * FROM session_exercises WHERE session_id = ? ORDER BY id';
      expect(
        await rowsOn(sql, ['sess-01'], v8: true),
        await rowsOn(sql, ['sess-01'], v8: false),
      );
    });

    test('CopySuppliedExercise: a blocked system exercise is not copied; '
        'otherwise WP 9 builds the same copy as on v7', () async {
      final writes = RecordingExerciseWrites(wp9.exercises);
      CopySuppliedExercise copyWith(ExerciseRepository e) =>
          CopySuppliedExercise(
            exercises: e,
            clock: V8LibraryFixture.clock,
            newId: counter('copy'),
          );
      await h.db.customStatement(
        'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
        "blocked_at, resolved_at) VALUES ('lib-leg-press', "
        "'unknownEquipment', '{}', ?, NULL)",
        [V8LibraryFixture.now.toIso8601String()],
      );
      final blocked = await copyWith(writes)(sourceId: 'lib-leg-press');
      expect(err(blocked), isA<NotFoundError>());
      expect(writes.upserts, isEmpty);
      final onV8 = await copyWith(writes)(
        sourceId: 'lib-back-squat',
        name: 'My squat',
      );
      final onV7 = await copyWith(
        DriftExerciseRepository(v7db, clock: V8LibraryFixture.clock),
      )(sourceId: 'lib-back-squat', name: 'My squat');
      expect(outcome(onV8), outcome(onV7));
      expect(writes.upserts, [ok(onV7)]);
    });

    test('the port search offers no blocked or retired exercise; '
        'includeArchived adds archived ones only', () async {
      await h.db.customStatement(
        "UPDATE exercises SET archived = 1 WHERE id = 'ex-squat'",
      );
      final ids = {
        for (final e in await wp9.exercises.search(const ExerciseQuery())) e.id,
      };
      expect(ids.intersection(V8LibraryFixture.blocked.keys.toSet()), isEmpty);
      expect(ids, containsAll(['ex-bench', 'ex-row', 'lib-back-squat']));
      expect(ids, isNot(contains('ex-squat')));
      final withArchived = await wp9.exercises.search(
        const ExerciseQuery(includeArchived: true),
      );
      expect(
        withArchived.firstWhere((e) => e.id == 'ex-squat').archived,
        isTrue,
      );
      expect(
        withArchived
            .map((e) => e.id)
            .toSet()
            .intersection(V8LibraryFixture.blocked.keys.toSet()),
        isEmpty,
      );
      expect(
        (await wp9.exercises.watchAll(includeArchived: true).first).length,
        withArchived.length,
      );
      expect(await wp9.exercises.exists('ex-rotator'), isTrue);
      expect(await wp9.exercises.byId('ex-rotator'), isNull);
      expect((await wp9.exercises.byId('ex-squat'))!.archived, isTrue);
      final row = (await wp9.exercises.byId('ex-row'))!;
      expect(() => wp9.exercises.upsert(row), throwsUnsupportedError);
    });
  });
}
