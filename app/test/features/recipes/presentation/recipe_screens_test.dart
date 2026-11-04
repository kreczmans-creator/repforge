import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/features/recipes/application/import_legacy_recipes.dart';
import 'package:repforge/ui/components/rf_text_field.dart';

import '../../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9);

final class _NoLookup implements FoodLookupService {
  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async =>
      const Ok([]);

  @override
  Future<Result<Food?>> byBarcode(String barcode) async => const Ok(null);
}

NutrientProfile _profile(
  double kcal, {
  double? p,
  double? c,
  double? f,
  double? fibre,
}) => NutrientProfile(
  per100: ReferenceUnit.grams,
  per100Amounts: NutrientAmounts(
    kcal: kcal,
    proteinG: p,
    carbsG: c,
    fatG: f,
    fibreG: fibre,
  ),
  provenance: DataProvenance.userEntered,
);

RecipeIngredient _ing(
  String id,
  String name,
  double grams,
  NutrientProfile profile, {
  List<RecipeSubstitute> subs = const [],
}) => RecipeIngredient(
  id: id,
  name: name,
  foodId: 'food-$id',
  quantity: Quantity.fromStored(grams, ReferenceUnit.grams),
  sortOrder: 0,
  per100: profile,
  substitutes: subs,
);

/// 4 portions: chicken 400 g (120 kcal/100 g, fibre 1) + rice 200 g
/// (130 kcal/100 g, fibre unknown) = 740 kcal, 185 per portion; fibre is
/// incomplete (rice does not state it): 4 g / 4 = 1 g.
Recipe _chilli({bool favourite = false}) => Recipe(
  id: 'chilli',
  name: 'Chilli',
  category: 'Dinner',
  portions: 4,
  prepMinutes: 15,
  cookMinutes: 30,
  cookSteps: const ['Simmer'],
  favourite: favourite,
  ingredients: [
    _ing(
      'chicken',
      'Chicken',
      400,
      _profile(120, p: 22, c: 0, f: 3, fibre: 1),
      subs: [
        RecipeSubstitute(
          name: 'Thigh',
          quantity: Quantity.fromStored(400, ReferenceUnit.grams),
          per100: _profile(155, p: 20, c: 0, f: 8, fibre: 1),
        ),
      ],
    ),
    _ing('rice', 'Rice', 200, _profile(130, p: 2.7, c: 28, f: 0.3)),
  ],
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

/// 2 portions of 800 g at 100 kcal/100 g: 400 kcal per portion.
Recipe _stew() => Recipe(
  id: 'stew',
  name: 'Stew',
  category: 'Lunch',
  portions: 2,
  ingredients: [
    _ing('beef', 'Beef', 800, _profile(100, p: 10, c: 5, f: 3, fibre: 1)),
  ],
  createdAt: _now.toUtc(),
  updatedAt: _now.toUtc(),
);

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data;

void main() {
  late AppDatabase db;
  late DriftRecipeRepository recipes;
  setUp(() {
    db = AppDatabase.inMemory();
    recipes = DriftRecipeRepository(db, clock: FixedClock(_now));
  });
  tearDown(() => db.close());

  Future<void> open(
    WidgetTester tester, {
    String location = RfRoutes.fuel,
    Key key = const ValueKey('scope'),
  }) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: key,
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(_now)),
          foodLookupServiceProvider.overrideWithValue(_NoLookup()),
          minuteTickProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: RepForgeApp(router: createRouter(initialLocation: location)),
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

  Finder inKey(String key, String text) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

  testWidgets('list shows the imported seeds labelled as estimates', (
    tester,
  ) async {
    await ImportLegacyRecipes(
      recipes: recipes,
      settings: DriftSettingsRepository(db, clock: FixedClock(_now)),
      clock: FixedClock(_now),
      loadJson: () async =>
          File('assets/seed/legacy_recipes.json').readAsStringSync(),
    )();
    await open(tester);
    await tapKey(tester, 'open-recipes');
    expect(find.byKey(const Key('new-recipe')), findsOneWidget);
    expect(find.text('Smoky Chicken Burrito Wrap'), findsOneWidget);
    expect(find.text('Estimate'), findsWidgets);
    expect(find.textContaining('460 kcal per portion'), findsOneWidget);

    // Detail of a seed: estimate note, original ingredients, no freezing
    // claim, an empty preparation section omitted.
    await tester.tap(find.text('Smoky Chicken Burrito Wrap'));
    await tester.pumpAndSettle();
    expect(find.text('Estimate'), findsWidgets);
    expect(find.byKey(const Key('nutrition-note')), findsOneWidget);
    expect(
      find.text('Ingredients (from the original recipe, not linked to foods)'),
      findsOneWidget,
    );
    expect(find.text('Freezing: not stated'), findsOneWidget);
    expect(find.text('Cooking'), findsOneWidget);
    expect(find.text('Preparation'), findsNothing);
    expect(inKey('nutrition-fibre', 'n/a'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('favourite toggles in one tap and the filter persists', (
    tester,
  ) async {
    await recipes.upsert(_chilli());
    await recipes.upsert(_stew());
    await open(tester, location: RfRoutes.fuelRecipes);
    expect(find.text('Chilli'), findsOneWidget);
    expect(find.text('Stew'), findsOneWidget);

    await tester.tap(find.byKey(const Key('fav-chilli')));
    await tester.pumpAndSettle();
    expect((await recipes.byId('chilli'))!.favourite, isTrue);

    await tester.tap(find.byKey(const Key('filter-favourites')));
    await tester.pumpAndSettle();
    expect(find.text('Chilli'), findsOneWidget);
    expect(find.text('Stew'), findsNothing);

    // "Restart": a brand new provider scope on the same database.
    await open(
      tester,
      location: RfRoutes.fuelRecipes,
      key: const ValueKey('restarted'),
    );
    expect(find.text('Stew'), findsNothing);
    expect(
      tester
          .widget<FilterChip>(find.byKey(const Key('filter-favourites')))
          .selected,
      isTrue,
    );
    await unmount(tester);
  });

  testWidgets('detail: incomplete fibre, total time, empty section omitted', (
    tester,
  ) async {
    await recipes.upsert(_chilli());
    await open(tester, location: RfRoutes.fuelRecipes);
    await tester.tap(find.text('Chilli'));
    await tester.pumpAndSettle();

    expect(inKey('nutrition-kcal', '185 kcal'), findsOneWidget);
    expect(inKey('nutrition-fibre', '1 g (incomplete)'), findsOneWidget);
    expect(find.text('Total time: 45 min'), findsOneWidget);
    expect(find.text('Cooking'), findsOneWidget);
    expect(find.text('Preparation'), findsNothing);
    expect(find.text('Freezing: not stated'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('scaling 4 to 6 multiplies by 1.5 and saves only on request', (
    tester,
  ) async {
    await recipes.upsert(_chilli());
    await open(tester, location: RfRoutes.fuelRecipes);
    await tester.tap(find.text('Chilli'));
    await tester.pumpAndSettle();

    await tapKey(tester, 'scale-open');
    await tester.enterText(find.byKey(const Key('scale-target')), '6');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scaled-indicator')), findsOneWidget);
    expect(_text(tester, 'ingredient-qty-chicken'), '600 g');
    expect(_text(tester, 'ingredient-qty-rice'), '300 g');
    expect(inKey('nutrition-kcal', '185 kcal'), findsOneWidget);
    // Nothing persisted yet.
    expect((await recipes.byId('chilli'))!.portions, 4);
    expect(
      (await recipes.byId('chilli'))!.ingredients.first.quantity.amount,
      400,
    );

    await tapKey(tester, 'scale-save-new');
    final all = await recipes.watchAll().first;
    expect(all, hasLength(2));
    final created = all.firstWhere((r) => r.id != 'chilli');
    expect(created.portions, 6);
    expect(created.ingredients.first.quantity.amount, 600);
    expect((await recipes.byId('chilli'))!.portions, 4);
    await unmount(tester);
  });

  testWidgets('scaling then overwrite replaces the saved recipe', (
    tester,
  ) async {
    await recipes.upsert(_chilli());
    await open(tester, location: RfRoutes.fuelRecipes);
    await tester.tap(find.text('Chilli'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'scale-open');
    await tester.enterText(find.byKey(const Key('scale-target')), '2');
    await tester.pumpAndSettle();
    await tapKey(tester, 'scale-overwrite');
    await tapKey(tester, 'scale-overwrite-confirm');
    final r = (await recipes.byId('chilli'))!;
    expect(r.portions, 2);
    expect(r.ingredients.first.quantity.amount, 200);
    await unmount(tester);
  });

  testWidgets('choosing a substitute shows the kcal per portion difference', (
    tester,
  ) async {
    await recipes.upsert(_chilli());
    await open(tester, location: RfRoutes.fuelRecipes);
    await tester.tap(find.text('Chilli'));
    await tester.pumpAndSettle();

    await tapKey(tester, 'sub-chicken-0');
    // (155 - 120) kcal/100 g x 4 = 140 kcal over 4 portions.
    expect(find.text('+35 kcal per portion'), findsOneWidget);
    expect(inKey('nutrition-kcal', '220 kcal'), findsOneWidget);
    expect((await recipes.byId('chilli'))!.ingredients.first.name, 'Chicken');

    await tapKey(tester, 'sub-chicken-original');
    expect(find.byKey(const Key('sub-delta')), findsNothing);
    await unmount(tester);
  });

  testWidgets('logging 1.5 portions of a 400 kcal recipe adds 600 kcal', (
    tester,
  ) async {
    await recipes.upsert(_stew());
    await open(tester);
    await tapKey(tester, 'open-recipes');
    await tester.tap(find.text('Stew'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'recipe-log');
    // Default 1 portion, grams offered because the recipe has a weight.
    expect(
      tester
          .widget<RfTextField>(find.byKey(const Key('log-portions')))
          .controller!
          .text,
      '1',
    );
    await tester.tap(find.byKey(const Key('log-portions-inc')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RfTextField>(find.byKey(const Key('log-portions')))
          .controller!
          .text,
      '1.5',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('log-preview')),
        matching: find.text('600'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('log-submit')));
    await tester.pumpAndSettle();

    final entries = await db.select(db.foodLogEntries).get();
    expect(entries.single.kcal, 600);
    expect(entries.single.name, 'Stew');

    // Back to the Fuel diary: name and portion count.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Stew'), findsOneWidget);
    expect(find.textContaining('1.5 portions · P'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('log by grams is offered only with a total weight', (
    tester,
  ) async {
    // A millilitre ingredient has no known mass, so no total weight.
    final ml = _stew().copyWith(
      ingredients: [
        RecipeIngredient(
          id: 'milk',
          name: 'Milk',
          foodId: 'milk',
          quantity: Quantity.fromStored(500, ReferenceUnit.millilitres),
          sortOrder: 0,
          per100: const NutrientProfile(
            per100: ReferenceUnit.millilitres,
            per100Amounts: NutrientAmounts(kcal: 50),
            provenance: DataProvenance.userEntered,
          ),
        ),
      ],
      id: 'milky',
      name: 'Milky',
    );
    await recipes.upsert(ml);
    await recipes.upsert(_stew());
    await open(tester, location: RfRoutes.fuelRecipes);
    await tester.tap(find.text('Milky'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'recipe-log');
    expect(find.byKey(const Key('log-mode')), findsNothing);
    await unmount(tester);
  });

  testWidgets('log 400 g of an 800 g, 2 portion recipe', (tester) async {
    await recipes.upsert(_stew());
    await open(tester, location: RfRoutes.fuelRecipes);
    await tester.tap(find.text('Stew'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'recipe-log');
    await tester.tap(find.text('Grams'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('log-grams')), '400');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log-submit')));
    await tester.pumpAndSettle();
    final e = (await db.select(db.foodLogEntries).get()).single;
    expect(e.kcal, 400);
    expect(e.amount, 400);
    await unmount(tester);
  });

  group('editor', () {
    Future<void> addFood(String id, String name, NutrientProfile p) =>
        DriftFoodRepository(db, clock: FixedClock(_now)).upsert(
          Food(
            id: id,
            name: name,
            profile: p,
            source: FoodSource.userCreated,
            createdAt: _now.toUtc(),
            updatedAt: _now.toUtc(),
          ),
        );

    Future<void> pickIngredient(
      WidgetTester tester,
      String query,
      String foodId,
      String amount,
    ) async {
      await tapKey(tester, 'add-ingredient');
      await tester.enterText(find.byKey(const Key('food-query')), query);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('local-$foodId')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('ingredient-amount')),
        amount,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ingredient-save')));
      await tester.pumpAndSettle();
    }

    Future<void> openNew(WidgetTester tester) async {
      await open(tester, location: RfRoutes.fuelRecipes);
      await tester.tap(find.byKey(const Key('new-recipe')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows validation messages next to the fields', (tester) async {
      await addFood('f1', 'Oats', _profile(200, p: 10, c: 20, f: 8));
      await openNew(tester);

      await tapKey(tester, 'recipe-save');
      expect(find.text('Enter a recipe name.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('recipe-name-field')), 'X');
      await tapKey(tester, 'recipe-save');
      expect(find.text('Add at least one ingredient.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('recipe-portions-field')),
        '0.5',
      );
      await tapKey(tester, 'recipe-save');
      expect(find.text('A recipe needs 1 or more portions.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('recipe-portions-field')),
        '2',
      );
      await pickIngredient(tester, 'oat', 'f1', '100');
      await tester.enterText(
        find.byKey(const Key('recipe-cook-field')),
        '1500',
      );
      await tapKey(tester, 'recipe-save');
      expect(find.text('Enter whole minutes from 0 to 1440.'), findsOneWidget);
      expect(await recipes.watchAll().first, isEmpty);
      await unmount(tester);
    });

    testWidgets('creates a recipe from two foods with computed values', (
      tester,
    ) async {
      await addFood('f1', 'Oats', _profile(200, p: 10, c: 20, f: 8));
      await addFood('f2', 'Milk', _profile(100, p: 5, c: 10, f: 2, fibre: 1));
      await openNew(tester);

      await tester.enterText(
        find.byKey(const Key('recipe-name-field')),
        'Porridge',
      );
      await tester.enterText(
        find.byKey(const Key('recipe-portions-field')),
        '2',
      );
      await tester.enterText(find.byKey(const Key('recipe-prep-field')), '5');
      await pickIngredient(tester, 'oat', 'f1', '150');
      await pickIngredient(tester, 'milk', 'f2', '40');
      expect(find.text('150 g'), findsOneWidget);
      expect(find.text('40 g'), findsOneWidget);

      // Reorder: milk first, then back.
      await tapKey(tester, 'ingredient-up-1');
      await tapKey(tester, 'ingredient-down-0');
      await tapKey(tester, 'recipe-save');

      final saved = (await recipes.watchAll().first).single;
      expect(saved.name, 'Porridge');
      expect(saved.ingredients.map((i) => i.name), ['Oats', 'Milk']);
      // Hand-calculated: 150 g oats + 40 g milk = 340 kcal, 17 g protein,
      // 34 g carbs, 12.8 g fat; per portion (2): 170 / 8.5 / 17 / 6.4.
      expect(saved.perPortion!.kcal, 170);
      expect(saved.perPortion!.proteinG, closeTo(8.5, 1e-9));
      expect(saved.perPortion!.carbsG, closeTo(17, 1e-9));
      expect(saved.perPortion!.fatG, closeTo(6.4, 1e-9));
      expect(saved.perPortion!.fibreG, isNull); // oats do not state fibre

      // The list pushed the detail of the new recipe.
      expect(inKey('nutrition-kcal', '170 kcal'), findsOneWidget);
      expect(inKey('nutrition-protein', '8.5 g'), findsOneWidget);
      expect(inKey('nutrition-fibre', '0.2 g (incomplete)'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('edits steps, weights and deletes with confirmation', (
      tester,
    ) async {
      await recipes.upsert(_chilli());
      await open(tester, location: RfRoutes.fuelRecipeEdit('chilli'));
      // Edit route is the only page: use the app through the list instead.
      await unmount(tester);
      await open(tester, location: RfRoutes.fuelRecipes);
      await tester.tap(find.text('Chilli'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'recipe-edit');
      expect(find.byKey(const Key('recipe-name-field')), findsOneWidget);

      await tapKey(tester, 'prep-step-add');
      await tester.enterText(find.byKey(const Key('prep-step-0')), 'Chop');
      await tapKey(tester, 'prep-step-add');
      await tester.enterText(find.byKey(const Key('prep-step-1')), 'Wash');
      await tapKey(tester, 'prep-step-up-1');
      await tapKey(tester, 'portion-mode');
      await tester.tap(find.text('By weight'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('recipe-total-weight-field')),
        '900',
      );
      await tester.enterText(
        find.byKey(const Key('recipe-portion-weight-field')),
        '300',
      );
      await tester.pumpAndSettle();
      expect(find.text('= 3 portions'), findsOneWidget);
      await tapKey(tester, 'recipe-save');

      final r = (await recipes.byId('chilli'))!;
      expect(r.prepSteps, ['Wash', 'Chop']);
      expect(r.portions, 3);
      expect(r.totalWeightG, 900);
      expect(r.portionWeightG, 300);
      expect(r.cookSteps, ['Simmer']);

      await tapKey(tester, 'recipe-edit');
      await tapKey(tester, 'recipe-delete');
      await tapKey(tester, 'recipe-delete-confirm');
      expect(await recipes.byId('chilli'), isNull);
      expect(find.byKey(const Key('recipes-empty')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an imported recipe keeps its notes and says so', (
      tester,
    ) async {
      await ImportLegacyRecipes(
        recipes: recipes,
        settings: DriftSettingsRepository(db, clock: FixedClock(_now)),
        clock: FixedClock(_now),
        loadJson: () async =>
            File('assets/seed/legacy_recipes.json').readAsStringSync(),
      )();
      await open(tester, location: RfRoutes.fuelRecipes);
      await tester.tap(find.text('Smoky Chicken Burrito Wrap'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'recipe-edit');
      expect(find.byKey(const Key('imported-note')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('recipe-description-field')),
        'Edited description',
      );
      await tapKey(tester, 'recipe-save');
      final r = (await recipes.byId('starter-chicken-burrito-001'))!;
      expect(r.description, 'Edited description');
      expect(r.ingredientNotes, isNotEmpty);
      expect(r.declaredPerPortion!.kcal, 460);
      await unmount(tester);
    });
  });
}
