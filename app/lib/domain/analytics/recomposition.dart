import 'package:meta/meta.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/weight_trend.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// One plotted point of a recomposition series.
@immutable
final class SeriesPoint {
  const SeriesPoint({
    required this.date,
    required this.value,
    required this.joinPrevious,
  });

  final CalendarDate date;
  final double value;

  /// Whether a line may join the previous point to this one: their dates are
  /// at most [chartJoinMaxDayGap] days apart (BCM-005(2)). The first point
  /// never joins.
  final bool joinPrevious;
}

/// One series with the number of points behind it (GOL-010(2)).
@immutable
final class SeriesData {
  const SeriesData({
    required this.name,
    required this.unit,
    required this.points,
  });

  final String name;
  final String unit;
  final List<SeriesPoint> points;

  int get pointCount => points.length;

  /// "Weight trend: 12 points".
  String get countText =>
      '$name: $pointCount ${pointCount == 1 ? 'point' : 'points'}';
}

/// Weight trend, waist readings and the strength series of one chosen
/// exercise on one shared date range (GOL-010). The series keep their own
/// units; the view stacks them on the same date axis (plan decision 12b).
/// Strength is the top-set weight per session (decision 6c).
@immutable
final class RecompositionSeries {
  const RecompositionSeries._({
    required this.period,
    required this.weight,
    required this.waist,
    required this.strength,
    this.exerciseId,
  });

  /// Builds the three series for [period].
  ///
  /// [weightReadings] should reach [trendWindowDays] - 1 days before the
  /// period start so the first trend points are complete. [waistReadings]
  /// may hold other sites. [strengthSessions] are the sessions of
  /// [exerciseId] (`sessionsForExercise`).
  factory RecompositionSeries.build({
    required AnalyticsPeriod period,
    required Iterable<Measurement> weightReadings,
    required Iterable<Measurement> waistReadings,
    required Iterable<ExerciseSessionHistory> strengthSessions,
    String? exerciseId,
  }) {
    final trend = [
      for (final p in weightTrend(weightReadings))
        if (p.average != null && period.containsDay(p.date)) p,
    ];
    final waist = readingsOf(
      waistReadings,
      MeasurementSite.waist,
      range: period.dateRange,
    );
    final strength = [
      for (final p in ExerciseProgress.build(
        strengthSessions,
        dayStartHour: period.dayStartHour,
      ).points)
        if (p.topSetWeightKg != null && period.containsDay(p.date)) p,
    ];

    bool joins(CalendarDate? a, CalendarDate b) =>
        a != null && a.daysUntil(b) <= chartJoinMaxDayGap;

    List<SeriesPoint> build<T>(
      List<T> items,
      CalendarDate Function(T) dateOf,
      double Function(T) valueOf,
    ) {
      CalendarDate? prev;
      return [
        for (final i in items)
          () {
            final d = dateOf(i);
            final point = SeriesPoint(
              date: d,
              value: valueOf(i),
              joinPrevious: joins(prev, d),
            );
            prev = d;
            return point;
          }(),
      ];
    }

    return RecompositionSeries._(
      period: period,
      exerciseId: exerciseId,
      weight: SeriesData(
        name: 'Weight trend',
        unit: 'kg',
        points: build<WeightTrendPoint>(
          trend,
          (p) => p.date,
          (p) => p.average!,
        ),
      ),
      waist: SeriesData(
        name: 'Waist',
        unit: 'cm',
        points: build<Measurement>(
          waist,
          (m) => CalendarDate.fromInstant(m.recordedAt),
          (m) => m.value.raw,
        ),
      ),
      strength: SeriesData(
        name: 'Top set weight',
        unit: 'kg',
        points: build<ExerciseProgressPoint>(
          strength,
          (p) => p.date,
          (p) => p.topSetWeightKg!,
        ),
      ),
    );
  }

  final AnalyticsPeriod period;

  /// The exercise of the strength series; null when none was chosen.
  final String? exerciseId;
  final SeriesData weight;
  final SeriesData waist;
  final SeriesData strength;

  /// The one date range all three series are drawn on.
  DateRange get range => period.dateRange;

  /// The three series, weight, waist, strength.
  List<SeriesData> get series => [weight, waist, strength];

  /// Points behind each series, for the text summary (UXD-009).
  List<String> get countTexts => [for (final s in series) s.countText];
}
