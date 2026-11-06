import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/presentation/saved_meals_screen.dart';
import 'package:repforge/ui/theme.dart';

import '../../../helpers/pump.dart';

final _now = DateTime(
  2026,
  11,
  3,
  9,
); // local, so the default slot is breakfast

SavedMeal _meal(
  String id,
  String name, {
  int items = 2,
  MealSlot? slot,
  double? protein = 20,
  bool lastUnknown = false,
}) => SavedMeal(
  id: id,
  name: name,
  defaultMeal: slot,
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
  items: [
    for (var i = 0; i < items; i++)
      SavedMealItem(
        id: '$id-$i',
        name: 'Item $i',
        quantity: Quantity.fromStored(100, ReferenceUnit.grams),
        nutrients: NutrientAmounts(
          kcal: 250,
          proteinG: lastUnknown && i == items - 1 ? null : protein,
          carbsG: 10,
          fatG: 5,
        ),
        provenance: DataProvenance.userEntered,
        sortOrder: i,
      ),
  ],
);

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  var ids = 0;

  setUp(() {
    db = AppDatabase.inMemory();
    ids = 0;
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(_now)),
        idGeneratorProvider.overrideWithValue(() => 'id${++ids}'),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: rfTheme(Brightness.dark), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when no meals are saved', (tester) async {
    await pump(tester, const SavedMealsScreen());
    expect(find.byKey(const Key('saved-meals-empty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('lists meals with item count, totals and item names', (
    tester,
  ) async {
    await container
        .read(savedMealRepositoryProvider)
        .upsert(_meal('m1', 'Box'));
    await pump(tester, const SavedMealsScreen());
    expect(find.text('Box'), findsOneWidget);
    expect(find.text('2 item(s) · 500 kcal · P 40 g'), findsOneWidget);
    expect(find.text('Item 0, Item 1'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('unknown protein shows n/a; partial total shows the marker', (
    tester,
  ) async {
    final repo = container.read(savedMealRepositoryProvider);
    await repo.upsert(_meal('m1', 'Unknown', protein: null));
    await repo.upsert(_meal('m2', 'Partial', lastUnknown: true));
    await pump(tester, const SavedMealsScreen());
    expect(find.text('2 item(s) · 500 kcal · P n/a'), findsOneWidget);
    expect(
      find.text('2 item(s) · 500 kcal · P 20 g · 1 unknown'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('deleting a meal removes it and shows the empty state', (
    tester,
  ) async {
    await container
        .read(savedMealRepositoryProvider)
        .upsert(_meal('m1', 'Box'));
    await pump(tester, const SavedMealsScreen());
    await tester.tap(find.byKey(const Key('delete-meal-m1')));
    await tester.pumpAndSettle();
    expect(find.text('Box'), findsNothing);
    expect(find.byKey(const Key('saved-meals-empty')), findsOneWidget);
    expect(await container.read(savedMealRepositoryProvider).byId('m1'), null);
    await unmount(tester);
  });

  testWidgets('logging uses the default slot and the selected day', (
    tester,
  ) async {
    await container
        .read(savedMealRepositoryProvider)
        .upsert(_meal('m1', 'Box', slot: MealSlot.dinner));
    await pump(tester, const SavedMealsScreen());
    await tester.tap(find.byKey(const Key('log-meal-m1')));
    await tester.pumpAndSettle();
    expect(find.text('Logged 2 item(s) to Dinner'), findsOneWidget);
    final logged = await container
        .read(foodLogRepositoryProvider)
        .forDays('2026-11-03', '2026-11-03');
    expect(logged.length, 2);
    expect(logged.map((e) => e.meal).toSet(), {MealSlot.dinner});
    await unmount(tester);
  });

  testWidgets('logging without a default slot picks one from the time', (
    tester,
  ) async {
    await container
        .read(savedMealRepositoryProvider)
        .upsert(_meal('m1', 'Box'));
    await pump(tester, const SavedMealsScreen());
    await tester.tap(find.byKey(const Key('log-meal-m1')));
    await tester.pumpAndSettle();
    expect(find.text('Logged 2 item(s) to Breakfast'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('logging a meal with no items reports the error', (tester) async {
    await container
        .read(savedMealRepositoryProvider)
        .upsert(_meal('m1', 'Hollow', items: 0));
    await pump(tester, const SavedMealsScreen());
    await tester.tap(find.byKey(const Key('log-meal-m1')));
    await tester.pumpAndSettle();
    expect(find.text('This saved meal has no items.'), findsOneWidget);
    await unmount(tester);
  });

  group('showSaveMealDialog', () {
    final entries = [
      FoodLogEntry(
        id: 'e1',
        day: '2026-11-03',
        meal: MealSlot.lunch,
        name: 'Rice',
        quantity: Quantity.fromStored(150, ReferenceUnit.grams),
        nutrients: const NutrientAmounts(
          kcal: 200,
          proteinG: 4,
          carbsG: 44,
          fatG: 1,
        ),
        provenance: DataProvenance.userEntered,
        loggedAt: _now.toUtc(),
        createdAt: _now.toUtc(),
        updatedAt: _now.toUtc(),
      ),
    ];
    Widget opener() => Consumer(
      builder: (context, ref, _) => Scaffold(
        body: TextButton(
          onPressed: () => showSaveMealDialog(
            context,
            ref,
            entries: entries,
            slot: MealSlot.lunch,
          ),
          child: const Text('save'),
        ),
      ),
    );

    testWidgets('names and saves the meal', (tester) async {
      await pump(tester, opener());
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Rice bowl');
      await tester.tap(find.byKey(const Key('save-meal-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Saved "Rice bowl"'), findsOneWidget);
      final all = await container
          .read(savedMealRepositoryProvider)
          .watchAll()
          .first;
      expect(all.single.defaultMeal, MealSlot.lunch);
      await unmount(tester);
    });

    testWidgets('a blank name is rejected with a message', (tester) async {
      await pump(tester, opener());
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-meal-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a meal name.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('cancelling saves nothing', (tester) async {
      await pump(tester, opener());
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final all = await container
          .read(savedMealRepositoryProvider)
          .watchAll()
          .first;
      expect(all, isEmpty);
      await unmount(tester);
    });
  });
}
