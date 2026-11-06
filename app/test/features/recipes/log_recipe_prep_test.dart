import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_prep_batch_repository.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/recipes/application/log_recipe.dart';

final _t = DateTime.utc(2026, 11, 4, 9);

Recipe _recipe(String id) => Recipe(
  id: id,
  name: 'Chilli $id',
  category: 'dinner',
  portions: 2,
  ingredients: [
    RecipeIngredient(
      id: 'i-$id',
      name: 'Chicken',
      foodId: 'chicken',
      quantity: Quantity.fromStored(800, ReferenceUnit.grams),
      sortOrder: 0,
      per100: const NutrientProfile(
        per100: ReferenceUnit.grams,
        per100Amounts: NutrientAmounts(kcal: 100, proteinG: 20),
        provenance: DataProvenance.verified,
      ),
    ),
  ],
  createdAt: _t,
  updatedAt: _t,
);

PrepBatch _batch(String id, String recipeId, double remaining) => PrepBatch(
  id: id,
  recipeId: recipeId,
  preparedAt: _t,
  portionsMade: 6,
  portionsRemaining: remaining,
  createdAt: _t,
  updatedAt: _t,
);

/// Delegates to the real log repository and fails inserts on demand.
final class _FailingLog implements FoodLogRepository {
  _FailingLog(this._inner);
  final DriftFoodLogRepository _inner;
  bool fail = false;

  @override
  Future<void> insert(FoodLogEntry entry) {
    if (fail) throw Exception('disk full');
    return _inner.insert(entry);
  }

  @override
  Stream<List<FoodLogEntry>> watchDay(String day) => _inner.watchDay(day);
  @override
  Future<List<FoodLogEntry>> forDays(String fromDay, String toDay) =>
      _inner.forDays(fromDay, toDay);
  @override
  Future<void> insertAll(List<FoodLogEntry> entries) =>
      _inner.insertAll(entries);
  @override
  Future<void> update(FoodLogEntry entry) => _inner.update(entry);
  @override
  Future<void> delete(String id) => _inner.delete(id);
}

void main() {
  late AppDatabase db;
  late DriftRecipeRepository recipes;
  late _FailingLog log;
  late DriftPrepBatchRepository batches;
  late LogRecipe logRecipe;
  final clock = FixedClock(_t);
  var ids = 0;

  setUp(() async {
    db = AppDatabase.inMemory();
    ids = 0;
    recipes = DriftRecipeRepository(db, clock: clock);
    log = _FailingLog(DriftFoodLogRepository(db, clock: clock));
    batches = DriftPrepBatchRepository(db, clock: clock);
    logRecipe = LogRecipe(
      recipes: recipes,
      log: log,
      clock: clock,
      newId: () => 'e${++ids}',
      prepBatches: batches,
    );
    await recipes.upsert(_recipe('r1'));
    await recipes.upsert(_recipe('r2'));
    await batches.upsert(_batch('b1', 'r1', 6));
  });
  tearDown(() => db.close());

  Future<Result<FoodLogEntry>> go({
    double? portions = 1,
    double? grams,
    String? batch = 'b1',
    String recipe = 'r1',
  }) => logRecipe(
    recipeId: recipe,
    meal: MealSlot.dinner,
    day: '2026-11-04',
    portions: portions,
    grams: grams,
    prepBatchId: batch,
  );

  Future<List<FoodLogEntry>> entries() =>
      log.forDays('2026-11-04', '2026-11-04');
  Future<double> remaining() async =>
      (await batches.byId('b1'))!.portionsRemaining;

  test(
    'logging a prepared portion logs and decrements by 1 (RCP-015(2))',
    () async {
      final r = await go();
      expect((r as Ok<FoodLogEntry>).value.nutrients.kcal, closeTo(400, 1e-9));
      expect(await remaining(), 5);
      expect(await entries(), hasLength(1));
    },
  );

  test('partial portions decrement by that amount', () async {
    await go(portions: 1.5);
    expect(await remaining(), 4.5);
  });

  test(
    'more than remains: ValidationError, nothing logged, batch unchanged',
    () async {
      await batches.upsert(_batch('b1', 'r1', 0.5));
      final r = await go();
      final error = (r as Err<FoodLogEntry>).error as ValidationError;
      expect(error.field, prepInsufficientField);
      expect(await entries(), isEmpty);
      expect(await remaining(), 0.5);
    },
  );

  test('logging from an empty batch is refused (cannot go below 0)', () async {
    await batches.upsert(_batch('b1', 'r1', 1));
    expect((await go()).isOk, isTrue);
    expect(await remaining(), 0);
    expect((await go()).isErr, isTrue);
    expect(await remaining(), 0);
    expect(await entries(), hasLength(1));
  });

  test('a failing log insert rolls the decrement back (atomic)', () async {
    log.fail = true;
    final r = await go();
    expect((r as Err<FoodLogEntry>).error, isA<StorageError>());
    expect(await remaining(), 6);
    log.fail = false;
    expect(await entries(), isEmpty);
  });

  test(
    'unknown batch, batch of another recipe, grams: refused cleanly',
    () async {
      expect(
        ((await go(batch: 'zzz')) as Err<FoodLogEntry>).error,
        isA<NotFoundError>(),
      );
      expect((await go(recipe: 'r2')).isErr, isTrue);
      expect((await go(portions: null, grams: 200)).isErr, isTrue);
      expect(await remaining(), 6);
      expect(await entries(), isEmpty);
    },
  );

  test('a recipe with no batch repository refuses a batch', () async {
    final bare = LogRecipe(
      recipes: recipes,
      log: log,
      clock: clock,
      newId: () => 'x',
    );
    final r = await bare(
      recipeId: 'r1',
      meal: MealSlot.dinner,
      day: '2026-11-04',
      portions: 1,
      prepBatchId: 'b1',
    );
    expect(r.isErr, isTrue);
    expect(await entries(), isEmpty);
  });

  test('without prepBatchId nothing about batches changes', () async {
    expect((await go(batch: null)).isOk, isTrue);
    expect(await remaining(), 6);
  });
}
