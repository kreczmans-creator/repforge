import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_training_split_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/training/training.dart';

import 'package:repforge/ui/components/rf_button.dart';

import '../../../helpers/pump.dart';
import '../../../helpers/scrolling.dart';

final _now = DateTime(2026, 11, 5, 9);

Exercise _exercise(
  String id,
  String name,
  ExerciseType type, {
  bool archived = false,
}) => Exercise(
  id: id,
  name: name,
  type: type,
  category: ExerciseCategory.legs,
  primaryMuscle: MuscleGroup.quadriceps,
  archived: archived,
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

WorkoutPlan _plan(
  String id,
  String name, {
  List<PlanExercise> exercises = const [],
  bool archived = false,
}) => WorkoutPlan(
  id: id,
  name: name,
  exercises: exercises,
  archived: archived,
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  late DriftWorkoutPlanRepository plans;
  late DriftTrainingSplitRepository splits;
  var gen = 0;

  setUp(() async {
    db = AppDatabase.inMemory();
    final clock = FixedClock(_now);
    exercises = DriftExerciseRepository(db, clock: clock);
    plans = DriftWorkoutPlanRepository(db, clock: clock);
    splits = DriftTrainingSplitRepository(db, clock: clock);
    gen = 0;
    await exercises.upsert(
      _exercise('squat', 'Back squat', ExerciseType.weighted),
    );
    await exercises.upsert(_exercise('plank', 'Plank', ExerciseType.timed));
    await exercises.upsert(_exercise('row', 'Rowing', ExerciseType.cardio));
    await exercises.upsert(
      _exercise('old', 'Old press', ExerciseType.weighted, archived: true),
    );
  });
  tearDown(() => db.close());

  Future<void> open(
    WidgetTester tester, {
    String location = RfRoutes.trainPlans,
    Size size = const Size(390, 3000),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      ProviderScope(
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
    if (f.evaluate().isEmpty) {
      // Off-screen slivers of a long form are not built yet.
      await tester.scrollUntilVisible(f, 300, scrollable: lastPageScrollable());
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      // Off-screen slivers of a long form are not built yet.
      await tester.scrollUntilVisible(f, 300, scrollable: lastPageScrollable());
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.enterText(f, text);
    await tester.pumpAndSettle();
  }

  Future<void> addExercise(WidgetTester tester, String id) async {
    await tapKey(tester, 'plan-add-exercise');
    await tapKey(tester, 'picker-exercise-$id');
  }

  String fieldText(WidgetTester tester, String key) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  String nameAt(WidgetTester tester, int i) =>
      tester.widget<Text>(find.byKey(Key('plan-exercise-name-$i'))).data!;

  group('plan list', () {
    testWidgets('lists plans and archives and restores one', (tester) async {
      await plans.upsert(_plan('p1', 'Upper A'));
      await plans.upsert(_plan('p2', 'Lower A'));
      await open(tester);

      expect(find.text('Upper A'), findsOneWidget);
      expect(find.text('Lower A'), findsOneWidget);
      expect(find.byKey(const Key('plans-show-archived')), findsNothing);

      await tapKey(tester, 'plan-archive-p1');
      expect(find.text('Upper A'), findsNothing);
      expect((await plans.byId('p1'))!.archived, isTrue);

      await tapKey(tester, 'plans-show-archived');
      expect(find.text('Upper A'), findsOneWidget);
      await tapKey(tester, 'plan-unarchive-p1');
      expect((await plans.byId('p1'))!.archived, isFalse);
      await unmount(tester);
    });

    testWidgets('shows an empty state and opens the builder', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('plans-empty')), findsOneWidget);
      expect(find.byKey(const Key('splits-empty')), findsOneWidget);
      await tapKey(tester, 'new-plan');
      expect(find.byKey(const Key('plan-name-field')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('is reachable from the Train tab', (tester) async {
      await open(tester, location: RfRoutes.train);
      await tapKey(tester, 'open-plans');
      expect(find.byKey(const Key('new-plan')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('plan builder', () {
    testWidgets(
      'creates a plan with a reps range and a timed exercise, reorders by '
      'buttons, saves and reopens in that order',
      (tester) async {
        await open(tester);
        await tapKey(tester, 'new-plan');
        await enter(tester, 'plan-name-field', 'Leg day');

        await addExercise(tester, 'squat');
        await enter(tester, 'plan-sets-0', '3');
        await enter(tester, 'plan-reps-min-0', '8');
        await enter(tester, 'plan-reps-max-0', '10');
        await enter(tester, 'plan-load-0', '102.5');
        await enter(tester, 'plan-rest-0', '120');

        await addExercise(tester, 'plank');
        // A timed exercise has a duration, no rep range.
        expect(find.byKey(const Key('plan-reps-min-1')), findsNothing);
        await enter(tester, 'plan-duration-1', '1:30');
        await enter(tester, 'plan-sets-1', '2');

        expect(nameAt(tester, 0), contains('Back squat'));
        await tapKey(tester, 'plan-move-up-1');
        expect(nameAt(tester, 0), contains('Plank'));
        expect(nameAt(tester, 1), contains('Back squat'));
        // Ends of the list cannot move further.
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('plan-move-up-0')))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('plan-move-down-1')))
              .onPressed,
          isNull,
        );

        await tapKey(tester, 'plan-save');
        // Back on the list.
        expect(find.text('Leg day'), findsOneWidget);
        expect(find.text('2 exercises'), findsOneWidget);

        final saved = (await plans.watchAll().first).single;
        expect(saved.name, 'Leg day');
        expect(
          [for (final e in saved.exercises) e.exerciseId],
          ['plank', 'squat'],
        );
        expect(saved.exercises[0].targetDuration, const Duration(seconds: 90));
        expect(saved.exercises[0].targetSets, 2);
        final squat = saved.exercises[1];
        expect([squat.targetSets, squat.repsMin, squat.repsMax], [3, 8, 10]);
        expect(squat.targetLoad?.value, 102.5);
        expect(squat.restSeconds, 120);

        // Reopen: same order and values.
        await tester.tap(find.text('Leg day'));
        await tester.pumpAndSettle();
        expect(nameAt(tester, 0), contains('Plank'));
        expect(nameAt(tester, 1), contains('Back squat'));
        expect(fieldText(tester, 'plan-duration-0'), '1:30');
        expect(fieldText(tester, 'plan-load-1'), '102.5');
        expect(fieldText(tester, 'plan-rest-1'), '120');
        await unmount(tester);
      },
    );

    testWidgets('moves an exercise down, removes one and reorders by drag', (
      tester,
    ) async {
      await open(tester);
      await tapKey(tester, 'new-plan');
      await addExercise(tester, 'squat');
      await addExercise(tester, 'plank');
      await addExercise(tester, 'row');

      await tapKey(tester, 'plan-move-down-0');
      expect(
        [for (var i = 0; i < 3; i++) nameAt(tester, i).split('. ').last],
        ['Plank', 'Back squat', 'Rowing'],
      );

      // Drag the last card above the others by its handle.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('plan-drag-2'))),
      );
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(0, -25));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        [for (var i = 0; i < 3; i++) nameAt(tester, i).split('. ').last],
        ['Rowing', 'Plank', 'Back squat'],
      );

      await tapKey(tester, 'plan-remove-0');
      expect(find.byKey(const Key('plan-exercise-name-2')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      // Unsaved changes: confirm before leaving.
      await tapKey(tester, 'discard-changes');
      expect(find.byKey(const Key('new-plan')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('picker hides archived exercises and can search', (
      tester,
    ) async {
      await open(tester);
      await tapKey(tester, 'new-plan');
      await tapKey(tester, 'plan-add-exercise');
      expect(find.byKey(const Key('picker-exercise-squat')), findsOneWidget);
      expect(find.byKey(const Key('picker-exercise-old')), findsNothing);
      await tester.enterText(find.byKey(const Key('picker-search')), 'plan');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('picker-exercise-squat')), findsNothing);
      expect(find.byKey(const Key('picker-exercise-plank')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('picker-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('picker-empty')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('shows validation messages next to the fields', (tester) async {
      await open(tester);
      await tapKey(tester, 'new-plan');

      // No exercise yet.
      await tapKey(tester, 'plan-save');
      expect(find.text('Add at least one exercise.'), findsOneWidget);

      await addExercise(tester, 'squat');
      await addExercise(tester, 'plank');

      // Missing name.
      await tapKey(tester, 'plan-save');
      expect(find.text('Enter a name of 1 to 100 characters.'), findsOneWidget);

      await enter(tester, 'plan-name-field', 'Mixed');
      // Parse errors: one place per field, nothing is saved.
      await enter(tester, 'plan-load-0', '80.1');
      await enter(tester, 'plan-duration-1', 'abc');
      await tapKey(tester, 'plan-save');
      expect(find.text('Load must be in steps of 0.25 kg.'), findsOneWidget);
      expect(
        find.text('Enter a duration as mm:ss, h:mm:ss or seconds.'),
        findsOneWidget,
      );
      expect(await plans.watchAll().first, isEmpty);

      // Use-case errors: reps range, sets, rest.
      await enter(tester, 'plan-load-0', '80');
      await enter(tester, 'plan-duration-1', '0:45');
      await enter(tester, 'plan-reps-min-0', '12');
      await enter(tester, 'plan-reps-max-0', '8');
      await tapKey(tester, 'plan-save');
      expect(
        find.text('The minimum reps cannot exceed the maximum.'),
        findsOneWidget,
      );
      await enter(tester, 'plan-reps-max-0', '12');
      await enter(tester, 'plan-sets-0', '25');
      await tapKey(tester, 'plan-save');
      expect(find.text('Sets must be 1 to 20.'), findsOneWidget);
      await enter(tester, 'plan-sets-0', '4');
      await enter(tester, 'plan-rest-0', '5000');
      await tapKey(tester, 'plan-save');
      expect(find.text('Rest must be 0 to 3600 seconds.'), findsOneWidget);
      await enter(tester, 'plan-rest-0', '90');
      await enter(tester, 'plan-reps-min-0', '');
      await tapKey(tester, 'plan-save');
      expect(find.text('Enter both ends of the rep range.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets(
      'refuses an exercise archived while editing, but not one the saved '
      'plan already lists (TD-42)',
      (tester) async {
        await open(tester);
        await tapKey(tester, 'new-plan');
        await enter(tester, 'plan-name-field', 'Fresh');
        await addExercise(tester, 'squat');
        await exercises.archive('squat', archived: true);
        await tester.pumpAndSettle();
        await tapKey(tester, 'plan-save');
        expect(
          find.text(
            '"Back squat" is archived. Restore it or remove it from the plan.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('plan-row-error-0')), findsOneWidget);
        expect(await plans.watchAll().first, isEmpty);
        await unmount(tester);
      },
    );

    testWidgets('renames a plan whose exercise was archived since', (
      tester,
    ) async {
      await plans.upsert(
        _plan(
          'p1',
          'Old plan',
          exercises: const [
            PlanExercise(
              id: 'pe1',
              exerciseId: 'old',
              sortOrder: 0,
              targetSets: 3,
              repsMin: 5,
              repsMax: 5,
            ),
          ],
        ),
      );
      await open(tester, location: RfRoutes.trainPlan('p1'));
      expect(find.text('Weighted · Archived'), findsOneWidget);
      await enter(tester, 'plan-name-field', 'Renamed');
      await tapKey(tester, 'plan-save');
      final saved = (await plans.byId('p1'))!;
      expect(saved.name, 'Renamed');
      expect(saved.exercises.single.id, 'pe1');
      await unmount(tester);
    });

    testWidgets('keeps weekdays and split of an existing plan on save', (
      tester,
    ) async {
      await plans.upsert(
        _plan(
          'p1',
          'Pattern',
          exercises: const [
            PlanExercise(
              id: 'pe1',
              exerciseId: 'squat',
              sortOrder: 0,
              targetSets: 3,
            ),
          ],
        ).copyWith(scheduledWeekdays: [1, 4], split: 'Upper/Lower'),
      );
      await open(tester, location: RfRoutes.trainPlan('p1'));
      await enter(tester, 'plan-name-field', 'Pattern 2');
      await tapKey(tester, 'plan-save');
      final saved = (await plans.byId('p1'))!;
      expect(saved.scheduledWeekdays, [1, 4]);
      expect(saved.split, 'Upper/Lower');
      await unmount(tester);
    });

    testWidgets('asks before leaving with unsaved changes', (tester) async {
      await open(tester);
      await tapKey(tester, 'new-plan');
      // Nothing typed: leaves without asking.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('new-plan')), findsOneWidget);

      await tapKey(tester, 'new-plan');
      await enter(tester, 'plan-name-field', 'Draft');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tapKey(tester, 'keep-editing');
      expect(find.byKey(const Key('plan-name-field')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapKey(tester, 'discard-changes');
      expect(find.byKey(const Key('new-plan')), findsOneWidget);
      expect(await plans.watchAll().first, isEmpty);
      await unmount(tester);
    });

    testWidgets('a missing plan shows a message', (tester) async {
      await open(tester, location: RfRoutes.trainPlan('nope'));
      expect(find.byKey(const Key('plan-missing')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('split editor', () {
    setUp(() async {
      await plans.upsert(_plan('ua', 'Upper A'));
      await plans.upsert(_plan('la', 'Lower A'));
      await plans.upsert(_plan('ub', 'Upper B'));
      await plans.upsert(_plan('lb', 'Lower B'));
      await plans.upsert(_plan('gone', 'Retired', archived: true));
    });

    Future<void> pickDay(WidgetTester tester, int day, String option) async {
      await tapKey(tester, 'split-day-$day');
      await tapKey(tester, 'split-option-$option');
    }

    testWidgets('saves a split with rest days and reopens it', (tester) async {
      await open(tester);
      await tapKey(tester, 'new-split');
      await enter(tester, 'split-name-field', 'Upper/Lower');
      await pickDay(tester, 0, 'ua');
      await pickDay(tester, 1, 'la');
      // Day 3 stays a rest day.
      await pickDay(tester, 3, 'ub');
      await pickDay(tester, 4, 'lb');
      await tapKey(tester, 'split-remove-day-6');
      await tapKey(tester, 'split-remove-day-5');
      expect(
        find.text(
          '5-day cycle, repeating. Choose a workout or a rest '
          'day for each day.',
        ),
        findsOneWidget,
      );
      // Archived plans are not offered.
      await tapKey(tester, 'split-day-2');
      expect(find.byKey(const Key('split-option-gone')), findsNothing);
      await tapKey(tester, 'split-option-rest');

      await tapKey(tester, 'split-save');
      final saved = (await splits.watchAll().first).single;
      expect(saved.name, 'Upper/Lower');
      expect(
        [for (final d in saved.days) d.planId],
        ['ua', 'la', null, 'ub', 'lb'],
      );
      expect(find.text('Upper/Lower'), findsOneWidget);
      expect(find.text('5-day cycle · 4 workouts · 1 rest'), findsOneWidget);

      await tester.tap(find.text('Upper/Lower'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('split-day-value-2'))).data,
        'Rest day',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('split-day-value-3'))).data,
        'Upper B',
      );
      await unmount(tester);
    });

    testWidgets('shows validation next to the fields', (tester) async {
      await open(tester);
      await tapKey(tester, 'new-split');
      await tapKey(tester, 'split-save');
      expect(find.text('Enter a name.'), findsOneWidget);
      await enter(tester, 'split-name-field', 'Empty');
      await tapKey(tester, 'split-save');
      expect(find.text('Enter a name.'), findsNothing);
      expect(
        find.text('Add at least one workout to the cycle.'),
        findsOneWidget,
      );
      expect(await splits.watchAll().first, isEmpty);
      await unmount(tester);
    });

    testWidgets('limits the cycle to 1 to 14 days', (tester) async {
      await open(tester);
      await tapKey(tester, 'new-split');
      for (var i = 0; i < 7; i++) {
        await tapKey(tester, 'split-add-day');
      }
      expect(find.byKey(const Key('split-day-13')), findsOneWidget);
      expect(
        tester
            .widget<RfButton>(find.byKey(const Key('split-add-day')))
            .onPressed,
        isNull,
      );
      for (var i = 13; i >= 1; i--) {
        await tapKey(tester, 'split-remove-day-$i');
      }
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('split-remove-day-0')))
            .onPressed,
        isNull,
      );
      await unmount(tester);
    });

    testWidgets('asks before leaving with unsaved changes', (tester) async {
      await open(tester);
      await tapKey(tester, 'new-split');
      await enter(tester, 'split-name-field', 'Draft');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tapKey(tester, 'discard-changes');
      expect(find.byKey(const Key('new-split')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('narrow width and large text', () {
    testWidgets('plan builder, list and split editor do not overflow', (
      tester,
    ) async {
      await plans.upsert(_plan('ua', 'Upper A with a rather long name'));
      await open(tester, size: const Size(360, 690), textScale: 1.3);
      expect(tester.takeException(), isNull);

      await tapKey(tester, 'new-plan');
      await enter(tester, 'plan-name-field', 'A long workout name for a phone');
      await addExercise(tester, 'squat');
      await enter(tester, 'plan-load-0', '1000');
      // Touch targets of the per-exercise controls.
      for (final k in ['plan-move-down-0', 'plan-remove-0', 'plan-drag-0']) {
        final size = tester.getSize(find.byKey(Key(k)));
        expect(size.shortestSide, greaterThanOrEqualTo(48), reason: k);
      }
      await addExercise(tester, 'plank');
      await addExercise(tester, 'row');
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'plan-save');
      expect(tester.takeException(), isNull);
      expect(find.text('A long workout name for a phone'), findsOneWidget);

      await tapKey(tester, 'new-split');
      await tapKey(tester, 'split-day-0');
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'split-option-ua');
      await tapKey(tester, 'split-save');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
