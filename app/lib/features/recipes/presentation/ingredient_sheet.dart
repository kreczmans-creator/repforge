import 'package:flutter/material.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/entry_unit.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/presentation/provenance_badge.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Sheet to set the quantity of a recipe ingredient (RCP-002). The amount is
/// entered in the food's reference unit or a larger metric unit of the same
/// basis (g | kg or ml | l, WP 15), or as a count of one of the food's
/// defined servings, so a unit mismatch cannot be entered. The stored
/// quantity is always canonical g or ml.
///
/// Pass [food] for a new ingredient, or [existing] to edit one. Returns the
/// ingredient (with [id]) or null when cancelled.
Future<RecipeIngredient?> showIngredientSheet(
  BuildContext context, {
  required String id,
  required int sortOrder,
  Food? food,
  RecipeIngredient? existing,
}) {
  assert(food != null || existing?.per100 != null, 'food or existing needed');
  return showModalBottomSheet<RecipeIngredient>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _IngredientSheet(
      id: id,
      sortOrder: sortOrder,
      food: food,
      existing: existing,
    ),
  );
}

class _IngredientSheet extends StatefulWidget {
  const _IngredientSheet({
    required this.id,
    required this.sortOrder,
    this.food,
    this.existing,
  });

  final String id;
  final int sortOrder;
  final Food? food;
  final RecipeIngredient? existing;

  @override
  State<_IngredientSheet> createState() => _IngredientSheetState();
}

class _IngredientSheetState extends State<_IngredientSheet> {
  late final NutrientProfile _profile =
      widget.food?.profile ?? widget.existing!.per100!;
  late final String _name = widget.food?.name ?? widget.existing!.name;
  late final String? _foodId = widget.food?.id ?? widget.existing?.foodId;

  /// Servings usable as ingredient units: same reference unit as the food.
  late final List<ServingSize> _servings = () {
    final list = <ServingSize>[
      for (final s in widget.food?.servings ?? const <ServingSize>[])
        if (s.quantity.unit == _profile.per100) s,
    ];
    final e = widget.existing;
    if (e?.servingLabel != null &&
        e?.servingCount != null &&
        e!.servingCount! > 0 &&
        list.every((s) => s.label != e.servingLabel)) {
      // Rebuild the serving an existing ingredient was entered with.
      final grams = e.quantity.amount / e.servingCount!;
      if (Quantity.of(grams, _profile.per100) case Ok(:final value)) {
        list.add(ServingSize(label: e.servingLabel!, quantity: value));
      }
    }
    return list;
  }();

  ServingSize? _serving;
  late EntryUnit _entryUnit = EntryUnit.canonicalFor(_profile.per100)!;
  late final TextEditingController _amount;
  late final TextEditingController _count;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null && e.servingLabel != null && e.servingCount != null) {
      for (final s in _servings) {
        if (s.label == e.servingLabel) _serving = s;
      }
    }
    _amount = TextEditingController(
      text: e == null ? '100' : formatNumber(e.quantity.amount),
    );
    _count = TextEditingController(
      text: e?.servingCount == null
          ? '1'
          : formatNumber(e!.servingCount!, maxDecimals: 2),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _count.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Quantity? get _entered {
    final v = _num(_amount);
    if (v == null) return null;
    return switch (_entryUnit.toCanonical(v)) {
      Ok(:final value) => value,
      Err() => null,
    };
  }

  /// Validation error for the typed amount in the current unit, or null when
  /// it converts to a stored quantity.
  String? get _amountError {
    if (_amount.text.trim().isEmpty) return null;
    final v = _num(_amount);
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
        // Not a valid amount in the old unit: clear rather than reinterpret
        // it in the new unit (review R15-02).
        _amount.clear();
      }
      _entryUnit = next;
      _error = invalid;
    });
  }

  void _save() {
    final s = _serving;
    final count = s == null ? null : _num(_count);
    final raw = s == null ? _num(_amount) : count;
    if (raw == null || raw <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    final Quantity quantity;
    if (s != null) {
      quantity = s.quantityFor(raw);
    } else {
      final q = _entryUnit.toCanonical(raw);
      if (q case Err(:final error)) {
        setState(() => _error = userMessageFor(error));
        return;
      }
      quantity = (q as Ok<Quantity>).value;
    }
    if (quantity.amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    Navigator.of(context).pop(
      RecipeIngredient(
        id: widget.id,
        name: _name,
        foodId: _foodId,
        quantity: quantity,
        sortOrder: widget.sortOrder,
        per100: _profile,
        note: widget.existing?.note,
        servingLabel: s?.label,
        servingCount: count,
        substitutes: widget.existing?.substitutes ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = _profile.per100.symbol;
    final entered = _entered;
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
            Text(_name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: RfSpace.s1),
            ProvenanceBadge(_profile.provenance),
            const SizedBox(height: RfSpace.s4),
            if (_servings.isNotEmpty) ...[
              Wrap(
                spacing: RfSpace.s2,
                children: [
                  ChoiceChip(
                    key: const Key('ingredient-unit'),
                    label: Text('Amount ($unit)'),
                    selected: _serving == null,
                    onSelected: (_) => setState(() => _serving = null),
                  ),
                  for (final s in _servings)
                    ChoiceChip(
                      label: Text('${s.label} (${s.quantity.label})'),
                      selected: _serving == s,
                      onSelected: (_) => setState(() => _serving = s),
                    ),
                ],
              ),
              const SizedBox(height: RfSpace.s3),
            ],
            if (_serving == null) ...[
              SegmentedButton<EntryUnit>(
                key: const Key('ingredient-entry-unit'),
                showSelectedIcon: false,
                segments: [
                  for (final u in EntryUnit.forBase(_profile.per100))
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
                key: const Key('ingredient-amount'),
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
                    key: const Key('ingredient-canonical'),
                    '= ${entered.label}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ] else
              RfTextField.number(
                key: const Key('ingredient-count'),
                controller: _count,
                label: 'Number of ${_serving!.label}',
                decimals: 2,
                errorText: _error,
                onChanged: (_) => setState(() => _error = null),
              ),
            const SizedBox(height: RfSpace.s4),
            RfButton(
              key: const Key('ingredient-save'),
              label: widget.existing == null ? 'Add ingredient' : 'Save',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
