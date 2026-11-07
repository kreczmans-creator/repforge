import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/presentation/food_source_line.dart';
import 'package:repforge/features/nutrition/presentation/portion_sheet.dart';
import 'package:repforge/ui/theme.dart';

import '../../../helpers/pump.dart';

final _created = DateTime(2026, 11, 3, 9);

Food _food({
  required FoodSource source,
  String? barcode,
  DataProvenance provenance = DataProvenance.userEntered,
}) => Food(
  id: source == FoodSource.openFoodFacts ? 'off:$barcode' : 'f1',
  name: 'Thing',
  profile: NutrientProfile(
    per100: ReferenceUnit.grams,
    per100Amounts: const NutrientAmounts(kcal: 100),
    provenance: provenance,
  ),
  source: source,
  barcode: barcode,
  createdAt: _created,
  updatedAt: _created,
);

void main() {
  group('foodSourceText (NUT-023)', () {
    test('imported Open Food Facts food: name, product code, import date', () {
      final food = _food(
        source: FoodSource.openFoodFacts,
        barcode: '3017620422003',
        provenance: DataProvenance.crowdsourced,
      );
      expect(
        foodSourceText(food),
        'Source: Open Food Facts · 3017620422003 · imported 2026-11-03',
      );
    });

    test('imported food without a stored code omits the identifier', () {
      expect(
        foodSourceText(_food(source: FoodSource.openFoodFacts)),
        'Source: Open Food Facts · imported 2026-11-03',
      );
    });

    test('user food: created date, no source name or code', () {
      expect(
        foodSourceText(_food(source: FoodSource.userCreated, barcode: '123')),
        'Your food · created 2026-11-03',
      );
    });

    test('unsaved online hit says so and shows no import date', () {
      final food = _food(
        source: FoodSource.openFoodFacts,
        barcode: '3017620422003',
      );
      expect(
        foodSourceText(food, stored: false),
        'Source: Open Food Facts · 3017620422003 · not saved yet',
      );
      expect(
        foodSourceText(food, stored: null),
        'Source: Open Food Facts · 3017620422003',
      );
    });

    test('a UTC instant near midnight shows the local calendar day', () {
      final utc = DateTime.utc(2026, 11, 3, 23, 30);
      final food = _food(source: FoodSource.userCreated)
          .copyWith(createdAt: utc, updatedAt: utc);
      expect(
        foodSourceText(food),
        'Your food · created ${dayKey(utc.toLocal())}',
      );
    });

    test('seed food', () {
      expect(
        foodSourceText(_food(source: FoodSource.seed)),
        'Source: built-in food list · added 2026-11-03',
      );
    });
  });

  group('portion sheet shows the source line', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.inMemory());
    tearDown(() => db.close());

    Future<void> open(
      WidgetTester tester,
      Food food, {
      Size size = const Size(600, 2400),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            clockProvider.overrideWithValue(FixedClock(_created)),
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

    testWidgets('imported food', (tester) async {
      final food = _food(
        source: FoodSource.openFoodFacts,
        barcode: '3017620422003',
        provenance: DataProvenance.crowdsourced,
      );
      await DriftFoodRepository(db, clock: FixedClock(_created)).upsert(food);
      await open(tester, food);
      expect(
        find.text(
          'Source: Open Food Facts · 3017620422003 · imported 2026-11-03',
        ),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('unsaved online hit shows "not saved yet"', (tester) async {
      await open(
        tester,
        _food(
          source: FoodSource.openFoodFacts,
          barcode: '3017620422003',
          provenance: DataProvenance.crowdsourced,
        ),
      );
      expect(
        find.text('Source: Open Food Facts · 3017620422003 · not saved yet'),
        findsOneWidget,
      );
      expect(find.textContaining('imported'), findsNothing);
      await unmount(tester);
    });

    testWidgets('long code at 320x640 does not overflow', (tester) async {
      final code = '1234567890123' * 4;
      await DriftFoodRepository(
        db,
        clock: FixedClock(_created),
      ).upsert(_food(source: FoodSource.openFoodFacts, barcode: code));
      await open(
        tester,
        _food(source: FoodSource.openFoodFacts, barcode: code),
        size: const Size(320, 640),
      );
      expect(find.textContaining(code), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('user food', (tester) async {
      await open(tester, _food(source: FoodSource.userCreated));
      expect(find.text('Your food · created 2026-11-03'), findsOneWidget);
      await unmount(tester);
    });
  });
}
