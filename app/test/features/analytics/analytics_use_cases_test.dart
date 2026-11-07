import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_goal_repository.dart';
import 'package:repforge/data/repositories/drift_measurement_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/goal_progress.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/analytics/period_comparison.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/analytics/weekly_report.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/unreadable_measurement.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/analytics/application/body_use_cases.dart';
import 'package:repforge/features/analytics/application/nutrition_use_cases.dart';
import 'package:repforge/features/analytics/application/report_use_cases.dart';
import 'package:repforge/features/analytics/application/target_history_use_cases.dart';
import 'package:repforge/features/analytics/application/training_use_cases.dart';

import '../../helpers/analytics_fixtures.dart';
import '../../helpers/seed_session.dart';

// Saturday 7 Nov 2026: this week is 2-8 Nov, last week 26 Oct - 1 Nov.
final _now = DateTime(2026, 11, 7, 12);
final _clock = FixedClock(_now);
final _t = DateTime.utc(2026, 10);

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final error) => fail('expected Ok, got ${error.message}'),
};

Goal _goal(
  String id,
  GoalKind kind,
  double target,
  DateTime start, {
  MeasurementSite? site,
}) => Goal(
  id: id,
  kind: kind,
  target: target,
  startDate: start.toUtc(),
  createdAt: start.toUtc(),
  updatedAt: start.toUtc(),
  site: site,
);

