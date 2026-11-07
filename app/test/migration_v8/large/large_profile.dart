import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../data/generated_migrations/schema_v5.dart' as v5;
import '../../data/generated_migrations/schema_v7.dart' as v7;

/// The large realistic profile of WP 8 3b-9 (D04 2026-11-06, device timing):
/// 5,000 exercises and 100,000 sets with the owner's profile elements that
/// exist at schema v7, built deterministically through the FROZEN v7 schema
/// (`DatabaseAtV7`, the snapshot classes), never through `AppDatabase`.
///
/// Profile elements (each count is exact and checked by the tests):
/// - [LargeProfileSpec.noPrimary] (303) exercises whose `primary_muscle` is
///   no v7 `MuscleGroup` id ([unmappablePrimaries]: legacy free text, empty);
/// - [LargeProfileSpec.unknownEquipment] exercises whose `equipment_json`
///   holds an id outside the v7 `Equipment` list ([unknownEquipmentIds]);
/// - [LargeProfileSpec.duplicateEquipment] exercises listing one equipment
///   id twice;
/// - [LargeProfileSpec.invalidExertion] sets with a legacy exertion value
///   that the TRN-020 rule (RPE 1–10 in halves, RIR integers 0–5, scale and
///   value together) rejects, within the v7 CHECK (0–10);
/// - loose references: sets and entries naming exercises that do not exist;
/// - representative user data: plans, sessions, schedules, splits,
///   measurements, foods, food log, recipes, saved meals, meal plan, prep
///   batches, goals, settings, pre-existing quarantine rows; soft-deleted
///   rows, nulls, long and non-ASCII text.
///
/// Not part of a v7 database, so not here: the reference bootstrap and the
/// migration report (both written by the v7 → v8 migration, 3b-4).
///
/// [buildLargeProfile] with `version: 5` writes the SAME generated rows into
/// the frozen v5 shapes (columns that v5 lacks dropped, `supplied` as
/// `is_custom`, the rep range as `target_reps`; no v6/v7-only table). That
/// variant is the input of the historical chain's host timing (a stand-in,
/// never v8 evidence) and random kill runs: the historical chain v5 → v7
/// rebuilds `exercises`, `plan_exercises` and `session_sets` and backfills
/// the session entries. The v7 variant is the input of the v7 → v8
/// migration (its kill runs and its host and device timing).
///
/// Never written under `fixtures/` (frozen): callers pass a temporary path.

