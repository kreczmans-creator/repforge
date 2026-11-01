import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/features/measurements/presentation/weight_providers.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_stat_tile.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Daily overview. In WP 1 it shows body weight only; nutrition and training
/// panels arrive with their work packages and are not mocked here.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestWeightProvider);
    final entries = ref.watch(weightEntriesProvider);
    final theme = Theme.of(context);
    final today = DateFormat('EEEE, d MMMM')
        .format(ref.watch(clockProvider).now().toLocal());

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: RfSpace.lg),
          children: [
            RfScreenTitle(kicker: today, title: 'Your cockpit'),
            latest.when(
              loading: () => const RfLoading(),
              error: (e, _) =>
                  const RfErrorState(message: 'Could not load body weight.'),
              data: (entry) => Row(
                children: [
                  Expanded(
                    child: RfStatTile(
                      key: const Key('latest-weight'),
                      label: 'Latest weight',
                      value: entry?.weight.label ?? '—',
                      caption: entry == null
                          ? 'Nothing logged yet'
                          : DateFormat.yMMMd().format(
                              entry.recordedAt.toLocal(),
                            ),
                    ),
                  ),
                  const SizedBox(width: RfSpace.md),
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
            const SizedBox(height: RfSpace.lg),
            RfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scope of this build',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: RfSpace.sm),
                  Text(
                    'WP 1 foundation: body-weight logging only. Nutrition, '
                    'recipes, training, measurements and goals are delivered '
                    'in later work packages and are intentionally absent here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RfSpace.xxl),
          ],
        ),
      ),
    );
  }
}
