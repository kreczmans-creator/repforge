import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';
import 'package:repforge/features/analytics/application/training_use_cases.dart';
import 'package:repforge/features/analytics/presentation/analytics_periods.dart';
import 'package:repforge/features/analytics/presentation/analytics_widgets.dart';
import 'package:repforge/features/analytics/presentation/record_text.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';
import 'package:repforge/ui/tokens.dart';

/// How many weeks the volume chart covers.
const int trainingWeeks = 8;

/// Training analytics (TRN-027, without muscle figures): weekly volume,
/// sessions and sets for the last [trainingWeeks] weeks, and the exercises of
/// the current week.
class TrainingAnalyticsScreen extends ConsumerWidget {
  const TrainingAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Oldest week first.
    final periods = [
      for (var i = trainingWeeks - 1; i >= 0; i--)
        periodFromSettings(ref, AnalyticsPeriodKind.week, back: i),
    ];
    // The earlier weeks need only their totals; names and record events are
    // read for the current week alone.
    final earlier = [
      for (final p in periods.take(periods.length - 1))
        ref.watch(weekTrainingTotalsProvider(p)),
    ];
    final current = ref.watch(weekTrainingProvider(periods.last));
    final all = <AsyncValue<Object?>>[...earlier, current];
    void retry() {
      for (final p in periods.take(periods.length - 1)) {
        ref.invalidate(weekTrainingTotalsProvider(p));
      }
      ref.invalidate(weekTrainingProvider(periods.last));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Training analytics')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Training analytics',
            caption: 'Volume, sessions and sets per week',
          ),
          if (all.any((v) => v.hasError && !v.hasValue))
            AnalyticsErrorState(
              key: const Key('training-error'),
              onRetry: retry,
            )
          else if (all.any((v) => !v.hasValue))
            const RfLoading()
          else
            _Body(
              periods: periods,
              weeks: [for (final v in earlier) v.value!, current.value!.week],
              current: current.value!,
            ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.periods,
    required this.weeks,
    required this.current,
  });

  final List<AnalyticsPeriod> periods;

  /// The training of each period, oldest first; the last is [current]'s.
  final List<WeekTraining> weeks;
  final WeekTrainingView current;

  @override
  Widget build(BuildContext context) {
    final points = <RfTrendPoint>[];
    for (var i = 0; i < periods.length; i++) {
      final v = weeks[i].totalVolumeKg.valueOrNull;
      if (v != null) {
        final d = periods[i].from;
        points.add(RfTrendPoint(DateTime(d.year, d.month, d.day), v));
      }
    }
    final anySession = weeks.any(
      (w) => w.sessionsCompleted + w.sessionsInProgress > 0,
    );
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!anySession)
          const RfEmptyState(
            key: Key('training-empty'),
            icon: Icons.fitness_center,
            message: 'No workout recorded in the last 8 weeks.',
          )
        else ...[
          const RfSectionHeader(title: 'Weekly volume'),
          RfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completed working sets, warm-ups excluded. Weeks start on '
                  'the date shown. ${periods.last.dayRule}.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: RfSpace.s3),
                RfTrendChart(
                  key: const Key('training-volume-chart'),
                  series: [
                    RfTrendSeries(label: 'Weekly volume', points: points),
                  ],
                  unit: 'kg',
                  showDataTable: true,
                  emptyMessage: 'No weighted working set in these weeks.',
                ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s3),
          const RfSectionHeader(title: 'Per week'),
          RfCard(
            key: const Key('training-weeks'),
            child: Column(
              children: [
                for (var i = periods.length - 1; i >= 0; i--)
                  FigureRow(
                    key: Key('training-week-${periods.length - 1 - i}'),
                    label: 'Week of ${periods[i].from.iso}',
                    value: _weekLine(weeks[i]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s3),
          const RfSectionHeader(title: 'Exercises this week'),
          if (current.week.byExercise.isEmpty)
            const RfEmptyState(
              key: Key('training-exercises-empty'),
              icon: Icons.list_alt,
              message: 'No completed sets this week.',
            )
          else
            RfCard(
              child: Column(
                children: [
                  for (final e in current.week.byExercise.entries)
                    ListTile(
                      key: Key('training-exercise-${e.key}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(_name(current, e.key)),
                      subtitle: Text(
                        '${e.value.sets} sets · ${_kg(e.value.loadKg)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(RfRoutes.goalsExercise(e.key)),
                    ),
                ],
              ),
            ),
          if (current.recordEvents.isNotEmpty) ...[
            const SizedBox(height: RfSpace.s3),
            const RfSectionHeader(title: 'Records this week'),
            RfCard(
              key: const Key('training-records'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in current.recordEvents)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: RfSpace.s1),
                      child: Text(
                        '${r.date.iso} · ${_name(current, r.exerciseId)}'
                        ' · ${recordText(r)}',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

String _name(WeekTrainingView v, String id) =>
    v.exerciseNames[id] ?? unknownExerciseName;

String _kg(double loadKg) => loadKg > 0
    ? '${formatNumber(loadKg, maxDecimals: 0)} kg'
    : notEnoughDataText;

String _weekLine(WeekTraining w) {
  final parts = [
    '${w.sessionsCompleted} sessions',
    '${w.workingSets} sets',
    metricText(w.totalVolumeKg, decimals: 0, unit: 'kg'),
    if (w.volume.reps > 0) '${w.volume.reps} reps',
    if (w.volume.seconds > 0) '${w.volume.seconds} s',
    if (w.volume.metres > 0)
      '${formatNumber(w.volume.metres, maxDecimals: 0)} m',
  ];
  return parts.join(' · ');
}
