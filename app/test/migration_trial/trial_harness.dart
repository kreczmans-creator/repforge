import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import 'trial_fixture.dart';
import 'trial_migration.dart';

const retainedExerciseColumns = [
  'id',
  'created_at',
  'updated_at',
  'deleted_at',
  'name',
  'type',
  'category',
  'equipment_json',
  'aliases_json',
  'search_key',
  'copied_from_id',
  'archived',
];

/// One configuration of the trial: how `exercises` and TRN-020 are done.
final class Config {
  const Config(this.label, this.exercises, this.trn020);
  final String label;
  final ExercisesOption exercises;
  final Trn020Option trn020;
}

const configs = [
  Config('A: exercises rebuild', ExercisesOption.rebuild, Trn020Option.none),
  Config(
    'B3: exercises ALTER ADD/DROP COLUMN',
    ExercisesOption.alterColumns,
    Trn020Option.none,
  ),
  Config(
    'T-A: session_sets rebuild (TRN-020 CHECK)',
    ExercisesOption.none,
    Trn020Option.rebuild,
  ),
  Config(
    'T-B: session_sets triggers (TRN-020)',
    ExercisesOption.none,
    Trn020Option.triggers,
  ),
  Config(
    'T-C: session_sets ALTER ADD CONSTRAINT (TRN-020)',
    ExercisesOption.none,
    Trn020Option.alterConstraint,
  ),
  Config(
    'A + T-A: both rebuilt',
    ExercisesOption.rebuild,
    Trn020Option.rebuild,
  ),
  Config(
    'B3 + T-B: columns altered, triggers',
    ExercisesOption.alterColumns,
    Trn020Option.triggers,
  ),
  Config(
    'B3 + T-C: columns altered, constraint added',
    ExercisesOption.alterColumns,
    Trn020Option.alterConstraint,
  ),
];

/// What the v7 fixture held before any migration.
final class Pre {
  Pre(this.path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      tables = userTables(db);
      all = digestAll(db);
      exercisesRetained = digest(
        db,
        'exercises',
        columns: retainedExerciseColumns,
      );
      invalidSetRows = [
        for (final r in db.select(
          'SELECT id, exertion_scale AS s, exertion_value AS v '
          'FROM session_sets ORDER BY id',
        ))
          if (!exertionValid(r['s'], r['v']))
            (r['id']! as String, r['s'], r['v']),
      ];
      invalidSets = invalidSetRows.length;
      sessionSetsCleared = digest(
        db,
        'session_sets',
        transform: (row) =>
            exertionValid(row['exertion_scale'], row['exertion_value'])
            ? row
            : {...row, 'exertion_scale': null, 'exertion_value': null},
      );
      exercises = [
        for (final r in db.select(
          'SELECT id, primary_muscle, secondary_muscles_json, supplied '
          'FROM exercises ORDER BY id',
        ))
          Map<String, Object?>.of(r),
      ];
      quarantineMaxId =
          db.select('SELECT max(id) AS m FROM legacy_quarantine').first['m']!
              as int;
      userVersion =
          db.select('PRAGMA user_version').first['user_version']! as int;
    } finally {
      db.close();
    }
  }

  final String path;
  late final List<String> tables;
  late final Map<String, Digest> all;
  late final Digest exercisesRetained;
  late final Digest sessionSetsCleared;
  late final int invalidSets;
  late final List<(String, Object?, Object?)> invalidSetRows;
  late final List<Map<String, Object?>> exercises;
  late final int quarantineMaxId;
  late final int userVersion;
}

/// Opens [path] through the trial database class (drift upgrade path).
TrialDb openTrial(
  String path,
  TrialPlan plan, {
  bool keysOnAtOpen = true,
  int? cachePages,
}) => TrialDb(
  NativeDatabase(
    File(path),
    setup: (raw) {
      if (keysOnAtOpen) raw.execute('PRAGMA foreign_keys = ON');
      if (cachePages != null) raw.execute('PRAGMA cache_size = $cachePages');
    },
  ),
  plan,
);

