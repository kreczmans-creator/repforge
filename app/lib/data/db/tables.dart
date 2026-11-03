import 'package:drift/drift.dart';

/// Columns every record carries (ADR-0004: sync-ready without a rewrite).
mixin SyncColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Body measurements: one row per site per reading (BCM). `site` is the
/// `MeasurementSite` enum name; `value` is kg for weight, cm otherwise.
@DataClassName('MeasurementRow')
class Measurements extends Table with SyncColumns {
  TextColumn get site => text()();
  RealColumn get value => real()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Foods (NUT-004). Nutrients per 100 of `per100Unit`, stored as the
/// `ReferenceUnit` enum name (`grams` | `millilitres`).
@DataClassName('FoodRow')
class Foods extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get per100Unit => text()();
  RealColumn get kcal => real()();
  RealColumn get proteinG => real()();
  RealColumn get carbsG => real()();
  RealColumn get fatG => real()();
  RealColumn get fibreG => real().nullable()();
  TextColumn get provenance => text()();
  TextColumn get source => text()();

  /// Lower-cased, diacritic-stripped name + brand for search.
  TextColumn get searchKey => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Named serving sizes of a food.
@DataClassName('FoodServingRow')
class FoodServings extends Table {
  TextColumn get id => text()();
  TextColumn get foodId =>
      text().references(Foods, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  RealColumn get amount => real()();
  TextColumn get unit => text()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Diary entries with a nutrient snapshot (NUT-010).
@DataClassName('FoodLogEntryRow')
class FoodLogEntries extends Table with SyncColumns {
  TextColumn get day => text()();
  TextColumn get meal => text()();
  TextColumn get name => text()();
  TextColumn get foodId => text().nullable()();
  TextColumn get recipeId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get unit => text()();
  RealColumn get kcal => real()();
  RealColumn get proteinG => real()();
  RealColumn get carbsG => real()();
  RealColumn get fatG => real()();
  RealColumn get fibreG => real().nullable()();
  TextColumn get provenance => text()();
  DateTimeColumn get loggedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Recipes (RCP). Method steps are stored as a JSON array of strings.
@DataClassName('RecipeRow')
class Recipes extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get portions => integer()();
  IntColumn get prepMinutes => integer().nullable()();
  IntColumn get cookMinutes => integer().nullable()();
  TextColumn get storage => text().nullable()();
  BoolColumn get freezerFriendly =>
      boolean().withDefault(const Constant(false))();
  TextColumn get reheating => text().nullable()();
  BoolColumn get favourite => boolean().withDefault(const Constant(false))();
  TextColumn get methodStepsJson => text()();
  RealColumn get declaredKcal => real().nullable()();
  RealColumn get declaredProteinG => real().nullable()();
  RealColumn get declaredCarbsG => real().nullable()();
  RealColumn get declaredFatG => real().nullable()();
  RealColumn get declaredFibreG => real().nullable()();
  TextColumn get nutritionNote => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Ingredient lines with an optional per-100 nutrient snapshot. The snapshot
/// is always per 100 of the line's own `unit`; a food measured in a different
/// reference unit is not calculable for that line (domain rule) and is stored
/// without a snapshot.
@DataClassName('RecipeIngredientRow')
class RecipeIngredients extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId =>
      text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get foodId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get unit => text()();
  IntColumn get sortOrder => integer()();
  TextColumn get note => text().nullable()();
  RealColumn get kcal => real().nullable()();
  RealColumn get proteinG => real().nullable()();
  RealColumn get carbsG => real().nullable()();
  RealColumn get fatG => real().nullable()();
  RealColumn get fibreG => real().nullable()();
  TextColumn get provenance => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Exercise library (TRN-010..012). Lists stored as JSON arrays.
@DataClassName('ExerciseRow')
class Exercises extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get category => text()();
  TextColumn get primaryMuscle => text()();
  TextColumn get secondaryMusclesJson => text()();
  TextColumn get equipmentJson => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('WorkoutPlanRow')
class WorkoutPlans extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get split => text().nullable()();
  TextColumn get scheduledWeekdaysJson => text()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PlanExerciseRow')
class PlanExercises extends Table {
  TextColumn get id => text()();
  TextColumn get planId =>
      text().references(WorkoutPlans, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text()();
  IntColumn get sortOrder => integer()();
  IntColumn get targetSets => integer()();
  IntColumn get targetReps => integer().nullable()();
  RealColumn get targetLoadKg => real().nullable()();
  IntColumn get targetDurationSec => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('WorkoutSessionRow')
class WorkoutSessions extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get planId => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One performed set. `type` selects which nullable columns are meaningful
/// (the domain `SetData` sealed class enforces the combinations).
@DataClassName('SessionSetRow')
class SessionSets extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text()();
  IntColumn get exerciseOrder => integer()();
  IntColumn get setOrder => integer()();
  TextColumn get type => text()();
  RealColumn get loadKg => real().nullable()();
  IntColumn get reps => integer().nullable()();
  RealColumn get assistanceKg => real().nullable()();
  IntColumn get durationSec => integer().nullable()();
  RealColumn get metres => real().nullable()();
  IntColumn get averageHeartRate => integer().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(true))();
  TextColumn get exertionScale => text().nullable()();
  RealColumn get exertionValue => real().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GoalRow')
class Goals extends Table with SyncColumns {
  TextColumn get kind => text()();
  TextColumn get site => text().nullable()();
  RealColumn get target => real()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Key/value settings; one row per key, values stored as text.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
