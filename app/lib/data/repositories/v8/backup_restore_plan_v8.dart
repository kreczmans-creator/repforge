import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:repforge/data/db/migration/legacy_training_rows_v6.dart';
import 'package:repforge/data/db/migration/v7_to_v8.dart' show V7ToV8Migration;
import 'package:repforge/data/repositories/v8/backup_schema_v8.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/legacy_v8_mapping.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/sha256_hex.dart';
import 'package:repforge/domain/training/training.dart'
    show ExerciseCategory, ExerciseType;

/// Phase 1a of a restore into schema v8 (WP 8 sub-stage 3b-7;
/// `docs/backup-format-3.md` section 4): parse, classify, map and validate a
/// backup of format 1, 2 or 3 **without any side effect**. The result is a
/// [RestorePlan] that phase 1b (device-aware checks) and phase 2 (the one
/// write transaction) of `DriftBackupRepositoryV8` consume.
///
/// Formats 1 and 2 (schema 1 to 7) go through the same rules as the v7 → v8
/// migration:
/// - pre-v6 rows through the frozen v6 mapping first ([LegacyTrainingRowsV6],
///   exactly as production `DriftBackupRepository._fromOlderSchema` maps
///   them), pre-v5 recipes through the production v4 mapping;
/// - every exercise through [mapLegacyExercise] (targets, equipment links,
///   blocks, quarantine, report events);
/// - every set through [classifyLegacyExertion]: an invalid TRN-020 pair is
///   quarantined, cleared and reported, never rejected by the CHECK.
/// Format 3 rows are schema v8 rows and are validated as they are.
///
/// Every resulting row is validated against the Dart mirror of the v8
/// constraints ([schemaV8Tables]): types, NOT NULL, CHECK, primary key and
/// UNIQUE sets, and every foreign key whose parent must be in the backup.
/// Nothing is corrected silently: anything the mappings do not cover
/// rejects the whole restore.

/// The backup formats this restore reads.
const int backupFormatV8 = 3;

/// Schema version of format 3 files.
const int backupSchemaV8 = 8;

/// The envelope keys every RepForge exporter has written for formats 1 and
/// 2 (production `DriftBackupRepository.exportJson`, every era).
const Set<String> legacyEnvelopeKeys = {
  'app',
  'formatVersion',
  'schemaVersion',
  'exportedAt',
  'tables',
};

/// The keys format 3 adds.
const Set<String> format3EnvelopeKeys = {'appVersion', 'releaseLog'};

/// A validation failure of phase 1: the whole restore is rejected and
/// nothing is changed.
final class RestoreRejected implements Exception {
  RestoreRejected(this.message, [List<String> details = const []])
    : details = List.unmodifiable(details);

  final String message;
  final List<String> details;

  /// The user-facing [ValidationError] (`field: 'file'`, as the envelope
  /// check of production).
  ValidationError toError() => ValidationError(describe(), field: 'file');

  String describe() {
    if (details.isEmpty) return '$message Nothing was changed.';
    const shown = 20;
    final head = details.take(shown).join('; ');
    final more = details.length > shown
        ? ' (and ${details.length - shown} more)'
        : '';
    return '$message $head$more. Nothing was changed.';
  }

  @override
  String toString() => 'RestoreRejected: ${describe()}';
}

/// One `legacy_quarantine` row the restore creates (no id: SQLite assigns
/// it, as production restore and the migration do).
@immutable
final class NewQuarantineRow {
  const NewQuarantineRow({
    required this.sourceTable,
    required this.rowId,
    required this.reason,
    required this.originalJson,
    required this.fields,
  });

  /// From a [QuarantineRequest] of the v8 mapping (R-06 encoding).
  factory NewQuarantineRow.fromRequest(QuarantineRequest q) => NewQuarantineRow(
    sourceTable: q.table,
    rowId: q.recordId,
    reason: q.reason,
    originalJson: q.originalJson,
    fields: q.original.keys.toList(),
  );

  final String sourceTable;
  final String rowId;
  final String reason;
  final String originalJson;

  /// The fields a report entry links to this row (`quarantine_id`); empty
  /// for a pre-v6 row, whose report entry is the `legacy_quarantine` entry.
  final List<String> fields;
}

/// One exercise of the backup with everything that belongs to it, as v8
/// rows.
@immutable
final class ExerciseAggregate {
  const ExerciseAggregate({
    required this.row,
    required this.targets,
    required this.patterns,
    required this.equipment,
    required this.names,
    required this.blocks,
    required this.events,
    required this.quarantine,
    this.v7Row,
  });

  String get id => row['id']! as String;
  String get source => row['source']! as String;
  bool get isSystem => source == 'system';

  /// The full v8 `exercises` row (every column).
  final Map<String, Object?> row;
  final List<Map<String, Object?>> targets;
  final List<Map<String, Object?>> patterns;
  final List<Map<String, Object?>> equipment;
  final List<Map<String, Object?>> names;

  /// `exercise_blocks` rows. For formats 1 and 2 `blocked_at` is left out;
  /// phase 2 stamps the restore time.
  final List<Map<String, Object?>> blocks;

  /// The v8 mapping's report events (formats 1 and 2); empty for format 3.
  final List<ReportEvent> events;

  /// The v8 mapping's quarantine rows (formats 1 and 2).
  final List<NewQuarantineRow> quarantine;

  /// The v7 row after the v6 mapping (formats 1 and 2).
  final Map<String, Object?>? v7Row;

