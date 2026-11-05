import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show DataProvenance;
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/import_exercise_library.dart';
import 'package:repforge/features/training/application/record_set.dart';

import '../../../helpers/pump.dart';
import '../../../helpers/scrolling.dart';
import '../../../helpers/seed_session.dart';

final _now = DateTime(2026, 11, 5, 9);

LoadKg _kg(double v) => LoadKg.fromStored(v);

Exercise _custom(
  String id,
  String name,
  ExerciseType type, {
  List<String> aliases = const [],
  ExerciseCategory category = ExerciseCategory.legs,
  MuscleGroup primary = MuscleGroup.quadriceps,
  List<Equipment> equipment = const [],
}) => Exercise(
  id: id,
  name: name,
  type: type,
  category: category,
  primaryMuscle: primary,
  equipment: equipment,
  aliases: aliases,
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  late DriftWorkoutSessionRepository sessions;
  late DriftSettingsRepository settings;
  late RecordSet record;
  var n = 0;
  var gen = 0;

  setUp(() {
    db = AppDatabase.inMemory();
    final clock = FixedClock(_now);
    exercises = DriftExerciseRepository(db, clock: clock);
    sessions = DriftWorkoutSessionRepository(db, clock: clock);
    settings = DriftSettingsRepository(db, clock: clock);
    n = 0;
    gen = 0;
    record = RecordSet(
      exercises: exercises,
      sessions: sessions,
      newId: () => 'set-${n++}',
    );
  });
  tearDown(() => db.close());

  Future<void> importSeed() async {
    await ImportExerciseLibrary(
      exercises: exercises,
      settings: settings,
      clock: FixedClock(_now),
      loadJson: () async =>
          File('assets/seed/exercise_library.json').readAsStringSync(),
    )();
  }

  Future<void> session(String id) => seedSession(
    sessions,
    WorkoutSession(
      id: id,
      name: 'Session $id',
      startedAt: DateTime.utc(2026, 11, 4, 18),
      createdAt: _now.toUtc(),
      updatedAt: _now.toUtc(),
    ),
  );

  Future<void> rec(String sessionId, String exerciseId, SetData data) async {
    final r = await recordFor(
      record,
      sessions,
      sessionId: sessionId,
      exerciseId: exerciseId,
      data: data,
    );
    expect(r, isA<Ok<SessionSet>>(), reason: '$data');
  }

  Future<void> open(
    WidgetTester tester, {
    String location = RfRoutes.train,
    Key key = const ValueKey('scope'),
    Size size = const Size(390, 12000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: key,
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(_now)),
          idGeneratorProvider.overrideWithValue(() => 'gen-${gen++}'),
        ],
        child: RepForgeApp(router: createRouter(initialLocation: location)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('exercise-search')), text);
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(Key('exercise-$id'));

  testWidgets('lists the imported library with supplied and custom badges', (
    tester,
  ) async {
    await importSeed();
    await exercises.upsert(_custom('mine', 'My curl', ExerciseType.weighted));
    await open(tester);
    expect(find.text('Barbell back squat'), findsOneWidget);
    expect(find.text('My curl'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('badge-lib-back-squat')),
        matching: find.text('Supplied'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('badge-mine')),
        matching: find.text('Custom'),
      ),
      findsOneWidget,
    );
    // The row shows type, category, primary muscle and equipment.
    expect(
      find.descendant(
        of: row('lib-back-squat'),
        matching: find.text(
          'Weighted · Legs · Quadriceps · Barbell, Squat rack',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('new-exercise')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('search matches aliases and ignores case and diacritics', (
    tester,
  ) async {
    await importSeed();
    await exercises.upsert(
      _custom(
        'presse',
        'Presse à cuisses',
        ExerciseType.weighted,
        aliases: const ['Leg press'],
      ),
    );
    await open(tester);

    await search(tester, 'rdl');
    expect(find.text('Romanian deadlift'), findsOneWidget);
    expect(find.text('Dumbbell Romanian deadlift'), findsOneWidget);
    expect(find.text('Barbell back squat'), findsNothing);

    await search(tester, 'PRESSE A CUISSES');
    expect(find.text('Presse à cuisses'), findsOneWidget);
    await search(tester, 'presse à');
    expect(find.text('Presse à cuisses'), findsOneWidget);
    await search(tester, 'leg PRESS');
    expect(find.text('Presse à cuisses'), findsOneWidget);

    await search(tester, 'zzzz nothing');
    expect(find.byKey(const Key('exercises-empty')), findsOneWidget);
    expect(find.textContaining('No exercises match'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('category filter narrows the list', (tester) async {
    await importSeed();
    await open(tester);
    expect(find.text('Push-up'), findsOneWidget);
    await tapKey(tester, 'filter-category-core');
    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('Push-up'), findsNothing);
    await tapKey(tester, 'filter-category-core');
    expect(find.text('Push-up'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('muscle filter lists primary matches before secondary ones', (
    tester,
  ) async {
    await importSeed();
    // drift streams need real time, not the test's fake clock.
    final primary = (await tester.runAsync(
      () =>
          exercises.search(const ExerciseQuery(muscle: MuscleGroup.quadriceps)),
    ))!;
    await open(tester);
    await tapKey(tester, 'filter-muscle');
    await tapKey(tester, 'muscle-quadriceps');
    expect(find.text('Muscle: Quadriceps'), findsOneWidget);

    expect(primary, isNotEmpty);
    final lastPrimaryY = [
      for (final e in primary)
        if (e.primaryMuscle == MuscleGroup.quadriceps)
          tester.getTopLeft(row(e.id)).dy,
    ].reduce((a, b) => a > b ? a : b);
    // A deadlift trains quadriceps only as a secondary muscle.
    expect(row('lib-deadlift'), findsOneWidget);
    expect(
      tester.getTopLeft(row('lib-deadlift')).dy,
      greaterThan(lastPrimaryY),
    );
    expect(
      find.byKey(const Key('secondary-hint-lib-deadlift')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('secondary-hint-lib-back-squat')),
      findsNothing,
    );
    // Unrelated exercises are gone.
    expect(find.text('Plank'), findsNothing);
    await unmount(tester);
  });

  testWidgets('available equipment shows subsets and bodyweight, and is '
      'remembered', (tester) async {
    await importSeed();
    final allowed = (await tester.runAsync(
      () => exercises.search(
        const ExerciseQuery(availableEquipment: {Equipment.dumbbell}),
      ),
    ))!;
    await open(tester);
    expect(find.text('Barbell back squat'), findsOneWidget);

    await tapKey(tester, 'filter-equipment');
    await tapKey(tester, 'avail-dumbbell');
    await tapKey(tester, 'avail-done');
    expect(find.text('Equipment: 1 selected'), findsOneWidget);
    expect(find.text('Goblet squat'), findsOneWidget); // dumbbell
    expect(find.text('Push-up'), findsOneWidget); // bodyweight
    expect(find.text('Barbell back squat'), findsNothing);
    // Needs a dumbbell and a bench: not a subset of {dumbbell}.
    expect(find.text('Dumbbell bench press'), findsNothing);
    expect(allowed.every((e) => e.equipment.length <= 1), isTrue);
    expect(allowed.map((e) => e.name), contains('Push-up'));

    // "Restart": a brand new provider scope on the same database.
    await open(tester, key: const ValueKey('restarted'));
    expect(find.text('Equipment: 1 selected'), findsOneWidget);
    expect(find.text('Goblet squat'), findsOneWidget);
    expect(find.text('Barbell back squat'), findsNothing);

    // Clearing the selection shows everything again.
    await tapKey(tester, 'filter-equipment');
    await tapKey(tester, 'avail-dumbbell');
    await tapKey(tester, 'avail-done');
    expect(find.text('Barbell back squat'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('bodyweight only is a choice of its own, distinct from no '
      'filter, and is remembered (TRN-011(2), L2)', (tester) async {
    await importSeed();
    final bodyweightOnly = (await tester.runAsync(
      () => exercises.search(const ExerciseQuery(availableEquipment: {})),
    ))!;
    expect(bodyweightOnly, isNotEmpty);
    expect(bodyweightOnly.every((e) => e.equipment.isEmpty), isTrue);
    await open(tester);
    // No filter: everything, including equipment exercises.
    expect(find.text('Barbell back squat'), findsOneWidget);
    expect(find.text('Push-up'), findsOneWidget);

    await tapKey(tester, 'equipment-bodyweight-only');
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Barbell back squat'), findsNothing);
    expect(find.text('Goblet squat'), findsNothing);

    // "Restart": a new provider scope on the same database.
    await open(tester, key: const ValueKey('restarted'));
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Barbell back squat'), findsNothing);

    // Choosing equipment replaces it; switching it off shows everything.
    await tapKey(tester, 'filter-equipment');
    await tapKey(tester, 'avail-dumbbell');
    await tapKey(tester, 'avail-done');
    expect(find.text('Goblet squat'), findsOneWidget);
    await tapKey(tester, 'equipment-bodyweight-only');
    expect(find.text('Goblet squat'), findsNothing);
    await tapKey(tester, 'equipment-bodyweight-only');
    expect(find.text('Barbell back squat'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('cancelling the copy editor creates nothing; saving creates '
      'exactly one copy and leaves the supplied exercise unchanged (L1)', (
    tester,
  ) async {
    await importSeed();
    final before = (await tester.runAsync(
      () => db.select(db.exercises).get(),
    ))!;
    final supplied = (await tester.runAsync(
      () => exercises.byId('lib-back-squat'),
    ))!;
    await open(tester, location: RfRoutes.trainExercise('lib-back-squat'));

    Future<void> startCopy() async {
      await tapKey(tester, 'exercise-edit');
      await tapKey(tester, 'copy-confirm');
      expect(find.text('Edit exercise'), findsOneWidget);
      // Prefilled from the original.
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('exercise-name-field')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        supplied.name,
      );
    }

    await startCopy();
    await tester.pageBack();
    await tester.pumpAndSettle();
    var rows = (await tester.runAsync(() => db.select(db.exercises).get()))!;
    expect(rows, hasLength(before.length), reason: 'cancel creates nothing');
    expect(find.text('Edit exercise'), findsNothing);
    expect(find.byKey(const Key('detail-badge')), findsOneWidget);

    await startCopy();
    await tester.enterText(
      find.byKey(const Key('exercise-name-field')),
      'My squat',
    );
    await tapKey(tester, 'exercise-save');
    rows = (await tester.runAsync(() => db.select(db.exercises).get()))!;
    expect(rows, hasLength(before.length + 1));
    final copies = rows.where((r) => r.copiedFromId == 'lib-back-squat');
    expect(copies, hasLength(1));
    expect(copies.single.name, 'My squat');
    expect(copies.single.supplied, isFalse);
    final after = (await tester.runAsync(
      () => exercises.byId('lib-back-squat'),
    ))!;
    expect(after, supplied);
    await unmount(tester);
  });

  testWidgets('editing a supplied exercise creates a custom copy', (
    tester,
  ) async {
    await importSeed();
    await open(tester);
    await search(tester, 'back squat');
    await tester.tap(row('lib-back-squat'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-badge')), findsOneWidget);
    expect(find.text('Supplied'), findsOneWidget);
    expect(find.byKey(const Key('exercise-archive')), findsNothing);
    expect(find.byKey(const Key('field-primary')), findsOneWidget);
    expect(find.text('Quadriceps'), findsOneWidget);

    await tapKey(tester, 'exercise-edit');
    expect(find.text('Edit creates your own copy'), findsOneWidget);
    await tapKey(tester, 'copy-confirm');

    // The editor opened on the copy, pre-filled.
    expect(find.text('Edit exercise'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('exercise-name-field')),
      'My back squat',
    );
    await tapKey(tester, 'exercise-save');

    final supplied = await exercises.byId('lib-back-squat');
    expect(supplied!.name, 'Barbell back squat');
    expect(supplied.supplied, isTrue);
    final copy = (await exercises.byId('gen-0'))!;
    expect(copy.copiedFromId, 'lib-back-squat');
    expect(copy.name, 'My back squat');
    expect(copy.supplied, isFalse);
    expect(copy.equipment, supplied.equipment);
    await unmount(tester);
  });

  testWidgets('custom editor validates, then saves (phone size)', (
    tester,
  ) async {
    await open(tester, size: const Size(412, 915));
    await tapKey(tester, 'new-exercise');
    expect(find.text('New exercise'), findsWidgets);

    Future<void> save() async {
      await tester.scrollUntilVisible(
        find.byKey(const Key('exercise-save')),
        200,
        scrollable: lastPageScrollable(),
      );
      await tester.ensureVisible(find.byKey(const Key('exercise-save')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('exercise-save')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('exercise-save')));
      await tester.pumpAndSettle();
    }

    await save();
    expect(find.text('Choose a type.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('type-weighted')),
      -200,
      scrollable: lastPageScrollable(),
    );
    await tapKey(tester, 'type-weighted');
    expect(find.text('Choose a type.'), findsNothing);

    await save();
    expect(find.text('Choose a category.'), findsOneWidget);
    await tapKey(tester, 'category-legs');

    await save();
    expect(find.text('Choose a primary muscle group.'), findsOneWidget);
    await tapKey(tester, 'primary-muscle');
    await tapKey(tester, 'primary-quadriceps');
    expect(find.byKey(const Key('primary-muscle-value')), findsOneWidget);
    expect(find.text('Quadriceps'), findsOneWidget);

    // Name is still empty: the error shows beside the name field.
    await save();
    await tester.drag(lastPageScrollable(), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('exercise-name-field')),
        matching: find.text('Enter a name.'),
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('exercise-name-field')),
      -200,
      scrollable: lastPageScrollable(),
    );
    await tester.enterText(
      find.byKey(const Key('exercise-name-field')),
      'Spanish squat',
    );
    await tester.enterText(find.byKey(const Key('alias-input')), 'Wall squat');
    await tapKey(tester, 'alias-add');
    await tester.enterText(find.byKey(const Key('alias-input')), 'Temp');
    await tapKey(tester, 'alias-add');
    await tester.ensureVisible(find.byTooltip('Remove Temp'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Temp'));
    await tester.pumpAndSettle();
    expect(find.text('Temp'), findsNothing);
    expect(find.text('Wall squat'), findsOneWidget);

    // Secondary muscles exclude the primary one.
    await tapKey(tester, 'secondary-muscles');
    expect(find.byKey(const Key('secondary-quadriceps')), findsNothing);
    await tapKey(tester, 'secondary-glutes');
    await tapKey(tester, 'secondary-done');
    expect(find.text('Glutes'), findsOneWidget);

    await tapKey(tester, 'equipment');
    await tapKey(tester, 'equip-pullUpBar');
    await tapKey(tester, 'equip-done');
    expect(find.text('Pull-up bar'), findsOneWidget);

    await save();
    // The new exercise's detail opens with the saved values.
    expect(find.byKey(const Key('field-type')), findsOneWidget);
    expect(find.text('Spanish squat'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    final saved = (await exercises.byId(
      'gen-1',
    ))!; // gen-0 went to the failed attempt
    expect(saved.name, 'Spanish squat');
    expect(saved.aliases, ['Wall squat']);
    expect(saved.type, ExerciseType.weighted);
    expect(saved.secondaryMuscles, [MuscleGroup.glutes]);
    expect(saved.equipment, [Equipment.pullUpBar]);
    expect(saved.supplied, isFalse);
    await unmount(tester);
  });

  testWidgets('history shows each set type correctly', (tester) async {
    for (final (id, name, type) in [
      ('w', 'W', ExerciseType.weighted),
      ('b', 'B', ExerciseType.bodyweight),
      ('a', 'A', ExerciseType.assisted),
      ('t', 'T', ExerciseType.timed),
      ('d', 'D', ExerciseType.distance),
      ('c', 'C', ExerciseType.cardio),
    ]) {
      await exercises.upsert(_custom(id, name, type));
      await session('s-$id');
    }
    await rec('s-w', 'w', SetData.weighted(load: _kg(80), reps: 5));
    await rec('s-b', 'b', const SetData.bodyweight(reps: 12));
    await rec('s-b', 'b', SetData.bodyweight(reps: 8, addedLoad: _kg(10)));
    await rec('s-a', 'a', SetData.assisted(reps: 6, assistance: _kg(20)));
    await rec('s-t', 't', const SetData.timed(duration: Duration(seconds: 90)));
    await rec(
      's-t',
      't',
      SetData.timed(duration: const Duration(seconds: 45), addedLoad: _kg(10)),
    );
    await rec('s-d', 'd', const SetData.distance(metres: 400));
    await rec('s-d', 'd', const SetData.distance(metres: 1200));
    await rec(
      's-c',
      'c',
      const SetData.cardio(
        duration: Duration(minutes: 30),
        metres: 5000,
        averageHeartRate: 150,
        energyKcal: 300,
        energyProvenance: DataProvenance.estimated,
      ),
    );

    Future<void> detail(String id) => open(
      tester,
      location: RfRoutes.trainExercise(id),
      key: ValueKey('detail-$id'),
    );
    Finder text(String t) => find.text(t);

    await detail('w');
    expect(text('80 kg × 5'), findsOneWidget);
    await detail('b');
    expect(text('12 reps'), findsOneWidget);
    expect(text('8 reps + 10 kg'), findsOneWidget);
    await detail('a');
    expect(text('6 reps, 20 kg assistance'), findsOneWidget);
    expect(find.textContaining('20 kg ×'), findsNothing);
    await detail('t');
    expect(text('1:30'), findsOneWidget);
    expect(text('0:45 + 10 kg'), findsOneWidget);
    await detail('d');
    expect(text('400 m'), findsOneWidget);
    expect(text('1.2 km'), findsOneWidget);
    await detail('c');
    expect(
      text('30:00, 5 km, avg HR 150 bpm, 300 kcal (estimated)'),
      findsOneWidget,
    );
    expect(find.text('Session s-c'), findsOneWidget);
    expect(find.text('4 Nov 2026'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('history shows the session note and the entry notes of the '
      'exercise', (tester) async {
    await exercises.upsert(_custom('hist', 'Cable fly', ExerciseType.weighted));
    await session('s');
    await rec('s', 'hist', SetData.weighted(load: _kg(25), reps: 10));
    await sessions.upsert(
      (await sessions.byId('s'))!.copyWith(notes: 'Felt flat today'),
    );
    final entry = (await sessions.byId('s'))!.exercises.single;
    await sessions.updateExercise(
      SessionExercise(
        id: entry.id,
        sessionId: 's',
        exerciseId: 'hist',
        position: entry.position,
        note: 'Left shoulder pinched',
      ),
    );
    await open(tester, location: RfRoutes.trainExercise('hist'));
    expect(find.byKey(const Key('history-session-note-s')), findsOneWidget);
    expect(find.text('Felt flat today'), findsOneWidget);
    expect(find.byKey(const Key('history-entry-note-s-0')), findsOneWidget);
    expect(find.text('Left shoulder pinched'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('empty history state', (tester) async {
    await exercises.upsert(_custom('x', 'Unused', ExerciseType.weighted));
    await open(tester, location: RfRoutes.trainExercise('x'));
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    await open(
      tester,
      location: RfRoutes.trainExercise('nope'),
      key: const ValueKey('missing'),
    );
    expect(find.byKey(const Key('exercise-missing')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('archiving hides it from the library but history stays', (
    tester,
  ) async {
    await exercises.upsert(_custom('hist', 'Cable fly', ExerciseType.weighted));
    await exercises.upsert(_custom('keep', 'Other', ExerciseType.weighted));
    await session('s');
    await rec('s', 'hist', SetData.weighted(load: _kg(25), reps: 10));
    await open(tester);
    expect(find.text('Cable fly'), findsOneWidget);

    await tester.tap(row('hist'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-archived')), findsNothing);
    await tapKey(tester, 'exercise-archive');
    expect(find.byKey(const Key('detail-archived')), findsOneWidget);
    expect(find.text('Unarchive'), findsOneWidget);
    // History is still readable on the archived exercise.
    expect(find.text('25 kg × 10'), findsOneWidget);
    expect((await exercises.byId('hist'))!.archived, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Cable fly'), findsNothing);
    expect(find.text('Other'), findsOneWidget);

    await tapKey(tester, 'show-archived');
    expect(find.text('Cable fly'), findsOneWidget);
    expect(find.byKey(const Key('archived-hist')), findsOneWidget);
    await tester.tap(row('hist'));
    await tester.pumpAndSettle();
    expect(find.text('25 kg × 10'), findsOneWidget);
    await tapKey(tester, 'exercise-archive');
    expect(find.byKey(const Key('detail-archived')), findsNothing);
    expect((await exercises.byId('hist'))!.archived, isFalse);
    await unmount(tester);
  });

  testWidgets('the type is locked when the exercise has history', (
    tester,
  ) async {
    await exercises.upsert(_custom('hist', 'Cable fly', ExerciseType.weighted));
    await exercises.upsert(_custom('free', 'Free', ExerciseType.weighted));
    await session('s');
    await rec('s', 'hist', SetData.weighted(load: _kg(25), reps: 10));

    await open(
      tester,
      location: RfRoutes.trainExerciseEdit('hist'),
      size: const Size(412, 915),
    );
    expect(find.byKey(const Key('type-locked')), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(find.byKey(const Key('type-timed')));
    expect(chip.onSelected, isNull);

    await open(
      tester,
      location: RfRoutes.trainExerciseEdit('free'),
      size: const Size(412, 915),
      key: const ValueKey('free'),
    );
    expect(find.byKey(const Key('type-locked')), findsNothing);
    final free = tester.widget<ChoiceChip>(find.byKey(const Key('type-timed')));
    expect(free.onSelected, isNotNull);

    await open(
      tester,
      location: RfRoutes.trainExerciseEdit('lib-none'),
      size: const Size(412, 915),
      key: const ValueKey('missing'),
    );
    expect(find.text('That exercise no longer exists.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a supplied exercise has no direct editor', (tester) async {
    await importSeed();
    await open(tester, location: RfRoutes.trainExerciseEdit('lib-back-squat'));
    expect(find.byKey(const Key('editor-supplied')), findsOneWidget);
    await unmount(tester);
  });
}
