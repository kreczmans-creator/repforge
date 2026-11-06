import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurement_comparison.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/measurements/application/measurement_providers.dart';
import 'package:repforge/features/measurements/presentation/measurement_format.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Comparison of one measurement type between two dates or two periods
/// (BCM-007, owner decision D4).
///
/// Dates: an exact reading is shown at once. A date without a reading shows
/// the nearest earlier and later readings with their actual dates, and no
/// change is shown until the user has chosen one for every such date; nothing
/// is substituted silently. Periods: the mean of the readings with the number
/// of readings in each period. The change is absolute and percent of the
/// earlier value.
class ComparisonScreen extends ConsumerStatefulWidget {
  const ComparisonScreen({
    super.key,
    this.site,
    this.periods = false,
    this.dateA,
    this.dateB,
    this.periodA,
    this.periodB,
  });

  /// Initial type; defaults to weight.
  final MeasurementSite? site;

  /// Start in period mode.
  final bool periods;

  /// Initial dates / periods; defaults are today and 28 days earlier, and the
  /// two latest 4-week periods.
  final CalendarDate? dateA;
  final CalendarDate? dateB;
  final DateRange? periodA;
  final DateRange? periodB;

  @override
  ConsumerState<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends ConsumerState<ComparisonScreen> {
  late MeasurementSite _site = widget.site ?? MeasurementSite.weight;
  late bool _periods = widget.periods;
  late CalendarDate _dateA;
  late CalendarDate _dateB;
  late DateRange _rangeA;
  late DateRange _rangeB;

  /// The user's choice per requested date that had no exact reading.
  final _choices = <CalendarDate, String>{};

  @override
  void initState() {
    super.initState();
    final today = CalendarDate.fromInstant(ref.read(clockProvider).now());
    _dateA = widget.dateA ?? today.addDays(-28);
    _dateB = widget.dateB ?? today;
    _rangeA =
        widget.periodA ?? DateRange(today.addDays(-55), today.addDays(-28));
    _rangeB = widget.periodB ?? DateRange(today.addDays(-27), today);
  }

  DateTime _dt(CalendarDate d) => DateTime(d.year, d.month, d.day);
  CalendarDate _cd(DateTime d) => CalendarDate(d.year, d.month, d.day);

  Future<void> _pickDate(bool first) async {
    final today = CalendarDate.fromInstant(ref.read(clockProvider).now());
    final current = first ? _dateA : _dateB;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dt(current),
      firstDate: DateTime(2000),
      lastDate: _dt(today),
    );
    if (picked == null) return;
    setState(() {
      if (first) {
        _dateA = _cd(picked);
      } else {
        _dateB = _cd(picked);
      }
      _choices.clear();
    });
  }

  Future<void> _pickPeriod(bool first) async {
    final today = CalendarDate.fromInstant(ref.read(clockProvider).now());
    final current = first ? _rangeA : _rangeB;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: _dt(today),
      initialDateRange: DateTimeRange(
        start: _dt(current.start),
        end: _dt(current.end),
      ),
    );
    if (picked == null) return;
    setState(() {
      final r = DateRange(_cd(picked.start), _cd(picked.end));
      if (first) {
        _rangeA = r;
      } else {
        _rangeB = r;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allMeasurementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Compare')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Compare',
            caption: 'Two dates or two periods',
          ),
          DropdownMenu<MeasurementSite>(
            key: const Key('compare-site-picker'),
            label: const Text('Measurement type'),
            initialSelection: _site,
            expandedInsets: EdgeInsets.zero,
            requestFocusOnTap: false,
            dropdownMenuEntries: [
              for (final s in MeasurementSite.values)
                DropdownMenuEntry(value: s, label: s.label),
            ],
            onSelected: (s) {
              if (s == null) return;
              setState(() {
                _site = s;
                _choices.clear();
              });
            },
          ),
          const SizedBox(height: RfSpace.s3),
          SegmentedButton<bool>(
            key: const Key('compare-mode'),
            segments: const [
              ButtonSegment(value: false, label: Text('Dates')),
              ButtonSegment(value: true, label: Text('Periods')),
            ],
            selected: {_periods},
            onSelectionChanged: (v) => setState(() => _periods = v.first),
          ),
          const SizedBox(height: RfSpace.s3),
          if (_periods) ..._periodPickers() else ..._datePickers(),
          const SizedBox(height: RfSpace.s3),
          all.when(
            loading: () => const RfLoading(),
            error: (e, _) => RfErrorState(
              message: 'Could not load your measurements.',
              onRetry: () => ref.invalidate(allMeasurementsProvider),
            ),
            data: (list) => _periods ? _periodResult(list) : _dateResult(list),
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }

  List<Widget> _datePickers() => [
    OutlinedButton(
      key: const Key('compare-date-a'),
      onPressed: () => _pickDate(true),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('Date A: ${formatCalendarDate(_dateA)}'),
      ),
    ),
    const SizedBox(height: RfSpace.sm),
    OutlinedButton(
      key: const Key('compare-date-b'),
      onPressed: () => _pickDate(false),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('Date B: ${formatCalendarDate(_dateB)}'),
      ),
    ),
  ];

