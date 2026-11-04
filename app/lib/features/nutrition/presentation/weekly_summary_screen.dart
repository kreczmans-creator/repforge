import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/summaries.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/nutrition/presentation/nutrient_display.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_stat_tile.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Seven-day nutrition summary ending on the selected day (NUT-016): energy,
/// protein, carbohydrate, fat and fibre as the average per logged day and in
/// every day row. Unknown values read "n/a", never 0 (NUT-021).
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
          final totals = w.weekTotals;
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
                _AverageRow(
                  left: _avgTile(
                    const Key('week-avg-kcal'),
                    'Avg calories',
                    avg.kcal,
                    'kcal',
                    targets.kcal,
                    0,
                  ),
                  right: _avgTile(
                    const Key('week-avg-protein'),
                    'Avg protein',
                    avg.proteinG,
                    'g',
                    targets.proteinG,
                    totals.unknownCount(Nutrient.proteinG),
                  ),
                ),
                const SizedBox(height: RfSpace.s3),
                _AverageRow(
                  left: _avgTile(
                    const Key('week-avg-carbs'),
                    'Avg carbs',
                    avg.carbsG,
                    'g',
                    targets.carbsG,
                    totals.unknownCount(Nutrient.carbsG),
                  ),
                  right: _avgTile(
                    const Key('week-avg-fat'),
                    'Avg fat',
                    avg.fatG,
                    'g',
                    targets.fatG,
                    totals.unknownCount(Nutrient.fatG),
                  ),
                ),
                const SizedBox(height: RfSpace.s3),
                _AverageRow(
                  left: _avgTile(
                    const Key('week-avg-fibre'),
                    'Avg fibre',
                    avg.fibreG,
                    'g',
                    targets.fibreG,
                    totals.unknownCount(Nutrient.fibreG),
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
                          totals: w.dayTotals[d],
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

/// One average tile. [value] null means no logged entry knew the nutrient
/// ("n/a"); [unknown] counts entries that lacked it in a partly known total.
Widget _avgTile(
  Key key,
  String label,
  double? value,
  String unit,
  double? target,
  int unknown,
) {
  final parts = <String>[
    if (target != null && target > 0)
      'target ${whole(target)}'
    else ...[
      'per logged day',
      'no target',
    ],
    if (value == null) 'not available' else if (unknown > 0) '$unknown unknown',
  ];
  return RfStatTile(
    key: key,
    label: label,
    value: numberOrNa(value),
    unit: value == null ? null : unit,
    caption: parts.join(' · '),
  );
}

class _AverageRow extends StatelessWidget {
  const _AverageRow({required this.left, this.right});

  final Widget left;
  final Widget? right;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: RfSpace.s3),
        Expanded(child: right ?? const SizedBox.shrink()),
      ],
    ),
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, this.totals, this.targetKcal});

  final String day;
  final NutrientTotals? totals;
  final double? targetKcal;

  static String _measure(String label, NutrientTotals t, Nutrient n) {
    final v = t.known.valueOf(n);
    final marker = v == null ? '' : unknownMarker(t.unknownCount(n));
    return '$label ${gramsOrNa(v)}$marker';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rf = context.rf;
    final t = totals;
    final a = t?.known;
    final fraction = (a == null || targetKcal == null || targetKcal == 0)
        ? null
        : (a.kcal / targetKcal!).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RfSpace.s1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      : '${formatNumber(a.kcal, maxDecimals: 0)} kcal',
                  textAlign: TextAlign.right,
                  style: context.rfText.dataS,
                ),
              ),
            ],
          ),
          if (t != null)
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Text(
                [
                  _measure('P', t, Nutrient.proteinG),
                  _measure('C', t, Nutrient.carbsG),
                  _measure('F', t, Nutrient.fatG),
                  _measure('Fibre', t, Nutrient.fibreG),
                ].join(' · '),
                style: context.rfText.caption,
              ),
            ),
        ],
      ),
    );
  }
}
