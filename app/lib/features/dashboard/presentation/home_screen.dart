import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';
import 'package:repforge/features/measurements/presentation/weight_providers.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_list_tile.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_stat_tile.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Daily overview. Shows live body-weight data; the nutrition and training
/// panels of the brand mock-up arrive with their work packages and are not
/// mocked here.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String _activityLine(WeightEntry e) {
    final day = DateFormat.MMMd().format(e.recordedAt.toLocal());
    return '$day · ${e.weight.label}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestWeightProvider);
    final entries = ref.watch(weightEntriesProvider);
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
        latest.when(
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
                        : entry.weight.value.toStringAsFixed(1),
                    unit: entry == null ? null : 'kg',
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
        ),
        const SizedBox(height: RfSpace.s4),
        const RfSectionHeader(title: 'Recent activity'),
        entries.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? const RfEmptyState(
                  icon: Icons.monitor_weight_outlined,
                  message: 'Log a weight on the Track tab to see it here.',
                )
              : RfCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RfSpace.s4,
                    vertical: RfSpace.s1,
                  ),
                  child: Column(
                    children: [
                      for (final e in list.take(3))
                        RfListTile(
                          icon: Icons.monitor_weight_outlined,
                          title: 'Weigh-in',
                          subtitle: _activityLine(e),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: RfSpace.s4),
        const RfNotYetAvailable(
          feature: 'Workouts this week, calories left and protein panels',
          workPackage: 'WP 5 (nutrition) and WP 9 (training)',
        ),
        const SizedBox(height: RfSpace.s8),
      ],
    );
  }
}