/// v7 `MuscleGroup` ids (the enum names; frozen copy, so a later enum
/// change cannot change the profile).
const v7MuscleIds = [
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

/// v7 `Equipment` ids (frozen copy).
const v7EquipmentIds = [
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

/// Primary texts that map to no v7 muscle id.
const unmappablePrimaries = [
  'rotator cuff',
  'Neck',
  '',
  'traps',
  'Serratus anterior',
  'hip flexors ✓',
];

/// Equipment texts outside the v7 list.
const unknownEquipmentIds = [
  'bodyweight',
  'sandbag',
  'Trx straps',
  '',
  'landmine',
];

/// Legacy exertion pairs that break TRN-020 (scale, value).
const invalidExertionPairs = <(String?, double?)>[
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

/// Size and seed of a profile.
final class LargeProfileSpec {
  const LargeProfileSpec({
    required this.exercises,
    required this.sets,
    required this.noPrimary,
    required this.unknownEquipment,
    required this.duplicateEquipment,
    required this.supplied,
    this.seed = largeProfileSeed,
  });

  /// The D04 profile: 5,000 exercises, 100,000 sets, 303 no-primary.
  const LargeProfileSpec.d04()
    : this(
        exercises: 5000,
        sets: 100000,
        noPrimary: 303,
        unknownEquipment: 150,
        duplicateEquipment: 40,
        supplied: 89,
      );

  /// A small profile with every element, for smoke runs (CI, emulator).
  const LargeProfileSpec.smoke()
    : this(
        exercises: 60,
        sets: 600,
        noPrimary: 4,
        unknownEquipment: 3,
        duplicateEquipment: 2,
        supplied: 10,
      );

  final int exercises;
  final int sets;
  final int noPrimary;
  final int unknownEquipment;
  final int duplicateEquipment;
  final int supplied;
  final int seed;

  /// Every 50th set (offset 7) carries an invalid exertion pair.
  int get invalidExertion => sets ~/ 50 + (sets % 50 > 7 ? 1 : 0);

  Map<String, Object?> toJson() => {
    'exercises': exercises,
    'sets': sets,
    'noPrimary': noPrimary,
    'unknownEquipment': unknownEquipment,
    'duplicateEquipment': duplicateEquipment,
    'invalidExertion': invalidExertion,
    'supplied': supplied,
    'seed': seed,
  };
}

/// Seed of the profile (distinct from the trial's 20261106).
const largeProfileSeed = 2026110603;

/// Measured facts about a built profile.
final class LargeProfileFacts {
  const LargeProfileFacts({
    required this.version,
    required this.spec,
    required this.counts,
    required this.bytes,
    required this.sqliteVersion,
    required this.buildMs,
  });

  final int version;
  final LargeProfileSpec spec;
  final Map<String, int> counts;
  final int bytes;
  final String sqliteVersion;
  final int buildMs;

  Map<String, Object?> toJson() => {
    'schemaVersion': version,
    'spec': spec.toJson(),
    'rowCounts': counts,
    'bytes': bytes,
    'sqliteVersion': sqliteVersion,
    'buildMs': buildMs,
  };
}

/// Builds the profile at [path] (deleted first) in the frozen shape of
/// schema [version] (7, or 5 for the historical chain's input).
Future<LargeProfileFacts> buildLargeProfile(
  String path, {
  LargeProfileSpec spec = const LargeProfileSpec.d04(),
  int version = 7,
}) async {
  final watch = Stopwatch()..start();
  final f = File(path);
  for (final p in [path, '$path-journal']) {
    if (File(p).existsSync()) File(p).deleteSync();
  }
  final creator = switch (version) {
    7 => v7.DatabaseAtV7(NativeDatabase(f)),
    5 => v5.DatabaseAtV5(NativeDatabase(f)),
    _ => throw ArgumentError.value(version, 'version', 'only 5 or 7'),
  };
  await creator.customSelect('SELECT 1').get();
  await creator.close();

  final db = sqlite3.open(path);
  try {
    final w = _Writer(db, version);
    db.execute('BEGIN');
    _Generator(w, spec).run();
    db.execute('COMMIT');
    w.close();
    final counts = <String, int>{
      for (final t in db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      ))
        t['name']! as String:
            db.select('SELECT count(*) AS c FROM "${t['name']}"').first['c']!
                as int,
    };
    final sqliteVersion =
        db.select('SELECT sqlite_version() AS v').first['v']! as String;
    db.close();
    watch.stop();
    return LargeProfileFacts(
      version: version,
      spec: spec,
      counts: counts,
      bytes: f.lengthSync(),
      sqliteVersion: sqliteVersion,
      buildMs: watch.elapsedMilliseconds,
    );
  } on Object {
    db.close();
    rethrow;
  }
}

/// Inserts generated rows (named in v7 terms) into the target version's
/// shape: unknown tables are skipped, absent columns dropped.
final class _Writer {
  _Writer(this.db, this.version) {
    for (final t in db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%'",
    )) {
      final name = t['name']! as String;
      _columns[name] = {
        for (final c in db.select('PRAGMA table_info("$name")'))
          c['name']! as String,
      };
    }
  }

  final Database db;
  final int version;
  final Map<String, Set<String>> _columns = {};
  final Map<String, PreparedStatement> _statements = {};

  void insert(String table, Map<String, Object?> row) {
    final cols = _columns[table];
    if (cols == null) return; // table not in this version
    final data = version == 7 ? row : _toV5(table, row);
    final keys = [
      for (final k in data.keys)
        if (cols.contains(k)) k,
    ];
    final sig = '$table(${keys.join(',')})';
    final st = _statements[sig] ??= db.prepare(
      'INSERT INTO "$table" (${keys.map((k) => '"$k"').join(', ')}) '
      'VALUES (${List.filled(keys.length, '?').join(', ')})',
    );
    st.execute([for (final k in keys) data[k]]);
  }

  static Map<String, Object?> _toV5(String table, Map<String, Object?> row) =>
      switch (table) {
        'exercises' => {...row, 'is_custom': row['supplied'] == 1 ? 0 : 1},
        'plan_exercises' => {...row, 'target_reps': row['reps_max']},
        _ => row,
      };

  void close() {
    for (final s in _statements.values) {
      s.close();
    }
  }
}

const _stamp = '2026-10-01T08:00:00.000Z';

String _pad(int i, [int w = 4]) => i.toString().padLeft(w, '0');

final class _Generator {
  _Generator(this.w, this.spec) : r = Random(spec.seed);

  final _Writer w;
  final LargeProfileSpec spec;
  final Random r;

  T _pick<T>(List<T> xs) => xs[r.nextInt(xs.length)];

  /// Exactly [count] of `0..n-1` are selected (multiplication by a prime
  /// modulo n is a permutation when the prime does not divide n).
  static bool _selected(int i, int n, int count, int prime) =>
      (i * prime) % n < count;

  String _exerciseId(int i) => 'ex-${_pad(i)}';

  /// Exercise for a new set: skewed toward the first ids.
  String _exerciseFor() {
    final u = r.nextDouble();
    return _exerciseId((spec.exercises * u * u * u).floor());
  }

  void run() {
    _exercises();
    _training();
    _body();
    _nutrition();
    _misc();
  }

  void _exercises() {
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
    final n = spec.exercises;
    for (var i = 0; i < n; i++) {
      final supplied = i < spec.supplied ? 1 : 0;
      var name = 'Exercise ${_pad(i)} variant ${i % 17}';
      if (i % 500 == 7) name = 'Écarté ✓ $iß';
      if (i % 701 == 3) name = 'O\'Neil "press" $i';
      if (i % 1499 == 11) name = 'Long ${'x' * 2000} $i';
      final noPrimary = _selected(i, n, spec.noPrimary, 7919);
      final primary = noPrimary
          ? unmappablePrimaries[i % unmappablePrimaries.length]
          : _pick(v7MuscleIds);
      final secondary = <String>[];
      final nSecondary = r.nextInt(100) < 2 ? 0 : r.nextInt(4);
      while (secondary.length < nSecondary) {
        final s = _pick(v7MuscleIds);
        if (!secondary.contains(s)) secondary.add(s);
      }
      final e = r.nextInt(100);
      if (e < 8 && !noPrimary) secondary.add(primary); // equals the primary
      if (e == 11) secondary.add('traps'); // unmapped secondary text
      final equipment = <String>{
        for (var k = r.nextInt(3); k > 0; k--) _pick(v7EquipmentIds),
      }.toList();
      if (_selected(i, n, spec.unknownEquipment, 104729)) {
        equipment.add(unknownEquipmentIds[i % unknownEquipmentIds.length]);
      }
      if (_selected(i, n, spec.duplicateEquipment, 1299709)) {
        final dup = equipment.firstWhere(
          v7EquipmentIds.contains,
          orElse: () => 'dumbbell',
        );
        equipment
          ..remove(dup)
          ..addAll([dup, dup]);
      }
      final aliases = r.nextInt(100) < 70
          ? <String>[]
          : ['alias ${i}a', if (r.nextBool()) 'Äpfel $i'];
      w.insert('exercises', {
        'id': _exerciseId(i),
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': i % 53 == 0 ? '2026-10-02T09:30:00.000Z' : null,
        'name': name,
        'type': _pick(types),
        'category': _pick(categories),
        'primary_muscle': primary,
        'secondary_muscles_json': jsonEncode(secondary),
        'equipment_json': jsonEncode(equipment),
        'aliases_json': jsonEncode(aliases),
        'search_key': name.toLowerCase(),
        'supplied': supplied,
        'copied_from_id': supplied == 0 && r.nextInt(100) < 30
            ? _exerciseId(r.nextInt(spec.supplied))
            : null,
        'archived': i % 20 == 0 ? 1 : 0,
      });
    }
  }

  void _training() {
    const plans = 40;
    for (var p = 0; p < plans; p++) {
      w.insert('workout_plans', {
        'id': 'plan-$p',
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': p == 39 ? _stamp : null,
        'name': 'Plan $p',
        'split': p % 3 == 0 ? null : 'PPL',
        'scheduled_weekdays_json': '[${p % 7}]',
        'archived': p % 10 == 0 ? 1 : 0,
      });
    }
    for (var i = 0; i < 400; i++) {
      final hasReps = i % 4 != 0;
      w.insert('plan_exercises', {
        'id': 'pe-$i',
        'plan_id': 'plan-${i % plans}',
        'exercise_id': i % 97 == 5 ? 'ex-missing-plan-$i' : _exerciseFor(),
        'sort_order': i ~/ plans,
        'target_sets': 1 + i % 20,
        'reps_min': hasReps ? 5 + i % 3 : null,
        'reps_max': hasReps ? 8 + i % 5 : null,
        'target_load_kg': i % 3 == 0 ? null : (i % 40) * 2.5,
        'target_duration_sec': i % 11 == 0 ? 60 : null,
        'target_metres': i % 13 == 0 ? 400.5 : null,
        'rest_seconds': i % 5 == 0 ? null : 90,
      });
    }

    var sets = 0;
    var sessionNo = 0;
    var entryNo = 0;
    while (sets < spec.sets) {
      final sid = 'ws-$sessionNo';
      final day = DateTime.utc(2023).add(Duration(hours: 8 + sessionNo * 6));
      w.insert('workout_sessions', {
        'id': sid,
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': sessionNo % 97 == 0 ? '2026-10-03T00:00:00.000Z' : null,
        'name': 'Session $sessionNo',
        'plan_id': sessionNo % 4 == 0 ? null : 'plan-${sessionNo % plans}',
        'started_at': day.toIso8601String(),
        'ended_at': sessionNo % 9 == 0
            ? null
            : day.add(const Duration(minutes: 70)).toIso8601String(),
        'notes': sessionNo % 13 == 0 ? 'Notes ✓ $sessionNo' : '',
      });
      final entries = 3 + r.nextInt(6);
      for (var pos = 0; pos < entries && sets < spec.sets; pos++) {
        final eid = 'se-$entryNo';
        entryNo++;
        final ex = entryNo % 997 == 5 ? 'ex-missing-$entryNo' : _exerciseFor();
        w.insert('session_exercises', {
          'id': eid,
          'session_id': sid,
          'position': pos,
          'exercise_id': ex,
          'note': entryNo % 50 == 0
              ? 'n' * 4000
              : (entryNo % 7 == 0 ? 'felt heavy' : null),
        });
        final n = 2 + r.nextInt(5);
        for (var s = 0; s < n && sets < spec.sets; s++) {
          _set(sets, sid, eid, ex, pos, s);
          sets++;
        }
      }
      sessionNo++;
    }

    for (var i = 0; i < 300; i++) {
      final d = '2026-11-${(1 + i % 28).toString().padLeft(2, '0')}';
      w.insert('scheduled_workouts', {
        'id': 'sw-$i',
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': null,
        'day': d,
        'source_day': d,
        'plan_id': 'plan-${i % plans}',
        'origin': const ['date', 'weekday', 'split'][i % 3],
        'status': const ['planned', 'skipped', 'done'][i % 3],
        'session_id': i % 3 == 2 ? 'ws-$i' : null,
      });
    }
    for (var i = 0; i < 5; i++) {
      w.insert('training_splits', {
        'id': 'split-$i',
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': null,
        'name': 'Split $i',
        'cycle_days': 7,
        'sort_order': i,
      });
      for (var d = 0; d < 7; d++) {
        w.insert('split_days', {
          'id': 'sd-$i-$d',
          'split_id': 'split-$i',
          'day_index': d,
          'plan_id': d == 6 ? null : 'plan-$d',
        });
      }
    }
  }

  void _set(int n, String sid, String eid, String ex, int pos, int order) {
    const types = ['weighted', 'bodyweight', 'assisted', 'timed', 'cardio'];
    final type = n % 5 == 4 ? 'cardio' : types[r.nextInt(4)];
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
    String? scale;
    double? value;
    final x = r.nextInt(1000);
    if (n % 50 == 7) {
      final bad = invalidExertionPairs[(n ~/ 50) % invalidExertionPairs.length];
      scale = bad.$1;
      value = bad.$2;
    } else if (x < 450) {
      // not recorded
    } else if (x < 780) {
      scale = 'rpe';
      value = 1 + r.nextInt(19) * 0.5;
    } else {
      scale = 'rir';
      value = r.nextInt(6).toDouble();
    }
    w.insert('session_sets', {
      'id': 'set-$n',
      'session_id': sid,
      'exercise_id': ex,
      'exercise_order': pos,
      'set_order': order,
      'type': type,
      'load_kg': load,
      'reps': reps,
      'assistance_kg': assist,
      'duration_sec': dur,
      'metres': metres,
      'average_heart_rate': hr,
      'energy_kcal': kcal,
      'energy_provenance': prov,
      'completed': n % 20 == 0 ? 0 : 1,
      'exertion_scale': scale,
      'exertion_value': value,
      'rest_seconds': n % 3 == 0 ? null : (n % 211 == 0 ? 3600 : 60 + n % 240),
      'note': n % 40 == 0 ? 'Note ✓ ünï $n' : null,
      'set_kind': n % 10 == 0
          ? 'warmUp'
          : (n % 20 == 1 ? 'failure' : 'working'),
      'session_exercise_id': eid,
    });
  }

  void _body() {
    for (var i = 0; i < 1000; i++) {
      final at = DateTime.utc(2023).add(Duration(days: i));
      w.insert('measurements', {
        'id': 'm-$i',
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': i % 101 == 0 ? _stamp : null,
        'site': const ['weight', 'weight', 'waist', 'chest', 'bodyFat'][i % 5],
        'value': 70.0 + r.nextInt(300) / 10,
        'recorded_at': at.toIso8601String(),
        'note': i % 25 == 0 ? 'note ✓ $i' : null,
      });
    }
    for (var i = 0; i < 10; i++) {
      w.insert('goals', {
        'id': 'g-$i',
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': null,
        'kind': 'weight',
        'site': i.isEven ? 'weight' : null,
        'target': 75.5,
        'start_date': '2026-01-01T00:00:00.000Z',
        'end_date': i.isEven ? null : '2026-12-31T00:00:00.000Z',
        'active': i == 0 ? 1 : 0,
      });
    }
  }

  void _nutrition() {
    for (var i = 0; i < 300; i++) {
      w.insert('foods', {
        'id': 'f-$i',
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': i % 61 == 0 ? _stamp : null,
        'name': i % 50 == 3 ? 'Crème fraîche $i' : 'Food $i',
        'brand': i.isEven ? 'Brand' : null,
        'barcode': i % 3 == 0 ? '50000000$i' : null,
        'per100_unit': i % 7 == 0 ? 'millilitres' : 'grams',
        'kcal': 100.0 + i,
        'protein_g': i % 4 == 0 ? null : 10.5,
        'carbs_g': i % 5 == 0 ? null : 20.0,
        'fat_g': 3.0,
        'fibre_g': i.isEven ? null : 1.5,
        'provenance': i % 3 == 0 ? 'barcode' : 'user',
        'source': 'user',
        'search_key': 'food $i',
      });
      for (var k = 0; k < 2; k++) {
        w.insert('food_servings', {
          'id': 'fs-$i-$k',
          'food_id': 'f-$i',
          'label': 'Serving $k',
          'amount': 30.0 * (k + 1),
          'unit': 'grams',
          'sort_order': k,
        });
      }
    }
    for (var i = 0; i < 40; i++) {
      w.insert('recipes', {
        'id': 'r-$i',
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': null,
        'name': 'Recipe $i',
        'category': const ['breakfast', 'main', 'snack'][i % 3],
        'description': i % 4 == 0 ? 'Long ${'d' * 500}' : '',
        'portions': 1.0 + i % 6,
        'prep_minutes': i % 5 == 0 ? null : 10,
        'cook_minutes': i % 7 == 0 ? null : 25,
        'storage': i.isEven ? 'fridge 3 days' : null,
        'freezing': const ['yes', 'no', 'unknown'][i % 3],
        'reheating': null,
        'favourite': i % 9 == 0 ? 1 : 0,
        'prep_steps_json': jsonEncode(['chop', 'mix']),
        'cook_steps_json': jsonEncode(['bake $i']),
        'total_weight_g': i % 3 == 0 ? null : 900.0,
        'portion_weight_g': null,
        'declared_kcal': i % 6 == 0 ? 450.0 : null,
        'declared_protein_g': null,
        'declared_carbs_g': null,
        'declared_fat_g': null,
        'declared_fibre_g': null,
        'nutrition_note': null,
        'ingredient_notes_json': '[]',
      });
      w.insert('prep_batches', {
        'id': 'pb-$i',
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': null,
        'recipe_id': 'r-$i',
        'prepared_at': _stamp,
        'portions_made': 4.0,
        'portions_remaining': (i % 5).toDouble(),
      });
    }
    for (var i = 0; i < 300; i++) {
      w.insert('recipe_ingredients', {
        'id': 'ri-$i',
        'recipe_id': 'r-${i % 40}',
        'name': 'Ingredient $i',
        'food_id': i % 3 == 0 ? null : 'f-${i % 300}',
        'amount': 50.0 + i % 200,
        'unit': 'grams',
        'sort_order': i ~/ 40,
        'note': i % 10 == 0 ? 'chopped' : null,
        'kcal': i % 3 == 0 ? 80.0 : null,
        'protein_g': null,
        'carbs_g': null,
        'fat_g': null,
        'fibre_g': null,
        'provenance': i % 3 == 0 ? 'user' : null,
        'serving_label': i % 8 == 0 ? 'cup' : null,
        'serving_count': i % 8 == 0 ? 1.5 : null,
      });
      if (i % 10 == 0) {
        w.insert('recipe_substitutes', {
          'id': 'rs-$i',
          'recipe_ingredient_id': 'ri-$i',
          'sort_order': 0,
          'name': 'Substitute $i',
          'food_id': null,
          'amount': 40.0,
          'unit': 'grams',
          'kcal': 70.0,
          'protein_g': null,
          'carbs_g': null,
          'fat_g': null,
          'fibre_g': null,
          'provenance': 'user',
        });
      }
    }
    for (var i = 0; i < 3000; i++) {
      final day = DateTime.utc(2025).add(Duration(days: i ~/ 6));
      final fromRecipe = i % 9 == 0;
      w.insert('food_log_entries', {
        'id': 'fl-$i',
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': i % 211 == 0 ? _stamp : null,
        'day': day.toIso8601String().substring(0, 10),
        'meal': const ['breakfast', 'lunch', 'dinner', 'snack'][i % 4],
        'name': 'Logged $i',
        'food_id': fromRecipe ? null : 'f-${i % 300}',
        'recipe_id': fromRecipe ? 'r-${i % 40}' : null,
        'amount': 100.0 + i % 150,
        'unit': 'grams',
        'kcal': 150.0 + i % 400,
        'protein_g': i % 4 == 0 ? null : 12.0,
        'carbs_g': null,
        'fat_g': 4.0,
        'fibre_g': null,
        'provenance': 'user',
        'logged_at': day.add(Duration(hours: 7 + i % 12)).toIso8601String(),
      });
    }
    for (var i = 0; i < 15; i++) {
      w.insert('saved_meals', {
        'id': 'sm-$i',
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': null,
        'name': 'Saved meal $i',
        'default_meal': i.isEven ? 'lunch' : null,
      });
      for (var k = 0; k < 4; k++) {
        w.insert('saved_meal_items', {
          'id': 'smi-$i-$k',
          'saved_meal_id': 'sm-$i',
          'name': 'Item $k',
          'food_id': k == 3 ? null : 'f-${(i * 4 + k) % 300}',
          'recipe_id': k == 3 ? 'r-${i % 40}' : null,
          'amount': 80.0,
          'unit': 'grams',
          'sort_order': k,
          'kcal': 120.0,
          'protein_g': null,
          'carbs_g': 10.0,
          'fat_g': null,
          'fibre_g': null,
          'provenance': 'user',
        });
      }
    }
    for (var i = 0; i < 200; i++) {
      w.insert('meal_plan_items', {
        'id': 'mp-$i',
        'created_at': _stamp,
        'updated_at': _stamp,
        'deleted_at': null,
        'day': '2026-11-${(1 + i % 28).toString().padLeft(2, '0')}',
        'meal': const ['breakfast', 'lunch', 'dinner', 'snack'][i % 4],
        'kind': i.isEven ? 'food' : 'recipe',
        'ref_id': i.isEven ? 'f-${i % 300}' : 'r-${i % 40}',
        'name': 'Planned $i',
        'amount': 1.0,
        'unit': i.isEven ? 'grams' : 'portion',
        'eaten_entry_id': i % 10 == 0 ? 'fl-$i' : null,
        'sort_order': i ~/ 28,
      });
    }
  }

  void _misc() {
    for (var i = 0; i < 12; i++) {
      w.insert('settings', {
        'key': 'setting.$i',
        'value': 'value $i',
        'updated_at': _stamp,
      });
    }
    for (var i = 0; i < 25; i++) {
      w.insert('legacy_quarantine', {
        'source_table': 'exercises',
        'row_id': 'ex-old-$i',
        'reason': 'v6 legacy value',
        'original_json': jsonEncode({'id': 'ex-old-$i', 'primary_muscle': 'x'}),
        'quarantined_at': '2026-02-01T10:00:00.000Z',
      });
    }
  }
}

/// Facts measured on a built v7 profile (not assumed from the generator):
/// the counts the tests compare with [LargeProfileSpec].
Map<String, Object?> measureV7Profile(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    int one(String sql, [List<Object?> args = const []]) =>
        db.select(sql, args).first.values.first! as int;
    final muscles = v7MuscleIds.map((m) => "'$m'").join(',');
    final equipment = v7EquipmentIds.map((m) => "'$m'").join(',');
    return {
      'exercises': one('SELECT count(*) FROM exercises'),
      'sets': one('SELECT count(*) FROM session_sets'),
      'noPrimary': one(
        'SELECT count(*) FROM exercises '
        'WHERE primary_muscle NOT IN ($muscles)',
      ),
      'unknownEquipment': one(
        'SELECT count(DISTINCT e.id) FROM exercises e, '
        'json_each(e.equipment_json) j WHERE j.value NOT IN ($equipment)',
      ),
      'duplicateEquipment': one(
        'SELECT count(*) FROM (SELECT e.id FROM exercises e, '
        'json_each(e.equipment_json) j GROUP BY e.id, j.value '
        'HAVING count(*) > 1)',
      ),
      'invalidExertion': one(
        'SELECT count(*) FROM session_sets WHERE CASE '
        'WHEN exertion_scale IS NULL AND exertion_value IS NULL THEN 0 '
        "WHEN exertion_scale = 'rpe' AND exertion_value BETWEEN 1 AND 10 "
        'AND exertion_value * 2 = CAST(exertion_value * 2 AS INTEGER) '
        'THEN 0 '
        "WHEN exertion_scale = 'rir' AND exertion_value BETWEEN 0 AND 5 "
        'AND exertion_value = CAST(exertion_value AS INTEGER) THEN 0 '
        'ELSE 1 END = 1',
      ),
      'supplied': one('SELECT count(*) FROM exercises WHERE supplied = 1'),
      'setsWithMissingExercise': one(
        'SELECT count(*) FROM session_sets s WHERE NOT EXISTS '
        '(SELECT 1 FROM exercises e WHERE e.id = s.exercise_id)',
      ),
      'setsWithoutEntry': one(
        'SELECT count(*) FROM session_sets WHERE session_exercise_id IS NULL',
      ),
      'foreignKeyViolations': db.select('PRAGMA foreign_key_check').length,
    };
  } finally {
    db.close();
  }
}
