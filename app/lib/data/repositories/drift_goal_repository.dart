import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// drift-backed [GoalRepository].
final class DriftGoalRepository implements GoalRepository {
  DriftGoalRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<List<Goal>> watchActive() =>
      (_db.select(_db.goals)
            ..where((t) => t.deletedAt.isNull() & t.active.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.startDate)]))
          .watch()
          .map((rows) => [for (final r in rows) ?toEntity(r)]);

  @override
  Future<List<Goal>> active() async {
    final rows =
        await (_db.select(_db.goals)
              ..where((t) => t.deletedAt.isNull() & t.active.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.startDate)]))
            .get();
    return [for (final r in rows) ?toEntity(r)];
  }

  @override
  Future<void> replaceActive(
    GoalKind kind,
    Goal? next, {
    MeasurementSite? site,
  }) => _db.transaction(() => _replaceActiveInTransaction(kind, next, site));

  @override
  Future<void> replaceActiveAll(Map<GoalKind, Goal?> changes) =>
      _db.transaction(() async {
        for (final entry in changes.entries) {
          final next = entry.value;
          if (next != null && next.kind != entry.key) {
            throw ArgumentError.value(
              next,
              'changes',
              'goal kind ${next.kind.name} under key ${entry.key.name}',
            );
          }
          await _replaceActiveInTransaction(entry.key, next, null);
        }
      });

  /// Body shared by [replaceActive] and [replaceActiveAll]; the caller owns
  /// the transaction.
  Future<void> _replaceActiveInTransaction(
    GoalKind kind,
    Goal? next,
    MeasurementSite? site,
  ) async {
    final now = _clock.now().toUtc();
    final target = _db.update(_db.goals)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.active.equals(true) &
            t.kind.equals(kind.name) &
            (site == null ? t.site.isNull() : t.site.equals(site.name)),
      );
    await target.write(
      GoalsCompanion(active: const Value(false), updatedAt: Value(now)),
    );
    if (next != null) {
      await _db.into(_db.goals).insertOnConflictUpdate(toRow(next));
    }
  }

  @override
  Future<void> upsert(Goal goal) =>
      _db.into(_db.goals).insertOnConflictUpdate(toRow(goal));

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    final target = _db.update(_db.goals)
      ..where((t) => t.id.equals(id) & t.deletedAt.isNull());
    await target.write(
      GoalsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  static Goal? toEntity(GoalRow r) {
    final kind = GoalKind.values.asNameMap()[r.kind];
    if (kind == null) return null;
    return Goal(
      id: r.id,
      kind: kind,
      site: MeasurementSite.values.asNameMap()[r.site ?? ''],
      target: r.target,
      startDate: r.startDate,
      endDate: r.endDate,
      active: r.active,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  static GoalsCompanion toRow(Goal g) => GoalsCompanion.insert(
    id: g.id,
    kind: g.kind.name,
    site: Value(g.site?.name),
    target: g.target,
    startDate: g.startDate,
    endDate: Value(g.endDate),
    active: Value(g.active),
    createdAt: g.createdAt,
    updatedAt: g.updatedAt,
  );
}
