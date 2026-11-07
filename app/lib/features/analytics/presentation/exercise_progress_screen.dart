import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';
import 'package:repforge/features/analytics/application/training_use_cases.dart';
import 'package:repforge/features/analytics/presentation/analytics_widgets.dart';
import 'package:repforge/features/analytics/presentation/record_text.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';
import 'package:repforge/ui/tokens.dart';

/// Progress of one exercise (TRN-028): top-set weight and session volume over
/// time, how the latest session compares with the one before it, and the
/// records set. Statements are descriptive only.
class ExerciseProgressScreen extends ConsumerStatefulWidget {
  const ExerciseProgressScreen({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  ConsumerState<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState
    extends ConsumerState<ExerciseProgressScreen> {
  @override
  Widget build(BuildContext context) {
    final view = ref.watch(exerciseProgressProvider(widget.exerciseId));
    return Scaffold(
      appBar: AppBar(
        title: Text(view.value?.exerciseName ?? 'Exercise progress'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          RfScreenTitle(
            title: view.value?.exerciseName ?? 'Exercise progress',
            caption: 'Top set and volume per session',
          ),
          analyticsWhen<ExerciseProgressView>(
            view,
            errorKey: const Key('exercise-progress-error'),
            onRetry: () =>
                ref.invalidate(exerciseProgressProvider(widget.exerciseId)),
            data: (v) => _Body(view: v),
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

DateTime _at(CalendarDate d) => DateTime(d.year, d.month, d.day);

class _Body extends StatelessWidget {
  const _Body({required this.view});

  final ExerciseProgressView view;

  List<RfTrendPoint> _points(
    List<ExerciseProgressPoint> points,
    double? Function(ExerciseProgressPoint) valueOf,
  ) {
    final out = <RfTrendPoint>[];
    CalendarDate? prev;
    for (final p in points) {
      final v = valueOf(p);
      if (v == null) continue;
      out.add(
        RfTrendPoint(
          _at(p.date),
          v,
          joinPrevious:
              prev != null && prev.daysUntil(p.date) <= chartJoinMaxDayGap,
        ),
      );
      prev = p.date;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final progress = view.progress;
    if (progress.isEmpty) {
      return const RfEmptyState(
        key: Key('exercise-progress-empty'),
        icon: Icons.show_chart,
        message: 'No completed sets for this exercise yet.',
      );
    }
    final latest = progress.latest!;
    String statement(String name, TrendStatement? s) =>
        '$name: ${s?.label ?? notEnoughDataText}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RfCard(
          key: const Key('exercise-statements'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Latest session, ${latest.date.iso}, against the previous one',
                style: context.rfText.caption,
              ),
              const SizedBox(height: RfSpace.s2),
              Text(
                statement('Top set weight', latest.topSetStatement),
                key: const Key('exercise-progress-statement-topSet'),
              ),
              const SizedBox(height: RfSpace.s1),
              Text(
                statement('Session volume', latest.volumeStatement),
                key: const Key('exercise-progress-statement-volume'),
              ),
            ],
          ),
        ),
        const SizedBox(height: RfSpace.s3),
        const RfSectionHeader(title: 'Top set weight'),
        RfCard(
          child: RfTrendChart(
            key: const Key('exercise-progress-chart'),
            series: [
              RfTrendSeries(
                label: 'Top set weight',
                points: _points(progress.points, (p) => p.topSetWeightKg),
              ),
            ],
            unit: 'kg',
            showDataTable: true,
            emptyMessage: 'No weighted working set yet.',
          ),
        ),
        const SizedBox(height: RfSpace.s3),
        const RfSectionHeader(title: 'Session volume'),
        RfCard(
          child: RfTrendChart(
            key: const Key('exercise-volume-chart'),
            series: [
              RfTrendSeries(
                label: 'Session volume',
                marker: RfTrendMarker.square,
                dashed: true,
                points: _points(progress.points, (p) => p.volumeKg),
              ),
            ],
            unit: 'kg',
            showDataTable: true,
            emptyMessage: 'No weighted working set yet.',
          ),
        ),
        const SizedBox(height: RfSpace.s3),
        const RfSectionHeader(title: 'Records (all time)'),
        if (view.recordEvents.isEmpty)
          const RfEmptyState(
            key: Key('exercise-records-empty'),
            icon: Icons.emoji_events_outlined,
            message: 'No records set yet.',
          )
        else
          RfCard(
            key: const Key('exercise-records'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in view.recordEvents.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: RfSpace.s1),
                    child: Text('${r.date.iso} · ${recordText(r)}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
