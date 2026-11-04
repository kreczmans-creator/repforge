import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

part 'summaries.freezed.dart';

/// Weekly nutrition summary (NUT-016): per-day totals and averages over the
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

  /// Average per logged day; null when nothing was logged. Energy is
  /// averaged over every logged day. Each other nutrient is averaged over
  /// the logged days that KNOW it (a day with no known value is left out of
  /// both numerator and denominator, never counted as 0) and is null when no
  /// logged day knows it. See [unknownDays] for how many days were left out.
  NutrientAmounts? get averagePerLoggedDay {
    if (dayTotals.isEmpty) return null;
    final known = dayTotals.values.map((t) => t.known).toList();
    double? avg(Nutrient n) {
      final values = known.map((a) => a.valueOf(n)).nonNulls.toList();
      if (values.isEmpty) return null;
      return values.fold<double>(0, (a, b) => a + b) / values.length;
    }

    return NutrientAmounts(
      kcal: known.fold<double>(0, (a, b) => a + b.kcal) / known.length,
      proteinG: avg(Nutrient.proteinG),
      carbsG: avg(Nutrient.carbsG),
      fatG: avg(Nutrient.fatG),
      fibreG: avg(Nutrient.fibreG),
    );
  }

  /// Logged days whose total for [nutrient] is unknown (no entry of that day
  /// knew it); these days are excluded from [averagePerLoggedDay].
  int unknownDays(Nutrient nutrient) =>
      dayTotals.values.where((t) => t.known.valueOf(nutrient) == null).length;

  /// Sum of the known values over the week.
  NutrientAmounts get total => weekTotals.known;
}

/// The seven day keys ending at the given local date (inclusive), oldest
/// first.
List<String> lastSevenDays(DateTime endLocal) => [
  for (var i = 6; i >= 0; i--)
    dayKey(DateTime(endLocal.year, endLocal.month, endLocal.day - i)),
];