void main() {
  late AppDatabase db;
  late DriftGoalRepository goals;
  late DriftFoodLogRepository foodLog;
  late DriftMeasurementRepository measurements;
  late DriftWorkoutSessionRepository sessions;
  late DriftExerciseRepository exercises;
  late DriftSettingsRepository settings;
  late AnalyticsPeriod thisWeek;
  late AnalyticsPeriod lastWeek;

  Future<String?> name(String id) async => (await exercises.byId(id))?.name;

  LoadNutritionWeek nutrition() =>
      LoadNutritionWeek(foodLog: foodLog, goals: goals, clock: _clock);
  LoadWeekTraining training() => LoadWeekTraining(
    sessions: sessions,
    settings: settings,
    exerciseName: name,
  );
  LoadWeightSummary weight() => LoadWeightSummary(measurements: measurements);

  Future<void> seedExercise(
    String id,
    String n, {
    bool archived = false,
  }) async {
    await exercises.upsert(
      Exercise(
        id: id,
        name: n,
        type: ExerciseType.weighted,
        category: ExerciseCategory.push,
        primaryMuscle: MuscleGroup.chest,
        createdAt: _t,
        updatedAt: _t,
      ),
    );
    if (archived) await exercises.archive(id, archived: true);
  }

  Future<void> seedWorkout(
    String id,
    DateTime start,
    List<SetData> sets, {
    String exercise = 'bench',
    bool ended = true,
  }) => seedSession(
    sessions,
    WorkoutSession(
      id: id,
      name: id,
      startedAt: start.toUtc(),
      endedAt: ended ? start.add(const Duration(hours: 1)).toUtc() : null,
      createdAt: start.toUtc(),
      updatedAt: start.toUtc(),
      sets: [
        for (var i = 0; i < sets.length; i++)
          SessionSet(
            id: '$id-$i',
            sessionId: id,
            exerciseId: exercise,
            exerciseOrder: 0,
            setOrder: i,
            data: sets[i],
            completed: true,
          ),
      ],
    ),
  );

  setUp(() async {
    db = AppDatabase.inMemory();
    goals = DriftGoalRepository(db, clock: _clock);
    foodLog = DriftFoodLogRepository(db, clock: _clock);
    measurements = DriftMeasurementRepository(db, clock: _clock);
    sessions = DriftWorkoutSessionRepository(db, clock: _clock);
    exercises = DriftExerciseRepository(db, clock: _clock);
    settings = DriftSettingsRepository(db, clock: _clock);
    thisWeek = AnalyticsPeriod.thisWeek(_now, 1);
    lastWeek = thisWeek.previous;

    await seedExercise('bench', 'Bench Press');
    await seedExercise('ohp', 'Overhead Press', archived: true);

    await goals.upsert(
      _goal('cal1', GoalKind.calories, 2400, DateTime(2026, 10)),
    );
    await goals.replaceActive(
      GoalKind.calories,
      _goal('cal2', GoalKind.calories, 2600, DateTime(2026, 11, 4, 9)),
    );
    await goals.upsert(
      _goal('bw', GoalKind.bodyWeight, 80, DateTime(2026, 11, 2, 9)),
    );
    await goals.upsert(
      _goal(
        'wst',
        GoalKind.measurement,
        85,
        DateTime(2026, 11, 2, 9),
        site: MeasurementSite.waist,
      ),
    );
    await goals.upsert(
      _goal('spw', GoalKind.sessionsPerWeek, 3, DateTime(2026, 10)),
    );

    await foodLog.insertAll([
      foodEntry('2026-10-27', 1800, protein: 90),
      foodEntry('2026-11-02', 2000, protein: 100),
      foodEntry('2026-11-03', 2200, protein: 120),
      foodEntry('2026-11-03', 100, provenance: DataProvenance.estimated),
      foodEntry('2026-11-20', 9999),
    ]);

    await measurements.insertAll([
      weightReading(91, 10, 29),
      weightReading(90, 11, 2),
      weightReading(90, 11, 3),
      weightReading(90, 11, 4),
      weightReading(87, 11, 7),
      reading(MeasurementSite.waist, 92, 11, 2),
      reading(MeasurementSite.waist, 90, 11, 6),
    ]);

    await seedWorkout('s1', DateTime(2026, 10, 28, 18), [weighted(80, 5)]);
    await seedWorkout('s2', DateTime(2026, 11, 3, 18), [
      weighted(82.5, 5),
      weighted(80, 4),
    ]);
    await seedWorkout('s3', DateTime(2026, 11, 5, 18), [
      weighted(40, 8),
    ], exercise: 'ohp');
    await seedWorkout('s4', DateTime(2026, 11, 6, 18), [
      weighted(60, 5),
    ], ended: false);
  });
  tearDown(() => db.close());

  test('LoadTargetHistory keeps the inactive row (GOL-006)', () async {
    final h = _ok(await LoadTargetHistory(goals: goals)());
    expect(h.targetsOn(CalendarDate(2026, 11, 3)).kcal, 2400);
    expect(h.targetsOn(CalendarDate(2026, 11, 4)).kcal, 2600);
    expect(h.periodsFor(GoalKind.calories), hasLength(2));
  });

  group('LoadNutritionWeek', () {
    test(
      'reads only the period and judges each day by its own target',
      () async {
        final w = _ok(await nutrition()(thisWeek));
        expect(w.loggedDays, 2);
        expect(w.daysLoggedText, '2 of 6 days logged');
        expect(w.days[1].targetsInEffect.kcal, 2400); // 3 Nov
        expect(w.days[2].targetsInEffect.kcal, 2600); // 4 Nov
        expect(w.days[1].totals.known.kcal, 2300);
        expect(w.days[1].provenance, DataProvenance.estimated);
        final avg = w.averageEnergyKcal as MetricValue<double>;
        expect(avg.value, closeTo((2000 + 2300) / 2, 1e-9));
      },
    );

    test('last week sees only its own entry', () async {
      final w = _ok(await nutrition()(lastWeek));
      expect(w.loggedDays, 1);
      expect((w.averageEnergyKcal as MetricValue<double>).value, 1800);
    });
  });

  group('LoadWeekTraining', () {
    test('counts completed sessions, volume, names and records', () async {
      final v = _ok(await training()(thisWeek));
      expect(v.week.sessionsCompleted, 2);
      expect(v.week.sessionsInProgress, 1);
      expect(v.week.volume.loadKg, 82.5 * 5 + 320 + 320 + 300);
      expect(v.exerciseNames, {
        'bench': 'Bench Press',
        'ohp': 'Overhead Press',
      });
      final records = v.recordEvents;
      expect(
        records.map((e) => (e.exerciseId, e.key.reps, e.value)),
        containsAll([('bench', 5, 82.5), ('bench', 4, 80.0), ('ohp', 8, 40.0)]),
      );
      // 60 x 5 in the in-progress session is not a record: 80 x 5 came first.
      expect(records.where((e) => e.setId == 's4-0'), isEmpty);
    });

    test('a deleted exercise keeps its sets under a neutral name', () async {
      await exercises.delete('ohp');
      final v = _ok(await training()(thisWeek));
      expect(v.exerciseNames['ohp'], unknownExerciseName);
    });

    test('last week holds the one earlier session', () async {
      final w = _ok(await training().loadWeek(lastWeek));
      expect(w.sessionsCompleted, 1);
      expect(w.volume.loadKg, 400);
    });
  });

  group('LoadWeightSummary', () {
    test('uses readings of the period and the lookback before it', () async {
      final s = _ok(await weight()(thisWeek));
      expect(s.readingsInWindow, 4);
      expect(s.latestRaw!.value.raw, 87);
      expect(s.latestTrend!.average, 89.25);
      // The lookback holds the 29 Oct reading (91): the first trend point
      // of the week is 3 Nov = (91 + 90 + 90) / 3.
      expect(
        (s.trendChange as MetricValue<double>).value,
        closeTo(89.25 - 271 / 3, 1e-9),
      );
    });

    test('an empty period has no trend', () async {
      final s = _ok(
        await weight()(
          AnalyticsPeriod.custom(
            CalendarDate(2026, 8, 1),
            CalendarDate(2026, 8, 7),
          ),
        ),
      );
      expect(s.latestRaw, isNull);
      expect(s.rateOfChange, isA<NotEnoughData<dynamic>>());
    });
  });

  test('LoadGoalProgress returns weight, waist and sessions goals', () async {
    final list = _ok(
      await LoadGoalProgress(
        goals: goals,
        measurements: measurements,
        sessions: sessions,
        settings: settings,
        clock: _clock,
      )(),
    );
    final byKind = {for (final p in list) p.goal.id: p};
    expect(byKind.keys.toSet(), {'bw', 'wst', 'spw'});
    final bw = byKind['bw']!;
    expect(bw.statement, '9.3 kg to go');
    expect(bw.percent, 7.5);
    expect(bw.drillDown.kind, DrillDownKind.weightEntries);
    final wst = byKind['wst']!;
    expect(wst.statement, '5.0 cm to go');
    expect(wst.percent, 28.6);
    expect(wst.drillDown.site, MeasurementSite.waist);
    expect(byKind['spw']!.statement, '2 of 3 sessions');
  });

  test('LoadGoalProgress with no goals is an empty list', () async {
    await db.delete(db.goals).go();
    final list = _ok(
      await LoadGoalProgress(
        goals: goals,
        measurements: measurements,
        sessions: sessions,
        settings: settings,
        clock: _clock,
      )(),
    );
    expect(list, isEmpty);
  });

  group('LoadWeeklyReport', () {
    LoadWeeklyReport report() => LoadWeeklyReport(
      nutrition: nutrition(),
      training: training(),
      weight: weight(),
      goals: goals,
    );

    test('this week fills all three sections', () async {
      final r = _ok(await report()(thisWeek));
      expect(r.nutrition.isAvailable, isTrue);
      expect(r.training.isAvailable, isTrue);
      expect(r.body.isAvailable, isTrue);
      final t = (r.training as MetricValue<TrainingSummary>).value;
      expect(t.sessionsGoal!.statement, '2 of 3 sessions');
      expect(
        (r.nutrition as MetricValue<NutritionSummary>).value.daysLoggedText,
        '2 of 6 days logged',
      );
    });

    test('a week without data reads 0 days logged and no body data', () async {
      final empty = AnalyticsPeriod.thisWeek(DateTime(2026, 6, 10, 12), 1);
      final r = _ok(await report()(empty));
      expect(
        (r.nutrition as MetricValue<NutritionSummary>).value.daysLoggedText,
        '0 of 7 days logged',
      );
      expect(r.training, isA<MetricValue<TrainingSummary>>()); // goal is set
      expect(r.body.isAvailable, isFalse);
    });

    test('a month period carries no sessions-per-week goal', () async {
      final r = _ok(await report()(AnalyticsPeriod.thisMonth(_now)));
      final t = (r.training as MetricValue<TrainingSummary>).value;
      expect(t.sessionsGoal, isNull);
    });
  });

  test('LoadPeriodComparison compares this week with last week', () async {
    final c = _ok(
      await LoadPeriodComparison(
        nutrition: nutrition(),
        training: training(),
        measurements: measurements,
      )(later: thisWeek),
    );
    expect(c.earlier, lastWeek);
    expect(c.of(ComparisonMeasure.energy).difference, 2150 - 1800);
    expect(c.of(ComparisonMeasure.volume).difference, 1352.5 - 400);
    // Last week has one weight reading (91), this week four (mean 89.3).
    expect(c.of(ComparisonMeasure.weight).difference, closeTo(-1.7, 1e-9));
  });

  test(
    'LoadPeriodComparison with an empty earlier period: not available',
    () async {
      final c = _ok(
        await LoadPeriodComparison(
          nutrition: nutrition(),
          training: training(),
          measurements: measurements,
        )(later: thisWeek, earlier: thisWeek.previous.previous.previous),
      );
      for (final m in c.measures) {
        expect(m.difference, isNull, reason: m.measure.name);
      }
    },
  );

  test('LoadExerciseProgress gives points, statements and records', () async {
    final v = _ok(
      await LoadExerciseProgress(
        sessions: sessions,
        settings: settings,
        exerciseName: name,
      )('bench'),
    );
    expect(v.exerciseName, 'Bench Press');
    expect(v.progress.points.map((p) => p.topSetWeightKg), [80, 82.5, 60]);
    expect(v.progress.points.map((p) => p.topSetStatement), [
      TrendStatement.firstSession,
      TrendStatement.increased,
      TrendStatement.decreased,
    ]);
    expect(
      v.recordEvents.map((e) => e.key),
      contains(const PrKey(PrMeasure.heaviestAtReps, 5)),
    );
  });

  test(
    'LoadExerciseProgress for an unknown exercise is empty, not an error',
    () async {
      final v = _ok(
        await LoadExerciseProgress(
          sessions: sessions,
          settings: settings,
          exerciseName: name,
        )('nope'),
      );
      expect(v.progress.isEmpty, isTrue);
      expect(v.exerciseName, unknownExerciseName);
    },
  );

  test('LoadRecompositionSeries puts three series on one range', () async {
    final period = AnalyticsPeriod.custom(
      CalendarDate(2026, 10, 26),
      CalendarDate(2026, 11, 8),
    );
    final s = _ok(
      await LoadRecompositionSeries(
        measurements: measurements,
        sessions: sessions,
      )(period: period, exerciseId: 'bench'),
    );
    expect(s.waist.pointCount, 2);
    expect(s.strength.pointCount, 3);
    expect(s.weight.pointCount, greaterThan(0));
    expect(s.range.start, CalendarDate(2026, 10, 26));
    final none = _ok(
      await LoadRecompositionSeries(
        measurements: measurements,
        sessions: sessions,
      )(period: period),
    );
    expect(none.strength.pointCount, 0);
    expect(none.exerciseId, isNull);
  });

  test(
    'a failing repository returns a StorageError, not an exception',
    () async {
      final failing = LoadTargetHistory(goals: _ThrowingGoals());
      final r = await failing();
      expect(r, isA<Err<dynamic>>());
      expect((r as Err).error, isA<StorageError>());
      expect(
        (await LoadWeightSummary(measurements: _ThrowingMeasurements())(
          thisWeek,
        )).isErr,
        isTrue,
      );
    },
  );

  test(
    'settings are read: a day start of 04:00 moves a late session',
    () async {
      await seedWorkout('late', DateTime(2026, 11, 9, 2, 30), [
        weighted(50, 5),
      ]);
      final next = AnalyticsPeriod.thisWeek(DateTime(2026, 11, 10, 12), 1);
      expect(_ok(await training().loadWeek(next)).sessionsCompleted, 1);
      await settings.save(const AppSettings(dayStartHour: 4));
      final shifted = AnalyticsPeriod.thisWeek(
        DateTime(2026, 11, 10, 12),
        1,
        dayStartHour: 4,
      );
      expect(_ok(await training().loadWeek(shifted)).sessionsCompleted, 0);
      expect(
        _ok(await training().loadWeek(shifted.previous)).sessionsCompleted,
        3,
      );
    },
  );
}

