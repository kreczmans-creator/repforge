import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/display.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/features/measurements/presentation/weight_providers.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_list_tile.dart';
import 'package:repforge/ui/components/rf_macro_bar.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_stat_tile.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Daily overview ("cockpit"): nutrition vs targets, next session, latest
/// weight and recent activity, all live from the database. Every panel has
/// an explicit empty state; nothing is mocked.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).now().toLocal();
    final date = DateFormat('EEEE d MMMM').format(now);
    final greeting = switch (now.hour) {
      < 12 => 'Good morning',
      < 18 => 'Good afternoon',
      _ => 'Good evening',
    };

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
      children: [
        RfScreenTitle(title: greeting, caption: date),
        const _NutritionPanel(),
        const SizedBox(height: RfSpace.s4),
        const RfSectionHeader(title: 'Training'),
        const _TrainingPanel(),
        const SizedBox(height: RfSpace.s4),
        const RfSectionHeader(title: 'Body'),
        const _BodyPanel(),
        const SizedBox(height: RfSpace.s4),
        const RfSectionHeader(title: 'Recent activity'),
        const _ActivityPanel(),
        const SizedBox(height: RfSpace.s8),
      ],
    );
  }
}

class _NutritionPanel extends ConsumerWidget {
  const _NutritionPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySummaryProvider);
    return summary.when(
      loading: () => const RfLoading(),
      error: (e, _) =>
          const RfErrorState(message: "Could not load today's nutrition."),
      data: (s) {
        final t = s.targets;
        final remaining = s.kcalRemaining;
        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: RfStatTile(
                      key: const Key('kcal-tile'),
                      label: remaining == null ? 'Calories' : 'Calories left',
                      value: _n(remaining ?? s.intake.kcal),
                      unit: 'kcal',
                      progress: t.kcal == null || t.kcal == 0
                          ? null
                          : s.intake.kcal / t.kcal!,
                      caption: t.kcal == null
                          ? 'No target set'
                          : '${_n(s.intake.kcal)} of ${_n(t.kcal!)}',
                    ),
                  ),
                  const SizedBox(width: RfSpace.s3),
                  Expanded(
                    child: RfStatTile(
                      key: const Key('protein-tile'),
                      label: 'Protein',
                      // TODO(D1-ui): unknown value rendered as 0
                      // until the UI agent handles it
                      value: _n(s.intake.proteinG ?? 0),
                      unit: 'g',
                      progress: t.proteinG == null || t.proteinG == 0
                          ? null
                          // TODO(D1-ui): unknown value rendered as 0
                          // until the UI agent handles it
                          : (s.intake.proteinG ?? 0) / t.proteinG!,
                      caption: t.proteinG == null
                          ? 'No target set'
                          : 'of ${_n(t.proteinG!)} g',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RfSpace.s3),
            if (s.entryCount == 0 && t.isEmpty)
              const RfEmptyState(
                key: Key('nutrition-empty'),
                icon: Icons.restaurant_outlined,
                message:
                    'Set daily targets in Settings; food logging arrives '
                    'with the Fuel work package.',
              )
            else
              RfCard(
                child: Column(
                  children: [
                    RfMacroBar(
                      label: 'Protein',
                      // TODO(D1-ui): unknown value rendered as 0
                      // until the UI agent handles it
                      amount: s.intake.proteinG ?? 0,
                      target: t.proteinG ?? 0,
                    ),
                    RfMacroBar(
                      label: 'Carbs',
                      // TODO(D1-ui): unknown value rendered as 0
                      // until the UI agent handles it
                      amount: s.intake.carbsG ?? 0,
                      target: t.carbsG ?? 0,
                      color: context.rf.textSecondary,
                    ),
                    RfMacroBar(
                      label: 'Fat',
                      // TODO(D1-ui): unknown value rendered as 0
                      // until the UI agent handles it
                      amount: s.intake.fatG ?? 0,
                      target: t.fatG ?? 0,
                      color: context.rf.textSecondary,
                    ),
                    if (t.fibreG != null)
                      RfMacroBar(
                        label: 'Fibre',
                        amount: s.intake.fibreG ?? 0,
                        target: t.fibreG!,
                        color: context.rf.textSecondary,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static String _n(double v) => v.round().toString();
}

class _TrainingPanel extends ConsumerWidget {
  const _TrainingPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    final sessions = ref.watch(recentSessionsProvider);
    return plans.when(
      loading: () => const RfLoading(),
      error: (e, _) => const RfErrorState(message: 'Could not load plans.'),
      data: (list) {
        final count = sessions.value?.length ?? 0;
        if (list.isEmpty) {
          return RfEmptyState(
            key: const Key('training-empty'),
            icon: Icons.fitness_center_outlined,
            message: count == 0
                ? 'No workout plans yet. Plans and session logging arrive '
                      'with the Train work packages.'
                : '$count recent session(s). No plan scheduled.',
          );
        }
        // Scheduling (which plan is next) arrives in WP 9; until then the
        // panel reports what exists without guessing an order.
        final names = list.take(3).map((p) => p.name).join(' · ');
        return RfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PLANS', style: context.rfText.kicker),
              const SizedBox(height: RfSpace.s1),
              Text(
                '${list.length} plan${list.length == 1 ? '' : 's'}'
                '${count == 0 ? '' : ' · $count recent session(s)'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(names, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}

class _BodyPanel extends ConsumerWidget {
  const _BodyPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestWeightProvider);
    final entries = ref.watch(weightEntriesProvider);
    final units =
        ref.watch(settingsProvider.select((s) => s.value?.units)) ??
        UnitSystem.metric;
    return latest.when(
      loading: () => const RfLoading(),
      error: (e, _) =>
          const RfErrorState(message: 'Could not load body weight.'),
      data: (entry) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RfStatTile(
                key: const Key('latest-weight'),
                label: 'Latest weight',
                value: entry == null
                    ? '—'
                    : bodyWeightParts(entry.weight, units).value,
                unit: entry == null
                    ? null
                    : bodyWeightParts(entry.weight, units).unit,
                caption: entry == null
                    ? 'Nothing logged yet'
                    : DateFormat.yMMMd().format(entry.recordedAt.toLocal()),
              ),
            ),
            const SizedBox(width: RfSpace.s3),
            Expanded(
              child: RfStatTile(
                key: const Key('weight-count'),
                label: 'Entries',
                value: '${entries.value?.length ?? 0}',
                caption: 'body-weight records',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityPanel extends ConsumerWidget {
  const _ActivityPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightsAsync = ref.watch(weightEntriesProvider);
    final sessionsAsync = ref.watch(recentSessionsProvider);
    final units =
        ref.watch(settingsProvider.select((s) => s.value?.units)) ??
        UnitSystem.metric;
    if (weightsAsync.isLoading || sessionsAsync.isLoading) {
      return const RfLoading();
    }
    if (weightsAsync.hasError || sessionsAsync.hasError) {
      return const RfErrorState(message: 'Could not load recent activity.');
    }
    final weights = weightsAsync.value ?? const [];
    final sessions = sessionsAsync.value ?? const [];
    final items = <_Activity>[
      for (final e in weights.take(5))
        _Activity(
          at: e.recordedAt,
          icon: Icons.monitor_weight_outlined,
          title: 'Weigh-in',
          subtitle: formatBodyWeight(e.weight, units),
        ),
      for (final s in sessions)
        _Activity(
          at: s.startedAt,
          icon: Icons.fitness_center,
          title: s.name,
          subtitle: _sessionLine(s),
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    if (items.isEmpty) {
      return const RfEmptyState(
        key: Key('activity-empty'),
        icon: Icons.history,
        message: 'Log a weight on the Track tab to see it here.',
      );
    }
    return RfCard(
      padding: const EdgeInsets.symmetric(
        horizontal: RfSpace.s4,
        vertical: RfSpace.s1,
      ),
      child: Column(
        children: [
          for (final a in items.take(5))
            RfListTile(
              icon: a.icon,
              title: a.title,
              subtitle:
                  '${DateFormat.MMMd().format(a.at.toLocal())} · ${a.subtitle}',
            ),
        ],
      ),
    );
  }

  static String _sessionLine(WorkoutSession s) {
    final sets = s.sets.where((x) => x.completed).length;
    return '$sets sets';
  }
}

final class _Activity {
  const _Activity({
    required this.at,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final DateTime at;
  final IconData icon;
  final String title;
  final String subtitle;
}
