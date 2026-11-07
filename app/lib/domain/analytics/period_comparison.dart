import 'package:meta/meta.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/analytics/nutrition_analytics.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/measurements/measurement_comparison.dart'
    show periodStats, roundToTenth;
import 'package:repforge/domain/measurements/measurements.dart';

/// What GOL-009 compares.
enum ComparisonMeasure {
  energy('Energy', 'kcal per logged day'),
  protein('Protein', 'g per logged day'),
  volume('Volume', 'kg'),
  weight('Weight', 'kg, mean of readings');

  ComparisonMeasure(this.label, this.unit);
  final String label;
  final String unit;
}

/// The text shown for a figure that cannot be compared (GOL-009(2)).
const String notAvailableText = 'not available';

/// One measure in two periods. [difference] is later minus earlier and is
/// null (with a [unavailableReason]) when either period has no data: a
/// missing period is "not available", never a zero.
@immutable
final class MeasureComparison {
  const MeasureComparison({
    required this.measure,
    required this.earlier,
    required this.later,
    this.difference,
    this.percent,
    this.unavailableReason,
  });

  factory MeasureComparison.of(
    ComparisonMeasure measure,
    Metric<double> earlier,
    Metric<double> later,
  ) {
    final a = earlier.valueOrNull;
    final b = later.valueOrNull;
    if (a == null || b == null) {
      final reasons = [
        if (earlier is NotEnoughData<double>)
          'earlier period: ${earlier.reason}',
        if (later is NotEnoughData<double>) 'later period: ${later.reason}',
      ];
      return MeasureComparison(
        measure: measure,
        earlier: earlier,
        later: later,
        unavailableReason: reasons.join(' '),
      );
    }
    return MeasureComparison(
      measure: measure,
      earlier: earlier,
      later: later,
      difference: b - a,
      percent: a == 0 ? null : roundToTenth((b - a) / a * 100),
    );
  }

  final ComparisonMeasure measure;
  final Metric<double> earlier;
  final Metric<double> later;

  /// Later minus earlier; null when not available.
  final double? difference;

  /// The difference as a percentage of the earlier value, to 0.1.
  final double? percent;

  /// Why the comparison is not available; null when it is.
  final String? unavailableReason;

  bool get isAvailable => difference != null;
}

/// This period against the one before it (GOL-009): energy and protein per
/// logged day, total volume, and mean weight. Periods of different length
/// (30 and 31 days) compare totals such as volume as they are; the lengths
/// are on the periods.
@immutable
final class PeriodComparison {
  const PeriodComparison._({
    required this.earlier,
    required this.later,
    required this.measures,
  });

  /// Compares [later] with [earlier]. Weight uses the mean of the readings
  /// dated inside each period (the WP 10 period statistic).
  factory PeriodComparison.build({
    required NutritionWeek earlierNutrition,
    required NutritionWeek laterNutrition,
    required WeekTraining earlierTraining,
    required WeekTraining laterTraining,
    required Iterable<Measurement> weightReadings,
  }) {
    final readings = weightReadings.toList();
    Metric<double> weightOf(AnalyticsPeriod p) {
      final s = periodStats(readings, MeasurementSite.weight, p.dateRange);
      if (s.mean == null) {
        return NotEnoughData(
          have: 0,
          need: 1,
          reason: 'No weight was recorded in ${p.label}.',
        );
      }
      return MetricValue(
        s.mean!,
        MetricBasis(
          period: p,
          sampleCount: s.count,
          sources: const ['weight readings'],
          dayRule: calendarDayRule,
        ),
      );
    }

    return PeriodComparison._(
      earlier: earlierNutrition.period,
      later: laterNutrition.period,
      measures: [
        MeasureComparison.of(
          ComparisonMeasure.energy,
          earlierNutrition.averageEnergyKcal,
          laterNutrition.averageEnergyKcal,
        ),
        MeasureComparison.of(
          ComparisonMeasure.protein,
          earlierNutrition.averageProteinG,
          laterNutrition.averageProteinG,
        ),
        MeasureComparison.of(
          ComparisonMeasure.volume,
          earlierTraining.totalVolumeKg,
          laterTraining.totalVolumeKg,
        ),
        MeasureComparison.of(
          ComparisonMeasure.weight,
          weightOf(earlierNutrition.period),
          weightOf(laterNutrition.period),
        ),
      ],
    );
  }

  final AnalyticsPeriod earlier;
  final AnalyticsPeriod later;

  /// Energy, protein, volume and weight, in that order.
  final List<MeasureComparison> measures;

  /// The comparison of [measure].
  MeasureComparison of(ComparisonMeasure measure) =>
      measures.firstWhere((m) => m.measure == measure);
}
