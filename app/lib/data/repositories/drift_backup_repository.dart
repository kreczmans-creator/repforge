import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/db/legacy_training_rows.dart';
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

  /// Bump when the JSON layout or meaning changes; a file with a newer
  /// version than this is refused on import. 2: written with schema v7 data
  /// (set kinds, session exercise entries, scheduled workouts), which an app
  /// that only knows format 1 would silently drop; format 1 files (schema v6
  /// and earlier) are still restored.
  static const formatVersion = 2;

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
    final quarantined = <Map<String, Object?>>[];
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
            final mapped = _fromOlderSchema(
              table.actualTableName,
              r,
              quarantined,
            );
            if (mapped == null) continue;
            await _insertRaw(table.actualTableName, allowed, mapped);
            n++;
          }
          counts[entry.key] = n;
        }
        // A backup made before schema v7 has sets without an exercise entry
        // (and no session_exercises table): give them entries, the same way
        // the migration does. A v7 backup carries its entries and is
        // restored as it is.
        if (!tables.containsKey('session_exercises')) {
          await _db.backfillSessionExercises();
        }
        // Pre-v6 training rows that broke a CHECK constraint: the original
        // is kept here, see LegacyTrainingRows.
        final quarantineColumns = {
          for (final c in byName['legacy_quarantine']!.$columns) c.$name,
        };
        for (final q in quarantined) {
          await _insertRaw('legacy_quarantine', quarantineColumns, q);
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

  /// Maps a row exported by an older schema onto the current columns, so a
  /// backup made before schema v6 restores without losing data.
  ///
  /// Before v5: the single v4 step list (`method_steps_json`) becomes the
  /// cooking steps and the v4 boolean `freezer_friendly` becomes `freezing`
  /// (true is 'yes'; false only ever meant "not stated", so 'unknown').
  ///
  /// Before v6: `exercises.is_custom` becomes `supplied` (its negation) with
  /// taxonomy identifiers, aliases and search key filled in;
  /// `plan_exercises.target_reps` becomes `reps_min` and `reps_max`. A
  /// training row that would break a v6 CHECK constraint is handled like in
  /// the migration (see [LegacyTrainingRows]): a nullable out-of-range value
  /// becomes NULL, a row with an out-of-range required value is not
  /// restored, and in both cases the original is added to [quarantined].
  /// Returns null when the row is not restored.
  static Map<String, Object?>? _fromOlderSchema(
    String table,
    Map<String, Object?> row,
    List<Map<String, Object?>> quarantined,
  ) {
    void quarantine(String reason) {
      quarantined.add({
        'source_table': table,
        'row_id': (row['id'] ?? '').toString(),
        'reason': reason,
        'original_json': jsonEncode(row),
        'quarantined_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    if (table == 'recipes' && row.containsKey('method_steps_json')) {
      final flag = row['freezer_friendly'];
      return {
        ...row,
        'cook_steps_json': row['cook_steps_json'] ?? row['method_steps_json'],
        'freezing':
            row['freezing'] ?? (flag == 1 || flag == true ? 'yes' : 'unknown'),
      };
    }
    if (table == 'exercises' && row.containsKey('is_custom')) {
      final mapped = LegacyTrainingRows.exercise(row);
      if (mapped.quarantineReason case final reason?) quarantine(reason);
      return mapped.row;
    }
    if (table == 'plan_exercises' && row.containsKey('target_reps')) {
      final fixed = LegacyTrainingRows.planExercise(row);
      if (!fixed.unchanged) quarantine(fixed.reason);
      return fixed.row;
    }
    if (table == 'session_sets' && !row.containsKey('energy_kcal')) {
      final fixed = LegacyTrainingRows.sessionSet(row);
      if (!fixed.unchanged) quarantine(fixed.reason);
      return fixed.row;
    }
    return row;
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
