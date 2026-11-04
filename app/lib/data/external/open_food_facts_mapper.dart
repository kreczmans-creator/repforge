import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';

/// Maps one Open Food Facts product or search hit to a [Food], or returns
/// null when the entry is unusable (no name, no energy, or implausible).
Food? mapOffProduct(Map<String, dynamic> json, {required DateTime now}) {
  final code = _string(json['code']);
  final name = _string(json['product_name']);
  if (code == null || name == null) return null;

  final nutriments = json['nutriments'];
  if (nutriments is! Map) return null;
  // Prefer kcal; fall back to kJ (many entries carry energy only in kJ).
  final kcal =
      _number(nutriments['energy-kcal_100g']) ??
      switch (_number(nutriments['energy-kj_100g']) ??
          (_string(nutriments['energy_unit']) == 'kJ'
              ? _number(nutriments['energy_100g'])
              : null)) {
        final kj? => kj / 4.184,
        null => null,
      };
  if (kcal == null) return null;

  final unit = _string(json['nutrition_data_per']) == '100ml'
      ? ReferenceUnit.millilitres
      : ReferenceUnit.grams;

  final validated = validateNutrientsPer100(
    kcal: kcal,
    proteinG: _number(nutriments['proteins_100g']),
    carbsG: _number(nutriments['carbohydrates_100g']),
    fatG: _number(nutriments['fat_100g']),
    fibreG: _number(nutriments['fiber_100g']),
  );
  final NutrientAmounts amounts;
  switch (validated) {
    case Ok(:final value):
      amounts = value;
    case Err():
      return null;
  }

  final servings = <ServingSize>[];
  final servingQty = _number(json['serving_quantity']);
  if (servingQty != null && servingQty > 0) {
    if (Quantity.of(servingQty, unit) case Ok(:final value)) {
      servings.add(
        ServingSize(
          label: _string(json['serving_size']) ?? '1 serving',
          quantity: value,
        ),
      );
    }
  }

  return Food(
    id: 'off:$code',
    name: name,
    brand: mapOffBrands(json['brands']),
    barcode: code,
    profile: NutrientProfile(
      per100: unit,
      per100Amounts: amounts,
      provenance: DataProvenance.crowdsourced,
    ),
    source: FoodSource.openFoodFacts,
    createdAt: now,
    updatedAt: now,
    servings: servings,
  );
}

/// Brands arrive as a list (search) or a string (product endpoint).
String? mapOffBrands(Object? brands) {
  if (brands is List) {
    final parts = brands
        .map(_string)
        .whereType<String>()
        .toList(growable: false);
    return parts.isEmpty ? null : parts.join(', ');
  }
  return _string(brands);
}

/// Maps a search response body; skips unusable hits.
List<Food> mapOffSearchResponse(
  Map<String, dynamic> body, {
  required DateTime now,
}) {
  final hits = body['hits'];
  if (hits is! List) return const [];
  return [
    for (final hit in hits)
      if (hit is Map<String, dynamic>) ?mapOffProduct(hit, now: now),
  ];
}

/// Maps a product-by-barcode response body; null when status is not 1 or the
/// product is unusable.
Food? mapOffProductResponse(
  Map<String, dynamic> body, {
  required DateTime now,
}) {
  if (body['status'] != 1) return null;
  final product = body['product'];
  if (product is! Map<String, dynamic>) return null;
  return mapOffProduct({'code': body['code'], ...product}, now: now);
}

String? _string(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

double? _number(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}
