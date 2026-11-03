import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';

const _diacritics = {
  'àáâäãå': 'a',
  'èéêë': 'e',
  'ìíîï': 'i',
  'òóôöõ': 'o',
  'ùúûü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

final Map<String, String> _foldMap = {
  for (final e in _diacritics.entries)
    for (final ch in e.key.split('')) ch: e.value,
};

/// Lower-cases [input] and strips common Latin diacritics.
String normaliseSearchKey(String input) {
  final buf = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    buf.write(_foldMap[ch] ?? ch);
  }
  return buf.toString();
}

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
  double proteinG,
  double carbsG,
  double fatG,
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
  if (unit == null || provenance == null || source == null) return null;
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
  proteinG: f.profile.per100Amounts.proteinG,
  carbsG: f.profile.per100Amounts.carbsG,
  fatG: f.profile.per100Amounts.fatG,
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
      proteinG: e.nutrients.proteinG,
      carbsG: e.nutrients.carbsG,
      fatG: e.nutrients.fatG,
      fibreG: Value(e.nutrients.fibreG),
      provenance: e.provenance.name,
      loggedAt: e.loggedAt,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );

// ------------------------------------------------------------- recipes

Recipe? recipeFromRow(RecipeRow row, List<RecipeIngredientRow> ingredientRows) {
  List<String> steps;
  try {
    final decoded = jsonDecode(row.methodStepsJson);
    if (decoded is! List) return null;
    steps = [for (final s in decoded) s as String];
  } on Object {
    return null;
  }
  final sorted = [...ingredientRows]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final ingredients = <RecipeIngredient>[];
  // Lenient like the training mappers: a bad ingredient line is skipped, the
  // recipe itself is still returned.
  for (final r in sorted) {
    if (_ingredientFromRow(r) case final i?) ingredients.add(i);
  }
  final declared =
      row.declaredKcal == null ||
          row.declaredProteinG == null ||
          row.declaredCarbsG == null ||
          row.declaredFatG == null
      ? null
      : _amounts(
          row.declaredKcal!,
          row.declaredProteinG!,
          row.declaredCarbsG!,
          row.declaredFatG!,
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
    freezerFriendly: row.freezerFriendly,
    reheating: row.reheating,
    favourite: row.favourite,
    ingredients: ingredients,
    methodSteps: steps,
    declaredPerPortion: declared,
    nutritionNote: row.nutritionNote,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

RecipeIngredient? _ingredientFromRow(RecipeIngredientRow r) {
  final q = _quantity(r.amount, r.unit);
  if (q == null) return null;
  NutrientProfile? profile;
  if (r.provenance != null) {
    final prov = _prov(r.provenance);
    if (prov == null ||
        r.kcal == null ||
        r.proteinG == null ||
        r.carbsG == null ||
        r.fatG == null) {
      return null;
    }
    profile = NutrientProfile(
      // The per-100 reference unit of the snapshot equals the line's unit.
      per100: q.unit,
      per100Amounts: _amounts(
        r.kcal!,
        r.proteinG!,
        r.carbsG!,
        r.fatG!,
        r.fibreG,
      ),
      provenance: prov,
    );
  }
  return RecipeIngredient(
    id: r.id,
    name: r.name,
    foodId: r.foodId,
    quantity: q,
    sortOrder: r.sortOrder,
    note: r.note,
    per100: profile,
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
  freezerFriendly: Value(r.freezerFriendly),
  reheating: Value(r.reheating),
  favourite: Value(r.favourite),
  methodStepsJson: jsonEncode(r.methodSteps),
  declaredKcal: Value(r.declaredPerPortion?.kcal),
  declaredProteinG: Value(r.declaredPerPortion?.proteinG),
  declaredCarbsG: Value(r.declaredPerPortion?.carbsG),
  declaredFatG: Value(r.declaredPerPortion?.fatG),
  declaredFibreG: Value(r.declaredPerPortion?.fibreG),
  nutritionNote: Value(r.nutritionNote),
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
      );
    }(),
];
