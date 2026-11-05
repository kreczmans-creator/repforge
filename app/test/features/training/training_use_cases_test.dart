import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_training_split_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/training/training_validation.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/exercise_use_cases.dart';
import 'package:repforge/features/training/application/plan_use_cases.dart';
import 'package:repforge/features/training/application/record_set.dart';

import '../../helpers/seed_session.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 5, 10));
final _t = DateTime.utc(2026, 11, 1, 9);

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final error) => fail('expected Ok, got ${error.message}'),
};

AppError _err<T>(Result<T> r) => switch (r) {
  Err(:final error) => error,
  Ok() => fail('expected Err'),
};

/// An exercise repository whose every call fails.
class _BrokenExercises implements ExerciseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('disk full');
}

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  late DriftWorkoutSessionRepository sessions;
  late DriftWorkoutPlanRepository plans;
  late DriftTrainingSplitRepository splits;
  var n = 0;
  String newId() => 'id-${n++}';

  late SaveCustomExercise save;
  late CopySuppliedExercise copy;
  late ArchiveExercise archive;
  late SavePlan savePlan;
  late SaveSplit saveSplit;

  setUp(() {
    db = AppDatabase.inMemory();
    exercises = DriftExerciseRepository(db, clock: _clock);
    sessions = DriftWorkoutSessionRepository(db, clock: _clock);
    plans = DriftWorkoutPlanRepository(db, clock: _clock);
    splits = DriftTrainingSplitRepository(db, clock: _clock);
    n = 0;
    save = SaveCustomExercise(
      exercises: exercises,
      sessions: sessions,
      plans: plans,
      clock: _clock,
      newId: newId,
    );
    copy = CopySuppliedExercise(
      exercises: exercises,
      clock: _clock,
      newId: newId,
    );
    archive = ArchiveExercise(exercises: exercises);
    savePlan = SavePlan(
      plans: plans,
      exercises: exercises,
      clock: _clock,
      newId: newId,
    );
    saveSplit = SaveSplit(
      splits: splits,
      plans: plans,
      clock: _clock,
      newId: newId,
    );
  });
  tearDown(() => db.close());

  Future<Exercise> seedSupplied() async {
    final e = Exercise(
      id: 'lib-bench',
      name: 'Bench Press',
      type: ExerciseType.weighted,
      category: ExerciseCategory.push,
      primaryMuscle: MuscleGroup.chest,
      secondaryMuscles: const [MuscleGroup.triceps],
      equipment: const [Equipment.barbell, Equipment.bench],
      aliases: const ['Flat bench'],
      supplied: true,
      createdAt: _t,
      updatedAt: _t,
    );
    await exercises.upsert(e);
    return e;
  }

  group('SaveCustomExercise (TRN-012(1))', () {
    test(
      'creates a custom exercise with a name, type, category and primary',
      () async {
        final e = _ok(
          await save(
            name: '  Cable Fly ',
            type: ExerciseType.weighted,
            category: ExerciseCategory.push,
            primaryMuscle: MuscleGroup.chest,
            secondaryMuscles: const [MuscleGroup.frontDelts],
            equipment: const [Equipment.cable],
            aliases: const ['Cable flye', ' '],
          ),
        );
        expect(e.id, 'id-0');
        expect(e.name, 'Cable Fly');
        expect(e.supplied, isFalse);
        expect(e.isCustom, isTrue);
        expect(e.copiedFromId, isNull);
        expect(e.aliases, ['Cable flye']);
        expect(e.createdAt, _clock.now());
        expect(await exercises.byId('id-0'), e);
      },
    );

    test('requires name, type, category and primary muscle', () async {
      Future<String?> field(
        String name, {
        ExerciseType? type = ExerciseType.weighted,
        ExerciseCategory? category = ExerciseCategory.push,
        MuscleGroup? primary = MuscleGroup.chest,
      }) async {
        final r = await save(
          name: name,
          type: type,
          category: category,
          primaryMuscle: primary,
        );
        return (_err(r) as ValidationError).field;
      }

      expect(await field(' '), 'name');
      expect(await field('X', type: null), 'type');
      expect(await field('X', category: null), 'category');
      expect(await field('X', primary: null), 'primary');
      expect(await exercises.search(const ExerciseQuery()), isEmpty);
    });

    test('rejects a primary muscle repeated as secondary', () async {
      final r = await save(
        name: 'X',
        type: ExerciseType.weighted,
        category: ExerciseCategory.push,
        primaryMuscle: MuscleGroup.chest,
        secondaryMuscles: const [MuscleGroup.chest],
      );
      expect((_err(r) as ValidationError).field, 'secondaryMuscles');
    });

    test(
      'edits an own exercise, keeping id, creation time and archive flag',
      () async {
        final created = _ok(
          await save(
            name: 'Curl',
            type: ExerciseType.weighted,
            category: ExerciseCategory.pull,
            primaryMuscle: MuscleGroup.biceps,
          ),
        );
        await archive(created.id);
        final edited = _ok(
          await save(
            id: created.id,
            name: 'Hammer Curl',
            type: ExerciseType.weighted,
            category: ExerciseCategory.pull,
            primaryMuscle: MuscleGroup.biceps,
            secondaryMuscles: const [MuscleGroup.forearms],
          ),
        );
        expect(edited.id, created.id);
        expect(edited.name, 'Hammer Curl');
        expect(edited.archived, isTrue);
        expect(edited.createdAt, created.createdAt);
        expect(
          await exercises.search(const ExerciseQuery(includeArchived: true)),
          [edited],
        );
      },
    );

    test('a supplied exercise cannot be edited in place', () async {
      await seedSupplied();
      final r = await save(
        id: 'lib-bench',
        name: 'Hacked',
        type: ExerciseType.weighted,
        category: ExerciseCategory.push,
        primaryMuscle: MuscleGroup.chest,
      );
      expect(_err(r), isA<ValidationError>());
      expect((await exercises.byId('lib-bench'))!.name, 'Bench Press');
    });

    test(
      'an unknown id is not found; the type is locked once sets exist',
      () async {
        final missing = await save(
          id: 'nope',
          name: 'X',
          type: ExerciseType.weighted,
          category: ExerciseCategory.push,
          primaryMuscle: MuscleGroup.chest,
        );
        expect(_err(missing), isA<NotFoundError>());

        final e = _ok(
          await save(
            name: 'Plank',
            type: ExerciseType.timed,
            category: ExerciseCategory.core,
            primaryMuscle: MuscleGroup.abs,
          ),
        );
        // Free to change the type while there is no history.
        final retyped = _ok(
          await save(
            id: e.id,
            name: 'Plank',
            type: ExerciseType.weighted,
            category: ExerciseCategory.core,
            primaryMuscle: MuscleGroup.abs,
          ),
        );
        expect(retyped.type, ExerciseType.weighted);
        await seedSession(
          sessions,
          WorkoutSession(
            id: 's',
            name: 'S',
            startedAt: _t,
            createdAt: _t,
            updatedAt: _t,
          ),
        );
        final record = RecordSet(
          exercises: exercises,
          sessions: sessions,
          newId: newId,
        );
        _ok(
          await record(
            sessionId: 's',
            exerciseId: e.id,
            data: SetData.weighted(load: LoadKg.fromStored(10), reps: 5),
          ),
        );
        final locked = await save(
          id: e.id,
          name: 'Plank',
          type: ExerciseType.timed,
          category: ExerciseCategory.core,
          primaryMuscle: MuscleGroup.abs,
        );
        expect((_err(locked) as ValidationError).field, 'type');
        // Renaming is still fine.
        expect(
          (await save(
            id: e.id,
            name: 'Plank 2',
            type: ExerciseType.weighted,
            category: ExerciseCategory.core,
            primaryMuscle: MuscleGroup.abs,
          )).isOk,
          isTrue,
        );
      },
    );

    test(
      'the type cannot change while a plan uses the exercise (L4)',
      () async {
        final e = _ok(
          await save(
            name: 'Plank',
            type: ExerciseType.timed,
            category: ExerciseCategory.core,
            primaryMuscle: MuscleGroup.abs,
          ),
        );
        await plans.upsert(
          WorkoutPlan(
            id: 'p',
            name: 'Core',
            exercises: [
              PlanExercise(
                id: 'pe',
                exerciseId: e.id,
                sortOrder: 0,
                targetSets: 3,
                targetDuration: const Duration(seconds: 60),
              ),
            ],
            createdAt: _t,
            updatedAt: _t,
          ),
        );
        expect(await sessions.hasHistory(e.id), isFalse);
        final r = await save(
          id: e.id,
          name: 'Plank',
          type: ExerciseType.weighted,
          category: ExerciseCategory.core,
          primaryMuscle: MuscleGroup.abs,
        );
        expect((_err(r) as ValidationError).field, 'type');
        expect((await exercises.byId(e.id))!.type, ExerciseType.timed);
        // Renaming is still fine; and a deleted plan no longer blocks.
        expect(
          (await save(
            id: e.id,
            name: 'Plank 2',
            type: ExerciseType.timed,
            category: ExerciseCategory.core,
            primaryMuscle: MuscleGroup.abs,
          )).isOk,
          isTrue,
        );
        await plans.delete('p');
        expect(
          (await save(
            id: e.id,
            name: 'Plank 2',
            type: ExerciseType.weighted,
            category: ExerciseCategory.core,
            primaryMuscle: MuscleGroup.abs,
          )).isOk,
          isTrue,
        );
      },
    );

    test('a storage failure is returned, not thrown', () async {
      final broken = SaveCustomExercise(
        exercises: _BrokenExercises(),
        sessions: sessions,
        plans: plans,
        clock: _clock,
        newId: newId,
      );
      final r = await broken(
        name: 'X',
        type: ExerciseType.weighted,
        category: ExerciseCategory.push,
        primaryMuscle: MuscleGroup.chest,
      );
      expect(_err(r), isA<StorageError>());
    });
  });

  group('CopySuppliedExercise (TRN-008(2))', () {
    test('editing a supplied exercise creates a custom copy and leaves the '
        'supplied one unchanged', () async {
      final original = await seedSupplied();
      final c = _ok(
        await copy(
          sourceId: 'lib-bench',
          name: 'My Bench Press',
          equipment: const [Equipment.dumbbell, Equipment.bench],
        ),
      );
      expect(c.id, isNot('lib-bench'));
      expect(c.supplied, isFalse);
      expect(c.copiedFromId, 'lib-bench');
      expect(c.name, 'My Bench Press');
      expect(c.equipment, [Equipment.dumbbell, Equipment.bench]);
      // Values not edited carry over.
      expect(c.type, ExerciseType.weighted);
      expect(c.primaryMuscle, MuscleGroup.chest);
      expect(c.secondaryMuscles, [MuscleGroup.triceps]);
      expect(c.aliases, ['Flat bench']);
      expect(await exercises.byId(c.id), c);
      expect(await exercises.byId('lib-bench'), original);
    });

    test('an invalid edit is rejected and nothing is created', () async {
      await seedSupplied();
      final r = await copy(sourceId: 'lib-bench', name: ' ');
      expect((_err(r) as ValidationError).field, 'name');
      expect(await exercises.search(const ExerciseQuery()), hasLength(1));
    });

    test(
      'only supplied exercises are copied; unknown ids are not found',
      () async {
        expect(_err(await copy(sourceId: 'nope')), isA<NotFoundError>());
        final mine = _ok(
          await save(
            name: 'Mine',
            type: ExerciseType.weighted,
            category: ExerciseCategory.push,
            primaryMuscle: MuscleGroup.chest,
          ),
        );
        expect(_err(await copy(sourceId: mine.id)), isA<ValidationError>());
      },
    );

    test('copies appear in the library next to the original', () async {
      await seedSupplied();
      await copy(sourceId: 'lib-bench', name: 'Bench Press (mine)');
      final all = await exercises.search(const ExerciseQuery(text: 'bench'));
      expect(all.map((e) => e.supplied), [true, false]);
    });
  });

  group('ArchiveExercise (TRN-012(2), TD-23)', () {
    test('hides from pickers, keeps history, and can be undone', () async {
      final e = _ok(
        await save(
          name: 'Row',
          type: ExerciseType.weighted,
          category: ExerciseCategory.pull,
          primaryMuscle: MuscleGroup.lats,
        ),
      );
      await seedSession(
        sessions,
        WorkoutSession(
          id: 's',
          name: 'S',
          startedAt: _t,
          createdAt: _t,
          updatedAt: _t,
        ),
      );
      final record = RecordSet(
        exercises: exercises,
        sessions: sessions,
        newId: newId,
      );
      _ok(
        await record(
          sessionId: 's',
          exerciseId: e.id,
          data: SetData.weighted(load: LoadKg.fromStored(40), reps: 10),
        ),
      );

      _ok(await archive(e.id));
      expect(await exercises.search(const ExerciseQuery()), isEmpty);
      expect(
        await exercises.search(const ExerciseQuery(includeArchived: true)),
        hasLength(1),
      );
      final history = await sessions.sessionsForExercise(e.id);
      expect(history.single.sets, hasLength(1));
      expect(await sessions.lastPerformance(e.id), hasLength(1));

      _ok(await archive(e.id, archived: false));
      expect(await exercises.search(const ExerciseQuery()), hasLength(1));
    });

    test(
      'a deleted or unknown exercise is not found and not touched',
      () async {
        expect(_err(await archive('nope')), isA<NotFoundError>());
        await seedSupplied();
        await exercises.delete('lib-bench');
        expect(_err(await archive('lib-bench')), isA<NotFoundError>());
        final row = await db.select(db.exercises).getSingle();
        expect(row.archived, isFalse);
      },
    );

    test('a supplied exercise can be archived too', () async {
      await seedSupplied();
      _ok(await archive('lib-bench'));
      expect(await exercises.search(const ExerciseQuery()), isEmpty);
    });
  });

  group('SavePlan (TRN-013)', () {
    Future<void> seedExercises() async {
      for (final (id, type) in [
        ('bench', ExerciseType.weighted),
        ('plank', ExerciseType.timed),
        ('run', ExerciseType.cardio),
      ]) {
        await exercises.upsert(
          Exercise(
            id: id,
            name: id,
            type: type,
            category: ExerciseCategory.push,
            primaryMuscle: MuscleGroup.chest,
            createdAt: _t,
            updatedAt: _t,
          ),
        );
      }
    }

    PlanExercise pe(
      String exerciseId, {
      int sets = 3,
      int? min = 8,
      int? max = 10,
    }) => PlanExercise(
      id: '',
      exerciseId: exerciseId,
      sortOrder: 99,
      targetSets: sets,
      repsMin: min,
      repsMax: max,
      restSeconds: 120,
    );

    test(
      'stores 3 sets of 8 to 10 reps with 120 s rest and reads them back',
      () async {
        await seedExercises();
        final plan = _ok(
          await savePlan(
            name: ' Push A ',
            planExercises: [
              pe('bench'),
              const PlanExercise(
                id: '',
                exerciseId: 'plank',
                sortOrder: 5,
                targetSets: 2,
                targetDuration: Duration(seconds: 60),
              ),
              const PlanExercise(
                id: '',
                exerciseId: 'run',
                sortOrder: 7,
                targetSets: 1,
                targetMetres: 5000,
              ),
            ],
            scheduledWeekdays: const [3, 1],
          ),
        );
        expect(plan.name, 'Push A');
        expect(plan.scheduledWeekdays, [1, 3]);
        final back = (await plans.byId(plan.id))!;
        expect(back, plan);
        final bench = back.exercises.first;
        expect(
          [bench.targetSets, bench.repsMin, bench.repsMax, bench.restSeconds],
          [3, 8, 10, 120],
        );
        expect(back.exercises.map((e) => e.sortOrder), [0, 1, 2]);
        expect(back.exercises.map((e) => e.id).toSet(), hasLength(3));
        expect(back.exercises[1].targetDuration, const Duration(seconds: 60));
        expect(back.exercises[2].targetMetres, 5000);
      },
    );

    test(
      'reordering with the domain rule and saving keeps the new order',
      () async {
        await seedExercises();
        final plan = _ok(
          await savePlan(
            name: 'P',
            planExercises: [
              pe('bench'),
              pe('bench', sets: 4),
              pe('bench', sets: 5),
            ],
          ),
        );
        final moved = _ok(reorderPlanExercises(plan.exercises, 2, 0));
        final saved = _ok(
          await savePlan(id: plan.id, name: 'P', planExercises: moved),
        );
        final back = (await plans.byId(plan.id))!;
        expect(back.exercises.map((e) => e.targetSets), [5, 3, 4]);
        expect(back.exercises.map((e) => e.sortOrder), [0, 1, 2]);
        expect(saved.createdAt, plan.createdAt);
      },
    );

    test(
      'rejects invalid targets, unknown exercises and bad weekdays',
      () async {
        await seedExercises();
        Future<AppError> fails(
          List<PlanExercise> list, {
          String name = 'P',
          List<int> days = const [],
        }) async => _err(
          await savePlan(
            name: name,
            planExercises: list,
            scheduledWeekdays: days,
          ),
        );

        expect(
          ((await fails([pe('bench', sets: 0)])) as ValidationError).field,
          'targetSets',
        );
        expect(
          ((await fails([
            pe('bench', min: 10, max: 8),
          ])) as ValidationError).field,
          'reps',
        );
        expect(
          ((await fails([pe('plank')])) as ValidationError).field,
          'reps',
          reason: 'a rep target on a timed exercise',
        );
        expect(await fails([pe('ghost')]), isA<NotFoundError>());
        expect(((await fails([], name: ' ')) as ValidationError).field, 'name');
        expect(
          ((await fails([], days: [0])) as ValidationError).field,
          'scheduledWeekdays',
        );
        expect(
          ((await fails([], days: [1, 1])) as ValidationError).field,
          'scheduledWeekdays',
        );
        expect(await plans.watchAll().first, isEmpty);
      },
    );

    test('an archived exercise cannot be added to a plan (L3)', () async {
      await seedExercises();
      expect(await exercises.archive('bench', archived: true), isTrue);
      final r = await savePlan(name: 'P', planExercises: [pe('bench')]);
      final error = _err(r) as ValidationError;
      expect(error.field, 'exerciseId');
      expect(error.message, contains('bench'));
      expect(await plans.watchAll().first, isEmpty);
      // Restoring it makes it usable again.
      await exercises.archive('bench', archived: false);
      expect(
        (await savePlan(name: 'P', planExercises: [pe('bench')])).isOk,
        isTrue,
      );
    });

    test('TD-42: re-saving a plan whose exercise was archived later is '
        'allowed for a rename and a reorder', () async {
      await seedExercises();
      final plan = _ok(
        await savePlan(
          name: 'P',
          planExercises: [pe('bench'), pe('plank', min: null, max: null)],
        ),
      );
      expect(await exercises.archive('bench', archived: true), isTrue);

      final renamed = _ok(
        await savePlan(
          id: plan.id,
          name: 'Renamed',
          planExercises: plan.exercises,
        ),
      );
      expect(renamed.name, 'Renamed');
      expect(renamed.exercises.map((e) => e.exerciseId), ['bench', 'plank']);

      final reordered = _ok(
        await savePlan(
          id: plan.id,
          name: 'Renamed',
          planExercises: renamed.exercises.reversed.toList(),
        ),
      );
      expect(reordered.exercises.map((e) => e.exerciseId), ['plank', 'bench']);
      expect((await plans.byId(plan.id))!.exercises.map((e) => e.exerciseId), [
        'plank',
        'bench',
      ]);
    });

    test('TD-42: a newly added archived exercise is still refused when '
        'editing an existing plan; the stored plan is unchanged', () async {
      await seedExercises();
      final plan = _ok(await savePlan(name: 'P', planExercises: [pe('bench')]));
      await exercises.upsert(
        Exercise(
          id: 'old',
          name: 'Old',
          type: ExerciseType.weighted,
          category: ExerciseCategory.push,
          primaryMuscle: MuscleGroup.chest,
          createdAt: _t,
          updatedAt: _t,
          archived: true,
        ),
      );
      final error = _err(
        await savePlan(
          id: plan.id,
          name: 'P',
          planExercises: [...plan.exercises, pe('old')],
        ),
      ) as ValidationError;
      expect(error.field, 'exerciseId');
      expect(error.message, contains('Old'));
      expect((await plans.byId(plan.id))!.exercises, hasLength(1));
      // An exercise the plan did not have is "new" even if the plan once had
      // another archived one: a different plan is not exempt.
      final other = await savePlan(name: 'Q', planExercises: [pe('old')]);
      expect(_err(other), isA<ValidationError>());
    });

    test('an unknown plan id is not found', () async {
      expect(
        _err(await savePlan(id: 'nope', name: 'P', planExercises: const [])),
        isA<NotFoundError>(),
      );
    });
  });

  group('SaveSplit (TRN-014)', () {
    Future<void> seedPlans() async {
      for (final id in ['upperA', 'lowerA', 'upperB', 'lowerB']) {
        _ok(await savePlan(name: id, planExercises: const []));
      }
    }

    test('saves Upper/Lower over a 7-day cycle with rest days', () async {
      await seedPlans();
      final all = await plans.watchAll().first;
      final byName = {for (final p in all) p.name: p.id};
      final split = _ok(
        await saveSplit(
          name: 'Upper/Lower',
          days: [
            byName['upperA'],
            byName['lowerA'],
            null,
            byName['upperB'],
            byName['lowerB'],
            null,
            null,
          ],
        ),
      );
      expect(split.cycleDays, 7);
      expect(split.days.where((d) => d.isRest), hasLength(3));
      expect(await splits.byId(split.id), split);
      expect(split.sortOrder, 0);
      final second = _ok(
        await saveSplit(name: 'Second', days: [byName['upperA']]),
      );
      expect(second.sortOrder, 1);
      final edited = _ok(
        await saveSplit(
          id: split.id,
          name: 'U/L',
          days: [byName['upperA'], null],
        ),
      );
      expect(edited.cycleDays, 2);
      expect(edited.sortOrder, 0);
      expect(edited.createdAt, split.createdAt);
    });

    test(
      'rejects an empty or too long cycle, all rest, unknown plans',
      () async {
        await seedPlans();
        final planId = (await plans.watchAll().first).first.id;
        expect(
          (_err(
            await saveSplit(name: 'S', days: const []),
          ) as ValidationError).field,
          'days',
        );
        expect(
          (_err(
            await saveSplit(name: 'S', days: List.filled(15, planId)),
          ) as ValidationError).field,
          'days',
        );
        expect(
          (_err(
            await saveSplit(name: 'S', days: [null, null]),
          ) as ValidationError).field,
          'days',
        );
        expect(
          _err(await saveSplit(name: 'S', days: ['ghost'])),
          isA<NotFoundError>(),
        );
        expect(
          _err(await saveSplit(id: 'nope', name: 'S', days: [planId])),
          isA<NotFoundError>(),
        );
        expect(
          (_err(
            await saveSplit(name: ' ', days: [planId]),
          ) as ValidationError).field,
          'name',
        );
        expect(await splits.watchAll().first, isEmpty);
        expect(
          (await saveSplit(
            name: 'Fourteen',
            days: List.filled(14, planId),
          )).isOk,
          isTrue,
        );
      },
    );
  });
}
