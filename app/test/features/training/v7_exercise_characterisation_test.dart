import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/db/drift_transactor.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_scheduled_workout_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_validation.dart';
import 'package:repforge/domain/training/volume.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/exercise_library_providers.dart';
import 'package:repforge/features/training/application/exercise_use_cases.dart';
import 'package:repforge/features/training/application/import_exercise_library.dart';
import 'package:repforge/features/training/application/plan_actions.dart';
import 'package:repforge/features/training/application/plan_use_cases.dart';
import 'package:repforge/features/training/application/record_set.dart';
import 'package:repforge/features/training/application/records_use_cases.dart';
import 'package:repforge/features/training/application/session_use_cases.dart';
import 'package:repforge/features/training/application/training_providers.dart';

import '../../helpers/seed_session.dart';

/// Characterisation of the v7 exercise model and the behaviour of exercise
/// selection, archived handling and the muscle fields, as the training
/// screens and use cases use them today (WP 8 stage 3d preparation,
/// `docs/wp8-stage-3d-call-sites.md`).
///
/// These tests pin what IS, including behaviour 3d may deliberately change
/// (the single primary muscle, OQ-19 volume, retired versus archived). When
/// 3d changes one of them the failing test names the rule; the change is then
/// a decision, not an accident. Tests only: no production behaviour changes.
final _now = DateTime.utc(2026, 11, 5, 10);
final _clock = FixedClock(_now);
final _t = DateTime.utc(2026, 11, 1, 9);

LoadKg _kg(double v) => LoadKg.fromStored(v);
SetData _w(double kg, int reps) => SetData.weighted(load: _kg(kg), reps: reps);

Exercise _ex(
  String id, {
  String? name,
  ExerciseType type = ExerciseType.weighted,
  ExerciseCategory category = ExerciseCategory.push,
  MuscleGroup primary = MuscleGroup.chest,
  List<MuscleGroup> secondary = const [],
  List<Equipment> equipment = const [],
  List<String> aliases = const [],
  bool supplied = false,
  bool archived = false,
  String? copiedFromId,
}) => Exercise(
  id: id,
  name: name ?? 'Name $id',
  type: type,
  category: category,
  primaryMuscle: primary,
  secondaryMuscles: secondary,
  equipment: equipment,
  aliases: aliases,
  supplied: supplied,
  archived: archived,
  copiedFromId: copiedFromId,
  createdAt: _t,
  updatedAt: _t,
);

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final error) => fail('expected Ok, got ${error.message}'),
};

ValidationError _invalid<T>(Result<T> r) => switch (r) {
  Err(:final error) when error is ValidationError => error,
  _ => fail('expected a ValidationError'),
};

