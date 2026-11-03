import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_goal_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';
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
      existing: const [],
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
    await useCase(
      input: {GoalKind.calories: '2400', GoalKind.protein: '180'},
      existing: const [],
    );
    final before = await repo.watchActive().first;
    await useCase(
      input: {GoalKind.calories: '2200', GoalKind.protein: '180'},
      existing: before,
    );
    final after = await repo.watchActive().first;
    expect(after.length, 2);
    expect(after.firstWhere((g) => g.kind == GoalKind.calories).target, 2200);
    expect(
      after.firstWhere((g) => g.kind == GoalKind.protein).id,
      before.firstWhere((g) => g.kind == GoalKind.protein).id,
    );
  });

  test('blank input deactivates an existing target', () async {
    await useCase(input: {GoalKind.calories: '2400'}, existing: const []);
    final before = await repo.watchActive().first;
    await useCase(input: {GoalKind.calories: ''}, existing: before);
    expect(await repo.watchActive().first, isEmpty);
  });

  test('rejects an out-of-range or non-numeric value with the field', () async {
    final r1 = await useCase(
      input: {GoalKind.calories: '300'},
      existing: const [],
    );
    final e1 = (r1 as Err<DailyTargets>).error as ValidationError;
    expect(e1.field, 'calories');
    final r2 = await useCase(
      input: {GoalKind.protein: 'lots'},
      existing: const [],
    );
    expect(
      ((r2 as Err<DailyTargets>).error as ValidationError).field,
      'protein',
    );
    expect(await repo.watchActive().first, isEmpty);
  });
}
