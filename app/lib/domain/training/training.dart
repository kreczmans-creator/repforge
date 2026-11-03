import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/units/units.dart';

part 'training.freezed.dart';

/// Exercise types the data model must support (TRN-001).
enum ExerciseType { weighted, bodyweight, assisted, timed, distance, cardio }

/// Exertion scale recorded on a set.
enum ExertionScale { rpe, rir }

/// Exercise library entry (TRN-010..012).
@freezed
abstract class Exercise with _$Exercise {
  const factory Exercise({
    required String id,
    required String name,
    required ExerciseType type,
    required String category,
    required String primaryMuscle,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(<String>[]) List<String> secondaryMuscles,
    @Default(<String>[]) List<String> equipment,
    @Default(false) bool isCustom,
    @Default(false) bool archived,
  }) = _Exercise;
}

/// Exertion rating: RPE 1–10 or RIR 0–10, half steps.
@freezed
abstract class Exertion with _$Exertion {
  const factory Exertion({
    required ExertionScale scale,
    required double value,
  }) = _Exertion;
}

/// Data recorded for one set. Each exercise type carries only the fields valid
/// for it; the sealed hierarchy makes invalid combinations unrepresentable.
@freezed
sealed class SetData with _$SetData {
  const factory SetData.weighted({required LoadKg load, required int reps}) =
      WeightedSet;
  const factory SetData.bodyweight({required int reps, LoadKg? addedLoad}) =
      BodyweightSet;
  const factory SetData.assisted({
    required int reps,
    required LoadKg assistance,
  }) = AssistedSet;
  const factory SetData.timed({required Duration duration}) = TimedSet;
  const factory SetData.distance({required double metres, Duration? duration}) =
      DistanceSet;
  const factory SetData.cardio({
    required Duration duration,
    double? metres,
    int? averageHeartRate,
  }) = CardioSet;

  const SetData._();

  ExerciseType get type => switch (this) {
    WeightedSet() => ExerciseType.weighted,
    BodyweightSet() => ExerciseType.bodyweight,
    AssistedSet() => ExerciseType.assisted,
    TimedSet() => ExerciseType.timed,
    DistanceSet() => ExerciseType.distance,
    CardioSet() => ExerciseType.cardio,
  };
}

/// A set performed in a session (TRN-002..009).
@freezed
abstract class SessionSet with _$SessionSet {
  const factory SessionSet({
    required String id,
    required String sessionId,
    required String exerciseId,
    required int exerciseOrder,
    required int setOrder,
    required SetData data,
    required bool completed,
    Exertion? exertion,
    int? restSeconds,
    String? note,
  }) = _SessionSet;
}

/// A performed (or in-progress) workout (TRN-015..).
@freezed
abstract class WorkoutSession with _$WorkoutSession {
  const factory WorkoutSession({
    required String id,
    required String name,
    required DateTime startedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? planId,
    DateTime? endedAt,
    @Default('') String notes,
    @Default(<SessionSet>[]) List<SessionSet> sets,
  }) = _WorkoutSession;
}

/// Planned exercise in a workout plan with targets.
@freezed
abstract class PlanExercise with _$PlanExercise {
  const factory PlanExercise({
    required String id,
    required String exerciseId,
    required int sortOrder,
    required int targetSets,
    int? targetReps,
    LoadKg? targetLoad,
    Duration? targetDuration,
    int? restSeconds,
  }) = _PlanExercise;
}

/// Workout plan / template (TRN-013, TRN-014).
@freezed
abstract class WorkoutPlan with _$WorkoutPlan {
  const factory WorkoutPlan({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? split,
    @Default(<int>[]) List<int> scheduledWeekdays,
    @Default(<PlanExercise>[]) List<PlanExercise> exercises,
    @Default(false) bool archived,
  }) = _WorkoutPlan;
}