  /// The children by table, in a fixed order.
  Map<String, List<Map<String, Object?>>> get children => {
    'exercise_targets': targets,
    'exercise_patterns': patterns,
    'exercise_equipment': equipment,
    'exercise_names': names,
    'exercise_blocks': blocks,
  };
}

/// The TRN-020 outcome of one set (formats 1 and 2).
@immutable
final class SetClassification {
  const SetClassification(this.setId, this.exerciseId, this.events);
  final String setId;
  final Object? exerciseId;
  final List<ReportEvent> events;
}

/// Everything phase 1a found: the rows to write and what the report needs.
@immutable
final class RestorePlan {
  const RestorePlan({
    required this.format,
    required this.schemaVersion,
    required this.exportedAt,
    required this.appVersion,
    required this.backupIdentity,
    required this.userRows,
    required this.exercises,
    required this.legacyQuarantineRows,
    required this.newQuarantineRows,
    required this.sets,
    required this.backfillSessionExercises,
    required this.referenceRows,
    required this.reportRows,
    required this.releaseLog,
    required this.previewCounts,
    required this.restorableRows,
  });

  final int format;

  /// Schema version stated by the file (null when a format 1 file omits it).
  final int? schemaVersion;
  final DateTime? exportedAt;

  /// The app version a format 3 file states; null for formats 1 and 2.
  final String? appVersion;

  /// `sha256:<hex>` of the exact UTF-8 bytes of the backup text: the backup
  /// identity of R-08 (`provenance_source` of a restore run).
  final String backupIdentity;

  /// Rows of every [TableKind.user] table except `legacy_quarantine`, as
  /// full v8 rows in backup order (sets after TRN-020).
  final Map<String, List<Map<String, Object?>>> userRows;

  /// Every exercise of the backup, in backup order.
  final List<ExerciseAggregate> exercises;

  /// `legacy_quarantine` rows of the backup (with their ids).
  final List<Map<String, Object?>> legacyQuarantineRows;

  /// Quarantine rows the restore creates, in write order: the frozen v6
  /// mapping's (backup table order), then the v8 mapping's (exercises by
  /// id, then sets by id), as the migration writes them.
  final List<NewQuarantineRow> newQuarantineRows;

  /// TRN-020 classification of every set (formats 1 and 2), in backup order.
  final List<SetClassification> sets;

  /// A backup without `session_exercises` (made before schema v7): phase 2
  /// gives every set an entry with the frozen v6 → v7 backfill, as
  /// production restore and the migration do.
  final bool backfillSessionExercises;

  /// Reference rows of a format 3 file by table, in backup order.
  final Map<String, List<Map<String, Object?>>> referenceRows;

  /// Report rows of a format 3 file by table.
  final Map<String, List<Map<String, Object?>>> reportRows;

  /// The release log stated in a format 3 envelope.
  final List<Map<String, Object?>> releaseLog;

  /// Rows the backup would write per table (`BackupPreview.rowCounts`).
  final Map<String, int> previewCounts;

  /// Rows that count against "structurally empty" (register B-08).
  final int restorableRows;

  bool get isLegacy => format < backupFormatV8;
}

/// Phase 1a. Throws [RestoreRejected] for every invalid backup, and only
/// that: anything unexpected while reading a file (review M1) is a
/// [RestoreRejected] as well, so the preview never throws.
RestorePlan planRestore(String json) {
  try {
    return _planRestore(json);
  } on RestoreRejected {
    rethrow;
  } on Object catch (e) {
    throw RestoreRejected('This backup cannot be read:', ['$e']);
  }
}

RestorePlan _planRestore(String json) {
  final envelope = parseBackupEnvelope(
    json,
    supportedFormatVersion: backupFormatV8,
  );
  final BackupEnvelope env;
  switch (envelope) {
    case Err(:final error):
      throw RestoreRejected(error.message);
    case Ok(:final value):
      env = value;
  }
  final decoded = jsonDecode(json) as Map<String, Object?>;
  final format = env.formatVersion;
  if (format < 1) {
    throw RestoreRejected('This backup has an unknown format ($format).');
  }
  // Review O1, B-09: the envelope keys are allow-listed per format.
  final allowedKeys = {
    ...legacyEnvelopeKeys,
    if (format == backupFormatV8) ...format3EnvelopeKeys,
  };
  final unknownKeys = [
    for (final k in decoded.keys)
      if (!allowedKeys.contains(k)) k,
  ];
  if (unknownKeys.isNotEmpty) {
    throw RestoreRejected('This backup has unknown envelope parts:', [
      for (final k in unknownKeys) 'unknown key "$k"',
    ]);
  }
  final schema = decoded['schemaVersion'];
  int? schemaVersion;
  if (format == backupFormatV8) {
    if (schema != backupSchemaV8) {
      throw RestoreRejected(
        'A format 3 backup must state schema version 8, not '
        '${jsonEncode(schema)}.',
      );
    }
    schemaVersion = backupSchemaV8;
  } else if (schema != null) {
    // Format 1 was written at schema 1 to 7, format 2 at schema 7 only.
    final minSchema = format == 1 ? 1 : 7;
    if (schema is! int || schema < minSchema || schema > 7) {
      throw RestoreRejected(
        'A format $format backup cannot state schema version '
        '${jsonEncode(schema)}.',
      );
    }
    schemaVersion = schema;
  }
  final identity = 'sha256:${sha256Hex(utf8.encode(json))}';
  return format == backupFormatV8
      ? _Format3Planner(env, decoded, identity).plan()
      : _LegacyPlanner(env, schemaVersion, identity).plan();
}

