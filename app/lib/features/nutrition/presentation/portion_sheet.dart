import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/entry_unit.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/nutrition/presentation/nutrient_display.dart';
import 'package:repforge/features/nutrition/presentation/provenance_badge.dart';
import 'package:repforge/features/settings/application/meal_label_providers.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Portion sheet: choose an amount (in the food's reference unit or a larger
/// metric unit of the same basis, g | kg or ml | l, WP 15; or a count of a
/// named serving) and a meal, see the resulting nutrients, log. The stored
/// amount is always canonical g or ml. Returns the entry when logged.
Future<FoodLogEntry?> showPortionSheet(
  BuildContext context,
  Food food, {
  MealSlot? initialMeal,
}) => showModalBottomSheet<FoodLogEntry>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _PortionSheet(food: food, initialMeal: initialMeal),
);

/// Default meal for the current hour (fast logging).
MealSlot defaultMealFor(DateTime local) => switch (local.hour) {
  < 11 => MealSlot.breakfast,
  < 15 => MealSlot.lunch,
  < 21 => MealSlot.dinner,
  _ => MealSlot.snack,
};

class _PortionSheet extends ConsumerStatefulWidget {
  const _PortionSheet({required this.food, this.initialMeal});

  final Food food;
  final MealSlot? initialMeal;

