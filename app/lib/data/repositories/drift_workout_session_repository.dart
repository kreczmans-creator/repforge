import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/group_by.dart';
import 'package:repforge/data/mappers/training_mappers.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// drift-backed [WorkoutSessionRepository] over `workout_sessions` and
/// `session_sets`.
final class DriftWorkoutSessionRepository implements WorkoutSessionRepository {
  DriftWorkoutSessionRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<List<WorkoutSession>> watchAll({int limit = 100}) {
    final q = _db.select(_db.workoutSessions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.startedAt),
        (t) => OrderingTerm.desc(t.createdAt),
      ])
      ..limit(limit);
    return q.watch().asyncMap(_load);
  }

  @override
  Future<WorkoutSession?> byId(String id) async {
    final row = await (_db.select(
      _db.workoutSessions,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return null;
    return (await _load([row])).firstOrNull;
  }

  /// Writes the session row only; never touches `session_sets`. Sets enter
  /// the database through [addSet] (used by `RecordSet`, which validates
  /// them), so a caller cannot store an unvalidated set by passing it here.
  @override
  Future<void> upsert(WorkoutSession session) => _db
      .into(_db.workoutSessions)
      .insertOnConflictUpdate(TrainingMappers.sessionToRow(session));

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    await (_db.update(
      _db.workoutSessions,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      WorkoutSessionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  @override
  Future<List<SessionSet>> setsForExercise(String exerciseId) async {
    final q =
        _db.select(_db.sessionSets).join([
            innerJoin(
              _db.workoutSessions,
              _db.workoutSessions.id.equalsExp(_db.sessionSets.sessionId),
            ),
          ])
          // Only completed sets count as performed history (PR checks).
          ..where(
            _db.sessionSets.exerciseId.equals(exerciseId) &
                _db.sessionSets.completed.equals(true) &
                _db.workoutSessions.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.asc(_db.workoutSessions.startedAt),
            OrderingTerm.asc(_db.sessionSets.sessionId),
            OrderingTerm.asc(_db.sessionSets.exerciseOrder),
            OrderingTerm.asc(_db.sessionSets.setOrder),
          ]);
    final rows = await q.map((r) => r.readTable(_db.sessionSets)).get();
    return [for (final r in rows) ?TrainingMappers.sessionSetToEntity(r)];
  }

  @override
  Future<void> addSet(SessionSet set) async {
    final session =
        await (_db.select(_db.workoutSessions)
              ..where((t) => t.id.equals(set.sessionId) & t.deletedAt.isNull()))
            .getSingleOrNull();
    if (session == null) {
      throw StateError('Session ${set.sessionId} does not exist.');
    }
    await _db
        .into(_db.sessionSets)
        .insert(TrainingMappers.sessionSetToRow(set.sessionId, set));
  }

  @override
  Future<bool> hasHistory(String exerciseId) async {
    final q =
        _db.selectOnly(_db.sessionSets).join([
            innerJoin(
              _db.workoutSessions,
              _db.workoutSessions.id.equalsExp(_db.sessionSets.sessionId),
            ),
          ])
          ..addColumns([_db.sessionSets.id])
          ..where(
            _db.sessionSets.exerciseId.equals(exerciseId) &
                _db.workoutSessions.deletedAt.isNull(),
          )
          ..limit(1);
    return (await q.get()).isNotEmpty;
  }

  @override
  Future<List<ExerciseSessionHistory>> sessionsForExercise(
    String exerciseId, {
    int? limit,
    int offset = 0,
  }) async {
    // Sessions that have completed sets of the exercise, newest first.
    final q = _db.select(_db.workoutSessions)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.id.isInQuery(
              _db.selectOnly(_db.sessionSets)
                ..addColumns([_db.sessionSets.sessionId])
                ..where(
                  _db.sessionSets.exerciseId.equals(exerciseId) &
                      _db.sessionSets.completed.equals(true),
                ),
            ),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.startedAt),
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    if (limit != null) q.limit(limit, offset: offset);
    final sessions = await q.get();
    if (sessions.isEmpty) return const [];
    final sets =
        await (_db.select(_db.sessionSets)
              ..where(
                (t) =>
                    t.exerciseId.equals(exerciseId) &
                    t.completed.equals(true) &
                    t.sessionId.isIn(sessions.map((s) => s.id)),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.exerciseOrder),
                (t) => OrderingTerm.asc(t.setOrder),
              ]))
            .get();
    final bySession = groupByParent(sets, (s) => s.sessionId);
    return [
      for (final s in sessions)
        ExerciseSessionHistory(
          sessionId: s.id,
          sessionName: s.name,
          startedAt: s.startedAt,
          sets: [
            for (final r in bySession[s.id] ?? const <SessionSetRow>[])
              ?TrainingMappers.sessionSetToEntity(r),
          ],
        ),
    ];
  }

  @override
  Future<List<SessionSet>> lastPerformance(String exerciseId) async {
    final history = await sessionsForExercise(exerciseId, limit: 1);
    return history.isEmpty ? const [] : history.first.sets;
  }

  Future<List<WorkoutSession>> _load(List<WorkoutSessionRow> rows) async {
    if (rows.isEmpty) return const [];
    final sets = await (_db.select(
      _db.sessionSets,
    )..where((t) => t.sessionId.isIn(rows.map((r) => r.id)))).get();
    final bySession = groupByParent(sets, (s) => s.sessionId);
    return [
      for (final r in rows)
        TrainingMappers.sessionToEntity(r, bySession[r.id] ?? const []),
    ];
  }
}
