import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/training/training_validation.dart';

/// Use case: create or edit a workout plan (TRN-013).
///
/// Validates the name, every plan exercise ([validatePlanExercise], with the
/// exercise's type so a rep target on a timed exercise is rejected), that
/// each referenced exercise exists, and the weekday numbers (1 Monday to 7
/// Sunday, no repeats). The order of [exercises] is the plan order:
/// `sortOrder` is renumbered 0..n-1 and a blank id gets a new one.
final class SavePlan {
  const SavePlan({
    required this.plans,
    required this.exercises,
    required this.clock,
    required this.newId,
  });

  final WorkoutPlanRepository plans;
  final ExerciseRepository exercises;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<WorkoutPlan>> call({
    required String name,
    required List<PlanExercise> planExercises,
    String? id,
    String? split,
    List<int> scheduledWeekdays = const [],
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > maxTrainingNameLength) {
      return const Err(
        ValidationError('Enter a name of 1 to 100 characters.', field: 'name'),
      );
    }
    if (scheduledWeekdays.any((d) => d < 1 || d > 7) ||
        scheduledWeekdays.toSet().length != scheduledWeekdays.length) {
      return const Err(
        ValidationError(
          'Weekdays are 1 (Monday) to 7 (Sunday), each once.',
          field: 'scheduledWeekdays',
        ),
      );
    }
    try {
      final existing = id == null ? null : await plans.byId(id);
      if (id != null && existing == null) {
        return const Err(NotFoundError('That plan no longer exists.'));
      }
      final out = <PlanExercise>[];
      for (var i = 0; i < planExercises.length; i++) {
        final pe = planExercises[i];
        final exercise = await exercises.byId(pe.exerciseId);
        if (exercise == null) {
          return const Err(
            NotFoundError('An exercise in the plan no longer exists.'),
          );
        }
        final checked = validatePlanExercise(
          pe.copyWith(sortOrder: i, id: pe.id.isEmpty ? newId() : pe.id),
          type: exercise.type,
        );
        switch (checked) {
          case Err(:final error):
            return Err(error);
          case Ok(:final value):
            out.add(value);
        }
      }
      final now = clock.now().toUtc();
      final plan = WorkoutPlan(
        id: existing?.id ?? newId(),
        name: trimmed,
        split: split,
        scheduledWeekdays: [...scheduledWeekdays]..sort(),
        exercises: out,
        archived: existing?.archived ?? false,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await plans.upsert(plan);
      return Ok(plan);
    } on Object catch (e) {
      return Err(StorageError('Could not save the plan.', cause: e));
    }
  }
}

/// Use case: create or edit a training split (TRN-014).
///
/// `days` is the cycle in order, one entry per day: a workout plan id, or
/// null for a rest day. Validated by `validateSplit`; each plan id must name
/// an existing plan. A new split goes to the end of the list.
final class SaveSplit {
  const SaveSplit({
    required this.splits,
    required this.plans,
    required this.clock,
    required this.newId,
  });

  final TrainingSplitRepository splits;
  final WorkoutPlanRepository plans;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<TrainingSplit>> call({
    required String name,
    required List<String?> days,
    String? id,
  }) async {
    try {
      final existing = id == null ? null : await splits.byId(id);
      if (id != null && existing == null) {
        return const Err(NotFoundError('That split no longer exists.'));
      }
      final now = clock.now().toUtc();
      var sortOrder = existing?.sortOrder ?? 0;
      if (existing == null) {
        final all = await splits.watchAll().first;
        sortOrder = all.isEmpty
            ? 0
            : all.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      }
      final draft = TrainingSplit(
        id: existing?.id ?? newId(),
        name: name,
        days: [for (final d in days) SplitDay(planId: d)],
        sortOrder: sortOrder,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      final checked = validateSplit(draft);
      if (checked case Err(:final error)) return Err(error);
      for (final planId in days.whereType<String>().toSet()) {
        if (await plans.byId(planId) == null) {
          return const Err(
            NotFoundError('A workout in the cycle no longer exists.'),
          );
        }
      }
      final value = (checked as Ok<TrainingSplit>).value;
      await splits.upsert(value);
      return Ok(value);
    } on Object catch (e) {
      return Err(StorageError('Could not save the split.', cause: e));
    }
  }
}
