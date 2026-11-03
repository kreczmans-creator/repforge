import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/summaries.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_stat_tile.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Seven-day nutrition summary ending on the selected day (NUT-021).
class WeeklySummaryScreen extends ConsumerWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weeklySummaryProvider);
    final targets = ref.watch(dailyTargetsProvider).value ?? DailyTargets.none;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Last 7 days')),
      body: week.when(
        loading: () => const RfLoading(),
        error: (e, _) =>
            const RfErrorState(message: 'Could not load the week.'),
        data: (w) {
          final avg = w.averagePerLoggedDay;
          final days = lastSevenDays(DateTime.parse(w.toDay));
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
            children: [
              RfScreenTitle(
                title: 'Last 7 days',
                caption:
                    '${DateFormat.MMMd().format(DateTime.parse(w.fromDay))} to '
                    '${DateFormat.MMMd().format(DateTime.parse(w.toDay))} · '
                    '${w.loggedDays} of 7 days logged',
              ),
              if (avg == null)
                const RfEmptyState(
                  key: Key('week-empty'),
                  icon: Icons.calendar_view_week_outlined,
                  message: 'Nothing logged in this period.',
                )
              else ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: RfStatTile(
                          key: const Key('week-avg-kcal'),
                          label: 'Avg calories',
                          value: formatNumber(avg.kcal, maxDecimals: 0),
                          unit: 'kcal',
                          caption: targets.kcal == null
                              ? 'per logged day'
                              : 'target ${whole(targets.kcal!)}',
                        ),
                      ),
                      const SizedBox(width: RfSpace.s3),
                      Expanded(
                        child: RfStatTile(
                          label: 'Avg protein',
                          value: formatNumber(avg.proteinG, maxDecimals: 0),
                          unit: 'g',
                          caption: targets.proteinG == null
                              ? 'per logged day'
                              : 'target ${whole(targets.proteinG!)}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RfSpace.s4),
                const RfSectionHeader(title: 'By day'),
                RfCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RfSpace.s4,
                    vertical: RfSpace.s2,
                  ),
                  child: Column(
                    children: [
                      for (final d in days)
                        _DayRow(
                          day: d,
                          amounts: w.perDay[d],
                          targetKcal: targets.kcal,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: RfSpace.s3),
                Text(
                  'Averages use only the days with at least one entry.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: RfSpace.s8),
            ],
          );
        },
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, this.amounts, this.targetKcal});

  final String day;
  final NutrientAmounts? amounts;
  final double? targetKcal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rf = context.rf;
    final a = amounts;
    final fraction = (a == null || targetKcal == null || targetKcal == 0)
        ? null
        : (a.kcal / targetKcal!).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RfSpace.s1),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              DateFormat.E().format(DateTime.parse(day)),
              style: theme.textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: a == null
                ? Text('—', style: theme.textTheme.bodySmall)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(RfRadius.pill),
                    child: LinearProgressIndicator(
                      value: fraction ?? 0,
                      minHeight: 6,
                      color: rf.accent,
                      backgroundColor: rf.track,
                    ),
                  ),
          ),
          const SizedBox(width: RfSpace.s3),
          SizedBox(
            width: 96,
            child: Text(
              a == null
                  ? 'not logged'
                  : '${formatNumber(a.kcal, maxDecimals: 0)} kcal · '
                        'P ${formatNumber(a.proteinG, maxDecimals: 0)}',
              textAlign: TextAlign.right,
              style: context.rfText.dataS,
            ),
          ),
        ],
      ),
    );
  }
}
