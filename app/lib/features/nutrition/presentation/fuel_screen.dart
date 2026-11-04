import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/nutrition/presentation/entry_edit_sheet.dart';
import 'package:repforge/features/nutrition/presentation/nutrient_display.dart';
import 'package:repforge/features/nutrition/presentation/provenance_badge.dart';
import 'package:repforge/features/nutrition/presentation/saved_meals_screen.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_macro_bar.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_stat_tile.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Fuel tab: the food diary for one day with totals against targets.
class FuelScreen extends ConsumerWidget {
  const FuelScreen({super.key});

  static const List<MealSlot> meals = [
    MealSlot.breakfast,
    MealSlot.lunch,
    MealSlot.dinner,
    MealSlot.snack,
  ];

  static String mealLabel(MealSlot m) => switch (m) {
    MealSlot.breakfast => 'Breakfast',
    MealSlot.lunch => 'Lunch',
    MealSlot.dinner => 'Dinner',
    MealSlot.snack => 'Snacks',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final today = ref.watch(todayKeyProvider);
    final summary = ref.watch(selectedDaySummaryProvider);
    final entries = ref.watch(selectedDayEntriesProvider);
    final theme = Theme.of(context);
    final date = DateTime.parse(day);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
      children: [
        _DayNavigator(
          label: day == today ? 'Today' : DateFormat('EEE d MMM').format(date),
          isToday: day == today,
          onPrevious: () => ref.read(selectedDayProvider.notifier).shift(-1),
          onNext: day == today
              ? null
              : () => ref.read(selectedDayProvider.notifier).shift(1),
          onToday: () => ref.read(selectedDayProvider.notifier).today(),
          onWeek: () => context.push(RfRoutes.fuelWeek),
        ),
        summary.when(
          loading: () => const RfLoading(),
          error: (e, _) =>
              const RfErrorState(message: 'Could not load the diary.'),
          data: (s) => _Totals(summary: s),
        ),
        const SizedBox(height: RfSpace.s3),
        Row(
          children: [
            Expanded(
              child: RfButton(
                key: const Key('log-food'),
                label: 'Log food',
                icon: Icons.add,
                onPressed: () => context.push(RfRoutes.fuelSearch),
              ),
            ),
            const SizedBox(width: RfSpace.s2),
            RfButton(
              key: const Key('open-saved-meals'),
              label: 'Saved meals',
              variant: RfButtonVariant.secondary,
              expand: false,
              onPressed: () => context.push(RfRoutes.fuelSavedMeals),
            ),
          ],
        ),
        const SizedBox(height: RfSpace.s2),
        entries.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (list) => Column(
            children: [
              for (final meal in meals)
                _MealSection(
                  meal: meal,
                  entries: [
                    for (final e in list)
                      if (e.meal == meal) e,
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: RfSpace.s2),
        Text(
          'Values are recorded when you log; editing a food later does not '
          'change past entries.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: RfSpace.s8),
      ],
    );
  }
}

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({
    required this.label,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onWeek,
  });

  final String label;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onToday;
  final VoidCallback onWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RfSpace.s2),
      child: Row(
        children: [
          IconButton(
            key: const Key('day-previous'),
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              label,
              key: const Key('day-label'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          IconButton(
            key: const Key('day-next'),
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
          if (!isToday)
            TextButton(
              key: const Key('day-today'),
              onPressed: onToday,
              child: const Text('Today'),
            ),
          IconButton(
            key: const Key('open-week'),
            tooltip: 'Weekly summary',
            icon: const Icon(Icons.calendar_view_week_outlined),
            onPressed: onWeek,
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final t = s.targets;
    final remaining = s.kcalRemaining;
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: RfStatTile(
                  key: const Key('fuel-kcal'),
                  label: remaining == null ? 'Calories' : 'Calories left',
                  value: formatNumber(
                    remaining ?? s.intake.kcal,
                    maxDecimals: 0,
                  ),
                  unit: 'kcal',
                  progress: t.kcal == null || t.kcal == 0
                      ? null
                      : s.intake.kcal / t.kcal!,
                  caption: t.kcal == null
                      ? 'No target set'
                      : '${formatNumber(s.intake.kcal, maxDecimals: 0)} of '
                            '${formatNumber(t.kcal!, maxDecimals: 0)}',
                ),
              ),
              const SizedBox(width: RfSpace.s3),
              Expanded(
                child: RfStatTile(
                  label: 'Entries',
                  value: '${s.entryCount}',
                  caption: s.entryCount == 1 ? 'item logged' : 'items logged',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RfSpace.s3),
        RfCard(
          child: Column(
            children: [
              RfMacroBar(
                label: 'Protein',
                amount: s.intake.proteinG,
                target: t.proteinG,
                unknownCount: s.totals.unknownCount(Nutrient.proteinG),
              ),
              RfMacroBar(
                label: 'Carbs',
                amount: s.intake.carbsG,
                target: t.carbsG,
                unknownCount: s.totals.unknownCount(Nutrient.carbsG),
                color: context.rf.textSecondary,
              ),
              RfMacroBar(
                label: 'Fat',
                amount: s.intake.fatG,
                target: t.fatG,
                unknownCount: s.totals.unknownCount(Nutrient.fatG),
                color: context.rf.textSecondary,
              ),
              RfMacroBar(
                label: 'Fibre',
                amount: s.intake.fibreG,
                target: t.fibreG,
                unknownCount: s.totals.unknownCount(Nutrient.fibreG),
                color: context.rf.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MealSection extends ConsumerWidget {
  const _MealSection({required this.meal, required this.entries});

  final MealSlot meal;
  final List<FoodLogEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kcal = NutrientAmounts.sum(entries.map((e) => e.nutrients)).kcal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RfSectionHeader(
          title: entries.isEmpty
              ? FuelScreen.mealLabel(meal)
              : '${FuelScreen.mealLabel(meal)} · '
                    '${formatNumber(kcal, maxDecimals: 0)} kcal',
          actionLabel: entries.isEmpty ? null : 'Save as meal',
          onAction: entries.isEmpty
              ? null
              : () => showSaveMealDialog(
                  context,
                  ref,
                  entries: entries,
                  slot: meal,
                ),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: RfSpace.s2),
            child: Text('Nothing logged.', style: theme.textTheme.bodySmall),
          )
        else
          RfCard(
            padding: const EdgeInsets.symmetric(
              horizontal: RfSpace.s4,
              vertical: RfSpace.s1,
            ),
            child: Column(
              children: [
                for (final e in entries)
                  ListTile(
                    key: Key('entry-${e.id}'),
                    contentPadding: EdgeInsets.zero,
                    onTap: () => showEntryEditSheet(context, e),
                    title: Text(
                      e.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${e.quantity.label} · '
                            'P ${numberOrNa(e.nutrients.proteinG)} · '
                            'C ${numberOrNa(e.nutrients.carbsG)} · '
                            'F ${numberOrNa(e.nutrients.fatG)}',
                            style: context.rfText.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: RfSpace.s2),
                        ProvenanceBadge(e.provenance),
                      ],
                    ),
                    trailing: Text(
                      formatNumber(e.nutrients.kcal, maxDecimals: 0),
                      style: context.rfText.dataS,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Deletes an entry and reports the outcome in a snackbar.
Future<void> deleteEntry(BuildContext context, WidgetRef ref, String id) async {
  final result = await ref.read(deleteFoodLogEntryProvider)(id);
  if (!context.mounted) return;
  if (result case Err(:final error)) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
  }
}
