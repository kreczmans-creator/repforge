import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/analytics/weekly_report.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';
import 'package:repforge/features/analytics/presentation/analytics_periods.dart';
import 'package:repforge/features/analytics/presentation/analytics_widgets.dart';
import 'package:repforge/features/nutrition/presentation/provenance_badge.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/tokens.dart';

/// Weekly summary (GOL-007): nutrition, training and body for this week or an
/// earlier one. A missing figure reads "not enough data", never 0. Each
/// section states its day rule once (plan decision 7b).
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  int _back = 0;

  @override
  Widget build(BuildContext context) {
    final period = periodFromSettings(
      ref,
      AnalyticsPeriodKind.week,
      back: _back,
    );
    final report = ref.watch(weeklyReportProvider(period));
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly summary')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Weekly summary',
            caption: 'Nutrition, training and body',
          ),
          Row(
            children: [
              IconButton(
                key: const Key('weekly-period-prev'),
                tooltip: 'Previous week',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _back++),
              ),
              Expanded(
                child: Text(
                  '${_back == 0
                      ? 'This week'
                      : _back == 1
                      ? 'Previous week'
                      : '$_back weeks ago'}'
                  ' · ${period.from.iso} to ${period.to.iso}',
                  key: const Key('weekly-period-label'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('weekly-period-next'),
                tooltip: 'Next week',
                icon: const Icon(Icons.chevron_right),
                onPressed: _back == 0 ? null : () => setState(() => _back--),
              ),
            ],
          ),
          const SizedBox(height: RfSpace.s2),
          analyticsWhen<WeeklyReport>(
            report,
            errorKey: const Key('weekly-error'),
            onRetry: () => ref.invalidate(weeklyReportProvider(period)),
            data: (r) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Nutrition(report: r),
                _Training(report: r),
                _Body(report: r),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.cardKey,
    required this.title,
    required this.dayRule,
    required this.children,
  });

  final Key cardKey;
  final String title;
  final String dayRule;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: RfSpace.s3),
      RfSectionHeader(title: title),
      RfCard(
        key: cardKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [...children, DayRuleNote(dayRule)],
        ),
      ),
    ],
  );
}

Widget _missing(Metric<Object?> m) => FigureRow(
  label: 'Figures',
  value: notEnoughDataText,
  caption: metricReason(m),
);

class _Nutrition extends StatelessWidget {
  const _Nutrition({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final section = report.nutrition;
    return _Section(
      cardKey: const Key('weekly-nutrition'),
      title: 'Nutrition',
      dayRule: report.nutritionDayRule,
      children: [
        if (section case MetricValue<NutritionSummary>(:final value)) ...[
          FigureRow(
            key: const Key('weekly-days-logged'),
            label: 'Days logged',
            value: switch (value.daysLogged) {
              MetricValue<int>(:final value, :final basis) =>
                '$value of ${basis.sampleCount}',
              NotEnoughData<int>() => notEnoughDataText,
            },
          ),
          FigureRow.metric(
            key: const Key('weekly-energy'),
            label: 'Average energy per logged day',
            metric: value.averageEnergyKcal,
            decimals: 0,
            unit: 'kcal',
          ),
          FigureRow.metric(
            key: const Key('weekly-protein'),
            label: 'Average protein per logged day',
            metric: value.averageProteinG,
            decimals: 0,
            unit: 'g',
          ),
          if (value.weakestProvenance != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RfSpace.s2),
              child: Row(
                children: [
                  const Expanded(child: Text('Weakest data source')),
                  ProvenanceBadge(
                    value.weakestProvenance!,
                    key: const Key('weekly-provenance'),
                  ),
                ],
              ),
            ),
          if (value.hasMissingData)
            Text(
              'Some entries have no value for some nutrients; averages use '
              'the known values only.',
              style: context.rfText.caption,
            ),
        ] else
          _missing(section),
      ],
    );
  }
}

class _Training extends StatelessWidget {
  const _Training({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final section = report.training;
    return _Section(
      cardKey: const Key('weekly-training'),
      title: 'Training',
      dayRule: report.trainingDayRule,
      children: [
        if (section case MetricValue<TrainingSummary>(:final value)) ...[
          FigureRow(
            key: const Key('weekly-sessions'),
            label: 'Sessions completed',
            value: value.sessionsGoal != null
                ? value.sessionsGoal!.statement
                : intMetricText(value.sessionsCompleted, unit: 'sessions'),
          ),
          FigureRow.metric(
            key: const Key('weekly-volume'),
            label: 'Total volume (completed working sets, warm-ups excluded)',
            metric: value.totalVolumeKg,
            decimals: 0,
            unit: 'kg',
          ),
          FigureRow(
            key: const Key('weekly-sets'),
            label: 'Working sets',
            value: '${value.workingSets}',
          ),
          if (value.reps > 0)
            FigureRow(
              key: const Key('weekly-reps'),
              label: 'Repetitions (bodyweight and assisted sets)',
              value: '${value.reps}',
            ),
          if (value.seconds > 0)
            FigureRow(
              key: const Key('weekly-seconds'),
              label: 'Time (timed and cardio sets)',
              value: '${value.seconds} s',
            ),
          if (value.metres > 0)
            FigureRow(
              key: const Key('weekly-metres'),
              label: 'Distance (distance and cardio sets)',
              value: '${formatNumber(value.metres, maxDecimals: 0)} m',
            ),
        ] else
          _missing(section),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final section = report.body;
    return _Section(
      cardKey: const Key('weekly-body'),
      title: 'Body',
      dayRule: report.bodyDayRule,
      children: [
        if (section case MetricValue<BodySummary>(:final value)) ...[
          FigureRow(
            key: const Key('weekly-weight-change'),
            label: 'Weight trend change over the week',
            value: value.weightChangeKg.valueOrNull == null
                ? notEnoughDataText
                : '${signedNumber(value.weightChangeKg.valueOrNull!)} kg',
            caption: metricReason(value.weightChangeKg),
          ),
          FigureRow(
            key: const Key('weekly-readings'),
            label: 'Weight readings',
            value: '${value.readings}',
          ),
        ] else
          _missing(section),
      ],
    );
  }
}
