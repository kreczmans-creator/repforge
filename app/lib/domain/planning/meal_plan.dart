import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';

/// What a planned item refers to.
enum PlannedKind { recipe, food, savedMeal }

/// Number of days (today included) an item can be planned ahead (RCP-014(1)).
const planWindowDays = 28;

/// [AppError] field names that identify the typed refusals of the planning
/// use cases (the error class set is closed, so the field carries the type).
abstract final class PlanErrorField {
  static const alreadyEaten = 'alreadyEaten';
  static const day = 'day';
  static const quantity = 'quantity';
  static const reference = 'reference';
  static const portions = 'portions';
}

/// One item of the meal plan (RCP-014): a recipe, food or saved meal planned
/// for a meal on a date.
///
/// [quantity] is portions for a recipe, g or ml (the food's reference unit)
/// for a food, and a multiplier (1 = once) for a saved meal; [unit] says
/// which. [eatenEntryIds] holds the diary entries created when the item was
/// marked as eaten (a saved meal creates one per item).
@immutable
final class MealPlanItem {
  const MealPlanItem({
    required this.id,
    required this.day,
    required this.meal,
    required this.kind,
    required this.refId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.eatenEntryIds = const [],
  });

  final String id;

  /// Local calendar day `YYYY-MM-DD`.
  final String day;
  final MealSlot meal;
  final PlannedKind kind;
  final String refId;
  final String name;
  final double quantity;
  final ReferenceUnit unit;
  final List<String> eatenEntryIds;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEaten => eatenEntryIds.isNotEmpty;

  MealPlanItem copyWith({
    String? day,
    MealSlot? meal,
    double? quantity,
    List<String>? eatenEntryIds,
    int? sortOrder,
    DateTime? updatedAt,
  }) => MealPlanItem(
    id: id,
    day: day ?? this.day,
    meal: meal ?? this.meal,
    kind: kind,
    refId: refId,
    name: name,
    quantity: quantity ?? this.quantity,
    unit: unit,
    eatenEntryIds: eatenEntryIds ?? this.eatenEntryIds,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is MealPlanItem &&
      other.id == id &&
      other.day == day &&
      other.meal == meal &&
      other.kind == kind &&
      other.refId == refId &&
      other.name == name &&
      other.quantity == quantity &&
      other.unit == unit &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.eatenEntryIds.join(',') == eatenEntryIds.join(',');

  @override
  int get hashCode => Object.hash(
    id,
    day,
    meal,
    kind,
    refId,
    quantity,
    unit,
    sortOrder,
    eatenEntryIds.join(','),
  );

  @override
  String toString() =>
      'MealPlanItem($id, $day, ${meal.name}, ${kind.name} '
      '$name × $quantity ${unit.symbol})';
}

abstract interface class MealPlanRepository {
  /// Live items of [day], ordered by sort order then creation time.
  Stream<List<MealPlanItem>> watchDay(String day);

  /// Live items from [fromDay] to [toDay] inclusive, ordered by day.
  Stream<List<MealPlanItem>> watchRange(String fromDay, String toDay);

  Future<MealPlanItem?> byId(String id);

  /// Inserts or replaces. Upserting a soft-deleted id keeps it deleted.
  Future<void> upsert(MealPlanItem item);

  /// Soft delete; idempotent.
  Future<void> delete(String id);

