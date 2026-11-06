import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/group_by.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/core/search_key.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';

export 'package:repforge/domain/core/search_key.dart' show normaliseSearchKey;

/// Search key stored on a food: name and brand, normalised.
String foodSearchKey(String name, String? brand) =>
    normaliseSearchKey(brand == null ? name : '$name $brand');

ReferenceUnit? _unit(String s) => ReferenceUnit.values.asNameMap()[s];

DataProvenance? _prov(String? s) => DataProvenance.values.asNameMap()[s];

Quantity? _quantity(double amount, String unit) {
  final u = _unit(unit);
  if (u == null) return null;
  return switch (Quantity.of(amount, u)) {
    Ok(:final value) => value,
    Err() => null,
  };
}

NutrientAmounts _amounts(
  double kcal,
  double? proteinG,
  double? carbsG,
  double? fatG,
  double? fibreG,
) => NutrientAmounts(
  kcal: kcal,
  proteinG: proteinG,
  carbsG: carbsG,
  fatG: fatG,
  fibreG: fibreG,
);

// ---------------------------------------------------------------- foods

/// Maps a food row and its servings; null when the row is invalid.
Food? foodFromRow(FoodRow row, List<FoodServingRow> servingRows) {
  final unit = _unit(row.per100Unit);
  final provenance = _prov(row.provenance);
  final source = FoodSource.values.asNameMap()[row.source];
  if (unit == null || !unit.isMeasure || provenance == null || source == null) {
    return null;
  }
  final amounts = switch (validateNutrientsPer100(
    kcal: row.kcal,
    proteinG: row.proteinG,
    carbsG: row.carbsG,
    fatG: row.fatG,
    fibreG: row.fibreG,
  )) {
    Ok(:final value) => value,
    Err() => null,
  };
  if (amounts == null) return null;
  final sorted = [...servingRows]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final servings = <ServingSize>[
    for (final s in sorted)
      if (_quantity(s.amount, s.unit) case final q?)
        ServingSize(label: s.label, quantity: q),
  ];
  return Food(
    id: row.id,
    name: row.name,
    brand: row.brand,
    barcode: row.barcode,
    profile: NutrientProfile(
      per100: unit,
      per100Amounts: amounts,
      provenance: provenance,
    ),
    source: source,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    servings: servings,
  );
}

FoodsCompanion foodToRow(Food f) => FoodsCompanion.insert(
  id: f.id,
  name: f.name,
  brand: Value(f.brand),
  barcode: Value(f.barcode),
  per100Unit: f.profile.per100.name,
  kcal: f.profile.per100Amounts.kcal,
  proteinG: Value(f.profile.per100Amounts.proteinG),
  carbsG: Value(f.profile.per100Amounts.carbsG),
  fatG: Value(f.profile.per100Amounts.fatG),
  fibreG: Value(f.profile.per100Amounts.fibreG),
  provenance: f.profile.provenance.name,
  source: f.source.name,
  searchKey: foodSearchKey(f.name, f.brand),
  createdAt: f.createdAt,
  updatedAt: f.updatedAt,
);

List<FoodServingsCompanion> servingRows(Food f) => [
  for (var i = 0; i < f.servings.length; i++)
    FoodServingsCompanion.insert(
      id: '${f.id}:$i',
      foodId: f.id,
      label: f.servings[i].label,
      amount: f.servings[i].quantity.amount,
      unit: f.servings[i].quantity.unit.name,
      sortOrder: i,
    ),
];

// ------------------------------------------------------------ food log

