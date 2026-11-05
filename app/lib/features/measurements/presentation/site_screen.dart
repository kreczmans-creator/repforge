import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurement_site_help.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/measurements/application/measurement_providers.dart';
import 'package:repforge/features/measurements/presentation/measurement_chart_data.dart';
import 'package:repforge/features/measurements/presentation/measurement_edit_sheet.dart';
import 'package:repforge/features/measurements/presentation/measurement_format.dart';
import 'package:repforge/features/measurements/presentation/measurement_widgets.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';
import 'package:repforge/ui/tokens.dart';

/// One measurement type: trend chart with a period selector (BCM-005, BCM-006,
/// UXD-009) and its history, newest first, with edit and delete (BCM-004).
/// Everything is driven by the live streams, so an edit or delete changes the
/// chart, summary and list at once.
class SiteScreen extends ConsumerStatefulWidget {
  const SiteScreen({required this.site, super.key});

  final MeasurementSite site;

  @override
  ConsumerState<SiteScreen> createState() => _SiteScreenState();
}

class _SiteScreenState extends ConsumerState<SiteScreen> {
  MeasurementPeriod _period = MeasurementPeriod.weeks12;

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final own = ref.watch(measurementsForSiteProvider(site));
    final other = site.counterpart;
    final otherAsync = other == null
        ? const AsyncData<List<Measurement>>([])
        : ref.watch(measurementsForSiteProvider(other));
    final now = clockNow(ref);
    return Scaffold(
      appBar: AppBar(title: Text(site.label)),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: RfSpace.s3),
                PeriodSelector(
                  selected: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
                const SizedBox(height: RfSpace.s3),
                if (own.hasError || otherAsync.hasError)
                  RfErrorState(
                    message:
                        'Could not load ${site.label.toLowerCase()} readings.',
                    onRetry: () {
                      ref.invalidate(measurementsForSiteProvider(site));
                      if (other != null) {
                        ref.invalidate(measurementsForSiteProvider(other));
                      }
                    },
                  )
                else if (!own.hasValue || !otherAsync.hasValue)
                  const RfLoading(),
              ]),
            ),
          ),
          if (own.hasValue && otherAsync.hasValue)
            ..._content(
              context,
              own.requireValue,
              otherAsync.requireValue,
              now,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: RfSpace.s8)),
        ],
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    List<Measurement> mine,
    List<Measurement> theirs,
    DateTime now,
  ) {
    final data = siteChartData(widget.site, [...mine, ...theirs], _period, now);
    final theme = Theme.of(context);
    const pad = EdgeInsets.symmetric(horizontal: RfSpace.gutter);
    return [
      SliverPadding(
        padding: pad,
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            RfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.summary,
                    key: const Key('chart-summary'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: RfSpace.s3),
                  RfTrendChart(
                    key: const Key('site-chart'),
                    series: data.series,
                    unit: data.unit,
                    showDataTable: true,
                    tableDecimals: 1,
                    emptyMessage: 'No readings in this period.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: RfSpace.s3),
            RfButton(
              key: const Key('add-measurement'),
              label: 'Add measurement',
              icon: Icons.add,
              onPressed: () => context.push(RfRoutes.trackEntry),
            ),
            const SizedBox(height: RfSpace.sm),
            RfButton(
              key: const Key('compare-site'),
              label: 'Compare',
              variant: RfButtonVariant.secondary,
              icon: Icons.compare_arrows,
              onPressed: () => context.push(RfRoutes.trackCompare(widget.site)),
            ),
            const SizedBox(height: RfSpace.s4),
            const RfSectionHeader(title: 'History'),
            if (mine.isEmpty)
              RfEmptyState(
                key: const Key('site-empty'),
                icon: Icons.straighten,
                message:
                    'No ${widget.site.label.toLowerCase()} readings yet. Use '
                    'Add measurement to log one.',
              ),
          ]),
        ),
      ),
      // The history is a lazy sliver list: only visible rows are built.
      SliverPadding(
        padding: pad,
        sliver: SliverList.separated(
          itemCount: mine.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _ReadingRow(measurement: mine[i]),
        ),
      ),
    ];
  }
}

class _ReadingRow extends ConsumerWidget {
  const _ReadingRow({required this.measurement});

  final Measurement measurement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = measurement;
    final theme = Theme.of(context);
    final description = '${formatReading(m)} on ${formatWhen(m.recordedAt)}';
    return Padding(
      key: Key('reading-${m.id}'),
      padding: const EdgeInsets.symmetric(vertical: RfSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatReading(m),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(formatWhen(m.recordedAt), style: context.rfText.caption),
                if (m.note != null)
                  Text(m.note!, style: context.rfText.caption),
              ],
            ),
          ),
          IconButton(
            key: Key('edit-${m.id}'),
            tooltip: 'Edit reading $description',
            icon: const Icon(Icons.edit_outlined),
            constraints: const BoxConstraints(
              minWidth: rfMinTouchTarget,
              minHeight: rfMinTouchTarget,
            ),
            onPressed: () => showMeasurementEditSheet(context, m),
          ),
          IconButton(
            key: Key('delete-${m.id}'),
            tooltip: 'Delete reading $description',
            icon: const Icon(Icons.delete_outline),
            constraints: const BoxConstraints(
              minWidth: rfMinTouchTarget,
              minHeight: rfMinTouchTarget,
            ),
            onPressed: () => confirmAndDeleteReading(
              context,
              ref,
              id: m.id,
              description: description,
            ),
          ),
        ],
      ),
    );
  }
}
