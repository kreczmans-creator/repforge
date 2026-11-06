import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/measurement_rules.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// Use case: edit one measurement's value, date/time and note (BCM-004).
///
/// Same rules as recording: strict value validation for the measurement's
/// own site, no future instant (against the injected clock), note trimmed.
/// The site cannot be changed, and no other row is touched (so editing one
/// side never alters the other, BCM-003). `recordedAt` and `note` replace the
/// stored values (a null/blank note clears it).
final class UpdateMeasurement {
  const UpdateMeasurement({required this._repository, required this._clock});

  final MeasurementRepository _repository;
  final Clock _clock;

  Future<Result<Measurement>> call({
    required String id,
    required String valueText,
    required DateTime recordedAt,
    required String? note,
  }) async {
    try {
      final existing = await _repository.byId(id);
      if (existing == null) {
        return const Err(NotFoundError('The measurement no longer exists.'));
      }
      final value = parseMeasurementValue(existing.site, valueText);
      final now = _clock.now().toUtc();
      final when = recordedAt.toUtc();
      final future = checkNotInFuture(when, now);
      final errors = [
        if (value case Err(:final error)) error as ValidationError,
        ?future,
      ];
      if (errors.isNotEmpty) return Err(combineValidationErrors(errors));

      final updated = existing.copyWith(
        value: (value as Ok<MeasurementValue>).value,
        recordedAt: when,
        note: normaliseNote(note),
        updatedAt: now,
      );
      final changed = await _repository.update(updated);
      if (changed == 0) {
        // Deleted between the read and the write.
        return const Err(NotFoundError('The measurement no longer exists.'));
      }
      return Ok(updated);
    } on Object catch (e) {
      return Err(StorageError('Could not save the measurement.', cause: e));
    }
  }
}
