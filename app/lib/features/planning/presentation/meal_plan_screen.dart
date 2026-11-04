import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/nutrition/presentation/nutrient_display.dart';
import 'package:repforge/features/nutrition/presentation/provenance_badge.dart';
import 'package:repforge/features/planning/application/plan_day_view.dart';
import 'package:repforge/features/planning/application/planning_providers.dart';
import 'package:repforge/features/planning/presentation/mark_eaten_sheet.dart';
import 'package:repforge/features/planning/presentation/plan_format.dart';
import 'package:repforge/features/planning/presentation/plan_quantity_sheet.dart';
import 'package:repforge/features/recipes/application/recipe_providers.dart';
import 'package:repforge/features/settings/application/meal_label_providers.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_macro_bar.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_stat_tile.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Meal plan (RCP-014): the next 28 days, four meals per day in the user's
/// label order, planned items with remove and mark-as-eaten, a day summary
/// with the diary's nutrient semantics, and the prepared batches (RCP-015).
typedef _Picked = ({String id, String name, ReferenceUnit unit});

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  /// Days after today, 0 to [planWindowDays] - 1.
  int _offset = 0;

  DateTime _today() {
    final now = ref.read(clockProvider).now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _date() {
    final t = _today();
    return DateTime(t.year, t.month, t.day + _offset);
  }

  void _shift(int delta) =>
      setState(() => _offset = (_offset + delta).clamp(0, planWindowDays - 1));

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add(MealSlot meal) async {
    final labels = ref.read(mealLabelsValueProvider);
    final kind = await showModalBottomSheet<PlannedKind>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('plan-add-recipe'),
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Recipe'),
              onTap: () => Navigator.of(ctx).pop(PlannedKind.recipe),
            ),
            ListTile(
              key: const Key('plan-add-food'),
              leading: const Icon(Icons.restaurant_outlined),
              title: const Text('Food'),
              onTap: () => Navigator.of(ctx).pop(PlannedKind.food),
            ),
            ListTile(
              key: const Key('plan-add-saved-meal'),
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Saved meal'),
              onTap: () => Navigator.of(ctx).pop(PlannedKind.savedMeal),
            ),
          ],
        ),
      ),
    );
    if (!mounted || kind == null) return;
    final chosen = switch (kind) {
      PlannedKind.recipe => await _chooseRecipe(),
      PlannedKind.food => await _chooseFood(),
      PlannedKind.savedMeal => await _chooseSavedMeal(),
    };
    if (!mounted || chosen == null) return;
    final item = await showPlanQuantitySheet(
      context,
      day: planDayKey(_date()),
      meal: meal,
      mealLabel: labels.labelOf(meal),
      kind: kind,
      refId: chosen.id,
      name: chosen.name,
      unit: chosen.unit,
    );
    if (!mounted || item == null) return;
    _snack('Planned ${item.name} for ${labels.labelOf(meal)}');
  }

  Future<_Picked?> _chooseRecipe() async {
    final recipe = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RecipePicker(),
    );
    return recipe == null
        ? null
        : (id: recipe.id, name: recipe.name, unit: ReferenceUnit.portions);
  }

  Future<_Picked?> _chooseFood() async {
    final food = await context.push<Food>(RfRoutes.fuelPickFood);
    return food == null
        ? null
        : (id: food.id, name: food.name, unit: food.profile.per100);
  }

  Future<_Picked?> _chooseSavedMeal() async {
    final meal = await showModalBottomSheet<SavedMeal>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SavedMealPicker(),
    );
    return meal == null
        ? null
        : (id: meal.id, name: meal.name, unit: ReferenceUnit.portions);
  }

  Future<void> _remove(MealPlanItem item) async {
    final result = await ref.read(removePlannedItemProvider)(item.id);
    if (!mounted) return;
    if (result case Err(:final error)) _snack(userMessageFor(error));
  }

  Future<void> _markEaten(MealPlanItem item) async {
    final entries = await showMarkEatenSheet(context, item);
    if (!mounted || entries == null) return;
    _snack('Marked ${item.name} as eaten');
  }

  @override
  Widget build(BuildContext context) {
    final date = _date();
    final day = planDayKey(date);
    final view = ref.watch(planDayViewProvider(day));
    final labels = ref.watch(mealLabelsValueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meal plan')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Meal plan',
            caption: 'Plan up to 28 days ahead',
          ),
          _Navigator(
            label: switch (_offset) {
              0 => 'Today',
              1 => 'Tomorrow',
              _ => DateFormat('EEE d MMM').format(date),
            },
            onPrevious: _offset == 0 ? null : () => _shift(-1),
            onNext: _offset >= planWindowDays - 1 ? null : () => _shift(1),
          ),
          view.when(
            loading: () => const RfLoading(),
            error: (e, _) =>
                const RfErrorState(message: 'Could not load the plan.'),
            data: (v) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Summary(summary: v.summary),
                const SizedBox(height: RfSpace.s2),
                for (final meal in labels.order)
                  _MealSection(
                    meal: meal,
                    label: labels.labelOf(meal),
                    lines: [
                      for (final l in v.lines)
                        if (l.item.meal == meal) l,
                    ],
                    onAdd: () => _add(meal),
                    onRemove: _remove,
                    onEat: _markEaten,
                  ),
              ],
            ),
          ),
          const _PrepList(),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

