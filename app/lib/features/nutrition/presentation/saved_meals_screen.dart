import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/nutrition/presentation/nutrient_display.dart';
import 'package:repforge/features/nutrition/presentation/portion_sheet.dart';
import 'package:repforge/features/settings/application/meal_label_providers.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Saved meals (NUT-013): log a saved set of items in one tap, or delete.
class SavedMealsScreen extends ConsumerWidget {
  const SavedMealsScreen({super.key});

  Future<void> _log(BuildContext context, WidgetRef ref, SavedMeal m) async {
    final now = ref.read(clockProvider).now().toLocal();
    final slot = m.defaultMeal ?? defaultMealFor(now);
    final result = await ref.read(logSavedMealProvider)(
      meal: m,
      slot: slot,
      day: ref.read(selectedDayProvider),
    );
    if (!context.mounted) return;
    switch (result) {
      case Ok(:final value):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged ${value.length} item(s) to '
              '${ref.read(mealLabelsValueProvider).labelOf(slot)}',
            ),
          ),
        );
        final nav = Navigator.of(context);
        if (nav.canPop()) nav.pop();
      case Err(:final error):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
    final result = await ref.read(deleteSavedMealProvider)(id);
    if (!context.mounted) return;
    if (result case Err(:final error)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(savedMealsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved meals')),
      body: meals.when(
        loading: () => const RfLoading(),
        error: (e, _) =>
            const RfErrorState(message: 'Could not load saved meals.'),
        data: (list) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
          children: [
            const RfScreenTitle(
              title: 'Saved meals',
              caption: 'Re-log a set of items in one tap',
            ),
            if (list.isEmpty)
              const RfEmptyState(
                key: Key('saved-meals-empty'),
                icon: Icons.bookmark_outline,
                message:
                    'No saved meals yet. On the diary, use "Save as meal" '
                    'under a meal that has items.',
              )
            else
              for (final m in list) ...[
                RfCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            key: Key('delete-meal-${m.id}'),
                            tooltip: 'Delete saved meal',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, ref, m.id),
                          ),
                        ],
                      ),
                      Text(
                        '${m.items.length} item(s) · '
                        '${whole(m.totals.kcal)} kcal · '
                        'P ${gramsOrNa(m.totals.proteinG)}'
                        '${_unknownProtein(m)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: RfSpace.s2),
                      Text(
                        m.items.map((i) => i.name).join(', '),
                        style: context.rfText.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: RfSpace.s3),
                      RfButton(
                        key: Key('log-meal-${m.id}'),
                        label: 'Log this meal',
                        icon: Icons.add,
                        onPressed: () => _log(context, ref, m),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RfSpace.s3),
              ],
            const SizedBox(height: RfSpace.s8),
          ],
        ),
      ),
    );
  }
}

/// Dialog to name and save the given entries as a meal.
Future<void> showSaveMealDialog(
  BuildContext context,
  WidgetRef ref, {
  required List<FoodLogEntry> entries,
  required MealSlot slot,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _NameDialog(),
  );
  if (name == null || !context.mounted) return;
  final result = await ref.read(saveMealFromEntriesProvider)(
    name: name,
    entries: entries,
    defaultMeal: slot,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(switch (result) {
        Ok(:final value) => 'Saved "${value.name}"',
        Err(:final error) => userMessageFor(error),
      }),
    ),
  );
}

/// Owns its controller so it is disposed with the dialog, after the exit
/// transition, not when the future resolves.
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save as meal'),
    content: RfTextField(
      key: const Key('save-meal-name'),
      controller: _controller,
      label: 'Meal name',
      autofocus: true,
      onSubmitted: (v) => Navigator.of(context).pop(v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('save-meal-confirm'),
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

/// " · 1 unknown" when some items lack protein but others state it.
String _unknownProtein(SavedMeal m) => m.totals.proteinG == null
    ? ''
    : unknownMarker(m.nutrientTotals.unknownCount(Nutrient.proteinG));
