import 'package:meta/meta.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/analytics/target_history.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/summaries.dart';

/// The five nutrition figures of the summaries (NUT-015, NUT-016).
enum NutritionMeasure {
  kcal,
  proteinG,
  carbsG,
  fatG,
  fibreG;

  /// The tracked nutrient; null for energy, which is always known.
  Nutrient? get nutrient => switch (this) {
    kcal => null,
    proteinG => Nutrient.proteinG,
    carbsG => Nutrient.carbsG,
    fatG => Nutrient.fatG,
    fibreG => Nutrient.fibreG,
  };

  /// The value of this measure in [a], or null when unknown.
  double? of(NutrientAmounts a) =>
      nutrient == null ? a.kcal : a.valueOf(nutrient!);

  String get label => switch (this) {
    kcal => 'energy',
    proteinG => 'protein',
    carbsG => 'carbohydrate',
    fatG => 'fat',
    fibreG => 'fibre',
  };
}

/// One diary day: what was eaten, the target in effect on that day (GOL-006)
/// and the weakest provenance among its entries (NUT-019).
///
/// Totals are built with the existing [DailySummary] / [NutrientTotals]
/// rules: no second nutrient formula.
@immutable
final class DayNutrition {
  const DayNutrition({
    required this.day,
    required this.totals,
    required this.targetsInEffect,
    required this.entryCount,
    this.provenance,
  });

  /// Builds the day from its [entries] and the targets in effect.
  factory DayNutrition.build({
    required CalendarDate day,
    required Iterable<FoodLogEntry> entries,
    required DailyTargets targets,
  }) {
    final list = entries.toList();
    final summary = DailySummary.fromEntries(
      day: day.iso,
      entries: list,
      targets: targets,
    );
    return DayNutrition(
      day: day,
      totals: summary.totals,
      targetsInEffect: targets,
      entryCount: summary.entryCount,
      provenance: weakestProvenance(list.map((e) => e.provenance)),
    );
  }

  final CalendarDate day;
  final NutrientTotals totals;

  /// The targets in effect on [day], not today's.
  final DailyTargets targetsInEffect;
  final int entryCount;

  /// The weakest label among the day's entries; null when nothing was logged.
  final DataProvenance? provenance;

  /// The diary day key.
  String get dayKey => day.iso;

  /// Whether the day has at least one entry. An unlogged day is "not
  /// logged", never 0 (NUT-016(2)).
  bool get isLogged => entryCount > 0;

  /// Whether some entry lacked a nutrient (NUT-021(2)).
  bool get hasMissingData => isLogged && !totals.isComplete;
}

/// A period of the food diary: every day with its totals, and averages over
/// the logged days (NUT-016, GOL-007, GOL-009). It also serves a month.
///
/// Days without entries are "not logged". Averages are taken over logged
/// days only, with the rules of [WeeklySummary.averagePerLoggedDay].
@immutable
final class NutritionWeek {
  const NutritionWeek._({
    required this.period,
    required this.days,
    required this.summary,
    required this.dayRule,
    required this.elapsedDays,
  });

  /// Builds the period from [entries] (entries outside it are ignored).
  /// [asOf] is the current diary day: days after it have not happened and are
  /// not counted as not logged.
  /// [dayStartHour] is the day-start setting the entries' day keys were
  /// stored with; it is stated beside the figures.
  factory NutritionWeek.build({
    required AnalyticsPeriod period,
    required Iterable<FoodLogEntry> entries,
    required TargetHistory history,
    required int dayStartHour,
    CalendarDate? asOf,
  }) {
    final inPeriod = [
      for (final e in entries)
        if (period.containsDayKey(e.day)) e,
    ];
    final byDay = <String, List<FoodLogEntry>>{};
    for (final e in inPeriod) {
      (byDay[e.day] ??= []).add(e);
    }
    return NutritionWeek._(
      period: period,
      days: [
        for (final d in period.days)
          DayNutrition.build(
            day: d,
            entries: byDay[d.iso] ?? const [],
            targets: history.targetsOn(d),
          ),
      ],
      summary: WeeklySummary.fromEntries(
        days: period.dayKeys,
        entries: inPeriod,
      ),
      dayRule: AnalyticsPeriod.dayRuleFor(dayStartHour),
      elapsedDays: asOf == null
          ? period.dayCount
          : period.days.where((d) => !d.isAfter(asOf)).length,
    );
  }

  final AnalyticsPeriod period;

  /// Every day of the period, oldest first, logged or not.
  final List<DayNutrition> days;

  /// The shared summary rules ([WeeklySummary]) this period is built on.
  final WeeklySummary summary;

  /// Which day boundary the entries use.
  final String dayRule;

  /// Days with at least one entry.
  int get loggedDays => summary.loggedDays;

  /// Days of the period that have started: all of them for a past period,
  /// up to `asOf` for the current one. Future days are neither logged nor
  /// not logged.
  final int elapsedDays;

  /// Elapsed days with no entry.
  int get notLoggedDays => elapsedDays - loggedDays;

  /// "5 of 7 days logged" (NUT-016(1)); for a week in progress the days that
  /// have started, for example "3 of 4 days logged".
  String get daysLoggedText => '$loggedDays of $elapsedDays days logged';

  /// The weakest provenance among all entries of the period (NUT-019);
  /// null when nothing was logged.
  DataProvenance? get weakestProvenanceOfPeriod =>
      weakestProvenance([for (final d in days) ?d.provenance]);

  /// Whether any logged day lacks a nutrient value.
  bool get hasMissingData => days.any((d) => d.hasMissingData);

  /// Logged days where [measure] is unknown (excluded from its average).
  int unknownDays(NutritionMeasure measure) =>
      measure.nutrient == null ? 0 : summary.unknownDays(measure.nutrient!);

  /// The average of [measure] per logged day (NUT-016). Not enough data when
  /// no day was logged, or when no logged day knows the nutrient.
  Metric<double> average(NutritionMeasure measure) {
    if (loggedDays == 0) {
      return NotEnoughData(
        have: 0,
        need: 1,
        reason: 'No day was logged in ${period.label}.',
      );
    }
    final value = measure.of(summary.averagePerLoggedDay!);
    if (value == null) {
      return NotEnoughData(
        have: 0,
        need: 1,
        reason: 'No logged day has a known ${measure.label} value.',
      );
    }
    return MetricValue(
      value,
      MetricBasis(
        period: period,
        sampleCount: loggedDays - unknownDays(measure),
        sources: const ['food log entries'],
        weakestProvenance: weakestProvenanceOfPeriod,
        dayRule: dayRule,
      ),
    );
  }

  /// Average energy per logged day.
  Metric<double> get averageEnergyKcal => average(NutritionMeasure.kcal);

  /// Average protein per logged day.
  Metric<double> get averageProteinG => average(NutritionMeasure.proteinG);
}
