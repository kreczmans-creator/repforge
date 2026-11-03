import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

/// drift-backed [MeasurementRepository] over the `measurements` table.
final class DriftMeasurementRepository implements MeasurementRepository {
  DriftMeasurementRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  /// Visible rows newest first. The valid value range is applied in SQL so
  /// a corrupt row can neither fail the stream nor shadow `latest()`.
  SimpleSelectStatement<$MeasurementsTable, MeasurementRow> _visible({
    MeasurementSite? site,
  }) => _db.select(_db.measurements)
    ..where((t) {
      final isWeight = t.site.equals(MeasurementSite.weight.name);
      final inRange =
          (isWeight & t.value.isBetweenValues(Kilograms.min, Kilograms.max)) |
          (isWeight.not() &
              t.value.isBetweenValues(Centimetres.min, Centimetres.max));
      final base = t.deletedAt.isNull() & inRange;
      return site == null ? base : base & t.site.equals(site.name);
    })
    ..orderBy([
      (t) => OrderingTerm.desc(t.recordedAt),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);

  @override
  Stream<List<Measurement>> watchSite(MeasurementSite site) =>
      _visible(site: site).watch().map(toEntities);

  @override
  Stream<List<Measurement>> watchAll({int? limit}) {
    final q = _visible();
    if (limit != null) q.limit(limit);
    return q.watch().map(toEntities);
  }

  @override
  Future<Measurement?> latest(MeasurementSite site) async {
    final rows = await (_visible(site: site)..limit(1)).get();
    return toEntities(rows).firstOrNull;
  }

  @override
  Future<void> insert(Measurement m) =>
      _db.into(_db.measurements).insert(toRow(m));

  @override
  Future<void> update(Measurement m) async {
    final now = _clock.now().toUtc();
    final target = _db.update(_db.measurements)
      ..where((t) => t.id.equals(m.id) & t.deletedAt.isNull());
    await target.write(
      MeasurementsCompanion(
        site: Value(m.site.name),
        value: Value(m.value.raw),
        recordedAt: Value(m.recordedAt),
        note: Value(m.note),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    final target = _db.update(_db.measurements)
      ..where((t) => t.id.equals(id) & t.deletedAt.isNull());
    await target.write(
      MeasurementsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Lenient mapping: rows with an unknown site or out-of-range value are
  /// skipped rather than failing the stream.
  static List<Measurement> toEntities(List<MeasurementRow> rows) => [
    for (final row in rows) ?toEntity(row),
  ];

  static Measurement? toEntity(MeasurementRow row) {
    final site = MeasurementSite.values.asNameMap()[row.site];
    if (site == null) return null;
    final value = site.isWeight
        ? switch (Kilograms.of(row.value)) {
            Ok(:final value) => MeasurementValue.kg(value),
            Err() => null,
          }
        : switch (Centimetres.of(row.value)) {
            Ok(:final value) => MeasurementValue.cm(value),
            Err() => null,
          };
    if (value == null) return null;
    return Measurement(
      id: row.id,
      site: site,
      value: value,
      recordedAt: row.recordedAt,
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static MeasurementsCompanion toRow(Measurement m) =>
      MeasurementsCompanion.insert(
        id: m.id,
        site: m.site.name,
        value: m.value.raw,
        recordedAt: m.recordedAt,
        note: Value(m.note),
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
      );
}