// ---------------------------------------------------------------------------
// Row validation (shared).

/// Validates one row of [spec] and returns the full v8 row: every column,
/// defaults applied, booleans stored as 1 or 0. [where] names the row in
/// messages.
Map<String, Object?> validateRowV8(
  TableSpec spec,
  Map<String, Object?> row, {
  required String where,
}) {
  final problems = <String>[];
  for (final key in row.keys) {
    if (spec.column(key) == null) {
      problems.add('$where: unknown column "$key"');
    }
  }
  final out = <String, Object?>{};
  for (final c in spec.columns) {
    Object? v;
    if (row.containsKey(c.name)) {
      v = row[c.name];
    } else if (c.hasDefault) {
      v = c.defaultValue;
    } else if (c.autoIncrement) {
      continue;
    } else {
      v = null;
    }
    if (v is bool) {
      if (c.type == ColumnType.integer) {
        v = v ? 1 : 0;
      } else {
        problems.add('$where: ${c.name} holds a boolean');
        continue;
      }
    }
    final typeOk = switch (c.type) {
      _ when v == null => true,
      ColumnType.text => v is String,
      ColumnType.integer => v is int,
      ColumnType.real => v is num,
    };
    if (!typeOk) {
      problems.add(
        '$where: ${c.name} must be ${c.type.name}, not '
        '${jsonEncode(v)}',
      );
      continue;
    }
    if (v == null && c.notNull && !c.autoIncrement) {
      problems.add('$where: ${c.name} is required (NOT NULL)');
      continue;
    }
    out[c.name] = v;
  }
  if (problems.isEmpty) {
    for (final check in spec.checks) {
      if (!check.passes(out)) {
        problems.add('$where: breaks ${check.sql}');
      }
    }
  }
  if (problems.isNotEmpty) {
    throw RestoreRejected('This backup holds an invalid row:', problems);
  }
  return out;
}

/// Primary-key and UNIQUE checks over the rows of one table of the backup.
void checkKeysV8(TableSpec spec, Iterable<Map<String, Object?>> rows) {
  final problems = <String>[];
  for (final key in [spec.primaryKey, ...spec.uniques]) {
    final seen = <String>{};
    for (final r in rows) {
      final values = [for (final c in key) r[c]];
      // NULLs are distinct in a UNIQUE set; an autoincrement id without a
      // value gets a new one.
      if (values.any((v) => v == null)) continue;
      if (!seen.add(jsonEncode(values))) {
        problems.add(
          '${spec.name}: (${key.join(', ')}) = ${jsonEncode(values)} appears '
          'twice',
        );
      }
    }
  }
  if (problems.isNotEmpty) {
    throw RestoreRejected('This backup repeats a key:', problems);
  }
}

/// Code-point order, the order of SQLite's BINARY collation on UTF-8 text
/// (`ORDER BY id`).
int compareSqlText(String a, String b) {
  final ra = a.runes.iterator;
  final rb = b.runes.iterator;
  while (true) {
    final ha = ra.moveNext();
    final hb = rb.moveNext();
    if (!ha || !hb) return ha == hb ? 0 : (ha ? 1 : -1);
    final c = ra.current.compareTo(rb.current);
    if (c != 0) return c;
  }
}

/// Foreign keys whose parent table must be in the backup itself (user
/// tables, exercises, report runs). Reference parents may be on the device:
/// phase 1b checks them against the composed state.
void checkInternalForeignKeys(
  Map<String, List<Map<String, Object?>>> rowsByTable,
  Set<String> internalParents,
) {
  final keys = <String, Set<Object?>>{};
  Set<Object?> parentKeys(String table, String column) =>
      keys.putIfAbsent('$table.$column', () {
        return {
          for (final r in rowsByTable[table] ?? const <Map<String, Object?>>[])
            r[column],
        };
      });
  final problems = <String>[];
  for (final MapEntry(key: table, value: rows) in rowsByTable.entries) {
    final spec = schemaV8ByName[table]!;
    for (final fk in spec.foreignKeys) {
      if (!internalParents.contains(fk.parentTable)) continue;
      final parents = parentKeys(fk.parentTable, fk.parentColumn);
      for (final r in rows) {
        final v = r[fk.column];
        if (v != null && !parents.contains(v)) {
          problems.add(
            '$table ${spec.keyOf(r)}: ${fk.column} ${jsonEncode(v)} has no '
            '${fk.parentTable} row',
          );
        }
      }
    }
  }
  if (problems.isNotEmpty) {
    throw RestoreRejected(
      'This backup has records whose parent record is missing (foreign '
      'key):',
      problems,
    );
  }
}

List<Map<String, Object?>> _rowsOf(Object? value, String table) {
  if (value is! List) {
    throw RestoreRejected('The table "$table" of this backup is not a list.');
  }
  return [
    for (var i = 0; i < value.length; i++)
      switch (value[i]) {
        final Map<String, Object?> m => m,
        _ => throw RestoreRejected(
          'Row ${i + 1} of the table "$table" of this backup is not an '
          'object.',
        ),
      },
  ];
}

// ---------------------------------------------------------------------------
// Formats 1 and 2.

final class _LegacyPlanner {
  _LegacyPlanner(this.env, this.schemaVersion, this.identity);

  final BackupEnvelope env;
  final int? schemaVersion;
  final String identity;

