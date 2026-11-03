import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

part 'summaries.freezed.dart';

/// Weekly nutrition summary (NUT-021): per-day totals and averages over the
/// days that have at least one entry, so an unlogged day does not drag the
/// average down.
@freezed
abstract class WeeklySummary with _$WeeklySummary {
  const factory WeeklySummary({
    required String fromDay,
    required String toDay,
    required Map<String, NutrientAmounts> perDay,
  }) = _WeeklySummary;

  const WeeklySummary._();

  factory WeeklySummary.fromEntries({
    required List<String> days,
    required Iterable<FoodLogEntry> entries,
  }) {
    final perDay = <String, NutrientAmounts>{};
    for (final e in entries) {
      perDay[e.day] = (perDay[e.day] ?? NutrientAmounts.zero) + e.nutrients;
    }
    return WeeklySummary(fromDay: days.first, toDay: days.last, perDay: perDay);
  }

  int get loggedDays => perDay.length;

  /// Average over logged days; null when nothing was logged.
  NutrientAmounts? get averagePerLoggedDay => perDay.isEmpty
      ? null
      : NutrientAmounts.sum(perDay.values).scaled(1 / perDay.length);

  NutrientAmounts get total => NutrientAmounts.sum(perDay.values);
}

/// The seven day keys ending at the given local date (inclusive), oldest
/// first.
List<String> lastSevenDays(DateTime endLocal) => [
  for (var i = 6; i >= 0; i--)
    dayKey(DateTime(endLocal.year, endLocal.month, endLocal.day - i)),
];
