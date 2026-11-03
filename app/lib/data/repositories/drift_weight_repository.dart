import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_measurement_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';
import 'package:repforge/domain/measurements/weight_repository.dart';

/// [WeightRepository] implemented as the `weight` site of the measurements
/// table (schema v2). Keeps the WP 1 body-weight feature working unchanged.
final class DriftWeightRepository implements WeightRepository {
  DriftWeightRepository(AppDatabase db, {required Clock clock})
    : _measurements = DriftMeasurementRepository(db, clock: clock);

  final MeasurementRepository _measurements;

  @override
  Stream<List<WeightEntry>> watchAll() => _measurements
      .watchSite(MeasurementSite.weight)
      .map((list) => list.map(_toEntry).whereType<WeightEntry>().toList());

  @override
  Future<WeightEntry?> latest() async {
    final m = await _measurements.latest(MeasurementSite.weight);
    return m == null ? null : _toEntry(m);
  }

  @override
  Future<void> insert(WeightEntry entry) => _measurements.insert(
    Measurement(
      id: entry.id,
      site: MeasurementSite.weight,
      value: MeasurementValue.kg(entry.weight),
      recordedAt: entry.recordedAt,
      note: entry.note,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    ),
  );

  @override
  Future<void> delete(String id) => _measurements.delete(id);

  static WeightEntry? _toEntry(Measurement m) => switch (m.value) {
    WeightValue(:final kg) => WeightEntry(
      id: m.id,
      recordedAt: m.recordedAt,
      weight: kg,
      note: m.note,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    ),
    LengthValue() => null,
  };
}
