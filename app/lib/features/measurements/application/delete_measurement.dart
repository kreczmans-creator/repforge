import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';

/// Use case: soft-delete one measurement of any site (BCM-004), including a
/// stored row that cannot be read as a measurement (listed by
/// `unreadableMeasurementsProvider`). Only that row
/// is marked deleted, so deleting one side of a left/right pair leaves the
/// other untouched (BCM-003).
final class DeleteMeasurement {
  const DeleteMeasurement({required this._repository});

  final MeasurementRepository _repository;

  Future<Result<void>> call(String id) async {
    try {
      if (!await _repository.exists(id)) {
        return const Err(NotFoundError('The measurement no longer exists.'));
      }
      await _repository.delete(id);
    } on Object catch (e) {
      return Err(StorageError('Could not delete the measurement.', cause: e));
    }
    return const Ok(null);
  }
}
