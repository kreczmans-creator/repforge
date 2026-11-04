import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

part 'summaries.freezed.dart';

/// Weekly nutrition summary (NUT-021): per-day totals and averages over the
/// days that have at least one entry, so an unlogged day does not drag the
/// average down. Unknown macros are carried as counts, never as zeros.
@freezed
abstract class WeeklySummary with _$WeeklySummary {
  const factory WeeklySummary({
    required String fromDay,
    required String toDay,
    required Map<String, NutrientTotals> dayTotals,
  }) = _WeeklySummary;

  const WeeklySummary._();

  factory WeeklySummary.fromEntries({
    required List<String> days,
    required Iterable<FoodLogEntry> entries,
  }) {
    final byDay = <String, List<NutrientAmounts>>{};
    for (final e in entries) {
      (byDay[e.day] ??= []).add(e.nutrients);
    }
    return WeeklySummary(
      fromDay: days.first,
      toDay: days.last,
      dayTotals: {
        for (final e in byDay.entries) e.key: NutrientTotals.of(e.value),
      },
    );
  }

  /// Number of days with at least one entry.
  int get loggedDays => dayTotals.length;

  /// Known per-day sums (unknown values are left out of the sum, not zero).
  /// See [dayTotals] for the unknown counts.
  Map<String, NutrientAmounts> get perDay => {
    for (final e in dayTotals.entries) e.key: e.value.known,
  };

  /// Totals of the whole week with unknown counts per nutrient.
  NutrientTotals get weekTotals => NutrientTotals.combine(dayTotals.values);

  /// Average of the known values over logged days; null when nothing was
  /// logged. See [weekTotals] for how many entries were unknown.
  NutrientAmounts? get averagePerLoggedDay =>
      dayTotals.isEmpty ? null : total.scaled(1 / dayTotals.length);

  /// Sum of the known values over the week.
  NutrientAmounts get total => weekTotals.known;
}

/// The seven day keys ending at the given local date (inclusive), oldest
/// first.
List<String> lastSevenDays(DateTime endLocal) => [
  for (var i = 6; i >= 0; i--)
    dayKey(DateTime(endLocal.year, endLocal.month, endLocal.day - i)),
];