  /// Records the diary entries created for the item.
  Future<void> markEaten(String id, List<String> entryIds);
}

/// The entities a plan item may resolve to. Pass the one matching the item's
/// kind; `null` means the reference no longer exists.
typedef PlannedRefs = ({Recipe? recipe, Food? food, SavedMeal? savedMeal});

/// The nutrient snapshots the item stands for, one per diary entry that
/// marking it as eaten would create (a recipe or food makes one, a saved meal
/// one per item). Uses exactly the log calculations (spec §9.5, NUT-004, saved
/// meal item snapshots × multiplier). `null` when the reference is missing or
/// has no nutrition; nothing is invented.
List<NutrientAmounts>? plannedEntryNutrients(
  MealPlanItem item, {
  Recipe? recipe,
  Food? food,
  SavedMeal? savedMeal,
}) {
  final q = Quantity.of(item.quantity, item.unit);
  if (q is! Ok<Quantity>) return null;
  final quantity = q.value;
  switch (item.kind) {
    case PlannedKind.recipe:
      final n = recipe?.nutritionForPortions(quantity.amount);
      return n == null ? null : [n];
    case PlannedKind.food:
      if (food == null) return null;
      final n = food.profile.forQuantity(quantity);
      return n is Ok<NutrientAmounts> ? [n.value] : null;
    case PlannedKind.savedMeal:
      if (savedMeal == null || savedMeal.items.isEmpty) return null;
      return [
        for (final i in savedMeal.items) i.nutrients.scaled(quantity.amount),
      ];
  }
}

/// Planned nutrition of one item (sum of [plannedEntryNutrients]); `null`
/// when it cannot be determined.
NutrientAmounts? plannedNutrition(
  MealPlanItem item, {
  Recipe? recipe,
  Food? food,
  SavedMeal? savedMeal,
}) {
  final parts = plannedEntryNutrients(
    item,
    recipe: recipe,
    food: food,
    savedMeal: savedMeal,
  );
  return parts == null ? null : NutrientAmounts.sum(parts);
}

/// Provenance of the item's nutrition (spec §8); `null` when unresolved.
DataProvenance? plannedProvenance({
  required PlannedKind kind,
  Recipe? recipe,
  Food? food,
  SavedMeal? savedMeal,
}) => switch (kind) {
  PlannedKind.recipe => recipe?.provenance,
  PlannedKind.food => food?.profile.provenance,
  PlannedKind.savedMeal =>
    savedMeal == null
        ? null
        : weakestProvenance(savedMeal.items.map((i) => i.provenance)),
};

/// Planned totals of one day (RCP-014(2)).
///
/// [totals] carries the unknown counts of spec §7.3 exactly as the log does.
/// Items whose reference was deleted (or has no nutrition) are listed in
/// [unresolvedItemIds] and contribute nothing to [totals]: their nutrition
/// is unknown, not zero.
final class PlanDaySummary {
  const PlanDaySummary({
    required this.day,
    required this.totals,
    required this.provenance,
    required this.itemCount,
    required this.unresolvedItemIds,
  });

  final String day;
  final NutrientTotals totals;

  /// Weakest provenance among resolved items (spec §8); `null` when none.
  final DataProvenance? provenance;
  final int itemCount;
  final List<String> unresolvedItemIds;

  int get unresolvedCount => unresolvedItemIds.length;
}

/// Builds the summary of [items] (all on [day]) from the resolved references,
/// keyed by id.
PlanDaySummary summarisePlanDay(
  String day,
  Iterable<MealPlanItem> items, {
  Map<String, Recipe> recipes = const {},
  Map<String, Food> foods = const {},
  Map<String, SavedMeal> savedMeals = const {},
}) {
  final list = items.toList();
  final amounts = <NutrientAmounts>[];
  final provenances = <DataProvenance>[];
  final unresolved = <String>[];
  for (final item in list) {
    final recipe = recipes[item.refId];
    final food = foods[item.refId];
    final meal = savedMeals[item.refId];
    final parts = plannedEntryNutrients(
      item,
      recipe: item.kind == PlannedKind.recipe ? recipe : null,
      food: item.kind == PlannedKind.food ? food : null,
      savedMeal: item.kind == PlannedKind.savedMeal ? meal : null,
    );
    final p = plannedProvenance(
      kind: item.kind,
      recipe: recipe,
      food: food,
      savedMeal: meal,
    );
    if (parts == null || p == null) {
      unresolved.add(item.id);
      continue;
    }
    amounts.addAll(parts);
    provenances.add(p);
  }
  return PlanDaySummary(
    day: day,
    totals: NutrientTotals.of(amounts),
    provenance: weakestProvenance(provenances),
    itemCount: list.length,
    unresolvedItemIds: unresolved,
  );
}
