import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// Header row of the measurement export (BCM-009, owner-approved D5).
const String measurementsCsvHeader = 'date,type,value,unit';

/// Builds the measurement CSV (BCM-009(1)); owner-approved D5.
///
/// - Columns `date,type,value,unit`; one row per reading (weight and every
///   circumference site; deleted readings are not passed in).
/// - `date`: the instant as ISO 8601 local date-time with the UTC offset of
///   the device zone at that instant, whole seconds, e.g.
///   `2026-11-05T14:30:00+13:00`.
/// - `type`: the site label ("Weight", "Left thigh", ...); `value`: one
///   decimal; `unit`: `kg` or `cm`.
/// - Rows are **oldest first** (spreadsheet-friendly chronological order);
///   ties by creation time, then id.
/// - RFC 4180: fields containing a comma, double quote or line break are
///   quoted with quotes doubled; records end with CRLF (also the last one).
/// - Returned as text; the caller encodes it as UTF-8 (no byte order mark;
///   the content is ASCII for the current labels).
String buildMeasurementsCsv(Iterable<Measurement> readings) {
  final rows = readings.toList()..sort(compareOldestFirst);
  final out = StringBuffer()
    ..write(measurementsCsvHeader)
    ..write('\r\n');
  for (final m in rows) {
    out
      ..write(
        [
          formatLocalIsoWithOffset(m.recordedAt),
          m.site.label,
          m.value.raw.toStringAsFixed(1),
          m.site.unit,
        ].map(csvField).join(','),
      )
      ..write('\r\n');
  }
  return out.toString();
}

/// RFC 4180 field: quoted when it contains `,`, `"`, CR or LF.
String csvField(String value) {
  if (!value.contains(RegExp('[",\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// `2026-11-05T14:30:00+13:00` for [instant] in the device's local zone.
String formatLocalIsoWithOffset(DateTime instant) {
  final l = instant.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final offset = l.timeZoneOffset;
  final minutes = offset.inMinutes.abs();
  final sign = offset.isNegative ? '-' : '+';
  return '${l.year.toString().padLeft(4, '0')}-${two(l.month)}-${two(l.day)}'
      'T${two(l.hour)}:${two(l.minute)}:${two(l.second)}'
      '$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}
