import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/features/measurements/application/measurement_providers.dart';
import 'package:repforge/features/measurements/presentation/measurement_format.dart';
import 'package:repforge/features/measurements/presentation/measurement_widgets.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Stored readings that cannot be shown (unknown type, or a value outside the
/// accepted range or not in 0.1 steps; possible only through a restored
/// backup). They are listed exactly as stored and can be deleted after a
/// confirmation. They are never edited, corrected or used in charts,
/// summaries or exports.
class UnreadableScreen extends ConsumerWidget {
  const UnreadableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(unreadableMeasurementsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Unreadable readings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Unreadable readings',
            caption: 'Stored values that cannot be shown',
          ),
          Text(
            'These readings are kept exactly as stored. They are not used in '
            'charts, summaries or exports. You can delete them.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: RfSpace.s3),
          async.when(
            loading: () => const RfLoading(),
            error: (e, _) => RfErrorState(
              message: 'Could not load the stored readings.',
              onRetry: () => ref.invalidate(unreadableMeasurementsProvider),
            ),
            data: (list) => list.isEmpty
                ? const RfEmptyState(
                    key: Key('unreadable-empty'),
                    icon: Icons.check_circle_outline,
                    message: 'No unreadable readings.',
                  )
                : RfCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RfSpace.s4,
                      vertical: RfSpace.s1,
                    ),
                    child: Column(
                      children: [
                        for (final u in list)
                          Padding(
                            key: Key('unreadable-${u.id}'),
                            padding: const EdgeInsets.symmetric(
                              vertical: RfSpace.xs,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Value ${u.rawValue}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        'Type: ${u.site}',
                                        style: context.rfText.caption,
                                      ),
                                      Text(
                                        formatWhen(u.recordedAt),
                                        style: context.rfText.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  key: Key('delete-${u.id}'),
                                  tooltip:
                                      'Delete stored reading ${u.rawValue} '
                                      'for ${u.site}',
                                  constraints: const BoxConstraints(
                                    minWidth: rfMinTouchTarget,
                                    minHeight: rfMinTouchTarget,
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => confirmAndDeleteReading(
                                    context,
                                    ref,
                                    id: u.id,
                                    description:
                                        'The stored value ${u.rawValue} '
                                        '(${u.site}) from '
                                        '${formatWhen(u.recordedAt)}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}
