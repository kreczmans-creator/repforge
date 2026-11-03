import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';

/// JSON backup of every table (DAT-003, DAT-004). Rows are exported as raw
/// SQL column values and restored with raw SQL inserts, so the backup is a
/// faithful copy independent of domain mapping. Restore replaces all data
/// inside one transaction; any failure rolls back and is returned as an
/// [AppError], never thrown.
final class DriftBackupRepository implements BackupRepository {
  DriftBackupRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

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
      'exportedAt': _clock.now().toUtc().toIso8601String(),
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
          final allowed = {for (final c in table.$columns) c.$name};
          var n = 0;
          for (final r in rows) {
            if (r is! Map<String, Object?>) continue;
            await _insertRaw(table.actualTableName, allowed, r);
            n++;
          }
          counts[entry.key] = n;
        }
      });
    } on Object catch (e) {
      // Errors (not only Exceptions) are possible here: sqlite3 binding
      // rejects nested values with ArgumentError. All of them mean "bad
      // backup"; the transaction has rolled back.
      return Err(
        StorageError('Restore failed; nothing was changed.', cause: e),
      );
    }
    return Ok(BackupSummary(formatVersion: version, rowCounts: counts));
  }

  Future<void> _insertRaw(
    String table,
    Set<String> allowed,
    Map<String, Object?> row,
  ) async {
    final cols = [
      for (final k in row.keys)
        if (allowed.contains(k)) k,
    ];
    if (cols.isEmpty) {
      throw const FormatException('Row has no known columns.');
    }
    final placeholders = List.filled(cols.length, '?').join(', ');
    final names = cols.map((c) => '"$c"').join(', ');
    await _db.customInsert(
      'INSERT INTO "$table" ($names) VALUES ($placeholders)',
      variables: [
        for (final c in cols)
          switch (row[c]) {
            null => const Variable<Object>(null),
            final num v => Variable<num>(v),
            final String v => Variable<String>(v),
            final bool v => Variable<bool>(v),
            final other => throw ArgumentError(
              'Unsupported value ${other.runtimeType} in $table.$c',
            ),
          },
      ],
    );
  }
}
