import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/training/training_validation.dart';
import 'package:repforge/features/training/application/plan_use_cases.dart';

/// Suffix a duplicated plan's name gets.
const planCopySuffix = ' (copy)';

/// Use case: duplicate a workout plan (WP 17 G5a). The copy has a new id, the
/// name with " (copy)" appended (the original name is shortened if the result
/// would pass the name limit), the same exercises and prescriptions under new
/// plan-exercise ids, is not archived and has no scheduled weekdays. The
/// original is not changed. An archived exercise is kept (TD-42: it can still
/// be copied); an exercise that has been removed is dropped, and a plan with
/// nothing left is refused.
final class DuplicatePlan {
  const DuplicatePlan({
    required this.plans,
    required this.exercises,
    required this.clock,
    required this.newId,
  });

  final WorkoutPlanRepository plans;
  final ExerciseRepository exercises;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<WorkoutPlan>> call(String planId) async {
    try {
      final source = await plans.byId(planId);
      if (source == null) {
        return const Err(NotFoundError('That workout no longer exists.'));
      }
      final ordered = List.of(source.exercises)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final kept = <PlanExercise>[];
      for (final e in ordered) {
        if (await exercises.byId(e.exerciseId) != null) kept.add(e);
      }
      if (kept.isEmpty) {
        return const Err(
          ValidationError(
            'Nothing to copy: every exercise in the plan has been removed.',
            field: 'exercises',
          ),
        );
      }
      const room = maxTrainingNameLength - planCopySuffix.length;
      final base = source.name.length > room
          ? source.name.substring(0, room).trimRight()
          : source.name;
      final now = clock.now().toUtc();
      final copy = WorkoutPlan(
        id: newId(),
        name: '$base$planCopySuffix',
        split: source.split,
        exercises: [
          for (final (i, e) in kept.indexed)
            e.copyWith(id: newId(), sortOrder: i),
        ],
        createdAt: now,
        updatedAt: now,
      );
      await plans.upsert(copy);
      return Ok(copy);
    } on Object catch (e) {
      return Err(StorageError('Could not duplicate the workout.', cause: e));
    }
  }
}

/// Use case: delete a workout plan (WP 17 G5b). Only the plan definition is
/// removed (soft delete in the repository). Sessions and scheduled workouts
/// keep their loose `planId`; nothing performed changes (TRN-013, TRN-024).
final class DeletePlan {
  const DeletePlan({required this.plans});

  final WorkoutPlanRepository plans;

  Future<Result<void>> call(String planId) async {
    try {
      if (await plans.byId(planId) == null) {
        return const Err(NotFoundError('That workout no longer exists.'));
      }
      await plans.delete(planId);
      return const Ok(null);
    } on Object catch (e) {
      return Err(StorageError('Could not delete the workout.', cause: e));
    }
  }
}

/// Use case: make a plan from a performed session (WP 17 G5c).
///
/// One plan exercise per session entry, in entry order. Entries without sets
/// are skipped; a session with no sets at all is refused. Per entry the
/// prescription comes from the sets that represent the working prescription:
/// sets that are `completed` and whose `kind` is not `SetKind.warmUp`
/// (working and failure sets); if an entry has no such set, all of its sets
/// are used instead. Only the chosen sets count below. `targetSets` is the
/// number of chosen sets (1 to 20); rep sets give `repsMin` and
/// `repsMax` as the lowest and highest performed reps; timed sets give
/// `targetDuration` as the longest duration; distance sets give
/// `targetMetres` as the greatest distance; cardio sets give both when
/// recorded; `restSeconds` is the most common recorded rest (the earliest
/// wins a tie). Loads are not carried over. An entry whose exercise is
/// archived or removed is left out, as when starting a workout from a plan,
/// and its name is reported in [SaveSessionAsPlanOutcome.skippedNames]; the
/// save is refused only when no entry remains. The plan is stored through
/// [SavePlan], so it is validated like any other plan.
final class SaveSessionAsPlan {
  const SaveSessionAsPlan({
    required this.sessions,
    required this.exercises,
    required this.savePlan,
  });

