import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/nutrition/presentation/provenance_badge.dart';
import 'package:repforge/features/planning/presentation/plan_format.dart';
import 'package:repforge/features/recipes/application/recipe_list_providers.dart';
import 'package:repforge/features/recipes/application/recipe_providers.dart';
import 'package:repforge/features/recipes/presentation/prep_batches_section.dart';
import 'package:repforge/features/recipes/presentation/recipe_format.dart';
import 'package:repforge/features/recipes/presentation/recipe_log_sheet.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Recipe detail (RCP-003, 004, 005, 007, 009, 010, 012).
class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({required this.recipeId, super.key});

  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

enum _ScaleBy { portions, weight }

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  final _scaleTarget = TextEditingController();
  _ScaleBy _scaleBy = _ScaleBy.portions;
  bool _scaling = false;

  /// Chosen substitute index per ingredient id (absent = the original).
  final Map<String, int> _subs = {};
  bool _busy = false;

  @override
  void dispose() {
    _scaleTarget.dispose();
    super.dispose();
  }

  /// The scaled view for the current target, or the error to show.
  Result<Recipe>? _scaled(Recipe base) {
    if (!_scaling) return null;
    final t = double.tryParse(_scaleTarget.text.trim().replaceAll(',', '.'));
    if (t == null) return null;
    if (t <= 0) {
      return const Err(
        ValidationError('Enter a target greater than zero.', field: 'target'),
      );
    }
    return _scaleBy == _ScaleBy.portions
        ? base.scaleToPortions(t)
        : base.scaleToWeight(t);
  }

  Recipe _applySubstitutions(Recipe r) {
    var view = r;
    for (final e in _subs.entries) {
      if (view.withSubstitution(e.key, e.value) case Ok(:final value)) {
        view = value;
      }
    }
    return view;
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _log(Recipe r) async {
    final entry = await showRecipeLogSheet(context, r);
    if (!mounted || entry == null) return;
    _snack('Logged ${entry.quantity.label} of ${entry.name}');
  }

  Future<void> _recordBatch(Recipe r) async {
    final batch = await showRecordBatchSheet(context, r);
    if (!mounted || batch == null) return;
    _snack('Recorded a batch of ${portionsLabel(batch.portionsMade)}');
  }

  Future<void> _saveScaled(Recipe scaled, {required bool asNew}) async {
    if (_busy) return;
    if (!asNew) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Overwrite recipe?'),
          content: const Text(
            'The saved quantities and portions are replaced by the scaled '
            'ones.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('scale-overwrite-confirm'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    final toSave = asNew
        ? scaled.copyWith(
            name: '${scaled.name} (${formatNumber(scaled.portions)} portions)',
          )
        : scaled;
    final result = await ref.read(saveRecipeProvider)(toSave, saveAsNew: asNew);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok(:final value):
        setState(() {
          _scaling = false;
          _scaleTarget.clear();
        });
        if (asNew) {
          _snack('Saved as a new recipe');
          await context.push<void>(RfRoutes.fuelRecipe(value.id));
        } else {
          _snack('Recipe updated');
        }
      case Err(:final error):
        _snack(userMessageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recipeByIdProvider(widget.recipeId), (prev, next) {
      // The recipe was deleted while this screen was open.
      if (prev?.value != null && next.hasValue && next.value == null) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      }
    });
    final async = ref.watch(recipeByIdProvider(widget.recipeId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe'),
        actions: [
          if (async.value != null)
            IconButton(
              key: const Key('recipe-edit'),
              tooltip: 'Edit recipe',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(RfRoutes.fuelRecipeEdit(widget.recipeId)),
            ),
        ],
      ),
      body: async.when(
        loading: () => const RfLoading(),
        error: (e, _) => const RfErrorState(message: 'Could not load recipe.'),
        data: (r) => r == null
            ? const Padding(
                padding: EdgeInsets.all(RfSpace.gutter),
                child: RfEmptyState(
                  key: Key('recipe-missing'),
                  message: 'That recipe no longer exists.',
                ),
              )
            : _body(context, r),
      ),
    );
  }

  Widget _body(BuildContext context, Recipe base) {
    final theme = Theme.of(context);
    final scaledResult = _scaled(base);
    // A target equal to the saved recipe is not a scaled view.
    final scaled = scaledResult is Ok<Recipe> && scaledResult.value != base
        ? scaledResult.value
        : null;
    final scaleError = scaledResult is Err<Recipe>
        ? userMessageFor(scaledResult.error)
        : null;
    final shown = scaled ?? base;
    final view = _applySubstitutions(shown);
    final delta = _subs.isEmpty ? null : _kcalDelta(shown, view);
    final total = base.totalMinutes;
    final scaleByWeightPossible = base.effectiveTotalWeightG != null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
      children: [
        const SizedBox(height: RfSpace.s2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                base.name,
                key: const Key('recipe-name'),
                style: theme.textTheme.headlineMedium,
              ),
            ),
            IconButton(
              key: Key('fav-${base.id}'),
              tooltip: base.favourite
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              icon: Icon(
                base.favourite ? Icons.star : Icons.star_outline,
                color: base.favourite ? context.rf.accentText : null,
              ),
              onPressed: () => ref.read(toggleFavouriteProvider)(base.id),
            ),
          ],
        ),
        if (base.category.trim().isNotEmpty)
          Text(base.category, style: theme.textTheme.bodySmall),
        if (base.description.trim().isNotEmpty) ...[
          const SizedBox(height: RfSpace.s2),
          Text(base.description, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: RfSpace.s3),
        RfButton(
          key: const Key('recipe-log'),
          label: 'Log',
          icon: Icons.add,
          onPressed: () => _log(base),
        ),
        const SizedBox(height: RfSpace.s2),
        RfButton(
          key: const Key('record-batch'),
          label: 'Record batch',
          icon: Icons.kitchen_outlined,
          variant: RfButtonVariant.secondary,
          onPressed: () => _recordBatch(base),
        ),
        const SizedBox(height: RfSpace.s3),
        RfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('PER PORTION', style: context.rfText.kicker),
                  ),
                  ProvenanceBadge(view.provenance),
                ],
              ),
              const SizedBox(height: RfSpace.s2),
              RecipeNutritionPanel(recipe: view),
              if (delta != null) ...[
                const SizedBox(height: RfSpace.s2),
                Text(
                  '${delta >= 0 ? '+' : '-'}'
                  '${formatNumber(delta.abs(), maxDecimals: 0)} kcal per '
                  'portion',
                  key: const Key('sub-delta'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.rf.accentText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (base.nutritionSource == RecipeNutritionSource.declared) ...[
                const SizedBox(height: RfSpace.s2),
                Text(
                  base.nutritionNote?.trim().isNotEmpty ?? false
                      ? 'Estimated nutrition: ${base.nutritionNote}'
                      : 'Estimated nutrition: not calculated from '
                            'ingredients.',
                  key: const Key('nutrition-note'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: RfSpace.s3),
        RfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Makes ${formatNumber(shown.portions, maxDecimals: 2)} '
                'portions',
                key: const Key('recipe-portions'),
                style: theme.textTheme.bodyMedium,
              ),
              if (total != null) ...[
                const SizedBox(height: RfSpace.s1),
                Text(
                  'Total time: ${minutesLabel(total)}',
                  key: const Key('recipe-total-time'),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  [
                    if (base.prepMinutes != null)
                      'Prep ${minutesLabel(base.prepMinutes!)}',
                    if (base.cookMinutes != null)
                      'Cook ${minutesLabel(base.cookMinutes!)}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: RfSpace.s1),
              Text(
                freezingLabel(base.freezing),
                key: const Key('recipe-freezing'),
                style: theme.textTheme.bodyMedium,
              ),
              if (base.storage?.trim().isNotEmpty ?? false)
                Text(
                  'Storage: ${base.storage}',
                  key: const Key('recipe-storage'),
                  style: theme.textTheme.bodyMedium,
                ),
              if (base.reheating?.trim().isNotEmpty ?? false)
                Text(
                  'Reheating: ${base.reheating}',
                  key: const Key('recipe-reheating'),
                  style: theme.textTheme.bodyMedium,
                ),
            ],
          ),
        ),
        PrepBatchesSection(recipeId: base.id),
        if (base.ingredients.isNotEmpty) ...[
          const SizedBox(height: RfSpace.s3),
          _scaleCard(context, base, scaled, scaleError, scaleByWeightPossible),
        ],
        const SizedBox(height: RfSpace.s3),
        if (shown.ingredients.isNotEmpty) ...[
          const RfSectionHeader(title: 'Ingredients'),
          RfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < view.ingredients.length; i++)
                  _ingredientRow(
                    context,
                    shown.ingredients[i],
                    view.ingredients[i],
                  ),
              ],
            ),
          ),
        ],
        if (base.ingredientNotes.isNotEmpty) ...[
          const RfSectionHeader(
            title:
                'Ingredients (from the original recipe, not linked to foods)',
          ),
          RfCard(
            key: const Key('ingredient-notes'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in base.ingredientNotes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(n, style: theme.textTheme.bodyMedium),
                  ),
              ],
            ),
          ),
        ],
        if (base.prepSteps.isNotEmpty)
          _steps(context, 'Preparation', 'prep', base.prepSteps),
        if (base.cookSteps.isNotEmpty)
          _steps(context, 'Cooking', 'cook', base.cookSteps),
        const SizedBox(height: RfSpace.s8),
      ],
    );
  }

  double? _kcalDelta(Recipe before, Recipe after) {
    if (!before.allIngredientsCalculable) return null;
    final a = before.perPortion?.kcal;
    final b = after.perPortion?.kcal;
    if (a == null || b == null) return null;
    return b - a;
  }

  Widget _steps(
    BuildContext context,
    String title,
    String prefix,
    List<String> steps,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RfSectionHeader(title: title),
      RfCard(
        key: Key('$prefix-steps'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: RfSpace.s1),
                child: Text(
                  '${i + 1}. ${steps[i]}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _ingredientRow(
    BuildContext context,
    RecipeIngredient original,
    RecipeIngredient shown,
  ) {
    final theme = Theme.of(context);
    final chosen = _subs[original.id];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RfSpace.s1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shown.name,
                  key: Key('ingredient-name-${original.id}'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                ingredientQuantityLabel(shown),
                key: Key('ingredient-qty-${original.id}'),
                style: context.rfText.dataS,
              ),
            ],
          ),
          if (original.substitutes.isNotEmpty)
            Wrap(
              spacing: RfSpace.s2,
              children: [
                ChoiceChip(
                  key: Key('sub-${original.id}-original'),
                  label: const Text('Original'),
                  selected: chosen == null,
                  onSelected: (_) => setState(() => _subs.remove(original.id)),
                ),
                for (var s = 0; s < original.substitutes.length; s++)
                  ChoiceChip(
                    key: Key('sub-${original.id}-$s'),
                    label: Text(original.substitutes[s].name),
                    selected: chosen == s,
                    onSelected: (_) => setState(() => _subs[original.id] = s),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _scaleCard(
    BuildContext context,
    Recipe base,
    Recipe? scaled,
    String? error,
    bool byWeightPossible,
  ) {
    final theme = Theme.of(context);
    if (!_scaling) {
      return RfButton(
        key: const Key('scale-open'),
        label: 'Scale recipe',
        icon: Icons.tune,
        variant: RfButtonVariant.secondary,
        onPressed: () => setState(() {
          _scaling = true;
          _scaleBy = _ScaleBy.portions;
          _scaleTarget.text = formatNumber(base.portions, maxDecimals: 2);
        }),
      );
    }
    return RfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('SCALE', style: context.rfText.kicker)),
              TextButton(
                key: const Key('scale-close'),
                onPressed: () => setState(() {
                  _scaling = false;
                  _scaleTarget.clear();
                }),
                child: const Text('Close'),
              ),
            ],
          ),
          SegmentedButton<_ScaleBy>(
            key: const Key('scale-mode'),
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(
                value: _ScaleBy.portions,
                label: Text('Portions'),
              ),
              ButtonSegment(
                value: _ScaleBy.weight,
                label: const Text('Total weight'),
                enabled: byWeightPossible,
              ),
            ],
            selected: {_scaleBy},
            onSelectionChanged: (s) => setState(() {
              _scaleBy = s.first;
              _scaleTarget.text = _scaleBy == _ScaleBy.portions
                  ? formatNumber(base.portions, maxDecimals: 2)
                  : formatNumber(base.effectiveTotalWeightG ?? 0);
            }),
          ),
          const SizedBox(height: RfSpace.s2),
          RfTextField.number(
            key: const Key('scale-target'),
            controller: _scaleTarget,
            label: _scaleBy == _ScaleBy.portions
                ? 'Target portions'
                : 'Target total weight',
            unit: _scaleBy == _ScaleBy.portions ? null : 'g',
            decimals: 2,
            errorText: error,
            onChanged: (_) => setState(() {}),
          ),
          if (!byWeightPossible)
            Text(
              'Scaling by weight needs every ingredient in grams or a total '
              'weight.',
              style: theme.textTheme.bodySmall,
            ),
          if (scaled != null) ...[
            const SizedBox(height: RfSpace.s2),
            Text(
              'Scaled view - not saved',
              key: const Key('scaled-indicator'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.rf.accentText,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Per-portion values stay the same.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: RfSpace.s2),
            Row(
              children: [
                Expanded(
                  child: RfButton(
                    key: const Key('scale-save-new'),
                    label: 'Save as new',
                    loading: _busy,
                    onPressed: () => _saveScaled(scaled, asNew: true),
                  ),
                ),
                const SizedBox(width: RfSpace.s2),
                Expanded(
                  child: RfButton(
                    key: const Key('scale-overwrite'),
                    label: 'Overwrite',
                    variant: RfButtonVariant.secondary,
                    onPressed: _busy
                        ? null
                        : () => _saveScaled(scaled, asNew: false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
