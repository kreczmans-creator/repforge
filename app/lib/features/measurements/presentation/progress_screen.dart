import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/progress_summary.dart';
import 'package:repforge/features/measurements/application/measurement_providers.dart';
import 'package:repforge/features/measurements/presentation/measurement_format.dart';
import 'package:repforge/features/measurements/presentation/measurement_widgets.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Progress summary (BCM-008): first value, latest value and difference per
/// type over the chosen period; "Not enough data" for types with fewer than
/// two readings in it.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  MeasurementPeriod _period = MeasurementPeriod.weeks12;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allMeasurementsProvider);
    final now = clockNow(ref);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Progress summary')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Progress summary',
            caption: 'First, latest and change over a period',
          ),
          PeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: RfSpace.s3),
          all.when(
            loading: () => const RfLoading(),
            error: (e, _) => RfErrorState(
              message: 'Could not load your measurements.',
              onRetry: () => ref.invalidate(allMeasurementsProvider),
            ),
            data: (list) {
              final entries = progressSummary(list, _period, now);
              return Column(
                children: [
                  if (list.isEmpty)
                    const RfEmptyState(
                      key: Key('progress-empty'),
                      icon: Icons.trending_up,
                      message:
                          'Nothing measured yet, so there is no progress to '
                          'show.',
                    ),
                  if (list.isEmpty) const SizedBox(height: RfSpace.s3),
                  RfCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RfSpace.s4,
                      vertical: RfSpace.s2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in entries)
                          Padding(
                            key: Key('progress-${e.site.name}'),
                            padding: const EdgeInsets.symmetric(
                              vertical: RfSpace.s2,
                            ),
                            child: switch (e) {
                              SiteProgress() => _ProgressRow(entry: e),
                              NotEnoughData() => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.site.label,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    e.count == 1
                                        ? 'Not enough data (1 reading)'
                                        : 'Not enough data',
                                    style: context.rfText.caption,
                                  ),
                                ],
                              ),
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.entry});

  final SiteProgress entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = entry.change;
    final pct = formatPercentChange(change);
    return Semantics(
      container: true,
      label:
          '${entry.site.label}. First ${formatReading(entry.first)}, latest '
          '${formatReading(entry.latest)}. ${spokenChange(change)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.site.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'First ${formatReading(entry.first)} · '
            'Latest ${formatReading(entry.latest)}',
            style: context.rfText.caption,
          ),
          Wrap(
            spacing: RfSpace.sm,
            children: [
              Text(
                formatAbsoluteChange(change),
                key: Key('change-abs-${entry.site.name}'),
                style: theme.textTheme.bodyMedium,
              ),
              if (pct != null)
                Text(
                  pct,
                  key: Key('change-pct-${entry.site.name}'),
                  style: theme.textTheme.bodyMedium,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
