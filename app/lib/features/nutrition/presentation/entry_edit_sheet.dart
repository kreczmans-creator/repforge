import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/nutrition/presentation/fuel_screen.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Bottom sheet to change an entry's amount or meal, or delete it.
Future<void> showEntryEditSheet(BuildContext context, FoodLogEntry entry) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EntryEditSheet(entry: entry),
    );

class _EntryEditSheet extends ConsumerStatefulWidget {
  const _EntryEditSheet({required this.entry});

  final FoodLogEntry entry;

  @override
  ConsumerState<_EntryEditSheet> createState() => _EntryEditSheetState();
}

class _EntryEditSheetState extends ConsumerState<_EntryEditSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: formatNumber(widget.entry.quantity.amount),
  );
  late MealSlot _meal = widget.entry.meal;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (amount == null) {
      setState(() {
        _busy = false;
        _error = 'Enter a number.';
      });
      return;
    }
    final result = await ref.read(updateFoodLogEntryProvider)(
      widget.entry,
      amount: amount,
      meal: _meal,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final error):
        setState(() {
          _busy = false;
          _error = userMessageFor(error);
        });
    }
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    await deleteEntry(context, ref, widget.entry.id);
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.entry;
    return Padding(
      padding: EdgeInsets.only(
        left: RfSpace.gutter,
        right: RfSpace.gutter,
        top: RfSpace.s4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + RfSpace.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.name, style: theme.textTheme.headlineSmall),
          Text(
            'Logged as ${e.quantity.label} · '
            '${formatNumber(e.nutrients.kcal, maxDecimals: 0)} kcal',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: RfSpace.s4),
          RfTextField.number(
            key: const Key('edit-amount'),
            controller: _amount,
            label: 'Amount',
            unit: e.quantity.unit.symbol,
            errorText: _error,
            autofocus: true,
          ),
          const SizedBox(height: RfSpace.s3),
          Text('MEAL', style: context.rfText.kicker),
          const SizedBox(height: RfSpace.s2),
          SegmentedButton<MealSlot>(
            key: const Key('edit-meal'),
            showSelectedIcon: false,
            segments: [
              for (final m in FuelScreen.meals)
                ButtonSegment(value: m, label: Text(FuelScreen.mealLabel(m))),
            ],
            selected: {_meal},
            onSelectionChanged: (s) => setState(() => _meal = s.first),
          ),
          const SizedBox(height: RfSpace.s4),
          RfButton(
            key: const Key('edit-save'),
            label: 'Save changes',
            loading: _busy,
            onPressed: _save,
          ),
          const SizedBox(height: RfSpace.s2),
          RfButton(
            key: const Key('edit-delete'),
            label: 'Delete entry',
            variant: RfButtonVariant.danger,
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
    );
  }
}
