import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/presentation/custom_food_screen.dart';
import 'package:repforge/ui/theme.dart';

final _now = DateTime.utc(2026, 11, 3, 12);

void main() {
  late AppDatabase db;
  Food? created;
  var ids = 0;

  setUp(() {
    db = AppDatabase.inMemory();
    created = null;
    ids = 0;
  });
  tearDown(() => db.close());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(_now)),
          idGeneratorProvider.overrideWithValue(() => 'food${++ids}'),
        ],
        child: MaterialApp(
          theme: rfTheme(Brightness.dark),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  created = await Navigator.of(context).push<Food>(
                    MaterialPageRoute(builder: (_) => const CustomFoodScreen()),
                  );
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

  Future<void> type(WidgetTester t, String key, String text) async {
    await t.enterText(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      ),
      text,
    );
  }

  Future<void> fillRequired(WidgetTester t) async {
    await type(t, 'food-name', 'Oat bar');
    await type(t, 'food-kcal', '400');
    await type(t, 'food-protein', '10');
    await type(t, 'food-carbs', '60');
    await type(t, 'food-fat', '12');
  }

  Future<void> save(WidgetTester t) async {
    await t.ensureVisible(find.byKey(const Key('food-save')));
    await t.tap(find.byKey(const Key('food-save')));
    await t.pumpAndSettle();
  }

  testWidgets('shows the form with the serving hint and no errors', (t) async {
    await open(t);
    expect(find.text('Save food'), findsOneWidget);
    expect(find.textContaining('Optional. For example'), findsOneWidget);
    expect(find.text('Enter a food name.'), findsNothing);
  });

  testWidgets('empty name shows an error next to the name field', (t) async {
    await open(t);
    await save(t);
    expect(find.text('Enter a food name.'), findsOneWidget);
    expect(find.byType(CustomFoodScreen), findsOneWidget);
  });

  testWidgets('missing energy shows a number error and keeps the form', (
    t,
  ) async {
    await open(t);
    await type(t, 'food-name', 'Oat bar');
    await save(t);
    expect(find.text('Enter a number.'), findsOneWidget);
    expect(created, isNull);
  });

  testWidgets('saves a food per 100 g and pops it with its nutrients', (
    t,
  ) async {
    await open(t);
    await fillRequired(t);
    await save(t);
    expect(find.byType(CustomFoodScreen), findsNothing);
    expect(created!.name, 'Oat bar');
    expect(created!.profile.per100, ReferenceUnit.grams);
    expect(created!.profile.per100Amounts.kcal, 400);
    expect(created!.source, FoodSource.userCreated);
    expect((await db.select(db.foods).get()).length, 1);
  });

  testWidgets('switching to millilitres saves a per-100-ml food', (t) async {
    await open(t);
    await t.tap(find.text('millilitres'));
    await t.pumpAndSettle();
    await fillRequired(t);
    await save(t);
    expect(created!.profile.per100, ReferenceUnit.millilitres);
  });

  testWidgets('adds, removes and saves servings', (t) async {
    await open(t);
    await t.ensureVisible(find.text('Add serving'));
    await t.tap(find.text('Add serving'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('serving-label-0')), findsOneWidget);
    await t.tap(find.byTooltip('Remove serving'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('serving-label-0')), findsNothing);

    await t.tap(find.text('Add serving'));
    await t.tap(find.text('Add serving'));
    await t.pumpAndSettle();
    await fillRequired(t);
    await type(t, 'serving-label-0', 'Bar');
    await type(t, 'serving-amount-0', '45');
    await save(t);
    // The second serving row is blank and ignored.
    expect(created!.servings.single.label, 'Bar');
    expect(created!.servings.single.quantity.amount, 45);
  });

  testWidgets('a serving without an amount shows the servings error', (
    t,
  ) async {
    await open(t);
    await fillRequired(t);
    await t.ensureVisible(find.text('Add serving'));
    await t.tap(find.text('Add serving'));
    await t.pumpAndSettle();
    await type(t, 'serving-label-0', 'Bar');
    await save(t);
    expect(
      find.text('Each serving needs a name and an amount above zero.'),
      findsOneWidget,
    );
    expect(created, isNull);
  });

  testWidgets('out-of-range energy shows a generic validation message', (
    t,
  ) async {
    await open(t);
    await fillRequired(t);
    await type(t, 'food-kcal', '99999');
    await save(t);
    expect(created, isNull);
    expect(find.text('Energy cannot exceed 900 kcal per 100.'), findsOneWidget);
  });
}
