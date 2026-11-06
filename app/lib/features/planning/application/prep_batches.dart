import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/domain/recipes/recipe_repository.dart';
import 'package:repforge/domain/units/units.dart';

/// Use case: record a batch of a recipe as prepared (RCP-015(1)). The new
/// batch has all `portionsMade` portions remaining.
final class RecordPrepBatch {
  const RecordPrepBatch({
    required this.batches,
    required this.recipes,
    required this.clock,
    required this.newId,
  });

  final PrepBatchRepository batches;
  final RecipeRepository recipes;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<PrepBatch>> call({
    required String recipeId,
    required double portionsMade,
    DateTime? preparedAt,
  }) async {
    final q = Quantity.of(portionsMade, ReferenceUnit.portions);
    if (q case Err(:final error)) return Err(error);
    final made = (q as Ok<Quantity>).value.amount;
    if (made <= 0) {
      return const Err(
        ValidationError(
          'Enter the number of portions made.',
          field: 'portionsMade',
        ),
      );
    }
    try {
      if (await recipes.byId(recipeId) == null) {
        return const Err(NotFoundError('That recipe no longer exists.'));
      }
      final now = clock.now().toUtc();
      final batch = PrepBatch(
        id: newId(),
        recipeId: recipeId,
        preparedAt: (preparedAt ?? now).toUtc(),
        portionsMade: made,
        portionsRemaining: made,
        createdAt: now,
        updatedAt: now,
      );
      await batches.upsert(batch);
      return Ok(batch);
    } on Exception catch (e) {
      return Err(StorageError('Could not record the batch.', cause: e));
    }
  }
}

/// Use case: take `portions` from a batch without logging (RCP-015(2)). The
/// count never goes below 0: asking for more than remains is refused with a
/// `ValidationError` and changes nothing.
/// To take a portion AND log it, use `LogRecipe` with `prepBatchId`.
final class ConsumePrepPortion {
  const ConsumePrepPortion({required this.batches});

  final PrepBatchRepository batches;

  Future<Result<PrepBatch>> call(String batchId, double portions) async {
    final q = Quantity.of(portions, ReferenceUnit.portions);
    if (q case Err(:final error)) return Err(error);
    final amount = (q as Ok<Quantity>).value.amount;
    if (amount <= 0) {
      return const Err(
        ValidationError('Enter a portion count above zero.', field: 'portions'),
      );
    }
    try {
      final outcome = await batches.consume(batchId, amount);
      if (outcome != ConsumeOutcome.consumed) return Err(consumeError(outcome));
      final batch = await batches.byId(batchId);
      return batch == null
          ? const Err(NotFoundError('That prepared batch no longer exists.'))
          : Ok(batch);
    } on Exception catch (e) {
      return Err(StorageError('Could not update the batch.', cause: e));
    }
  }
}

/// Use case: delete a prepared batch.
final class DeletePrepBatch {
  const DeletePrepBatch({required this.batches});

  final PrepBatchRepository batches;

  Future<Result<void>> call(String id) async {
    try {
      await batches.delete(id);
    } on Exception catch (e) {
      return Err(StorageError('Could not delete the batch.', cause: e));
    }
    return const Ok(null);
  }
}
