import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/features/training/application/plan_providers.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/plan_format.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// How a workout is put on the calendar (TRN-015).
enum ScheduleMode { date, weekdays, split }

/// What a successful scheduling reports back to the schedule screen.
class ScheduleSheetResult {
  const ScheduleSheetResult({required this.message, required this.start});

  /// Plain-language outcome, e.g. `Scheduled 16 workouts.`
  final String message;

  /// The first date the user chose, so the list can show it.
  final DateTime start;
}

/// Bottom sheet that schedules a plan on a date, on weekdays for the next 8
/// weeks, or a split's cycle from a start date. Use-case errors show next to
/// the field they belong to; the sheet stays open until it succeeds.
Future<ScheduleSheetResult?> showScheduleSheet(
  BuildContext context, {
  required ScheduleMode mode,
  required DateTime today,
}) => showModalBottomSheet<ScheduleSheetResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (ctx) => ScheduleSheet(mode: mode, today: today),
);

class ScheduleSheet extends ConsumerStatefulWidget {
  const ScheduleSheet({required this.mode, required this.today, super.key});

  final ScheduleMode mode;
  final DateTime today;

  @override
  ConsumerState<ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends ConsumerState<ScheduleSheet> {
  String? _planId;
  String? _splitId;
  final _weekdays = <int>{};
  late DateTime _date = widget.today;
  final Map<String, String> _errors = {};
  bool _busy = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(widget.today.year - 1),
      lastDate: DateTime(widget.today.year + 3, 12, 31),
      helpText: widget.mode == ScheduleMode.date ? 'Date' : 'Start date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = scheduleDate(picked);
      _errors.remove('date');
    });
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(_errors.clear);
    if (widget.mode == ScheduleMode.split) {
      if (_splitId == null) {
        setState(() => _errors['splitId'] = 'Choose a split.');
        return;
      }
    } else if (_planId == null) {
      setState(() => _errors['planId'] = 'Choose a workout.');
      return;
    }
    setState(() => _busy = true);
    final String message;
    switch (widget.mode) {
      case ScheduleMode.date:
        final r = await ref.read(scheduleOnDateProvider)(
          planId: _planId!,
          date: _date,
        );
        if (!mounted) return;
        if (r case Err(:final error)) return _fail(error);
        message = 'Scheduled for ${formatScheduleDate(_date)}.';
      case ScheduleMode.weekdays:
        final r = await ref.read(scheduleWeekdaysProvider)(
          planId: _planId!,
          start: _date,
          weekdays: _weekdays.isEmpty ? null : ([..._weekdays]..sort()),
        );
        if (!mounted) return;
        switch (r) {
          case Err(:final error):
            return _fail(error);
          case Ok(:final value):
            message = _outcomeText(value.created.length, value.alreadyThere);
        }
      case ScheduleMode.split:
        final r = await ref.read(scheduleSplitCycleProvider)(
          splitId: _splitId!,
          start: _date,
        );
        if (!mounted) return;
        switch (r) {
          case Err(:final error):
            return _fail(error);
          case Ok(:final value):
            final missing = value.missingPlans;
            message =
                _outcomeText(value.created.length, value.alreadyThere) +
                (missing == 0
                    ? ''
                    : ' $missing workout${missing == 1 ? ' is' : 's are'} '
                          'archived or deleted and was left out.');
        }
    }
    Navigator.of(context)
        .pop(ScheduleSheetResult(message: message, start: _date));
  }

  void _fail(AppError error) {
    final field = error is ValidationError ? error.field : null;
    setState(() {
      _busy = false;
      _errors[field ?? 'general'] = userMessageFor(error);
    });
  }

  String _outcomeText(int created, int alreadyThere) {
    final base = 'Scheduled $created workout${created == 1 ? '' : 's'}.';
    return alreadyThere == 0 ? base : '$base $alreadyThere already there.';
  }

  Widget _error(String field) {
    final message = _errors[field];
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: RfSpace.s1),
      child: Text(
        message,
        key: Key('sched-error-$field'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekStart = ref.watch(settingsProvider).value?.weekStartDay ?? 1;
    final plans = ref.watch(activeWorkoutPlansProvider).value ?? const [];
    final splits = ref.watch(trainingSplitsProvider).value ?? const [];
    final title = switch (widget.mode) {
      ScheduleMode.date => 'Schedule on a date',
      ScheduleMode.weekdays => 'Schedule by weekdays',
      ScheduleMode.split => 'Schedule a split',
    };
    final needsPlan = widget.mode != ScheduleMode.split;
    final choices = needsPlan ? plans.length : splits.length;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        RfSpace.gutter,
        0,
        RfSpace.gutter,
        RfSpace.gutter + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (widget.mode != ScheduleMode.date)
            Padding(
              padding: const EdgeInsets.only(top: RfSpace.s1),
              child: Text(
                'Fills the next $scheduleHorizonWeeks weeks from the start '
                'date. Running it again never adds duplicates.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: RfSpace.s3),
          Text(
            needsPlan ? 'Workout' : 'Split',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: RfSpace.s1),
          if (choices == 0)
            RfEmptyState(
              key: const Key('sched-no-choices'),
              message: needsPlan
                  ? 'Create a workout first.'
                  : 'Create a split first.',
            )
          else
            Wrap(
              spacing: RfSpace.s2,
              runSpacing: RfSpace.s1,
              children: [
                if (needsPlan)
                  for (final p in plans)
                    ChoiceChip(
                      key: Key('sched-plan-${p.id}'),
                      label: Text(p.name),
                      selected: _planId == p.id,
                      onSelected: (_) => setState(() {
                        _planId = p.id;
                        _errors.remove('planId');
                      }),
                    )
                else
                  for (final s in splits)
                    ChoiceChip(
                      key: Key('sched-split-${s.id}'),
                      label: Text(s.name),
                      selected: _splitId == s.id,
                      onSelected: (_) => setState(() {
                        _splitId = s.id;
                        _errors.remove('splitId');
                      }),
                    ),
              ],
            ),
          _error('planId'),
          _error('splitId'),
          if (widget.mode == ScheduleMode.weekdays) ...[
            const SizedBox(height: RfSpace.s3),
            Text('Weekdays', style: theme.textTheme.labelLarge),
            const SizedBox(height: RfSpace.s1),
            Wrap(
              spacing: RfSpace.s2,
              runSpacing: RfSpace.s1,
              children: [
                for (final d in weekdaysFrom(weekStart))
                  FilterChip(
                    key: Key('sched-weekday-$d'),
                    label: Text(
                      weekdayShort(d),
                      semanticsLabel: weekdayNames[d - 1],
                    ),
                    selected: _weekdays.contains(d),
                    onSelected: (v) => setState(() {
                      v ? _weekdays.add(d) : _weekdays.remove(d);
                      _errors.remove('weekdays');
                    }),
                  ),
              ],
            ),
            _error('weekdays'),
          ],
          const SizedBox(height: RfSpace.s3),
          Text(
            widget.mode == ScheduleMode.date ? 'Date' : 'Start date',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: RfSpace.s1),
          RfButton(
            key: const Key('sched-date'),
            label: formatScheduleDate(_date),
            icon: Icons.event_outlined,
            variant: RfButtonVariant.secondary,
            onPressed: _pickDate,
          ),
          _error('date'),
          _error('general'),
          const SizedBox(height: RfSpace.s4),
          RfButton(
            key: const Key('sched-confirm'),
            label: 'Schedule',
            loading: _busy,
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }
}
