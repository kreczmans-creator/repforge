// Generator for the frozen v8 migration evidence (WP 8 stage 3b-1).
//
// Run once, from `app/`:
//
//   flutter test --concurrency=1 test/migration_v8/fixtures/build_fixtures.dart
//
// (The file name does not end in `_test.dart`, so a plain `flutter test`
// never runs it.) It writes, next to itself:
//   fixture_v1.sqlite .. fixture_v7.sqlite    clean databases: zero
//                                             foreign-key violations, like a
//                                             real database (the app ran with
//                                             foreign keys on)
//   fixture_v2_orphans.sqlite .. _v7_orphans  the clean content plus
//                                             foreign-key orphans and loose
//                                             references (damaged databases)
//   golden_format1_v{2..7}[_orphans].json     format 1 backups of that era
//   golden_format2_v7[_orphans].json          format 2 backup (production)
//   golden_format{1,2}_settings_only.json     settings-only backups
//   expected_v7_digests.json                  production migration and
//                                             restore results
//   MANIFEST.sha256                           SHA-256 of every frozen file
//
// The generator REFUSES to overwrite an existing file. The artefacts are
// frozen evidence: a new case means a new file with a new name, never a
// regenerated old one. See README.md.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/training/training.dart' show exerciseSearchKey;
import 'package:sqlite3/sqlite3.dart';

import '../../data/generated_migrations/schema.dart';
import '../migration_digest.dart';

// ---- Deterministic values --------------------------------------------------

const _t1 = '2026-01-15T08:00:00.000Z';
const _t2 = '2026-01-16T09:30:00.000Z';
const _t3 = '2026-01-17T18:45:00.000Z';
const _tSeed = '2026-01-10T07:00:00.000Z';
const _quarantineStamp = '2026-02-01T10:00:00.000Z';

/// Exactly 4,000 code points of mixed ASCII, accented, CJK and emoji text.
String text4000([String seed = 'Notiz äöüß ✓ 日本語 😀 note. ']) {
  final runes = <int>[];
  while (runes.length < 4000) {
    runes.addAll(seed.runes);
  }
  return String.fromCharCodes(runes.sublist(0, 4000));
}

const _unicodeName = 'Écarté ✓ Übung ß 鶏肉 🍗';
const _quoted = 'O\'Neil "press" \\ back/slash';

/// Real settings keys (`DriftSettingsRepository`), each added in the era in
/// which its key first appears in git history: units/theme/exertionScale/
/// dayStartHour/weekStartDay from v2; mealLabels and seedRecipesVersion from
/// v5 (77540ae); recipeFavouritesOnly and availableEquipment from v5/v6;
/// equipmentBodyweightOnly and seedExercisesVersion from v6; defaultRest-
/// Seconds and restTimerNotifications from v7. The first-appearance version
/// of recipeFavouritesOnly (ae338e0) and availableEquipment (058d433) is
/// approximated as v6.
List<Map<String, Object?>> realSettings(int v) {
  const t = '2026-01-12T07:30:00.000Z';
  Map<String, Object?> s(String k, String val) => {
    'key': k,
    'value': val,
    'updated_at': t,
  };
  return [
    s('units', 'metric'),
    s('theme', 'dark'),
    s('exertionScale', 'rpe'),
    s('dayStartHour', '4'),
    s('weekStartDay', '1'),
    if (v >= 5) ...[
      s(
        'mealLabels',
        '{"order":["breakfast","lunch","dinner","snack"],"labels":'
            '{"breakfast":"Frühstück","lunch":"Lunch","dinner":"Dinner",'
            '"snack":"Snacks"}}',
      ),
      s('seedRecipesVersion', '1'),
    ],
    if (v >= 6) ...[
      s('recipeFavouritesOnly', 'false'),
      s('availableEquipment', 'barbell,bench,dumbbell,squatRack'),
      s('equipmentBodyweightOnly', 'false'),
      s('seedExercisesVersion', '1'),
    ],
    if (v >= 7) ...[
      s('defaultRestSeconds', '90'),
      s('restTimerNotifications', 'true'),
    ],
  ];
}

// ---- Insert helper ----------------------------------------------------------

final class _Fx {
  _Fx(this.db);
  final Database db;
  final _columns = <String, Set<String>>{};

  Set<String> cols(String table) => _columns.putIfAbsent(table, () {
    return {
      for (final r in db.select('PRAGMA table_info("$table")'))
        r['name']! as String,
    };
  });

  /// Strict insert: every key must be a column of [table]; omitted columns
  /// take their default or NULL (a missing NOT NULL value fails loudly).
  void put(String table, Map<String, Object?> row) {
    final known = cols(table);
    for (final k in row.keys) {
      if (!known.contains(k)) {
        throw StateError('$table has no column $k');
      }
    }
    final names = row.keys.map((k) => '"$k"').join(', ');
    final marks = List.filled(row.length, '?').join(', ');
    db.execute(
      'INSERT INTO "$table" ($names) VALUES ($marks)',
      row.values.toList(),
    );
  }
}

Map<String, Object?> _stamps({String? deleted, String at = _t1}) => {
  'created_at': at,
  'updated_at': at,
  'deleted_at': deleted,
};

// ---- Content per area ------------------------------------------------------

void _measurements(_Fx f) {
  f.put('measurements', {
    'id': 'm-01',
    ..._stamps(),
    'site': 'weight',
    'value': 82.4,
    'recorded_at': _t1,
    'note': 'morning',
  });
  f.put('measurements', {
    'id': 'm-02',
    ..._stamps(deleted: _t2),
    'site': 'weight',
    'value': 82.0,
    'recorded_at': _t2,
  });
  f.put('measurements', {
    'id': 'm-03',
    ..._stamps(),
    'site': 'waist',
    'value': 0.0,
    'recorded_at': _t2,
  });
  f.put('measurements', {
    'id': 'm-04',
    ..._stamps(),
    'site': 'weight',
    'value': 81.9,
    'recorded_at': _t3,
    'note': text4000(),
  });
  f.put('measurements', {
    'id': 'm-05',
    ..._stamps(),
    'site': 'chest',
    'value': 101.5,
    'recorded_at': _t3,
    'note': _unicodeName,
  });
}

