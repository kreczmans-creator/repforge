import 'package:flutter/material.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/ui/tokens.dart';

/// The one-line statement of where a food record came from and when it
/// entered the local database (NUT-023, licence compliance).
///
/// No schema change backs this: the source name is [Food.source], the source
/// identifier is [Food.barcode] (for Open Food Facts the product code, which
/// the importer stores there and repeats in the id as `off:<code>`), and the
/// import date is [Food.createdAt], the moment the record was first stored
/// locally. The date is shown as the local calendar day, `YYYY-MM-DD`.
String foodSourceText(Food food) {
  final day = dayKey(food.createdAt.toLocal());
  switch (food.source) {
    case FoodSource.openFoodFacts:
      final code = food.barcode;
      final id = code == null || code.isEmpty ? '' : ' · $code';
      return 'Source: Open Food Facts$id · imported $day';
    case FoodSource.userCreated:
      return 'Your food · created $day';
    case FoodSource.seed:
      return 'Source: built-in food list · added $day';
  }
}

/// Small caption showing [foodSourceText] for [food].
class FoodSourceLine extends StatelessWidget {
  const FoodSourceLine(this.food, {super.key});

  final Food food;

  @override
  Widget build(BuildContext context) => Text(
    foodSourceText(food),
    key: const Key('food-source'),
    style: context.rfText.meta,
  );
}
