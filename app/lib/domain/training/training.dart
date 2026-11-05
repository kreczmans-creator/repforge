import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/core/search_key.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show DataProvenance;
import 'package:repforge/domain/units/units.dart';

part 'training.freezed.dart';

/// Exercise types the data model must support (TRN-001).
enum ExerciseType { weighted, bodyweight, assisted, timed, distance, cardio }

/// Exertion scale recorded on a set.
enum ExertionScale { rpe, rir }

/// Exercise category (TRN-009), exactly one per exercise. The identifiers are
/// the enum names and are normative (`docs/training-taxonomy.md`); labels are
/// display text.
enum ExerciseCategory { push, pull, legs, core, fullBody, cardio, mobility }

/// Muscle group (TRN-010): one primary and any number of secondary groups per
/// exercise. Normative list in `docs/training-taxonomy.md`.
enum MuscleGroup {
  chest,
  frontDelts,
  sideDelts,
  rearDelts,
  triceps,
  biceps,
  forearms,
  upperBack,
  lats,
  lowerBack,
  abs,
  obliques,
  glutes,
  quadriceps,
  hamstrings,
  adductors,
  abductors,
  calves,
  fullBody,
}

/// Equipment an exercise requires (TRN-011). An exercise with no equipment is
/// bodyweight only. Normative list in `docs/training-taxonomy.md`.
enum Equipment {
  barbell,
  ezBar,
  trapBar,
  dumbbell,
  kettlebell,
  cable,
  machine,
  smithMachine,
  bench,
  squatRack,
  pullUpBar,
  dipBars,
  resistanceBand,
  plate,
  medicineBall,
  rings,
  treadmill,
  bike,
  rower,
  elliptical,
  skippingRope,
}

/// Exercise library entry (TRN-008..012).
///
/// [supplied] is the one provenance concept: true for an exercise that ships
/// in the bundled library (read-only, TRN-008(2)), false for one the user
/// created or copied. It replaces the WP 3 `isCustom` flag; [isCustom] is its
/// negation and is kept only as a readable accessor, never stored.
@freezed
abstract class Exercise with _$Exercise {
  const factory Exercise({
    required String id,
    required String name,
    required ExerciseType type,
    required ExerciseCategory category,
    required MuscleGroup primaryMuscle,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(<MuscleGroup>[]) List<MuscleGroup> secondaryMuscles,
    @Default(<Equipment>[]) List<Equipment> equipment,

    /// Alternative names the search also matches (TRN-008(3)).
    @Default(<String>[]) List<String> aliases,
    @Default(false) bool supplied,

    /// For a custom copy of a supplied exercise (TRN-008(2)): the id of the
    /// supplied original. Null otherwise.
    String? copiedFromId,
    @Default(false) bool archived,
  }) = _Exercise;

  const Exercise._();

  /// True for exercises the user owns (not supplied).
  bool get isCustom => !supplied;

  /// Normalised text the library search matches against: name and aliases,
  /// lower-cased with diacritics folded (TRN-008(3)).
  String get searchKey => exerciseSearchKey(name, aliases);
}

/// Search key for an exercise: [name] and [aliases], space separated,
/// lower-cased with diacritics folded.
String exerciseSearchKey(String name, Iterable<String> aliases) =>
    normaliseSearchKey([name, ...aliases].join(' '));

/// Exertion rating: RPE 1–10 in steps of 0.5, or RIR 0–5 in whole numbers.
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

  /// Timed set (TRN-005): duration plus an optional added load (stored in
  /// the same `load_kg` column as a bodyweight set's added load).
  const factory SetData.timed({required Duration duration, LoadKg? addedLoad}) =
      TimedSet;
  const factory SetData.distance({required double metres, Duration? duration}) =
      DistanceSet;

  /// Cardio entry (TRN-007). [energyKcal], when given, must carry an
  /// [energyProvenance] of `userEntered` or `estimated`; it is a training
  /// record only and is never read by nutrition code or added to the energy
  /// balance (TRN-007(2)).
  const factory SetData.cardio({
    required Duration duration,
    double? metres,
    int? averageHeartRate,
    double? energyKcal,
    DataProvenance? energyProvenance,
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

/// Planned exercise in a workout plan with targets (TRN-013). Reps are a
/// range ([repsMin] to [repsMax], equal for a fixed target); a timed or
/// distance exercise uses [targetDuration] or [targetMetres] instead.
@freezed
abstract class PlanExercise with _$PlanExercise {
  const factory PlanExercise({
    required String id,
    required String exerciseId,
    required int sortOrder,
    required int targetSets,
    int? repsMin,
    int? repsMax,
    Duration? targetDuration,
    double? targetMetres,
    LoadKg? targetLoad,
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

/// One day of a split's repeating cycle (TRN-014): a workout plan, or a rest
/// day when [planId] is null.
@freezed
abstract class SplitDay with _$SplitDay {
  const factory SplitDay({String? planId}) = _SplitDay;
  const SplitDay._();

  bool get isRest => planId == null;
}

/// Training split (TRN-014): named workouts arranged over a repeating cycle
/// of 1 to 14 days, rest days included. The cycle length is the number of
/// [days].
@freezed
abstract class TrainingSplit with _$TrainingSplit {
  const factory TrainingSplit({
    required String id,
    required String name,
    required List<SplitDay> days,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(0) int sortOrder,
  }) = _TrainingSplit;
  const TrainingSplit._();

  int get cycleDays => days.length;
}