class _Navigator extends StatelessWidget {
  const _Navigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: RfSpace.s2),
    child: Row(
      children: [
        IconButton(
          key: const Key('plan-day-previous'),
          tooltip: 'Previous day',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            label,
            key: const Key('plan-day-label'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        IconButton(
          key: const Key('plan-day-next'),
          tooltip: 'Next day',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final PlanDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final t = summary.totals;
    final n = summary.unresolvedCount;
    final p = summary.provenance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RfStatTile(
          key: const Key('plan-kcal'),
          label: 'Planned energy',
          value: formatNumber(t.known.kcal, maxDecimals: 0),
          unit: 'kcal',
          caption: summary.itemCount == 1
              ? '1 planned item'
              : '${summary.itemCount} planned items',
        ),
        const SizedBox(height: RfSpace.s3),
        RfCard(
          child: Column(
            children: [
              RfMacroBar(
                label: 'Protein',
                amount: t.known.proteinG,
                target: null,
                unknownCount: t.unknownCount(Nutrient.proteinG),
              ),
              RfMacroBar(
                label: 'Carbs',
                amount: t.known.carbsG,
                target: null,
                unknownCount: t.unknownCount(Nutrient.carbsG),
                color: context.rf.textSecondary,
              ),
              RfMacroBar(
                label: 'Fat',
                amount: t.known.fatG,
                target: null,
                unknownCount: t.unknownCount(Nutrient.fatG),
                color: context.rf.textSecondary,
              ),
              RfMacroBar(
                label: 'Fibre',
                amount: t.known.fibreG,
                target: null,
                unknownCount: t.unknownCount(Nutrient.fibreG),
                color: context.rf.textSecondary,
              ),
              if (p != null) ...[
                const SizedBox(height: RfSpace.s2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ProvenanceBadge(p),
                ),
              ],
            ],
          ),
        ),
        if (n > 0) ...[
          const SizedBox(height: RfSpace.s2),
          Text(
            n == 1
                ? '1 planned item no longer exists'
                : '$n planned items no longer exist',
            key: const Key('plan-unresolved'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.rf.accentText,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'It is not counted in the totals. Remove it or plan something '
            'else.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.meal,
    required this.label,
    required this.lines,
    required this.onAdd,
    required this.onRemove,
    required this.onEat,
  });

  final MealSlot meal;
  final String label;
  final List<PlannedLine> lines;
  final VoidCallback onAdd;
  final void Function(MealPlanItem) onRemove;
  final void Function(MealPlanItem) onEat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kcal = NutrientAmounts.sum([
      for (final l in lines)
        if (l.nutrition != null) l.nutrition!,
    ]).kcal;
    return Column(
      key: Key('plan-meal-${meal.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: RfSpace.s3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  lines.isEmpty
                      ? label
                      : '$label · ${formatNumber(kcal, maxDecimals: 0)} kcal',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                key: Key('plan-add-${meal.name}'),
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: RfIcon.sm),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: RfSpace.s2),
            child: Text('Nothing planned.', style: theme.textTheme.bodySmall),
          )
        else
          RfCard(
            padding: const EdgeInsets.symmetric(
              horizontal: RfSpace.s4,
              vertical: RfSpace.s1,
            ),
            child: Column(
              children: [
                for (final l in lines)
                  _PlannedTile(line: l, onRemove: onRemove, onEat: onEat),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlannedTile extends StatelessWidget {
  const _PlannedTile({
    required this.line,
    required this.onRemove,
    required this.onEat,
  });

  final PlannedLine line;
  final void Function(MealPlanItem) onRemove;
  final void Function(MealPlanItem) onEat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = line.item;
    final kcal = line.nutrition?.kcal;
    return ListTile(
      key: Key('plan-item-${item.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        item.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          plannedQuantityLabel(item),
          if (!line.resolved) 'no longer exists',
          if (item.isEaten) 'Eaten',
        ].join(' · '),
        key: Key('plan-item-sub-${item.id}'),
        style: context.rfText.caption,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kcal == null
                ? unknownShort
                : '${formatNumber(kcal, maxDecimals: 0)} kcal',
            key: Key('plan-item-kcal-${item.id}'),
            style: context.rfText.dataS,
          ),
          if (item.isEaten)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RfSpace.s2),
              child: Icon(
                Icons.check_circle,
                key: Key('plan-eaten-${item.id}'),
                semanticLabel: 'Eaten',
                color: context.rf.successText,
              ),
            )
          else
            IconButton(
              key: Key('plan-eat-${item.id}'),
              tooltip: 'Mark as eaten',
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () => onEat(item),
            ),
          IconButton(
            key: Key('plan-remove-${item.id}'),
            tooltip: 'Remove from plan',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onRemove(item),
          ),
        ],
      ),
    );
  }
}

/// All prepared batches that still have portions (RCP-015).
class _PrepList extends ConsumerWidget {
  const _PrepList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(activePrepBatchesProvider).value ?? const [];
    if (batches.isEmpty) return const SizedBox.shrink();
    final names = {
      for (final r in ref.watch(recipesProvider).value ?? const <Recipe>[])
        r.id: r.name,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: RfSpace.s3),
        const RfSectionHeader(title: 'Prep'),
        RfCard(
          key: const Key('plan-prep'),
          child: Column(
            children: [
              for (final PrepBatch b in batches)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: RfSpace.s1),
                  child: Row(
                    key: Key('plan-prep-${b.id}'),
                    children: [
                      Expanded(
                        child: Text(
                          names[b.recipeId] ?? 'Deleted recipe',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        portionsLeftLabel(b.portionsRemaining),
                        style: context.rfText.dataS,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _perPortionText(Recipe r) {
  final kcal = r.perPortion?.kcal;
  return kcal == null
      ? 'no nutrition'
      : '${formatNumber(kcal, maxDecimals: 0)} kcal per portion';
}

class _RecipePicker extends ConsumerWidget {
  const _RecipePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: recipes.when(
          loading: () => const RfLoading(),
          error: (e, _) =>
              const RfErrorState(message: 'Could not load recipes.'),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(RfSpace.gutter),
                  child: RfEmptyState(
                    key: Key('pick-recipe-empty'),
                    message: 'No recipes yet.',
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in list)
                      ListTile(
                        key: Key('pick-recipe-${r.id}'),
                        title: Text(r.name),
                        subtitle: Text(_perPortionText(r)),
                        onTap: () => Navigator.of(context).pop(r),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SavedMealPicker extends ConsumerWidget {
  const _SavedMealPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(savedMealsProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: meals.when(
          loading: () => const RfLoading(),
          error: (e, _) =>
              const RfErrorState(message: 'Could not load saved meals.'),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(RfSpace.gutter),
                  child: RfEmptyState(
                    key: Key('pick-saved-empty'),
                    message: 'No saved meals yet.',
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in list)
                      ListTile(
                        key: Key('pick-saved-${m.id}'),
                        title: Text(m.name),
                        subtitle: Text(
                          '${formatNumber(m.totals.kcal, maxDecimals: 0)} kcal',
                        ),
                        onTap: () => Navigator.of(context).pop(m),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
