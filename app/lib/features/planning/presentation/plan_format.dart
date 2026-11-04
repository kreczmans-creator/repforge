import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';

/// Quantity of a planned item for display: "1.5 portions" (recipe),
/// "150 g" (food), "×1 saved meal" (saved meal multiplier).
String plannedQuantityLabel(MealPlanItem item) {
  final n = formatNumber(item.quantity, maxDecimals: 2);
  return switch (item.kind) {
    PlannedKind.recipe => portionsLabel(item.quantity),
    PlannedKind.food => '$n ${item.unit.symbol}',
    PlannedKind.savedMeal => '×$n saved meal',
  };
}

/// "1 portion", "1.5 portions", "6 portions".
String portionsLabel(double portions) =>
    '${formatNumber(portions)} ${portions == 1 ? 'portion' : 'portions'}';

/// "6 portions left" for a prepared batch (RCP-015), to one decimal.
String portionsLeftLabel(double remaining) =>
    '${formatNumber(remaining)} '
    '${remaining == 1 ? 'portion' : 'portions'} left';

/// Day key `YYYY-MM-DD` of [d] (its calendar date, any time zone as given).
String planDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Unit of the quantity input for a planned kind.
String planUnitLabel(PlannedKind kind, ReferenceUnit unit) => switch (kind) {
  PlannedKind.recipe => 'portions',
  PlannedKind.food => unit.symbol,
  PlannedKind.savedMeal => '× (times)',
};
