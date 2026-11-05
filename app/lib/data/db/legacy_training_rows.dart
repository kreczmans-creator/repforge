import 'dart:convert';

import 'package:repforge/domain/training/training.dart';

/// Result of checking one pre-v6 training row against the schema v6 CHECK
/// constraints.
final class SanitisedRow {
  const SanitisedRow({
    required this.row,
    required this.nulledColumns,
    required this.reason,
  });

  /// The row mapped to the v6 shape with out-of-range nullable values set to
  /// null, or null when a NOT NULL value was out of range and the whole row
  /// must be quarantined instead of stored.
  final Map<String, Object?>? row;

  /// Columns (named as in the input row) whose out-of-range value was
  /// replaced by NULL.
  final List<String> nulledColumns;

  /// Human-readable summary stored with the quarantined original.
  final String reason;

  /// True when the row was already valid.
  bool get unchanged => row != null && nulledColumns.isEmpty;
}

/// Decides what happens to a training row that violates a schema v6 CHECK
/// constraint (TD-25) when it is migrated or restored from a pre-v6 backup.
///
/// Decision (documented in `docs/data-model.md`): a value is never clamped.
/// An out-of-range value in a nullable column becomes NULL (the domain allows
/// "not recorded"); a row whose NOT NULL value is out of range is removed
/// from its table. In both cases the complete original row is kept as JSON in
/// `legacy_quarantine`, so nothing is lost silently. Before WP 8 no app code
/// could write a set, so real data is expected never to hit this path.
abstract final class LegacyTrainingRows {
  static bool _between(Object? v, num lo, num hi) =>
      v is num && v >= lo && v <= hi;

  static SanitisedRow _result(
    Map<String, Object?> row,
    Map<String, Object?> out,
    List<String> nulled,
  ) => SanitisedRow(
    row: out,
    nulledColumns: nulled,
    reason: nulled.isEmpty
        ? 'valid'
        : 'Out-of-range value set to NULL: ${nulled.join(', ')}',
  );

  /// `session_sets` row (the same shape in v5 and v6).
  static SanitisedRow sessionSet(Map<String, Object?> row) {
    final checks = <String, bool Function(Object?)>{
      'reps': (v) => _between(v, 1, 100),
      'load_kg': (v) => _between(v, 0, 1000),
      'assistance_kg': (v) => _between(v, 0, 1000),
      'duration_sec': (v) => v is num && v > 0,
      'metres': (v) => v is num && v > 0,
      'average_heart_rate': (v) => _between(v, 30, 250),
      'exertion_value': (v) => _between(v, 0, 10),
      'rest_seconds': (v) => _between(v, 0, 3600),
    };
    final out = Map<String, Object?>.of(row);
    final nulled = <String>[];
    checks.forEach((column, ok) {
      final v = row[column];
      if (v != null && !ok(v)) {
        out[column] = null;
        nulled.add(column);
      }
    });
    return _result(row, out, nulled);
  }

  /// `plan_exercises` row in the v5 shape (`target_reps`), mapped to the v6
  /// shape (`reps_min` = `reps_max` = `target_reps`, when valid). Returns a
  /// row that is already v6-shaped unchanged apart from range checks.
  static SanitisedRow planExercise(Map<String, Object?> row) {
    final sets = row['target_sets'];
    final order = row['sort_order'];
    if (!_between(sets, 1, 20) || order is! num || order < 0) {
      return const SanitisedRow(
        row: null,
        nulledColumns: [],
        reason: 'Out-of-range target_sets or sort_order; row moved here',
      );
    }
    final out = Map<String, Object?>.of(row);
    final nulled = <String>[];
    void nullIf(String column, bool Function(Object?) ok) {
      final v = row[column];
      if (v != null && !ok(v)) {
        out[column] = null;
        nulled.add(column);
      }
    }

    nullIf('target_load_kg', (v) => _between(v, 0, 1000));
    nullIf('target_duration_sec', (v) => v is num && v > 0);
    nullIf('target_metres', (v) => v is num && v > 0);
    nullIf('rest_seconds', (v) => _between(v, 0, 3600));
    if (row.containsKey('target_reps')) {
      nullIf('target_reps', (v) => _between(v, 1, 100));
      out['reps_min'] = out['target_reps'];
      out['reps_max'] = out['target_reps'];
      out.remove('target_reps');
    } else {
      nullIf('reps_min', (v) => _between(v, 1, 100));
      nullIf('reps_max', (v) => _between(v, 1, 100));
      final min = out['reps_min'];
      final max = out['reps_max'];
      if (min == null || max == null || (min as num) > (max as num)) {
        if (out['reps_min'] != null || out['reps_max'] != null) {
          nulled.addAll(['reps_min', 'reps_max']);
        }
        out['reps_min'] = null;
        out['reps_max'] = null;
      }
    }
    return _result(row, out, nulled);
  }

  /// Matches [raw] (free text from the WP 3 schema, e.g. `Push` or
  /// `front delts`) to an enum value ignoring case, spaces and punctuation;
  /// returns the enum name, or [raw] unchanged when nothing matches.
  static String canonicalName<T extends Enum>(String raw, List<T> values) {
    final folded = raw.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    for (final v in values) {
      if (v.name.toLowerCase() == folded) return v.name;
    }
    return raw;
  }

  /// [canonicalName] applied to a JSON array of strings; text that is not
  /// such an array is returned unchanged.
  static String canonicalNamesJson<T extends Enum>(
    String json,
    List<T> values,
  ) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List && decoded.every((e) => e is String)) {
        return jsonEncode([
          for (final e in decoded) canonicalName(e as String, values),
        ]);
      }
    } on FormatException {
      // Fall through: keep the stored text.
    }
    return json;
  }

  /// Maps an `exercises` row from the v5 shape (or earlier) to v6: `supplied`
  /// from `is_custom`, canonical enum names, aliases and search key.
  static Map<String, Object?> exercise(Map<String, Object?> row) {
    final out = Map<String, Object?>.of(row);
    if (!out.containsKey('supplied')) {
      final custom = out['is_custom'];
      out['supplied'] = (custom == 1 || custom == true) ? 0 : 1;
    }
    out.remove('is_custom');
    out['category'] = canonicalName(
      (row['category'] ?? '').toString(),
      ExerciseCategory.values,
    );
    out['primary_muscle'] = canonicalName(
      (row['primary_muscle'] ?? '').toString(),
      MuscleGroup.values,
    );
    out['secondary_muscles_json'] = canonicalNamesJson(
      (row['secondary_muscles_json'] ?? '[]').toString(),
      MuscleGroup.values,
    );
    out['equipment_json'] = canonicalNamesJson(
      (row['equipment_json'] ?? '[]').toString(),
      Equipment.values,
    );
    final aliasesJson = (row['aliases_json'] ?? '[]').toString();
    var aliases = <String>[];
    try {
      final decoded = jsonDecode(aliasesJson);
      if (decoded is List) aliases = [for (final a in decoded) a.toString()];
    } on FormatException {
      aliases = [];
    }
    out['aliases_json'] = jsonEncode(aliases);
    out['search_key'] = exerciseSearchKey(
      (row['name'] ?? '').toString(),
      aliases,
    );
    return out;
  }
}
