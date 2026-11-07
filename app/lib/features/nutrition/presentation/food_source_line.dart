import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
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
///
/// [stored] is whether the record exists in the local database. An online
/// search hit that was never saved has only the time it was mapped, which is
/// not an import date, so it reads "not saved yet" instead. [stored] is null
/// while that is still being looked up.
String foodSourceText(Food food, {bool? stored = true}) {
  final day = dayKey(food.createdAt.toLocal());
  switch (food.source) {
    case FoodSource.openFoodFacts:
      final code = food.barcode;
      final id = code == null || code.isEmpty ? '' : ' · $code';
      if (stored == null) return 'Source: Open Food Facts$id';
      if (!stored) return 'Source: Open Food Facts$id · not saved yet';
      return 'Source: Open Food Facts$id · imported $day';
    case FoodSource.userCreated:
      return 'Your food · created $day';
    case FoodSource.seed:
      return 'Source: built-in food list · added $day';
  }
}

/// Whether a food id exists in the local database (looked up on each open).
// ignore: specify_nonobvious_property_types
final foodStoredProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, id) async => await ref.read(foodRepositoryProvider).byId(id) != null,
);

/// Small caption showing [foodSourceText] for [food].
class FoodSourceLine extends ConsumerWidget {
  const FoodSourceLine(this.food, {super.key});

  final Food food;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = food.source == FoodSource.openFoodFacts
        ? ref.watch(foodStoredProvider(food.id)).value
        : true as bool?;
    return Text(
      foodSourceText(food, stored: stored),
      key: const Key('food-source'),
      style: context.rfText.meta,
      softWrap: true,
    );
  }
}
