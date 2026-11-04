import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';

/// One serving as typed by the user.
typedef ServingInput = ({String label, String amount});

/// Use case: create or edit a user food (NUT-006, NUT-007).
final class CreateCustomFood {
  const CreateCustomFood({
    required this.foods,
    required this.clock,
    required this.newId,
  });

  final FoodRepository foods;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<Food>> call({
    required String name,
    required ReferenceUnit per100,
    required String kcal,
    required String proteinG,
    required String carbsG,
    required String fatG,
    String? fibreG,
    String? brand,
    String? barcode,
    List<ServingInput> servings = const [],
    Food? existing,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(ValidationError('Enter a food name.', field: 'name'));
    }
    double? num(String? s, String field) => (s == null || s.trim().isEmpty)
        ? null
        : double.tryParse(s.trim().replaceAll(',', '.'));
    final energy = num(kcal, 'kcal');
    if (energy == null) {
      return const Err(ValidationError('Enter a number.', field: 'kcal'));
    }
    // Blank protein/carbs/fat/fibre means "unknown" (null), never zero;
    // text that is not a number is still an error for that field.
    final optional = <String, double?>{};
    for (final (field, text) in [
      ('proteinG', proteinG),
      ('carbsG', carbsG),
      ('fatG', fatG),
      ('fibreG', fibreG),
    ]) {
      if (text == null || text.trim().isEmpty) {
        optional[field] = null;
        continue;
      }
      final v = num(text, field);
      if (v == null) {
        return Err(ValidationError('Enter a number.', field: field));
      }
      optional[field] = v;
    }
    final amounts = validateNutrientsPer100(
      kcal: energy,
      proteinG: optional['proteinG'],
      carbsG: optional['carbsG'],
      fatG: optional['fatG'],
      fibreG: optional['fibreG'],
    );
    if (amounts case Err(:final error)) return Err(error);

    final servingList = <ServingSize>[];
    for (final s in servings) {
      if (s.label.trim().isEmpty && s.amount.trim().isEmpty) continue;
      final a = num(s.amount, 'serving');
      if (s.label.trim().isEmpty || a == null || a <= 0) {
        return const Err(
          ValidationError(
            'Each serving needs a name and an amount above zero.',
            field: 'servings',
          ),
        );
      }
      final q = Quantity.of(a, per100);
      if (q case Err(:final error)) return Err(error);
      servingList.add(
        ServingSize(label: s.label.trim(), quantity: (q as Ok<Quantity>).value),
      );
    }

    final now = clock.now().toUtc();
    final food = Food(
      id: existing?.id ?? newId(),
      name: trimmed,
      brand: (brand == null || brand.trim().isEmpty) ? null : brand.trim(),
      barcode: (barcode == null || barcode.trim().isEmpty)
          ? null
          : barcode.trim(),
      profile: NutrientProfile(
        per100: per100,
        per100Amounts: (amounts as Ok<NutrientAmounts>).value,
        provenance: DataProvenance.userEntered,
      ),
      servings: servingList,
      source: FoodSource.userCreated,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await foods.upsert(food);
    } on Exception catch (e) {
      return Err(StorageError('Could not save the food.', cause: e));
    }
    return Ok(food);
  }
}
