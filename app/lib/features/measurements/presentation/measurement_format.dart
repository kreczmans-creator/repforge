import 'package:intl/intl.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurement_comparison.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// The typographic minus sign (U+2212) used for negative changes.
const String minusSign = '−';

/// Local date and time of an instant, e.g. "Nov 5, 2026 14:30".
String formatWhen(DateTime instant) =>
    DateFormat.yMMMd().add_Hm().format(instant.toLocal());

/// Local date of an instant, e.g. "Nov 5, 2026".
String formatDay(DateTime instant) =>
    DateFormat.yMMMd().format(instant.toLocal());

/// A calendar date, e.g. "Nov 5, 2026".
String formatCalendarDate(CalendarDate d) =>
    DateFormat.yMMMd().format(DateTime(d.year, d.month, d.day));

/// A reading's value with its unit, e.g. "87.5 cm".
String formatReading(Measurement m) => m.value.label;

/// "+2.5", "−2.5" or "0.0" to one decimal.
String formatSigned(double v) {
  final text = v.abs().toStringAsFixed(1);
  if (v > 0) return '+$text';
  if (v < 0) return '$minusSign$text';
  return text;
}

/// The absolute change with unit: "−2.5 cm".
String formatAbsoluteChange(Change c) =>
    '${formatSigned(c.absolute)} ${c.unit}';

/// The percentage change: "−2.8 %", or null when undefined.
String? formatPercentChange(Change c) =>
    c.percent == null ? null : '${formatSigned(c.percent!)} %';

/// Spoken form of a change for a screen reader.
String spokenChange(Change c) {
  String words(double v, String unit) => v == 0
      ? '0.0 $unit'
      : '${v < 0 ? 'minus' : 'plus'} ${v.abs().toStringAsFixed(1)} $unit';
  final unit = c.unit == 'kg' ? 'kilograms' : 'centimetres';
  final pct = c.percent == null ? '' : ', ${words(c.percent!, 'percent')}';
  return 'Change ${words(c.absolute, unit)}$pct';
}
