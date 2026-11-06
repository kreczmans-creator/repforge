import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/features/measurements/presentation/measurement_format.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Period choice (BCM-005, BCM-008): 4 weeks, 12 weeks, 1 year, all. Chips
/// wrap onto several lines at narrow widths; each is at least 48 dp high.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final MeasurementPeriod selected;
  final ValueChanged<MeasurementPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Period',
      child: Wrap(
        spacing: RfSpace.sm,
        children: [
          for (final p in MeasurementPeriod.values)
            ChoiceChip(
              key: Key('period-${p.name}'),
              label: Text(p.label),
              selected: p == selected,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => onChanged(p),
            ),
        ],
      ),
    );
  }
}

/// Date and time pickers for a reading (BCM-004(1)). Future dates cannot be
/// picked; a time later than now on today is reported by the use case.
class WhenFields extends StatelessWidget {
  const WhenFields({
    required this.date,
    required this.time,
    required this.now,
    required this.onDate,
    required this.onTime,
    super.key,
    this.errorText,
  });

  final CalendarDate date;
  final TimeOfDay time;

  /// The current local time (from the app clock): the last pickable date.
  final DateTime now;
  final ValueChanged<CalendarDate> onDate;
  final ValueChanged<TimeOfDay> onTime;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final today = CalendarDate.fromInstant(now);
    final theme = Theme.of(context);
    final timeText = MaterialLocalizations.of(context)
        .formatTimeOfDay(time, alwaysUse24HourFormat: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('pick-date'),
          icon: const Icon(Icons.calendar_today_outlined, size: RfIcon.sm),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text('Date: ${formatCalendarDate(date)}'),
          ),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(date.year, date.month, date.day),
              firstDate: DateTime(2000),
              lastDate: DateTime(today.year, today.month, today.day),
              helpText: 'Date of measurement',
            );
            if (picked != null) {
              onDate(CalendarDate(picked.year, picked.month, picked.day));
            }
          },
        ),
        const SizedBox(height: RfSpace.sm),
        OutlinedButton.icon(
          key: const Key('pick-time'),
          icon: const Icon(Icons.schedule, size: RfIcon.sm),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text('Time: $timeText'),
          ),
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
              helpText: 'Time of measurement',
            );
            if (picked != null) onTime(picked);
          },
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: RfSpace.xs),
            child: Text(
              errorText!,
              key: const Key('when-error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// Asks for confirmation, then soft-deletes the reading [id] through the
/// `DeleteMeasurement` use case. [description] names the reading in the
/// dialog. Failures are shown in a snackbar.
Future<void> confirmAndDeleteReading(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String description,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete this reading?'),
      content: Text('$description will be removed. This cannot be undone.'),
      actions: [
        TextButton(
          key: const Key('delete-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('delete-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final result = await ref.read(deleteMeasurementProvider)(id);
  if (!context.mounted) return;
  if (result case Err(:final error)) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
  }
}

/// The app clock's current time, read when a screen builds.
DateTime clockNow(WidgetRef ref) => ref.watch(clockProvider).now();
