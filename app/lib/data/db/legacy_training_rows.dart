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

  // ---- Taxonomy matching for free text (WP 3 schema) -----------------------

  static String _fold(String raw) =>
      raw.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  /// Display labels from `docs/training-taxonomy.md` that differ from the
  /// identifier once folded (the full label before any parenthesis). A
  /// frozen snapshot: later label rewording does not change what a legacy
  /// row maps to. Identifiers are matched through the enum names.
  static const Map<String, String> _labelToIdentifier = {
    // Equipment labels.
    'dumbbells': 'dumbbell',
    'cablestation': 'cable',
    'weightplate': 'plate',
    'gymnasticrings': 'rings',
    'exercisebike': 'bike',
    'rowingmachine': 'rower',
    'crosstrainer': 'elliptical',
  };

  /// The small, explicit synonym table (folded text to identifier). Only
  /// everyday gym words with one unambiguous target; anything else is
  /// quarantined rather than guessed. "Delts" and "shoulders" are left out
  /// because they map to three groups.
  static const Map<String, String> _synonyms = {
    // Muscles.
    'quads': 'quadriceps',
    'quad': 'quadriceps',
    'hams': 'hamstrings',
    'hamstring': 'hamstrings',
    'lat': 'lats',
    'glute': 'glutes',
    'calf': 'calves',
    'pecs': 'chest',
    'pectorals': 'chest',
    'traps': 'upperBack',
    'trapezius': 'upperBack',
    'rhomboids': 'upperBack',
    'abdominals': 'abs',
    'tricep': 'triceps',
    'bicep': 'biceps',
    // Equipment.
    'cables': 'cable',
    'kettlebells': 'kettlebell',
    'barbells': 'barbell',
    'band': 'resistanceBand',
    'bands': 'resistanceBand',
    'plates': 'plate',
    // Category.
    'stretching': 'mobility',
  };

  /// Equipment texts that mean "no equipment" (an empty list, not a loss).
  static const Set<String> _noEquipment = {'none', 'bodyweight', 'noequipment'};

  /// Matches [raw] (free text from the WP 3 schema, e.g. `Push`, `front
  /// delts`, `Dumbbells`) to an enum value: identifier, taxonomy label or a
  /// synonym, ignoring case, spaces and punctuation. Returns the enum name,
  /// or null when nothing matches.
  static String? matchName<T extends Enum>(String raw, List<T> values) {
    final folded = _fold(raw);
    if (folded.isEmpty) return null;
    for (final v in values) {
      if (_fold(v.name) == folded) return v.name;
    }
    final names = {for (final v in values) v.name};
    final viaLabel = _labelToIdentifier[folded];
    if (viaLabel != null && names.contains(viaLabel)) return viaLabel;
    final viaSynonym = _synonyms[folded];
    if (viaSynonym != null && names.contains(viaSynonym)) return viaSynonym;
    return null;
  }

  /// Maps a JSON array of strings (secondary muscles, equipment) to
  /// identifiers. Unmatched items are dropped and listed in `dropped`; text
  /// that is not an array of strings becomes an empty list with the whole
  /// text in `dropped`. [noneWords] are recognised as "nothing" and skipped
  /// silently.
  static ({String json, List<String> dropped}) _mapList<T extends Enum>(
    String json,
    List<T> values, {
    Set<String> noneWords = const {},
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      decoded = null;
    }
    if (decoded is! List || decoded.any((e) => e is! String)) {
      return (json: '[]', dropped: [json]);
    }
    final out = <String>[];
    final dropped = <String>[];
    for (final e in decoded.cast<String>()) {
      final m = matchName(e, values);
      if (m != null) {
        if (!out.contains(m)) out.add(m);
      } else if (!noneWords.contains(_fold(e))) {
        dropped.add(e);
      }
    }
    return (json: jsonEncode(out), dropped: dropped);
  }

  /// Maps an `exercises` row from the v5 shape (or earlier) to v6: `supplied`
  /// from `is_custom`, canonical enum names, aliases and search key.
  ///
  /// An unmatched optional value (a secondary muscle, an equipment item) is
  /// dropped from its list. An unmatched required value (type, category,
  /// primary muscle) cannot be invented, so it is kept as it is and the
  /// exercise stays unreadable to the mappers. Either way
  /// [ExerciseMapping.quarantineReason] is set and the caller copies the
  /// original row to `legacy_quarantine`.
  static ExerciseMapping exercise(Map<String, Object?> row) {
    final out = Map<String, Object?>.of(row);
    if (!out.containsKey('supplied')) {
      final custom = out['is_custom'];
      out['supplied'] = (custom == 1 || custom == true) ? 0 : 1;
    }
    out.remove('is_custom');
    final reasons = <String>[];
    final unreadable = <String>[];
    String required<T extends Enum>(String column, List<T> values) {
      final raw = (row[column] ?? '').toString();
      final m = matchName(raw, values);
      if (m == null) unreadable.add('$column "$raw"');
      return m ?? raw;
    }

    out['type'] = required('type', ExerciseType.values);
    out['category'] = required('category', ExerciseCategory.values);
    out['primary_muscle'] = required('primary_muscle', MuscleGroup.values);
    final secondary = _mapList(
      (row['secondary_muscles_json'] ?? '[]').toString(),
      MuscleGroup.values,
    );
    out['secondary_muscles_json'] = secondary.json;
    if (secondary.dropped.isNotEmpty) {
      reasons.add(
        'Unrecognised secondary muscle(s) dropped: '
        '${secondary.dropped.join(', ')}',
      );
    }
    final equipment = _mapList(
      (row['equipment_json'] ?? '[]').toString(),
      Equipment.values,
      noneWords: _noEquipment,
    );
    out['equipment_json'] = equipment.json;
    if (equipment.dropped.isNotEmpty) {
      reasons.add(
        'Unrecognised equipment dropped: ${equipment.dropped.join(', ')}',
      );
    }
    if (unreadable.isNotEmpty) {
      reasons.insert(
        0,
        'Unrecognised required value(s), exercise kept but unreadable by '
        'the app: ${unreadable.join(', ')}',
      );
    }
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
    return ExerciseMapping(
      row: out,
      quarantineReason: reasons.isEmpty ? null : reasons.join('; '),
    );
  }
}

/// Result of [LegacyTrainingRows.exercise].
final class ExerciseMapping {
  const ExerciseMapping({required this.row, required this.quarantineReason});

  /// The v6-shaped row (always kept).
  final Map<String, Object?> row;

  /// Non-null when the original row must be copied to `legacy_quarantine`.
  final String? quarantineReason;
}
