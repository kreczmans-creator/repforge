import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/nutrition/presentation/nutrient_display.dart';
import 'package:repforge/features/nutrition/presentation/portion_sheet.dart';
import 'package:repforge/features/nutrition/presentation/provenance_badge.dart';
import 'package:repforge/features/planning/application/planning_providers.dart';
import 'package:repforge/features/planning/presentation/plan_format.dart';
import 'package:repforge/features/recipes/application/recipe_providers.dart';
import 'package:repforge/features/settings/application/meal_label_providers.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Sheet to log a recipe (RCP-012): portions (default 1, step 0.5) or grams
/// (only when the recipe has a total weight), meal, live preview. Returns the
/// logged entry.
Future<FoodLogEntry?> showRecipeLogSheet(BuildContext context, Recipe recipe) =>
    showModalBottomSheet<FoodLogEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecipeLogSheet(recipe: recipe),
    );

class _RecipeLogSheet extends ConsumerStatefulWidget {
  const _RecipeLogSheet({required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<_RecipeLogSheet> createState() => _RecipeLogSheetState();
}

class _RecipeLogSheetState extends ConsumerState<_RecipeLogSheet> {
  final _portions = TextEditingController(text: '1');
  final _grams = TextEditingController();
  bool _byGrams = false;
  late MealSlot _meal = defaultMealFor(ref.read(clockProvider).now().toLocal());
  String? _batchId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _portions.dispose();
    _grams.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  bool get _canLogGrams => widget.recipe.effectiveTotalWeightG != null;

  NutrientAmounts? get _preview {
    final v = _parse(_byGrams ? _grams : _portions);
    if (v == null || v <= 0) return null;
    return _byGrams
        ? widget.recipe.nutritionForWeight(v)
        : widget.recipe.nutritionForPortions(v);
  }

  void _step(double delta) {
    final current = _parse(_portions) ?? 0;
    final next = (current + delta).clamp(0.5, 1000).toDouble();
    setState(() {
      _portions.text = formatNumber(next);
      _error = null;
    });
  }

  Future<void> _log() async {
    if (_busy) return;
    final v = _parse(_byGrams ? _grams : _portions);
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(logRecipeProvider)(
      recipeId: widget.recipe.id,
      meal: _meal,
      day: ref.read(selectedDayProvider),
      portions: _byGrams ? null : v,
      grams: _byGrams ? v : null,
      prepBatchId: _byGrams ? null : _batchId,
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
    final labels = ref.watch(mealLabelsValueProvider);
    final preview = _preview;
    final batches = [
      for (final b
          in ref.watch(prepBatchesForRecipeProvider(widget.recipe.id)).value ??
              const <PrepBatch>[])
        if (!b.isEmpty) b,
    ];
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
            Text(widget.recipe.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: RfSpace.s1),
            ProvenanceBadge(widget.recipe.provenance),
            const SizedBox(height: RfSpace.s4),
            if (_canLogGrams) ...[
              SegmentedButton<bool>(
                key: const Key('log-mode'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Portions')),
                  ButtonSegment(value: true, label: Text('Grams')),
                ],
                selected: {_byGrams},
                onSelectionChanged: (s) => setState(() {
                  _byGrams = s.first;
                  _error = null;
                  _batchId = null;
                }),
              ),
              const SizedBox(height: RfSpace.s3),
            ],
            if (_byGrams)
              RfTextField.number(
                key: const Key('log-grams'),
                controller: _grams,
                label: 'Amount eaten',
                unit: 'g',
                errorText: _error,
                autofocus: true,
                onChanged: (_) => setState(() => _error = null),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    key: const Key('log-portions-dec'),
                    tooltip: 'Fewer portions',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _step(-0.5),
                  ),
                  Expanded(
                    child: RfTextField.number(
                      key: const Key('log-portions'),
                      controller: _portions,
                      label: 'Portions',
                      errorText: _error,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                  IconButton(
                    key: const Key('log-portions-inc'),
                    tooltip: 'More portions',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _step(0.5),
                  ),
                ],
              ),
            if (!_byGrams && batches.isNotEmpty) ...[
              const SizedBox(height: RfSpace.s3),
              Text('FROM PREPARED BATCH', style: context.rfText.kicker),
              const SizedBox(height: RfSpace.s2),
              Wrap(
                spacing: RfSpace.s2,
                children: [
                  ChoiceChip(
                    key: const Key('log-batch-none'),
                    label: const Text('None'),
                    selected: _batchId == null,
                    onSelected: (_) => setState(() {
                      _batchId = null;
                      _error = null;
                    }),
                  ),
                  for (final b in batches)
                    ChoiceChip(
                      key: Key('log-batch-${b.id}'),
                      label: Text(portionsLeftLabel(b.portionsRemaining)),
                      selected: _batchId == b.id,
                      onSelected: (_) => setState(() {
                        _batchId = b.id;
                        _error = null;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: RfSpace.s3),
            Text('MEAL', style: context.rfText.kicker),
            const SizedBox(height: RfSpace.s2),
            SegmentedButton<MealSlot>(
              key: const Key('log-meal'),
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
                key: const Key('log-preview'),
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Figure('kcal', formatNumber(preview.kcal, maxDecimals: 0)),
                  _Figure('P', gramsOrNa(preview.proteinG)),
                  _Figure('C', gramsOrNa(preview.carbsG)),
                  _Figure('F', gramsOrNa(preview.fatG)),
                  _Figure('Fibre', gramsOrNa(preview.fibreG)),
                ],
              )
            else
              Text(
                'No nutrition to preview.',
                key: const Key('log-preview-none'),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: RfSpace.s4),
            RfButton(
              key: const Key('log-submit'),
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
