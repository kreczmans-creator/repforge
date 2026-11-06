import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/measurement_rules.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// Use case: record one measurement entry covering any subset of the 13 sites
/// (BCM-001..004).
///
/// - `values` maps a site to the typed text. Blank text means "not measured":
///   such sites write nothing (an absent value is never stored as 0).
/// - At least one non-blank value is required.
/// - Every provided value is validated strictly for its site (kg 20.0–500.0 /
///   cm 10.0–300.0, 0.1 steps; off-step input is rejected, never rounded).
///   Nothing is written unless every value is valid. All bad fields are
///   reported together in `ValidationError.fieldErrors` (site name or
///   `recordedAt` to message).
/// - One row is written per provided site, all with the same `recordedAt`;
///   the rows are inserted atomically. Left and right sites are independent
///   rows (BCM-003).
/// - `recordedAt` defaults to the clock's now; an instant later than now plus
///   `futureTolerance` is rejected (BCM-004(1)). Stored as UTC.
/// - The note is trimmed (blank → none) and applied to every row of the entry.
final class RecordMeasurementEntry {
  const RecordMeasurementEntry({
    required this._repository,
    required this._clock,
    required this._newId,
  });

  final MeasurementRepository _repository;
  final Clock _clock;
  final IdGenerator _newId;

  Future<Result<List<Measurement>>> call({
    required Map<MeasurementSite, String> values,
    DateTime? recordedAt,
    String? note,
  }) async {
    final now = _clock.now().toUtc();
    final when = (recordedAt ?? now).toUtc();
    final provided = [
      for (final site in MeasurementSite.values)
        if ((values[site] ?? '').trim().isNotEmpty) site,
    ];
    if (provided.isEmpty) {
      return const Err(
        ValidationError('Enter at least one measurement.', field: 'values'),
      );
    }
    final parsed = <MeasurementSite, MeasurementValue>{};
    final errors = <ValidationError>[];
    for (final site in provided) {
      switch (parseMeasurementValue(site, values[site]!)) {
        case Ok(:final value):
          parsed[site] = value;
        case Err(:final error):
          errors.add(error as ValidationError);
      }
    }
    final future = checkNotInFuture(when, now);
    if (future != null) errors.add(future);
    if (errors.isNotEmpty) return Err(combineValidationErrors(errors));

    final cleanNote = normaliseNote(note);
    final entries = [
      for (final site in provided)
        Measurement(
          id: _newId(),
          site: site,
          value: parsed[site]!,
          recordedAt: when,
          note: cleanNote,
          createdAt: now,
          updatedAt: now,
        ),
    ];
    try {
      await _repository.insertAll(entries);
    } on Object catch (e) {
      return Err(StorageError('Could not save the measurements.', cause: e));
    }
    return Ok(entries);
  }
}