  List<Widget> _periodPickers() => [
    OutlinedButton(
      key: const Key('compare-period-a'),
      onPressed: () => _pickPeriod(true),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Period A: ${formatCalendarDate(_rangeA.start)} to '
          '${formatCalendarDate(_rangeA.end)}',
        ),
      ),
    ),
    const SizedBox(height: RfSpace.sm),
    OutlinedButton(
      key: const Key('compare-period-b'),
      onPressed: () => _pickPeriod(false),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Period B: ${formatCalendarDate(_rangeB.start)} to '
          '${formatCalendarDate(_rangeB.end)}',
        ),
      ),
    ),
  ];

  // ---- dates ----

  Widget _dateResult(List<Measurement> list) {
    final c = compareDates(list, _site, _dateA, _dateB);
    final first = _resolved(c.earlier);
    final second = _resolved(c.later);
    // The chosen readings can be in either order (a later reading chosen for
    // the earlier date): the change always runs from the older reading to
    // the newer one.
    final ordered = first != null && second != null
        ? (first.recordedAt.isAfter(second.recordedAt)
              ? (second, first)
              : (first, second))
        : null;
    final change = ordered == null
        ? null
        : changeBetweenReadings(ordered.$1, ordered.$2);
    final same = first != null && second != null && first.id == second.id;
    final pending = [
      c.earlier,
      c.later,
    ].any((o) => o is NeedsChoice && _resolved(o) == null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _outcomeCard('first', c.earlier, first),
        const SizedBox(height: RfSpace.s3),
        _outcomeCard('second', c.later, second),
        const SizedBox(height: RfSpace.s3),
        if (same)
          RfEmptyState(
            key: const Key('compare-same-reading'),
            icon: Icons.compare_arrows,
            message:
                'Both dates use the same reading '
                '(${formatReading(first)} on '
                '${formatDay(first.recordedAt)}), so there is no change.',
          )
        else if (change != null && ordered != null)
          _changeCard(
            change,
            'From ${formatReading(ordered.$1)} on '
            '${formatDay(ordered.$1.recordedAt)} to '
            '${formatReading(ordered.$2)} on '
            '${formatDay(ordered.$2.recordedAt)}',
          )
        else if (pending)
          const RfEmptyState(
            key: Key('compare-choose-prompt'),
            icon: Icons.touch_app_outlined,
            message:
                'Choose a reading for each date without one to see the change.',
          )
        else
          const RfEmptyState(
            key: Key('compare-no-change'),
            icon: Icons.compare_arrows,
            message:
                'There is no change to show without readings for this type.',
          ),
      ],
    );
  }

  /// The reading to use for [o]: the exact reading, or the user's choice
  /// (only while it is still one of the offered neighbours).
  Measurement? _resolved(DateOutcome o) => switch (o) {
    ExactReading(:final reading) => reading,
    NeedsChoice(:final before, :final after) =>
      [before, after]
          .whereType<Measurement>()
          .where((m) => m.id == _choices[o.requested])
          .firstOrNull,
    NoData() => null,
  };

  Widget _outcomeCard(String tag, DateOutcome o, Measurement? chosen) {
    final theme = Theme.of(context);
    final day = formatCalendarDate(o.requested);
    return RfCard(
      key: Key('outcome-$tag'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: switch (o) {
          ExactReading(:final reading) => [
            Text(day, style: context.rfText.kicker),
            Text(
              formatReading(reading),
              key: Key('outcome-value-$tag'),
              style: theme.textTheme.titleMedium,
            ),
          ],
          NoData() => [
            Text(day, style: context.rfText.kicker),
            Text(
              'No readings for this type.',
              key: Key('outcome-nodata-$tag'),
              style: theme.textTheme.bodyMedium,
            ),
          ],
          NeedsChoice(:final before, :final after) => [
            Text(day, style: context.rfText.kicker),
            Text(
              'No reading on this date. Choose which reading to use:',
              key: Key('outcome-needs-choice-$tag'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: RfSpace.xs),
            if (before != null)
              _ChoiceTile(
                key: Key('choice-$tag-before'),
                label:
                    'Earlier: ${formatReading(before)} on '
                    '${formatWhen(before.recordedAt)}',
                selected: chosen?.id == before.id,
                onTap: () => setState(() => _choices[o.requested] = before.id),
              ),
            if (after != null)
              _ChoiceTile(
                key: Key('choice-$tag-after'),
                label:
                    'Later: ${formatReading(after)} on '
                    '${formatWhen(after.recordedAt)}',
                selected: chosen?.id == after.id,
                onTap: () => setState(() => _choices[o.requested] = after.id),
              ),
          ],
        },
      ),
    );
  }

  // ---- periods ----

  Widget _periodResult(List<Measurement> list) {
    final c = comparePeriods(list, _site, _rangeA, _rangeB);
    final theme = Theme.of(context);
    Widget card(String tag, PeriodStats s) => RfCard(
      key: Key('period-$tag'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatCalendarDate(s.range.start)} to '
            '${formatCalendarDate(s.range.end)}',
            style: context.rfText.kicker,
          ),
          if (s.mean == null)
            Text(
              'No readings in this period.',
              key: Key('period-empty-$tag'),
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            Text(
              'Mean ${s.mean!.toStringAsFixed(1)} ${_site.unit}',
              key: Key('period-mean-$tag'),
              style: theme.textTheme.titleMedium,
            ),
            Text(
              '${s.count} ${s.count == 1 ? 'reading' : 'readings'}',
              key: Key('period-count-$tag'),
              style: context.rfText.caption,
            ),
          ],
        ],
      ),
    );
    final change = c.change;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card('first', c.earlier),
        const SizedBox(height: RfSpace.s3),
        card('second', c.later),
        const SizedBox(height: RfSpace.s3),
        if (change != null)
          _changeCard(change, 'Change between the two period means')
        else
          const RfEmptyState(
            key: Key('compare-no-change'),
            icon: Icons.compare_arrows,
            message: 'Both periods need at least one reading to show a change.',
          ),
      ],
    );
  }

  Widget _changeCard(Change change, String caption) {
    final theme = Theme.of(context);
    final pct = formatPercentChange(change);
    return RfCard(
      key: const Key('compare-change'),
      accentEdge: true,
      child: Semantics(
        container: true,
        label: '${spokenChange(change)}. $caption',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CHANGE', style: context.rfText.kicker),
            Wrap(
              spacing: RfSpace.md,
              children: [
                Text(
                  formatAbsoluteChange(change),
                  key: const Key('compare-change-abs'),
                  style: theme.textTheme.titleMedium,
                ),
                if (pct != null)
                  Text(
                    pct,
                    key: const Key('compare-change-pct'),
                    style: theme.textTheme.titleMedium,
                  ),
              ],
            ),
            Text(caption, style: context.rfText.caption),
          ],
        ),
      ),
    );
  }
}

/// One selectable reading; at least 48 dp tall; announced as a selectable
/// option in a group.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: rfMinTouchTarget),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? theme.colorScheme.primary : null,
              ),
              const SizedBox(width: RfSpace.s3),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            ],
          ),
        ),
      ),
    );
  }
}
