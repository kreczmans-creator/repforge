import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/result.dart';

/// JSON backup of every table (DAT-003, DAT-004). Rows are exported as raw
/// SQL column values, so the backup is a faithful copy independent of domain
/// mapping. Restore replaces all data inside one transaction.
final class DriftBackupRepository implements BackupRepository {
  DriftBackupRepository(this._db);

  final AppDatabase _db;

  /// Bump when the JSON layout changes; a newer file is refused on import.
  static const formatVersion = 1;

  @override
  Future<String> exportJson() async {
    final tables = <String, List<Map<String, Object?>>>{};
    await _db.transaction(() async {
      for (final table in _db.allTables) {
        final name = table.actualTableName;
        final rows = await _db.customSelect('SELECT * FROM "$name"').get();
        tables[name] = [for (final r in rows) Map.of(r.data)];
      }
    });
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'repforge',
      'formatVersion': formatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    });
  }

  @override
  Future<Result<BackupSummary>> importJson(String json) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return const Err(
        ValidationError('Backup is not valid JSON.', field: 'file'),
      );
    }
    if (decoded is! Map<String, Object?> || decoded['app'] != 'repforge') {
      return const Err(
        ValidationError('This file is not a RepForge backup.', field: 'file'),
      );
    }
    final version = decoded['formatVersion'];
    if (version is! int || version > formatVersion) {
      return const Err(
        ValidationError(
          'This backup was made by a newer version of RepForge.',
          field: 'file',
        ),
      );
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, Object?>) {
      return const Err(ValidationError('Backup has no tables.', field: 'file'));
    }
    final byName = {for (final t in _db.allTables) t.actualTableName: t};
    final counts = <String, int>{};
    try {
      await _db.transaction(() async {
        for (final t in _db.allTables.toList().reversed) {
          await _db.delete(t).go();
        }
        for (final entry in tables.entries) {
          final table = byName[entry.key];
          final rows = entry.value;
          if (table == null || rows is! List) continue;
          var n = 0;
          for (final r in rows) {
            if (r is! Map<String, Object?>) continue;
            await _db.into(table).insert(RawValuesInsertable(_toColumns(r)));
            n++;
          }
          counts[entry.key] = n;
        }
      });
    } on Exception catch (e) {
      return Err(
        StorageError('Restore failed; nothing was changed.', cause: e),
      );
    }
    return Ok(BackupSummary(formatVersion: version, rowCounts: counts));
  }

  static Map<String, Expression<Object>> _toColumns(Map<String, Object?> r) => {
    for (final e in r.entries)
      if (e.value case final Object v) e.key: Variable<Object>(v),
    for (final e in r.entries)
      if (e.value == null) e.key: const Constant<Object>(null),
  };
}