AppError _err<T>(Result<T> r) => switch (r) {
  Err(:final error) => error,
  Ok() => fail('expected Err'),
};

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  late DriftWorkoutSessionRepository sessions;
  late DriftWorkoutPlanRepository plans;
  late DriftScheduledWorkoutRepository scheduled;
  late DriftSettingsRepository settings;
  late RecordSet record;
  var n = 0;
  String newId() => 'id${n++}';

  setUp(() {
    db = AppDatabase.inMemory();
    n = 0;
    exercises = DriftExerciseRepository(db, clock: _clock);
    sessions = DriftWorkoutSessionRepository(db, clock: _clock);
    plans = DriftWorkoutPlanRepository(db, clock: _clock);
    scheduled = DriftScheduledWorkoutRepository(db);
    settings = DriftSettingsRepository(db, clock: _clock);
    record = RecordSet(exercises: exercises, sessions: sessions, newId: newId);
  });
  tearDown(() => db.close());

  SavePlan savePlan() =>
      SavePlan(plans: plans, exercises: exercises, clock: _clock, newId: newId);

  PlanExercise planRow(String exerciseId) => PlanExercise(
    id: '',
    exerciseId: exerciseId,
    sortOrder: 0,
    targetSets: 3,
    repsMin: 5,
    repsMax: 8,
  );

  Future<void> importSeed() async {
    final result = await ImportExerciseLibrary(
      exercises: exercises,
      settings: settings,
      clock: _clock,
      loadJson: () => File('assets/seed/exercise_library.json').readAsString(),
    ).call();
    expect(result.isOk, isTrue);
  }

  group('the v7 Exercise value', () {
    test('has exactly these fields and defaults (3d replaces them)', () {
      final e = Exercise(
        id: 'a',
        name: 'A',
        type: ExerciseType.weighted,
        category: ExerciseCategory.push,
        primaryMuscle: MuscleGroup.chest,
        createdAt: _t,
        updatedAt: _t,
      );
      expect(e.secondaryMuscles, isEmpty);
      expect(e.equipment, isEmpty);
      expect(e.aliases, isEmpty);
      expect(e.supplied, isFalse);
      expect(e.copiedFromId, isNull);
      expect(e.archived, isFalse);
      expect(e.isCustom, isTrue);
      expect(
        e.toString(),
        'Exercise(id: a, name: A, type: ExerciseType.weighted, category: '
        'ExerciseCategory.push, primaryMuscle: MuscleGroup.chest, createdAt: '
        '$_t, updatedAt: $_t, secondaryMuscles: [], equipment: [], aliases: '
        '[], supplied: false, copiedFromId: null, archived: false)',
      );
    });

    test('the search key is the name and aliases, lower-cased, diacritics '
        'folded', () {
      final e = _ex('a', name: 'Pull-up', aliases: ['Chin Über', 'Pullup']);
      expect(e.searchKey, 'pull-up chin uber pullup');
      expect(exerciseSearchKey('Café', const []), 'cafe');
    });

    test('there are 19 muscle groups and fullBody is one of them', () {
      expect(MuscleGroup.values, hasLength(19));
      expect(MuscleGroup.values, contains(MuscleGroup.fullBody));
    });
  });

  group('the bundled v7 library as imported at first start', () {
    test(
      '89 supplied, active exercises, each with one primary muscle',
      () async {
        await importSeed();
        final all = await exercises.watchAll(includeArchived: true).first;
        expect(all, hasLength(89));
        expect(all.every((e) => e.supplied && !e.archived), isTrue);
        expect(all.every((e) => e.copiedFromId == null), isTrue);
        expect(
          {for (final e in all) e.id}.length,
          89,
          reason: 'ids are unique and are the ids WP 17 plans use',
        );
      },
    );

    test(
      'the muscle fields of the seed, by primary muscle and category',
      () async {
        await importSeed();
        final all = await exercises.watchAll().first;
        Map<String, int> count(String Function(Exercise) key) {
          final m = <String, int>{};
          for (final e in all) {
            m.update(key(e), (c) => c + 1, ifAbsent: () => 1);
          }
          return Map.fromEntries(
            m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
          );
        }

        expect(count((e) => e.primaryMuscle.name), {
          'abductors': 1,
          'abs': 6,
          'adductors': 1,
          'biceps': 5,
          'calves': 2,
          'chest': 9,
          'forearms': 2,
          'frontDelts': 3,
          'fullBody': 6,
          'glutes': 8,
          'hamstrings': 5,
          'lats': 7,
          'lowerBack': 1,
          'obliques': 2,
          'quadriceps': 17,
          'rearDelts': 2,
          'sideDelts': 1,
          'triceps': 5,
          'upperBack': 6,
        });
        expect(count((e) => e.category.name), {
          'cardio': 8,
          'core': 10,
          'fullBody': 5,
          'legs': 24,
          'mobility': 8,
          'pull': 18,
          'push': 16,
        });
        expect(all.fold<int>(0, (s, e) => s + e.secondaryMuscles.length), 162);
      },
    );

    test('specific seed rows 3d must map: a plain one, a support-bar one and '
        'one with a fullBody secondary', () async {
      await importSeed();
      final squat = (await exercises.byId('lib-back-squat'))!;
      expect(squat.primaryMuscle, MuscleGroup.quadriceps);
      expect(squat.secondaryMuscles, [
        MuscleGroup.glutes,
        MuscleGroup.adductors,
        MuscleGroup.lowerBack,
      ]);
      expect(squat.equipment, [Equipment.barbell, Equipment.squatRack]);
      final row = (await exercises.byId('lib-inverted-row'))!;
      expect(row.primaryMuscle, MuscleGroup.upperBack);
      expect(row.equipment, [Equipment.barbell, Equipment.squatRack]);
      final skipping = (await exercises.byId('lib-skipping'))!;
      expect(skipping.primaryMuscle, MuscleGroup.calves);
      expect(skipping.secondaryMuscles, [MuscleGroup.fullBody]);
    });

    test('importing again does nothing; a user-removed exercise stays '
        'removed', () async {
      await importSeed();
      expect(await exercises.delete('lib-plank'), isTrue);
      final again = await ImportExerciseLibrary(
        exercises: exercises,
        settings: settings,
        clock: _clock,
        loadJson: () =>
            File('assets/seed/exercise_library.json').readAsString(),
      ).call();
      expect(_ok(again).alreadyDone, isTrue);
      expect(await exercises.byId('lib-plank'), isNull);
      expect(await exercises.exists('lib-plank'), isTrue);
    });
  });

  group('selection (library, picker, filters)', () {
    setUp(importSeed);

    test('the picker query lists active exercises by name, ignoring case and '
        'diacritics', () async {
      final list = await exercises.search(const ExerciseQuery());
      expect(list, hasLength(89));
      final keys = [for (final e in list) e.name.toLowerCase()];
      expect(keys, [...keys]..sort());
    });

    test('a muscle filter lists primary matches first, then secondary '
        'ones, each by name', () async {
      final list = await exercises.search(
        const ExerciseQuery(muscle: MuscleGroup.chest),
      );
      final ids = [for (final e in list) e.id];
      expect(ids.take(9).toSet(), {
        'lib-bench-press',
        'lib-db-bench-press',
        'lib-incline-bench-press',
        'lib-incline-db-press',
        'lib-machine-chest-press',
        'lib-cable-fly',
        'lib-db-fly',
        'lib-push-up',
        'lib-doorway-chest-stretch',
      });
      expect(ids.skip(9).toSet(), {'lib-dips', 'lib-assisted-dip'});
      expect(
        list.take(9).every((e) => e.primaryMuscle == MuscleGroup.chest),
        isTrue,
      );
      expect(
        list.skip(9).every((e) => e.primaryMuscle != MuscleGroup.chest),
        isTrue,
      );
    });

    test('a muscle filter matches the secondary list, and fullBody is '
        'filterable like any muscle', () async {
      final list = await exercises.search(
        const ExerciseQuery(muscle: MuscleGroup.fullBody),
      );
      expect(
        {for (final e in list) e.id},
        {
          'lib-burpee',
          'lib-treadmill-run',
          'lib-rowing-machine',
          'lib-cross-trainer',
          'lib-skipping',
          'lib-run-400m',
          'lib-outdoor-run',
          // Primary fullBody entries that are not in the secondary lists above.
          ...[
            for (final e in await exercises.watchAll().first)
              if (e.primaryMuscle == MuscleGroup.fullBody) e.id,
          ],
        },
      );
      // A primary match always precedes a secondary-only match.
      final firstSecondary = list.indexWhere(
        (e) => e.primaryMuscle != MuscleGroup.fullBody,
      );
      expect(
        list
            .skip(firstSecondary < 0 ? list.length : firstSecondary)
            .every((e) => e.primaryMuscle != MuscleGroup.fullBody),
        isTrue,
      );
    });

    test('an empty equipment set is bodyweight only; null is no filter; a '
        'set shows subsets', () async {
      final bodyweight = await exercises.search(
        const ExerciseQuery(availableEquipment: <Equipment>{}),
      );
      expect(bodyweight, hasLength(20));
      expect(bodyweight.every((e) => e.equipment.isEmpty), isTrue);
      final dumbbells = await exercises.search(
        const ExerciseQuery(availableEquipment: {Equipment.dumbbell}),
      );
      expect(
        dumbbells.every(
          (e) => e.equipment.every((q) => q == Equipment.dumbbell),
        ),
        isTrue,
      );
      expect(dumbbells.length, greaterThan(bodyweight.length));
    });

    test(
      'text search matches name and aliases, every word, any case',
      () async {
        final bySquat = await exercises.search(
          const ExerciseQuery(text: 'SQUAT'),
        );
        expect(bySquat.map((e) => e.id), contains('lib-back-squat'));
        final byAlias = await exercises.search(
          const ExerciseQuery(text: 'jump rope'),
        );
        expect(byAlias.map((e) => e.id), ['lib-skipping']);
        expect(
          await exercises.search(const ExerciseQuery(text: 'zzz nothing')),
          isEmpty,
        );
      },
    );

    test(
      'category filter, and the combined filter is an intersection',
      () async {
        final legs = await exercises.search(
          const ExerciseQuery(category: ExerciseCategory.legs),
        );
        expect(legs, hasLength(24));
        final quadsLegs = await exercises.search(
          const ExerciseQuery(
            category: ExerciseCategory.legs,
            muscle: MuscleGroup.quadriceps,
          ),
        );
        expect(
          quadsLegs.every((e) => e.category == ExerciseCategory.legs),
          isTrue,
        );
        expect(quadsLegs.length, lessThanOrEqualTo(legs.length));
      },
    );

    test(
      'the live stream, the one-shot search and the pure filter agree',
      () async {
        const query = ExerciseQuery(muscle: MuscleGroup.lats, text: 'row');
        final streamed = await exercises.watchLibrary(query).first;
        final searched = await exercises.search(query);
        final pure = filterExercises(await exercises.watchAll().first, query);
        expect(
          [for (final e in streamed) e.id],
          [for (final e in searched) e.id],
        );
        expect([for (final e in pure) e.id], [for (final e in searched) e.id]);
      },
    );

    test('the providers the screens watch give the same lists', () async {
      final container = ProviderContainer(
        overrides: [exerciseRepositoryProvider.overrideWithValue(exercises)],
      );
      addTearDown(container.dispose);
      const query = ExerciseQuery(category: ExerciseCategory.core);
      final sub = container.listen(exerciseLibraryProvider(query), (_, _) {});
      addTearDown(sub.close);
      final fromProvider = await container.read(
        exerciseLibraryProvider(query).future,
      );
      expect(fromProvider, hasLength(10));
      for (final id in ['lib-plank', 'missing']) {
        addTearDown(
          container.listen(exerciseByIdProvider(id), (_, _) {}).close,
        );
      }
      final byId = await container.read(
        exerciseByIdProvider('lib-plank').future,
      );
      expect(byId?.name, isNotEmpty);
      expect(
        await container.read(exerciseByIdProvider('missing').future),
        isNull,
      );
    });
  });

  group('archived handling', () {
    test(
      'archived exercises leave the default lists but stay reachable',
      () async {
        await exercises.upsert(_ex('a', name: 'Alpha'));
        await exercises.upsert(_ex('b', name: 'Beta'));
        expect(await exercises.archive('b', archived: true), isTrue);
        expect((await exercises.watchAll().first).map((e) => e.id), ['a']);
        expect(
          (await exercises.watchAll(includeArchived: true).first).map(
            (e) => e.id,
          ),
          ['a', 'b'],
        );
        expect(
          (await exercises.search(const ExerciseQuery())).map((e) => e.id),
          ['a'],
        );
        expect(
          (await exercises.search(const ExerciseQuery(includeArchived: true)))
              .map((e) => e.id),
          ['a', 'b'],
        );
        expect((await exercises.byId('b'))!.archived, isTrue);
        expect(await exercises.exists('b'), isTrue);
        expect(await exercises.archive('b', archived: false), isTrue);
        expect((await exercises.watchAll().first).map((e) => e.id), ['a', 'b']);
      },
    );

    test('a deleted exercise is neither listed nor archivable, but its id '
        'still exists', () async {
      await exercises.upsert(_ex('a'));
      expect(await exercises.delete('a'), isTrue);
      expect(await exercises.byId('a'), isNull);
      expect(await exercises.exists('a'), isTrue);
      expect(await exercises.archive('a', archived: true), isFalse);
      expect(await exercises.delete('a'), isFalse);
      expect(
        _err(await ArchiveExercise(exercises: exercises)('a')),
        isA<NotFoundError>(),
      );
    });

    test('the provider behind the detail screen returns archived exercises; '
        'the library provider does not', () async {
      await exercises.upsert(_ex('a'));
      await exercises.archive('a', archived: true);
      final container = ProviderContainer(
        overrides: [exerciseRepositoryProvider.overrideWithValue(exercises)],
      );
      addTearDown(container.dispose);
      final byId = container.listen(exerciseByIdProvider('a'), (_, _) {});
      final lib = container.listen(
        exerciseLibraryProvider(const ExerciseQuery()),
        (_, _) {},
      );
      addTearDown(byId.close);
      addTearDown(lib.close);
      expect(
        (await container.read(exerciseByIdProvider('a').future))?.archived,
        isTrue,
      );
      expect(
        await container.read(
          exerciseLibraryProvider(const ExerciseQuery()).future,
        ),
        isEmpty,
      );
    });

    test('a supplied exercise can be archived; the archived flag is not '
        'copied to a custom copy', () async {
      await exercises.upsert(_ex('s', supplied: true, archived: true));
      final copy = _ok(
        await CopySuppliedExercise(
          exercises: exercises,
          clock: _clock,
          newId: newId,
        )(sourceId: 's', name: 'My copy'),
      );
      expect(copy.archived, isFalse);
      expect(copy.supplied, isFalse);
      expect(copy.copiedFromId, 's');
      expect(copy.isCustom, isTrue);
    });

    test('editing an archived custom exercise keeps it archived', () async {
      await exercises.upsert(_ex('c', archived: true));
      final saved = _ok(
        await SaveCustomExercise(
          exercises: exercises,
          sessions: sessions,
          plans: plans,
          clock: _clock,
          newId: newId,
        )(
          id: 'c',
          name: 'Renamed',
          type: ExerciseType.weighted,
          category: ExerciseCategory.push,
          primaryMuscle: MuscleGroup.chest,
        ),
      );
      expect(saved.archived, isTrue);
      expect((await exercises.byId('c'))!.name, 'Renamed');
    });

    test('a plan refuses a newly added archived exercise but keeps one it '
        'already lists (TD-42)', () async {
      await exercises.upsert(_ex('a'));
      await exercises.upsert(_ex('b'));
      final plan = _ok(
        await savePlan()(
          name: 'Day 1',
          planExercises: [planRow('a'), planRow('b')],
        ),
      );
      await exercises.archive('b', archived: true);
      await exercises.upsert(_ex('c', archived: true));
      final refused = _invalid(
        await savePlan()(
          id: plan.id,
          name: 'Day 1',
          planExercises: [planRow('a'), planRow('b'), planRow('c')],
        ),
      );
      expect(refused.field, 'exerciseId');
      expect(refused.message, contains('is archived'));
      final renamed = _ok(
        await savePlan()(
          id: plan.id,
          name: 'Day 1 renamed',
          planExercises: [planRow('a'), planRow('b')],
        ),
      );
      expect(renamed.exercises.map((e) => e.exerciseId), ['a', 'b']);
    });

    test('starting from a plan skips archived and deleted exercises with a '
        'warning and still starts', () async {
      for (final id in ['a', 'b', 'c']) {
        await exercises.upsert(_ex(id, name: 'N$id'));
      }
      final plan = _ok(
        await savePlan()(
          name: 'Day',
          planExercises: [planRow('a'), planRow('b'), planRow('c')],
        ),
      );
      await exercises.archive('b', archived: true);
      await exercises.delete('c');
      final started = _ok(
        await StartSessionFromPlan(
          plans: plans,
          sessions: sessions,
          exercises: exercises,
          scheduled: scheduled,
          transactor: DriftTransactor(db),
          clock: _clock,
          newId: newId,
        )(planId: plan.id),
      );
      expect(started.session.exercises.map((e) => e.exerciseId), ['a']);
      expect(
        {for (final w in started.warnings) w.exerciseId: w.reason},
        {'b': StartSkipReason.archived, 'c': StartSkipReason.missing},
      );
      expect(
        started.warnings.firstWhere((w) => w.exerciseId == 'b').exerciseName,
        'Nb',
      );
      expect(
        started.warnings.firstWhere((w) => w.exerciseId == 'c').exerciseName,
        isNull,
      );
    });

    test('adding, replacing and recording refuse an archived exercise, with '
        'one message', () async {
      await exercises.upsert(_ex('a'));
      await exercises.upsert(_ex('b'));
      final session = _ok(
        await StartEmptySession(
          sessions: sessions,
          clock: _clock,
          newId: newId,
        )(name: 'Today'),
      );
      final entry = _ok(
        await AddSessionExercise(
          sessions: sessions,
          exercises: exercises,
          newId: newId,
        )(sessionId: session.id, exerciseId: 'a'),
      );
      await exercises.archive('b', archived: true);
      const message = 'An archived exercise cannot be used. Restore it first.';

      final add = _invalid(
        await AddSessionExercise(
          sessions: sessions,
          exercises: exercises,
          newId: newId,
        )(sessionId: session.id, exerciseId: 'b'),
      );
      expect(add.message, message);
      expect(add.field, 'exerciseId');

      final replace = _invalid(
        await ReplaceSessionExercise(
          sessions: sessions,
          exercises: exercises,
          transactor: DriftTransactor(db),
          newId: newId,
        )(
          sessionId: session.id,
          sessionExerciseId: entry.id,
          newExerciseId: 'b',
        ),
      );
      expect(replace.message, message);

      // Recording on an entry whose exercise was archived afterwards.
      await exercises.archive('a', archived: true);
      final recorded = _invalid(
        await record(
          sessionId: session.id,
          sessionExerciseId: entry.id,
          data: _w(60, 5),
        ),
      );
      expect(recorded.message, message);
      expect((await sessions.byId(session.id))!.sets, isEmpty);
    });

    test('history keeps archived exercises: sets stay readable and editable '
        'by type', () async {
      await exercises.upsert(_ex('a'));
      final session = _ok(
        await StartEmptySession(
          sessions: sessions,
          clock: _clock,
          newId: newId,
        )(name: 'Today'),
      );
      _ok(
        await AddSessionExercise(
          sessions: sessions,
          exercises: exercises,
          newId: newId,
        )(sessionId: session.id, exerciseId: 'a'),
      );
      final stored = _ok(
        await recordFor(
          record,
          sessions,
          sessionId: session.id,
          exerciseId: 'a',
          data: _w(80, 5),
        ),
      );
      await exercises.archive('a', archived: true);
      expect((await sessions.byId(session.id))!.sets.single.id, stored.id);
      final edited = _ok(
        await EditSet(exercises: exercises, sessions: sessions)(
          sessionId: session.id,
          setId: stored.id,
          data: _w(85, 5),
        ),
      );
      expect(edited.data, _w(85, 5));
    });

    test('a set of a deleted exercise is validated by the type of the set it '
        'holds (EditSet fallback uses fullBody as a placeholder)', () async {
      await exercises.upsert(_ex('a'));
      final session = _ok(
        await StartEmptySession(
          sessions: sessions,
          clock: _clock,
          newId: newId,
        )(name: 'Today'),
      );
      final stored = _ok(
        await recordFor(
          record,
          sessions,
          sessionId: session.id,
          exerciseId: 'a',
          data: _w(80, 5),
        ),
      );
      await exercises.delete('a');
      final edited = _ok(
        await EditSet(exercises: exercises, sessions: sessions)(
          sessionId: session.id,
          setId: stored.id,
          data: _w(90, 3),
        ),
      );
      expect(edited.data, _w(90, 3));
    });

    test('saving a workout as a plan leaves out archived and removed '
        'exercises and says so', () async {
      await exercises.upsert(_ex('a', name: 'Alpha'));
      await exercises.upsert(_ex('b', name: 'Beta'));
      await exercises.upsert(_ex('c', name: 'Gamma'));
      final session = _ok(
        await StartEmptySession(
          sessions: sessions,
          clock: _clock,
          newId: newId,
        )(name: 'Today'),
      );
      for (final id in ['a', 'b', 'c']) {
        _ok(
          await recordFor(
            record,
            sessions,
            sessionId: session.id,
            exerciseId: id,
            data: _w(50, 8),
          ),
        );
      }
      await exercises.archive('b', archived: true);
      await exercises.delete('c');
      final outcome = _ok(
        await SaveSessionAsPlan(
          sessions: sessions,
          exercises: exercises,
          savePlan: savePlan(),
        )(session.id),
      );
      expect(outcome.plan.exercises.map((e) => e.exerciseId), ['a']);
      expect(outcome.skippedNames, ['Beta', 'Removed exercise']);
    });
  });

  group('the muscle fields', () {
    test(
      'a primary muscle is required by the use case, with its field name',
      () async {
        final error = _invalid(
          await SaveCustomExercise(
            exercises: exercises,
            sessions: sessions,
            plans: plans,
            clock: _clock,
            newId: newId,
          )(
            name: 'X',
            type: ExerciseType.weighted,
            category: ExerciseCategory.push,
            primaryMuscle: null,
          ),
        );
        expect(error.field, 'primary');
        expect(error.message, 'Choose a primary muscle group.');
      },
    );

    test('the primary muscle cannot repeat among the secondary ones; '
        'duplicates collapse in order', () {
      final repeated = _invalid(
        validateExercise(_ex('a', secondary: [MuscleGroup.chest])),
      );
      expect(repeated.field, 'secondaryMuscles');
      final ok = _ok(
        validateExercise(
          _ex(
            'a',
            secondary: [
              MuscleGroup.triceps,
              MuscleGroup.frontDelts,
              MuscleGroup.triceps,
            ],
            equipment: [Equipment.barbell, Equipment.barbell],
          ),
        ),
      );
      expect(ok.secondaryMuscles, [
        MuscleGroup.triceps,
        MuscleGroup.frontDelts,
      ]);
      expect(ok.equipment, [Equipment.barbell]);
    });

    test('fullBody is accepted as a primary like any other muscle', () {
      expect(
        validateExercise(_ex('a', primary: MuscleGroup.fullBody)).isOk,
        isTrue,
      );
    });

    test('the primary and secondary lists survive storage in order', () async {
      final e = _ex(
        'a',
        primary: MuscleGroup.lats,
        secondary: [
          MuscleGroup.biceps,
          MuscleGroup.rearDelts,
          MuscleGroup.forearms,
        ],
        equipment: [Equipment.pullUpBar, Equipment.resistanceBand],
        aliases: ['Chin', 'Pull'],
      );
      await exercises.upsert(e);
      expect(await exercises.byId('a'), e);
    });

    test('a stored row with an identifier outside the taxonomy is skipped, '
        'not guessed', () async {
      await exercises.upsert(_ex('good'));
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              id: 'bad',
              name: 'Bad',
              type: 'weighted',
              category: 'push',
              primaryMuscle: 'bogus',
              secondaryMusclesJson: '[]',
              equipmentJson: '[]',
              createdAt: _t,
              updatedAt: _t,
            ),
          );
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              id: 'bad-secondary',
              name: 'Bad secondary',
              type: 'weighted',
              category: 'push',
              primaryMuscle: 'chest',
              secondaryMusclesJson: '["triceps","bogus"]',
              equipmentJson: '[]',
              createdAt: _t,
              updatedAt: _t,
              archived: const Value(false),
            ),
          );
      expect((await exercises.watchAll().first).map((e) => e.id), ['good']);
      expect(await exercises.byId('bad'), isNull);
      expect(await exercises.byId('bad-secondary'), isNull);
      expect(await exercises.exists('bad'), isTrue);
    });

    test('a custom copy takes the source muscles unless the edit gives its '
        'own', () async {
      await exercises.upsert(
        _ex(
          's',
          supplied: true,
          primary: MuscleGroup.quadriceps,
          secondary: [MuscleGroup.glutes],
        ),
      );
      final copy = CopySuppliedExercise(
        exercises: exercises,
        clock: _clock,
        newId: newId,
      );
      final same = _ok(await copy(sourceId: 's'));
      expect(same.primaryMuscle, MuscleGroup.quadriceps);
      expect(same.secondaryMuscles, [MuscleGroup.glutes]);
      final changed = _ok(
        await copy(
          sourceId: 's',
          primaryMuscle: MuscleGroup.hamstrings,
          secondaryMuscles: const [],
        ),
      );
      expect(changed.primaryMuscle, MuscleGroup.hamstrings);
      expect(changed.secondaryMuscles, isEmpty);
      expect(_err(await copy(sourceId: 'missing')), isA<NotFoundError>());
    });

    test('a supplied exercise cannot be edited in place; only supplied ones '
        'are copied', () async {
      await exercises.upsert(_ex('s', supplied: true));
      await exercises.upsert(_ex('c'));
      final save = SaveCustomExercise(
        exercises: exercises,
        sessions: sessions,
        plans: plans,
        clock: _clock,
        newId: newId,
      );
      final edit = _invalid(
        await save(
          id: 's',
          name: 'X',
          type: ExerciseType.weighted,
          category: ExerciseCategory.push,
          primaryMuscle: MuscleGroup.chest,
        ),
      );
      expect(edit.field, 'id');
      final copyOfCustom = _invalid(
        await CopySuppliedExercise(
          exercises: exercises,
          clock: _clock,
          newId: newId,
        )(sourceId: 'c'),
      );
      expect(copyOfCustom.field, 'id');
    });
  });

  group('per-muscle volume today (the rule OQ-19 changes in 3d)', () {
    SessionSet set(
      String exerciseId,
      SetData data, {
      bool completed = true,
      SetKind kind = SetKind.working,
    }) => SessionSet(
      id: 's-$exerciseId-${n++}',
      sessionId: 'x',
      exerciseId: exerciseId,
      exerciseOrder: 0,
      setOrder: n,
      data: data,
      completed: completed,
      kind: kind,
    );

    test('a set counts in full for the single primary muscle and, separately, '
        'for each secondary muscle', () {
      final bench = _ex(
        'bench',
        secondary: [MuscleGroup.triceps, MuscleGroup.frontDelts],
      );
      final out = VolumeRules.byMuscle(
        [set('bench', _w(100, 5)), set('bench', _w(100, 5))],
        {'bench': bench},
      );
      expect(out[MuscleGroup.chest]!.primary.loadKg, 1000);
      expect(out[MuscleGroup.chest]!.primary.sets, 2);
      expect(out[MuscleGroup.chest]!.secondary.sets, 0);
      expect(out[MuscleGroup.triceps]!.secondary.loadKg, 1000);
      expect(out[MuscleGroup.triceps]!.primary.sets, 0);
      expect(out[MuscleGroup.frontDelts]!.secondary.sets, 2);
      expect(out.keys.toSet(), {
        MuscleGroup.chest,
        MuscleGroup.triceps,
        MuscleGroup.frontDelts,
      });
    });

    test('warm-ups, uncompleted sets and exercises that are not known add '
        'nothing; a duplicated secondary counts once per set', () {
      final e = _ex(
        'e',
        primary: MuscleGroup.lats,
        secondary: [MuscleGroup.biceps, MuscleGroup.biceps],
      );
      final out = VolumeRules.byMuscle(
        [
          set('e', _w(50, 10), kind: SetKind.warmUp),
          set('e', _w(50, 10), completed: false),
          set('unknown', _w(50, 10)),
          set('e', _w(60, 10)),
        ],
        {'e': e},
      );
      expect(out[MuscleGroup.lats]!.primary.sets, 1);
      expect(out[MuscleGroup.biceps]!.secondary.sets, 1);
      expect(out.keys.toSet(), {MuscleGroup.lats, MuscleGroup.biceps});
    });

    test('a bodyweight set adds repetitions and no kilograms; a fullBody '
        'primary is an ordinary row', () {
      final e = _ex(
        'burpee',
        type: ExerciseType.bodyweight,
        primary: MuscleGroup.fullBody,
      );
      final out = VolumeRules.byMuscle(
        [set('burpee', const SetData.bodyweight(reps: 12))],
        {'burpee': e},
      );
      expect(out[MuscleGroup.fullBody]!.primary.reps, 12);
      expect(out[MuscleGroup.fullBody]!.primary.loadKg, 0);
    });

    test(
      'the weekly use case attributes by the exercise as it is stored now',
      () async {
        await exercises.upsert(_ex('bench', secondary: [MuscleGroup.triceps]));
        final started = DateTime(2026, 11, 2, 18);
        await sessions.upsert(
          WorkoutSession(
            id: 'ws',
            name: 'Push',
            startedAt: started.toUtc(),
            endedAt: started.add(const Duration(minutes: 45)).toUtc(),
            createdAt: started.toUtc(),
            updatedAt: started.toUtc(),
          ),
        );
        await sessions.addExercise(
          const SessionExercise(
            id: 'ws-e0',
            sessionId: 'ws',
            exerciseId: 'bench',
            position: 0,
          ),
        );
        await sessions.addSet(
          SessionSet(
            id: 'ws-s0',
            sessionId: 'ws',
            exerciseId: 'bench',
            exerciseOrder: 0,
            setOrder: 0,
            sessionExerciseId: 'ws-e0',
            data: _w(80, 5),
            completed: true,
          ),
        );
        final weeks = _ok(
          await GetWeeklyVolume(sessions: sessions, exercises: exercises)(
            from: DateTime(2026, 11, 2),
            to: DateTime(2026, 11, 9),
            settings: const AppSettings(),
          ),
        );
        expect(weeks, hasLength(1));
        final week = weeks.single;
        expect(week.weekStart, DateTime(2026, 11, 2));
        expect(week.total.loadKg, 400);
        expect(week.byMuscle[MuscleGroup.chest]!.primary.loadKg, 400);
        expect(week.byMuscle[MuscleGroup.triceps]!.secondary.loadKg, 400);
      },
    );
  });
}
