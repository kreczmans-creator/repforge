import 'dart:convert';

/// Frozen copy of `LegacyTrainingRows` (`lib/data/db/legacy_training_rows.dart`)
/// as the schema v6 migration step uses it (WP 8 stage 3b-3, review M3).
///
/// The historical step v5 → v6 must give the same result forever, so this
/// copy does not depend on live code:
/// - the enum identifiers of `ExerciseType`, `ExerciseCategory`,
///   `MuscleGroup` and `Equipment` are frozen as text lists in their
///   declaration order;
/// - `exerciseSearchKey` and `normaliseSearchKey` are frozen with their
///   diacritic table. Lower-casing still uses Dart's `String.toLowerCase`, as
///   production does; `historical_steps_test.dart` pins a Unicode sample.
///
/// Ranges, labels, synonyms and reason texts are copied unchanged.
/// Production restore keeps using `LegacyTrainingRows`; a test proves both
/// classes agree today. Pinned by `fixtures/MANIFEST_3b3.sha256`: never edit.
abstract final class LegacyTrainingRowsV6 {
  /// `ExerciseType` identifiers at schema v7.
  static const exerciseTypes = [
    'weighted',
    'bodyweight',
    'assisted',
    'timed',
    'distance',
    'cardio',
  ];

  /// `ExerciseCategory` identifiers at schema v7.
  static const exerciseCategories = [
    'push',
    'pull',
    'legs',
    'core',
    'fullBody',
    'cardio',
    'mobility',
  ];

  /// `MuscleGroup` identifiers at schema v7.
  static const muscleGroups = [
    'chest',
    'frontDelts',
    'sideDelts',
    'rearDelts',
    'triceps',
    'biceps',
    'forearms',
    'upperBack',
    'lats',
    'lowerBack',
    'abs',
    'obliques',
    'glutes',
    'quadriceps',
    'hamstrings',
    'adductors',
    'abductors',
    'calves',
    'fullBody',
  ];

  /// `Equipment` identifiers at schema v7.
  static const equipment = [
    'barbell',
    'ezBar',
    'trapBar',
    'dumbbell',
    'kettlebell',
    'cable',
    'machine',
    'smithMachine',
    'bench',
    'squatRack',
    'pullUpBar',
    'dipBars',
    'resistanceBand',
    'plate',
    'medicineBall',
    'rings',
    'treadmill',
    'bike',
    'rower',
    'elliptical',
    'skippingRope',
  ];

  static bool _between(Object? v, num lo, num hi) =>
      v is num && v >= lo && v <= hi;

  static SanitisedRowV6 _result(
    Map<String, Object?> row,
    Map<String, Object?> out,
    List<String> nulled,
  ) => SanitisedRowV6(
    row: out,
    nulledColumns: nulled,
    reason: nulled.isEmpty
        ? 'valid'
        : 'Out-of-range value set to NULL: ${nulled.join(', ')}',
  );

