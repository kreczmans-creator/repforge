import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurement_rules.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';
import 'package:repforge/domain/measurements/weight_repository.dart';
import 'package:repforge/domain/units/kilograms.dart';

/// Use case: validate and persist a body-weight entry (BCM-001).
///
/// Rules enforced here, not in the UI:
/// - weight must parse and lie within [Kilograms.min]..[Kilograms.max];
/// - the recorded time may not be in the future (shared rule
///   `checkNotInFuture`, one minute of clock-skew tolerance);
/// - the note is trimmed; an empty note is stored as null.
final class RecordBodyWeight {
  const RecordBodyWeight({
    required this._repository,
    required this._clock,
    required this._newId,
  });

  final WeightRepository _repository;
  final Clock _clock;
  final IdGenerator _newId;

  Future<Result<WeightEntry>> call({
    required String weightText,
    DateTime? recordedAt,
    String? note,
  }) async {
    final now = _clock.now().toUtc();
    final weight = Kilograms.parse(weightText);
    if (weight case Err(:final error)) {
      return Err(error);
    }
    final when = (recordedAt ?? now).toUtc();
    final future = checkNotInFuture(when, now);
    if (future != null) return Err(future);
    final entry = WeightEntry(
      id: _newId(),
      recordedAt: when,
      weight: (weight as Ok<Kilograms>).value,
      note: normaliseNote(note),
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _repository.insert(entry);
    } on Exception catch (e) {
      return Err(StorageError('Could not save the weight entry.', cause: e));
    }
    return Ok(entry);
  }
}
