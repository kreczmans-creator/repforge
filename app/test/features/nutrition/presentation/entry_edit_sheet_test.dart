import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/presentation/entry_edit_sheet.dart';
import 'package:repforge/ui/theme.dart';

final _now = DateTime(2026, 11, 3, 9);

final _entry = FoodLogEntry(
  id: 'e1',
  day: '2026-11-03',
  meal: MealSlot.lunch,
  name: 'Rice',
  quantity: Quantity.fromStored(100, ReferenceUnit.grams),
  nutrients: const NutrientAmounts(kcal: 130, proteinG: 3, carbsG: 28, fatG: 0),
  provenance: DataProvenance.userEntered,
  loggedAt: _now.toUtc(),
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

// 1.25 portions of a 400 kcal / P 30 per portion recipe.
final _portionsEntry = FoodLogEntry(
  id: 'e2',
  day: '2026-11-03',
  meal: MealSlot.dinner,
  name: 'Chilli',
  recipeId: 'r1',
  quantity: Quantity.fromStored(1.25, ReferenceUnit.portions),
  nutrients: const NutrientAmounts(kcal: 500, proteinG: 37.5),
  provenance: DataProvenance.userEntered,
  loggedAt: _now.toUtc(),
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.inMemory();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(_now)),
      ],
    );
    await container.read(foodLogRepositoryProvider).insert(_entry);
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> openSheet(WidgetTester tester, [FoodLogEntry? entry]) async {
    final e = entry ?? _entry;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: rfTheme(Brightness.dark),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showEntryEditSheet(context, e),
                child: const Text('edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
  }

  Future<FoodLogEntry> stored() async =>
      (await container
              .read(foodLogRepositoryProvider)
              .forDays('2026-11-03', '2026-11-03'))
          .single;

  testWidgets('prefills the amount and describes the entry', (tester) async {
    await openSheet(tester);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.textContaining('130 kcal'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '100',
    );
  });

  testWidgets('saving a new amount rescales nutrients and closes', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), '200');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-save')), findsNothing);
    final e = await stored();
    expect(e.quantity.amount, 200);
    expect(e.nutrients.kcal, 260);
  });

  testWidgets('changing the meal moves the entry', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect((await stored()).meal, MealSlot.dinner);
  });

  testWidgets('an empty amount shows an error and keeps the sheet', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number.'), findsOneWidget);
    expect((await stored()).quantity.amount, 100);
  });

  testWidgets('a zero amount is rejected by the use case', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    expect((await stored()).quantity.amount, 100);
  });

  testWidgets('delete removes the entry and closes the sheet', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('edit-delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-delete')), findsNothing);
    expect(
      await container
          .read(foodLogRepositoryProvider)
          .forDays('2026-11-03', '2026-11-03'),
      isEmpty,
    );
  });

  group('recipe entries (RCP-013)', () {
    final recipe = Recipe(
      id: 'r1',
      name: 'Chilli',
      category: '',
      portions: 2,
      ingredients: [
        RecipeIngredient(
          id: 'i1',
          name: 'Beans',
          foodId: 'beans',
          quantity: Quantity.fromStored(400, ReferenceUnit.grams),
          sortOrder: 0,
          per100: const NutrientProfile(
            per100: ReferenceUnit.grams,
            per100Amounts: NutrientAmounts(kcal: 100),
            provenance: DataProvenance.userEntered,
          ),
        ),
      ],
      createdAt: _now.toUtc(),
      updatedAt: _now.toUtc(),
    );
    final fromRecipe = _entry.copyWith(recipeId: 'r1');

    Future<void> openRouted(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => showEntryEditSheet(context, fromRecipe),
                child: const Text('edit'),
              ),
            ),
          ),
          GoRoute(
            path: '/fuel/recipes/:id',
            builder: (context, state) =>
                Scaffold(body: Text('detail ${state.pathParameters['id']}')),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: rfTheme(Brightness.dark),
            routerConfig: router,
          ),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
    }

    testWidgets('a plain entry has no open-recipe action', (tester) async {
      await openSheet(tester);
      expect(find.byKey(const Key('entry-open-recipe')), findsNothing);
    });

    testWidgets('opens the recipe it was logged from', (tester) async {
      await tester.runAsync(
        () => container.read(recipeRepositoryProvider).upsert(recipe),
      );
      await openRouted(tester);
      await tester.tap(find.byKey(const Key('entry-open-recipe')));
      // drift streams only emit in real time.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('detail r1'), findsOneWidget);
      expect(find.byKey(const Key('edit-save')), findsNothing);
    });

    testWidgets('says so when the recipe no longer exists', (tester) async {
      await openRouted(tester);
      await tester.tap(find.byKey(const Key('entry-open-recipe')));
      // drift streams only emit in real time.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('This recipe no longer exists.'), findsOneWidget);
      expect(find.byKey(const Key('edit-save')), findsOneWidget);
    });
  });

  testWidgets('a portions entry shows 1.25 and rescales exactly to 1.75', (
    tester,
  ) async {
    await container.read(foodLogRepositoryProvider).insert(_portionsEntry);
    await openSheet(tester, _portionsEntry);
    expect(find.textContaining('Logged as 1.25 portions'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1.25',
    );
    await tester.enterText(find.byType(TextField), '1.75');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1.75',
    );
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    final stored =
        (await container
                .read(foodLogRepositoryProvider)
                .forDays('2026-11-03', '2026-11-03'))
            .firstWhere((x) => x.id == 'e2');
    expect(stored.quantity.amount, 1.75);
    expect(stored.nutrients.kcal, closeTo(700, 1e-9));
    expect(stored.nutrients.proteinG, closeTo(52.5, 1e-9));
  });

  testWidgets('a portions amount cannot take a third decimal; grams stop at '
      'one', (tester) async {
    await openSheet(tester, _portionsEntry);
    await tester.enterText(find.byType(TextField), '1.255');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1.25',
    );
    await tester.pumpWidget(const SizedBox());
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), '100.5');
    await tester.enterText(find.byType(TextField), '100.55');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '100.5',
    );
  });
}
