import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/training_mappers.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// drift-backed [ExerciseRepository] over the `exercises` table.
final class DriftExerciseRepository implements ExerciseRepository {
  DriftExerciseRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<List<Exercise>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.exercises)
      ..where(
        (t) => includeArchived
            ? t.deletedAt.isNull()
            : t.deletedAt.isNull() & t.archived.equals(false),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return q.watch().map(_toEntities);
  }

  @override
  Stream<List<Exercise>> watchLibrary(ExerciseQuery query) {
    // The library is a few hundred rows: filtering and the primary-first
    // ordering run in Dart on the same rule the tests exercise
    // (filterExercises); only archived rows are excluded in SQL.
    final q = _db.select(_db.exercises)
      ..where(
        (t) => query.includeArchived
            ? t.deletedAt.isNull()
            : t.deletedAt.isNull() & t.archived.equals(false),
      );
    return q.watch().map((rows) => filterExercises(_toEntities(rows), query));
  }

  @override
  Future<List<Exercise>> search(ExerciseQuery query) =>
      watchLibrary(query).first;

  @override
  Future<Exercise?> byId(String id) async {
    final row = await (_db.select(
      _db.exercises,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : TrainingMappers.exerciseToEntity(row);
  }

  @override
  Future<bool> exists(String id) async =>
      (await (_db.selectOnly(_db.exercises)
                ..addColumns([_db.exercises.id])
                ..where(_db.exercises.id.equals(id)))
              .get())
          .isNotEmpty;

  @override
  Future<void> upsert(Exercise exercise) => _db
      .into(_db.exercises)
      .insertOnConflictUpdate(TrainingMappers.exerciseToRow(exercise));

  @override
  Future<bool> archive(String id, {required bool archived}) async {
    final changed =
        await (_db.update(
          _db.exercises,
        )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
          ExercisesCompanion(
            archived: Value(archived),
            updatedAt: Value(_clock.now().toUtc()),
          ),
        );
    return changed > 0;
  }

  @override
  Future<bool> delete(String id) async {
    final now = _clock.now().toUtc();
    final changed =
        await (_db.update(
          _db.exercises,
        )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
          ExercisesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
    return changed > 0;
  }

  static List<Exercise> _toEntities(List<ExerciseRow> rows) => [
    for (final r in rows) ?TrainingMappers.exerciseToEntity(r),
  ];
}