  final Map<String, List<Map<String, Object?>>> _user = {};
  final List<Map<String, Object?>> _legacyQuarantine = [];
  final List<NewQuarantineRow> _v6Quarantine = [];
  final Map<String, int> _preview = {};
  var _restorable = 0;
  final List<ExerciseAggregate> _exercises = [];
  final List<SetClassification> _sets = [];

  RestorePlan plan() {
    for (final MapEntry(key: table, value: raw) in env.tables.entries) {
      if (!schemaV7TableNames.contains(table)) {
        throw RestoreRejected(
          'This backup holds the table "$table", which a format '
          '${env.formatVersion} backup cannot contain.',
        );
      }
      final rows = _rowsOf(raw, table);
      var n = 0;
      for (var i = 0; i < rows.length; i++) {
        if (_addRow(table, rows[i], '$table row ${i + 1}')) n++;
      }
      _preview[table] = n;
      _restorable += n;
    }

    // v8 mapping quarantine, in the migration's order: exercises by id,
    // then sets by id.
    final v8Quarantine = <NewQuarantineRow>[
      for (final x
          in _exercises.toList()..sort((a, b) => compareSqlText(a.id, b.id)))
        ...x.quarantine,
      ...(_setQuarantine.entries.toList()
            ..sort((a, b) => compareSqlText(a.key, b.key)))
          .map((e) => e.value),
    ];

    for (final MapEntry(key: table, value: rows) in _user.entries) {
      checkKeysV8(schemaV8ByName[table]!, rows);
    }
    checkKeysV8(schemaV8ByName['legacy_quarantine']!, _legacyQuarantine);
    checkKeysV8(schemaV8ByName['exercises']!, [
      for (final x in _exercises) x.row,
    ]);
    for (final x in _exercises) {
      for (final MapEntry(key: t, value: rows) in x.children.entries) {
        checkKeysV8(schemaV8ByName[t]!, rows);
      }
    }
    checkInternalForeignKeys({
      ..._user,
      'exercises': [for (final x in _exercises) x.row],
    }, _internalParents);

    return RestorePlan(
      format: env.formatVersion,
      schemaVersion: schemaVersion,
      exportedAt: env.exportedAt,
      appVersion: null,
      backupIdentity: identity,
      userRows: _user,
      exercises: _exercises,
      legacyQuarantineRows: _legacyQuarantine,
      newQuarantineRows: [..._v6Quarantine, ...v8Quarantine],
      sets: _sets,
      backfillSessionExercises: !env.tables.containsKey('session_exercises'),
      referenceRows: const {},
      reportRows: const {},
      releaseLog: const [],
      previewCounts: _preview,
      restorableRows: _restorable,
    );
  }

  final Map<String, NewQuarantineRow> _setQuarantine = {};

  /// Production's pre-v6 quarantine record (`_fromOlderSchema`), copied:
  /// the original row as plain JSON. The time is stamped in phase 2.
  void _v6(String table, Map<String, Object?> original, String reason) =>
      _v6Quarantine.add(
        NewQuarantineRow(
          sourceTable: table,
          rowId: (original['id'] ?? '').toString(),
          reason: reason,
          originalJson: jsonEncode(original),
          fields: const [],
        ),
      );

  /// Returns true when the row is restored (production's preview count).
  bool _addRow(String table, Map<String, Object?> row, String where) {
    switch (table) {
      case 'recipes' when row.containsKey('method_steps_json'):
        // Production `_fromOlderSchema`, schema v4 recipes (copied).
        final flag = row['freezer_friendly'];
        final mapped = {
          ...row,
          'cook_steps_json': row['cook_steps_json'] ?? row['method_steps_json'],
          'freezing':
              row['freezing'] ??
              (flag == 1 || flag == true ? 'yes' : 'unknown'),
        }..removeWhere((k, _) => legacyConsumedColumns['recipes']!.contains(k));
        _addUser(table, mapped, where);
        return true;
      case 'exercises':
        _addExercise(row, where);
        return true;
      case 'plan_exercises' when row.containsKey('target_reps'):
        final fixed = LegacyTrainingRowsV6.planExercise(row);
        if (!fixed.unchanged) _v6(table, row, fixed.reason);
        final out = fixed.row;
        if (out == null) return false;
        _addUser(table, out, where);
        return true;
      case 'session_sets':
        var set = row;
        if (!row.containsKey('energy_kcal')) {
          final fixed = LegacyTrainingRowsV6.sessionSet(row);
          if (!fixed.unchanged) _v6(table, row, fixed.reason);
          set = fixed.row!;
        }
        _addSet(set, where);
        return true;
      case 'legacy_quarantine':
        final spec = schemaV8ByName[table]!;
        _legacyQuarantine.add(validateRowV8(spec, row, where: where));
        return true;
      default:
        _addUser(table, row, where);
        return true;
    }
  }

  void _addUser(String table, Map<String, Object?> row, String where) {
    final spec = schemaV8ByName[table]!;
    _user
        .putIfAbsent(table, () => [])
        .add(validateRowV8(spec, row, where: where));
  }

