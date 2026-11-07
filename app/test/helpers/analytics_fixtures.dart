import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

/// Small builders for the analytics tests. Times are LOCAL wall-clock times
/// so expectations hold in every time zone.
int _seq = 0;

FoodLogEntry foodEntry(
  String day,
  double kcal, {
  double? protein = 10,
  DataProvenance provenance = DataProvenance.verified,
}) {
  final t = DateTime.utc(2026, 11);
  return FoodLogEntry(
    id: 'fe${_seq++}',
    day: day,
    meal: MealSlot.lunch,
    name: 'item',
    quantity: Quantity.fromStored(100, ReferenceUnit.grams),
    nutrients: NutrientAmounts(
      kcal: kcal,
      proteinG: protein,
      carbsG: 20,
      fatG: 5,
      fibreG: 2,
    ),
    provenance: provenance,
    loggedAt: t,
    createdAt: t,
    updatedAt: t,
  );
}

Measurement reading(MeasurementSite site, double v, int month, int day) {
  final at = DateTime(2026, month, day, 12);
  return Measurement(
    id: 'rd${_seq++}',
    site: site,
    value: site.isWeight
        ? MeasurementValue.kg(Kilograms.fromStored(v))
        : MeasurementValue.cm(Centimetres.fromStored(v)),
    recordedAt: at.toUtc(),
    createdAt: at.toUtc(),
    updatedAt: at.toUtc(),
  );
}

Measurement weightReading(double v, int month, int day) =>
    reading(MeasurementSite.weight, v, month, day);

SetData weighted(double kg, int reps) =>
    SetData.weighted(load: LoadKg.fromStored(kg), reps: reps);

SessionSet workingSet(
  String sessionId,
  SetData data, {
  String exercise = 'bench',
}) => SessionSet(
  id: 'st${_seq++}',
  sessionId: sessionId,
  exerciseId: exercise,
  exerciseOrder: 0,
  setOrder: _seq,
  data: data,
  completed: true,
);

WorkoutSession workout(
  DateTime start,
  List<SetData> sets, {
  bool ended = true,
  String exercise = 'bench',
}) {
  final id = 'ws${_seq++}';
  return WorkoutSession(
    id: id,
    name: 'Session',
    startedAt: start.toUtc(),
    endedAt: ended ? start.add(const Duration(hours: 1)).toUtc() : null,
    createdAt: start.toUtc(),
    updatedAt: start.toUtc(),
    sets: [for (final d in sets) workingSet(id, d, exercise: exercise)],
  );
}

ExerciseSessionHistory exerciseHistory(DateTime start, List<SetData> sets) {
  final id = 'eh${_seq++}';
  return ExerciseSessionHistory(
    sessionId: id,
    sessionName: 'S',
    startedAt: start.toUtc(),
    sets: [for (final d in sets) workingSet(id, d)],
  );
}
