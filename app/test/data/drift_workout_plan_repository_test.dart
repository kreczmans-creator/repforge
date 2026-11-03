import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));
final _t = DateTime.utc(2026, 11, 1, 8);

WorkoutPlan _plan(String id, List<PlanExercise> exercises, {String? name}) =>
    WorkoutPlan(
      id: id,
      name: name ?? 'Push A',
      split: 'PPL',
      scheduledWeekdays: const [1, 3, 5],
      exercises: exercises,
      createdAt: _t,
      updatedAt: _t,
    );

PlanExercise _pe(String id, int order, {bool full = false}) => PlanExercise(
  id: id,
  exerciseId: 'ex-$id',
  sortOrder: order,
  targetSets: 3,
  targetReps: full ? 8 : null,
  targetLoad: full ? LoadKg.fromStored(62.5) : null,
  targetDuration: full ? const Duration(seconds: 45) : null,
  restSeconds: full ? 90 : null,
);

void main() {
  late AppDatabase db;
  late DriftWorkoutPlanRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftWorkoutPlanRepository(db, clock: _clock);
  });
  tearDown(() => db.close());

  test('round-trips a plan with exercises in order', () async {
    final plan = _plan('p', [_pe('a', 0, full: true), _pe('b', 1)]);
    await repo.upsert(plan);
    expect(await repo.byId('p'), plan);
    expect((await repo.watchAll().first).single, plan);
  });

  test('preserves sortOrder regardless of insertion order', () async {
    final plan = _plan('p', [_pe('c', 2), _pe('a', 0), _pe('b', 1)]);
    await repo.upsert(plan);
    final loaded = (await repo.byId('p'))!;
    expect(loaded.exercises.map((e) => e.id), ['a', 'b', 'c']);
  });

  test('upsert replaces children', () async {
    await repo.upsert(_plan('p', [_pe('a', 0), _pe('b', 1)]));
    final updated = _plan('p', [_pe('c', 0, full: true)], name: 'Push B');
    await repo.upsert(updated);
    expect(await repo.byId('p'), updated);
    expect(await db.select(db.planExercises).get(), hasLength(1));
    expect(await db.select(db.workoutPlans).get(), hasLength(1));
  });

  test('archived plans are hidden unless requested', () async {
    final plan = _plan('p', [_pe('a', 0)]).copyWith(archived: true);
    await repo.upsert(plan);
    expect(await repo.watchAll().first, isEmpty);
    expect(await repo.watchAll(includeArchived: true).first, [plan]);
  });

  test('delete soft-deletes, stamps from clock, and is idempotent', () async {
    await repo.upsert(_plan('p', [_pe('a', 0)]));
    await repo.delete('p');
    final first = (await db.select(db.workoutPlans).get()).single;
    expect(first.deletedAt, _clock.now());
    expect(await repo.byId('p'), isNull);
    expect(await repo.watchAll(includeArchived: true).first, isEmpty);

    await repo.delete('p');
    final second = (await db.select(db.workoutPlans).get()).single;
    expect(second.updatedAt, first.updatedAt);
    expect(second.deletedAt, first.deletedAt);
  });

  test('skips a plan exercise with an out-of-range target load', () async {
    await repo.upsert(_plan('p', [_pe('a', 0)]));
    await db
        .into(db.planExercises)
        .insert(
          PlanExercisesCompanion.insert(
            id: 'bad',
            planId: 'p',
            exerciseId: 'x',
            sortOrder: 1,
            targetSets: 3,
            targetLoadKg: const Value(5000),
          ),
        );
    final loaded = (await repo.byId('p'))!;
    expect(loaded.exercises.map((e) => e.id), ['a']);
  });

  test('skips a plan with corrupt weekday JSON', () async {
    await db
        .into(db.workoutPlans)
        .insert(
          WorkoutPlansCompanion.insert(
            id: 'bad',
            name: 'Bad',
            scheduledWeekdaysJson: 'not json',
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    expect(await repo.watchAll().first, isEmpty);
  });
}
