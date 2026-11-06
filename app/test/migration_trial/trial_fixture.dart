import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import '../data/generated_migrations/schema_v7.dart' as v7;

/// Muscle identifiers used by schema v7 data (`MuscleGroup` enum names).
const muscleIds = [
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

const fixtureExerciseCount = 5000;
const fixtureSetCount = 100000;
const _stamp = '2026-10-01T08:00:00.000Z';

/// Facts about the generated fixture, recorded in the results.
final class FixtureFacts {
  FixtureFacts(this.counts, this.bytes, this.sqliteVersion);
  final Map<String, int> counts;
  final int bytes;
  final String sqliteVersion;
}

/// Creates a deterministic schema-v7 database file (seed 20261106).
///
/// The schema comes from the generated v7 snapshot used by the migration
/// tests. Rows are written with plain SQL in one transaction. The data
/// includes null and edge values, legacy muscle text, legacy exertion values
/// that break the planned TRN-020 rule, and loose references to exercises
/// that do not exist.
Future<FixtureFacts> buildV7Fixture(String path) async {
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  final creator = v7.DatabaseAtV7(NativeDatabase(f));
  await creator.customSelect('SELECT 1').get();
  await creator.close();

  final db = sqlite3.open(path);
  try {
    db.execute('BEGIN');
    final rnd = Random(20261106);
    _exercises(db, rnd);
    _training(db, rnd);
    _others(db, rnd);
    db.execute('COMMIT');
    final counts = <String, int>{};
    final tables = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    for (final t in tables) {
      final n = t['name'] as String;
      counts[n] =
          db.select('SELECT count(*) AS c FROM "$n"').first['c']! as int;
    }
    final version =
        db.select('SELECT sqlite_version() AS v').first['v']! as String;
    return FixtureFacts(counts, f.lengthSync(), version);
  } finally {
    db.close();
  }
}

String _pick(Random r, List<String> xs) => xs[r.nextInt(xs.length)];

void _exercises(Database db, Random r) {
  const types = [
    'weighted',
    'weighted',
    'weighted',
    'bodyweight',
    'assisted',
    'timed',
    'distance',
    'cardio',
  ];
  const categories = [
    'push',
    'pull',
    'legs',
    'core',
    'fullBody',
    'cardio',
    'mobility',
  ];
  const equipment = [
    'barbell',
    'dumbbell',
    'machine',
    'cable',
    'bodyweight',
    'kettlebell',
    'bench',
  ];
  final stmt = db.prepare(
    'INSERT INTO exercises (id, created_at, updated_at, deleted_at, name, '
    'type, category, primary_muscle, secondary_muscles_json, '
    'equipment_json, aliases_json, search_key, supplied, copied_from_id, '
    'archived) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
  );
  for (var i = 0; i < fixtureExerciseCount; i++) {
    final id = 'ex-${i.toString().padLeft(4, '0')}';
    final supplied = i < 89 ? 1 : 0;
    var name = 'Exercise ${i.toString().padLeft(4, '0')} variant ${i % 17}';
    if (i % 500 == 7) name = 'Écarté ✓ ${i}ß';
    if (i % 701 == 3) name = 'O\'Neil "press" $i';
    if (i % 1499 == 11) name = 'Long ${'x' * 2000} $i';
    final roll = r.nextInt(100);
    String primary;
    if (roll < 94) {
      primary = _pick(r, muscleIds);
    } else if (roll < 97) {
      primary = 'rotator cuff'; // legacy free text kept by v6
    } else if (roll < 99) {
      primary = 'Neck'; // unmapped legacy text
    } else {
      primary = ''; // edge: empty but NOT NULL
    }
    final nSecondary = r.nextInt(100) < 2 ? 0 : r.nextInt(4);
    final secondary = <String>[];
    while (secondary.length < nSecondary) {
      final s = _pick(r, muscleIds);
      if (!secondary.contains(s)) secondary.add(s);
    }
    final e = r.nextInt(100);
    if (e < 8 && muscleIds.contains(primary)) secondary.add(primary);
    if (e >= 8 && e < 11 && !secondary.contains('fullBody')) {
      secondary.add('fullBody');
    }
    if (e == 11) secondary.add('traps'); // unmapped secondary
    final eq = {for (var k = 0; k < r.nextInt(3); k++) _pick(r, equipment)};
    final aliases = r.nextInt(100) < 70
        ? '[]'
        : jsonEncode(['alias ${i}a', if (r.nextBool()) 'Äpfel $i']);
    stmt.execute([
      id,
      _stamp,
      _stamp,
      i % 53 == 0 ? '2026-10-02T09:30:00.000Z' : null,
      name,
      _pick(r, types),
      _pick(r, categories),
      primary,
      jsonEncode(secondary),
      jsonEncode(eq.toList()),
      aliases,
      name.toLowerCase(),
      supplied,
      supplied == 0 && r.nextInt(100) < 30
          ? 'ex-${r.nextInt(89).toString().padLeft(4, '0')}'
          : null,
      i % 20 == 0 ? 1 : 0,
    ]);
  }
  stmt.close();
}

/// Index of an exercise for a new set: skewed toward the first ids.
String _exerciseFor(Random r) {
  final u = r.nextDouble();
  final idx = (fixtureExerciseCount * u * u * u).floor();
  return 'ex-${idx.toString().padLeft(4, '0')}';
}

void _training(Database db, Random r) {
  // Plans and plan exercises.
  final plan = db.prepare(
    'INSERT INTO workout_plans (id, created_at, updated_at, deleted_at, '
    'name, split, scheduled_weekdays_json, archived) VALUES (?,?,?,?,?,?,?,?)',
  );
  for (var p = 0; p < 40; p++) {
    plan.execute([
      'plan-$p',
      _stamp,
      _stamp,
      null,
      'Plan $p',
      p % 3 == 0 ? null : 'PPL',
      '[${p % 7}]',
      p % 10 == 0 ? 1 : 0,
    ]);
  }
  plan.close();
  final pe = db.prepare(
    'INSERT INTO plan_exercises (id, plan_id, exercise_id, sort_order, '
    'target_sets, reps_min, reps_max, target_load_kg, target_duration_sec, '
    'target_metres, rest_seconds) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
  );
  for (var i = 0; i < 400; i++) {
    final hasReps = i % 4 != 0;
    pe.execute([
      'pe-$i',
      'plan-${i % 40}',
      _exerciseFor(r),
      i ~/ 40,
      1 + i % 20,
      hasReps ? 5 : null,
      hasReps ? 8 + i % 5 : null,
      i % 3 == 0 ? null : (i % 40) * 2.5,
      i % 11 == 0 ? 60 : null,
      i % 13 == 0 ? 400.5 : null,
      i % 5 == 0 ? null : 90,
    ]);
  }
  pe.close();

  final sessionStmt = db.prepare(
    'INSERT INTO workout_sessions (id, created_at, updated_at, deleted_at, '
    'name, plan_id, started_at, ended_at, notes) VALUES (?,?,?,?,?,?,?,?,?)',
  );
  final entryStmt = db.prepare(
    'INSERT INTO session_exercises (id, session_id, position, exercise_id, '
    'note) VALUES (?,?,?,?,?)',
  );
  final setStmt = db.prepare(
    'INSERT INTO session_sets (id, session_id, exercise_id, exercise_order, '
    'set_order, type, load_kg, reps, assistance_kg, duration_sec, metres, '
    'average_heart_rate, energy_kcal, energy_provenance, completed, '
    'exertion_scale, exertion_value, rest_seconds, note, set_kind, '
    'session_exercise_id) VALUES '
    '(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
  );
  var sets = 0;
  var sessionNo = 0;
  var entryNo = 0;
  while (sets < fixtureSetCount) {
    final sid = 'ws-$sessionNo';
    sessionStmt.execute([
      sid,
      _stamp,
      _stamp,
      sessionNo % 97 == 0 ? '2026-10-03T00:00:00.000Z' : null,
      'Session $sessionNo',
      sessionNo % 4 == 0 ? null : 'plan-${sessionNo % 40}',
      '2026-0${1 + sessionNo % 9}-1${sessionNo % 10}T07:00:00.000Z',
      sessionNo % 9 == 0 ? null : '2026-01-01T08:00:00.000Z',
      sessionNo % 13 == 0 ? 'Notes ✓ $sessionNo' : '',
    ]);
    final entries = 3 + r.nextInt(6);
    for (var pos = 0; pos < entries && sets < fixtureSetCount; pos++) {
      final eid = 'se-$entryNo';
      entryNo++;
      // A few loose references to exercises that do not exist (no FK).
      final ex = sets % 2000 == 5 ? 'ex-missing-$sets' : _exerciseFor(r);
      entryStmt.execute([
        eid,
        sid,
        pos,
        ex,
        entryNo % 50 == 0
            ? 'n' * 4000
            : (entryNo % 7 == 0 ? 'felt heavy' : null),
      ]);
      final n = 2 + r.nextInt(5);
      for (var s = 0; s < n && sets < fixtureSetCount; s++) {
        _insertSet(setStmt, r, sets, sid, eid, ex, pos, s);
        sets++;
      }
    }
    sessionNo++;
  }
  sessionStmt.close();
  entryStmt.close();
  setStmt.close();

  // Scheduled workouts, splits.
  final sw = db.prepare(
    'INSERT INTO scheduled_workouts (id, created_at, updated_at, '
    'deleted_at, day, source_day, plan_id, origin, status, session_id) '
    'VALUES (?,?,?,?,?,?,?,?,?,?)',
  );
  for (var i = 0; i < 300; i++) {
    sw.execute([
      'sw-$i',
      _stamp,
      _stamp,
      null,
      '2026-11-${(1 + i % 28).toString().padLeft(2, '0')}',
      '2026-11-${(1 + i % 28).toString().padLeft(2, '0')}',
      'plan-${i % 40}',
      const ['date', 'weekday', 'split'][i % 3],
      const ['planned', 'skipped', 'done'][i % 3],
      i % 3 == 2 ? 'ws-$i' : null,
    ]);
  }
  sw.close();
  final ts = db.prepare(
    'INSERT INTO training_splits (id, created_at, updated_at, deleted_at, '
    'name, cycle_days, sort_order) VALUES (?,?,?,?,?,?,?)',
  );
  final sd = db.prepare(
    'INSERT INTO split_days (id, split_id, day_index, plan_id) '
    'VALUES (?,?,?,?)',
  );
  for (var i = 0; i < 5; i++) {
    ts.execute(['split-$i', _stamp, _stamp, null, 'Split $i', 7, i]);
    for (var d = 0; d < 7; d++) {
      sd.execute(['sd-$i-$d', 'split-$i', d, d == 6 ? null : 'plan-$d']);
    }
  }
  ts.close();
  sd.close();
}

void _insertSet(
  PreparedStatement st,
  Random r,
  int n,
  String sid,
  String eid,
  String ex,
  int pos,
  int setOrder,
) {
  const types = ['weighted', 'bodyweight', 'assisted', 'timed', 'cardio'];
  final type = types[n % types.length == 4 ? 4 : r.nextInt(4)];
  double? load;
  int? reps;
  double? assist;
  int? dur;
  double? metres;
  int? hr;
  double? kcal;
  String? prov;
  switch (type) {
    case 'weighted':
      load = n % 997 == 0
          ? 1000.0
          : (n % 991 == 0 ? 0.0 : r.nextInt(120) * 2.5);
      reps = n % 983 == 0 ? 100 : 1 + r.nextInt(30);
    case 'bodyweight':
      reps = 1 + r.nextInt(40);
    case 'assisted':
      assist = r.nextInt(40) * 2.5;
      reps = 1 + r.nextInt(15);
    case 'timed':
      dur = 10 + r.nextInt(300);
      load = n % 5 == 0 ? r.nextInt(20) * 2.5 : null;
    case 'cardio':
      dur = 300 + r.nextInt(3000);
      metres = r.nextInt(100) < 70 ? 500.0 + r.nextInt(8000) : null;
      hr = r.nextInt(100) < 60
          ? (n % 971 == 0 ? 250 : 90 + r.nextInt(90))
          : null;
      if (r.nextInt(100) < 50) {
        kcal = 50.0 + r.nextInt(500);
        prov = r.nextBool() ? 'userEntered' : 'estimated';
      }
  }
  // Exertion. 2 % of sets carry a legacy value the TRN-020 rule rejects.
  String? scale;
  double? value;
  final x = r.nextInt(1000);
  if (x < 450) {
    // not recorded
  } else if (x < 780) {
    scale = 'rpe';
    value = 1 + r.nextInt(19) * 0.5; // 1 .. 10 in halves
  } else if (x < 980) {
    scale = 'rir';
    value = r.nextInt(6).toDouble(); // 0 .. 5
  } else {
    const legacy = <(String?, double?)>[
      ('rpe', 0.0),
      ('rpe', 0.5),
      ('rpe', 7.3),
      ('rpe', 9.75),
      ('rir', 6.0),
      ('rir', 7.5),
      ('rir', 2.5),
      ('rir', 0.5),
      ('borg', 5.0),
      (null, 6.0),
      ('rir', null),
      ('rpe', null),
    ];
    final l = legacy[x % legacy.length];
    scale = l.$1;
    value = l.$2;
  }
  st.execute([
    'set-$n',
    sid,
    ex,
    pos,
    setOrder,
    type,
    load,
    reps,
    assist,
    dur,
    metres,
    hr,
    kcal,
    prov,
    n % 20 == 0 ? 0 : 1,
    scale,
    value,
    n % 3 == 0 ? null : (n % 211 == 0 ? 3600 : 60 + r.nextInt(240)),
    n % 40 == 0 ? 'Note ✓ ünï $n' : null,
    n % 10 == 0 ? 'warmUp' : (n % 20 == 1 ? 'failure' : 'working'),
    eid,
  ]);
}

void _others(Database db, Random r) {
  final m = db.prepare(
    'INSERT INTO measurements (id, created_at, updated_at, deleted_at, site, '
    'value, recorded_at, note) VALUES (?,?,?,?,?,?,?,?)',
  );
  for (var i = 0; i < 300; i++) {
    m.execute([
      'm-$i',
      _stamp,
      _stamp,
      null,
      const ['weight', 'waist', 'chest'][i % 3],
      70.0 + r.nextInt(300) / 10,
      '2026-0${1 + i % 9}-1${i % 10}T06:00:00.000Z',
      i % 5 == 0 ? 'note $i' : null,
    ]);
  }
  m.close();
  final fd = db.prepare(
    'INSERT INTO foods (id, created_at, updated_at, deleted_at, name, brand, '
    'barcode, per100_unit, kcal, protein_g, carbs_g, fat_g, fibre_g, '
    'provenance, source, search_key) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
  );
  final fs = db.prepare(
    'INSERT INTO food_servings (id, food_id, label, amount, unit, '
    'sort_order) VALUES (?,?,?,?,?,?)',
  );
  for (var i = 0; i < 200; i++) {
    fd.execute([
      'f-$i',
      _stamp,
      _stamp,
      null,
      'Food $i',
      i % 2 == 0 ? 'Brand' : null,
      i % 3 == 0 ? '50000000$i' : null,
      'grams',
      100.0 + i,
      i % 4 == 0 ? null : 10.5,
      null,
      3.0,
      null,
      'user',
      'user',
      'food $i',
    ]);
    for (var k = 0; k < 2; k++) {
      fs.execute([
        'fs-$i-$k',
        'f-$i',
        'Serving $k',
        30.0 * (k + 1),
        'grams',
        k,
      ]);
    }
  }
  fd.close();
  fs.close();
  final g = db.prepare(
    'INSERT INTO goals (id, created_at, updated_at, deleted_at, kind, site, '
    'target, start_date, end_date, active) VALUES (?,?,?,?,?,?,?,?,?,?)',
  );
  for (var i = 0; i < 10; i++) {
    g.execute([
      'g-$i',
      _stamp,
      _stamp,
      null,
      'weight',
      i % 2 == 0 ? 'weight' : null,
      75.5,
      '2026-01-01T00:00:00.000Z',
      null,
      i == 0 ? 1 : 0,
    ]);
  }
  g.close();
  final s = db.prepare(
    'INSERT INTO settings (key, value, updated_at) VALUES (?,?,?)',
  );
  for (var i = 0; i < 12; i++) {
    s.execute(['setting.$i', 'value $i', _stamp]);
  }
  s.close();
  final q = db.prepare(
    'INSERT INTO legacy_quarantine (source_table, row_id, reason, '
    'original_json, quarantined_at) VALUES (?,?,?,?,?)',
  );
  for (var i = 0; i < 25; i++) {
    q.execute([
      'exercises',
      'ex-old-$i',
      'v6 legacy value',
      jsonEncode({'id': 'ex-old-$i', 'primary_muscle': 'x$i'}),
      _stamp,
    ]);
  }
  q.close();
}

// ---------------------------------------------------------------------------
// Row hashing (value equality, section 17.2 and 17.4 of the plan)

/// Table digest: row count and a 64-bit FNV-1a hash over every row, taken in
/// primary-key order, with the type of each value included so a change from
/// INTEGER to REAL is a difference.
final class Digest {
  const Digest(this.count, this.hash);
  final int count;
  final String hash;

  @override
  bool operator ==(Object other) =>
      other is Digest && other.count == count && other.hash == hash;

  @override
  int get hashCode => Object.hash(count, hash);

  @override
  String toString() => '$count rows #$hash';
}

const _fnvOffset = -3750763034362895579; // 0xcbf29ce484222325 as signed
const _fnvPrime = 0x100000001b3;

int _fold(int h, String s) {
  var x = h;
  for (final c in s.codeUnits) {
    x = (x ^ c) * _fnvPrime;
  }
  return x;
}

String _render(Object? v) => switch (v) {
  null => 'N;',
  final int i => 'i$i;',
  final double d => 'r$d;',
  final String s => 't${s.length}:$s;',
  final Uint8List b => 'b${b.length}:${base64.encode(b)};',
  _ => 'x$v;',
};

/// Names of the user tables (all but SQLite internals), sorted.
List<String> userTables(Database db) => [
  for (final r in db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name",
  ))
    r['name']! as String,
];

