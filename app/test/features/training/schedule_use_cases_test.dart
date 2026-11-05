import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_scheduled_workout_repository.dart';
import 'package:repforge/data/repositories/drift_training_split_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/schedule_use_cases.dart';

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

// 2026-11-02 is a Monday.
final _monday = DateTime(2026, 11, 2);

void main() {
  late AppDatabase db;
  late DriftWorkoutPlanRepository plans;
  late DriftTrainingSplitRepository splits;
  late DriftScheduledWorkoutRepository scheduled;
  var n = 0;
  String newId() => 'w${n++}';

  late ScheduleOnDate onDate;
  late ScheduleWeekdays weekdays;
  late ScheduleSplitCycle cycle;
  late MoveScheduledWorkout move;
  late SkipScheduledWorkout skip;
  late ScheduledWorkoutsInRange inRange;

  Future<void> plan(
    String id, {
    List<int> days = const [],
    bool archived = false,
  }) => plans.upsert(
    WorkoutPlan(
      id: id,
      name: id,
      scheduledWeekdays: days,
      archived: archived,
      createdAt: _t,
      updatedAt: _t,
    ),
  );

  setUp(() async {
    db = AppDatabase.inMemory();
    n = 0;
    plans = DriftWorkoutPlanRepository(db, clock: _clock);
    splits = DriftTrainingSplitRepository(db, clock: _clock);
    scheduled = DriftScheduledWorkoutRepository(db);
    onDate = ScheduleOnDate(
      plans: plans,
      scheduled: scheduled,
      clock: _clock,
      newId: newId,
    );
    weekdays = ScheduleWeekdays(
      plans: plans,
      scheduled: scheduled,
      clock: _clock,
      newId: newId,
    );
    cycle = ScheduleSplitCycle(
      splits: splits,
      plans: plans,
      scheduled: scheduled,
      clock: _clock,
      newId: newId,
    );
    move = MoveScheduledWorkout(scheduled: scheduled, clock: _clock);
    skip = SkipScheduledWorkout(scheduled: scheduled, clock: _clock);
    inRange = ScheduledWorkoutsInRange(scheduled: scheduled);
    await plan('upperA', days: [1, 4]);
    await plan('lowerA');
  });
  tearDown(() => db.close());

  Future<List<ScheduledWorkout>> all() =>
      scheduled.inRange(DateTime(2026), DateTime(2027));

  group('pure date generation', () {
    test('weekday dates: Mondays and Thursdays for 8 weeks from a Monday', () {
      final dates = weekdayDates(_monday, [1, 4]);
      expect(dates, hasLength(16));
      expect(dates.first, DateTime(2026, 11, 2));
      expect(dates[1], DateTime(2026, 11, 5));
      expect(dates.last, DateTime(2026, 12, 24));
      expect(dates.every((d) => d.weekday == 1 || d.weekday == 4), isTrue);
    });

    test('weekday dates start from the given date, inclusive', () {
      final dates = weekdayDates(DateTime(2026, 11, 5, 17, 30), [4]);
      expect(dates.first, DateTime(2026, 11, 5));
      expect(dates, hasLength(8));
    });

    test('day keys round-trip and reject malformed input', () {
      expect(scheduleDayKey(DateTime(2026, 3, 9, 23, 59)), '2026-03-09');
      expect(parseScheduleDayKey('2026-03-09'), DateTime(2026, 3, 9));
      expect(parseScheduleDayKey('2026-02-30'), isNull);
      expect(parseScheduleDayKey('nope'), isNull);
    });
  });

  group('TRN-015(1) schedule on a date, by weekday, by split cycle', () {
    test('on a date', () async {
      final w = _ok(
        await onDate(planId: 'upperA', date: DateTime(2026, 11, 9, 15)),
      );
      expect(w.day, DateTime(2026, 11, 9));
      expect(w.sourceDay, w.day);
      expect(w.origin, ScheduleOrigin.date);
      expect(w.status, ScheduleStatus.planned);
      expect(w.sessionId, isNull);
      expect(await all(), hasLength(1));
    });

    test('on a date: the same plan twice on one date, an unknown or archived '
        'plan are refused and nothing is stored', () async {
      _ok(await onDate(planId: 'upperA', date: DateTime(2026, 11, 9)));
      expect(
        _err(await onDate(planId: 'upperA', date: DateTime(2026, 11, 9))),
        isA<ValidationError>(),
      );
      expect(
        _err(await onDate(planId: 'nope', date: DateTime(2026, 11, 9))),
        isA<NotFoundError>(),
      );
      await plan('old', archived: true);
      expect(
        _err(await onDate(planId: 'old', date: DateTime(2026, 11, 9))),
        isA<ValidationError>(),
      );
      expect(await all(), hasLength(1));
    });

    test('weekdays: Upper A on Mondays and Thursdays for 8 weeks (D04 '
        'example)', () async {
      final out = _ok(await weekdays(planId: 'upperA', start: _monday));
      expect(out.created, hasLength(16));
      expect(out.alreadyThere, 0);
      final stored = await all();
      expect(stored, hasLength(16));
      expect(stored.every((w) => w.origin == ScheduleOrigin.weekday), isTrue);
      expect(stored.map((w) => w.day.weekday).toSet(), {
        DateTime.monday,
        DateTime.thursday,
      });
      expect(stored.last.day, DateTime(2026, 12, 24));
    });

    test('weekdays: an explicit pattern overrides the plan pattern; an '
        'empty or invalid pattern is refused', () async {
      final out = _ok(
        await weekdays(planId: 'upperA', start: _monday, weekdays: [3]),
      );
      expect(out.created, hasLength(8));
      expect(
        _err(await weekdays(planId: 'lowerA', start: _monday)),
        isA<ValidationError>(),
        reason: 'the plan has no pattern',
      );
      for (final bad in [
        <int>[],
        [0],
        [8],
        [1, 1],
      ]) {
        expect(
          _err(await weekdays(planId: 'upperA', start: _monday, weekdays: bad)),
          isA<ValidationError>(),
        );
      }
      expect(
        _err(await weekdays(planId: 'nope', start: _monday)),
        isA<NotFoundError>(),
      );
      expect(await all(), hasLength(8));
    });

    Future<TrainingSplit> split(List<String?> days) async {
      final s = TrainingSplit(
        id: 'sp',
        name: 'Upper/Lower',
        days: [for (final d in days) SplitDay(planId: d)],
        createdAt: _t,
        updatedAt: _t,
      );
      await splits.upsert(s);
      return s;
    }

    test('split cycle: rest days produce nothing; 8 weeks; day 0 is the '
        'start date', () async {
      // 4-day cycle: Upper, Lower, rest, rest.
      await split(['upperA', 'lowerA', null, null]);
      final out = _ok(await cycle(splitId: 'sp', start: _monday));
      expect(out.created, hasLength(28), reason: '56 days / 4 x 2 workouts');
      expect(out.missingPlans, 0);
      final stored = await all();
      expect(stored.first.day, DateTime(2026, 11, 2));
      expect(stored.first.planId, 'upperA');
      expect(stored[1].day, DateTime(2026, 11, 3));
      expect(stored[1].planId, 'lowerA');
      expect(stored[2].day, DateTime(2026, 11, 6));
      expect(stored.every((w) => w.origin == ScheduleOrigin.split), isTrue);
      expect(stored.last.day.isBefore(DateTime(2026, 12, 28)), isTrue);
    });

    test('split cycle: a deleted or archived workout is left out and '
        'counted; an unknown split is refused', () async {
      await split(['upperA', 'gone', null]);
      await plan('arch', archived: true);
      await splits.upsert(
        TrainingSplit(
          id: 'sp2',
          name: 'S2',
          days: const [
            SplitDay(planId: 'arch'),
            SplitDay(planId: 'lowerA'),
          ],
          createdAt: _t,
          updatedAt: _t,
        ),
      );
      final out = _ok(await cycle(splitId: 'sp', start: _monday));
      expect(out.missingPlans, 1);
      expect((await all()).every((w) => w.planId == 'upperA'), isTrue);
      final out2 = _ok(await cycle(splitId: 'sp2', start: _monday));
      expect(out2.missingPlans, 1);
      expect(out2.created.every((w) => w.planId == 'lowerA'), isTrue);
      expect(
        _err(await cycle(splitId: 'nope', start: _monday)),
        isA<NotFoundError>(),
      );
    });
  });

  group('duplicate rule on regeneration', () {
    test('generating the same pattern twice creates nothing the second '
        'time', () async {
      _ok(await weekdays(planId: 'upperA', start: _monday));
      final again = _ok(await weekdays(planId: 'upperA', start: _monday));
      expect(again.created, isEmpty);
      expect(again.alreadyThere, 16);
      expect(await all(), hasLength(16));
    });

    test('a later start extends the schedule without duplicating the '
        'overlap', () async {
      _ok(await weekdays(planId: 'upperA', start: _monday));
      final next = _ok(
        await weekdays(planId: 'upperA', start: DateTime(2026, 11, 30)),
      );
      // 30 Nov .. 24 Jan; overlap with the first run ends 24 Dec.
      expect(next.alreadyThere, greaterThan(0));
      final days = (await all()).map((w) => scheduleDayKey(w.day)).toList();
      expect(days.toSet().length, days.length, reason: 'no date twice');
    });

    test('a moved occurrence is not recreated on its original date, and a '
        'skipped one is not brought back', () async {
      final first = _ok(await weekdays(planId: 'upperA', start: _monday));
      final monday = first.created.first; // 2 Nov
      final thursday = first.created[1]; // 5 Nov
      _ok(
        await move(
          scheduledWorkoutId: monday.id,
          newDate: DateTime(2026, 11, 3),
        ),
      );
      _ok(await skip(thursday.id));
      final again = _ok(await weekdays(planId: 'upperA', start: _monday));
      expect(again.created, isEmpty);
      final stored = await all();
      expect(stored, hasLength(16));
      expect(
        stored.where((w) => w.sourceDay == DateTime(2026, 11, 2)).single.day,
        DateTime(2026, 11, 3),
      );
    });

    test('a weekday run does not double a plan already on that date from a '
        'one-off', () async {
      _ok(await onDate(planId: 'upperA', date: DateTime(2026, 11, 5)));
      final out = _ok(await weekdays(planId: 'upperA', start: _monday));
      expect(out.created, hasLength(15));
      expect(out.alreadyThere, 1);
    });

    test('split cycle regeneration is idempotent', () async {
      await splits.upsert(
        TrainingSplit(
          id: 'sp',
          name: 'S',
          days: const [
            SplitDay(planId: 'upperA'),
            SplitDay(),
          ],
          createdAt: _t,
          updatedAt: _t,
        ),
      );
      final a = _ok(await cycle(splitId: 'sp', start: _monday));
      final b = _ok(await cycle(splitId: 'sp', start: _monday));
      expect(a.created, hasLength(28));
      expect(b.created, isEmpty);
      expect(b.alreadyThere, 28);
    });
  });

  group('TRN-015(2) move and skip leave the plan unchanged', () {
    test(
      'move changes only the scheduled row; the plan is identical',
      () async {
        final before = await plans.byId('upperA');
        final w = _ok(
          await onDate(planId: 'upperA', date: DateTime(2026, 11, 9)),
        );
        final moved = _ok(
          await move(scheduledWorkoutId: w.id, newDate: DateTime(2026, 11, 11)),
        );
        expect(moved.day, DateTime(2026, 11, 11));
        expect(moved.sourceDay, DateTime(2026, 11, 9));
        expect(moved.status, ScheduleStatus.planned);
        expect(await plans.byId('upperA'), before);
        expect((await scheduled.byId(w.id))!.day, DateTime(2026, 11, 11));
      },
    );

    test('skip marks it skipped on its date; the plan is identical', () async {
      final before = await plans.byId('upperA');
      final w = _ok(
        await onDate(planId: 'upperA', date: DateTime(2026, 11, 9)),
      );
      final skipped = _ok(await skip(w.id));
      expect(skipped.status, ScheduleStatus.skipped);
      expect(skipped.day, DateTime(2026, 11, 9));
      expect(await plans.byId('upperA'), before);
      expect(await plans.byId('lowerA'), isNotNull);
    });

    test('only a planned workout can be moved or skipped; unknown ids and '
        'a clash on the new date are refused with nothing changed', () async {
      final a = _ok(
        await onDate(planId: 'upperA', date: DateTime(2026, 11, 9)),
      );
      final b = _ok(
        await onDate(planId: 'upperA', date: DateTime(2026, 11, 10)),
      );
      expect(
        _err(
          await move(scheduledWorkoutId: a.id, newDate: DateTime(2026, 11, 10)),
        ),
        isA<ValidationError>(),
        reason: 'same plan already on that date',
      );
      _ok(await skip(b.id));
      // A skipped occurrence does not block the date.
      _ok(
        await move(scheduledWorkoutId: a.id, newDate: DateTime(2026, 11, 10)),
      );
      expect(
        _err(
          await move(scheduledWorkoutId: b.id, newDate: DateTime(2026, 11, 20)),
        ),
        isA<ValidationError>(),
        reason: 'skipped cannot be moved',
      );
      expect(_err(await skip(b.id)), isA<ValidationError>());
      expect(
        _err(await move(scheduledWorkoutId: 'zzz', newDate: _monday)),
        isA<NotFoundError>(),
      );
      expect(_err(await skip('zzz')), isA<NotFoundError>());
      await scheduled.upsert(
        a.copyWith(status: ScheduleStatus.done, sessionId: 's'),
      );
      expect(
        _err(
          await move(scheduledWorkoutId: a.id, newDate: DateTime(2026, 11, 30)),
        ),
        isA<ValidationError>(),
      );
      expect(_err(await skip(a.id)), isA<ValidationError>());
    });
  });

  group('query in a date range', () {
    test('returns the scheduled workouts whose current date is inside, '
        'inclusive, by date', () async {
      final w = _ok(await weekdays(planId: 'upperA', start: _monday));
      _ok(
        await move(
          scheduledWorkoutId: w.created.first.id,
          newDate: DateTime(2026, 11, 20),
        ),
      );
      final week = _ok(
        await inRange(DateTime(2026, 11, 2), DateTime(2026, 11, 8, 22)),
      );
      expect(week.map((x) => scheduleDayKey(x.day)), ['2026-11-05']);
      final later = _ok(
        await inRange(DateTime(2026, 11, 19), DateTime(2026, 11, 20)),
      );
      expect(later.map((x) => scheduleDayKey(x.day)), [
        '2026-11-19',
        '2026-11-20',
      ]);
      expect(
        _err(await inRange(DateTime(2026, 11, 8), DateTime(2026, 11, 2))),
        isA<ValidationError>(),
      );
    });

    test('watchRange emits when a workout is scheduled', () async {
      final emitted = <int>[];
      final sub = scheduled
          .watchRange(DateTime(2026, 11), DateTime(2026, 11, 30))
          .listen((l) => emitted.add(l.length));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      _ok(await onDate(planId: 'upperA', date: DateTime(2026, 11, 9)));
      await pumpEventQueue();
      expect(emitted, containsAllInOrder([0, 1]));
    });
  });

  test('a storage failure is a StorageError, not a throw', () async {
    await db.close();
    expect(
      _err(await onDate(planId: 'upperA', date: DateTime(2026, 11, 9))),
      isA<StorageError>(),
    );
    db = AppDatabase.inMemory();
  });
}
