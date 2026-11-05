import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

/// Clock-skew allowance for "not in the future" (BCM-004(1)): a recorded
/// instant up to one minute ahead of the clock is accepted. Same value the
/// WP 1 weight use case always used.
const Duration futureTolerance = Duration(minutes: 1);

/// Rejects a recorded instant later than [now] plus [futureTolerance]
/// (BCM-004(1)). Compares instants, so it does not depend on the time zone.
ValidationError? checkNotInFuture(DateTime recordedAt, DateTime now) =>
    recordedAt.toUtc().isAfter(now.toUtc().add(futureTolerance))
    ? const ValidationError(
        'The date cannot be in the future.',
        field: 'recordedAt',
      )
    : null;

/// Trims [note]; blank becomes null.
String? normaliseNote(String? note) {
  final t = note?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// Strictly parses typed text for [site] (BCM-001(1), BCM-002(1)): kg for
/// weight, cm otherwise. Out-of-range and off-step input is rejected, never
/// rounded. The error's `field` is the site name.
Result<MeasurementValue> parseMeasurementValue(
  MeasurementSite site,
  String text,
) {
  if (site.isWeight) {
    return switch (Kilograms.parse(text)) {
      Ok(:final value) => Ok(MeasurementValue.kg(value)),
      Err(:final error) => Err(_forSite(site, error)),
    };
  }
  return switch (Centimetres.parse(text)) {
    Ok(:final value) => Ok(MeasurementValue.cm(value)),
    Err(:final error) => Err(_forSite(site, error)),
  };
}

AppError _forSite(MeasurementSite site, AppError e) =>
    ValidationError('${site.label}: ${e.message}', field: site.name);

/// Combines field errors into one [ValidationError] carrying all of them in
/// [ValidationError.fieldErrors]; the first error supplies `message`/`field`.
/// [errors] must not be empty.
ValidationError combineValidationErrors(List<ValidationError> errors) {
  final first = errors.first;
  return ValidationError(
    first.message,
    field: first.field,
    fieldErrors: {
      for (final e in errors)
        if (e.field != null) e.field!: e.message,
    },
  );
}
