import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// The name of a goal group for headings: "Body weight", "Waist".
String goalGroupLabel(GoalKind kind, MeasurementSite? site) => switch (kind) {
  GoalKind.calories => 'Calories',
  GoalKind.protein => 'Protein',
  GoalKind.carbs => 'Carbohydrate',
  GoalKind.fat => 'Fat',
  GoalKind.fibre => 'Fibre',
  GoalKind.bodyWeight => 'Body weight',
  GoalKind.measurement => site?.label ?? 'Measurement',
  GoalKind.sessionsPerWeek => 'Sessions per week',
};

/// The unit of a goal's target value.
String goalUnit(GoalKind kind, MeasurementSite? site) => switch (kind) {
  GoalKind.calories => 'kcal',
  GoalKind.protein || GoalKind.carbs || GoalKind.fat || GoalKind.fibre => 'g',
  GoalKind.bodyWeight => 'kg',
  GoalKind.measurement => site?.unit ?? 'cm',
  GoalKind.sessionsPerWeek => 'sessions',
};
