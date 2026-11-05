import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_scheduled_workout_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/data/repositories/drift_training_split_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';

import '../../../helpers/pump.dart';

// Thursday 5 November 2026.
final _now = DateTime(2026, 11, 5, 9);
final _today = DateTime(2026, 11, 5);
final _horizonEnd = DateTime(2027);

WorkoutPlan _plan(String id, String name, {bool archived = false}) =>
    WorkoutPlan(
      id: id,
      name: name,
      archived: archived,
      exercises: [
        PlanExercise(
          id: 'pe-$id',
          exerciseId: 'squat',
          sortOrder: 0,
          targetSets: 3,
          repsMin: 8,
          repsMax: 10,
        ),
      ],
      createdAt: _now.toUtc(),
      updatedAt: _now.toUtc(),
    );

void main() {
  late AppDatabase db;
  late DriftWorkoutPlanRepository plans;
  late DriftTrainingSplitRepository splits;
  late DriftScheduledWorkoutRepository scheduled;
  late DriftSettingsRepository settings;
  var gen = 0;

  setUp(() async {
    db = AppDatabase.inMemory();
    final clock = FixedClock(_now);
    plans = DriftWorkoutPlanRepository(db, clock: clock);
    splits = DriftTrainingSplitRepository(db, clock: clock);
    scheduled = DriftScheduledWorkoutRepository(db);
    settings = DriftSettingsRepository(db, clock: clock);
    gen = 0;
    await plans.upsert(_plan('ua', 'Upper A'));
    await plans.upsert(_plan('la', 'Lower A'));
    await plans.upsert(_plan('old', 'Retired', archived: true));
  });
  tearDown(() => db.close());

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 12000),
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
        child: RepForgeApp(
          router: createRouter(initialLocation: RfRoutes.trainSchedule),
        ),
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

  Finder rows() => find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> &&
        k.value.startsWith('scheduled-') &&
        !k.value.startsWith('scheduled-status-') &&
        !k.value.startsWith('scheduled-date-');
  });

  Future<List<ScheduledWorkout>> all() =>
      scheduled.inRange(_today, _horizonEnd);

  Future<void> scheduleMondaysAndThursdays(WidgetTester tester) async {
    await tapKey(tester, 'schedule-weekdays');
    await tapKey(tester, 'sched-plan-ua');
    await tapKey(tester, 'sched-weekday-1');
    await tapKey(tester, 'sched-weekday-4');
    await tapKey(tester, 'sched-confirm');
  }

  testWidgets('shows an empty state and reaches the screen from Train', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('schedule-empty')), findsOneWidget);
    expect(find.text('Thu 5 Nov 2026 to Wed 30 Dec 2026'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'scheduling Mondays and Thursdays places each date for 8 weeks, grouped '
    'by date',
    (tester) async {
      await open(tester);
      await scheduleMondaysAndThursdays(tester);

      expect(find.text('Scheduled 16 workouts.'), findsOneWidget);
      expect(rows(), findsNWidgets(16));
      final stored = await all();
      expect(stored, hasLength(16));
      expect(stored.map((w) => w.day.weekday).toSet(), {
        DateTime.monday,
        DateTime.thursday,
      });
      expect(stored.first.day, _today);
      expect(stored.last.day, DateTime(2026, 12, 28));
      // Grouped by date, in date order.
      expect(find.text('Thu 5 Nov 2026'), findsOneWidget);
      expect(find.text('Mon 9 Nov 2026'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Thu 5 Nov 2026')).dy,
        lessThan(tester.getTopLeft(find.text('Mon 9 Nov 2026')).dy),
      );

      // Running it again adds nothing.
      await scheduleMondaysAndThursdays(tester);
      expect(
        find.text('Scheduled 0 workouts. 16 already there.'),
        findsOneWidget,
      );
      expect(await all(), hasLength(16));
      await unmount(tester);
    },
  );

  testWidgets('weekday chips start at the week start day setting', (
    tester,
  ) async {
    await settings.save(const AppSettings(weekStartDay: 7));
    await open(tester);
    await tapKey(tester, 'schedule-weekdays');
    double x(int d) =>
        tester.getTopLeft(find.byKey(Key('sched-weekday-$d'))).dx;
    expect(x(7), lessThan(x(1)));
    expect(x(1), lessThan(x(6)));
    await unmount(tester);
  });

  testWidgets('moving an occurrence updates the list and not the plan', (
    tester,
  ) async {
    await open(tester);
    await scheduleMondaysAndThursdays(tester);
    final planBefore = await plans.byId('ua');
    final first = (await all()).first;

    await tapKey(tester, 'schedule-move-${first.id}');
    // Thursday 5 Nov -> Friday 6 Nov.
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Moved to Fri 6 Nov 2026.'), findsOneWidget);
    expect(find.text('Fri 6 Nov 2026'), findsOneWidget);
    expect(find.text('Thu 5 Nov 2026'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(Key('scheduled-status-${first.id}'))).data,
      'Planned · moved from Thu 5 Nov 2026',
    );
    final moved = (await scheduled.byId(first.id))!;
    expect(moved.day, DateTime(2026, 11, 6));
    expect(moved.sourceDay, _today);
    expect(await plans.byId('ua'), planBefore);
    await unmount(tester);
  });

  testWidgets('moving onto a date the workout is already on shows the error', (
    tester,
  ) async {
    await open(tester);
    await scheduleMondaysAndThursdays(tester);
    final first = (await all()).first;

    await tapKey(tester, 'schedule-move-${first.id}');
    // Monday 9 Nov already has Upper A.
    await tester.tap(find.text('9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      find.text('That workout is already scheduled on that date.'),
      findsOneWidget,
    );
    expect((await scheduled.byId(first.id))!.day, _today);
    await unmount(tester);
  });

  testWidgets('skipping an occurrence keeps it listed as skipped', (
    tester,
  ) async {
    await open(tester);
    await scheduleMondaysAndThursdays(tester);
    final planBefore = await plans.byId('ua');
    final first = (await all()).first;

    await tapKey(tester, 'schedule-skip-${first.id}');
    expect(find.text('Skip Upper A?'), findsOneWidget);
    await tapKey(tester, 'skip-cancel');
    expect((await scheduled.byId(first.id))!.status, ScheduleStatus.planned);

    await tapKey(tester, 'schedule-skip-${first.id}');
    await tapKey(tester, 'skip-confirm');
    expect(
      tester.widget<Text>(find.byKey(Key('scheduled-status-${first.id}'))).data,
      'Skipped',
    );
    expect(find.byKey(Key('schedule-move-${first.id}')), findsNothing);
    expect(find.byKey(Key('schedule-skip-${first.id}')), findsNothing);
    expect(rows(), findsNWidgets(16));
    expect((await scheduled.byId(first.id))!.status, ScheduleStatus.skipped);
    expect(await plans.byId('ua'), planBefore);

    // Scheduling again does not bring the skipped one back.
    await scheduleMondaysAndThursdays(tester);
    expect(rows(), findsNWidgets(16));
    await unmount(tester);
  });

  testWidgets('a skipped occurrence can be restored to planned; refused '
      'when the date was taken meanwhile', (tester) async {
    await open(tester);
    await scheduleMondaysAndThursdays(tester);
    final first = (await all()).first;
    await tapKey(tester, 'schedule-skip-${first.id}');
    await tapKey(tester, 'skip-confirm');
    expect(find.byKey(Key('schedule-restore-${first.id}')), findsOneWidget);
    // Only skipped occurrences offer Restore.
    expect(find.text('Restore'), findsOneWidget);

    // The date is taken meanwhile by another planned occurrence.
    await scheduled.upsert(
      ScheduledWorkout(
        id: 'extra',
        day: first.day,
        sourceDay: first.day,
        planId: first.planId,
        origin: ScheduleOrigin.date,
        status: ScheduleStatus.planned,
        createdAt: _now.toUtc(),
        updatedAt: _now.toUtc(),
      ),
    );
    await tapKey(tester, 'schedule-restore-${first.id}');
    expect(find.textContaining('planned or done'), findsOneWidget);
    expect((await scheduled.byId(first.id))!.status, ScheduleStatus.skipped);

    await scheduled.upsert(
      (await scheduled.byId('extra'))!.copyWith(status: ScheduleStatus.skipped),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tapKey(tester, 'schedule-restore-${first.id}');
    expect((await scheduled.byId(first.id))!.status, ScheduleStatus.planned);
    expect(find.byKey(Key('schedule-restore-${first.id}')), findsNothing);
    expect(find.byKey(Key('schedule-skip-${first.id}')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('schedules on a single date and refuses a duplicate', (
    tester,
  ) async {
    await open(tester);
    await tapKey(tester, 'schedule-on-date');
    await tapKey(tester, 'sched-plan-la');
    await tapKey(tester, 'sched-date');
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'sched-confirm');
    expect(find.text('Scheduled for Fri 20 Nov 2026.'), findsOneWidget);
    expect(find.text('Fri 20 Nov 2026'), findsOneWidget);

    await tapKey(tester, 'schedule-on-date');
    await tapKey(tester, 'sched-plan-la');
    await tapKey(tester, 'sched-date');
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'sched-confirm');
    // The error stays in the sheet, next to the date.
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byKey(const Key('sched-error-date')),
      ),
      findsOneWidget,
    );
    expect(await all(), hasLength(1));
    await unmount(tester);
  });

  testWidgets('a split cycle schedules its workouts and skips rest days', (
    tester,
  ) async {
    final now = _now.toUtc();
    await splits.upsert(
      TrainingSplit(
        id: 'sp',
        name: 'Two on one off',
        days: const [
          SplitDay(planId: 'ua'),
          SplitDay(planId: 'la'),
          SplitDay(),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );
    await open(tester);
    await tapKey(tester, 'schedule-split');
    await tapKey(tester, 'sched-split-sp');
    await tapKey(tester, 'sched-confirm');

    // 56 days, days 2, 5, 8 ... are rest: 56 - 18 = 38 workouts.
    expect(find.text('Scheduled 38 workouts.'), findsOneWidget);
    final stored = await all();
    expect(stored, hasLength(38));
    expect(stored.first.day, _today);
    expect(stored.first.planId, 'ua');
    expect(stored[1].planId, 'la');
    expect(stored[2].day, DateTime(2026, 11, 8));
    expect(find.text('Thu 5 Nov 2026'), findsOneWidget);
    expect(find.text('Sat 7 Nov 2026'), findsNothing);
    await unmount(tester);
  });

  testWidgets('shows errors in the sheet and offers no archived workouts', (
    tester,
  ) async {
    await open(tester);
    await tapKey(tester, 'schedule-weekdays');
    expect(find.byKey(const Key('sched-plan-old')), findsNothing);
    await tapKey(tester, 'sched-confirm');
    expect(find.text('Choose a workout.'), findsOneWidget);
    await tapKey(tester, 'sched-plan-ua');
    await tapKey(tester, 'sched-confirm');
    expect(
      find.text('Choose weekdays from 1 (Monday) to 7 (Sunday), each once.'),
      findsOneWidget,
    );
    expect(await all(), isEmpty);

    // A split needs a choice too.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tapKey(tester, 'schedule-split');
    expect(find.byKey(const Key('sched-no-choices')), findsOneWidget);
    await tapKey(tester, 'sched-confirm');
    expect(find.text('Choose a split.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('pages through earlier and later ranges', (tester) async {
    await scheduled.upsert(
      ScheduledWorkout(
        id: 'far',
        day: DateTime(2027, 1, 20),
        sourceDay: DateTime(2027, 1, 20),
        planId: 'ua',
        origin: ScheduleOrigin.date,
        status: ScheduleStatus.planned,
        createdAt: _now.toUtc(),
        updatedAt: _now.toUtc(),
      ),
    );
    await open(tester);
    expect(find.byKey(const Key('scheduled-far')), findsNothing);
    await tapKey(tester, 'range-next');
    expect(find.byKey(const Key('scheduled-far')), findsOneWidget);
    await tapKey(tester, 'range-prev');
    expect(find.byKey(const Key('schedule-empty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('does not overflow at 360x690 with 1.3x text', (tester) async {
    await open(tester, size: const Size(360, 690), textScale: 1.3);
    await tapKey(tester, 'schedule-weekdays');
    await tapKey(tester, 'sched-plan-ua');
    await tapKey(tester, 'sched-plan-la');
    for (var d = 1; d <= 7; d++) {
      await tapKey(tester, 'sched-weekday-$d');
    }
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'sched-confirm');
    expect(tester.takeException(), isNull);
    final first = (await all()).first;
    for (final k in [
      'schedule-move-${first.id}',
      'schedule-skip-${first.id}',
    ]) {
      final f = find.byKey(Key(k));
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getSize(f).height, greaterThanOrEqualTo(48), reason: k);
    }
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
