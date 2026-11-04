import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/recipes/application/recipe_list_providers.dart';
import 'package:repforge/features/recipes/application/recipe_providers.dart';
import 'package:repforge/features/recipes/presentation/ingredient_sheet.dart';
import 'package:repforge/features/recipes/presentation/recipe_format.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Create or edit a recipe (RCP-001..005, 008, 011). Pops with the saved
/// recipe. With [recipeId] null a new recipe is created.
class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, this.recipeId});

  final String? recipeId;

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _portions = TextEditingController(text: '1');
  final _totalWeight = TextEditingController();
  final _portionWeight = TextEditingController();
  final _prep = TextEditingController();
  final _cook = TextEditingController();
  final _storage = TextEditingController();
  final _reheating = TextEditingController();
  final List<TextEditingController> _prepSteps = [];
  final List<TextEditingController> _cookSteps = [];
  List<RecipeIngredient> _ingredients = [];
  bool _byWeight = false;
  FreezingSuitability _freezing = FreezingSuitability.unknown;
  bool _favourite = false;

  Recipe? _original;
  bool _seeded = false;
  bool _busy = false;
  String? _error;
  String? _errorField;

  bool get _isNew => widget.recipeId == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) _seeded = true;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _category,
      _description,
      _portions,
      _totalWeight,
      _portionWeight,
      _prep,
      _cook,
      _storage,
      _reheating,
      ..._prepSteps,
      ..._cookSteps,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(Recipe r) {
    if (_seeded) return;
    _seeded = true;
    _original = r;
    _name.text = r.name;
    _category.text = r.category;
    _description.text = r.description;
    _byWeight = r.portionWeightG != null;
    _portions.text = formatNumber(r.portions, maxDecimals: 2);
    _totalWeight.text = r.totalWeightG == null
        ? ''
        : formatNumber(r.totalWeightG!);
    _portionWeight.text = r.portionWeightG == null
        ? ''
        : formatNumber(r.portionWeightG!);
    _prep.text = r.prepMinutes?.toString() ?? '';
    _cook.text = r.cookMinutes?.toString() ?? '';
    _storage.text = r.storage ?? '';
    _reheating.text = r.reheating ?? '';
    _freezing = r.freezing;
    _favourite = r.favourite;
    _ingredients = [...r.ingredients];
    _prepSteps.addAll(r.prepSteps.map((s) => TextEditingController(text: s)));
    _cookSteps.addAll(r.cookSteps.map((s) => TextEditingController(text: s)));
  }

  double? _num(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.')) ?? double.nan;
  }

  /// Portions derived from weights, or null.
  double? get _derived =>
      portionsByWeight(_num(_totalWeight), _num(_portionWeight));

  Recipe _build() {
    final now = ref.read(clockProvider).now().toUtc();
    final base =
        _original ??
        Recipe(
          id: ref.read(idGeneratorProvider)(),
          name: '',
          category: '',
          portions: 1,
          ingredients: const [],
          createdAt: now,
          updatedAt: now,
        );
    final total = _num(_totalWeight);
    final portionW = _byWeight ? _num(_portionWeight) : null;
    final portions = _byWeight
        ? (portionsByWeight(total, portionW) ?? 0)
        : (_num(_portions) ?? 0);
    int? minutes(TextEditingController c) {
      final t = c.text.trim();
      if (t.isEmpty) return null;
      return int.tryParse(t) ?? -1;
    }

    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return base.copyWith(
      name: _name.text,
      category: _category.text.trim(),
      description: _description.text.trim(),
      portions: portions,
      totalWeightG: total,
      portionWeightG: portionW,
      ingredients: [
        for (var i = 0; i < _ingredients.length; i++)
          _ingredients[i].copyWith(sortOrder: i),
      ],
      prepSteps: [for (final c in _prepSteps) c.text],
      cookSteps: [for (final c in _cookSteps) c.text],
      prepMinutes: minutes(_prep),
      cookMinutes: minutes(_cook),
      storage: text(_storage),
      reheating: text(_reheating),
      freezing: _freezing,
      favourite: _favourite,
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorField = null;
    });
    final result = await ref.read(saveRecipeProvider)(_build());
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final error):
        setState(() {
          _busy = false;
          _error = userMessageFor(error);
          _errorField = error is ValidationError ? error.field : null;
        });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: const Text(
          'Meals you already logged from this recipe keep their values.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('recipe-delete-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await ref.read(deleteRecipeProvider)(widget.recipeId!);
    if (!mounted) return;
    switch (result) {
      case Ok():
        // Detail screens close themselves when the recipe disappears.
        if (context.canPop()) context.pop();
      case Err(:final error):
        setState(() => _error = userMessageFor(error));
    }
  }

  Future<void> _addIngredient() async {
    final food = await context.push<Food>(RfRoutes.fuelPickFood);
    if (!mounted || food == null) return;
    final ing = await showIngredientSheet(
      context,
      id: ref.read(idGeneratorProvider)(),
      sortOrder: _ingredients.length,
      food: food,
    );
    if (!mounted || ing == null) return;
    setState(() {
      _ingredients = [..._ingredients, ing];
      _clearError('ingredients');
    });
  }

  Future<void> _editIngredient(int index) async {
    final existing = _ingredients[index];
    if (existing.per100 == null) return;
    final ing = await showIngredientSheet(
      context,
      id: existing.id,
      sortOrder: index,
      existing: existing,
    );
    if (!mounted || ing == null) return;
    setState(() {
      _ingredients = [
        for (var i = 0; i < _ingredients.length; i++)
          if (i == index) ing else _ingredients[i],
      ];
      _clearError('quantity');
    });
  }

  void _clearError(String field) {
    if (_errorField == field) {
      _error = null;
      _errorField = null;
    }
  }

  void _moveIngredient(int index, int delta) {
    final to = index + delta;
    if (to < 0 || to >= _ingredients.length) return;
    setState(() {
      final list = [..._ingredients];
      final item = list.removeAt(index);
      list.insert(to, item);
      _ingredients = list;
    });
  }

  void _moveStep(List<TextEditingController> list, int index, int delta) {
    final to = index + delta;
    if (to < 0 || to >= list.length) return;
    setState(() {
      final item = list.removeAt(index);
      list.insert(to, item);
    });
  }

  String? _errorFor(String field) => _errorField == field ? _error : null;

  @override
  Widget build(BuildContext context) {
    if (!_isNew) {
      final async = ref.watch(recipeByIdProvider(widget.recipeId!));
      if (async.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Edit recipe')),
          body: const RfErrorState(message: 'Could not load recipe.'),
        );
      }
      final r = async.value;
      if (r == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Edit recipe')),
          body: async.isLoading
              ? const RfLoading()
              : const Padding(
                  padding: EdgeInsets.all(RfSpace.gutter),
                  child: RfEmptyState(message: 'That recipe no longer exists.'),
                ),
        );
      }
      _seed(r);
    }
    final theme = Theme.of(context);
    final original = _original;
    final imported =
        original != null &&
        original.ingredients.isEmpty &&
        _ingredients.isEmpty &&
        (original.ingredientNotes.isNotEmpty ||
            original.declaredPerPortion != null);
    final derived = _derived;
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New recipe' : 'Edit recipe')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const SizedBox(height: RfSpace.s3),
          if (imported) ...[
            RfCard(
              key: const Key('imported-note'),
              child: Text(
                'This is an imported recipe. Its original ingredient notes '
                'and estimated nutrition are kept until you add ingredients '
                'linked to foods; then nutrition is calculated from them.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: RfSpace.s3),
          ],
          RfTextField(
            key: const Key('recipe-name-field'),
            controller: _name,
            label: 'Name',
            errorText: _errorFor('name'),
            onChanged: (_) => setState(() => _clearError('name')),
          ),
          const SizedBox(height: RfSpace.s3),
          RfTextField(
            key: const Key('recipe-category-field'),
            controller: _category,
            label: 'Category',
            hint: 'e.g. Lunch',
          ),
          const SizedBox(height: RfSpace.s3),
          RfTextField(
            key: const Key('recipe-description-field'),
            controller: _description,
            label: 'Description',
            maxLines: 3,
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Portions'),
          SegmentedButton<bool>(
            key: const Key('portion-mode'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Number of portions')),
              ButtonSegment(value: true, label: Text('By weight')),
            ],
            selected: {_byWeight},
            onSelectionChanged: (s) => setState(() {
              _byWeight = s.first;
              _error = null;
              _errorField = null;
            }),
          ),
          const SizedBox(height: RfSpace.s3),
          if (!_byWeight)
            RfTextField.number(
              key: const Key('recipe-portions-field'),
              controller: _portions,
              label: 'Portions',
              decimals: 2,
              errorText: _errorFor('portions'),
              onChanged: (_) => setState(() => _clearError('portions')),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RfTextField.number(
                    key: const Key('recipe-total-weight-field'),
                    controller: _totalWeight,
                    label: 'Total weight',
                    unit: 'g',
                    errorText: _errorFor('totalWeightG'),
                    onChanged: (_) =>
                        setState(() => _clearError('totalWeightG')),
                  ),
                ),
                rfFieldGap,
                Expanded(
                  child: RfTextField.number(
                    key: const Key('recipe-portion-weight-field'),
                    controller: _portionWeight,
                    label: 'Portion weight',
                    unit: 'g',
                    errorText: _errorFor('portionWeightG'),
                    onChanged: (_) =>
                        setState(() => _clearError('portionWeightG')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RfSpace.s2),
            Text(
              derived == null
                  ? 'Enter both weights to get the number of portions.'
                  : '= ${formatNumber(derived, maxDecimals: 2)} portions',
              key: const Key('derived-portions'),
              style: theme.textTheme.bodyMedium,
            ),
            if (_errorFor('portions') != null)
              _FieldError(_errorFor('portions')!),
          ],
          if (!_byWeight) ...[
            const SizedBox(height: RfSpace.s3),
            RfTextField.number(
              key: const Key('recipe-total-weight-field'),
              controller: _totalWeight,
              label: 'Total cooked weight (optional)',
              unit: 'g',
              errorText: _errorFor('totalWeightG'),
              helper: 'Lets you log by grams.',
              onChanged: (_) => setState(() => _clearError('totalWeightG')),
            ),
          ],
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Time'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RfTextField.integer(
                  key: const Key('recipe-prep-field'),
                  controller: _prep,
                  label: 'Prep',
                  unit: 'min',
                  errorText: _errorFor('prepMinutes'),
                  onChanged: (_) => setState(() => _clearError('prepMinutes')),
                ),
              ),
              rfFieldGap,
              Expanded(
                child: RfTextField.integer(
                  key: const Key('recipe-cook-field'),
                  controller: _cook,
                  label: 'Cook',
                  unit: 'min',
                  errorText: _errorFor('cookMinutes'),
                  onChanged: (_) => setState(() => _clearError('cookMinutes')),
                ),
              ),
            ],
          ),
          const SizedBox(height: RfSpace.s4),
          RfSectionHeader(
            title: 'Ingredients',
            actionLabel: 'Add',
            onAction: _addIngredient,
          ),
          RfButton(
            key: const Key('add-ingredient'),
            label: 'Add ingredient',
            icon: Icons.add,
            variant: RfButtonVariant.secondary,
            onPressed: _addIngredient,
          ),
          const SizedBox(height: RfSpace.s2),
          if (_ingredients.isEmpty)
            Text(
              'No ingredients yet. Pick a food to add one.',
              style: theme.textTheme.bodySmall,
            )
          else
            RfCard(
              padding: const EdgeInsets.symmetric(
                horizontal: RfSpace.s3,
                vertical: RfSpace.s1,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _ingredients.length; i++)
                    _ingredientRow(i),
                ],
              ),
            ),
          if (_errorFor('ingredients') != null)
            _FieldError(_errorFor('ingredients')!),
          if (_errorFor('quantity') != null)
            _FieldError(_errorFor('quantity')!),
          const SizedBox(height: RfSpace.s4),
          _stepSection('Preparation', 'prep', _prepSteps),
          _stepSection('Cooking', 'cook', _cookSteps),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Storage and freezing'),
          RfTextField(
            key: const Key('recipe-storage-field'),
            controller: _storage,
            label: 'Storage',
            hint: 'e.g. Fridge, up to 3 days',
          ),
          const SizedBox(height: RfSpace.s3),
          SegmentedButton<FreezingSuitability>(
            key: const Key('recipe-freezing-field'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: FreezingSuitability.unknown,
                label: Text('Not stated'),
              ),
              ButtonSegment(value: FreezingSuitability.yes, label: Text('Yes')),
              ButtonSegment(value: FreezingSuitability.no, label: Text('No')),
            ],
            selected: {_freezing},
            onSelectionChanged: (s) => setState(() => _freezing = s.first),
          ),
          const SizedBox(height: RfSpace.s3),
          RfTextField(
            key: const Key('recipe-reheating-field'),
            controller: _reheating,
            label: 'Reheating',
          ),
          const SizedBox(height: RfSpace.s3),
          SwitchListTile(
            key: const Key('recipe-favourite-field'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Favourite'),
            value: _favourite,
            onChanged: (v) => setState(() => _favourite = v),
          ),
          if (_error != null &&
              !{
                'name',
                'portions',
                'ingredients',
                'quantity',
                'prepMinutes',
                'cookMinutes',
                'totalWeightG',
                'portionWeightG',
              }.contains(_errorField))
            _FieldError(_error!, key: const Key('recipe-error')),
          const SizedBox(height: RfSpace.s3),
          RfButton(
            key: const Key('recipe-save'),
            label: 'Save recipe',
            loading: _busy,
            onPressed: _save,
          ),
          if (!_isNew) ...[
            const SizedBox(height: RfSpace.s2),
            RfButton(
              key: const Key('recipe-delete'),
              label: 'Delete recipe',
              variant: RfButtonVariant.danger,
              onPressed: _busy ? null : _delete,
            ),
          ],
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }

  Widget _ingredientRow(int i) {
    final ing = _ingredients[i];
    return Row(
      key: ObjectKey(ing),
      children: [
        Expanded(
          child: InkWell(
            key: Key('ingredient-$i'),
            onTap: ing.per100 == null ? null : () => _editIngredient(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: RfSpace.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ing.name, style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    ingredientQuantityLabel(ing),
                    style: context.rfText.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          key: Key('ingredient-up-$i'),
          tooltip: 'Move up',
          icon: const Icon(Icons.arrow_upward, size: RfIcon.sm),
          onPressed: i == 0 ? null : () => _moveIngredient(i, -1),
        ),
        IconButton(
          key: Key('ingredient-down-$i'),
          tooltip: 'Move down',
          icon: const Icon(Icons.arrow_downward, size: RfIcon.sm),
          onPressed: i == _ingredients.length - 1
              ? null
              : () => _moveIngredient(i, 1),
        ),
        IconButton(
          key: Key('ingredient-delete-$i'),
          tooltip: 'Remove ingredient',
          icon: const Icon(Icons.delete_outline, size: RfIcon.sm),
          onPressed: () => setState(() {
            _ingredients = [..._ingredients]..removeAt(i);
          }),
        ),
      ],
    );
  }

  Widget _stepSection(
    String title,
    String prefix,
    List<TextEditingController> steps,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RfSectionHeader(title: title),
        for (var i = 0; i < steps.length; i++)
          Row(
            key: ObjectKey(steps[i]),
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: RfSpace.s1),
                  child: RfTextField(
                    key: Key('$prefix-step-$i'),
                    controller: steps[i],
                    label: 'Step ${i + 1}',
                    maxLines: 3,
                  ),
                ),
              ),
              Column(
                children: [
                  IconButton(
                    key: Key('$prefix-step-up-$i'),
                    tooltip: 'Move up',
                    icon: const Icon(Icons.arrow_upward, size: RfIcon.sm),
                    onPressed: i == 0 ? null : () => _moveStep(steps, i, -1),
                  ),
                  IconButton(
                    key: Key('$prefix-step-down-$i'),
                    tooltip: 'Move down',
                    icon: const Icon(Icons.arrow_downward, size: RfIcon.sm),
                    onPressed: i == steps.length - 1
                        ? null
                        : () => _moveStep(steps, i, 1),
                  ),
                ],
              ),
              IconButton(
                key: Key('$prefix-step-delete-$i'),
                tooltip: 'Delete step',
                icon: const Icon(Icons.delete_outline, size: RfIcon.sm),
                onPressed: () => setState(() {
                  steps.removeAt(i).dispose();
                }),
              ),
            ],
          ),
        TextButton.icon(
          key: Key('$prefix-step-add'),
          onPressed: () => setState(() => steps.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text('Add step'),
        ),
      ],
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: RfSpace.s1),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: context.rf.alertText),
    ),
  );
}