  void _addSet(Map<String, Object?> row, String where) {
    final id = row['id'];
    if (id is! String || id.isEmpty) {
      throw RestoreRejected('This backup holds an invalid row:', [
        '$where: id must be a non-empty text',
      ]);
    }
    // Review M1: the classification reads stored SQLite values; a JSON
    // boolean, array or object is none and is refused, never coerced.
    for (final column in const ['exertion_scale', 'exertion_value']) {
      final v = row[column];
      if (v != null && v is! String && v is! num) {
        final problem =
            '$where: $column must be a text, a number or null, not '
            '${jsonEncode(v)}';
        throw RestoreRejected('This backup holds an invalid row:', [problem]);
      }
    }
    final c = classifyLegacyExertion(
      setId: id,
      scale: row['exertion_scale'],
      value: row['exertion_value'],
    );
    final out = Map<String, Object?>.of(row);
    if (c.quarantine case final q?) {
      out['exertion_scale'] = null;
      out['exertion_value'] = null;
      _setQuarantine[id] = NewQuarantineRow.fromRequest(q);
    }
    _addUser('session_sets', out, where);
    _sets.add(SetClassification(id, row['exercise_id'], c.events));
  }

  void _addExercise(Map<String, Object?> original, String where) {
    var row = original;
    if (row.containsKey('is_custom')) {
      final mapped = LegacyTrainingRowsV6.exercise(row);
      if (mapped.quarantineReason case final reason?) {
        _v6('exercises', original, reason);
      }
      row = mapped.row;
    }
    // The v7 row: its columns, types and NOT NULL values.
    final problems = <String>[];
    final v7 = <String, Object?>{};
    final known = {for (final c in v7ExerciseColumns) c.name};
    for (final k in row.keys) {
      if (!known.contains(k)) problems.add('$where: unknown column "$k"');
    }
    for (final c in v7ExerciseColumns) {
      var v = row.containsKey(c.name)
          ? row[c.name]
          : (c.hasDefault ? c.defaultValue : null);
      if (v is bool && c.type == ColumnType.integer) v = v ? 1 : 0;
      if (v == null) {
        if (c.notNull) problems.add('$where: ${c.name} is required');
      } else if (c.type == ColumnType.text ? v is! String : v is! int) {
        problems.add(
          '$where: ${c.name} must be ${c.type.name}, not ${jsonEncode(v)}',
        );
      }
      v7[c.name] = v;
    }
    if (problems.isNotEmpty) {
      throw RestoreRejected('This backup holds an invalid exercise:', problems);
    }
    final id = v7['id']! as String;
    if (id.isEmpty) {
      throw RestoreRejected('This backup holds an invalid exercise:', [
        '$where: the id is empty',
      ]);
    }
    // The v7 CHECK on `supplied` (0 or 1); the mapping refuses anything else.
    if (v7['supplied'] != 0 && v7['supplied'] != 1) {
      throw RestoreRejected('This backup holds an invalid exercise:', [
        '$where: supplied must be 0 or 1, not ${jsonEncode(v7['supplied'])}',
      ]);
    }
    final m = mapLegacyExercise(
      LegacyExerciseRow(
        id: id,
        type: v7['type'],
        category: v7['category'],
        aliasesJson: v7['aliases_json'],
        primaryMuscle: v7['primary_muscle'],
        secondaryMusclesJson: v7['secondary_muscles_json'],
        equipmentJson: v7['equipment_json'],
        supplied: v7['supplied'],
      ),
    );
    final v8 = <String, Object?>{
      for (final MapEntry(:key, :value) in v7.entries)
        if (!const {
          'primary_muscle',
          'secondary_muscles_json',
          'equipment_json',
          'supplied',
        }.contains(key))
          key: value,
      'source': m.source.name,
      'provider_id': m.providerId?.value,
      'revision': m.revision,
    };
    final spec = schemaV8ByName['exercises']!;
    _exercises.add(
      ExerciseAggregate(
        row: validateRowV8(spec, v8, where: where),
        targets: [
          for (final t in m.targets)
            validateRowV8(schemaV8ByName['exercise_targets']!, {
              'exercise_id': id,
              'node_id': t.node.value,
              'role': t.role.name,
              'ordinal': t.ordinal,
            }, where: '$where target ${t.node.value}'),
        ],
        patterns: const [],
        equipment: [
          for (final e in m.equipment)
            validateRowV8(schemaV8ByName['exercise_equipment']!, {
              'exercise_id': id,
              'equipment_id': e.item.value,
              'ordinal': e.ordinal,
              'role_override': null,
              'override_note': null,
            }, where: '$where equipment ${e.item.value}'),
        ],
        names: const [],
        blocks: [
          for (final b in m.blocks)
            {
              'exercise_id': id,
              'reason': b.reason.name,
              'original_json': V7ToV8Migration.blockOriginalJson(b.reason, v7),
              'resolved_at': null,
            },
        ],
        events: m.events,
        quarantine: [
          for (final q in m.quarantine) NewQuarantineRow.fromRequest(q),
        ],
        v7Row: v7,
      ),
    );
  }
}

/// Parents the backup itself must hold (formats 1 and 2: every v7 table;
/// format 3 adds the report runs).
const Set<String> _internalParents = {
  'foods',
  'saved_meals',
  'recipes',
  'recipe_ingredients',
  'workout_plans',
  'workout_sessions',
  'session_exercises',
  'training_splits',
  'exercises',
  'migration_runs',
};

// ---------------------------------------------------------------------------
// Format 3.

/// Tables whose rows are exercise children, keyed by `exercise_id`.
const List<String> exerciseChildTables = [
  'exercise_targets',
  'exercise_patterns',
  'exercise_equipment',
  'exercise_names',
  'exercise_blocks',
];

final class _Format3Planner {
  _Format3Planner(this.env, this.decoded, this.identity);