void _nutrition(_Fx f, int v, bool orphans) {
  final macros = v >= 4; // v4: protein, carbs and fat become nullable
  Map<String, Object?> food(
    String id,
    String name, {
    double? p = 20,
    double? c = 10,
    double? fat = 5,
    String? deleted,
    String? brand,
    String? barcode,
    double? fibre,
  }) => {
    'id': id,
    ..._stamps(deleted: deleted),
    'name': name,
    'brand': brand,
    'barcode': barcode,
    'per100_unit': 'g',
    'kcal': 250.0,
    'protein_g': p,
    'carbs_g': c,
    'fat_g': fat,
    'fibre_g': fibre,
    'provenance': 'userEntered',
    'source': 'custom',
    'search_key': name.toLowerCase(),
  };
  f.put(
    'foods',
    food(
      'food-01',
      'Chicken breast',
      brand: 'Farm',
      barcode: '4001234567890',
      fibre: 0.0,
    ),
  );
  f.put(
    'foods',
    food(
      'food-02',
      _unicodeName,
      deleted: _t2,
      p: macros ? null : 0,
      c: macros ? null : 0,
      fat: macros ? null : 0,
    ),
  );
  f.put('foods', food('food-03', _quoted, p: macros ? null : 0.0));
  f.put('food_servings', {
    'id': 'fs-01',
    'food_id': 'food-01',
    'label': '1 fillet',
    'amount': 120.0,
    'unit': 'g',
    'sort_order': 0,
  });
  Map<String, Object?> entry(
    String id, {
    String? food,
    String? recipe,
    String? deleted,
    double? p = 30,
  }) => {
    'id': id,
    ..._stamps(deleted: deleted),
    'day': '2026-01-15',
    'meal': 'lunch',
    'name': 'Meal $id',
    'food_id': food,
    'recipe_id': recipe,
    'amount': 150.0,
    'unit': 'g',
    'kcal': 330.0,
    'protein_g': p,
    'carbs_g': macros ? null : 0.0,
    'fat_g': macros ? null : 0.0,
    'provenance': 'userEntered',
    'logged_at': _t1,
  };
  f.put('food_log_entries', entry('log-01', food: 'food-01'));
  f.put('food_log_entries', entry('log-02')); // no food or recipe reference
  f.put(
    'food_log_entries',
    entry('log-03', deleted: _t2, p: macros ? null : 0),
  );
  if (v >= 3) {
    f.put('saved_meals', {
      'id': 'sm-01',
      ..._stamps(),
      'name': 'Usual lunch',
      'default_meal': 'lunch',
    });
    f.put('saved_meals', {
      'id': 'sm-02',
      ..._stamps(deleted: _t3),
      'name': _unicodeName,
    });
    Map<String, Object?> item(String id, String meal, {String? foodId}) => {
      'id': id,
      'saved_meal_id': meal,
      'name': 'Item $id',
      'food_id': foodId,
      'amount': 100.0,
      'unit': 'g',
      'sort_order': 0,
      'kcal': 120.0,
      'protein_g': macros ? null : 0.0,
      'carbs_g': macros ? null : 0.0,
      'fat_g': macros ? null : 0.0,
      'provenance': 'userEntered',
    };
    f.put('saved_meal_items', item('smi-01', 'sm-01', foodId: 'food-01'));
    if (orphans) {
      f.put(
        'saved_meal_items',
        item('smi-orphan', 'ghost-meal', foodId: 'ghost-food'),
      );
    }
  }
  if (orphans) {
    f.put('food_servings', {
      'id': 'fs-orphan',
      'food_id': 'ghost-food',
      'label': 'orphan',
      'amount': 1.0,
      'unit': 'g',
      'sort_order': 1,
    });
    f.put(
      'food_log_entries',
      entry('log-loose', food: 'ghost-food', recipe: 'ghost-recipe'),
    ); // loose references
  }
}

void _recipes(_Fx f, int v, bool orphans) {
  final legacy =
      v <= 4; // v2..v4: portions INTEGER, method steps, boolean freezer flag
  Map<String, Object?> recipe(
    String id, {
    String? deleted,
    Object portions = 4,
    int freezer = 0,
    String? freezing,
    String description = '',
    String name = 'Recipe',
  }) {
    final m = <String, Object?>{
      'id': id,
      ..._stamps(deleted: deleted),
      'name': name,
      'category': 'dinner',
      'description': description,
      'portions': portions,
      'favourite': 0,
    };
    if (legacy) {
      m['freezer_friendly'] = freezer;
      m['method_steps_json'] = jsonEncode(['Mix', 'Bake 20 min', 'Rest ✓']);
    } else {
      m['freezing'] = freezing ?? 'unknown';
      m['prep_steps_json'] = jsonEncode(['Chop']);
      m['cook_steps_json'] = jsonEncode(['Cook gently', 'Serve 🍲']);
      m['ingredient_notes_json'] = '[]';
    }
    return m;
  }

  // v4 freezer hazard: 1 -> yes, 0 means "not stated" (-> unknown, never no).
  f.put('recipes', recipe('rec-01', freezer: 1, freezing: 'yes', name: 'Stew'));
  f.put(
    'recipes',
    recipe(
      'rec-02',
      freezer: 0,
      freezing: 'unknown',
      name: 'Curry',
      portions: legacy ? 3 : 2.5,
    ),
  );
  f.put(
    'recipes',
    recipe(
      'rec-03',
      deleted: _t2,
      freezer: 1,
      freezing: 'no',
      description: text4000(),
      name: _unicodeName,
    ),
  );
  f.put(
    'recipes',
    recipe('rec-04', name: _quoted, description: 'null nutrition fields'),
  );
  Map<String, Object?> ing(
    String id,
    String recipeId, {
    String? foodId,
    double? kcal,
  }) => {
    'id': id,
    'recipe_id': recipeId,
    'name': 'Ingredient $id',
    'food_id': foodId,
    'amount': 200.0,
    'unit': 'g',
    'sort_order': 0,
    'kcal': kcal,
  };
  f.put(
    'recipe_ingredients',
    ing('ri-01', 'rec-01', foodId: 'food-01', kcal: 300.0),
  );
  f.put(
    'recipe_ingredients',
    ing('ri-02', 'rec-01'),
  ); // free-text ingredient, no food
  if (orphans) {
    f.put(
      'recipe_ingredients',
      ing('ri-loose', 'rec-01', foodId: 'ghost-food'),
    ); // loose food reference
    f.put('recipe_ingredients', ing('ri-orphan', 'ghost-recipe')); // orphan
  }
  if (v >= 5) {
    f.put('recipe_substitutes', {
      'id': 'rs-01',
      'recipe_ingredient_id': 'ri-01',
      'sort_order': 0,
      'name': 'Tofu',
      'amount': 150.0,
      'unit': 'g',
      'kcal': 180.0,
      'provenance': 'userEntered',
    });
    f.put('meal_plan_items', {
      'id': 'mp-01',
      ..._stamps(),
      'day': '2026-01-16',
      'meal': 'dinner',
      'kind': 'recipe',
      'ref_id': 'rec-01',
      'name': 'Stew',
      'amount': 1.0,
      'unit': 'portion',
      'sort_order': 0,
    });
    f.put('prep_batches', {
      'id': 'pb-01',
      ..._stamps(),
      'recipe_id': 'rec-01',
      'prepared_at': _t1,
      'portions_made': 4.0,
      'portions_remaining': 0.0,
    });
    if (orphans) {
      f.put('recipe_substitutes', {
        'id': 'rs-orphan',
        'recipe_ingredient_id': 'ghost-ingredient',
        'sort_order': 0,
        'name': 'Orphan',
        'amount': 1.0,
        'unit': 'g',
        'kcal': 1.0,
        'provenance': 'userEntered',
      });
      f.put('meal_plan_items', {
        'id': 'mp-loose',
        ..._stamps(deleted: _t3),
        'day': '2026-01-16',
        'meal': 'lunch',
        'kind': 'food',
        'ref_id': 'ghost-food',
        'name': 'Ghost',
        'amount': 1.0,
        'unit': 'g',
        'eaten_entry_id': 'ghost-entry',
        'sort_order': 1,
      });
      f.put('prep_batches', {
        'id': 'pb-orphan',
        ..._stamps(),
        'recipe_id': 'ghost-recipe',
        'prepared_at': _t2,
        'portions_made': 2.5,
        'portions_remaining': 2.5,
      });
    }
  }
}

