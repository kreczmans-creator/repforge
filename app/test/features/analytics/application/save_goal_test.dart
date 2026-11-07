import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_goal_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/analytics/application/save_goal.dart';

void main() {
  late AppDatabase db;
  late DriftGoalRepository repo;
  late SaveGoal save;
  var n = 0;

  setUp(() {
    db = AppDatabase.inMemory();
    final clock = FixedClock(DateTime(2026, 11, 7, 12));
    repo = DriftGoalRepository(db, clock: clock);
    save = SaveGoal(repository: repo, clock: clock, newId: () => 'id${n++}');
  });
  tearDown(() => db.close());

  String? errorField(Result<Object?> r) =>
      r is Err<Object?> && r.error is ValidationError
      ? (r.error as ValidationError).field
      : null;

  test('saves a weight goal and replaces the active one', () async {
    final first = await save(kind: GoalKind.bodyWeight, targetText: '80');
    expect(first.isOk, isTrue);
    final second = await save(
      kind: GoalKind.bodyWeight,
      targetText: '78,5',
      endDateText: '2026-12-31',
    );
    expect(second.isOk, isTrue);
    final active = await repo.active();
    expect(active, hasLength(1));
    expect(active.single.target, 78.5);
    expect(active.single.endDate, isNotNull);
    expect(await repo.history(), hasLength(2));
  });

  test('one active measurement goal per site; left and right differ', () async {
    await save(
      kind: GoalKind.measurement,
      targetText: '60',
      site: MeasurementSite.thighLeft,
    );
    await save(
      kind: GoalKind.measurement,
      targetText: '61',
      site: MeasurementSite.thighRight,
    );
    await save(
      kind: GoalKind.measurement,
      targetText: '59',
      site: MeasurementSite.thighLeft,
    );
    final active = await repo.active();
    expect(active, hasLength(2));
    expect(
      active.firstWhere((g) => g.site == MeasurementSite.thighLeft).target,
      59,
    );
    expect(
      active.firstWhere((g) => g.site == MeasurementSite.thighRight).target,
      61,
    );
  });

  test('validates target, whole sessions, site and date', () async {
    expect(
      errorField(await save(kind: GoalKind.bodyWeight, targetText: '')),
      'target',
    );
    expect(
      errorField(await save(kind: GoalKind.bodyWeight, targetText: '10')),
      'target',
    );
    expect(
      errorField(await save(kind: GoalKind.sessionsPerWeek, targetText: '15')),
      'target',
    );
    expect(
      errorField(await save(kind: GoalKind.sessionsPerWeek, targetText: '2.5')),
      'target',
    );
    expect(
      errorField(await save(kind: GoalKind.sessionsPerWeek, targetText: '0')),
      'target',
    );
    expect(
      (await save(kind: GoalKind.sessionsPerWeek, targetText: '1')).isOk,
      isTrue,
    );
    expect(
      errorField(await save(kind: GoalKind.measurement, targetText: '60')),
      'site',
    );
    expect(
      errorField(
        await save(
          kind: GoalKind.measurement,
          targetText: '60',
          site: MeasurementSite.weight,
        ),
      ),
      'site',
    );
    expect(
      errorField(
        await save(
          kind: GoalKind.bodyWeight,
          targetText: '80',
          endDateText: '2026-02-30',
        ),
      ),
      'endDate',
    );
    expect(
      errorField(
        await save(
          kind: GoalKind.bodyWeight,
          targetText: '80',
          endDateText: '2026-11-06',
        ),
      ),
      'endDate',
    );
    expect(
      (await save(
        kind: GoalKind.bodyWeight,
        targetText: '80',
        endDateText: '2026-11-07',
      )).isOk,
      isTrue,
    );
  });

  test('a deadline is stored as a UTC calendar date', () async {
    final r = await save(
      kind: GoalKind.bodyWeight,
      targetText: '80',
      endDateText: '2026-12-31',
    );
    expect((r as Ok<Goal>).value.endDate, DateTime.utc(2026, 12, 31));
    final stored = (await repo.active()).single.endDate!.toUtc();
    expect((stored.year, stored.month, stored.day), (2026, 12, 31));
  });

  test('daily nutrition kinds are not handled here', () async {
    final r = await save(kind: GoalKind.calories, targetText: '2000');
    expect(r.isErr, isTrue);
    expect((await save.clear(GoalKind.calories)).isErr, isTrue);
    expect(await repo.active(), isEmpty);
  });

  test('clear deactivates the goal and keeps the history', () async {
    await save(kind: GoalKind.sessionsPerWeek, targetText: '3');
    expect(
      (await save.current(GoalKind.sessionsPerWeek) as Ok<Goal?>).value,
      isNotNull,
    );
    expect(
      ((await save.clear(GoalKind.sessionsPerWeek)) as Ok<bool>).value,
      isTrue,
    );
    expect(await repo.active(), isEmpty);
    expect(await repo.history(), hasLength(1));
    expect(
      ((await save.clear(GoalKind.sessionsPerWeek)) as Ok<bool>).value,
      isFalse,
    );
  });

  test('a storage failure is returned, not thrown', () async {
    final failing = SaveGoal(
      repository: _FailingGoals(),
      clock: FixedClock(DateTime(2026, 11, 7, 12)),
      newId: () => 'x',
    );
    final saved = await failing(kind: GoalKind.bodyWeight, targetText: '80');
    expect((saved as Err<Goal>).error, isA<StorageError>());
    final cleared = await failing.clear(GoalKind.bodyWeight);
    expect((cleared as Err<bool>).error, isA<StorageError>());
    final current = await failing.current(GoalKind.bodyWeight);
    expect((current as Err<Goal?>).error, isA<StorageError>());
  });
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
