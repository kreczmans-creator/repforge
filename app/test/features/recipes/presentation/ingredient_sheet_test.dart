import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/recipes/presentation/ingredient_sheet.dart';
import 'package:repforge/ui/theme.dart';

import '../../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9);

Food _food(ReferenceUnit basis) => Food(
  id: 'f1',
  name: 'Thing',
  profile: NutrientProfile(
    per100: basis,
    per100Amounts: const NutrientAmounts(kcal: 100),
    provenance: DataProvenance.userEntered,
  ),
  source: FoodSource.userCreated,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  RecipeIngredient? result;

  Future<void> open(
    WidgetTester tester,
    Food? food, {
    RecipeIngredient? existing,
  }) async {
    result = null;
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: rfTheme(Brightness.dark),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showIngredientSheet(
                  context,
                  id: 'i1',
                  sortOrder: 0,
                  food: food,
                  existing: existing,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder segmentLabel(String t) => find.descendant(
    of: find.byKey(const Key('ingredient-entry-unit')),
    matching: find.text(t),
  );

  testWidgets('a per-100 g food offers g and kg only', (tester) async {
    await open(tester, _food(ReferenceUnit.grams));
    expect(segmentLabel('g'), findsOneWidget);
    expect(segmentLabel('kg'), findsOneWidget);
    expect(segmentLabel('ml'), findsNothing);
    expect(segmentLabel('l'), findsNothing);
    await unmount(tester);
  });

  testWidgets('0.5 l of a per-100 ml food is stored as 500 ml', (tester) async {
    await open(tester, _food(ReferenceUnit.millilitres));
    expect(segmentLabel('ml'), findsOneWidget);
    await tester.tap(segmentLabel('l'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('ingredient-amount')), '0.5');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('ingredient-canonical'))).data,
      '= 500 ml',
    );
    await tester.tap(find.byKey(const Key('ingredient-save')));
    await tester.pumpAndSettle();
    expect(
      result?.quantity,
      Quantity.fromStored(500, ReferenceUnit.millilitres),
    );
    await unmount(tester);
  });

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('ingredient-amount')),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  testWidgets('switching g to kg converts the text and back', (tester) async {
    await open(tester, _food(ReferenceUnit.grams));
    await tester.enterText(find.byKey(const Key('ingredient-amount')), '250');
    await tester.tap(segmentLabel('kg'));
    await tester.pump();
    expect(fieldText(tester), '0.25');
    expect(
      tester.widget<Text>(find.byKey(const Key('ingredient-canonical'))).data,
      '= 250 g',
    );
    await tester.tap(segmentLabel('g'));
    await tester.pump();
    expect(fieldText(tester), '250');
    expect(find.byKey(const Key('ingredient-canonical')), findsNothing);
    await unmount(tester);
  });

  testWidgets('editing an existing ingredient pre-fills canonical g and '
      'converts on switch', (tester) async {
    final food = _food(ReferenceUnit.grams);
    final existing = RecipeIngredient(
      id: 'i1',
      name: food.name,
      foodId: food.id,
      quantity: Quantity.fromStored(500, ReferenceUnit.grams),
      sortOrder: 0,
      per100: food.profile,
    );
    await open(tester, null, existing: existing);
    expect(fieldText(tester), '500');
    await tester.tap(segmentLabel('kg'));
    await tester.pump();
    expect(fieldText(tester), '0.5');
    await tester.tap(find.byKey(const Key('ingredient-save')));
    await tester.pumpAndSettle();
    expect(result?.quantity, Quantity.fromStored(500, ReferenceUnit.grams));
    await unmount(tester);
  });

  testWidgets('an over-range kg amount shows its validation message and '
      'switching clears it (R15-01, R15-02)', (tester) async {
    await open(tester, _food(ReferenceUnit.grams));
    await tester.tap(segmentLabel('kg'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('ingredient-amount')), '150');
    await tester.tap(find.byKey(const Key('ingredient-save')));
    await tester.pump();
    expect(find.text('Quantity is unrealistically large.'), findsOneWidget);
    expect(result, isNull);
    await tester.tap(segmentLabel('g'));
    await tester.pump();
    expect(fieldText(tester), isEmpty);
    expect(find.text('Quantity is unrealistically large.'), findsOneWidget);
    expect(find.byTooltip('kilograms'), findsOneWidget);
    await unmount(tester);
  });
}
