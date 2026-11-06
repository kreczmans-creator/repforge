import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/external/open_food_facts_mapper.dart';

final _now = DateTime.utc(2026, 11, 3, 12);

void main() {
  group('mapOffProduct unknown macros', () {
    test('an energy-only product maps with null macros, not zero', () {
      final f = mapOffProduct({
        'code': '1',
        'product_name': 'A',
        'nutriments': {'energy-kcal_100g': 10},
      }, now: _now)!;
      expect(f.profile.per100Amounts.kcal, 10);
      expect(f.profile.per100Amounts.proteinG, isNull);
      expect(f.profile.per100Amounts.carbsG, isNull);
      expect(f.profile.per100Amounts.fatG, isNull);
      expect(f.profile.per100Amounts.fibreG, isNull);
    });

    test('an explicit zero stays zero while absent macros stay null', () {
      final f = mapOffProduct({
        'code': '1',
        'product_name': 'A',
        'nutriments': {'energy-kcal_100g': 10, 'proteins_100g': 0},
      }, now: _now)!;
      expect(f.profile.per100Amounts.proteinG, 0);
      expect(f.profile.per100Amounts.carbsG, isNull);
    });

    test('a product without energy is still unusable', () {
      expect(
        mapOffProduct({
          'code': '1',
          'product_name': 'A',
          'nutriments': {'proteins_100g': 5},
        }, now: _now),
        isNull,
      );
    });
  });
}
