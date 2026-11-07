import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/recomposition.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';
import 'package:repforge/features/analytics/presentation/analytics_widgets.dart';
import 'package:repforge/features/training/presentation/exercise_picker.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';
import 'package:repforge/ui/tokens.dart';

/// The exercise chosen for the strength panel, kept for the running session
/// only (it is not stored).
typedef ChosenExercise = ({String id, String name});

class _ChosenExercise extends Notifier<ChosenExercise?> {
  @override
  ChosenExercise? build() => null;

  // Notifier setter is the Riverpod 3 way to change state.
  // ignore: use_setters_to_change_properties
  void choose(ChosenExercise? value) => state = value;
}

final recompositionExerciseProvider =
    NotifierProvider<_ChosenExercise, ChosenExercise?>(_ChosenExercise.new);

/// Recomposition view (GOL-010, plan decision 12b): the weight trend, waist
/// readings and the top-set weight of a chosen exercise as three stacked
/// charts over one date range, each stating how many points it rests on.
class RecompositionScreen extends ConsumerStatefulWidget {
  const RecompositionScreen({super.key});

  @override
  ConsumerState<RecompositionScreen> createState() =>
      _RecompositionScreenState();
}

class _RecompositionScreenState extends ConsumerState<RecompositionScreen> {
  int _weeks = 12;

  AnalyticsPeriod _period() {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final today = CalendarDate.fromInstant(ref.watch(clockProvider).now());
    return AnalyticsPeriod.custom(
      today.addDays(-(_weeks * 7 - 1)),
      today,
      dayStartHour: settings.dayStartHour,
    );
  }

  Future<void> _pick() async {
    final picked = await pickExercise(context);
    if (picked != null) {
      ref.read(recompositionExerciseProvider.notifier).choose((
        id: picked.id,
        name: picked.name,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = _period();
    final chosen = ref.watch(recompositionExerciseProvider);
    final key = (period: period, exerciseId: chosen?.id);
    final series = ref.watch(recompositionSeriesProvider(key));
    return Scaffold(
      appBar: AppBar(title: const Text('Recomposition')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Recomposition',
            caption: 'Weight trend, waist and strength on one date range',
          ),
          SegmentedButton<int>(
            key: const Key('recomposition-range'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 4, label: Text('4 weeks')),
              ButtonSegment(value: 12, label: Text('12 weeks')),
              ButtonSegment(value: 26, label: Text('26 weeks')),
            ],
            selected: {_weeks},
            onSelectionChanged: (s) => setState(() => _weeks = s.first),
          ),
          const SizedBox(height: RfSpace.s2),
          Text(
            'Date range ${rangeText(period.from, period.to)}',
            key: const Key('recomposition-range-label'),
            style: context.rfText.caption,
          ),
          const SizedBox(height: RfSpace.s3),
          RfButton(
            key: const Key('recomposition-exercise-pick'),
            label: chosen == null
                ? 'Choose an exercise for strength'
                : 'Strength: ${chosen.name}',
            icon: Icons.fitness_center,
            variant: RfButtonVariant.secondary,
            onPressed: _pick,
          ),
          const SizedBox(height: RfSpace.s3),
          analyticsWhen<RecompositionSeries>(
            series,
            errorKey: const Key('recomposition-error'),
            onRetry: () => ref.invalidate(recompositionSeriesProvider(key)),
            data: (r) => Column(
              children: [
                _Panel(
                  name: 'weight',
                  data: r.weight,
                  emptyMessage: 'No weight trend value in this range.',
                  marker: RfTrendMarker.circle,
                ),
                _Panel(
                  name: 'waist',
                  data: r.waist,
                  emptyMessage: 'No waist reading in this range.',
                  marker: RfTrendMarker.square,
                ),
                _Panel(
                  name: 'strength',
                  data: r.strength,
                  emptyMessage: chosen == null
                      ? 'No exercise chosen.'
                      : 'No weighted working set of ${chosen.name} in this '
                            'range.',
                  marker: RfTrendMarker.diamond,
                ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.name,
    required this.data,
    required this.emptyMessage,
    required this.marker,
  });

  final String name;
  final SeriesData data;
  final String emptyMessage;
  final RfTrendMarker marker;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RfSpace.s3),
    child: RfCard(
      key: Key('recomposition-panel-$name'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.countText,
            key: Key('recomposition-points-$name'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: RfSpace.s2),
          RfTrendChart(
            key: Key('recomposition-chart-$name'),
            series: [
              RfTrendSeries(
                label: data.name,
                marker: marker,
                points: [
                  for (final p in data.points)
                    RfTrendPoint(
                      DateTime(p.date.year, p.date.month, p.date.day),
                      p.value,
                      joinPrevious: p.joinPrevious,
                    ),
                ],
              ),
            ],
            unit: data.unit,
            height: 160,
            showDataTable: true,
            tableDecimals: 1,
            emptyMessage: emptyMessage,
          ),
        ],
      ),
    ),
  );
}