  /// `session_sets` row (the same shape in v5 and v6).
  static SanitisedRowV6 sessionSet(Map<String, Object?> row) {
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
  /// shape (`reps_min` = `reps_max` = `target_reps`, when valid).
  static SanitisedRowV6 planExercise(Map<String, Object?> row) {
    final sets = row['target_sets'];
    final order = row['sort_order'];
    if (!_between(sets, 1, 20) || order is! num || order < 0) {
      return const SanitisedRowV6(
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

  static String _fold(String raw) =>
      raw.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  /// Display labels that differ from the identifier once folded.
  static const Map<String, String> labelToIdentifier = {
    // Equipment labels.
    'dumbbells': 'dumbbell',
    'cablestation': 'cable',
    'weightplate': 'plate',
    'gymnasticrings': 'rings',
    'exercisebike': 'bike',
    'rowingmachine': 'rower',
    'crosstrainer': 'elliptical',
  };

  /// The synonym table (folded text to identifier).
  static const Map<String, String> synonyms = {
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

  /// Equipment texts that mean "no equipment".
  static const Set<String> noEquipment = {'none', 'bodyweight', 'noequipment'};

  /// Matches [raw] to one of [names]: identifier, label or synonym, ignoring
  /// case, spaces and punctuation. Null when nothing matches.
  static String? matchName(String raw, List<String> names) {
    final folded = _fold(raw);
    if (folded.isEmpty) return null;
    for (final n in names) {
      if (_fold(n) == folded) return n;
    }
    final viaLabel = labelToIdentifier[folded];
    if (viaLabel != null && names.contains(viaLabel)) return viaLabel;
    final viaSynonym = synonyms[folded];
    if (viaSynonym != null && names.contains(viaSynonym)) return viaSynonym;
    return null;
  }

  static ({String json, List<String> dropped}) _mapList(
    String json,
    List<String> names, {
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
      final m = matchName(e, names);
      if (m != null) {
        if (!out.contains(m)) out.add(m);
      } else if (!noneWords.contains(_fold(e))) {
        dropped.add(e);
      }
    }
    return (json: jsonEncode(out), dropped: dropped);
  }

  /// Maps an `exercises` row from the v5 shape (or earlier) to v6.
  static ExerciseMappingV6 exercise(Map<String, Object?> row) {
    final out = Map<String, Object?>.of(row);
    if (!out.containsKey('supplied')) {
      final custom = out['is_custom'];
      out['supplied'] = (custom == 1 || custom == true) ? 0 : 1;
    }
    out.remove('is_custom');
    final reasons = <String>[];
    final unreadable = <String>[];
    String required(String column, List<String> names) {
      final raw = (row[column] ?? '').toString();
      final m = matchName(raw, names);
      if (m == null) unreadable.add('$column "$raw"');
      return m ?? raw;
    }

    out['type'] = required('type', exerciseTypes);
    out['category'] = required('category', exerciseCategories);
    out['primary_muscle'] = required('primary_muscle', muscleGroups);
    final secondary = _mapList(
      (row['secondary_muscles_json'] ?? '[]').toString(),
      muscleGroups,
    );
    out['secondary_muscles_json'] = secondary.json;
    if (secondary.dropped.isNotEmpty) {
      reasons.add(
        'Unrecognised secondary muscle(s) dropped: '
        '${secondary.dropped.join(', ')}',
      );
    }
    final mappedEquipment = _mapList(
      (row['equipment_json'] ?? '[]').toString(),
      equipment,
      noneWords: noEquipment,
    );
    out['equipment_json'] = mappedEquipment.json;
    if (mappedEquipment.dropped.isNotEmpty) {
      reasons.add(
        'Unrecognised equipment dropped: '
        '${mappedEquipment.dropped.join(', ')}',
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
    out['search_key'] = searchKey((row['name'] ?? '').toString(), aliases);
    return ExerciseMappingV6(
      row: out,
      quarantineReason: reasons.isEmpty ? null : reasons.join('; '),
    );
  }

  // ---- Frozen `exerciseSearchKey` / `normaliseSearchKey` -------------------

  static const _diacritics = {
    'àáâäãå': 'a',
    'èéêë': 'e',
    'ìíîï': 'i',
    'òóôöõ': 'o',
    'ùúûü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };

  static final Map<String, String> _foldMap = {
    for (final e in _diacritics.entries)
      for (final ch in e.key.split('')) ch: e.value,
  };

  /// Search key of the v6 step: [name] and [aliases], space separated,
  /// lower-cased, with the frozen diacritic table applied per UTF-16 unit.
  static String searchKey(String name, Iterable<String> aliases) {
    final buf = StringBuffer();
    for (final ch in [name, ...aliases].join(' ').toLowerCase().split('')) {
      buf.write(_foldMap[ch] ?? ch);
    }
    return buf.toString();
  }
}

/// Frozen copy of `SanitisedRow`.
final class SanitisedRowV6 {
  const SanitisedRowV6({
    required this.row,
    required this.nulledColumns,
    required this.reason,
  });

  final Map<String, Object?>? row;
  final List<String> nulledColumns;
  final String reason;

  bool get unchanged => row != null && nulledColumns.isEmpty;
}

/// Frozen copy of `ExerciseMapping`.
final class ExerciseMappingV6 {
  const ExerciseMappingV6({required this.row, required this.quarantineReason});

  final Map<String, Object?> row;
  final String? quarantineReason;
}
