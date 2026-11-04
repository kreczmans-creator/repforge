import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/settings/meal_labels.dart';

/// The user's meal names and order as a plain value (NUT-011): the saved
/// labels once loaded, [MealLabels.defaults] while loading. Presentation
/// reads this instead of hard-coding meal names or order.
final mealLabelsValueProvider = Provider<MealLabels>(
  (ref) => ref.watch(mealLabelsProvider).value ?? MealLabels.defaults,
);
