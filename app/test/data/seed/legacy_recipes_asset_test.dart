import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final file = File('assets/seed/legacy_recipes.json');
  late Map<String, dynamic> doc;
  late List<Map<String, dynamic>> recipes;

  setUpAll(() {
    doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    recipes = (doc['recipes'] as List).cast<Map<String, dynamic>>();
  });

  test('has format version and source', () {
    expect(doc['formatVersion'], 1);
    expect(doc['source'], isA<String>());
    expect(doc['source'] as String, contains('defaultStarterRecipes()'));
  });

  test('contains 22 recipes with unique starter- ids', () {
    expect(recipes, hasLength(22));
    final ids = recipes.map((r) => r['id'] as String).toList();
    expect(ids.toSet(), hasLength(22));
    for (final id in ids) {
      expect(id, startsWith('starter-'));
    }
  });

  test('every recipe is structurally valid', () {
    final numbered = RegExp(r'^\d+\. ');
    for (final r in recipes) {
      final id = r['id'];
      expect((r['name'] as String).trim(), isNotEmpty, reason: '$id name');
      expect(r['portions'] as int, greaterThanOrEqualTo(1), reason: '$id');
      final pp = r['perPortion'] as Map<String, dynamic>;
      for (final k in ['kcal', 'proteinG', 'carbsG', 'fatG']) {
        expect(pp[k], isA<num>(), reason: '$id $k present');
        expect(pp[k] as num, greaterThanOrEqualTo(0), reason: '$id $k');
      }
      expect(pp.containsKey('fibreG'), isFalse, reason: '$id: no fibre');
      final lines = (r['ingredientLines'] as List).cast<String>();
      expect(lines, isNotEmpty, reason: '$id ingredients');
      for (final l in lines) {
        expect(l.trim(), isNotEmpty);
      }
      final steps = (r['methodSteps'] as List).cast<String>();
      expect(steps, isNotEmpty, reason: '$id steps');
      for (final s in steps) {
        expect(s.trim(), isNotEmpty, reason: '$id step');
        expect(numbered.hasMatch(s), isFalse, reason: '$id step "$s"');
      }
      expect(r['legacyFreezerFriendly'], isA<bool>(), reason: id.toString());
      expect(r['nutritionNote'] as String, isNotEmpty, reason: '$id note');
    }
  });

  test('first recipe is Smoky Chicken Burrito Wrap with legacy values', () {
    final r = recipes.first;
    expect(r['name'], 'Smoky Chicken Burrito Wrap');
    expect(r['portions'], 8);
    final pp = r['perPortion'] as Map<String, dynamic>;
    expect(pp['kcal'], 460);
    expect(pp['proteinG'], 43);
    expect(pp['carbsG'], 48);
    expect(pp['fatG'], 11);
    expect(r['ingredientLines'] as List, hasLength(17));
    expect(r['methodSteps'] as List, hasLength(8));
  });
}
