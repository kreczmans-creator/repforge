import 'package:repforge/domain/training/training.dart';

/// The single place that turns the training enums into display text. Labels
/// follow `docs/training-taxonomy.md`; the identifiers stay the enum names.
String exerciseTypeLabel(ExerciseType t) => switch (t) {
  ExerciseType.weighted => 'Weighted',
  ExerciseType.bodyweight => 'Bodyweight',
  ExerciseType.assisted => 'Assisted',
  ExerciseType.timed => 'Timed',
  ExerciseType.distance => 'Distance',
  ExerciseType.cardio => 'Cardio',
};

/// What the type records, shown in the editor.
String exerciseTypeHint(ExerciseType t) => switch (t) {
  ExerciseType.weighted => 'Load and reps',
  ExerciseType.bodyweight => 'Reps, with optional added load',
  ExerciseType.assisted => 'Reps and assistance',
  ExerciseType.timed => 'Duration, with optional added load',
  ExerciseType.distance => 'Distance, with optional duration',
  ExerciseType.cardio => 'Duration, with optional distance and heart rate',
};

String exerciseCategoryLabel(ExerciseCategory c) => switch (c) {
  ExerciseCategory.push => 'Push',
  ExerciseCategory.pull => 'Pull',
  ExerciseCategory.legs => 'Legs',
  ExerciseCategory.core => 'Core',
  ExerciseCategory.fullBody => 'Full body',
  ExerciseCategory.cardio => 'Cardio',
  ExerciseCategory.mobility => 'Mobility',
};

String muscleGroupLabel(MuscleGroup m) => switch (m) {
  MuscleGroup.chest => 'Chest',
  MuscleGroup.frontDelts => 'Front delts',
  MuscleGroup.sideDelts => 'Side delts',
  MuscleGroup.rearDelts => 'Rear delts',
  MuscleGroup.triceps => 'Triceps',
  MuscleGroup.biceps => 'Biceps',
  MuscleGroup.forearms => 'Forearms',
  MuscleGroup.upperBack => 'Upper back (traps, rhomboids)',
  MuscleGroup.lats => 'Lats',
  MuscleGroup.lowerBack => 'Lower back',
  MuscleGroup.abs => 'Abs',
  MuscleGroup.obliques => 'Obliques',
  MuscleGroup.glutes => 'Glutes',
  MuscleGroup.quadriceps => 'Quadriceps',
  MuscleGroup.hamstrings => 'Hamstrings',
  MuscleGroup.adductors => 'Adductors',
  MuscleGroup.abductors => 'Abductors',
  MuscleGroup.calves => 'Calves',
  MuscleGroup.fullBody => 'Full body (cardio and conditioning)',
};

String equipmentLabel(Equipment e) => switch (e) {
  Equipment.barbell => 'Barbell',
  Equipment.ezBar => 'EZ bar',
  Equipment.trapBar => 'Trap bar',
  Equipment.dumbbell => 'Dumbbells',
  Equipment.kettlebell => 'Kettlebell',
  Equipment.cable => 'Cable station',
  Equipment.machine => 'Machine (selectorised or plate-loaded)',
  Equipment.smithMachine => 'Smith machine',
  Equipment.bench => 'Bench',
  Equipment.squatRack => 'Squat rack',
  Equipment.pullUpBar => 'Pull-up bar',
  Equipment.dipBars => 'Dip bars',
  Equipment.resistanceBand => 'Resistance band',
  Equipment.plate => 'Weight plate',
  Equipment.medicineBall => 'Medicine ball',
  Equipment.rings => 'Gymnastic rings',
  Equipment.treadmill => 'Treadmill',
  Equipment.bike => 'Exercise bike',
  Equipment.rower => 'Rowing machine',
  Equipment.elliptical => 'Cross-trainer',
  Equipment.skippingRope => 'Skipping rope',
};

/// Equipment as a list label; none means bodyweight only (TRN-011(1)).
String equipmentSummary(Iterable<Equipment> equipment) => equipment.isEmpty
    ? 'Bodyweight only'
    : equipment.map(equipmentLabel).join(', ');
