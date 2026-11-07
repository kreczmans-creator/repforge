import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/period_comparison.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';
import 'package:repforge/features/analytics/presentation/analytics_periods.dart';
import 'package:repforge/features/analytics/presentation/analytics_widgets.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/tokens.dart';

/// Period comparison (GOL-009): this week against last week, or this month
/// against last month, for energy, protein, volume and weight. A period
/// without data reads "not available", never 0.
class PeriodComparisonScreen extends ConsumerStatefulWidget {
  const PeriodComparisonScreen({super.key});

  @override
  ConsumerState<PeriodComparisonScreen> createState() =>
      _PeriodComparisonScreenState();
}

class _PeriodComparisonScreenState
    extends ConsumerState<PeriodComparisonScreen> {
  AnalyticsPeriodKind _kind = AnalyticsPeriodKind.week;

  @override
  Widget build(BuildContext context) {
    final later = periodFromSettings(ref, _kind);
    final earlier = ref.watch(
      currentPeriodProvider(
        _kind == AnalyticsPeriodKind.month
            ? PeriodChoice.lastMonth
            : PeriodChoice.lastWeek,
      ),
    );
    final comparison = ref.watch(
      periodComparisonProvider((later: later, earlier: earlier)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Compare periods')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Compare periods',
            caption: 'A period against the one before it',
          ),
          SegmentedButton<AnalyticsPeriodKind>(
            key: const Key('compare-mode'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: AnalyticsPeriodKind.week,
                label: Text('Week'),
              ),
              ButtonSegment(
                value: AnalyticsPeriodKind.month,
                label: Text('Month'),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: RfSpace.s3),
          Text(
            'Earlier: ${earlier.label} (${earlier.from.iso} to '
            '${earlier.to.iso})',
            key: const Key('compare-earlier-label'),
            style: context.rfText.caption,
          ),
          Text(
            'Later: ${later.label} (${later.from.iso} to ${later.to.iso})',
            key: const Key('compare-later-label'),
            style: context.rfText.caption,
          ),
          const SizedBox(height: RfSpace.s3),
          analyticsWhen<PeriodComparison>(
            comparison,
            errorKey: const Key('compare-error'),
            onRetry: () => ref.invalidate(
              periodComparisonProvider((later: later, earlier: earlier)),
            ),
            data: (c) => _Table(comparison: c),
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.comparison});

  final PeriodComparison comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String text, {Key? key, bool header = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: RfSpace.s2),
      child: Text(
        text,
        key: key,
        style: header ? context.rfText.kicker : context.rfText.dataS,
      ),
    );
    String value(MeasureComparison m, double? v) =>
        v == null ? notAvailableText : formatMeasure(m.measure, v);
    return RfCard(
      key: const Key('compare-table'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            columnWidths: const {0: FlexColumnWidth(1.3)},
            children: [
              TableRow(
                children: [
                  cell('MEASURE', header: true),
                  cell('EARLIER', header: true),
                  cell('LATER', header: true),
                  cell('DIFFERENCE', header: true),
                ],
              ),
              for (final m in comparison.measures)
                TableRow(
                  children: [
                    cell(
                      m.measure.label,
                      key: Key('compare-${m.measure.name}-measure'),
                    ),
                    cell(
                      value(m, m.earlier.valueOrNull),
                      key: Key('compare-${m.measure.name}-earlier'),
                    ),
                    cell(
                      value(m, m.later.valueOrNull),
                      key: Key('compare-${m.measure.name}-later'),
                    ),
                    cell(
                      m.difference == null
                          ? notAvailableText
                          : signedNumber(m.difference!),
                      key: Key('compare-${m.measure.name}-difference'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: RfSpace.s2),
          if (comparison.partialNote != null)
            Padding(
              padding: const EdgeInsets.only(bottom: RfSpace.s1),
              child: Text(
                comparison.partialNote!,
                key: const Key('compare-partial-note'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: RfSpace.s1),
            child: Text(
              PeriodComparison.weightBasisNote,
              key: const Key('compare-weight-note'),
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final m in comparison.measures)
            Text(
              '${m.measure.label}: ${m.measure.unit}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// A figure of [measure] as text, without its unit (units are listed below
/// the table).
String formatMeasure(ComparisonMeasure measure, double v) =>
    formatNumber(v, maxDecimals: measure == ComparisonMeasure.weight ? 1 : 0);
