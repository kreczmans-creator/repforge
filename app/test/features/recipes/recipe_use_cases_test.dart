import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/recipes/application/save_recipe.dart';

final _created = DateTime.utc(2026, 11);
final _now = DateTime.utc(2026, 11, 4, 9);

const _profile = NutrientProfile(
  per100: ReferenceUnit.grams,
  per100Amounts: NutrientAmounts(kcal: 100, proteinG: 20),
  provenance: DataProvenance.verified,
);

RecipeIngredient _ing(String id, double grams) => RecipeIngredient(
  id: id,
  name: 'Chicken',
  foodId: 'chicken',
  quantity: Quantity.fromStored(grams, ReferenceUnit.grams),
  sortOrder: 0,
  per100: _profile,
);

Recipe _recipe({
  String id = 'r1',
  String name = 'Chilli',
  double portions = 2,
  List<RecipeIngredient>? ingredients,
}) => Recipe(
  id: id,
  name: name,
  category: 'dinner',
  portions: portions,
  ingredients: ingredients ?? [_ing('i1', 800)],
  createdAt: _created,
  updatedAt: _created,
);

void main() {
  late AppDatabase db;
  late DriftRecipeRepository repo;
  late SaveRecipe save;
  var ids = 0;
  final clock = FixedClock(_now);

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftRecipeRepository(db, clock: clock);
    ids = 0;
    save = SaveRecipe(recipes: repo, clock: clock, newId: () => 'n${++ids}');
  });
  tearDown(() => db.close());

  group('SaveRecipe', () {
    test('saves a valid new recipe, stamping created and updated', () async {
      final r = await save(_recipe(name: '  Chilli  '));
      final saved = (r as Ok<Recipe>).value;
      expect(saved.name, 'Chilli');
      expect(saved.createdAt, _now);
      expect(saved.updatedAt, _now);
      expect(await repo.byId('r1'), saved);
    });

    test(
      'RCP-001(2) a saved recipe is available from the repository list',
      () async {
        await save(_recipe());
        expect((await repo.watchAll().first).map((r) => r.id), ['r1']);
      },
    );

    test('rejects an invalid recipe and stores nothing', () async {
      for (final bad in [
        _recipe(name: ''),
        _recipe(portions: 0.5),
        _recipe(ingredients: const []),
        _recipe(ingredients: [_ing('i1', 0)]),
      ]) {
        final r = await save(bad);
        expect((r as Err).error, isA<ValidationError>());
      }
      expect(await repo.watchAll().first, isEmpty);
    });

    test('tidies blank steps and notes', () async {
      final r = await save(
        _recipe().copyWith(
          prepSteps: [' Chop ', '', '  '],
          cookSteps: ['Cook'],
          ingredientNotes: ['x', ' '],
        ),
      );
      final saved = (r as Ok<Recipe>).value;
      expect(saved.prepSteps, ['Chop']);
      expect(saved.ingredientNotes, ['x']);
    });

    test('overwrite keeps createdAt and the id, and moves updatedAt', () async {
      await save(_recipe());
      final later = SaveRecipe(
        recipes: repo,
        clock: FixedClock(DateTime.utc(2026, 11, 5)),
        newId: () => 'unused',
      );
      final r = await later(_recipe(name: 'Chilli v2'));
      final saved = (r as Ok<Recipe>).value;
      expect(saved.id, 'r1');
      expect(saved.createdAt, _now);
      expect(saved.updatedAt, DateTime.utc(2026, 11, 5));
      expect((await repo.watchAll().first).single.name, 'Chilli v2');
    });

    test('RCP-009(2) save as new stores a separate recipe and leaves the '
        'original unchanged', () async {
      await save(_recipe());
      final original = (await repo.byId('r1'))!;
      final scaled = (original.scaleToPortions(6) as Ok<Recipe>).value;

      final r = await save(scaled.copyWith(name: 'Chilli x6'), saveAsNew: true);
      final copy = (r as Ok<Recipe>).value;

      expect(copy.id, isNot('r1'));
      expect(copy.ingredients.single.id, isNot('i1'));
      expect(copy.ingredients.single.quantity.amount, 2400);
      expect(copy.portions, 6);
      expect(copy.favourite, isFalse);
      expect(await repo.byId('r1'), original);
      expect(await repo.watchAll().first, hasLength(2));
    });

    test('RCP-009(2) overwrite replaces the saved recipe with the scaled '
        'view', () async {
      await save(_recipe());
      final scaled =
          ((await repo.byId('r1'))!.scaleToPortions(6) as Ok<Recipe>).value;
      await save(scaled);
      final read = (await repo.byId('r1'))!;
      expect(read.portions, 6);
      expect(read.ingredients.single.quantity.amount, 2400);
      expect(await repo.watchAll().first, hasLength(1));
    });
  });

  group('DeleteRecipe and ToggleFavourite', () {
    test('delete hides the recipe; a missing recipe is NotFound', () async {
      await save(_recipe());
      final del = DeleteRecipe(recipes: repo);
      expect((await del('r1')).isOk, isTrue);
      expect(await repo.byId('r1'), isNull);
      expect(((await del('r1')) as Err).error, isA<NotFoundError>());
    });

    test('RCP-011(1) toggling takes one call and flips the flag', () async {
      await save(_recipe());
      final toggle = ToggleFavourite(recipes: repo);
      expect(((await toggle('r1')) as Ok<bool>).value, isTrue);
      expect((await repo.byId('r1'))!.favourite, isTrue);
      expect(((await toggle('r1')) as Ok<bool>).value, isFalse);
      expect(((await toggle('r1', favourite: true)) as Ok<bool>).value, isTrue);
      expect(((await toggle('zzz')) as Err).error, isA<NotFoundError>());
    });
  });
}