  final BackupEnvelope env;
  final Map<String, Object?> decoded;
  final String identity;

  RestorePlan plan() {
    final appVersion = decoded['appVersion'];
    if (appVersion is! String || appVersion.isEmpty) {
      throw RestoreRejected('A format 3 backup must state its app version.');
    }
    final tables = env.tables;
    final missing = [
      for (final t in schemaV8Tables)
        if (!tables.containsKey(t.name)) t.name,
    ];
    final unknown = [
      for (final k in tables.keys)
        if (!schemaV8ByName.containsKey(k)) k,
    ];
    if (unknown.isNotEmpty || missing.isNotEmpty) {
      throw RestoreRejected('This format 3 backup is incomplete or unknown:', [
        for (final t in unknown) 'unknown table "$t"',
        for (final t in missing) 'missing table "$t"',
      ]);
    }
    final rows = <String, List<Map<String, Object?>>>{};
    final preview = <String, int>{};
    for (final spec in schemaV8Tables) {
      final raw = _rowsOf(tables[spec.name], spec.name);
      rows[spec.name] = [
        for (var i = 0; i < raw.length; i++)
          validateRowV8(spec, raw[i], where: '${spec.name} row ${i + 1}'),
      ];
      checkKeysV8(spec, rows[spec.name]!);
      preview[spec.name] = raw.length;
    }
    checkInternalForeignKeys(rows, _internalParents);
    _checkReport(rows);
    final releaseLog = _checkReleaseLog(rows['catalogue_releases']!);

    // Exercise aggregates.
    final children = <String, Map<String, List<Map<String, Object?>>>>{
      for (final t in exerciseChildTables) t: {},
    };
    for (final t in exerciseChildTables) {
      for (final r in rows[t]!) {
        children[t]!.putIfAbsent(r['exercise_id']! as String, () => []).add(r);
      }
    }
    final exercises = [
      for (final r in rows['exercises']!)
        ExerciseAggregate(
          row: r,
          targets: children['exercise_targets']![r['id']] ?? const [],
          patterns: children['exercise_patterns']![r['id']] ?? const [],
          equipment: children['exercise_equipment']![r['id']] ?? const [],
          names: children['exercise_names']![r['id']] ?? const [],
          blocks: children['exercise_blocks']![r['id']] ?? const [],
          events: const [],
          quarantine: const [],
        ),
    ];

    final user = <String, List<Map<String, Object?>>>{
      for (final t in schemaV8Tables)
        if (t.kind == TableKind.user && t.name != 'legacy_quarantine')
          t.name: rows[t.name]!,
    };
    // Register B-08 (review M4): user tables and user or imported exercises
    // count; system exercises are catalogue content the device keeps, and
    // reference and report rows alone restore nothing of the user's.
    var restorable = rows['exercises']!
        .where((r) => r['source'] != 'system')
        .length;
    for (final t in schemaV8Tables) {
      // legacy_quarantine is merged history since B-03 (decided), not
      // user data a restore replaces.
      if (t.kind == TableKind.user && t.name != 'legacy_quarantine') {
        restorable += rows[t.name]!.length;
      }
    }
    return RestorePlan(
      format: backupFormatV8,
      schemaVersion: backupSchemaV8,
      exportedAt: env.exportedAt,
      appVersion: decoded['appVersion']! as String,
      backupIdentity: identity,
      userRows: user,
      exercises: exercises,
      legacyQuarantineRows: rows['legacy_quarantine']!,
      newQuarantineRows: const [],
      sets: const [],
      backfillSessionExercises: false,
      referenceRows: {
        for (final t in schemaV8Tables)
          if (t.kind == TableKind.reference) t.name: rows[t.name]!,
      },
      reportRows: {
        for (final t in schemaV8Tables)
          if (t.kind == TableKind.report) t.name: rows[t.name]!,
      },
      releaseLog: releaseLog,
      previewCounts: preview,
      restorableRows: restorable,
    );
  }

  /// The envelope's `releaseLog` must equal the release records of the
  /// table (one fact, two places: they may never differ).
  List<Map<String, Object?>> _checkReleaseLog(
    List<Map<String, Object?>> releases,
  ) {
    final log = decoded['releaseLog'];
    if (log is! List) {
      throw RestoreRejected('A format 3 backup must state its release log.');
    }
    final expected = [for (final r in releases) releaseLogEntry(r)];
    if (jsonEncode(log) != jsonEncode(expected)) {
      throw RestoreRejected(
        'The release log of this backup does not match its catalogue '
        'releases.',
      );
    }
    return expected;
  }

