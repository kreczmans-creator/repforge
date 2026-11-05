import 'package:meta/meta.dart';
import 'package:repforge/domain/measurements/measurement_comparison.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// Progress of one site over a period (BCM-008): sealed into [SiteProgress]
/// (at least two readings) and [NotEnoughData].
sealed class ProgressEntry {
  const ProgressEntry(this.site, this.count);
  final MeasurementSite site;

  /// Readings of the site in the period (0 when none).
  final int count;
}

/// First value, latest value and difference over the period.
@immutable
final class SiteProgress extends ProgressEntry {
  const SiteProgress({
    required MeasurementSite site,
    required int count,
    required this.first,
    required this.latest,
    required this.change,
  }) : super(site, count);

  /// Oldest reading in the period.
  final Measurement first;

  /// Newest reading in the period.
  final Measurement latest;

  /// latest − first (absolute and percent of the first value).
  final Change change;
}

/// Fewer than two readings in the period: shown as "not enough data".
@immutable
final class NotEnoughData extends ProgressEntry {
  const NotEnoughData({required MeasurementSite site, required int count})
    : super(site, count);
}

/// Progress for one [site] over the readings in [period] ending on the local
/// date of [now]. First and latest are the oldest and newest readings by
/// instant; the difference needs at least two readings, else [NotEnoughData].
ProgressEntry progressFor(
  Iterable<Measurement> all,
  MeasurementSite site,
  MeasurementPeriod period,
  DateTime now,
) {
  final inPeriod = filterByPeriod(
    all.where((m) => m.site == site),
    period,
    now,
  );
  if (inPeriod.length < 2) {
    return NotEnoughData(site: site, count: inPeriod.length);
  }
  final first = inPeriod.first;
  final latest = inPeriod.last;
  return SiteProgress(
    site: site,
    count: inPeriod.length,
    first: first,
    latest: latest,
    change: changeBetweenReadings(first, latest),
  );
}

/// Progress for every site, in [MeasurementSite] order (weight first). Sites
/// with no readings come back as [NotEnoughData] with count 0 so a screen can
/// hide them or list them as it chooses.
List<ProgressEntry> progressSummary(
  Iterable<Measurement> all,
  MeasurementPeriod period,
  DateTime now,
) {
  final list = all.toList();
  return [
    for (final site in MeasurementSite.values)
      progressFor(list, site, period, now),
  ];
}