  final WorkoutSessionRepository sessions;
  final ExerciseRepository exercises;
  final SavePlan savePlan;

  Future<Result<SaveSessionAsPlanOutcome>> call(
    String sessionId, {
    String? name,
  }) async {
    final WorkoutSession? session;
    try {
      session = await sessions.byId(sessionId);
    } on Object catch (e) {
      return Err(StorageError('Could not read the workout.', cause: e));
    }
    if (session == null) {
      return const Err(NotFoundError('That workout no longer exists.'));
    }
    final planExercises = <PlanExercise>[];
    final skipped = <String>[];
    for (final entry in session.exercises) {
      final sets = [
        for (final s in session.sets)
          if (s.sessionExerciseId == entry.id) s,
      ]..sort((a, b) => a.setOrder.compareTo(b.setOrder));
      if (sets.isEmpty) continue;
      final Exercise? exercise;
      try {
        exercise = await exercises.byId(entry.exerciseId);
      } on Object catch (e) {
        return Err(StorageError('Could not read the exercises.', cause: e));
      }
      if (exercise == null || exercise.archived) {
        final name = exercise?.name ?? 'Removed exercise';
        if (!skipped.contains(name)) skipped.add(name);
        continue;
      }
      final working = [
        for (final s in sets)
          if (s.completed && s.kind != SetKind.warmUp) s,
      ];
      planExercises.add(_prescribe(entry, working.isEmpty ? sets : working));
    }
    if (planExercises.isEmpty) {
      return Err(
        ValidationError(
          skipped.isEmpty
              ? 'This workout has no sets to make a plan from.'
              : 'Every exercise in this workout is archived or removed.',
          field: 'sets',
        ),
      );
    }
    final saved = await savePlan(
      name: name ?? session.name,
      planExercises: planExercises,
    );
    return switch (saved) {
      Ok(:final value) => Ok(
        SaveSessionAsPlanOutcome(plan: value, skippedNames: skipped),
      ),
      Err(:final error) => Err(error),
    };
  }

  PlanExercise _prescribe(SessionExercise entry, List<SessionSet> sets) {
    final reps = <int>[];
    final durations = <Duration>[];
    final metres = <double>[];
    for (final s in sets) {
      switch (s.data) {
        case WeightedSet(reps: final r):
        case BodyweightSet(reps: final r):
        case AssistedSet(reps: final r):
          reps.add(r);
        case TimedSet(:final duration):
          durations.add(duration);
        case DistanceSet(metres: final m):
          metres.add(m);
        case CardioSet(:final duration, metres: final m):
          durations.add(duration);
          if (m != null) metres.add(m);
      }
    }
    final rests = <int, int>{};
    for (final s in sets) {
      final r = s.restSeconds;
      if (r != null) rests[r] = (rests[r] ?? 0) + 1;
    }
    int? rest;
    var best = 0;
    for (final e in rests.entries) {
      if (e.value > best) {
        best = e.value;
        rest = e.key;
      }
    }
    return PlanExercise(
      id: '',
      exerciseId: entry.exerciseId,
      sortOrder: 0,
      targetSets: sets.length.clamp(1, 20),
      repsMin: reps.isEmpty ? null : reps.reduce((a, b) => a < b ? a : b),
      repsMax: reps.isEmpty ? null : reps.reduce((a, b) => a > b ? a : b),
      targetDuration: durations.isEmpty
          ? null
          : durations.reduce((a, b) => a > b ? a : b),
      targetMetres: metres.isEmpty
          ? null
          : metres.reduce((a, b) => a > b ? a : b),
      restSeconds: rest,
    );
  }
}

/// What [SaveSessionAsPlan] made: the stored plan and the names of the
/// exercises left out because they are archived or removed.
final class SaveSessionAsPlanOutcome {
  const SaveSessionAsPlanOutcome({
    required this.plan,
    this.skippedNames = const [],
  });

  final WorkoutPlan plan;
  final List<String> skippedNames;
}
