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
@TableIndex(
  name: 'idx_measurements_site_recorded',
  columns: {#site, #recordedAt},
)
class Measurements extends Table with SyncColumns {
  TextColumn get site => text()();
  RealColumn get value => real()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Foods (NUT-004). Nutrients per 100 of `per100Unit`, stored as the
/// `ReferenceUnit` enum name (`grams` | `millilitres`). Protein, carbs, fat
/// and fibre are null when unknown (schema v4); unknown is never stored as 0.
@DataClassName('FoodRow')
@TableIndex(name: 'idx_foods_barcode', columns: {#barcode})
@TableIndex(name: 'idx_foods_search_key', columns: {#searchKey})
class Foods extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get per100Unit => text()();
  RealColumn get kcal => real()();
  RealColumn get proteinG => real().nullable()();
  RealColumn get carbsG => real().nullable()();
  RealColumn get fatG => real().nullable()();
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
@TableIndex(name: 'idx_food_servings_food', columns: {#foodId})
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

/// Diary entries with a nutrient snapshot (NUT-010). Protein, carbs, fat and
/// fibre are null when unknown (schema v4); unknown is never stored as 0.
@DataClassName('FoodLogEntryRow')
@TableIndex(name: 'idx_food_log_day', columns: {#day})
class FoodLogEntries extends Table with SyncColumns {
  TextColumn get day => text()();
  TextColumn get meal => text()();
  TextColumn get name => text()();
  TextColumn get foodId => text().nullable()();
  TextColumn get recipeId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get unit => text()();
  RealColumn get kcal => real()();
  RealColumn get proteinG => real().nullable()();
  RealColumn get carbsG => real().nullable()();
  RealColumn get fatG => real().nullable()();
  RealColumn get fibreG => real().nullable()();
  TextColumn get provenance => text()();
  DateTimeColumn get loggedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Saved meals (NUT-013): a named set of items re-logged in one action.
@DataClassName('SavedMealRow')
class SavedMeals extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get defaultMeal => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Items of a saved meal with a nutrient snapshot FOR THE STORED AMOUNT (not
/// per 100). Protein, carbs, fat and fibre are null when unknown (schema v4);
/// unknown is never stored as 0.
@DataClassName('SavedMealItemRow')
@TableIndex(name: 'idx_saved_meal_items_meal', columns: {#savedMealId})
class SavedMealItems extends Table {
  TextColumn get id => text()();
  TextColumn get savedMealId =>
      text().references(SavedMeals, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get foodId => text().nullable()();
  TextColumn get recipeId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get unit => text()();
  IntColumn get sortOrder => integer()();
  RealColumn get kcal => real()();
  RealColumn get proteinG => real().nullable()();
  RealColumn get carbsG => real().nullable()();
  RealColumn get fatG => real().nullable()();
  RealColumn get fibreG => real().nullable()();
  TextColumn get provenance => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Recipes (RCP). Step lists and ingredient notes are JSON arrays of
/// strings. Schema v5: `portions` is a real number (weight-derived portion
/// counts are fractional), preparation and cooking steps are separate lists
/// (`method_steps_json` became `cook_steps_json`), `freezing` replaces the
/// boolean `freezer_friendly`, and total and portion weight are stored.
@DataClassName('RecipeRow')
class Recipes extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get portions => real()();
  IntColumn get prepMinutes => integer().nullable()();
  IntColumn get cookMinutes => integer().nullable()();
  TextColumn get storage => text().nullable()();

  /// `FreezingSuitability` enum name: yes | no | unknown (default).
  TextColumn get freezing => text().withDefault(const Constant('unknown'))();
  TextColumn get reheating => text().nullable()();
  BoolColumn get favourite => boolean().withDefault(const Constant(false))();
  TextColumn get prepStepsJson => text().withDefault(const Constant('[]'))();
  TextColumn get cookStepsJson => text().withDefault(const Constant('[]'))();
  RealColumn get totalWeightG => real().nullable()();
  RealColumn get portionWeightG => real().nullable()();
  RealColumn get declaredKcal => real().nullable()();
  RealColumn get declaredProteinG => real().nullable()();
  RealColumn get declaredCarbsG => real().nullable()();
  RealColumn get declaredFatG => real().nullable()();
  RealColumn get declaredFibreG => real().nullable()();
  TextColumn get nutritionNote => text().nullable()();
  TextColumn get ingredientNotesJson =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Ingredient lines with an optional per-100 nutrient snapshot. The snapshot
/// is always per 100 of the line's own `unit`; a food measured in a different
/// reference unit is not calculable for that line (domain rule) and is stored
/// without a snapshot. `amount` and `unit` are the canonical g or ml quantity;
/// `serving_label` and `serving_count` (schema v5) only record how it was
/// entered.
@DataClassName('RecipeIngredientRow')
@TableIndex(name: 'idx_recipe_ingredients_recipe', columns: {#recipeId})
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
  TextColumn get servingLabel => text().nullable()();
  RealColumn get servingCount => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Alternative foods for a recipe ingredient (RCP-010, schema v5). Nutrients
/// are per 100 of `unit`, the unit of `amount`.
@DataClassName('RecipeSubstituteRow')
@TableIndex(
  name: 'idx_recipe_substitutes_ingredient',
  columns: {#recipeIngredientId},
)
class RecipeSubstitutes extends Table {
  TextColumn get id => text()();
  TextColumn get recipeIngredientId =>
      text().references(RecipeIngredients, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer()();
  TextColumn get name => text()();
  TextColumn get foodId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get unit => text()();
  RealColumn get kcal => real()();
  RealColumn get proteinG => real().nullable()();
  RealColumn get carbsG => real().nullable()();
  RealColumn get fatG => real().nullable()();
  RealColumn get fibreG => real().nullable()();
  TextColumn get provenance => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Meal-plan items (RCP-014, schema v5; used from WP 7 stage 3). `day` is
/// `YYYY-MM-DD`, `meal` a `MealSlot` name, `kind` recipe | food | savedMeal,
/// `ref_id` the id of the referenced record, `unit` grams | millilitres |
/// portions (the `ReferenceUnit` names). `eaten_entry_id` holds the id(s) of
/// the diary entries created when the item is marked eaten: one or more,
/// comma-separated (a saved meal creates one per item).
@DataClassName('MealPlanItemRow')
@TableIndex(name: 'idx_meal_plan_items_day', columns: {#day})
class MealPlanItems extends Table with SyncColumns {
  TextColumn get day => text()();
  TextColumn get meal => text()();
  TextColumn get kind => text()();
  TextColumn get refId => text()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get unit => text()();
  TextColumn get eatenEntryId => text().nullable()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Meal-prep batches (RCP-015, schema v5; used from WP 7 stage 3): portions
/// made and still remaining, never below 0.
@DataClassName('PrepBatchRow')
@TableIndex(name: 'idx_prep_batches_recipe', columns: {#recipeId})
class PrepBatches extends Table with SyncColumns {
  TextColumn get recipeId =>
      text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get preparedAt => dateTime()();
  RealColumn get portionsMade => real()();
  RealColumn get portionsRemaining =>
      // ignore: recursive_getters, drift's check() refers to its own column
      real().check(portionsRemaining.isBiggerOrEqualValue(0))();

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
@TableIndex(name: 'idx_plan_exercises_plan', columns: {#planId})
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
@TableIndex(name: 'idx_workout_sessions_started', columns: {#startedAt})
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
@TableIndex(name: 'idx_session_sets_session', columns: {#sessionId})
@TableIndex(name: 'idx_session_sets_exercise', columns: {#exerciseId})
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
