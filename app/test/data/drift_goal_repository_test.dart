import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_goal_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));
final _t = DateTime.utc(2026, 11, 1, 8);

Goal _goal(
  String id,
  GoalKind kind,
  double target, {
  DateTime? start,
  MeasurementSite? site,
  DateTime? endDate,
  bool active = true,
}) => Goal(
  id: id,
  kind: kind,
  target: target,
  startDate: start ?? _t,
  site: site,
  endDate: endDate,
  active: active,
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  group('DriftGoalRepository (in-memory)', () {
    late AppDatabase db;
    late DriftGoalRepository repo;

    setUp(() {
      db = AppDatabase.inMemory();
      repo = DriftGoalRepository(db, clock: _clock);
    });
    tearDown(() => db.close());

    test('upsert then read a plain goal', () async {
      await repo.upsert(_goal('g', GoalKind.calories, 2400));
      final g = (await repo.watchActive().first).single;
      expect(g.id, 'g');
      expect(g.kind, GoalKind.calories);
      expect(g.target, 2400);
      expect(g.site, isNull);
      expect(g.endDate, isNull);
      expect(g.active, isTrue);
      expect(g.startDate.isAtSameMomentAs(_t), isTrue);
    });

    test('keeps site and endDate for a measurement goal', () async {
      final end = DateTime.utc(2027);
      await repo.upsert(
        _goal(
          'm',
          GoalKind.measurement,
          82,
          site: MeasurementSite.waist,
          endDate: end,
        ),
      );
      final g = (await repo.watchActive().first).single;
      expect(g.kind, GoalKind.measurement);
      expect(g.site, MeasurementSite.waist);
      expect(g.endDate!.isAtSameMomentAs(end), isTrue);
    });

    test('upsert replaces an existing goal', () async {
      await repo.upsert(_goal('g', GoalKind.protein, 150));
      await repo.upsert(_goal('g', GoalKind.protein, 180));
      final goals = await repo.watchActive().first;
      expect(goals, hasLength(1));
      expect(goals.single.target, 180);
    });

    test('watchActive hides inactive goals', () async {
      await repo.upsert(_goal('a', GoalKind.calories, 2400));
      await repo.upsert(_goal('b', GoalKind.protein, 150, active: false));
      expect((await repo.watchActive().first).map((g) => g.id), ['a']);
    });

    test('watchActive orders by startDate ascending', () async {
      await repo.upsert(
        _goal('late', GoalKind.fat, 70, start: DateTime.utc(2026, 11, 3)),
      );
      await repo.upsert(
        _goal('early', GoalKind.carbs, 250, start: DateTime.utc(2026, 10)),
      );
      expect((await repo.watchActive().first).map((g) => g.id), [
        'early',
        'late',
      ]);
    });

    test('delete soft-deletes, hides the goal and is idempotent', () async {
      await repo.upsert(_goal('g', GoalKind.calories, 2400));
      await repo.delete('g');
      expect(await repo.watchActive().first, isEmpty);

      final first = (await db.select(db.goals).get()).single;
      expect(first.deletedAt!.isAtSameMomentAs(_clock.now()), isTrue);

      await repo.delete('g');
      await repo.delete('missing');
      final second = (await db.select(db.goals).get()).single;
      expect(second.updatedAt, first.updatedAt);
    });

    test('skips a row with an unknown kind', () async {
      await repo.upsert(_goal('ok', GoalKind.calories, 2400));
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'bad',
              kind: 'moonshot',
              target: 1,
              startDate: _t,
              createdAt: _t,
              updatedAt: _t,
            ),
          );
      expect((await repo.watchActive().first).map((g) => g.id), ['ok']);
    });

    test('unknown site string maps to null site', () async {
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'g',
              kind: 'measurement',
              site: const Value('earlobe'),
              target: 1,
              startDate: _t,
              createdAt: _t,
              updatedAt: _t,
            ),
          );
      expect((await repo.watchActive().first).single.site, isNull);
    });
  });
}
