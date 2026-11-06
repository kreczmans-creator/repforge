import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/features/nutrition/presentation/fuel_screen.dart';
import 'package:repforge/features/settings/presentation/settings_screen.dart';
import 'package:repforge/ui/theme.dart';

import '../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9);

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() {
    db = AppDatabase.inMemory();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(_now)),
        minuteTickProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> show(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: rfTheme(Brightness.dark), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> logSnack() => container
      .read(foodLogRepositoryProvider)
      .insert(
        FoodLogEntry(
          id: 'e1',
          day: '2026-11-03',
          meal: MealSlot.snack,
          name: 'Bar',
          quantity: Quantity.fromStored(1, ReferenceUnit.grams),
          nutrients: const NutrientAmounts(kcal: 150),
          provenance: DataProvenance.userEntered,
          loggedAt: _now.toUtc(),
          createdAt: _now.toUtc(),
          updatedAt: _now.toUtc(),
        ),
      );

  testWidgets('renaming Snacks relabels an existing entry section', (
    tester,
  ) async {
    await logSnack();
    await show(tester, const Scaffold(body: FuelScreen()));
    expect(find.text('Snacks · 150 kcal'), findsOneWidget);

    await show(tester, const SettingsScreen());
    await tester.enterText(
      find.byKey(const Key('meal-label-snack')),
      'Pre-workout',
    );
    await tapKey(tester, 'save-meals');
    expect(find.text('Meal names saved'), findsOneWidget);

    await show(tester, const Scaffold(body: FuelScreen()));
    expect(find.text('Pre-workout · 150 kcal'), findsOneWidget);
    expect(find.textContaining('Snacks'), findsNothing);
    await unmount(tester);
  });

  testWidgets('reordering meals changes the section order', (tester) async {
    await show(tester, const SettingsScreen());
    // Dinner (index 2) up twice: Dinner, Breakfast, Lunch, Snacks.
    await tapKey(tester, 'meal-up-dinner');
    await tapKey(tester, 'meal-up-dinner');
    await tapKey(tester, 'save-meals');

    await show(tester, const Scaffold(body: FuelScreen()));
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Dinner'), lessThan(y('Breakfast')));
    expect(y('Breakfast'), lessThan(y('Lunch')));
    expect(y('Lunch'), lessThan(y('Snacks')));
    await unmount(tester);
  });

  testWidgets('shows validation messages for blank and duplicate names', (
    tester,
  ) async {
    await show(tester, const SettingsScreen());
    await tester.enterText(find.byKey(const Key('meal-label-lunch')), '  ');
    await tapKey(tester, 'save-meals');
    expect(find.text('Enter a meal name.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('meal-label-lunch')),
      'breakfast',
    );
    await tapKey(tester, 'save-meals');
    expect(
      find.text('Meal names must be different from each other.'),
      findsOneWidget,
    );
    await unmount(tester);
  });
}
