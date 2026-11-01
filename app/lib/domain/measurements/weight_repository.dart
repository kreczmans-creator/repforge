import 'package:repforge/domain/measurements/weight_entry.dart';

/// Persistence boundary for body-weight entries.
///
/// Implemented by the data layer; the application layer depends only on this
/// interface. Deleted rows are never returned.
abstract interface class WeightRepository {
  /// Live list ordered by [WeightEntry.recordedAt] descending.
  Stream<List<WeightEntry>> watchAll();

  /// The most recent entry, or null when none exist.
  Future<WeightEntry?> latest();

  Future<void> insert(WeightEntry entry);

  /// Soft-deletes the entry with [id]. No-op when absent.
  Future<void> delete(String id);
}