  /// Every report entry keeps the R-06 encoding, the action-category rules
  /// and its R-07 event id; every run's stored counts reconcile with its
  /// entries (R-04, Review A M1).
  void _checkReport(Map<String, List<Map<String, Object?>>> rows) {
    final problems = <String>[];
    final entries = rows['migration_report_entries']!;
    for (final r in entries) {
      final where = 'migration_report_entries ${r['event_id']}';
      try {
        final event = reportEventOfRow(r);
        final stored = ReportEntry.stored(
          runId: r['run_id']! as String,
          eventId: r['event_id']! as String,
          event: event,
        );
        if (!stored.eventIdMatches) {
          problems.add('$where: the event id does not match its fields');
        }
      } on Object catch (e) {
        problems.add('$where: ${e is ArgumentError ? e.message : e}');
      }
    }
    // Every quarantine link has its row in the backup (register B-03: the
    // links are rewritten with the rows, so a link without a row could
    // only point at an unrelated device row).
    final quarantine = {for (final q in rows['legacy_quarantine']!) q['id']};
    for (final r in entries) {
      final q = r['quarantine_id'];
      if (q != null && !quarantine.contains(q)) {
        problems.add(
          'migration_report_entries ${r['event_id']}: quarantine_id $q has '
          'no legacy_quarantine row in the backup',
        );
      }
    }
    // Reconciliation of each run's counts.
    final counts = <String, Map<String, int>>{};
    for (final c in rows['migration_report_counts']!) {
      counts.putIfAbsent(
        '${c['run_id']}|${c['source_table']}',
        () => {},
      )['${c['dimension']}|${c['code']}'] = c['record_count']! as int;
    }
    final byRunTable = <String, List<Map<String, Object?>>>{};
    for (final r in entries) {
      byRunTable
          .putIfAbsent('${r['run_id']}|${r['source_table']}', () => [])
          .add(r);
    }
    for (final MapEntry(key: k, value: c) in counts.entries) {
      final examined = c['category|examined'];
      if (examined != null) {
        final sum = [
          for (final o in ReportCategory.outcomes) c['category|${o.code}'] ?? 0,
        ].fold(0, (a, b) => a + b);
        if (sum != examined) {
          problems.add('counts $k: outcomes sum to $sum, examined $examined');
        }
      }
      final list = byRunTable[k] ?? const [];
      for (final a in ReportAction.values) {
        final stated = c['disposition|${a.name}'];
        if (stated == null) continue;
        final actual = list.where((e) => e['disposition'] == a.name).length;
        if (stated != actual) {
          problems.add(
            'counts $k: ${a.name} $stated, but $actual entries have it',
          );
        }
      }
      final warnings = c['category|warningForReview'];
      if (warnings != null) {
        final actual = {
          for (final e in list)
            if (e['category'] == ReportCategory.warningForReview.code)
              e['record_id'],
        }.length;
        if (warnings != actual) {
          problems.add(
            'counts $k: $warnings records with warnings, but $actual have '
            'warning entries',
          );
        }
      }
    }
    for (final k in byRunTable.keys) {
      if (!counts.containsKey(k)) {
        problems.add('entries of $k have no counts');
      }
    }
    if (problems.isNotEmpty) {
      throw RestoreRejected(
        'The report history of this backup is not consistent:',
        problems,
      );
    }
  }
}

/// One release log entry of a `catalogue_releases` row.
Map<String, Object?> releaseLogEntry(Map<String, Object?> r) => {
  'providerId': r['provider_id'],
  'release': r['release'],
  'contentHashAlgorithm': r['content_hash_algorithm'],
  'contentHashEncoding': r['content_hash_encoding'],
  'contentHash': r['content_hash'],
};

/// The WS4 [ReportEvent] of a stored `migration_report_entries` row. Its
/// constructor validates the R-06 encoding, the action-category rules and
/// the block reason; it throws [ArgumentError] or [FormatException]
/// otherwise.
ReportEvent reportEventOfRow(Map<String, Object?> r) {
  final action = ReportAction.fromName(r['disposition']! as String);
  final category = ReportCategory.fromCode(r['category']! as String);
  final blockName = r['block_reason'] as String?;
  BlockReason? block;
  if (blockName != null) {
    for (final b in BlockReason.values) {
      if (b.name == blockName) block = b;
    }
  }
  if (action == null ||
      category == null ||
      (blockName != null && block == null)) {
    throw ArgumentError('unknown disposition, category or block reason');
  }
  return ReportEvent(
    table: r['source_table']! as String,
    recordId: r['record_id']! as String,
    field: r['field']! as String,
    position: r['position'] as int?,
    originalValue: r['original_value']! as String,
    element: r['element'] as String?,
    resultingValue: r['resulting_value']! as String,
    action: action,
    rule: r['rule']! as String,
    category: category,
    reason: r['reason']! as String,
    blockReason: block,
  );
}

// ---------------------------------------------------------------------------
// Domain validation of the exercises a format 3 restore inserts (review H1).

/// The [ReferenceData] of the composed state (device rows kept plus the
/// backup's rows to insert), for `validateExercise`. Reference lifecycle and
/// equipment class wait for stage 3c (R-21, Q11): every row is active and
/// items carry [EquipmentClass.other], which the rules never read (the same
/// convention as `DriftLibraryRepositoryV8`).
ReferenceData referenceDataOf({
  required Iterable<Map<String, Object?>> nodes,
  required Iterable<Map<String, Object?>> patterns,
  required Iterable<Map<String, Object?>> items,
}) => ReferenceData(
  anatomy: AnatomyTree([
    for (final n in nodes)
      AnatomyNode(
        id: AnatomyNodeId(n['id']! as String),
        parentId: switch (n['parent_id']) {
          final String p => AnatomyNodeId(p),
          _ => null,
        },
        level: n['level']! as int,
        sort: n['sort_order']! as int,
        labels: const {},
        nonAnatomical: n['non_anatomical'] == 1,
        providerId: ProviderId(n['provider_id']! as String),
      ),
  ]),
  patterns: PatternTree([
    for (final p in patterns)
      MovementPattern(
        id: MovementPatternId(p['id']! as String),
        parentId: switch (p['parent_id']) {
          final String id => MovementPatternId(id),
          _ => null,
        },
        level: p['parent_id'] == null ? 1 : 2,
        sort: p['sort_order']! as int,
        labels: const {},
        providerId: ProviderId(p['provider_id']! as String),
      ),
  ]),
  equipment: EquipmentCatalogue([
    for (final i in items)
      EquipmentItem(
        id: EquipmentItemId(i['id']! as String),
        sort: i['sort_order']! as int,
        labels: const {},
        equipmentClass: EquipmentClass.other,
        defaultRole:
            enumByName(EquipmentDefaultRole.values, i['default_role']) ??
            (throw StateError('default role ${i['default_role']}')),
        providerId: ProviderId(i['provider_id']! as String),
      ),
  ]),
);