/// Library exercises (`assets/seed/exercise_library.json`) used by the v6 and
/// v7 fixtures: the first [n] entries, inserted as `ImportExerciseLibrary`
/// does (supplied = 1, aliases, search key).
List<Map<String, dynamic>> _libraryRows(int n) {
  final json = jsonDecode(
    File('assets/seed/exercise_library.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return [
    for (final e in (json['exercises'] as List).take(n))
      e as Map<String, dynamic>,
  ];
}

/// Exercises of schema v2..v7. Carries every muscle hazard the planned v8
/// migration must report: unmapped primary and secondary text, `fullBody`
/// as a secondary, secondary equal to the primary, a secondary repeated in
/// one list, an empty primary, non-JSON lists, an unmapped type and
/// category, free-text case and synonyms (v2..v5), soft-deleted and
/// non-ASCII rows. v6 and v7 additionally hold library rows (`lib-*`,
/// supplied) and user copies of them (`copied_from_id`).
void _exercises(_Fx f, int v) {
  final preV6 = v <= 5; // is_custom, free text
  Map<String, Object?> ex(
    String id,
    String name,
    String type,
    String category,
    String primary,
    String secondary,
    String equipment, {
    bool custom = false,
    String? deleted,
    int archived = 0,
    String? copiedFrom,
    String aliases = '[]',
  }) {
    final m = <String, Object?>{
      'id': id,
      ..._stamps(deleted: deleted),
      'name': name,
      'type': type,
      'category': category,
      'primary_muscle': primary,
      'secondary_muscles_json': secondary,
      'equipment_json': equipment,
      'archived': archived,
    };
    if (preV6) {
      m['is_custom'] = custom ? 1 : 0;
    } else {
      m['supplied'] = custom ? 0 : 1;
      m['aliases_json'] = aliases;
      m['search_key'] = exerciseSearchKey(
        name,
        (jsonDecode(aliases) as List).cast<String>(),
      );
      m['copied_from_id'] = copiedFrom;
    }
    return m;
  }

  // Identifier spelling for v6/v7, free text (case, spaces, synonyms) before.
  String pick(String ident, String free) => preV6 ? free : ident;
  if (!preV6) {
    for (final e in _libraryRows(12)) {
      final aliases = (e['aliases'] as List).cast<String>();
      f.put('exercises', {
        'id': e['id'],
        ..._stamps(at: _tSeed),
        'name': e['name'],
        'type': e['type'],
        'category': e['category'],
        'primary_muscle': e['primaryMuscle'],
        'secondary_muscles_json': jsonEncode(e['secondaryMuscles']),
        'equipment_json': jsonEncode(e['equipment']),
        'aliases_json': jsonEncode(aliases),
        'search_key': exerciseSearchKey(e['name'] as String, aliases),
        'supplied': 1,
        'copied_from_id': null,
        'archived': 0,
      });
    }
  }
  f.put(
    'exercises',
    ex(
      'ex-bench',
      'Bench Press',
      pick('weighted', 'Weighted'),
      pick('push', 'Push'),
      pick('chest', 'Chest'),
      preV6 ? '["Triceps","front delts"]' : '["triceps","frontDelts"]',
      preV6 ? '["Barbell","Bench"]' : '["barbell","bench"]',
      custom: !preV6,
    ),
  );
  f.put(
    'exercises',
    ex(
      'ex-squat',
      'Back Squat (mine)',
      'weighted',
      pick('legs', 'Legs'),
      pick('quadriceps', 'Quads'),
      preV6 ? '["Glutes","hams"]' : '["glutes","hamstrings"]',
      '["barbell"]',
      custom: true,
      copiedFrom: preV6 ? null : 'lib-back-squat',
    ),
  );
  f.put(
    'exercises',
    ex(
      'ex-row',
      'Row',
      'weighted',
      'pull',
      pick('lats', 'lats'),
      '["upperBack"]',
      '["cable"]',
      aliases: preV6 ? '[]' : '["Seated row","Rudern ✓"]',
      custom: true,
    ),
  );
  // Unmapped primaries (v8: no primary target) and an empty one.
  f.put(
    'exercises',
    ex(
      'ex-rotator',
      'External rotation',
      'weighted',
      'push',
      'rotator cuff',
      '["traps"]',
      '["Dumbbells","None","Pulley"]',
      custom: true,
    ),
  );
  f.put(
    'exercises',
    ex(
      'ex-neck',
      'Neck curl',
      'bodyweight',
      'core',
      'Neck',
      '["Neck","Shoulders"]',
      '[]',
      custom: true,
    ),
  );
  f.put(
    'exercises',
    ex(
      'ex-empty',
      'No muscle given',
      'bodyweight',
      'core',
      '',
      '[]',
      '[]',
      custom: true,
    ),
  );
  // Secondary equal to primary, repeated in one list, fullBody as secondary.
  f.put(
    'exercises',
    ex(
      'ex-dup',
      'Dips',
      'bodyweight',
      'push',
      pick('chest', 'Chest'),
      preV6
          ? '["chest","Chest","triceps","triceps"]'
          : '["chest","triceps","triceps","chest"]',
      '["bodyweight"]',
      custom: true,
    ),
  );
  f.put(
    'exercises',
    ex(
      'ex-full',
      'Burpee',
      'bodyweight',
      'fullBody',
      pick('quadriceps', 'quads'),
      preV6 ? '["full body","fullBody"]' : '["fullBody","fullBody","glutes"]',
      '[]',
      custom: true,
    ),
  );
  // Unmapped secondary text next to a mapped primary.
  f.put(
    'exercises',
    ex(
      'ex-trapsec',
      'Face pull',
      'weighted',
      'pull',
      pick('rearDelts', 'rear delts'),
      '["trapezius muscle","rhomboid","${preV6 ? 'Lats' : 'lats'}"]',
      '["cable"]',
      custom: true,
    ),
  );
  // Unmapped required enum text (type and category), and a synonym row.
  f.put(
    'exercises',
    ex(
      'ex-unmapped-enums',
      'Plyo hops',
      'Aerobic',
      'Plyometrics',
      pick('quadriceps', 'quads'),
      '[]',
      '[]',
      custom: true,
    ),
  );
  if (preV6) {
    f.put(
      'exercises',
      ex(
        'ex-stretch',
        'Hamstring stretch',
        'timed',
        'Stretching',
        'hamstrings',
        '[]',
        '[]',
        custom: true,
      ),
    ); // Stretching -> mobility
  }
  // Non-JSON list columns (a damaged or hand-edited row).
  f.put(
    'exercises',
    ex(
      'ex-garbage',
      'Garbage lists',
      'weighted',
      'push',
      pick('chest', 'chest'),
      'not json',
      '{"a":1}',
      custom: true,
    ),
  );
  // Soft-deleted, archived, non-ASCII, quote characters, long name.
  f.put(
    'exercises',
    ex(
      'ex-deleted',
      _unicodeName,
      'timed',
      'core',
      pick('abs', 'Abs'),
      '[]',
      '[]',
      deleted: _t2,
      archived: 1,
      custom: true,
    ),
  );
  f.put(
    'exercises',
    ex(
      'ex-quote',
      _quoted,
      'weighted',
      'push',
      pick('triceps', 'triceps'),
      '[]',
      '[]',
      custom: true,
      copiedFrom: preV6 ? null : 'ex-bench',
    ),
  );
  f.put(
    'exercises',
    ex(
      'ex-long',
      'Long name ${'x' * 300}',
      'distance',
      'cardio',
      pick('fullBody', 'Full Body'),
      '[]',
      '["treadmill"]',
      custom: true,
    ),
  );
}

void _plans(_Fx f, int v, bool orphans) {
  f.put('workout_plans', {
    'id': 'plan-01',
    ..._stamps(),
    'name': 'Push A',
    'split': 'push',
    'scheduled_weekdays_json': '[1,3]',
    'archived': 0,
  });
  f.put('workout_plans', {
    'id': 'plan-02',
    ..._stamps(deleted: _t2),
    'name': _unicodeName,
    'scheduled_weekdays_json': '[]',
    'archived': 1,
  });
  f.put('workout_plans', {
    'id': 'plan-03',
    ..._stamps(),
    'name': 'Empty plan',
    'scheduled_weekdays_json': '[]',
  });
  final preV6 = v <= 5;
  Map<String, Object?> pe(
    String id,
    String plan,
    String exercise,
    int order,
    int sets, {
    Object? reps,
    double? load,
    int? dur,
    double? metres,
    int? rest,
    Object? repsMax,
  }) {
    final m = <String, Object?>{
      'id': id,
      'plan_id': plan,
      'exercise_id': exercise,
      'sort_order': order,
      'target_sets': sets,
      'target_load_kg': load,
      'target_duration_sec': dur,
      'rest_seconds': rest,
    };
    if (preV6) {
      m['target_reps'] = reps;
    } else {
      m['reps_min'] = reps;
      m['reps_max'] = repsMax ?? reps;
      m['target_metres'] = metres;
    }
    return m;
  }

  final lib = preV6 ? 'ex-squat' : 'lib-back-squat';
  f.put(
    'plan_exercises',
    pe('pe-01', 'plan-01', 'ex-bench', 0, 4, reps: 5, load: 80.0, rest: 120),
  );
  f.put('plan_exercises', pe('pe-02', 'plan-01', lib, 1, 3, reps: 10));
  f.put(
    'plan_exercises',
    pe('pe-04', 'plan-01', 'ex-row', 2, 3, dur: 600),
  ); // all-null reps
  f.put(
    'plan_exercises',
    pe('pe-05', 'plan-03', 'ex-long', 0, 1, metres: 5000.0, dur: 1800),
  );
  // Valid boundary values of the v6 CHECKs.
  f.put(
    'plan_exercises',
    pe(
      'pe-b-min',
      'plan-02',
      'ex-row',
      0,
      1,
      reps: 1,
      load: 0.0,
      dur: 1,
      metres: 0.1,
      rest: 0,
    ),
  );
  f.put(
    'plan_exercises',
    pe(
      'pe-b-max',
      'plan-02',
      'ex-row',
      1,
      20,
      reps: 100,
      load: 1000.0,
      rest: 3600,
    ),
  );
  if (preV6) {
    // Values outside the v6 CHECKs: nullable ones become NULL, a NOT NULL
    // one removes the row (both go to legacy_quarantine).
    f.put(
      'plan_exercises',
      pe('pe-bad-reps', 'plan-01', 'ex-bench', 3, 3, reps: 0),
    );
    f.put(
      'plan_exercises',
      pe('pe-bad-reps2', 'plan-01', 'ex-bench', 4, 3, reps: 101),
    );
    f.put(
      'plan_exercises',
      pe('pe-bad-load', 'plan-01', 'ex-bench', 5, 3, reps: 5, load: -2.5),
    );
    f.put(
      'plan_exercises',
      pe('pe-bad-load2', 'plan-01', 'ex-bench', 6, 3, reps: 5, load: 1500.0),
    );
    f.put(
      'plan_exercises',
      pe('pe-bad-dur', 'plan-01', 'ex-row', 7, 3, dur: 0),
    );
    f.put(
      'plan_exercises',
      pe('pe-bad-rest', 'plan-01', 'ex-row', 8, 3, reps: 5, rest: 3601),
    );
    f.put(
      'plan_exercises',
      pe('pe-bad-sets', 'plan-01', 'ex-row', 9, 0, reps: 5),
    );
    f.put(
      'plan_exercises',
      pe('pe-bad-sets2', 'plan-01', 'ex-row', 10, 21, reps: 5),
    );
    f.put(
      'plan_exercises',
      pe('pe-bad-order', 'plan-01', 'ex-row', -1, 3, reps: 5),
    );
  } else {
    f.put(
      'plan_exercises',
      pe(
        'pe-range',
        'plan-01',
        'ex-squat',
        3,
        5,
        reps: 6,
        repsMax: 8,
        load: 100.0,
      ),
    );
  }
  if (orphans) {
    f.put(
      'plan_exercises',
      pe('pe-loose', 'plan-01', 'ghost-exercise', 20, 3, reps: 10),
    ); // loose exercise reference
    f.put(
      'plan_exercises',
      pe('pe-orphan', 'ghost-plan', 'ex-row', 0, 3, reps: 8),
    ); // FK orphan
  }
}

/// RPE / RIR / other exertion values. v6 and v7 enforce 0..10 on the value
/// only, so every pair here is storable there; before v6 values outside
/// 0..10 are added as well.
const _exertion = <(String?, double?)>[
  ('rpe', 8.5), // valid
  ('rpe', 10.0), // valid
  ('rpe', 1.0), // valid
  ('rpe', 0.0), // TRN-020: RPE starts at 1
  ('rpe', 0.5), // TRN-020: RPE starts at 1
  ('rpe', 7.3), // TRN-020: not a half step
  ('rpe', 9.75), // TRN-020: not a half step
  ('rir', 0.0), // valid
  ('rir', 3.0), // valid
  ('rir', 5.0), // valid
  ('rir', 2.5), // TRN-020: RIR is an integer
  ('rir', 6.0), // TRN-020: RIR is 0..5
  ('borg', 6.0), // TRN-020: unknown scale
  ('RPE', 8.0), // TRN-020: scale spelled in capitals
  (null, 7.0), // value without scale
  ('rpe', null), // scale without value
  (null, null), // none
];

void _training(_Fx f, int v, bool orphans) {
  final preV6 = v <= 5;
  final v6plus = v >= 6;
  final v7 = v >= 7;
  // Exercises the sessions use: library rows from v6 on.
  final squat = preV6 ? 'ex-squat' : 'lib-back-squat';
  final deadlift = preV6 ? 'ex-row' : 'lib-deadlift';
  f.put('workout_sessions', {
    'id': 'sess-01',
    ..._stamps(),
    'name': 'Push',
    'plan_id': 'plan-01',
    'started_at': _t1,
    'ended_at': _t2,
    'notes': text4000(),
  });
  f.put('workout_sessions', {
    'id': 'sess-02',
    ..._stamps(deleted: _t3),
    'name': _unicodeName,
    'started_at': _t2,
    'notes': 'deleted session',
  });
  f.put('workout_sessions', {
    'id': 'sess-03',
    ..._stamps(),
    'name': 'No plan',
    'started_at': _t3,
  });
  f.put('workout_sessions', {
    'id': 'sess-04',
    ..._stamps(),
    'name': _quoted,
    'started_at': _t3,
    'ended_at': null,
    'notes': '',
  });
  f.put('workout_sessions', {
    'id': 'sess-05',
    ..._stamps(),
    'name': 'Boundaries',
    'started_at': _t3,
  });
  if (orphans) {
    f.put('workout_sessions', {
      'id': 'sess-loose',
      ..._stamps(),
      'name': 'Loose plan',
      'plan_id': 'ghost-plan',
      'started_at': _t3,
    });
  }

  var n = 0;
  Map<String, Object?> mkSet(
    String session,
    String exercise,
    int exOrder,
    int setOrder, {
    String type = 'weighted',
    double? load,
    int? reps,
    double? assist,
    int? dur,
    double? metres,
    int? hr,
    int completed = 1,
    String? scale,
    double? value,
    int? rest,
    String? note,
    double? kcal,
    String? kcalProv,
    String kind = 'working',
    String? entry,
    String? id,
  }) {
    n++;
    final m = <String, Object?>{
      'id': id ?? 'set-${n.toString().padLeft(3, '0')}',
      'session_id': session,
      'exercise_id': exercise,
      'exercise_order': exOrder,
      'set_order': setOrder,
      'type': type,
      'load_kg': load,
      'reps': reps,
      'assistance_kg': assist,
      'duration_sec': dur,
      'metres': metres,
      'average_heart_rate': hr,
      'completed': completed,
      'exertion_scale': scale,
      'exertion_value': value,
      'rest_seconds': rest,
      'note': note,
    };
    if (v6plus) {
      m['energy_kcal'] = kcal;
      m['energy_provenance'] = kcalProv;
    }
    if (v7) {
      m['set_kind'] = kind;
      m['session_exercise_id'] = entry;
    }
    return m;
  }

  String? e(String id) => v7 ? id : null;
  if (v7) {
    // Entries first (sets reference them).
    Map<String, Object?> entry(
      String id,
      String session,
      int position,
      String exercise, {
      String? note,
    }) => {
      'id': id,
      'session_id': session,
      'position': position,
      'exercise_id': exercise,
      'note': note,
    };
    f.put(
      'session_exercises',
      entry('se-01', 'sess-01', 0, 'ex-bench', note: text4000('Übung ✓ 😀 ')),
    );
    f.put('session_exercises', entry('se-02', 'sess-01', 1, 'ex-row'));
    f.put(
      'session_exercises',
      entry('se-03', 'sess-01', 2, 'ex-bench', note: _unicodeName),
    ); // same exercise twice
    f.put('session_exercises', entry('se-04', 'sess-01', 3, 'ex-long'));
    f.put(
      'session_exercises',
      entry('se-05', 'sess-02', 0, 'ex-deleted'),
    ); // soft-deleted session
    f.put('session_exercises', entry('se-06', 'sess-03', 0, 'ex-row'));
    f.put(
      'session_exercises',
      entry('se-07', 'sess-03', 1, 'ex-bench'),
    ); // same order as se-06's sets, other exercise
    f.put('session_exercises', entry('se-08', 'sess-01', 4, squat));
    f.put('session_exercises', entry('se-09', 'sess-01', 5, deadlift));
    f.put('session_exercises', entry('se-x', 'sess-04', 0, 'ex-bench'));
    f.put('session_exercises', entry('se-b', 'sess-05', 0, 'ex-row'));
  }

  // Regular sets: valid, null-heavy and non-ASCII.
  f.put(
    'session_sets',
    mkSet(
      'sess-01',
      'ex-bench',
      0,
      0,
      load: 80.0,
      reps: 5,
      scale: 'rpe',
      value: 8.0,
      rest: 120,
      note: 'ok',
      entry: e('se-01'),
    ),
  );
  f.put(
    'session_sets',
    mkSet(
      'sess-01',
      'ex-bench',
      0,
      1,
      load: 0.0,
      reps: 1,
      kind: 'warmUp',
      entry: e('se-01'),
    ),
  ); // zero load
  f.put(
    'session_sets',
    mkSet('sess-01', 'ex-bench', 0, 2, completed: 0, entry: e('se-01')),
  ); // all optional values null
  f.put(
    'session_sets',
    mkSet(
      'sess-01',
      'ex-row',
      1,
      0,
      load: 60.5,
      reps: 10,
      note: text4000(),
      entry: e('se-02'),
    ),
  );
  f.put(
    'session_sets',
    mkSet(
      'sess-01',
      'ex-bench',
      2,
      0,
      load: 77.5,
      reps: 6,
      kind: 'failure',
      note: _unicodeName,
      entry: e('se-03'),
    ),
  );
  f.put(
    'session_sets',
    mkSet(
      'sess-01',
      'ex-long',
      3,
      0,
      type: 'distance',
      metres: 5000.0,
      dur: 1800,
      hr: 150,
      entry: e('se-04'),
    ),
  );
  f.put(
    'session_sets',
    mkSet(
      'sess-01',
      squat,
      4,
      0,
      load: 100.0,
      reps: 5,
      note: _quoted,
      entry: e('se-08'),
    ),
  );
  f.put(
    'session_sets',
    mkSet(
      'sess-01',
      deadlift,
      5,
      0,
      load: 140.0,
      reps: 3,
      scale: 'rir',
      value: 2.0,
      entry: e('se-09'),
    ),
  );
  f.put(
    'session_sets',
    mkSet(
      'sess-02',
      'ex-deleted',
      0,
      0,
      type: 'timed',
      dur: 60,
      entry: e('se-05'),
    ),
  ); // soft-deleted session
  f.put(
    'session_sets',
    mkSet('sess-03', 'ex-row', 0, 0, load: 40.0, reps: 12, entry: e('se-06')),
  );
  f.put(
    'session_sets',
    mkSet('sess-03', 'ex-bench', 0, 1, load: 40.0, reps: 12, entry: e('se-07')),
  );
  if (v6plus) {
    f.put(
      'session_sets',
      mkSet(
        'sess-01',
        'ex-long',
        3,
        1,
        type: 'cardio',
        dur: 600,
        kcal: 120.0,
        kcalProv: 'estimated',
        entry: e('se-04'),
      ),
    );
    f.put(
      'session_sets',
      mkSet(
        'sess-01',
        'ex-long',
        3,
        2,
        type: 'cardio',
        dur: 600,
        kcal: 0.0,
        kcalProv: 'userEntered',
        entry: e('se-04'),
      ),
    );
  }

  // Valid boundary values of the v6 CHECKs (also valid before v6).
  var b = 0;
  void boundary({
    int? reps,
    double? load,
    double? assist,
    int? dur,
    double? metres,
    int? hr,
    int? rest,
    String? scale,
    double? value,
  }) {
    b++;
    f.put(
      'session_sets',
      mkSet(
        'sess-05',
        'ex-row',
        0,
        b,
        reps: reps,
        load: load,
        assist: assist,
        dur: dur,
        metres: metres,
        hr: hr,
        rest: rest,
        scale: scale,
        value: value,
        entry: e('se-b'),
        id: 'set-bound-${b.toString().padLeft(2, '0')}',
      ),
    );
  }

  boundary(
    reps: 1,
    load: 0.0,
    assist: 0.0,
    dur: 1,
    metres: 0.1,
    hr: 30,
    rest: 0,
    scale: 'rpe',
    value: 1.0,
  );
  boundary(
    reps: 100,
    load: 1000.0,
    assist: 1000.0,
    dur: 86400,
    metres: 100000.0,
    hr: 250,
    rest: 3600,
    scale: 'rpe',
    value: 10.0,
  );
  boundary(reps: 12, scale: 'rir', value: 0.0);
  boundary(reps: 12, scale: 'rir', value: 5.0);
  if (v6plus) {
    f.put(
      'session_sets',
      mkSet(
        'sess-05',
        'ex-row',
        0,
        9,
        type: 'cardio',
        dur: 60,
        kcal: 0.0,
        kcalProv: 'userEntered',
        entry: e('se-b'),
        id: 'set-bound-09',
      ),
    );
  }

  // TRN-020 exertion combinations, one set each (session sess-04, ex-bench).
  var k = 0;
  for (final (scale, value) in _exertion) {
    k++;
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-bench',
        0,
        k,
        load: 50.0,
        reps: 8,
        scale: scale,
        value: value,
        entry: e('se-x'),
        id: 'set-exert-${k.toString().padLeft(2, '0')}',
      ),
    );
  }
  if (preV6) {
    // Beyond the v6 CHECKs. Nullable values become NULL; the row is kept.
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-bench',
        1,
        0,
        load: 50.0,
        reps: 8,
        scale: 'rpe',
        value: 11.0,
        id: 'set-bad-exertion-high',
      ),
    );
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-bench',
        1,
        1,
        load: 50.0,
        reps: 8,
        scale: 'rpe',
        value: -1.0,
        id: 'set-bad-exertion-low',
      ),
    );
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-bench',
        1,
        2,
        load: 50.0,
        reps: 0,
        id: 'set-bad-reps-0',
      ),
    );
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-bench',
        1,
        3,
        load: 50.0,
        reps: 101,
        id: 'set-bad-reps-101',
      ),
    );
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-bench',
        1,
        4,
        load: -5.0,
        reps: 5,
        id: 'set-bad-load-neg',
      ),
    );
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-bench',
        1,
        5,
        load: 1500.0,
        reps: 5,
        id: 'set-bad-load-big',
      ),
    );
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-bench',
        1,
        6,
        assist: 1001.0,
        reps: 5,
        id: 'set-bad-assist',
      ),
    );
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-row',
        2,
        0,
        type: 'timed',
        dur: 0,
        id: 'set-bad-duration',
      ),
    );
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-row',
        2,
        1,
        type: 'distance',
        metres: 0.0,
        id: 'set-bad-metres',
      ),
    );
    f.put(
      'session_sets',
      mkSet('sess-04', 'ex-row', 2, 2, hr: 20, reps: 5, id: 'set-bad-hr-low'),
    );
    f.put(
      'session_sets',
      mkSet('sess-04', 'ex-row', 2, 3, hr: 300, reps: 5, id: 'set-bad-hr-high'),
    );
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-row',
        2,
        4,
        rest: -1,
        reps: 5,
        id: 'set-bad-rest-neg',
      ),
    );
    f.put(
      'session_sets',
      mkSet(
        'sess-04',
        'ex-row',
        2,
        5,
        rest: 3601,
        reps: 5,
        id: 'set-bad-rest-big',
      ),
    );
  }

  if (v7) {
    f.put('scheduled_workouts', {
      'id': 'sw-01',
      ..._stamps(),
      'day': '2026-01-19',
      'source_day': '2026-01-19',
      'plan_id': 'plan-01',
      'origin': 'weekday',
      'status': 'planned',
    });
    f.put('scheduled_workouts', {
      'id': 'sw-02',
      ..._stamps(),
      'day': '2026-01-20',
      'source_day': '2026-01-18',
      'plan_id': 'plan-01',
      'origin': 'date',
      'status': 'done',
      'session_id': 'sess-01',
    });
    f.put('scheduled_workouts', {
      'id': 'sw-03',
      ..._stamps(deleted: _t3),
      'day': '2026-01-21',
      'source_day': '2026-01-21',
      'plan_id': 'plan-02',
      'origin': 'split',
      'status': 'skipped',
    });
  }

  if (orphans) {
    f.put(
      'session_sets',
      mkSet(
        'sess-01',
        'ghost-exercise',
        6,
        0,
        load: 10.0,
        reps: 10,
        note: _quoted,
        entry: e('se-04'),
        id: 'set-loose-exercise',
      ),
    ); // loose exercise
    f.put(
      'session_sets',
      mkSet(
        'ghost-session',
        'ex-bench',
        0,
        0,
        load: 20.0,
        reps: 5,
        entry: v7 ? 'se-orphan' : null,
        id: 'set-orphan-session',
      ),
    ); // FK orphan: no session
    if (v7) {
      f.put('session_exercises', {
        'id': 'se-orphan',
        'session_id': 'ghost-session',
        'position': 0,
        'exercise_id': 'ex-bench',
      }); // FK orphan
      f.put('session_exercises', {
        'id': 'se-loose',
        'session_id': 'sess-01',
        'position': 6,
        'exercise_id': 'ghost-exercise',
      }); // loose exercise
      // A set without an entry (a damaged v7 file), one whose entry is gone.
      f.put(
        'session_sets',
        mkSet('sess-01', squat, 7, 0, load: 100.0, reps: 5, id: 'set-no-entry'),
      );
      f.put(
        'session_sets',
        mkSet(
          'sess-01',
          squat,
          7,
          1,
          load: 100.0,
          reps: 5,
          entry: 'se-ghost',
          id: 'set-ghost-entry',
        ),
      ); // FK orphan: entry missing
      f.put('scheduled_workouts', {
        'id': 'sw-loose',
        ..._stamps(deleted: _t3),
        'day': '2026-01-22',
        'source_day': '2026-01-22',
        'plan_id': 'ghost-plan',
        'origin': 'split',
        'status': 'skipped',
        'session_id': 'ghost-session',
      });
    }
  }
}

