import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';
import 'package:repforge/domain/measurements/weight_repository.dart';
import 'package:repforge/domain/units/kilograms.dart';

/// drift-backed [WeightRepository]. Nothing above this class sees a drift row.
final class DriftWeightRepository implements WeightRepository {
  DriftWeightRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<WeightEntry>> watchAll() {
    final query = _db.select(_db.weightEntries)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.recordedAt),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<WeightEntry?> latest() async {
    final query = _db.select(_db.weightEntries)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.recordedAt),
        (t) => OrderingTerm.desc(t.createdAt),
      ])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> insert(WeightEntry entry) =>
      _db.into(_db.weightEntries).insert(_toRow(entry));

  @override
  Future<void> delete(String id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.weightEntries)..where((t) => t.id.equals(id))).write(
      WeightEntriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  static WeightEntry _toEntity(WeightEntryRow row) => WeightEntry(
    id: row.id,
    recordedAt: row.recordedAt,
    weight: Kilograms.fromStored(row.weightKg),
    note: row.note,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  static WeightEntriesCompanion _toRow(WeightEntry e) =>
      WeightEntriesCompanion.insert(
        id: e.id,
        recordedAt: e.recordedAt,
        weightKg: e.weight.value,
        note: Value(e.note),
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );
}