List<String> columnsOf(Database db, String table) => [
  for (final r in db.select('PRAGMA table_info("$table")'))
    r['name']! as String,
];

/// Digest of [table]. [columns] limits the compared columns (default all);
/// [where] filters rows; [transform] rewrites each row (column to value)
/// before hashing, used to apply an expected change independently of SQL.
Digest digest(
  Database db,
  String table, {
  List<String>? columns,
  String? where,
  Map<String, Object?> Function(Map<String, Object?> row)? transform,
}) {
  final cols = columns ?? columnsOf(db, table);
  final order = cols.contains('id')
      ? 'id'
      : (cols.contains('key') ? 'key' : cols.first);
  final sql =
      'SELECT ${cols.map((c) => '"$c"').join(', ')} FROM "$table"'
      '${where == null ? '' : ' WHERE $where'} ORDER BY "$order"';
  var h = _fnvOffset;
  var n = 0;
  for (final row in db.select(sql)) {
    var data = <String, Object?>{for (final c in cols) c: row[c]};
    if (transform != null) data = transform(data);
    for (final c in cols) {
      h = _fold(h, _render(data[c]));
    }
    h = _fold(h, '\n');
    n++;
  }
  return Digest(n, (h & 0xFFFFFFFFFFFFFFF).toRadixString(16));
}

