import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Create a user food with nutrients per 100 g/ml and optional servings
/// (NUT-006, NUT-007). Pops with the created [Food].
class CustomFoodScreen extends ConsumerStatefulWidget {
  const CustomFoodScreen({super.key});

  @override
  ConsumerState<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends ConsumerState<CustomFoodScreen> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _barcode = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fibre = TextEditingController();
  final _servings = <(TextEditingController, TextEditingController)>[];
  ReferenceUnit _unit = ReferenceUnit.grams;
  String? _error;
  String? _errorField;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _brand,
      _barcode,
      _kcal,
      _protein,
      _carbs,
      _fat,
      _fibre,
    ]) {
      c.dispose();
    }
    for (final (a, b) in _servings) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorField = null;
    });
    final result = await ref.read(createCustomFoodProvider)(
      name: _name.text,
      brand: _brand.text,
      barcode: _barcode.text,
      per100: _unit,
      kcal: _kcal.text,
      proteinG: _protein.text,
      carbsG: _carbs.text,
      fatG: _fat.text,
      fibreG: _fibre.text,
      servings: [
        for (final (l, a) in _servings) (label: l.text, amount: a.text),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        final nav = Navigator.of(context);
        if (nav.canPop()) nav.pop(value);
      case Err(:final error):
        setState(() {
          _busy = false;
          _error = userMessageFor(error);
          _errorField = error is ValidationError ? error.field : null;
        });
    }
  }

  static const _fields = {
    'name',
    'kcal',
    'proteinG',
    'carbsG',
    'fatG',
    'fibreG',
    'servings',
  };

  String? _err(String field) => _errorField == field ? _error : null;

  /// Errors for fields this form cannot point at (e.g. 'quantity' from a
  /// serving amount) are shown in the generic block below the form.
  bool get _showGenericError =>
      _error != null && (_errorField == null || !_fields.contains(_errorField));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = _unit.symbol;
    return Scaffold(
      appBar: AppBar(title: const Text('New food')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'New food',
            caption: 'Nutrients per 100 g or 100 ml, from the label',
          ),
          RfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RfTextField(
                  key: const Key('food-name'),
                  controller: _name,
                  label: 'Name',
                  errorText: _err('name'),
                  autofocus: true,
                ),
                const SizedBox(height: RfSpace.s3),
                Row(
                  children: [
                    Expanded(
                      child: RfTextField(
                        key: const Key('food-brand'),
                        controller: _brand,
                        label: 'Brand (optional)',
                      ),
                    ),
                    rfFieldGap,
                    Expanded(
                      child: RfTextField.integer(
                        key: const Key('food-barcode'),
                        controller: _barcode,
                        label: 'Barcode (optional)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RfSpace.s3),
                Text('VALUES PER 100', style: context.rfText.kicker),
                const SizedBox(height: RfSpace.s2),
                SegmentedButton<ReferenceUnit>(
                  key: const Key('food-unit'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ReferenceUnit.grams,
                      label: Text('grams'),
                    ),
                    ButtonSegment(
                      value: ReferenceUnit.millilitres,
                      label: Text('millilitres'),
                    ),
                  ],
                  selected: {_unit},
                  onSelectionChanged: (s) => setState(() => _unit = s.first),
                ),
                const SizedBox(height: RfSpace.s3),
                RfTextField.number(
                  key: const Key('food-kcal'),
                  controller: _kcal,
                  label: 'Energy',
                  unit: 'kcal / 100 $unit',
                  errorText: _err('kcal'),
                ),
                const SizedBox(height: RfSpace.s3),
                Row(
                  children: [
                    Expanded(
                      child: RfTextField.number(
                        key: const Key('food-protein'),
                        controller: _protein,
                        label: 'Protein',
                        unit: 'g',
                        errorText: _err('proteinG'),
                      ),
                    ),
                    rfFieldGap,
                    Expanded(
                      child: RfTextField.number(
                        key: const Key('food-carbs'),
                        controller: _carbs,
                        label: 'Carbs',
                        unit: 'g',
                        errorText: _err('carbsG'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RfSpace.s3),
                Row(
                  children: [
                    Expanded(
                      child: RfTextField.number(
                        key: const Key('food-fat'),
                        controller: _fat,
                        label: 'Fat',
                        unit: 'g',
                        errorText: _err('fatG'),
                      ),
                    ),
                    rfFieldGap,
                    Expanded(
                      child: RfTextField.number(
                        key: const Key('food-fibre'),
                        controller: _fibre,
                        label: 'Fibre (optional)',
                        unit: 'g',
                        errorText: _err('fibreG'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s3),
          RfSectionHeader(
            title: 'Servings',
            actionLabel: 'Add serving',
            onAction: () => setState(
              () => _servings.add((
                TextEditingController(),
                TextEditingController(),
              )),
            ),
          ),
          if (_servings.isEmpty)
            Text(
              'Optional. For example "1 slice" = 35 $unit.',
              style: theme.textTheme.bodySmall,
            )
          else
            RfCard(
              child: Column(
                children: [
                  for (var i = 0; i < _servings.length; i++) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: RfTextField(
                            key: Key('serving-label-$i'),
                            controller: _servings[i].$1,
                            label: 'Serving name',
                          ),
                        ),
                        rfFieldGap,
                        Expanded(
                          flex: 2,
                          child: RfTextField.number(
                            key: Key('serving-amount-$i'),
                            controller: _servings[i].$2,
                            label: 'Amount',
                            unit: unit,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove serving',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            final (a, b) = _servings.removeAt(i);
                            a.dispose();
                            b.dispose();
                          }),
                        ),
                      ],
                    ),
                    if (i < _servings.length - 1)
                      const SizedBox(height: RfSpace.s2),
                  ],
                  if (_err('servings') != null)
                    Padding(
                      padding: const EdgeInsets.only(top: RfSpace.s2),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.rf.alertText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_showGenericError) ...[
            const SizedBox(height: RfSpace.s2),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.rf.alertText,
              ),
            ),
          ],
          const SizedBox(height: RfSpace.s4),
          RfButton(
            key: const Key('food-save'),
            label: 'Save food',
            loading: _busy,
            onPressed: _save,
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}
