import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/measurements/presentation/measurement_widgets.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Opens the edit sheet for [m]; resolves true when saved.
Future<bool?> showMeasurementEditSheet(BuildContext context, Measurement m) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MeasurementEditSheet(measurement: m),
    );

/// Edit of one reading: value, date, time and note (BCM-004). The measurement
/// type is fixed; changing it would be a delete and a new entry.
class MeasurementEditSheet extends ConsumerStatefulWidget {
  const MeasurementEditSheet({required this.measurement, super.key});

  final Measurement measurement;

  @override
  ConsumerState<MeasurementEditSheet> createState() =>
      _MeasurementEditSheetState();
}

class _MeasurementEditSheetState extends ConsumerState<MeasurementEditSheet> {
  late final TextEditingController _value;
  late final TextEditingController _note;
  late CalendarDate _date;
  late TimeOfDay _time;
  bool _saving = false;
  Map<String, String> _errors = const {};
  String? _generalError;

  @override
  void initState() {
    super.initState();
    final m = widget.measurement;
    final local = m.recordedAt.toLocal();
    _value = TextEditingController(text: m.value.raw.toStringAsFixed(1));
    _note = TextEditingController(text: m.note ?? '');
    _date = CalendarDate(local.year, local.month, local.day);
    _time = TimeOfDay(hour: local.hour, minute: local.minute);
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errors = const {};
      _generalError = null;
    });
    final original = widget.measurement.recordedAt.toLocal();
    final unchangedTime =
        _time.hour == original.hour && _time.minute == original.minute;
    // Keep the stored seconds when the user did not touch date or time.
    final recordedAt =
        unchangedTime && CalendarDate.fromInstant(original) == _date
        ? widget.measurement.recordedAt
        : DateTime(
            _date.year,
            _date.month,
            _date.day,
            _time.hour,
            _time.minute,
          );
    final result = await ref.read(updateMeasurementProvider)(
      id: widget.measurement.id,
      valueText: _value.text,
      recordedAt: recordedAt,
      note: _note.text,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final error):
        setState(() {
          _saving = false;
          if (error case ValidationError(:final fieldErrors)
              when fieldErrors.isNotEmpty) {
            _errors = fieldErrors;
          } else {
            _generalError = userMessageFor(error);
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.measurement;
    final now = ref.watch(clockProvider).now();
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(RfSpace.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit ${m.site.label}', style: theme.textTheme.titleMedium),
            const SizedBox(height: RfSpace.s3),
            RfTextField.number(
              key: const Key('edit-value'),
              controller: _value,
              label: m.site.label,
              unit: m.site.unit,
              decimals: 2,
              errorText: _errors[m.site.name],
            ),
            const SizedBox(height: RfSpace.s3),
            WhenFields(
              date: _date,
              time: _time,
              now: now,
              errorText: _errors['recordedAt'],
              onDate: (d) => setState(() => _date = d),
              onTime: (t) => setState(() => _time = t),
            ),
            const SizedBox(height: RfSpace.s3),
            RfTextField(
              key: const Key('edit-note'),
              controller: _note,
              label: 'Note (optional)',
            ),
            const SizedBox(height: RfSpace.s4),
            if (_generalError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: RfSpace.sm),
                child: Text(
                  _generalError!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            RfButton(
              key: const Key('edit-save'),
              label: _saving ? 'Saving' : 'Save changes',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: RfSpace.sm),
            RfButton(
              key: const Key('edit-cancel'),
              label: 'Cancel',
              variant: RfButtonVariant.tertiary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
