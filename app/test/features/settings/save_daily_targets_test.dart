import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_goal_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/settings/application/save_daily_targets.dart';

void main() {
  late AppDatabase db;
  late DriftGoalRepository repo;
  late SaveDailyTargets useCase;
  var ids = 0;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftGoalRepository(
      db,
      clock: FixedClock(DateTime.utc(2026, 11, 3, 9)),
    );
    useCase = SaveDailyTargets(
      repository: repo,
      clock: FixedClock(DateTime.utc(2026, 11, 3, 9)),
      newId: () => 'g${++ids}',
    );
  });
  tearDown(() => db.close());

  test('creates active goals for the filled kinds only', () async {
    final r = await useCase(
      input: {
        GoalKind.calories: '2400',
        GoalKind.protein: '180',
        GoalKind.carbs: '',
        GoalKind.fat: ' 75 ',
      },
    );
    expect(r, isA<Ok<DailyTargets>>());
    final goals = await repo.watchActive().first;
    expect(goals.map((g) => g.kind), [
      GoalKind.calories,
      GoalKind.protein,
      GoalKind.fat,
    ]);
    expect(goals.firstWhere((g) => g.kind == GoalKind.fat).target, 75);
  });

  test('replaces a changed target and keeps an unchanged one', () async {
    await useCase(input: {GoalKind.calories: '2400', GoalKind.protein: '180'});
    final before = await repo.watchActive().first;
    await useCase(input: {GoalKind.calories: '2200', GoalKind.protein: '180'});
    final after = await repo.watchActive().first;
    expect(after.length, 2);
    expect(after.firstWhere((g) => g.kind == GoalKind.calories).target, 2200);
    expect(
      after.firstWhere((g) => g.kind == GoalKind.protein).id,
      before.firstWhere((g) => g.kind == GoalKind.protein).id,
    );
  });

  test('blank input deactivates an existing target', () async {
    await useCase(input: {GoalKind.calories: '2400'});
    await useCase(input: {GoalKind.calories: ''});
    expect(await repo.watchActive().first, isEmpty);
  });

  test('rejects an out-of-range or non-numeric value with the field', () async {
    final r1 = await useCase(input: {GoalKind.calories: '300'});
    final e1 = (r1 as Err<DailyTargets>).error as ValidationError;
    expect(e1.field, 'calories');
    final r2 = await useCase(input: {GoalKind.protein: 'lots'});
    expect(
      ((r2 as Err<DailyTargets>).error as ValidationError).field,
      'protein',
    );
    expect(await repo.watchActive().first, isEmpty);
  });

  test('applies all changed kinds in one repository transaction', () async {
    await useCase(input: {GoalKind.calories: '2400', GoalKind.protein: '180'});
    final recording = _Recording(repo);
    final atomic = SaveDailyTargets(
      repository: recording,
      clock: FixedClock(DateTime.utc(2026, 11, 3, 10)),
      newId: () => 'a${++ids}',
    );
    final r = await atomic(
      input: {
        GoalKind.calories: '2000',
        GoalKind.protein: '180', // unchanged: not part of the call
        GoalKind.fat: '70',
      },
    );
    expect(r, isA<Ok<DailyTargets>>());
    // Atomicity is the repository's guarantee (see
    // drift_goal_repository_test "rolls back every kind when a later entry
    // fails"); the use case must hand it every change in a single call.
    expect(recording.batches.length, 1);
    expect(recording.batches.single.keys.toSet(), {
      GoalKind.calories,
      GoalKind.fat,
    });
    expect(recording.singleCalls, isEmpty);
  });
}

/// Delegates to the real repository and records how changes were applied.
final class _Recording implements GoalRepository {
  _Recording(this.inner);
  final GoalRepository inner;
  final batches = <Map<GoalKind, Goal?>>[];
  final singleCalls = <GoalKind>[];

  @override
  Future<void> replaceActiveAll(Map<GoalKind, Goal?> changes) {
    batches.add(Map.of(changes));
    return inner.replaceActiveAll(changes);
  }

  @override
  Future<List<Goal>> active() => inner.active();
  @override
  Future<List<Goal>> history() => inner.history();
  @override
  Stream<List<Goal>> watchHistory() => inner.watchHistory();
  @override
  Future<void> delete(String id) => inner.delete(id);
  @override
  Future<void> replaceActive(
    GoalKind kind,
    Goal? next, {
    MeasurementSite? site,
  }) {
    singleCalls.add(kind);
    return inner.replaceActive(kind, next, site: site);
  }

  @override
  Future<void> upsert(Goal goal) => inner.upsert(goal);
  @override
  Stream<List<Goal>> watchActive() => inner.watchActive();
}
