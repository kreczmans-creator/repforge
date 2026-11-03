import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/training_mappers.dart';
import 'package:repforge/domain/core/clock.dart';
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
  Future<Exercise?> byId(String id) async {
    final row = await (_db.select(
      _db.exercises,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : TrainingMappers.exerciseToEntity(row);
  }

  @override
  Future<void> upsert(Exercise exercise) => _db
      .into(_db.exercises)
      .insertOnConflictUpdate(TrainingMappers.exerciseToRow(exercise));

  @override
  Future<void> archive(String id, {required bool archived}) async {
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(
        archived: Value(archived),
        updatedAt: Value(_clock.now().toUtc()),
      ),
    );
  }

  static List<Exercise> _toEntities(List<ExerciseRow> rows) => [
    for (final r in rows) ?TrainingMappers.exerciseToEntity(r),
  ];
}
