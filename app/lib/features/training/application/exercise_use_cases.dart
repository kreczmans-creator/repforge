import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/training/training_validation.dart';

/// Use case: create or edit a custom exercise (TRN-012(1)).
///
/// A name, type, category and primary muscle group are required. Editing is
/// only for exercises the user owns: a supplied exercise is never changed
/// (use [CopySuppliedExercise], TRN-008(2)). The type of an exercise that
/// already has recorded sets cannot change, because those sets would no
/// longer match it.
final class SaveCustomExercise {
  const SaveCustomExercise({
    required this.exercises,
    required this.sessions,
    required this.clock,
    required this.newId,
  });

  final ExerciseRepository exercises;
  final WorkoutSessionRepository sessions;
  final Clock clock;
  final IdGenerator newId;

  /// Creates a custom exercise, or edits the one with [id].
  Future<Result<Exercise>> call({
    required String name,
    required ExerciseType? type,
    required ExerciseCategory? category,
    required MuscleGroup? primaryMuscle,
    String? id,
    List<MuscleGroup> secondaryMuscles = const [],
    List<Equipment> equipment = const [],
    List<String> aliases = const [],
  }) async {
    if (type == null) {
      return const Err(ValidationError('Choose a type.', field: 'type'));
    }
    if (category == null) {
      return const Err(
        ValidationError('Choose a category.', field: 'category'),
      );
    }
    if (primaryMuscle == null) {
      return const Err(
        ValidationError('Choose a primary muscle group.', field: 'primary'),
      );
    }
    try {
      final now = clock.now().toUtc();
      final existing = id == null ? null : await exercises.byId(id);
      if (id != null && existing == null) {
        return const Err(NotFoundError('That exercise no longer exists.'));
      }
      if (existing != null) {
        if (existing.supplied) {
          return const Err(
            ValidationError(
              'A supplied exercise cannot be edited; make a copy.',
              field: 'id',
            ),
          );
        }
        if (existing.type != type && await sessions.hasHistory(existing.id)) {
          return const Err(
            ValidationError(
              'The type cannot change once sets have been recorded.',
              field: 'type',
            ),
          );
        }
      }
      final draft = Exercise(
        id: existing?.id ?? newId(),
        name: name,
        type: type,
        category: category,
        primaryMuscle: primaryMuscle,
        secondaryMuscles: secondaryMuscles,
        equipment: equipment,
        aliases: aliases,
        copiedFromId: existing?.copiedFromId,
        archived: existing?.archived ?? false,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      final checked = validateExercise(draft);
      if (checked case Ok(:final value)) {
        await exercises.upsert(value);
      }
      return checked;
    } on Object catch (e) {
      return Err(StorageError('Could not save the exercise.', cause: e));
    }
  }
}

/// Use case: "edit" a supplied exercise (TRN-008(2)). The supplied exercise
/// stays exactly as it is; a new custom exercise is created from the edited
/// values with `copiedFromId` pointing at the original.
final class CopySuppliedExercise {
  const CopySuppliedExercise({
    required this.exercises,
    required this.clock,
    required this.newId,
  });

  final ExerciseRepository exercises;
  final Clock clock;
  final IdGenerator newId;

  /// Creates the custom copy of [sourceId] with the given edited values.
  /// Any value left null keeps the original's.
  Future<Result<Exercise>> call({
    required String sourceId,
    String? name,
    ExerciseType? type,
    ExerciseCategory? category,
    MuscleGroup? primaryMuscle,
    List<MuscleGroup>? secondaryMuscles,
    List<Equipment>? equipment,
    List<String>? aliases,
  }) async {
    try {
      final source = await exercises.byId(sourceId);
      if (source == null) {
        return const Err(NotFoundError('That exercise no longer exists.'));
      }
      if (!source.supplied) {
        return const Err(
          ValidationError(
            'Only a supplied exercise is copied; edit your own directly.',
            field: 'id',
          ),
        );
      }
      final now = clock.now().toUtc();
      final draft = Exercise(
        id: newId(),
        name: name ?? source.name,
        type: type ?? source.type,
        category: category ?? source.category,
        primaryMuscle: primaryMuscle ?? source.primaryMuscle,
        secondaryMuscles: secondaryMuscles ?? source.secondaryMuscles,
        equipment: equipment ?? source.equipment,
        aliases: aliases ?? source.aliases,
        copiedFromId: source.id,
        createdAt: now,
        updatedAt: now,
      );
      final checked = validateExercise(draft);
      if (checked case Ok(:final value)) {
        await exercises.upsert(value);
      }
      return checked;
    } on Object catch (e) {
      return Err(StorageError('Could not copy the exercise.', cause: e));
    }
  }
}

/// Use case: archive (or restore) an exercise (TRN-012(2)). An archived
/// exercise is hidden from pickers but its history stays (TD-23: the
/// repository only touches a row that is not deleted).
final class ArchiveExercise {
  const ArchiveExercise({required this.exercises});

  final ExerciseRepository exercises;

  Future<Result<void>> call(String id, {bool archived = true}) async {
    try {
      final changed = await exercises.archive(id, archived: archived);
      return changed
          ? const Ok(null)
          : const Err(NotFoundError('That exercise no longer exists.'));
    } on Object catch (e) {
      return Err(StorageError('Could not update the exercise.', cause: e));
    }
  }
}
