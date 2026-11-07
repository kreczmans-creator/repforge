import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// The text for a figure that cannot be computed (GOL-007(2)); never 0.
const String notEnoughDataText = 'not enough data';

/// The value of [metric] as text, or [notEnoughDataText]. [unit] is appended
/// when a value is present.
String metricText(Metric<double> metric, {int decimals = 1, String? unit}) {
  final v = metric.valueOrNull;
  if (v == null) return notEnoughDataText;
  final n = formatNumber(v, maxDecimals: decimals);
  return unit == null ? n : '$n $unit';
}

/// A whole-number metric as text, or [notEnoughDataText].
String intMetricText(Metric<int> metric, {String? unit}) {
  final v = metric.valueOrNull;
  if (v == null) return notEnoughDataText;
  return unit == null ? '$v' : '$v $unit';
}

/// Why a metric is missing; null when it is present.
String? metricReason(Metric<Object?> metric) =>
    metric is NotEnoughData ? metric.reason : null;

/// "2026-11-02 to 2026-11-08".
String rangeText(CalendarDate from, CalendarDate to) =>
    '${from.iso} to ${to.iso}';

/// "+1.5", "-0.4" or "0" for a difference.
String signedNumber(double v, {int decimals = 1}) {
  final n = formatNumber(v, maxDecimals: decimals);
  if (n == '0') return n;
  return v > 0 ? '+$n' : n;
}

/// Error panel with a retry that re-runs the failed provider. The developer
/// message of the failure is not shown (engineering standards section 5).
class AnalyticsErrorState extends StatelessWidget {
  const AnalyticsErrorState({
    required this.onRetry,
    super.key,
    this.message = 'Could not load this view. Your data is unchanged.',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) =>
      RfErrorState(message: message, onRetry: onRetry);
}

/// Renders the three states of an analytics provider: loading, error with
/// retry, and data.
Widget analyticsWhen<T>(
  AsyncValue<T> value, {
  required Widget Function(T data) data,
  required VoidCallback onRetry,
  Key? errorKey,
}) => value.when(
  loading: () => const RfLoading(),
  error: (e, _) => AnalyticsErrorState(key: errorKey, onRetry: onRetry),
  data: data,
);

/// One labelled figure: label left, value right, optional caption below.
/// A missing figure shows [notEnoughDataText] and its reason as the caption.
class FigureRow extends StatelessWidget {
  const FigureRow({
    required this.label,
    required this.value,
    super.key,
    this.caption,
  });

  /// A row for a metric of doubles.
  FigureRow.metric({
    required this.label,
    required Metric<double> metric,
    super.key,
    int decimals = 1,
    String? unit,
  }) : value = metricText(metric, decimals: decimals, unit: unit),
       caption = metricReason(metric);

  /// A row for a whole-number metric.
  FigureRow.count({
    required this.label,
    required Metric<int> metric,
    super.key,
    String? unit,
  }) : value = intMetricText(metric, unit: unit),
       caption = metricReason(metric);

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RfSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: RfSpace.s3),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: context.rfText.dataM,
                ),
              ),
            ],
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: RfSpace.s1),
              child: Text(caption!, style: context.rfText.caption),
            ),
        ],
      ),
    );
  }
}

/// A small statement of where a section's day boundary lies (plan decision
/// 7b), shown once per section.
class DayRuleNote extends StatelessWidget {
  const DayRuleNote(this.rule, {super.key});

  final String rule;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: RfSpace.s1),
    child: Text(rule, style: context.rfText.caption),
  );
}
