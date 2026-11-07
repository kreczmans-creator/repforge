import 'package:meta/meta.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show DataProvenance;

/// What a figure was computed from, so the screen can show its basis
/// (GOL-008(1)).
@immutable
final class MetricBasis {
  const MetricBasis({
    required this.sampleCount,
    required this.sources,
    required this.dayRule,
    this.period,
    this.weakestProvenance,
  });

  /// The period the figure covers; null for a figure about the latest
  /// reading only.
  final AnalyticsPeriod? period;

  /// How many inputs (days, readings, sessions) the figure rests on.
  final int sampleCount;

  /// What was read, for example `food log entries`.
  final List<String> sources;

  /// The weakest provenance among the inputs when they carry one (NUT-019).
  final DataProvenance? weakestProvenance;

  /// Which day boundary applies (plan decision 7b).
  final String dayRule;

  /// One line for the screen: sources, period, count and day rule.
  String describe() {
    final parts = [
      sources.join(', '),
      ?period?.label,
      '$sampleCount ${sampleCount == 1 ? 'sample' : 'samples'}',
      dayRule,
    ];
    return parts.join(' · ');
  }
}

/// A figure that is either present with its basis or explicitly missing. A
/// missing figure is never a zero (GOL-007(2), GEN-006, BCM-008).
sealed class Metric<T> {
  const Metric();

  /// The value, or null when there is not enough data.
  T? get valueOrNull;

  /// Whether a value is present.
  bool get isAvailable => this is MetricValue<T>;
}

/// A figure with the basis it was computed from.
final class MetricValue<T> extends Metric<T> {
  const MetricValue(this.value, this.basis);

  final T value;
  final MetricBasis basis;

  @override
  T? get valueOrNull => value;
}

/// Not enough data for the figure: [have] of the [need]ed inputs exist, and
/// [reason] says what is missing in plain words.
final class NotEnoughData<T> extends Metric<T> {
  const NotEnoughData({
    required this.have,
    required this.need,
    required this.reason,
  });

  final int have;
  final int need;
  final String reason;

  @override
  T? get valueOrNull => null;
}
