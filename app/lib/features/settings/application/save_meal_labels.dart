import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/settings/meal_labels.dart';
import 'package:repforge/domain/settings/settings.dart';

/// Use case: rename and reorder the meal slots (NUT-011). Entries store the
/// slot key, so the new names apply to existing and new entries alike.
final class SaveMealLabels {
  const SaveMealLabels({required this.repository});

  final SettingsRepository repository;

  /// Validates ([MealLabels.create]) and saves.
  Future<Result<MealLabels>> call({
    required Map<MealSlot, String> labels,
    required List<MealSlot> order,
  }) async {
    final built = MealLabels.create(labels: labels, order: order);
    if (built case Err(:final error)) return Err(error);
    final value = (built as Ok<MealLabels>).value;
    try {
      await repository.saveMealLabels(value);
    } on Exception catch (e) {
      return Err(StorageError('Could not save the meal names.', cause: e));
    }
    return Ok(value);
  }
}
