import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';
import 'package:repforge/domain/measurements/weight_repository.dart';
import 'package:repforge/domain/units/kilograms.dart';

/// drift-backed [WeightRepository]. Nothing above this class sees a drift row.
final class DriftWeightRepository implements WeightRepository {
  DriftWeightRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  /// Single definition of "visible rows, newest first" used by every read.
  /// Rows outside the accepted weight range are excluded here, in SQL, so a
  /// corrupt row can neither fail the stream nor shadow `latest()`.
  SimpleSelectStatement<$WeightEntriesTable, WeightEntryRow> _visible() =>
      _db.select(_db.weightEntries)
        ..where(
          (t) =>
              t.deletedAt.isNull() &
              t.weightKg.isBetweenValues(Kilograms.min, Kilograms.max),
        )
        ..orderBy([
          (t) => OrderingTerm.desc(t.recordedAt),
          (t) => OrderingTerm.desc(t.createdAt),
        ]);

  @override
  Stream<List<WeightEntry>> watchAll() => _visible().watch().map(_toEntities);

  @override
  Future<WeightEntry?> latest() async {
    final rows = await (_visible()..limit(1)).get();
    return _toEntities(rows).firstOrNull;
  }

  @override
  Future<void> insert(WeightEntry entry) =>
      _db.into(_db.weightEntries).insert(_toRow(entry));

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    final target = _db.update(_db.weightEntries)
      ..where((t) => t.id.equals(id) & t.deletedAt.isNull());
    await target.write(
      WeightEntriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Maps rows leniently as a second line of defence: anything `Kilograms.of`
  /// still rejects (for example NaN) is skipped rather than failing the
  /// stream.
  static List<WeightEntry> _toEntities(List<WeightEntryRow> rows) => [
    for (final row in rows)
      if (Kilograms.of(row.weightKg) case Ok(:final value))
        WeightEntry(
          id: row.id,
          recordedAt: row.recordedAt,
          weight: value,
          note: row.note,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
  ];

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