/// Runs the migration on [path] and returns the elapsed milliseconds. The
/// error, if any, is returned instead of thrown.
Future<(int, Object?)> runMigration(
  String path,
  TrialPlan plan, {
  bool keysOnAtOpen = true,
  int? cachePages,
}) async {
  final db = openTrial(
    path,
    plan,
    keysOnAtOpen: keysOnAtOpen,
    cachePages: cachePages,
  );
  final sw = Stopwatch()..start();
  Object? error;
  try {
    await db.customSelect('SELECT 1').get();
  } on Object catch (e) {
    error = e;
  }
  sw.stop();
  try {
    await db.close();
  } on Object {
    // A failed open can fail again on close; the file is what matters.
  }
  return (sw.elapsedMilliseconds, error);
}

/// Outcome of checking a migrated database file.
final class Verification {
  final failures = <String>[];
  final facts = <String, Object?>{};
  bool get ok => failures.isEmpty;
}

String _one(Database db, String sql) => '${db.select(sql).first.values.first}';

/// Expected `exercise_targets` rows and report counts, computed in Dart from
/// the v7 values (independent of the SQL used by the migration).
({
  Set<String> targets,
  int quarantined,
  int secondaryEqualPrimary,
  int fullBody,
  int withoutPrimary,
  int duplicateWithinList,
})
expectedTargets(Pre pre) {
  final targets = <String>{};
  var quarantined = 0;
  var dup = 0;
  var fullBody = 0;
  var withoutPrimary = 0;
  var dupList = 0;
  for (final e in pre.exercises) {
    final id = e['id']! as String;
    final primary = e['primary_muscle']! as String;
    if (muscleIds.contains(primary)) {
      targets.add('$id|$primary|primary|0');
    } else {
      quarantined++;
      withoutPrimary++;
    }
    final list = (jsonDecode(e['secondary_muscles_json']! as String) as List)
        .cast<String>();
    final seen = <String>{};
    final seenAny = <String>{};
    for (var i = 0; i < list.length; i++) {
      final s = list[i];
      if (s == 'fullBody') fullBody++;
      if (!muscleIds.contains(s)) {
        quarantined++;
        continue;
      }
      if (!seenAny.add(s)) dupList++;
      if (s == primary) {
        dup++;
        continue;
      }
      if (seen.add(s)) targets.add('$id|$s|secondary|${i + 1}');
    }
  }
  return (
    targets: targets,
    quarantined: quarantined,
    secondaryEqualPrimary: dup,
    fullBody: fullBody,
    withoutPrimary: withoutPrimary,
    duplicateWithinList: dupList,
  );
}

/// Expected new `legacy_quarantine` rows from the exercise muscle values,
/// as sorted JSON strings of (table, row id, reason, original).
List<String> expectedQuarantine(Pre pre) {
  final out = <String>[];
  String row(String id, String reason, Object original) =>
      jsonEncode(['exercises', id, reason, original]);
  for (final e in pre.exercises) {
    final id = e['id']! as String;
    final primary = e['primary_muscle']! as String;
    if (!muscleIds.contains(primary)) {
      out.add(row(id, 'unmapped primary muscle', {'primary_muscle': primary}));
    }
    final list = (jsonDecode(e['secondary_muscles_json']! as String) as List)
        .cast<String>();
    for (final s in list) {
      if (!muscleIds.contains(s)) {
        out.add(row(id, 'unmapped secondary muscle', {'secondary_muscle': s}));
      }
    }
  }
  return out..sort();
}

List<String> expectedSetQuarantine(Pre pre) => [
  for (final (id, scale, value) in pre.invalidSetRows)
    jsonEncode([
      'session_sets',
      id,
      'TRN-020 exertion outside the rule',
      {'exertion_scale': scale, 'exertion_value': value},
    ]),
]..sort();

List<String> actualQuarantine(Database db, Pre pre, String table) => [
  for (final r in db.select(
    'SELECT source_table, row_id, reason, original_json FROM '
    'legacy_quarantine WHERE id > ? AND source_table = ?',
    [pre.quarantineMaxId, table],
  ))
    jsonEncode([
      r['source_table'],
      r['row_id'],
      r['reason'],
      jsonDecode(r['original_json']! as String),
    ]),
]..sort();

