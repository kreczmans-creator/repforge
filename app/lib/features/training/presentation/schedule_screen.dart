import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show diaryDayKey;
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/plan_providers.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/plan_format.dart';
import 'package:repforge/features/training/presentation/schedule_sheet.dart';
import 'package:repforge/features/training/presentation/session_starter.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Days shown at once: the 8-week horizon (TRN-015(1)).
const int _rangeDays = scheduleHorizonWeeks * 7;

/// Schedule (TRN-015): the scheduled workouts of the next 8 weeks grouped by
/// date, with actions to schedule a workout on a date, on weekdays or from a
/// split cycle, and to move, skip or restore an occurrence without touching
/// its plan.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  /// First day of the shown range; null means today.
  DateTime? _from;

  /// Today as a calendar date, honouring the day-start hour setting.
  DateTime _today() {
    final hour = ref.read(settingsProvider).value?.dayStartHour ?? 0;
    final now = ref.read(clockProvider).now();
    return parseScheduleDayKey(diaryDayKey(now, hour)) ?? scheduleDate(now);
  }

  DateTime get _start => _from ?? _today();

  DateTime _end(DateTime from) =>
      DateTime(from.year, from.month, from.day + _rangeDays - 1);

  void _shift(int days) => setState(() {
    final s = _start;
    _from = DateTime(s.year, s.month, s.day + days);
  });

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _schedule(ScheduleMode mode) async {
    final result = await showScheduleSheet(
      context,
      mode: mode,
      today: _today(),
    );
    if (result == null || !mounted) return;
    ref.invalidate(scheduledRangeProvider);
    setState(() {
      final from = _start;
      final to = _end(from);
      if (result.start.isBefore(from) || result.start.isAfter(to)) {
        _from = result.start;
      }
    });
    _snack(result.message);
  }

  Future<void> _move(ScheduledWorkout w, String planName) async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: w.day,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 3, 12, 31),
      helpText: 'Move $planName to',
    );
    if (picked == null || !mounted) return;
    final result = await ref.read(moveScheduledWorkoutProvider)(
      scheduledWorkoutId: w.id,
      newDate: picked,
    );
    if (!mounted) return;
    ref.invalidate(scheduledRangeProvider);
    switch (result) {
      case Ok(:final value):
        _snack('Moved to ${formatScheduleDate(value.day)}.');
      case Err(:final error):
        _snack(userMessageFor(error));
    }
  }

  Future<void> _skip(ScheduledWorkout w, String planName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Skip $planName?'),
        content: Text(
          'It stays in the list as skipped on ${formatScheduleDate(w.day)}. '
          'The workout itself is not changed.',
        ),
        actions: [
          TextButton(
            key: const Key('skip-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('skip-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref.read(skipScheduledWorkoutProvider)(w.id);
    if (!mounted) return;
    ref.invalidate(scheduledRangeProvider);
    if (result case Err(:final error)) _snack(userMessageFor(error));
  }

  Future<void> _restore(ScheduledWorkout w) async {
    final result = await ref.read(unskipScheduledWorkoutProvider)(w.id);
    if (!mounted) return;
    ref.invalidate(scheduledRangeProvider);
    switch (result) {
      case Ok():
        _snack('Restored to planned.');
      case Err(:final error):
        _snack(userMessageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = _start;
    final to = _end(from);
    final plansAsync = ref.watch(allWorkoutPlansProvider);
    final plans = {
      for (final p in plansAsync.value ?? const <WorkoutPlan>[]) p.id: p,
    };
    // Until the plans have loaded, a missing id is unknown, not deleted.
    final plansLoaded = plansAsync.hasValue;
    final scheduled = ref.watch(scheduledRangeProvider((from: from, to: to)));
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Schedule',
            caption: 'Your planned workouts by date',
          ),
          RfButton(
            key: const Key('schedule-on-date'),
            label: 'Schedule on a date',
            icon: Icons.event_outlined,
            onPressed: () => _schedule(ScheduleMode.date),
          ),
          const SizedBox(height: RfSpace.s2),
          RfButton(
            key: const Key('schedule-weekdays'),
            label: 'Schedule by weekdays',
            icon: Icons.repeat,
            variant: RfButtonVariant.secondary,
            onPressed: () => _schedule(ScheduleMode.weekdays),
          ),
          const SizedBox(height: RfSpace.s2),
          RfButton(
            key: const Key('schedule-split'),
            label: 'Schedule a split',
            icon: Icons.view_week_outlined,
            variant: RfButtonVariant.secondary,
            onPressed: () => _schedule(ScheduleMode.split),
          ),
          const SizedBox(height: RfSpace.s4),
          Text(
            '${formatScheduleDate(from)} to ${formatScheduleDate(to)}',
            key: const Key('range-label'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: RfSpace.s2,
            children: [
              RfButton(
                key: const Key('range-prev'),
                label: 'Earlier',
                icon: Icons.chevron_left,
                variant: RfButtonVariant.tertiary,
                expand: false,
                onPressed: () => _shift(-_rangeDays),
              ),
              RfButton(
                key: const Key('range-next'),
                label: 'Later',
                icon: Icons.chevron_right,
                variant: RfButtonVariant.tertiary,
                expand: false,
                onPressed: () => _shift(_rangeDays),
              ),
            ],
          ),
          const SizedBox(height: RfSpace.s2),
          ..._list(scheduled, plans, plansLoaded: plansLoaded),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }

  List<Widget> _list(
    AsyncValue<List<ScheduledWorkout>> scheduled,
    Map<String, WorkoutPlan> plans, {
    required bool plansLoaded,
  }) {
    if (scheduled.hasError) {
      return [
        RfErrorState(
          message: 'Could not load the schedule.',
          onRetry: () => ref.invalidate(scheduledRangeProvider),
        ),
      ];
    }
    final items = scheduled.value;
    if (items == null) return [const RfLoading()];
    if (items.isEmpty) {
      return [
        const RfEmptyState(
          key: Key('schedule-empty'),
          icon: Icons.event_busy_outlined,
          message: 'Nothing scheduled in this range.',
        ),
      ];
    }
    final theme = Theme.of(context);
    final out = <Widget>[];
    String? lastKey;
    for (final w in items) {
      final key = scheduleDayKey(w.day);
      if (key != lastKey) {
        lastKey = key;
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: RfSpace.s3, bottom: RfSpace.s1),
            child: Semantics(
              header: true,
              child: Text(
                formatScheduleDate(w.day),
                key: Key('schedule-date-$key'),
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
        );
      }
      final name =
          plans[w.planId]?.name ?? (plansLoaded ? 'Deleted workout' : '…');
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: RfSpace.s2),
          child: _ScheduledRow(
            workout: w,
            planName: name,
            onMove: () => _move(w, name),
            onSkip: () => _skip(w, name),
            onRestore: () => _restore(w),
            // A deleted plan cannot be started, so the row offers no Start.
            onStart: plansLoaded && plans[w.planId] == null
                ? null
                : () => ref.startFromPlan(
                    context,
                    w.planId,
                    scheduledWorkoutId: w.id,
                  ),
          ),
        ),
      );
    }
    return out;
  }
}

class _ScheduledRow extends StatelessWidget {
  const _ScheduledRow({
    required this.workout,
    required this.planName,
    required this.onMove,
    required this.onSkip,
    required this.onRestore,
    required this.onStart,
  });

  final ScheduledWorkout workout;
  final String planName;
  final VoidCallback onMove;
  final VoidCallback onSkip;
  final VoidCallback onRestore;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final w = workout;
    final theme = Theme.of(context);
    final skipped = w.status == ScheduleStatus.skipped;
    final status = switch (w.status) {
      ScheduleStatus.planned => 'Planned',
      ScheduleStatus.skipped => 'Skipped',
      ScheduleStatus.done => 'Done',
    };
    final moved = scheduleDayKey(w.sourceDay) != scheduleDayKey(w.day);
    return RfCard(
      key: Key('scheduled-${w.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            planName,
            style: theme.textTheme.titleMedium?.copyWith(
              decoration: skipped ? TextDecoration.lineThrough : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            [
              status,
              if (moved) 'moved from ${formatScheduleDate(w.sourceDay)}',
            ].join(' · '),
            key: Key('scheduled-status-${w.id}'),
            style: context.rfText.caption,
          ),
          if (w.status == ScheduleStatus.planned)
            Wrap(
              spacing: RfSpace.s2,
              children: [
                if (onStart != null)
                  Tooltip(
                    message: 'Start $planName',
                    child: TextButton.icon(
                      key: Key('schedule-start-${w.id}'),
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                    ),
                  ),
                Tooltip(
                  message: 'Move $planName to another date',
                  child: TextButton.icon(
                    key: Key('schedule-move-${w.id}'),
                    onPressed: onMove,
                    icon: const Icon(Icons.event_repeat_outlined),
                    label: const Text('Move'),
                  ),
                ),
                Tooltip(
                  message: 'Skip $planName on ${formatScheduleDate(w.day)}',
                  child: TextButton.icon(
                    key: Key('schedule-skip-${w.id}'),
                    onPressed: onSkip,
                    icon: const Icon(Icons.skip_next_outlined),
                    label: const Text('Skip'),
                  ),
                ),
              ],
            ),
          if (skipped)
            Tooltip(
              message: 'Restore $planName on ${formatScheduleDate(w.day)}',
              child: TextButton.icon(
                key: Key('schedule-restore-${w.id}'),
                onPressed: onRestore,
                icon: const Icon(Icons.undo),
                label: const Text('Restore'),
              ),
            ),
        ],
      ),
    );
  }
}
