import 'package:repforge/domain/core/calendar_date.dart';
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
        'The date and time cannot be in the future.',
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
/// rounded. The error's `field` is the site name and its message does not
/// repeat the site's label (review N3).
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

/// Keeps the message as is (it does not repeat the site name: a form shows it
/// next to the labelled field) and sets the field to the site name.
AppError _forSite(MeasurementSite site, AppError e) =>
    ValidationError(e.message, field: site.name);

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

/// Default local date and time of a new entry for [date] (BCM-004(1)): the
/// current time (to the minute) when [date] is today, otherwise 12:00 local on
/// that date. Never later than [now]: a future [date] falls back to [now].
DateTime defaultRecordedAt(CalendarDate date, DateTime now) {
  final local = now.toLocal();
  final today = CalendarDate.fromInstant(local);
  if (date.compareTo(today) >= 0) {
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }
  return DateTime(date.year, date.month, date.day, 12);
}