  @override
  ConsumerState<_PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends ConsumerState<_PortionSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.food.servings.isEmpty
        ? '100'
        : formatNumber(widget.food.servings.first.quantity.amount),
  );
  late final TextEditingController _servings = TextEditingController(text: '1');
  late MealSlot _meal = widget.initialMeal ?? MealSlot.snack;
  ServingSize? _serving;
  late EntryUnit _entryUnit = EntryUnit.canonicalFor(
    widget.food.profile.per100,
  )!;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.food.servings.isNotEmpty) _serving = widget.food.servings.first;
  }

  @override
  void dispose() {
    _amount.dispose();
    _servings.dispose();
    super.dispose();
  }

  double? get _amountValue {
    if (_serving == null) {
      return _entered?.amount;
    }
    final n = double.tryParse(_servings.text.trim().replaceAll(',', '.'));
    return n == null ? null : _serving!.quantityFor(n).amount;
  }

  /// The typed amount as a stored quantity in the food's basis (spec §2.3);
  /// null when the text is not a number or the amount is invalid. Lenient
  /// parse as before WP 15, so a trailing separator is still accepted.
  Quantity? get _entered {
    final v = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (v == null) return null;
    return switch (_entryUnit.toCanonical(v)) {
      Ok(:final value) => value,
      Err() => null,
    };
  }

  /// Validation error for the typed amount in the current unit, or null when
  /// it converts to a stored quantity.
  String? get _amountError {
    final text = _amount.text.trim();
    if (text.isEmpty) return null;
    final v = double.tryParse(text.replaceAll(',', '.'));
    if (v == null) return 'Enter a number.';
    return switch (_entryUnit.toCanonical(v)) {
      Ok() => null,
      Err(:final error) => userMessageFor(error),
    };
  }

  void _selectUnit(EntryUnit next) {
    final current = _entered;
    final invalid = current == null ? _amountError : null;
    setState(() {
      if (current != null) {
        _amount.text = formatNumber(
          next.fromCanonical(current),
          maxDecimals: next.decimals,
        );
      } else if (invalid != null) {
        // Text that is not a valid amount in the old unit would be silently
        // reinterpreted in the new one (review R15-02): clear it and say why.
        _amount.clear();
      }
      _entryUnit = next;
      _error = invalid;
    });
  }

  NutrientAmounts? get _preview {
    final a = _amountValue;
    if (a == null || a < 0) return null;
    return switch (Quantity.of(a, widget.food.profile.per100)) {
      Ok(:final value) => switch (widget.food.profile.forQuantity(value)) {
        Ok(:final value) => value,
        Err() => null,
      },
      Err() => null,
    };
  }

  Future<void> _log() async {
    if (_busy) return;
    final a = _amountValue;
    if (a == null) {
      // Out-of-range custom amounts keep their validation message
      // (review R15-01); only unparseable text is "Enter a number.".
      final message = _serving == null ? _amountError : null;
      setState(() => _error = message ?? 'Enter a number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(logFoodProvider)(
      food: widget.food,
      amount: a,
      meal: _meal,
      day: ref.read(selectedDayProvider),
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
    final food = widget.food;
    final unit = food.profile.per100.symbol;
    final preview = _preview;
    final entered = _entered;
    final labels = ref.watch(mealLabelsValueProvider);
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
            Text(food.name, style: theme.textTheme.headlineSmall),
            Row(
              children: [
                if (food.brand != null)
                  Flexible(
                    child: Text(
                      food.brand!,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (food.brand != null) const SizedBox(width: RfSpace.s2),
                ProvenanceBadge(food.profile.provenance),
              ],
            ),
            const SizedBox(height: RfSpace.s4),
            if (food.servings.isNotEmpty) ...[
              Text('PORTION', style: context.rfText.kicker),
              const SizedBox(height: RfSpace.s2),
              Wrap(
                spacing: RfSpace.s2,
                children: [
                  for (final s in food.servings)
                    ChoiceChip(
                      label: Text('${s.label} (${s.quantity.label})'),
                      selected: _serving == s,
                      onSelected: (_) => setState(() => _serving = s),
                    ),
                  ChoiceChip(
                    key: const Key('portion-custom'),
                    label: Text('Custom $unit'),
                    selected: _serving == null,
                    onSelected: (_) => setState(() => _serving = null),
                  ),
                ],
              ),
              const SizedBox(height: RfSpace.s3),
            ],
            if (_serving == null) ...[
              SegmentedButton<EntryUnit>(
                key: const Key('portion-entry-unit'),
                showSelectedIcon: false,
                segments: [
                  for (final u in EntryUnit.forBase(food.profile.per100))
                    ButtonSegment(
                      value: u,
                      label: Text(u.symbol),
                      tooltip: u.name,
                    ),
                ],
                selected: {_entryUnit},
                onSelectionChanged: (s) => _selectUnit(s.first),
              ),
              const SizedBox(height: RfSpace.s2),
              RfTextField.number(
                key: const Key('portion-amount'),
                controller: _amount,
                label: 'Amount',
                unit: _entryUnit.symbol,
                decimals: _entryUnit.decimals,
                errorText: _error,
                autofocus: true,
                onChanged: (_) => setState(() => _error = null),
              ),
              if (!_entryUnit.isCanonical && entered != null)
                Padding(
                  padding: const EdgeInsets.only(top: RfSpace.s1),
                  child: Text(
                    key: const Key('portion-canonical'),
                    '= ${entered.label}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ] else
              RfTextField.number(
                key: const Key('portion-servings'),
                controller: _servings,
                label: 'Number of ${_serving!.label}',
                decimals: 2,
                errorText: _error,
                onChanged: (_) => setState(() => _error = null),
              ),
            const SizedBox(height: RfSpace.s3),
            Text('MEAL', style: context.rfText.kicker),
            const SizedBox(height: RfSpace.s2),
            SegmentedButton<MealSlot>(
              key: const Key('portion-meal'),
              showSelectedIcon: false,
              segments: [
                for (final m in labels.order)
                  ButtonSegment(value: m, label: Text(labels.labelOf(m))),
              ],
              selected: {_meal},
              onSelectionChanged: (s) => setState(() => _meal = s.first),
            ),
            const SizedBox(height: RfSpace.s4),
            if (preview != null)
              Row(
                key: const Key('portion-preview'),
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Figure('kcal', formatNumber(preview.kcal, maxDecimals: 0)),
                  _Figure('P', gramsOrNa(preview.proteinG, maxDecimals: 1)),
                  _Figure('C', gramsOrNa(preview.carbsG, maxDecimals: 1)),
                  _Figure('F', gramsOrNa(preview.fatG, maxDecimals: 1)),
                  _Figure('Fibre', gramsOrNa(preview.fibreG, maxDecimals: 1)),
                ],
              ),
            const SizedBox(height: RfSpace.s4),
            RfButton(
              key: const Key('portion-log'),
              label: 'Log to ${labels.labelOf(_meal)}',
              loading: _busy,
              onPressed: _log,
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: context.rfText.dataM),
      Text(label, style: context.rfText.meta),
    ],
  );
}