List<String>? _stringList(Object? json) {
  if (json is! String) return null;
  try {
    final v = jsonDecode(json);
    if (v is! List) return null;
    final out = <String>[];
    for (final x in v) {
      if (x is! String) return null;
      out.add(x);
    }
    return out;
  } on FormatException {
    return null;
  }
}

/// The block reasons the stored row of [x] calls for under the
/// unreadable-data decision (2026-11-06): `type` or `category` that is not
/// a domain identifier → [BlockReason.invalidClassification];
/// `aliases_json` that is not a JSON array of strings →
/// [BlockReason.invalidAliases].
Set<BlockReason> unreadableBlockReasons(ExerciseAggregate x) => {
  if (enumByName(ExerciseType.values, x.row['type']) == null ||
      enumByName(ExerciseCategory.values, x.row['category']) == null)
    BlockReason.invalidClassification,
  if (_stringList(x.row['aliases_json']) == null) BlockReason.invalidAliases,
};

/// The domain exercise of [x], read as `DriftLibraryRepositoryV8` reads a
/// stored exercise; null when the stored `type`, `category` or
/// `aliases_json` is not a domain identifier or a JSON list of strings, or
/// when a stored date or value cannot be represented in the domain.
///
/// With [placeholders] an unreadable `type` or `category` reads as the
/// first identifier and unreadable aliases as none, so the structural rules
/// can still check a blocked unreadable exercise (review O4); the
/// placeholder never reaches storage.
CatalogueExercise? catalogueExerciseOf(
  ExerciseAggregate x, {
  bool placeholders = false,
}) {
  final r = x.row;
  var type = enumByName(ExerciseType.values, r['type']);
  var category = enumByName(ExerciseCategory.values, r['category']);
  var aliases = _stringList(r['aliases_json']);
  if (placeholders) {
    type ??= ExerciseType.values.first;
    category ??= ExerciseCategory.values.first;
    aliases ??= const [];
  }
  final source = enumByName(ExerciseSource.values, r['source']);
  final created = DateTime.tryParse(r['created_at']! as String);
  final updated = DateTime.tryParse(r['updated_at']! as String);
  if (type == null ||
      category == null ||
      aliases == null ||
      source == null ||
      created == null ||
      updated == null) {
    return null;
  }
  int ord(Map<String, Object?> a) => a['ordinal']! as int;
  List<Map<String, Object?>> sorted(List<Map<String, Object?>> rows) =>
      [...rows]..sort((a, b) => ord(a).compareTo(ord(b)));
  try {
    return CatalogueExercise(
      id: ExerciseId(x.id),
      names: ExerciseNames({
        canonicalLocale: LocalizedName(r['name']! as String, aliases: aliases),
        for (final n in x.names)
          n['locale']! as String: LocalizedName(
            n['name']! as String,
            aliases: _stringList(n['aliases_json']) ?? const [],
          ),
      }),
      type: type,
      category: category,
      source: source,
      providerId: switch (r['provider_id']) {
        final String p => ProviderId(p),
        _ => null,
      },
      revision: r['revision'] as int?,
      targets: [
        for (final t in sorted(x.targets))
          ExerciseTarget(
            node: AnatomyNodeId(t['node_id']! as String),
            role:
                enumByName(TargetRole.values, t['role']) ??
                (throw StateError('target role')),
            ordinal: ord(t),
          ),
      ],
      patterns: [
        for (final p in sorted(x.patterns))
          MovementPatternId(p['pattern_id']! as String),
      ],
      equipment: [
        for (final e in sorted(x.equipment))
          ExerciseEquipment(
            EquipmentItemId(e['equipment_id']! as String),
            roleOverride: enumByName(EquipmentRole.values, e['role_override']),
            overrideNote: e['override_note'] as String?,
          ),
      ],
      mechanics: enumByName(Mechanics.values, r['mechanics']),
      laterality: enumByName(Laterality.values, r['laterality']),
      difficulty: enumByName(Difficulty.values, r['difficulty']),
      attributes: {
        for (final (attribute, column) in const [
          (ExerciseAttribute.angle, 'angle'),
          (ExerciseAttribute.armPosition, 'arm_position'),
          (ExerciseAttribute.bodyPosition, 'body_position'),
          (ExerciseAttribute.grip, 'grip'),
          (ExerciseAttribute.gripWidth, 'grip_width'),
          (ExerciseAttribute.kneePosition, 'knee_position'),
          (ExerciseAttribute.stance, 'stance'),
        ])
          if (r[column] case final String v) attribute: v,
      },
      retiredAt: switch (r['retired_at']) {
        final String t => DateTime.tryParse(t),
        _ => null,
      },
      copiedFromId: switch (r['copied_from_id']) {
        final String c => ExerciseId(c),
        _ => null,
      },
      createdAt: created,
      updatedAt: updated,
    );
  } on Object {
    return null;
  }
}
