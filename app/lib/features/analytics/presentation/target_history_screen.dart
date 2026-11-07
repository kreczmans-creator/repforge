import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/analytics/target_history.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';
import 'package:repforge/features/analytics/presentation/analytics_widgets.dart';
import 'package:repforge/features/analytics/presentation/goal_labels.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Target history (GOL-006(2)): for every kind (and body site) the periods
/// during which each target value was in effect.
class TargetHistoryScreen extends ConsumerStatefulWidget {
  const TargetHistoryScreen({super.key});

  @override
  ConsumerState<TargetHistoryScreen> createState() =>
      _TargetHistoryScreenState();
}

class _TargetHistoryScreenState extends ConsumerState<TargetHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final history = ref.watch(targetHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Target history')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Target history',
            caption: 'What each target was, and from when to when',
          ),
          analyticsWhen<TargetHistory>(
            history,
            errorKey: const Key('target-history-error'),
            onRetry: () => ref.invalidate(targetHistoryProvider),
            data: (h) => h.allPeriods.isEmpty
                ? const RfEmptyState(
                    key: Key('target-history-empty'),
                    icon: Icons.history,
                    message: 'No target has been set yet.',
                  )
                : _List(periods: h.allPeriods),
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.periods});

  final List<TargetPeriod> periods;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    (GoalKind, MeasurementSite?)? group;
    for (var i = 0; i < periods.length; i++) {
      final p = periods[i];
      final key = (p.kind, p.site);
      final siteSuffix = p.site == null ? '' : '-${p.site!.name}';
      if (key != group) {
        group = key;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: RfSpace.s3, bottom: RfSpace.s1),
            child: Text(
              goalGroupLabel(p.kind, p.site),
              key: Key('target-group-${p.kind.name}$siteSuffix'),
              style: theme.textTheme.titleMedium,
            ),
          ),
        );
      }
      final unit = goalUnit(p.kind, p.site);
      children.add(
        Padding(
          key: Key('target-period-$i'),
          padding: const EdgeInsets.symmetric(vertical: RfSpace.s2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatNumber(p.target)} $unit',
                style: context.rfText.dataM,
              ),
              Text(
                p.replacedSameDay
                    ? 'Set on ${p.effectiveFrom.iso}, replaced the same day '
                          '(applied on no day)'
                    : 'From ${p.effectiveFrom.iso} to '
                          '${p.effectiveTo?.iso ?? 'current'}',
                key: Key('target-period-text-$i'),
                style: context.rfText.caption,
              ),
            ],
          ),
        ),
      );
    }
    return RfCard(
      key: const Key('target-history-list'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
