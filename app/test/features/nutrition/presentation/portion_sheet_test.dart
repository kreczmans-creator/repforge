import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/presentation/portion_sheet.dart';
import 'package:repforge/ui/theme.dart';

import '../../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9);

Food _food(NutrientAmounts per100) => Food(
  id: 'f1',
  name: 'Thing',
  profile: NutrientProfile(
    per100: ReferenceUnit.grams,
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

  Future<void> open(WidgetTester tester, Food food) async {
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
                onPressed: () => showPortionSheet(context, food),
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
}