void _splitsAndQuarantine(_Fx f, bool orphans) {
  f.put('training_splits', {
    'id': 'split-01',
    ..._stamps(),
    'name': 'PPL',
    'cycle_days': 7,
    'sort_order': 1,
  });
  f.put('training_splits', {
    'id': 'split-02',
    ..._stamps(deleted: _t3),
    'name': _unicodeName,
    'cycle_days': 14,
  });
  f.put('split_days', {
    'id': 'sd-01',
    'split_id': 'split-01',
    'day_index': 0,
    'plan_id': 'plan-01',
  });
  f.put('split_days', {
    'id': 'sd-02',
    'split_id': 'split-01',
    'day_index': 1,
  }); // rest day, null plan
  if (orphans) {
    f.put('split_days', {
      'id': 'sd-loose',
      'split_id': 'split-01',
      'day_index': 2,
      'plan_id': 'ghost-plan',
    }); // loose plan
    f.put('split_days', {
      'id': 'sd-orphan',
      'split_id': 'ghost-split',
      'day_index': 0,
    }); // FK orphan
  }
  // Rows the v5 -> v6 migration of the era's app had already quarantined.
  f.put('legacy_quarantine', {
    'source_table': 'session_sets',
    'row_id': 'set-old-1',
    'reason': 'Out-of-range value set to NULL: reps',
    'original_json': jsonEncode({'id': 'set-old-1', 'reps': 0}),
    'quarantined_at': _quarantineStamp,
  });
  f.put('legacy_quarantine', {
    'source_table': 'exercises',
    'row_id': 'ex-old',
    'reason': 'Unrecognised secondary muscle(s) dropped: Neck',
    'original_json': jsonEncode({'id': 'ex-old', 'name': _unicodeName}),
    'quarantined_at': _quarantineStamp,
  });
}

