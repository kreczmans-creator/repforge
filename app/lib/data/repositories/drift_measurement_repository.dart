import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/unreadable_measurement.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

/// drift-backed [MeasurementRepository] over the `measurements` table.
final class DriftMeasurementRepository implements MeasurementRepository {
  DriftMeasurementRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  /// Not-deleted rows newest first. Classification into readable and
  /// unreadable happens in Dart (see [toEntity]) so it always agrees with the
  /// strict `tryFromStored` readers; no row is hidden by the query.
  SimpleSelectStatement<$MeasurementsTable, MeasurementRow> _visible({
    MeasurementSite? site,
  }) => _db.select(_db.measurements)
    ..where((t) {
      final base = t.deletedAt.isNull();
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
    return _visible().watch().map((rows) {
      final all = toEntities(rows);
      return limit == null ? all : all.take(limit).toList();
    });
  }

  @override
  Future<Measurement?> latest(MeasurementSite site) async {
    final rows = await _visible(site: site).get();
    return toEntities(rows).firstOrNull;
  }

  @override
  Future<Measurement?> byId(String id) async {
    final rows = await (_visible()..where((t) => t.id.equals(id))).get();
    return toEntities(rows).firstOrNull;
  }

  @override
  Future<bool> exists(String id) async =>
      (await (_visible()..where((t) => t.id.equals(id))).get()).isNotEmpty;

  @override
  Stream<List<UnreadableMeasurement>> watchUnreadable() =>
      _visible().watch().map(
        (rows) => [
          for (final row in rows)
            if (toEntity(row) == null)
              UnreadableMeasurement(
                id: row.id,
                site: row.site,
                rawValue: row.value,
                recordedAt: row.recordedAt.toUtc(),
              ),
        ],
      );

  @override
  Future<void> insert(Measurement m) =>
      _db.into(_db.measurements).insert(toRow(m));

  @override
  Future<void> insertAll(List<Measurement> items) => _db.transaction(() async {
    for (final m in items) {
      await _db.into(_db.measurements).insert(toRow(m));
    }
  });

  @override
  Future<int> update(Measurement m) {
    final now = _clock.now().toUtc();
    final target = _db.update(_db.measurements)
      ..where((t) => t.id.equals(m.id) & t.deletedAt.isNull());
    return target.write(
      MeasurementsCompanion(
        site: Value(m.site.name),
        value: Value(m.value.raw),
        recordedAt: Value(m.recordedAt.toUtc()),
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

  /// Mapping: rows with an unknown site or a stored value that fails the
  /// strict rule (range, 0.1 step, 1e-9 float noise only) are left out of the
  /// readable list rather than failing the stream and are reported by
  /// [watchUnreadable] with their raw value; stored values are never snapped
  /// or corrected (owner rule on legacy values). Instants
  /// are written and returned as UTC (drift reads text dates back as local
  /// `DateTime`s of the same instant); calendar logic converts to local in the
  /// domain.
  static List<Measurement> toEntities(List<MeasurementRow> rows) => [
    for (final row in rows) ?toEntity(row),
  ];

  static Measurement? toEntity(MeasurementRow row) {
    final site = MeasurementSite.values.asNameMap()[row.site];
    if (site == null) return null;
    final MeasurementValue? value;
    if (site.isWeight) {
      final kg = Kilograms.tryFromStored(row.value);
      value = kg == null ? null : MeasurementValue.kg(kg);
    } else {
      final cm = Centimetres.tryFromStored(row.value);
      value = cm == null ? null : MeasurementValue.cm(cm);
    }
    if (value == null) return null;
    return Measurement(
      id: row.id,
      site: site,
      value: value,
      recordedAt: row.recordedAt.toUtc(),
      note: row.note,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  static MeasurementsCompanion toRow(Measurement m) =>
      MeasurementsCompanion.insert(
        id: m.id,
        site: m.site.name,
        value: m.value.raw,
        recordedAt: m.recordedAt.toUtc(),
        note: Value(m.note),
        createdAt: m.createdAt.toUtc(),
        updatedAt: m.updatedAt.toUtc(),
      );
}
