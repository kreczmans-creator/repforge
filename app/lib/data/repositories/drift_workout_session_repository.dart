import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/group_by.dart';
import 'package:repforge/data/mappers/training_mappers.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// drift-backed [WorkoutSessionRepository] over `workout_sessions` and
/// `session_sets` and `session_exercises`.
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
  Future<WorkoutSession?> byId(String id, {bool includeDeleted = false}) async {
    final row =
        await (_db.select(_db.workoutSessions)..where(
              (t) => includeDeleted
                  ? t.id.equals(id)
                  : t.id.equals(id) & t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return (await _load([row])).firstOrNull;
  }

  @override
  Future<List<WorkoutSession>> sessionsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final rows =
        await (_db.select(_db.workoutSessions)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.startedAt.isBiggerOrEqualValue(from.toUtc()) &
                    t.startedAt.isSmallerThanValue(to.toUtc()),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.startedAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return await _load(rows);
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
  Future<bool> restore(String id) async {
    final now = _clock.now().toUtc();
    final changed =
        await (_db.update(
          _db.workoutSessions,
        )..where((t) => t.id.equals(id) & t.deletedAt.isNotNull())).write(
          WorkoutSessionsCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(now),
          ),
        );
    return changed > 0;
  }

  @override
  Future<List<PerformedSet>> performedSets(String exerciseId) async {
    final q =
        _db.select(_db.sessionSets).join([
            innerJoin(
              _db.workoutSessions,
              _db.workoutSessions.id.equalsExp(_db.sessionSets.sessionId),
            ),
          ])
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
    final rows = await q.get();
    return [
      for (final r in rows)
        if (TrainingMappers.sessionSetToEntity(r.readTable(_db.sessionSets))
            case final set?)
          PerformedSet(
            sessionId: set.sessionId,
            startedAt: r.readTable(_db.workoutSessions).startedAt,
            set: set,
          ),
    ];
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
  Future<void> addSet(
    SessionSet set, {
    SessionExercise? newEntry,
  }) => _db.transaction(() async {
    final session =
        await (_db.select(_db.workoutSessions)
              ..where((t) => t.id.equals(set.sessionId) & t.deletedAt.isNull()))
            .getSingleOrNull();
    if (session == null) {
      throw StateError('Session ${set.sessionId} does not exist.');
    }
    final entries = await (_db.select(
      _db.sessionExercises,
    )..where((t) => t.sessionId.equals(set.sessionId))).get();
    SessionExerciseRow? entry;
    final wanted = set.sessionExerciseId;
    if (wanted != null) {
      entry = entries.where((e) => e.id == wanted).firstOrNull;
      if (entry == null && newEntry?.id != wanted) {
        throw StateError('Entry $wanted is not in ${set.sessionId}.');
      }
    } else {
      // A raw set (no entry named) joins the entry of its exercise at its
      // own exercise order; RecordSet always names the entry.
      entry = entries
          .where(
            (e) =>
                e.exerciseId == set.exerciseId &&
                e.position == set.exerciseOrder,
          )
          .firstOrNull;
    }
    if (entry != null && entry.exerciseId != set.exerciseId) {
      throw StateError('Entry ${entry.id} is for another exercise.');
    }
    if (entry == null) {
      final taken = {for (final e in entries) e.position};
      final last = taken.isEmpty ? -1 : taken.reduce((a, b) => a > b ? a : b);
      final created =
          newEntry ??
          SessionExercise(
            id: 'entry-${set.id}',
            sessionId: set.sessionId,
            exerciseId: set.exerciseId,
            position:
                !taken.contains(set.exerciseOrder) && set.exerciseOrder >= 0
                ? set.exerciseOrder
                : last + 1,
          );
      if (created.sessionId != set.sessionId ||
          created.exerciseId != set.exerciseId) {
        throw StateError('The new entry does not match the set.');
      }
      await _db
          .into(_db.sessionExercises)
          .insert(TrainingMappers.sessionExerciseToRow(created));
      entry = await (_db.select(
        _db.sessionExercises,
      )..where((t) => t.id.equals(created.id))).getSingle();
    }
    await _db
        .into(_db.sessionSets)
        .insert(
          TrainingMappers.sessionSetToRow(
            set.sessionId,
            set.copyWith(
              sessionExerciseId: entry.id,
              exerciseOrder: entry.position,
            ),
          ),
        );
  });

  @override
  Future<bool> updateSet(SessionSet set) async {
    final row = await (_db.select(
      _db.sessionSets,
    )..where((t) => t.id.equals(set.id))).getSingleOrNull();
    if (row == null) return false;
    final keep = set.copyWith(
      sessionId: row.sessionId,
      exerciseId: row.exerciseId,
      sessionExerciseId: row.sessionExerciseId,
      exerciseOrder: row.exerciseOrder,
    );
    await (_db.update(_db.sessionSets)..where((t) => t.id.equals(set.id)))
        .write(TrainingMappers.sessionSetToRow(row.sessionId, keep));
    return true;
  }

  @override
  Future<bool> deleteSet(String setId) async {
    final n = await (_db.delete(
      _db.sessionSets,
    )..where((t) => t.id.equals(setId))).go();
    return n > 0;
  }

  @override
  Future<void> addExercise(SessionExercise entry) async {
    final session =
        await (_db.select(_db.workoutSessions)..where(
              (t) => t.id.equals(entry.sessionId) & t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (session == null) {
      throw StateError('Session ${entry.sessionId} does not exist.');
    }
    await _db
        .into(_db.sessionExercises)
        .insert(TrainingMappers.sessionExerciseToRow(entry));
  }

  @override
  Future<bool> updateExercise(SessionExercise entry) =>
      _db.transaction(() async {
        final changed =
            await (_db.update(
              _db.sessionExercises,
            )..where((t) => t.id.equals(entry.id))).write(
              SessionExercisesCompanion(
                exerciseId: Value(entry.exerciseId),
                note: Value(entry.note),
              ),
            );
        if (changed == 0) return false;
        await (_db.update(_db.sessionSets)
              ..where((t) => t.sessionExerciseId.equals(entry.id)))
            .write(SessionSetsCompanion(exerciseId: Value(entry.exerciseId)));
        return true;
      });

  @override
  Future<bool> removeExercise(String entryId) => _db.transaction(() async {
    await (_db.delete(
      _db.sessionSets,
    )..where((t) => t.sessionExerciseId.equals(entryId))).go();
    final n = await (_db.delete(
      _db.sessionExercises,
    )..where((t) => t.id.equals(entryId))).go();
    return n > 0;
  });

  @override
  Future<void> setExerciseOrder(String sessionId, List<String> entryIds) =>
      _db.transaction(() async {
        final entries = await (_db.select(
          _db.sessionExercises,
        )..where((t) => t.sessionId.equals(sessionId))).get();
        final stored = {for (final e in entries) e.id};
        if (entryIds.length != stored.length ||
            entryIds.toSet().length != entryIds.length ||
            !stored.containsAll(entryIds)) {
          throw StateError('The order must list the session entries.');
        }
        for (var i = 0; i < entryIds.length; i++) {
          await (_db.update(_db.sessionExercises)
                ..where((t) => t.id.equals(entryIds[i])))
              .write(SessionExercisesCompanion(position: Value(i)));
          await (_db.update(_db.sessionSets)
                ..where((t) => t.sessionExerciseId.equals(entryIds[i])))
              .write(SessionSetsCompanion(exerciseOrder: Value(i)));
        }
      });

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
    final ids = rows.map((r) => r.id);
    final sets = await (_db.select(
      _db.sessionSets,
    )..where((t) => t.sessionId.isIn(ids))).get();
    final entries = await (_db.select(
      _db.sessionExercises,
    )..where((t) => t.sessionId.isIn(ids))).get();
    final bySession = groupByParent(sets, (s) => s.sessionId);
    final entriesBySession = groupByParent(entries, (e) => e.sessionId);
    return [
      for (final r in rows)
        TrainingMappers.sessionToEntity(
          r,
          bySession[r.id] ?? const [],
          entriesBySession[r.id] ?? const [],
        ),
    ];
  }
}
