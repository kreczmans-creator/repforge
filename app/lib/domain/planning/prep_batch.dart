import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';

/// A batch of a recipe prepared in advance (RCP-015): [portionsMade] portions
/// cooked, [portionsRemaining] still available (never below 0).
@immutable
final class PrepBatch {
  const PrepBatch({
    required this.id,
    required this.recipeId,
    required this.preparedAt,
    required this.portionsMade,
    required this.portionsRemaining,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String recipeId;
  final DateTime preparedAt;
  final double portionsMade;
  final double portionsRemaining;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmpty => portionsRemaining <= 0;

  PrepBatch copyWith({double? portionsRemaining, DateTime? updatedAt}) =>
      PrepBatch(
        id: id,
        recipeId: recipeId,
        preparedAt: preparedAt,
        portionsMade: portionsMade,
        portionsRemaining: portionsRemaining ?? this.portionsRemaining,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is PrepBatch &&
      other.id == id &&
      other.recipeId == recipeId &&
      other.preparedAt == preparedAt &&
      other.portionsMade == portionsMade &&
      other.portionsRemaining == portionsRemaining &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    recipeId,
    preparedAt,
    portionsMade,
    portionsRemaining,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'PrepBatch($id, $recipeId, $portionsRemaining/$portionsMade)';
}

/// Outcome of [PrepBatchRepository.consume].
enum ConsumeOutcome { consumed, notFound, insufficient }

abstract interface class PrepBatchRepository {
  /// Live batches with portions remaining, newest first.
  Stream<List<PrepBatch>> watchActive();

  /// Live batches of one recipe (including empty ones), newest first.
  Stream<List<PrepBatch>> watchForRecipe(String recipeId);

  Future<PrepBatch?> byId(String id);

  /// Inserts or replaces. Upserting a soft-deleted id keeps it deleted.
  Future<void> upsert(PrepBatch batch);

  /// Soft delete; idempotent.
  Future<void> delete(String id);

  /// Atomically takes [portions] from the batch (RCP-015(2)). In ONE
  /// transaction: checks the batch has at least [portions] remaining (else
  /// returns [ConsumeOutcome.insufficient] and changes nothing), decrements
  /// it, then runs [alongside] (e.g. inserting the diary entry). If
  /// [alongside] throws, the decrement is rolled back and the error
  /// propagates, so the two happen together or not at all.
  Future<ConsumeOutcome> consume(
    String id,
    double portions, {
    Future<void> Function()? alongside,
  });
}

/// Error field for the typed refusal when a batch has too few portions.
const prepInsufficientField = 'portionsRemaining';

/// Error for [ConsumeOutcome.insufficient] / [ConsumeOutcome.notFound].
AppError consumeError(ConsumeOutcome outcome) => switch (outcome) {
  ConsumeOutcome.notFound => const NotFoundError(
    'That prepared batch no longer exists.',
  ),
  ConsumeOutcome.insufficient => const ValidationError(
    'Not enough portions remaining in this batch.',
    field: prepInsufficientField,
  ),
  ConsumeOutcome.consumed => const UnexpectedError('Nothing to report.'),
};
