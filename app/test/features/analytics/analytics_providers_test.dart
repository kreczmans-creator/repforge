import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';

import '../../helpers/analytics_fixtures.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime(2026, 11, 7, 12);

  setUp(() {
    db = AppDatabase.inMemory();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(now)),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('family providers read through the repositories', () async {
    final week = AnalyticsPeriod.thisWeek(now, 1);
    await container.read(foodLogRepositoryProvider).insertAll([
      foodEntry('2026-11-03', 2000),
    ]);
    await container.read(measurementRepositoryProvider).insertAll([
      weightReading(90, 11, 3),
      weightReading(90, 11, 4),
      weightReading(90, 11, 5),
    ]);

    final nutrition = await container.read(nutritionWeekProvider(week).future);
    expect(nutrition.daysLoggedText, '1 of 7 days logged');

    final weight = await container.read(weightSummaryProvider(week).future);
    expect(weight.latestTrend!.average, 90);

    final report = await container.read(weeklyReportProvider(week).future);
    expect(report.nutrition.isAvailable, isTrue);
    expect(report.training.isAvailable, isFalse);

    final training = await container.read(weekTrainingProvider(week).future);
    expect(training.week.sessionsCompleted, 0);

    final comparison = await container.read(
      periodComparisonProvider((later: week, earlier: week.previous)).future,
    );
    expect(comparison.measures, hasLength(4));

    final recomposition = await container.read(
      recompositionSeriesProvider((period: week, exerciseId: null)).future,
    );
    expect(recomposition.weight.pointCount, 1);
  });

  test('the same period key gives the same provider instance', () {
    final a = AnalyticsPeriod.thisWeek(now, 1);
    final b = AnalyticsPeriod.thisWeek(now, 1);
    expect(nutritionWeekProvider(a), nutritionWeekProvider(b));
  });

  test('goal progress, target history and exercise progress', () async {
    final goals = container.read(goalRepositoryProvider);
    await goals.upsert(
      Goal(
        id: 'g',
        kind: GoalKind.sessionsPerWeek,
        target: 3,
        startDate: DateTime(2026, 10).toUtc(),
        createdAt: DateTime(2026, 10).toUtc(),
        updatedAt: DateTime(2026, 10).toUtc(),
      ),
    );
    final progress = await container.read(goalProgressProvider.future);
    expect(progress.single.statement, '0 of 3 sessions');

    final history = await container.read(targetHistoryProvider.future);
    expect(history.allPeriods, hasLength(1));

    await DriftExerciseRepository(db, clock: FixedClock(now)).upsert(
      Exercise(
        id: 'bench',
        name: 'Bench Press',
        type: ExerciseType.weighted,
        category: ExerciseCategory.push,
        primaryMuscle: MuscleGroup.chest,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
    );
    final view = await container.read(exerciseProgressProvider('bench').future);
    expect(view.exerciseName, 'Bench Press');
    expect(view.progress.isEmpty, isTrue);
    expect(await container.read(exerciseNameLookupProvider)('missing'), isNull);
  });

  test('a failed load surfaces as AnalyticsLoadException', () async {
    final failing = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        goalRepositoryProvider.overrideWithValue(_FailingGoals()),
      ],
    );
    addTearDown(failing.dispose);
    await expectLater(
      failing.read(goalProgressProvider.future),
      throwsA(isA<AnalyticsLoadException>()),
    );
  });

  test(
    'NotEnoughData is returned, not thrown, for an empty database',
    () async {
      final week = AnalyticsPeriod.thisWeek(now, 1);
      final n = await container.read(nutritionWeekProvider(week).future);
      expect(n.averageEnergyKcal, isA<NotEnoughData<double>>());
    },
  );
}

final class _FailingGoals implements GoalRepository {
  @override
  Future<List<Goal>> active() => Future.error(StateError('db gone'));
  @override
  Future<List<Goal>> history() => Future.error(StateError('db gone'));
  @override
  Stream<List<Goal>> watchActive() => Stream.error(StateError('db gone'));
  @override
  Stream<List<Goal>> watchHistory() => Stream.error(StateError('db gone'));
  @override
  Future<void> upsert(Goal goal) => Future.error(StateError('db gone'));
  @override
  Future<void> replaceActive(
    GoalKind kind,
    Goal? next, {
    MeasurementSite? site,
  }) => Future.error(StateError('db gone'));
  @override
  Future<void> replaceActiveAll(Map<GoalKind, Goal?> changes) =>
      Future.error(StateError('db gone'));
  @override
  Future<void> delete(String id) => Future.error(StateError('db gone'));
}
