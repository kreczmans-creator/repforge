import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/weight_repository.dart';

/// Use case: soft-delete a body-weight entry.
final class DeleteWeightEntry {
  const DeleteWeightEntry({required this._repository});

  final WeightRepository _repository;

  Future<Result<void>> call(String id) async {
    try {
      await _repository.delete(id);
    } on Exception catch (e) {
      return Err(StorageError('Could not delete the entry.', cause: e));
    }
    return const Ok(null);
  }
}