void _goals(_Fx f) {
  f.put('goals', {
    'id': 'goal-01',
    ..._stamps(),
    'kind': 'weight',
    'site': 'weight',
    'target': 80.0,
    'start_date': '2026-01-01',
    'end_date': '2026-06-01',
    'active': 1,
  });
  f.put('goals', {
    'id': 'goal-02',
    ..._stamps(deleted: _t2),
    'kind': 'calories',
    'target': 2400.0,
    'start_date': '2026-01-01',
    'active': 0,
  });
}

// ---- Builders --------------------------------------------------------------

void _populate(Database db, int v, {required bool orphans}) {
  final f = _Fx(db);
  db.execute('BEGIN');
  if (v == 1) {
    Map<String, Object?> w(
      String id,
      double kg, {
      String? note,
      String? deleted,
      String at = _t1,
    }) => {
      'id': id,
      'recorded_at': at,
      'weight_kg': kg,
      'note': note,
      'created_at': _t1,
      'updated_at': _t1,
      'deleted_at': deleted,
    };
    f.put('weight_entries', w('w-01', 82.4, note: 'morning'));
    f.put('weight_entries', w('w-02', 82.0, at: _t2)); // null note
    f.put(
      'weight_entries',
      w('w-03', 81.5, deleted: _t2, at: _t2),
    ); // soft-deleted
    f.put('weight_entries', w('w-04', 81.2, note: _unicodeName, at: _t3));
    f.put('weight_entries', w('w-05', 80.9, note: text4000(), at: _t3));
    f.put(
      'weight_entries',
      w('w-06', 0.0, note: _quoted, at: _t3),
    ); // edge value
    f.put('weight_entries', w('w-07', 79.95)); // same instant as w-01
    f.put(
      'weight_entries',
      w('w-08', 80.1, at: '2026-01-18T09:00:00+01:00'),
    ); // UTC offset, not Z
  } else {
    _measurements(f);
    _nutrition(f, v, orphans);
    _recipes(f, v, orphans);
    _exercises(f, v);
    _plans(f, v, orphans);
    _training(f, v, orphans);
    if (v >= 6) _splitsAndQuarantine(f, orphans);
    _goals(f);
    for (final s in realSettings(v)) {
      f.put('settings', s);
    }
  }
  db.execute('COMMIT');
}

