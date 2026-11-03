import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';
import 'package:repforge/domain/measurements/weight_repository.dart';
import 'package:repforge/domain/units/kilograms.dart';

/// Generates record identifiers. Injected so tests can be deterministic.
typedef IdGenerator = String Function();

/// Use case: validate and persist a body-weight entry (BCM-001).
///
/// Rules enforced here, not in the UI:
/// - weight must parse and lie within [Kilograms.min]..[Kilograms.max];
/// - the recorded time may not be in the future (more than one minute ahead of
///   the clock, to tolerate clock skew);
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
    if (when.isAfter(now.add(const Duration(minutes: 1)))) {
      return const Err(
        ValidationError(
          'The date cannot be in the future.',
          field: 'recordedAt',
        ),
      );
    }
    final trimmedNote = note?.trim();
    final entry = WeightEntry(
      id: _newId(),
      recordedAt: when,
      weight: (weight as Ok<Kilograms>).value,
      note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
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
