import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/planning/application/planning_providers.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Sheet to choose the quantity of an item being planned (RCP-014(1)):
/// portions (step 0.5) for a recipe, grams or millilitres for a food, a
/// multiplier (step 0.5) for a saved meal. Saves through `PlanItem` and pops
/// the planned item; refusals are shown in the sheet.
Future<MealPlanItem?> showPlanQuantitySheet(
  BuildContext context, {
  required String day,
  required MealSlot meal,
  required String mealLabel,
  required PlannedKind kind,
  required String refId,
  required String name,
  required ReferenceUnit unit,
}) => showModalBottomSheet<MealPlanItem>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _PlanQuantitySheet(
    day: day,
    meal: meal,
    mealLabel: mealLabel,
    kind: kind,
    refId: refId,
    name: name,
    unit: unit,
  ),
);

class _PlanQuantitySheet extends ConsumerStatefulWidget {
  const _PlanQuantitySheet({
    required this.day,
    required this.meal,
    required this.mealLabel,
    required this.kind,
    required this.refId,
    required this.name,
    required this.unit,
  });

  final String day;
  final MealSlot meal;
  final String mealLabel;
  final PlannedKind kind;
  final String refId;
  final String name;
  final ReferenceUnit unit;

  @override
  ConsumerState<_PlanQuantitySheet> createState() => _PlanQuantitySheetState();
}

class _PlanQuantitySheetState extends ConsumerState<_PlanQuantitySheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.kind == PlannedKind.food ? '100' : '1',
  );
  String? _error;
  bool _busy = false;

  bool get _stepped => widget.kind != PlannedKind.food;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.'));

  void _step(double delta) {
    final next = ((_value ?? 0) + delta).clamp(0.5, 1000).toDouble();
    setState(() {
      _amount.text = formatNumber(
        next,
        maxDecimals: widget.kind == PlannedKind.savedMeal ? 2 : 1,
      );
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final v = _value;
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(planItemProvider)(
      day: widget.day,
      meal: widget.meal,
      kind: widget.kind,
      refId: widget.refId,
      quantity: v,
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final error):
        setState(() {
          _busy = false;
          _error = userMessageFor(error);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (widget.kind) {
      PlannedKind.recipe => 'Portions',
      PlannedKind.food => 'Amount',
      PlannedKind.savedMeal => 'Times (multiplier)',
    };
    final field = RfTextField.number(
      key: const Key('plan-quantity'),
      controller: _amount,
      label: label,
      unit: widget.kind == PlannedKind.food ? widget.unit.symbol : null,
      decimals: widget.kind == PlannedKind.savedMeal ? 2 : 1,
      errorText: _error,
      autofocus: !_stepped,
      onChanged: (_) => setState(() => _error = null),
    );
    return Padding(
      padding: EdgeInsets.only(
        left: RfSpace.gutter,
        right: RfSpace.gutter,
        top: RfSpace.s4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + RfSpace.s4,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: RfSpace.s1),
            Text(
              'Plan for ${widget.mealLabel}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: RfSpace.s4),
            if (_stepped)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    key: const Key('plan-quantity-dec'),
                    tooltip: 'Less',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _step(-0.5),
                  ),
                  Expanded(child: field),
                  IconButton(
                    key: const Key('plan-quantity-inc'),
                    tooltip: 'More',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _step(0.5),
                  ),
                ],
              )
            else
              field,
            const SizedBox(height: RfSpace.s4),
            RfButton(
              key: const Key('plan-submit'),
              label: 'Add to ${widget.mealLabel}',
              loading: _busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