Future<void> _createFixture(int v, {required bool orphans}) async {
  final path = fixturePath(v, orphans: orphans);
  _refuseOverwrite(path);
  final gen = GeneratedHelper().databaseForVersion(
    NativeDatabase(File(path)),
    v,
  );
  await gen
      .customSelect('SELECT 1')
      .get(); // creates the schema, user_version = v
  await gen.close();
  final db = sqlite3.open(path);
  try {
    _populate(db, v, orphans: orphans);
    // Journal mode stays `delete`; no WAL sidecar files are left behind.
  } finally {
    db.close();
  }
}

void _refuseOverwrite(String path) {
  if (File(path).existsSync()) {
    throw StateError(
      '$path already exists. The artefacts are frozen evidence and are never '
      'regenerated; add a new file under a new name instead.',
    );
  }
}

void _write(String path, String content) {
  _refuseOverwrite(path);
  File(path).writeAsStringSync(content);
}

/// Everything the manifest covers, relative to `app/`.
List<String> manifestFiles() => [
  for (final (_, p) in allFixtures()) p,
  for (final (_, p) in allGoldens()) p,
  expectedDigestsPath,
  for (var v = 1; v <= 7; v++) 'drift_schemas/drift_schema_v$v.json',
  for (var v = 1; v <= 7; v++) 'test/data/generated_migrations/schema_v$v.dart',
];

