import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/measurements/application/measurement_providers.dart';
import 'package:repforge/features/measurements/presentation/csv_export_action.dart';
import 'package:repforge/features/measurements/presentation/measurement_format.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_list_tile.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Track tab: the 13 measurement types with the latest value and date, an
/// entry action, links to progress and comparison, and a notice when stored
/// readings cannot be shown.
class MeasurementsHomeScreen extends ConsumerStatefulWidget {
  const MeasurementsHomeScreen({super.key});

  @override
  ConsumerState<MeasurementsHomeScreen> createState() =>
      _MeasurementsHomeScreenState();
}

class _MeasurementsHomeScreenState
    extends ConsumerState<MeasurementsHomeScreen> {
  final GlobalKey _exportKey = GlobalKey();
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await runMeasurementsCsvExport(
        context,
        ref,
        anchorContext: _exportKey.currentContext,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allMeasurementsProvider);
    final unreadable = ref.watch(unreadableMeasurementCountProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
      children: [
        const RfScreenTitle(
          title: 'Track',
          caption: 'Body weight and measurements',
        ),
        RfButton(
          key: const Key('log-weight'),
          label: 'Log weight',
          icon: Icons.monitor_weight_outlined,
          onPressed: () =>
              context.push(RfRoutes.trackEntryFor(MeasurementSite.weight)),
        ),
        const SizedBox(height: RfSpace.sm),
        RfButton(
          key: const Key('add-measurements'),
          label: 'Add measurements',
          variant: RfButtonVariant.secondary,
          icon: Icons.add,
          onPressed: () => context.push(RfRoutes.trackEntry),
        ),
        const SizedBox(height: RfSpace.sm),
        RfButton(
          key: const Key('open-progress'),
          label: 'Progress summary',
          variant: RfButtonVariant.secondary,
          icon: Icons.trending_up,
          onPressed: () => context.push(RfRoutes.trackProgress),
        ),
        const SizedBox(height: RfSpace.sm),
        RfButton(
          key: const Key('open-compare'),
          label: 'Compare',
          variant: RfButtonVariant.secondary,
          icon: Icons.compare_arrows,
          onPressed: () => context.push(RfRoutes.trackCompare()),
        ),
        const SizedBox(height: RfSpace.sm),
        KeyedSubtree(
          key: _exportKey,
          child: RfButton(
            key: const Key('export-csv'),
            label: 'Export CSV',
            variant: RfButtonVariant.secondary,
            icon: Icons.ios_share,
            loading: _exporting,
            onPressed: _export,
          ),
        ),
        if (unreadable > 0) ...[
          const SizedBox(height: RfSpace.s4),
          RfCard(
            key: const Key('unreadable-notice'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: context.rf.alert,
                      size: RfIcon.md,
                    ),
                    const SizedBox(width: RfSpace.s3),
                    Expanded(
                      child: Text(
                        unreadable == 1
                            ? '1 stored reading cannot be shown'
                            : '$unreadable stored readings cannot be shown',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  key: const Key('open-unreadable'),
                  onPressed: () => context.push(RfRoutes.trackUnreadable),
                  child: const Text('See details'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: RfSpace.s4),
        const RfSectionHeader(title: 'Measurements'),
        all.when(
          loading: () => const RfLoading(),
          error: (e, _) => RfErrorState(
            message: 'Could not load your measurements.',
            onRetry: () => ref.invalidate(allMeasurementsProvider),
          ),
          data: (list) {
            final latest = latestPerSite(list);
            return Column(
              children: [
                if (list.isEmpty)
                  const RfEmptyState(
                    key: Key('measurements-empty'),
                    icon: Icons.straighten,
                    message:
                        'Nothing measured yet. Use Add measurements to log '
                        'your first reading.',
                  ),
                if (list.isEmpty) const SizedBox(height: RfSpace.s3),
                RfCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RfSpace.s4,
                    vertical: RfSpace.s1,
                  ),
                  child: Column(
                    children: [
                      for (final site in MeasurementSite.values)
                        RfListTile(
                          key: Key('site-${site.name}'),
                          icon: site.isWeight
                              ? Icons.monitor_weight_outlined
                              : Icons.straighten,
                          title: site.label,
                          subtitle: latest[site] == null
                              ? 'No readings yet'
                              : '${formatReading(latest[site]!)} · '
                                    '${formatDay(latest[site]!.recordedAt)}',
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(RfRoutes.trackSite(site)),
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
    );
  }
}
