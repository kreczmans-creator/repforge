import 'package:flutter/material.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/nutrition/presentation/nutrient_display.dart';
import 'package:repforge/ui/tokens.dart';

/// "45 min", "1 h 30 min", "2 h".
String minutesLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Freezing line (RCP-005). Unknown never implies safety: "not stated".
String freezingLabel(FreezingSuitability f) => switch (f) {
  FreezingSuitability.yes => 'Freezing: suitable for freezing',
  FreezingSuitability.no => 'Freezing: not suitable for freezing',
  FreezingSuitability.unknown => 'Freezing: not stated',
};

/// "200 g" or, for an ingredient entered by serving, "2 x slice (70 g)".
String ingredientQuantityLabel(RecipeIngredient i) {
  final label = i.servingLabel;
  final count = i.servingCount;
  if (label != null && count != null) {
    return '${formatNumber(count, maxDecimals: 2)} x $label '
        '(${i.quantity.label})';
  }
  return i.quantity.label;
}

/// Display text of one per-portion value (RCP-007(2)): a complete value is a
/// number, a partial sum carries the word "incomplete", and a nutrient no
/// ingredient states is "n/a". Never a partial sum presented as complete.
String portionValueText(
  double? known,
  int unknownCount, {
  String unit = 'g',
  int maxDecimals = 1,
}) {
  if (known == null) return unknownShort;
  final v = '${formatNumber(known, maxDecimals: maxDecimals)} $unit';
  return unknownCount > 0 ? '$v (incomplete)' : v;
}

/// The five per-portion measures of a recipe, with semantics from
/// `perPortionTotals`.
class RecipeNutritionPanel extends StatelessWidget {
  const RecipeNutritionPanel({required this.recipe, super.key});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final totals = recipe.perPortionTotals;
    if (totals == null) {
      return Text(
        'No nutrition for this recipe.',
        key: const Key('nutrition-none'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final k = totals.known;
    Widget row(String key, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: RfSpace.s1),
      child: Row(
        key: Key(key),
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.rfText.dataS,
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        row(
          'nutrition-kcal',
          'Energy',
          '${formatNumber(k.kcal, maxDecimals: 0)} kcal',
        ),
        row(
          'nutrition-protein',
          'Protein',
          portionValueText(k.proteinG, totals.unknownProteinCount),
        ),
        row(
          'nutrition-carbs',
          'Carbohydrate',
          portionValueText(k.carbsG, totals.unknownCarbsCount),
        ),
        row(
          'nutrition-fat',
          'Fat',
          portionValueText(k.fatG, totals.unknownFatCount),
        ),
        row(
          'nutrition-fibre',
          'Fibre',
          portionValueText(k.fibreG, totals.unknownFibreCount),
        ),
      ],
    );
  }
}
