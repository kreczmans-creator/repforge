import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/analytics/goal_progress.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';
import 'package:repforge/features/analytics/presentation/analytics_widgets.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Goals tab: progress of every active goal (GOL-008) and the entries to the
/// editors and the summaries. Text is descriptive only (GOL-011).
class GoalsHomeScreen extends ConsumerStatefulWidget {
  const GoalsHomeScreen({super.key});

  @override
  ConsumerState<GoalsHomeScreen> createState() => _GoalsHomeScreenState();
}

class _GoalsHomeScreenState extends ConsumerState<GoalsHomeScreen> {
  Future<void> _open(String route) => context.push<Object?>(route);

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(goalProgressProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
      children: [
        const RfScreenTitle(
          title: 'Goals',
          caption: 'Targets, progress and summaries',
        ),
        analyticsWhen<List<GoalProgress>>(
          progress,
          errorKey: const Key('goals-error'),
          onRetry: () => ref.invalidate(goalProgressProvider),
          data: (list) => list.isEmpty
              ? const RfEmptyState(
                  key: Key('goals-empty'),
                  icon: Icons.flag_outlined,
                  message: 'No goals set yet.',
                )
              : Column(
                  children: [
                    for (final p in list) ...[
                      _GoalCard(progress: p, onOpen: _open),
                      const SizedBox(height: RfSpace.s3),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: RfSpace.s3),
        const RfSectionHeader(title: 'Set a goal'),
        RfButton(
          key: const Key('goal-set-bodyWeight'),
          label: 'Body weight goal',
          icon: Icons.monitor_weight_outlined,
          variant: RfButtonVariant.secondary,
          onPressed: () => _open(RfRoutes.goalsEdit(GoalKind.bodyWeight)),
        ),
        const SizedBox(height: RfSpace.s2),
        RfButton(
          key: const Key('goal-set-measurement'),
          label: 'Measurement goal',
          icon: Icons.straighten,
          variant: RfButtonVariant.secondary,
          onPressed: () => _open(RfRoutes.goalsEdit(GoalKind.measurement)),
        ),
        const SizedBox(height: RfSpace.s2),
        RfButton(
          key: const Key('goal-set-sessionsPerWeek'),
          label: 'Sessions per week goal',
          icon: Icons.fitness_center,
          variant: RfButtonVariant.secondary,
          onPressed: () => _open(RfRoutes.goalsEdit(GoalKind.sessionsPerWeek)),
        ),
        const SizedBox(height: RfSpace.s2),
        RfButton(
          key: const Key('goals-open-targets'),
          label: 'Daily nutrition targets',
          icon: Icons.restaurant_outlined,
          variant: RfButtonVariant.tertiary,
          onPressed: () => context.push(RfRoutes.settings),
        ),
        const SizedBox(height: RfSpace.s4),
        const RfSectionHeader(title: 'Summaries'),
        RfButton(
          key: const Key('goals-open-weekly'),
          label: 'Weekly summary',
          icon: Icons.calendar_view_week_outlined,
          variant: RfButtonVariant.secondary,
          onPressed: () => context.push(RfRoutes.goalsWeekly),
        ),
        const SizedBox(height: RfSpace.s2),
        RfButton(
          key: const Key('goals-open-compare'),
          label: 'Compare periods',
          icon: Icons.compare_arrows,
          variant: RfButtonVariant.secondary,
          onPressed: () => context.push(RfRoutes.goalsCompare),
        ),
        const SizedBox(height: RfSpace.s2),
        RfButton(
          key: const Key('goals-open-training'),
          label: 'Training analytics',
          icon: Icons.bar_chart,
          variant: RfButtonVariant.secondary,
          onPressed: () => context.push(RfRoutes.goalsTraining),
        ),
        const SizedBox(height: RfSpace.s2),
        RfButton(
          key: const Key('goals-open-recomposition'),
          label: 'Recomposition',
          icon: Icons.stacked_line_chart,
          variant: RfButtonVariant.secondary,
          onPressed: () => context.push(RfRoutes.goalsRecomposition),
        ),
        const SizedBox(height: RfSpace.s2),
        RfButton(
          key: const Key('goals-open-history'),
          label: 'Target history',
          icon: Icons.history,
          variant: RfButtonVariant.secondary,
          onPressed: () => context.push(RfRoutes.goalsHistory),
        ),
        const SizedBox(height: RfSpace.s8),
      ],
    );
  }
}

/// The suffix of a goal card key: the kind, plus the site of a measurement.
String goalKeySuffix(Goal goal) => goal.kind == GoalKind.measurement
    ? 'measurement-${goal.site?.name ?? 'none'}'
    : goal.kind.name;

String _title(Goal goal) => switch (goal.kind) {
  GoalKind.bodyWeight => 'Body weight',
  GoalKind.measurement => goal.site?.label ?? 'Measurement',
  GoalKind.sessionsPerWeek => 'Sessions per week',
  _ => goal.kind.name,
};

String _entriesRoute(GoalProgress p) => switch (p.drillDown.kind) {
  DrillDownKind.weightEntries => RfRoutes.trackSite(MeasurementSite.weight),
  DrillDownKind.measurementEntries =>
    p.drillDown.site == null
        ? RfRoutes.track
        : RfRoutes.trackSite(p.drillDown.site!),
  DrillDownKind.sessions => RfRoutes.trainHistory,
};

String _entriesLabel(GoalProgress p) => switch (p.drillDown.kind) {
  DrillDownKind.weightEntries => 'View weight entries',
  DrillDownKind.measurementEntries => 'View measurement entries',
  DrillDownKind.sessions => 'View workouts',
};

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.progress, required this.onOpen});

  final GoalProgress progress;
  final Future<void> Function(String route) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final goal = p.goal;
    final suffix = goalKeySuffix(goal);
    final theme = Theme.of(context);
    final rf = context.rf;
    final isSessions = goal.kind == GoalKind.sessionsPerWeek;
    final current = p.current;
    final currentText = current.valueOrNull == null
        ? notEnoughDataText
        : isSessions
        ? '${formatNumber(current.valueOrNull!)} sessions'
        : '${formatNumber(current.valueOrNull!)} ${p.unit}';
    final targetText =
        '${formatNumber(goal.target)} ${p.unit}'
        '${goal.endDate == null ? '' : ' by ${_day(goal.endDate!)}'}';
    final percent = p.percent;
    final basis = switch (current) {
      MetricValue<double>(:final basis) => basis.describe(),
      NotEnoughData<double>(:final reason) => reason,
    };
    return RfCard(
      key: Key('goal-card-$suffix'),
      accentEdge: true,
      onTap: () => onOpen(_entriesRoute(p)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title(goal), style: theme.textTheme.titleMedium),
          const SizedBox(height: RfSpace.s2),
          FigureRow(
            key: Key('goal-current-$suffix'),
            label: isSessions ? 'This week' : 'Current',
            value: currentText,
          ),
          FigureRow(
            key: Key('goal-target-$suffix'),
            label: 'Target',
            value: targetText,
          ),
          FigureRow(
            key: Key('goal-percent-$suffix'),
            label: 'Progress',
            value: percent == null
                ? notEnoughDataText
                : '${formatNumber(percent)} %',
          ),
          if (percent != null) ...[
            const SizedBox(height: RfSpace.s1),
            ClipRRect(
              borderRadius: BorderRadius.circular(RfRadius.pill),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0, 1),
                minHeight: 6,
                color: rf.accent,
                backgroundColor: rf.track,
              ),
            ),
          ],
          const SizedBox(height: RfSpace.s2),
          Text(
            p.statement,
            key: Key('goal-statement-$suffix'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: RfSpace.s1),
          Text(
            'Range ${rangeText(p.drillDown.from, p.drillDown.to)}',
            key: Key('goal-range-$suffix'),
            style: context.rfText.caption,
          ),
          Text(
            basis,
            key: Key('goal-basis-$suffix'),
            style: context.rfText.caption,
          ),
          const SizedBox(height: RfSpace.s2),
          Wrap(
            spacing: RfSpace.s2,
            children: [
              TextButton(
                key: Key('goal-entries-$suffix'),
                onPressed: () => onOpen(_entriesRoute(p)),
                child: Text(_entriesLabel(p)),
              ),
              TextButton(
                key: Key('goal-edit-$suffix'),
                onPressed: () =>
                    onOpen(RfRoutes.goalsEdit(goal.kind, goal.site)),
                child: const Text('Edit goal'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The deadline is stored as a UTC calendar date (see `SaveGoal`).
  static String _day(DateTime d) {
    final u = d.toUtc();
    return CalendarDate(u.year, u.month, u.day).iso;
  }
}