String manifestText() =>
    manifestFiles().map((p) => '${sha256OfFile(p)}  $p\n').join();

void main() {
  test('build the frozen v8 migration evidence', () async {
    expect(Directory('lib').existsSync(), isTrue, reason: 'run from app/');
    Directory(fixturesDir).createSync(recursive: true);

    // 1. Fixtures: clean (zero FK violations) and orphans.
    for (final (key, path) in allFixtures()) {
      final orphans = key.endsWith('_orphans');
      final v = int.parse(key.substring(1).split('_').first);
      await _createFixture(v, orphans: orphans);
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        expect(userVersion(db), v);
        expect(
          jsonEncode(describeSchema(db)),
          jsonEncode(await freshSchemaDescription(v)),
          reason: '$key schema',
        );
        expect(integrityCheck(db), 'ok');
        if (orphans) {
          expect(
            foreignKeyViolations(db),
            isNotEmpty,
            reason: '$key must carry FK orphans',
          );
        } else {
          expect(
            foreignKeyViolations(db),
            isEmpty,
            reason: '$key must be FK-clean',
          );
        }
      } finally {
        db.close();
      }
    }

    // 2. Golden backups. Format 1: the era exporter over the fixture.
    for (final v in goldenFormat1Versions) {
      expect(
        eraTableOrder[v],
        await generatedTableOrder(v),
        reason: 'era table order v$v',
      );
      for (final orphans in [false, true]) {
        final db = sqlite3.open(
          fixturePath(v, orphans: orphans),
          mode: OpenMode.readOnly,
        );
        try {
          _write(
            goldenFormat1Path(v, orphans: orphans),
            '${exportFormat1(db, v)}\n',
          );
        } finally {
          db.close();
        }
      }
    }
    // Format 2: the production repository on the v7 fixture, opened at v7.
    for (final orphans in [false, true]) {
      _write(
        goldenFormat2Path(orphans: orphans),
        '${await exportFormat2FromFixture(orphans: orphans)}\n',
      );
    }
    // Settings-only backups (valid data, zero records besides settings).
    _write(
      goldenFormat1SettingsOnlyPath,
      '${await settingsOnlyFormat1(realSettings(6))}\n',
    );
    _write(
      goldenFormat2SettingsOnlyPath,
      '${await settingsOnlyFormat2(realSettings(7))}\n',
    );

    // 3. Expected results of the CURRENT production code.
    final digests = await expectedDigests(
      generatedV7Schema: await freshSchemaDescription(7),
      productionFreshSchema: await productionFreshSchemaDescription(),
    );
    final restores = await expectedRestores();
    _write(expectedDigestsPath, encodeJson(expectedFile(digests, restores)));

    // 4. Manifest (last, over everything above).
    _write(manifestPath, manifestText());
  });
}