FoodLogEntry? logEntryFromRow(FoodLogEntryRow row) {
  final meal = MealSlot.values.asNameMap()[row.meal];
  final provenance = _prov(row.provenance);
  final quantity = _quantity(row.amount, row.unit);
  if (meal == null || provenance == null || quantity == null) return null;
  return FoodLogEntry(
    id: row.id,
    day: row.day,
    meal: meal,
    name: row.name,
    foodId: row.foodId,
    recipeId: row.recipeId,
    quantity: quantity,
    nutrients: _amounts(
      row.kcal,
      row.proteinG,
      row.carbsG,
      row.fatG,
      row.fibreG,
    ),
    provenance: provenance,
    loggedAt: row.loggedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

FoodLogEntriesCompanion logEntryToRow(FoodLogEntry e) =>
    FoodLogEntriesCompanion.insert(
      id: e.id,
      day: e.day,
      meal: e.meal.name,
      name: e.name,
      foodId: Value(e.foodId),
      recipeId: Value(e.recipeId),
      amount: e.quantity.amount,
      unit: e.quantity.unit.name,
      kcal: e.nutrients.kcal,
      proteinG: Value(e.nutrients.proteinG),
      carbsG: Value(e.nutrients.carbsG),
      fatG: Value(e.nutrients.fatG),
      fibreG: Value(e.nutrients.fibreG),
      provenance: e.provenance.name,
      loggedAt: e.loggedAt,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );

// ------------------------------------------------------------- recipes

List<String>? _stringList(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return null;
    return [for (final s in decoded) s as String];
  } on Object {
    return null;
  }
}

/// Maps a recipe row with its ingredient and substitute rows; null when the
/// row is invalid (corrupt JSON in a list column).
Recipe? recipeFromRow(
  RecipeRow row,
  List<RecipeIngredientRow> ingredientRows, [
  List<RecipeSubstituteRow> substituteRows = const [],
]) {
  final prepSteps = _stringList(row.prepStepsJson);
  final cookSteps = _stringList(row.cookStepsJson);
  final notes = _stringList(row.ingredientNotesJson);
  if (prepSteps == null || cookSteps == null || notes == null) return null;
  final subsByIngredient = groupByParent<RecipeSubstituteRow>(
    substituteRows,
    (s) => s.recipeIngredientId,
  );
  final sorted = [...ingredientRows]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final ingredients = <RecipeIngredient>[];
  // Lenient like the training mappers: a bad ingredient line is skipped, the
  // recipe itself is still returned.
  for (final r in sorted) {
    final i = _ingredientFromRow(r, subsByIngredient[r.id] ?? const []);
    if (i != null) ingredients.add(i);
  }
  final declared = row.declaredKcal == null
      ? null
      : _amounts(
          row.declaredKcal!,
          row.declaredProteinG,
          row.declaredCarbsG,
          row.declaredFatG,
          row.declaredFibreG,
        );
  return Recipe(
    id: row.id,
    name: row.name,
    category: row.category,
    description: row.description,
    portions: row.portions,
    prepMinutes: row.prepMinutes,
    cookMinutes: row.cookMinutes,
    storage: row.storage,
    freezing:
        FreezingSuitability.values.asNameMap()[row.freezing] ??
        FreezingSuitability.unknown,
    reheating: row.reheating,
    favourite: row.favourite,
    ingredients: ingredients,
    prepSteps: prepSteps,
    cookSteps: cookSteps,
    totalWeightG: row.totalWeightG,
    portionWeightG: row.portionWeightG,
    declaredPerPortion: declared,
    nutritionNote: row.nutritionNote,
    ingredientNotes: notes,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

RecipeIngredient? _ingredientFromRow(
  RecipeIngredientRow r,
  List<RecipeSubstituteRow> substituteRows,
) {
  final q = _quantity(r.amount, r.unit);
  if (q == null) return null;
  NutrientProfile? profile;
  if (r.provenance != null) {
    final prov = _prov(r.provenance);
    if (prov == null || r.kcal == null) return null;
    profile = NutrientProfile(
      // The per-100 reference unit of the snapshot equals the line's unit.
      per100: q.unit,
      per100Amounts: _amounts(r.kcal!, r.proteinG, r.carbsG, r.fatG, r.fibreG),
      provenance: prov,
    );
  }
  final subs = [...substituteRows]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return RecipeIngredient(
    id: r.id,
    name: r.name,
    foodId: r.foodId,
    quantity: q,
    sortOrder: r.sortOrder,
    note: r.note,
    per100: profile,
    servingLabel: r.servingLabel,
    servingCount: r.servingCount,
    substitutes: [for (final s in subs) ?_substituteFromRow(s)],
  );
}

RecipeSubstitute? _substituteFromRow(RecipeSubstituteRow r) {
  final q = _quantity(r.amount, r.unit);
  final prov = _prov(r.provenance);
  if (q == null || prov == null) return null;
  return RecipeSubstitute(
    name: r.name,
    foodId: r.foodId,
    quantity: q,
    per100: NutrientProfile(
      per100: q.unit,
      per100Amounts: _amounts(r.kcal, r.proteinG, r.carbsG, r.fatG, r.fibreG),
      provenance: prov,
    ),
  );
}

RecipesCompanion recipeToRow(Recipe r) => RecipesCompanion.insert(
  id: r.id,
  name: r.name,
  category: r.category,
  description: Value(r.description),
  portions: r.portions,
  prepMinutes: Value(r.prepMinutes),
  cookMinutes: Value(r.cookMinutes),
  storage: Value(r.storage),
  freezing: Value(r.freezing.name),
  reheating: Value(r.reheating),
  favourite: Value(r.favourite),
  prepStepsJson: Value(jsonEncode(r.prepSteps)),
  cookStepsJson: Value(jsonEncode(r.cookSteps)),
  totalWeightG: Value(r.totalWeightG),
  portionWeightG: Value(r.portionWeightG),
  declaredKcal: Value(r.declaredPerPortion?.kcal),
  declaredProteinG: Value(r.declaredPerPortion?.proteinG),
  declaredCarbsG: Value(r.declaredPerPortion?.carbsG),
  declaredFatG: Value(r.declaredPerPortion?.fatG),
  declaredFibreG: Value(r.declaredPerPortion?.fibreG),
  nutritionNote: Value(r.nutritionNote),
  ingredientNotesJson: Value(jsonEncode(r.ingredientNotes)),
  createdAt: r.createdAt,
  updatedAt: r.updatedAt,
);

/// The per-100 snapshot is stored only when its reference unit equals the
/// line's unit; otherwise the line is not calculable and is saved without one
/// (the column set cannot express a different basis).
List<RecipeIngredientsCompanion> ingredientRows(Recipe r) => [
  for (final i in r.ingredients)
    () {
      final p = i.per100?.per100 == i.quantity.unit ? i.per100 : null;
      return RecipeIngredientsCompanion.insert(
        id: i.id,
        recipeId: r.id,
        name: i.name,
        foodId: Value(i.foodId),
        amount: i.quantity.amount,
        unit: i.quantity.unit.name,
        sortOrder: i.sortOrder,
        note: Value(i.note),
        kcal: Value(p?.per100Amounts.kcal),
        proteinG: Value(p?.per100Amounts.proteinG),
        carbsG: Value(p?.per100Amounts.carbsG),
        fatG: Value(p?.per100Amounts.fatG),
        fibreG: Value(p?.per100Amounts.fibreG),
        provenance: Value(p?.provenance.name),
        servingLabel: Value(i.servingLabel),
        servingCount: Value(i.servingCount),
      );
    }(),
];

/// Substitute rows of every ingredient of [r], in order. Ids are derived
/// from the ingredient id and position, like food servings.
List<RecipeSubstitutesCompanion> substituteRows(Recipe r) => [
  for (final i in r.ingredients)
    for (var n = 0; n < i.substitutes.length; n++)
      RecipeSubstitutesCompanion.insert(
        id: '${i.id}:sub:$n',
        recipeIngredientId: i.id,
        sortOrder: n,
        name: i.substitutes[n].name,
        foodId: Value(i.substitutes[n].foodId),
        amount: i.substitutes[n].quantity.amount,
        unit: i.substitutes[n].quantity.unit.name,
        kcal: i.substitutes[n].per100.per100Amounts.kcal,
        proteinG: Value(i.substitutes[n].per100.per100Amounts.proteinG),
        carbsG: Value(i.substitutes[n].per100.per100Amounts.carbsG),
        fatG: Value(i.substitutes[n].per100.per100Amounts.fatG),
        fibreG: Value(i.substitutes[n].per100.per100Amounts.fibreG),
        provenance: i.substitutes[n].per100.provenance.name,
      ),
];
