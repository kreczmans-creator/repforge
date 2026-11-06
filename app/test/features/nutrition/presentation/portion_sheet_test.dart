import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/presentation/portion_sheet.dart';
import 'package:repforge/ui/theme.dart';

import '../../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9);

Food _food(
  NutrientAmounts per100, {
  ReferenceUnit basis = ReferenceUnit.grams,
}) => Food(
  id: 'f1',
  name: 'Thing',
  profile: NutrientProfile(
    per100: basis,
    per100Amounts: per100,
    provenance: DataProvenance.userEntered,
  ),
  source: FoodSource.userCreated,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  FoodLogEntry? logged;

  Future<void> open(WidgetTester tester, Food food) async {
    logged = null;
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(_now)),
        ],
        child: MaterialApp(
          theme: rfTheme(Brightness.dark),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  logged = await showPortionSheet(context, food);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('preview shows n/a for unknown values and 0 g for known zero', (
    tester,
  ) async {
    await open(
      tester,
      _food(const NutrientAmounts(kcal: 100, proteinG: 0, fatG: 5)),
    );
    final preview = find.byKey(const Key('portion-preview'));
    Finder inPreview(String t) =>
        find.descendant(of: preview, matching: find.text(t));
    expect(inPreview('0 g'), findsOneWidget); // protein, known zero
    expect(inPreview('5 g'), findsOneWidget); // fat
    expect(inPreview('n/a'), findsNWidgets(2)); // carbs and fibre
    await unmount(tester);
  });

  const per100 = NutrientAmounts(kcal: 200, proteinG: 10, fatG: 4);

  Finder segmentLabel(String t) => find.descendant(
    of: find.byKey(const Key('portion-entry-unit')),
    matching: find.text(t),
  );

  testWidgets('entry units follow the food basis and never cross it', (
    tester,
  ) async {
    await open(tester, _food(per100));
    expect(segmentLabel('g'), findsOneWidget);
    expect(segmentLabel('kg'), findsOneWidget);
    expect(segmentLabel('ml'), findsNothing);
    expect(segmentLabel('l'), findsNothing);
    await unmount(tester);

    await open(tester, _food(per100, basis: ReferenceUnit.millilitres));
    expect(segmentLabel('ml'), findsOneWidget);
    expect(segmentLabel('l'), findsOneWidget);
    expect(segmentLabel('g'), findsNothing);
    expect(segmentLabel('kg'), findsNothing);
    await unmount(tester);
  });

  testWidgets('typing 0.25 kg previews and logs 250 g', (tester) async {
    final food = _food(per100);
    await DriftFoodRepository(db, clock: FixedClock(_now)).upsert(food);
    await open(tester, food);
    await tester.tap(segmentLabel('kg'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('portion-amount')), '0.25');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('portion-canonical'))).data,
      '= 250 g',
    );
    // 250 g of 200 kcal/100 g.
    expect(
      find.descendant(
        of: find.byKey(const Key('portion-preview')),
        matching: find.text('500'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('portion-log')));
    await tester.pumpAndSettle();
    expect(logged?.quantity, Quantity.fromStored(250, ReferenceUnit.grams));
    await unmount(tester);
  });

  testWidgets('switching g to kg converts the text and back', (tester) async {
    await open(tester, _food(per100));
    final field = find.byKey(const Key('portion-amount'));
    String text() => tester
        .widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)),
        )
        .controller!
        .text;
    await tester.enterText(field, '250');
    await tester.tap(segmentLabel('kg'));
    await tester.pump();
    expect(text(), '0.25');
    await tester.tap(segmentLabel('g'));
    await tester.pump();
    expect(text(), '250');
    await unmount(tester);
  });
}