bool sameList(List<String> a, List<String> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

/// Checks a migrated file against the fixture: integrity, foreign keys,
/// version and value equality (plan sections 17.2 and 17.4).
Verification verifyMigrated(String path, Pre pre, Config c) {
  final v = Verification();
  final db = sqlite3.open(path);
  try {
    db.execute('PRAGMA foreign_keys = ON');
    final integrity = _one(db, 'PRAGMA integrity_check');
    final fk = db.select('PRAGMA foreign_key_check');
    final version = db.select('PRAGMA user_version').first.values.first;
    v.facts['integrity_check'] = integrity;
    v.facts['foreign_key_check_rows'] = fk.length;
    v.facts['user_version'] = version;
    if (integrity != 'ok') v.failures.add('integrity_check: $integrity');
    if (fk.isNotEmpty) v.failures.add('foreign_key_check: ${fk.length} rows');
    if (version != 8) v.failures.add('user_version $version');

    final skip = <String>{'legacy_quarantine'};
    if (c.exercises != ExercisesOption.none) {
      skip.add('exercises');
      final cols = columnsOf(db, 'exercises');
      for (final gone in [
        'primary_muscle',
        'secondary_muscles_json',
        'supplied',
      ]) {
        if (cols.contains(gone)) v.failures.add('column $gone still present');
      }
      final now = digest(db, 'exercises', columns: retainedExerciseColumns);
      v.facts['exercises_retained_equal'] = now == pre.exercisesRetained;
      if (now != pre.exercisesRetained) {
        v.failures.add(
          'exercises retained columns differ: ${pre.exercisesRetained} vs $now',
        );
      }
      // New column values.
      final bySupplied = {
        for (final e in pre.exercises) e['id']! as String: e['supplied'],
      };
      var wrong = 0;
      for (final r in db.select(
        'SELECT id, source, provider_id, revision, mechanics, laterality, '
        'difficulty, retired_at FROM exercises',
      )) {
        final sys = bySupplied[r['id']] == 1;
        final ok =
            r['source'] == (sys ? 'system' : 'user') &&
            r['provider_id'] == (sys ? 'repforge' : null) &&
            r['revision'] == (sys ? 1 : null) &&
            r['mechanics'] == null &&
            r['laterality'] == null &&
            r['difficulty'] == null &&
            r['retired_at'] == null;
        if (!ok) wrong++;
      }
      v.facts['new_column_values_wrong'] = wrong;
      if (wrong != 0) v.failures.add('$wrong exercises with wrong new values');
      // Targets.
      final exp = expectedTargets(pre);
      final actual = {
        for (final r in db.select(
          'SELECT exercise_id, node_id, role, ordinal FROM exercise_targets',
        ))
          '${r['exercise_id']}|${r['node_id']}|${r['role']}|${r['ordinal']}',
      };
      v.facts['targets'] = actual.length;
      v.facts['targets_match_expected'] =
          actual.length == exp.targets.length &&
          actual.containsAll(exp.targets);
      if (v.facts['targets_match_expected'] != true) {
        v.failures.add(
          'targets differ: expected ${exp.targets.length}, got ${actual.length}',
        );
      }
      final newQ =
          db.select(
                "SELECT count(*) AS c FROM legacy_quarantine WHERE id > ? "
                "AND source_table = 'exercises'",
                [pre.quarantineMaxId],
              ).first['c']!
              as int;
      v.facts['quarantined_exercise_values'] = newQ;
      v.facts['secondary_equal_primary_not_duplicated'] =
          exp.secondaryEqualPrimary;
      v.facts['fullBody_secondary_kept'] = exp.fullBody;
      if (newQ != exp.quarantined) {
        v.failures.add('quarantine rows $newQ, expected ${exp.quarantined}');
      }
      v.facts['exercise_quarantine_rows_match_expected'] = sameList(
        actualQuarantine(db, pre, 'exercises'),
        expectedQuarantine(pre),
      );
      if (v.facts['exercise_quarantine_rows_match_expected'] != true) {
        v.failures.add('exercise quarantine content differs');
      }
      final noPrimary =
          db
                  .select(
                    'SELECT count(*) AS c FROM exercises e WHERE NOT EXISTS '
                    '(SELECT 1 FROM exercise_targets t WHERE '
                    "t.exercise_id = e.id AND t.role = 'primary')",
                  )
                  .first['c']!
              as int;
      v.facts['exercises_without_primary_target'] = noPrimary;
      if (noPrimary != exp.withoutPrimary) {
        v.failures.add('exercises without primary: $noPrimary');
      }
      v.facts['secondary_duplicated_within_list'] = exp.duplicateWithinList;
    } else {
      skip.add('exercises');
      final now = digest(db, 'exercises');
      if (now != pre.all['exercises']) v.failures.add('exercises changed');
    }

    if (c.trn020 != Trn020Option.none) {
      skip.add('session_sets');
      final now = digest(db, 'session_sets');
      v.facts['session_sets_equal_after_clearing'] =
          now == pre.sessionSetsCleared;
      if (now != pre.sessionSetsCleared) {
        v.failures.add(
          'session_sets differ: ${pre.sessionSetsCleared} vs $now',
        );
      }
      final q =
          db.select(
                "SELECT count(*) AS c FROM legacy_quarantine WHERE id > ? "
                "AND source_table = 'session_sets'",
                [pre.quarantineMaxId],
              ).first['c']!
              as int;
      v.facts['quarantined_sets'] = q;
      if (q != pre.invalidSets) {
        v.failures.add('set quarantine rows $q, expected ${pre.invalidSets}');
      }
      v.facts['set_quarantine_rows_match_expected'] = sameList(
        actualQuarantine(db, pre, 'session_sets'),
        expectedSetQuarantine(pre),
      );
      if (v.facts['set_quarantine_rows_match_expected'] != true) {
        v.failures.add('set quarantine content differs');
      }
    }
    // Untouched tables, plus the old quarantine rows.
    for (final t in pre.tables) {
      if (skip.contains(t)) continue;
      final now = digest(db, t);
      if (now != pre.all[t]) v.failures.add('table $t changed');
    }
    final oldQ = digest(
      db,
      'legacy_quarantine',
      where: 'id <= ${pre.quarantineMaxId}',
    );
    if (oldQ != pre.all['legacy_quarantine']) {
      v.failures.add('old legacy_quarantine rows changed');
    }
    v.facts['file_bytes'] = File(path).lengthSync();
  } finally {
    db.close();
  }
  return v;
}

/// Violating statements that must be rejected, as (label, sql).
List<(String, String)> exerciseViolations() {
  String ins(String cols, String vals) =>
      'INSERT INTO exercises (id, created_at, updated_at, name, type, '
      'category, equipment_json, $cols) VALUES '
      "('zz', 't', 't', 'n', 'weighted', 'push', '[]', $vals)";
  return [
    ('source = bogus', ins('source', "'bogus'")),
    ('source = NULL', ins('source', 'NULL')),
    ('mechanics = weird', ins('mechanics', "'weird'")),
    ('laterality = x', ins('laterality', "'x'")),
    ('difficulty = x', ins('difficulty', "'x'")),
    ('revision = 0', ins('revision', '0')),
    ('archived = 2', ins('archived', '2')),
    (
      'duplicate id',
      "INSERT INTO exercises (id, created_at, updated_at, name, type, "
          "category, equipment_json) VALUES "
          "('ex-0001', 't', 't', 'n', 'weighted', 'push', '[]')",
    ),
    (
      'name = NULL',
      "INSERT INTO exercises (id, created_at, updated_at, name, type, "
          "category, equipment_json) VALUES "
          "('zz', 't', 't', NULL, 'weighted', 'push', '[]')",
    ),
    (
      'target for missing exercise (FK)',
      "INSERT INTO exercise_targets VALUES ('nope', 'chest', 'primary', 0)",
    ),
    (
      'target with unknown node (FK)',
      "INSERT INTO exercise_targets VALUES ('ex-0001', 'nope', 'primary', 0)",
    ),
    (
      'target role = other',
      "INSERT INTO exercise_targets VALUES ('ex-0001', 'lats', 'other', 0)",
    ),
  ];
}

List<(String, String)> exertionViolations() {
  String ins(String scale, String value) =>
      'INSERT INTO session_sets (id, session_id, exercise_id, '
      'exercise_order, set_order, type, exertion_scale, exertion_value) '
      "VALUES ('zz', 'ws-0', 'ex-0001', 0, 0, 'weighted', $scale, $value)";
  return [
    ('rpe 7.3', ins("'rpe'", '7.3')),
    ('rpe 0.5', ins("'rpe'", '0.5')),
    ('rpe 10.5', ins("'rpe'", '10.5')),
    ('rir 2.5', ins("'rir'", '2.5')),
    ('rir 6', ins("'rir'", '6')),
    ('rir -1', ins("'rir'", '-1')),
    ("scale 'borg'", ins("'borg'", '5')),
    ('value without scale', ins('NULL', '6')),
    ('scale without value', ins("'rpe'", 'NULL')),
  ];
}

List<(String, String)> exertionValid_() {
  String ins(String scale, String value) =>
      'INSERT INTO session_sets (id, session_id, exercise_id, '
      'exercise_order, set_order, type, exertion_scale, exertion_value) '
      "VALUES ('zz', 'ws-0', 'ex-0001', 0, 0, 'weighted', $scale, $value)";
  return [
    ('rpe 1', ins("'rpe'", '1')),
    ('rpe 8.5', ins("'rpe'", '8.5')),
    ('rpe 10', ins("'rpe'", '10')),
    ('rir 0', ins("'rir'", '0')),
    ('rir 5', ins("'rir'", '5')),
    ('none', ins('NULL', 'NULL')),
  ];
}

/// Result of trying [cases] on a migrated file: how many were rejected. Each
/// statement runs in a savepoint that is rolled back.
({int rejected, int total, List<String> accepted}) tryStatements(
  String path,
  List<(String, String)> cases,
) {
  final db = sqlite3.open(path);
  try {
    db.execute('PRAGMA foreign_keys = ON');
    var rejected = 0;
    final accepted = <String>[];
    for (final (label, sql) in cases) {
      db.execute('SAVEPOINT t');
      try {
        db.execute(sql);
        accepted.add(label);
      } on SqliteException {
        rejected++;
      } finally {
        db.execute('ROLLBACK TO t');
        db.execute('RELEASE t');
      }
    }
    return (rejected: rejected, total: cases.length, accepted: accepted);
  } finally {
    db.close();
  }
}

/// Deleting an exercise must cascade to its targets (proves the foreign key
/// still points at the rebuilt table). Returns targets removed.
int cascadeCheck(String path) {
  final db = sqlite3.open(path);
  try {
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('SAVEPOINT t');
    final before =
        db
                .select(
                  "SELECT count(*) AS c FROM exercise_targets "
                  "WHERE exercise_id = 'ex-0100'",
                )
                .first['c']!
            as int;
    db.execute("DELETE FROM exercises WHERE id = 'ex-0100'");
    final after =
        db
                .select(
                  "SELECT count(*) AS c FROM exercise_targets "
                  "WHERE exercise_id = 'ex-0100'",
                )
                .first['c']!
            as int;
    db.execute('ROLLBACK TO t');
    db.execute('RELEASE t');
    return before - after;
  } finally {
    db.close();
  }
}

/// Column shape (order-independent) of [table].
Set<String> shapeOf(Database db, String table) => {
  for (final r in db.select('PRAGMA table_info("$table")'))
    '${r['name']}|${r['type']}|${r['notnull']}|${r['dflt_value']}|${r['pk']}',
};

double median(List<int> xs) {
  final s = [...xs]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2].toDouble() : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}
