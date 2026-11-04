import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/domain/units/units.dart';

/// Separator for several diary entry ids in the single stored column.
const _idSeparator = ',';

/// Lenient: a row with an unknown kind, meal or unit, or a bad quantity, is
/// skipped (null) rather than failing the whole list.
MealPlanItem? mealPlanItemFromRow(MealPlanItemRow r) {
  final kind = PlannedKind.values.asNameMap()[r.kind];
  final meal = MealSlot.values.asNameMap()[r.meal];
  final unit = ReferenceUnit.values.asNameMap()[r.unit];
  if (kind == null || meal == null || unit == null) return null;
  if (r.amount.isNaN || r.amount.isInfinite || r.amount < 0) return null;
  final eaten = r.eatenEntryId;
  return MealPlanItem(
    id: r.id,
    day: r.day,
    meal: meal,
    kind: kind,
    refId: r.refId,
    name: r.name,
    quantity: r.amount,
    unit: unit,
    eatenEntryIds: eaten == null || eaten.isEmpty
        ? const []
        : eaten.split(_idSeparator),
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );
}

MealPlanItemsCompanion mealPlanItemToCompanion(
  MealPlanItem i, {
  required DateTime updatedAt,
}) => MealPlanItemsCompanion.insert(
  id: i.id,
  day: i.day,
  meal: i.meal.name,
  kind: i.kind.name,
  refId: i.refId,
  name: i.name,
  amount: i.quantity,
  unit: i.unit.name,
  eatenEntryId: Value(i.isEaten ? i.eatenEntryIds.join(_idSeparator) : null),
  sortOrder: i.sortOrder,
  createdAt: i.createdAt,
  updatedAt: updatedAt,
);

String joinEntryIds(List<String> ids) => ids.join(_idSeparator);

PrepBatch? prepBatchFromRow(PrepBatchRow r) {
  if (r.portionsMade.isNaN ||
      r.portionsRemaining.isNaN ||
      r.portionsMade <= 0 ||
      r.portionsRemaining < 0) {
    return null;
  }
  return PrepBatch(
    id: r.id,
    recipeId: r.recipeId,
    preparedAt: r.preparedAt,
    portionsMade: r.portionsMade,
    portionsRemaining: r.portionsRemaining,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );
}

PrepBatchesCompanion prepBatchToCompanion(
  PrepBatch b, {
  required DateTime updatedAt,
}) => PrepBatchesCompanion.insert(
  id: b.id,
  recipeId: b.recipeId,
  preparedAt: b.preparedAt,
  portionsMade: b.portionsMade,
  portionsRemaining: b.portionsRemaining,
  createdAt: b.createdAt,
  updatedAt: updatedAt,
);