/// Digest of every user table that a migration step must leave untouched.
Map<String, Digest> digestAll(Database db, {Set<String> skip = const {}}) => {
  for (final t in userTables(db))
    if (!skip.contains(t)) t: digest(db, t),
};

/// The planned TRN-020 rule (plan safeguard C), written in Dart so it can
/// check the SQL version independently.
bool exertionValid(Object? scale, Object? value) {
  if (scale == null && value == null) return true;
  if (scale == null || value == null) return false;
  final v = (value as num).toDouble();
  if (scale == 'rpe') return v >= 1 && v <= 10 && (v * 2) == (v * 2).floor();
  if (scale == 'rir') return v >= 0 && v <= 5 && v == v.floor();
  return false;
}

/// Measured facts about a fixture file, recorded in the results so the
/// description of the data is checked, not assumed.
Map<String, Object?> fixtureStats(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    Object? one(String sql) => db.select(sql).first.values.first;
    final neverNull = <String>[];
    final someNull = <String>[];
    for (final t in userTables(db)) {
      for (final c in db.select('PRAGMA table_info("$t")')) {
        if (c['notnull'] == 1) continue;
        final n =
            db
                    .select(
                      'SELECT count(*) AS c FROM "$t" WHERE "${c['name']}" IS NULL',
                    )
                    .first['c']!
                as int;
        final rows =
            db.select('SELECT count(*) AS c FROM "$t"').first['c']! as int;
        if (rows == 0) continue;
        (n == 0 ? neverNull : someNull).add('$t.${c['name']}');
      }
    }
    return {
      'min_rest_seconds': one('SELECT min(rest_seconds) FROM session_sets'),
      'max_rest_seconds': one('SELECT max(rest_seconds) FROM session_sets'),
      'min_load_kg': one('SELECT min(load_kg) FROM session_sets'),
      'max_load_kg': one('SELECT max(load_kg) FROM session_sets'),
      'min_reps': one('SELECT min(reps) FROM session_sets'),
      'max_reps': one('SELECT max(reps) FROM session_sets'),
      'max_heart_rate': one('SELECT max(average_heart_rate) FROM session_sets'),
      'session_exercise_notes_of_4000': one(
        'SELECT count(*) FROM session_exercises '
        'WHERE length(note) = 4000',
      ),
      'max_exercise_name_length': one(
        'SELECT max(length(name)) FROM exercises',
      ),
      'sets_with_missing_exercise': one(
        "SELECT count(*) FROM session_sets WHERE exercise_id LIKE 'ex-missing%'",
      ),
      'entries_with_missing_exercise': one(
        "SELECT count(*) FROM session_exercises "
        "WHERE exercise_id LIKE 'ex-missing%'",
      ),
      'nullable_columns_without_any_null': neverNull,
      'nullable_columns_with_null': someNull.length,
    };
  } finally {
    db.close();
  }
}