final class _ThrowingGoals implements GoalRepository {
  @override
  Future<List<Goal>> history() => throw Exception('db gone');
  @override
  Stream<List<Goal>> watchHistory() => throw Exception('db gone');
  @override
  Future<List<Goal>> active() => throw Exception('db gone');
  @override
  Stream<List<Goal>> watchActive() => throw Exception('db gone');
  @override
  Future<void> upsert(Goal goal) => throw Exception('db gone');
  @override
  Future<void> replaceActive(
    GoalKind kind,
    Goal? next, {
    MeasurementSite? site,
  }) => throw Exception('db gone');
  @override
  Future<void> replaceActiveAll(Map<GoalKind, Goal?> changes) =>
      throw Exception('db gone');
  @override
  Future<void> delete(String id) => throw Exception('db gone');
}

final class _ThrowingMeasurements implements MeasurementRepository {
  @override
  Future<List<Measurement>> readingsBetween(
    DateTime from,
    DateTime to, {
    MeasurementSite? site,
  }) => throw Exception('db gone');
  @override
  Stream<List<Measurement>> watchSite(MeasurementSite site) =>
      throw Exception('db gone');
  @override
  Stream<List<Measurement>> watchAll({int? limit}) =>
      throw Exception('db gone');
  @override
  Future<Measurement?> latest(MeasurementSite site) =>
      throw Exception('db gone');
  @override
  Future<Measurement?> byId(String id) => throw Exception('db gone');
  @override
  Future<bool> exists(String id) => throw Exception('db gone');
  @override
  Stream<List<UnreadableMeasurement>> watchUnreadable() =>
      throw Exception('db gone');
  @override
  Future<void> insert(Measurement m) => throw Exception('db gone');
  @override
  Future<void> insertAll(List<Measurement> items) => throw Exception('db gone');
  @override
  Future<int> update(Measurement m) => throw Exception('db gone');
  @override
  Future<void> delete(String id) => throw Exception('db gone');
}
