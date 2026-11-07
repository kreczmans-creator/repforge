import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/unreadable_measurement.dart';

abstract interface class MeasurementRepository {
  /// Newest first for one site.
  Stream<List<Measurement>> watchSite(MeasurementSite site);

  /// Every site, newest first, optionally limited.
  Stream<List<Measurement>> watchAll({int? limit});
  Future<Measurement?> latest(MeasurementSite site);

  /// Readable, not-deleted readings recorded in `[from, to)`, oldest first,
  /// optionally of one [site] only. A bounded read for the analytics
  /// (WP 11): it loads only the period's rows. Unreadable rows are left out
  /// as everywhere else.
  Future<List<Measurement>> readingsBetween(
    DateTime from,
    DateTime to, {
    MeasurementSite? site,
  });

  /// A visible (not deleted), readable measurement by id, or null.
  Future<Measurement?> byId(String id);

  /// Whether a not-deleted row with [id] exists, readable or not.
  Future<bool> exists(String id);

  /// Stored not-deleted rows that cannot be read as a [Measurement] (unknown
  /// site or value out of range), newest first. They stay in the database
  /// untouched and are excluded from history, charts and CSV; the caller
  /// reports them and may delete them by id.
  Stream<List<UnreadableMeasurement>> watchUnreadable();

  /// Persists [m]. `recordedAt` is normalised to UTC by the implementation.
  Future<void> insert(Measurement m);

  /// Persists all of [items] atomically: all rows are kept or none.
  Future<void> insertAll(List<Measurement> items);

  /// Writes the editable fields of a visible row; returns the number of rows
  /// changed (0 when the row is missing or was deleted meanwhile).
  Future<int> update(Measurement m);
  Future<void> delete(String id);
}
