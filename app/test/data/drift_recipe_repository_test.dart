import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));
final _t = DateTime.utc(2026, 11, 1, 8);

RecipeIngredient _ing(String id, int order, {bool withProfile = true}) =>
    RecipeIngredient(
      id: id,
      name: 'Ingredient $id',
      foodId: withProfile ? 'food-$id' : null,
      quantity: Quantity.fromStored(200, ReferenceUnit.grams),
      sortOrder: order,
      note: withProfile ? 'chopped' : null,
      per100: withProfile
          ? const NutrientProfile(
              per100: ReferenceUnit.grams,
              per100Amounts: NutrientAmounts(
                kcal: 100,
                proteinG: 20,
                carbsG: 5,
                fatG: 2,
                fibreG: 1,
              ),
              provenance: DataProvenance.verified,
            )
          : null,
    );

Recipe _recipe(
  String id,
  String name, {
  List<RecipeIngredient>? ingredients,
  bool full = true,
}) => Recipe(
  id: id,
  name: name,
  category: 'dinner',
  portions: 2,
  ingredients:
      ingredients ?? [_ing('$id-1', 0), _ing('$id-2', 1, withProfile: false)],
  methodSteps: const ['Chop', 'Cook, "stirring" often'],
  description: full ? 'Tasty' : '',
  prepMinutes: full ? 10 : null,
  cookMinutes: full ? 20 : null,
  storage: full ? 'Fridge 3 days' : null,
  freezerFriendly: full,
  reheating: full ? 'Microwave' : null,
  favourite: full,
  declaredPerPortion: full
      ? const NutrientAmounts(kcal: 500, proteinG: 40, carbsG: 30, fatG: 15)
      : null,
  nutritionNote: full ? 'Estimated' : null,
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  late AppDatabase db;
  late DriftRecipeRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftRecipeRepository(db, clock: _clock);
  });
  tearDown(() => db.close());

  test('upsert and byId round-trip the full entity', () async {
    final r = _recipe('r1', 'Chilli');
    await repo.upsert(r);
    expect(await repo.byId('r1'), r);
  });

  test('round-trips minimal recipe with null fields', () async {
    final r = _recipe('r2', 'Plain', full: false, ingredients: const []);
    await repo.upsert(r);
    final read = await repo.byId('r2');
    expect(read, r);
    expect(read!.declaredPerPortion, isNull);
    expect(read.prepMinutes, isNull);
  });

  test('upsert replaces ingredients', () async {
    await repo.upsert(_recipe('r1', 'Chilli'));
    final updated = _recipe('r1', 'Chilli v2', ingredients: [_ing('x', 0)]);
    await repo.upsert(updated);
    final read = await repo.byId('r1');
    expect(read, updated);
    expect(read!.ingredients.map((i) => i.id), ['x']);
    expect(await db.select(db.recipeIngredients).get(), hasLength(1));
  });

  test('ingredients come back in sortOrder', () async {
    final r = _recipe('r1', 'A', ingredients: [_ing('b', 1), _ing('a', 0)]);
    await repo.upsert(r);
    expect((await repo.byId('r1'))!.ingredients.map((i) => i.id), ['a', 'b']);
  });

  test('setFavourite toggles and stamps updatedAt', () async {
    await repo.upsert(_recipe('r1', 'A', full: false));
    await repo.setFavourite('r1', favourite: true);
    var read = (await repo.byId('r1'))!;
    expect(read.favourite, isTrue);
    expect(read.updatedAt, _clock.now());
    await repo.setFavourite('r1', favourite: false);
    read = (await repo.byId('r1'))!;
    expect(read.favourite, isFalse);
  });

  test('delete soft-deletes, hides and is idempotent', () async {
    await repo.upsert(_recipe('r1', 'A'));
    await repo.delete('r1');
    expect(await repo.byId('r1'), isNull);
    expect(await repo.watchAll().first, isEmpty);
    final first = (await db.select(db.recipes).get()).single;
    expect(first.deletedAt, _clock.now());
    await repo.delete('r1');
    final second = (await db.select(db.recipes).get()).single;
    expect(second.updatedAt, first.updatedAt);
  });

  test('watchAll emits on insert, ordered by name', () async {
    final emissions = <List<String>>[];
    final sub = repo.watchAll().listen(
      (l) => emissions.add([for (final r in l) r.id]),
    );
    await pumpEventQueue();
    await repo.upsert(_recipe('b', 'Beta'));
    await pumpEventQueue();
    await repo.upsert(_recipe('a', 'Alpha'));
    await pumpEventQueue();
    await sub.cancel();
    expect(emissions.first, isEmpty);
    expect(emissions.last, ['a', 'b']);
  });

  test('skips a recipe whose method JSON is corrupt', () async {
    await repo.upsert(_recipe('ok', 'Fine'));
    await db
        .into(db.recipes)
        .insert(
          RecipesCompanion.insert(
            id: 'bad',
            name: 'Bad',
            category: 'x',
            portions: 1,
            methodStepsJson: 'not json',
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    expect((await repo.watchAll().first).map((r) => r.id), ['ok']);
  });
}
