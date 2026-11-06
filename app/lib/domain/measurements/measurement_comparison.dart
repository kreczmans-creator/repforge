import 'package:meta/meta.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// Rounds half away from zero to one decimal, ignoring floating-point noise
/// below 1e-9 (so 0.05 → 0.1 and -0.05 → -0.1).
double roundToTenth(double v) {
  final nudged = v * 10 + (v >= 0 ? 1e-9 : -1e-9);
  return nudged.roundToDouble() / 10 + 0.0; // +0.0 maps -0.0 to 0
}

/// Change from an earlier value to a later one (BCM-007, BCM-008).
///
/// [absolute] = later − earlier and [percent] = (later − earlier) / earlier ×
/// 100, **relative to the earlier value**, each rounded half away from zero to
/// 0.1. Waist 90.0 → 87.5 gives −2.5 cm and −2.8 % (D04 BCM-007(1)).
/// [percent] is null when the earlier value is 0 (cannot occur for valid
/// measurements).
@immutable
final class Change {
  const Change._({
    required this.earlier,
    required this.later,
    required this.absolute,
    required this.percent,
    required this.unit,
  });

  factory Change.between(double earlier, double later, {required String unit}) {
    final diff = later - earlier;
    return Change._(
      earlier: earlier,
      later: later,
      absolute: roundToTenth(diff),
      percent: earlier == 0 ? null : roundToTenth(diff / earlier * 100),
      unit: unit,
    );
  }

  final double earlier;
  final double later;

  /// Later minus earlier, to 0.1 of [unit].
  final double absolute;

  /// Percentage of the earlier value, to 0.1; null if the earlier is 0.
  final double? percent;
  final String unit;

  @override
  bool operator ==(Object other) =>
      other is Change &&
      other.earlier == earlier &&
      other.later == later &&
      other.absolute == absolute &&
      other.percent == percent &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(earlier, later, absolute, percent, unit);

  @override
  String toString() => 'Change($absolute $unit, $percent %)';
}

/// Change between two chosen readings; [earlier] is the base. Use this for
/// readings the user picked, including nearest-entry substitutes.
Change changeBetweenReadings(Measurement earlier, Measurement later) =>
    Change.between(earlier.value.raw, later.value.raw, unit: earlier.site.unit);

/// Outcome of looking up one requested calendar date (BCM-007(2), owner
/// decision D4): an exact reading, a choice the user must make, or no data.
sealed class DateOutcome {
  const DateOutcome(this.requested);
  final CalendarDate requested;
}

/// The date has a reading. With several that day, the **latest** that day.
final class ExactReading extends DateOutcome {
  const ExactReading(super.requested, this.reading);
  final Measurement reading;
}

/// The date has no reading but others exist: both neighbours are returned
/// with their actual dates (`recordedAt`) and **neither is substituted**. The
/// caller must let the user choose, then call [changeBetweenReadings].
/// [before] is the latest reading on the nearest earlier date that has one;
/// [after] the earliest reading on the nearest later date that has one. Each
/// may be null, never both.
final class NeedsChoice extends DateOutcome {
  const NeedsChoice(super.requested, {this.before, this.after});
  final Measurement? before;
  final Measurement? after;
}

/// The site has no readings at all.
final class NoData extends DateOutcome {
  const NoData(super.requested);
}

/// Looks up [date] among the readings of one site (see [DateOutcome]).
DateOutcome pickForDate(Iterable<Measurement> siteReadings, CalendarDate date) {
  final sorted = siteReadings.toList()..sort(compareOldestFirst);
  Measurement? onDate;
  Measurement? before;
  Measurement? after;
  for (final m in sorted) {
    final c = CalendarDate.fromInstant(m.recordedAt).compareTo(date);
    if (c == 0) {
      onDate = m; // oldest first, so the last one wins: latest that day
    } else if (c < 0) {
      before = m; // keeps the latest reading of the nearest earlier date
    } else {
      after ??= m; // first is the earliest reading of the nearest later date
    }
  }
  if (onDate != null) return ExactReading(date, onDate);
  if (before == null && after == null) return NoData(date);
  return NeedsChoice(date, before: before, after: after);
}

/// Comparison of one site between two calendar dates.
@immutable
final class DateComparison {
  const DateComparison({
    required this.site,
    required this.earlier,
    required this.later,
    required this.change,
  });

  final MeasurementSite site;

  /// Outcome for the earlier requested date (the base of the change).
  final DateOutcome earlier;
  final DateOutcome later;

  /// Computed only when both dates have an exact reading. Otherwise null:
  /// the caller makes the user choose among [NeedsChoice] readings and then
  /// uses [changeBetweenReadings]; nothing is substituted silently.
  final Change? change;
}

/// Compares [site] between two calendar dates. The earlier date (whichever
/// argument it is) is the base of the change. [all] may hold other sites.
DateComparison compareDates(
  Iterable<Measurement> all,
  MeasurementSite site,
  CalendarDate a,
  CalendarDate b,
) {
  final readings = readingsOf(all, site);
  final firstDate = a.compareTo(b) <= 0 ? a : b;
  final secondDate = a.compareTo(b) <= 0 ? b : a;
  final first = pickForDate(readings, firstDate);
  final second = pickForDate(readings, secondDate);
  return DateComparison(
    site: site,
    earlier: first,
    later: second,
    change: switch ((first, second)) {
      (ExactReading(reading: final x), ExactReading(reading: final y)) =>
        changeBetweenReadings(x, y),
      _ => null,
    },
  );
}

/// Statistics of one site over one period (owner-approved D4: the mean of the
/// readings in the period, with the count).
@immutable
final class PeriodStats {
  const PeriodStats({required this.range, required this.count, this.mean});

  final DateRange range;

  /// Number of readings in the range (all of them, several per day included).
  final int count;

  /// Arithmetic mean of the readings, rounded to 0.1; null when [count] is 0.
  final double? mean;
}

/// Comparison of one site between two periods.
@immutable
final class PeriodComparison {
  const PeriodComparison({
    required this.site,
    required this.earlier,
    required this.later,
    required this.change,
  });

  final MeasurementSite site;
  final PeriodStats earlier;
  final PeriodStats later;

  /// Change of the rounded means; null unless both periods have readings.
  final Change? change;
}

/// Mean and count of [site] over [range].
PeriodStats periodStats(
  Iterable<Measurement> all,
  MeasurementSite site,
  DateRange range,
) {
  final readings = readingsOf(all, site, range: range);
  if (readings.isEmpty) return PeriodStats(range: range, count: 0);
  final sum = readings.fold<double>(0, (s, m) => s + m.value.raw);
  return PeriodStats(
    range: range,
    count: readings.length,
    mean: roundToTenth(sum / readings.length),
  );
}

/// Compares [site] between two periods (owner-approved D4). The period that
/// starts earlier is the base. The change uses the displayed (rounded) means
/// so the numbers shown add up.
PeriodComparison comparePeriods(
  Iterable<Measurement> all,
  MeasurementSite site,
  DateRange a,
  DateRange b,
) {
  final ordered = a.start.compareTo(b.start) <= 0 ? [a, b] : [b, a];
  final first = periodStats(all, site, ordered[0]);
  final second = periodStats(all, site, ordered[1]);
  return PeriodComparison(
    site: site,
    earlier: first,
    later: second,
    change: first.mean != null && second.mean != null
        ? Change.between(first.mean!, second.mean!, unit: site.unit)
        : null,
  );
}
