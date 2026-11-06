import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart' show ExerciseRow;
import 'package:repforge/data/mappers/training_mappers.dart';
import 'package:sqlite3/sqlite3.dart';

import '../migration_trial/trial_fixture.dart' show buildV7Fixture;
import 'large/large_profile.dart' show buildLargeProfile;
import 'migration_digest.dart' show allFixtures;
import 'v8_migration_support.dart';

/// Visibility parity of the unreadable-data decision (D04 §7, 2026-11-06,
/// stage 3b decision baseline: "restoration never makes hidden information
/// newly visible"; review DB L4).
///
/// For each input, the set of exercises the **real v7 mapper** hides
/// (`TrainingMappers.exerciseToEntity` returns null, or a column is not
/// even text) equals the set of exercises the v7 → v8 migration blocks:
/// nothing newly visible, nothing newly hidden. Inputs: every frozen
/// fixture (through the frozen chain to v7), the comparison-trial profile,
/// the trial profile with the damage of `v8_large_profile_test.dart`, 32
/// edge cases on the v7 fixture and (heavy) the D04 profile.
void main() {
  for (final (key, path) in allFixtures()) {
    test('frozen fixture $key', () async {
      await inTempDir((dir) async {
        await expectParity(key, await v7Copy(path, dir), dir);
      });
    });
  }

  test('comparison-trial profile', () async {
    await inTempDir((dir) async {
      final v7 = File('${dir.path}/trial.sqlite');
      await buildV7Fixture(v7.path);
      final r = await expectParity('trial', v7, dir);
      expect(r.hidden, greaterThan(0));
    });
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('comparison-trial profile with unreadable type, category, aliases '
      'and equipment', () async {
    await inTempDir((dir) async {
      final v7 = File('${dir.path}/trial_damaged.sqlite');
      await buildV7Fixture(v7.path);
      final d = sqlite3.open(v7.path);
      try {
        d
          ..execute(
            "UPDATE exercises SET type = 'Aerobic' WHERE rowid % 397 = 0",
          )
          ..execute(
            "UPDATE exercises SET category = 'Stretching' "
            'WHERE rowid % 401 = 1',
          )
          ..execute(
            "UPDATE exercises SET aliases_json = 'a, b' WHERE rowid % 409 = 2",
          )
          ..execute(
            'UPDATE exercises SET aliases_json = \'["x",1]\' '
            'WHERE rowid % 419 = 3',
          )
          ..execute(
            "UPDATE exercises SET equipment_json = 'barbell, bench' "
            'WHERE rowid % 431 = 4',
          );
      } finally {
        d.close();
      }
      final r = await expectParity('trial-damaged', v7, dir);
      expect(
        r.reasons.keys,
        containsAll(['invalidClassification', 'invalidAliases']),
      );
    });
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('32 edge cases on the v7 fixture', () async {
    await inTempDir((dir) async {
      final v7 = await v7Copy(digestFixtureV7, dir);
      expect(edgeCases, hasLength(32));
      final d = sqlite3.open(v7.path);
      try {
        final template =
            d
                    .select('SELECT id FROM exercises ORDER BY id LIMIT 1')
                    .single['id']
                as String;
        final cols = [
          for (final r in d.select('PRAGMA table_info(exercises)'))
            r['name'] as String,
        ].where((c) => c != 'id').map((c) => '"$c"').join(', ');
        for (var i = 0; i < edgeCases.length; i++) {
          final id = 'edge-${i.toString().padLeft(2, '0')}';
          d
            ..execute(
              'INSERT INTO exercises (id, $cols) SELECT ?, $cols FROM '
              'exercises WHERE id = ?',
              [id, template],
            )
            // A readable baseline, then one edge case.
            ..execute(
              "UPDATE exercises SET name = name || ' $id', "
              "type = 'weighted', category = 'push', primary_muscle = "
              "'chest', secondary_muscles_json = '[]', equipment_json = "
              "'[]', aliases_json = '[]' WHERE id = ?",
              [id],
            )
            ..execute('UPDATE exercises SET ${edgeCases[i]} WHERE id = ?', [
              id,
            ]);
        }
      } finally {
        d.close();
      }
      final r = await expectParity('edge', v7, dir);
      // Both sides of every boundary occur: 21 edge rows hidden by v7 and
      // blocked by v8, 11 read by v7 and left selectable by v8.
      expect(r.edgeHidden, 21);
    });
  });

  test(
    'D04 profile',
    () async {
      await inTempDir((dir) async {
        final v7 = File('${dir.path}/large.sqlite');
        await buildLargeProfile(v7.path);
        await expectParity('large-d04', v7, dir);
      });
    },
    tags: ['heavy'],
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

String get digestFixtureV7 => allFixtures().singleWhere((f) => f.$1 == 'v7').$2;

/// One column change each, applied to a readable copy of a fixture row.
/// Readable and unreadable values on both sides of every v7 rule.
const edgeCases = <String>[
  "secondary_muscles_json = 'null'",
  "secondary_muscles_json = '\"chest\"'",
  "secondary_muscles_json = '[null]'",
  "secondary_muscles_json = '[\"Chest\"]'",
  "secondary_muscles_json = '[\"chest\",\"chest\"]'",
  "secondary_muscles_json = '[\"fullBody\"]'",
  "secondary_muscles_json = ' [\"chest\"] '",
  "secondary_muscles_json = '[1.0]'",
  "secondary_muscles_json = '[\"chest\"]x'",
  "secondary_muscles_json = '[]'",
  "aliases_json = '{}'",
  "aliases_json = '[]'",
  "aliases_json = '[\"a\",null]'",
  "aliases_json = 'null'",
  "aliases_json = '[[\"a\"]]'",
  "aliases_json = '[\"\"]'",
  "aliases_json = '[\"a\",\"a\"]'",
  "aliases_json = ''",
  "type = 'Weighted'",
  "type = ''",
  "type = ' weighted'",
  "category = 'fullbody'",
  "category = 'fullBody'",
  "equipment_json = '[\"barbell\",\"barbell\"]'",
  "equipment_json = '[\"Barbell\"]'",
  "equipment_json = '[]'",
  "equipment_json = 'null'",
  "primary_muscle = 'fullBody'",
  "primary_muscle = 'traps'",
  "primary_muscle = 'Chest'",
  "type = 'weighted', category = 'Push'",
  "aliases_json = '[\"x\"]', secondary_muscles_json = '[\"traps\"]'",
];

/// Ids the real v7 mapper hides, with the stored values (for diagnostics).
Map<String, String> v7Hidden(String path) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final out = <String, String>{};
    for (final r in db.select('SELECT * FROM exercises')) {
      final id = r['id'] as String;
      final values = [
        for (final c in [
          'type',
          'category',
          'primary_muscle',
          'secondary_muscles_json',
          'equipment_json',
          'aliases_json',
        ])
          r[c],
      ];
      if (values.any((v) => v is! String)) {
        out[id] = 'not text: $values';
        continue;
      }
      final [t, c, p, s, e, a] = values.cast<String>();
      final row = ExerciseRow(
        id: id,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        name: r['name'] as String,
        type: t,
        category: c,
        primaryMuscle: p,
        secondaryMusclesJson: s,
        equipmentJson: e,
        aliasesJson: a,
        searchKey: (r['search_key'] ?? '') as String,
        supplied: r['supplied'] == 1,
        archived: r['archived'] == 1,
      );
      if (TrainingMappers.exerciseToEntity(row) == null) out[id] = '$values';
    }
    return out;
  } finally {
    db.close();
  }
}

/// Active block reasons by exercise after migrating a copy of [v7].
Future<Map<String, Set<String>>> v8Blocked(File v7, Directory dir) async {
  final f = v7.copySync('${dir.path}/v8_${v7.uri.pathSegments.last}');
  final error = await openV8(f);
  if (error != null) throw StateError('migration failed: $error');
  final db = sqlite3.open(f.path, mode: OpenMode.readOnly);
  try {
    final out = <String, Set<String>>{};
    for (final r in db.select(
      'SELECT exercise_id, reason FROM exercise_blocks '
      'WHERE resolved_at IS NULL',
    )) {
      out
          .putIfAbsent(r['exercise_id'] as String, () => {})
          .add(r['reason'] as String);
    }
    return out;
  } finally {
    db.close();
  }
}

Future<({int hidden, int edgeHidden, Map<String, int> reasons})> expectParity(
  String label,
  File v7,
  Directory dir,
) async {
  final hidden = v7Hidden(v7.path);
  final blocked = await v8Blocked(v7, dir);
  final newlyVisible = hidden.keys.toSet().difference(blocked.keys.toSet());
  final newlyHidden = blocked.keys.toSet().difference(hidden.keys.toSet());
  expect(newlyVisible, isEmpty, reason: '$label newly visible: $hidden');
  expect(newlyHidden, isEmpty, reason: '$label newly hidden: $blocked');
  final reasons = <String, int>{};
  for (final s in blocked.values) {
    for (final r in s) {
      reasons.update(r, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return (
    hidden: hidden.length,
    edgeHidden: hidden.keys.where((k) => k.startsWith('edge-')).length,
    reasons: reasons,
  );
}
