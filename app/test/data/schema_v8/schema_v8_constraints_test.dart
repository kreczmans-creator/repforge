import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/library_enums.dart';

import 'v8_support.dart';

/// WP 8 stage 3b-2: the constraints of schema v8, each accepted and refused
/// case. Approved sources: ADR-0008 clarification A, B and E; plan section
/// 5; D04 TRN-020 and plan section 21 safeguard C; owner decisions of
/// 2026-11-06 (report categories, blocks).
void main() {
  late FreshV8 v8;
  setUp(() async => v8 = await FreshV8.open());
  tearDown(() => v8.close());

  group('session_sets: TRN-020 (RPE 1-10 in 0.5 steps, RIR 0-5 whole)', () {
    void seedSession() {
      v8.run(
        'INSERT INTO workout_sessions (id, created_at, updated_at, name, '
        "started_at) VALUES ('s1', ?, ?, 'S', ?)",
        [stamp, stamp, stamp],
      );
    }

    bool set(Object? scale, Object? value) => v8.accepts(
      'INSERT INTO session_sets (id, session_id, exercise_id, '
      'exercise_order, set_order, type, exertion_scale, exertion_value) '
      "VALUES ('x', 's1', 'e1', 0, 0, 'weighted', ?, ?)",
      [scale, value],
    );

    test('accepts valid pairs and no exertion', () {
      seedSession();
      for (final (scale, value) in <(Object?, Object?)>[
        (null, null),
        ('rpe', 1),
        ('rpe', 1.5),
        ('rpe', 7.5),
        ('rpe', 8),
        ('rpe', 10),
        ('rpe', 10.0),
        ('rir', 0),
        ('rir', 3),
        ('rir', 5),
        ('rir', 4.0),
        // REAL affinity stores a numeric text as the number 8.5.
        ('rpe', '8.5'),
      ]) {
        expect(set(scale, value), isTrue, reason: '$scale $value');
      }
    });

    test('rejects values off the rule, unpaired values and other scales', () {
      seedSession();
      for (final (scale, value) in <(Object?, Object?)>[
        ('rpe', 0),
        ('rpe', 0.5),
        ('rpe', 10.5),
        ('rpe', 11),
        ('rpe', 7.3),
        ('rpe', 9.75),
        ('rpe', -1),
        ('rir', -1),
        ('rir', 6),
        ('rir', 2.5),
        ('rir', 0.5),
        ('rir', 7.5),
        ('borg', 5),
        ('RPE', 8),
        ('Rir', 2),
        ('', 2),
        ('rpe', null),
        ('rir', null),
        (null, 5),
        (null, 0),
        // Non-numeric values: text and blob are never numbers.
        ('rpe', 'abc'),
        ('rir', 'three'),
        ('rpe', ''),
        ('rpe', [8]),
        ('rpe', double.infinity),
      ]) {
        expect(set(scale, value), isFalse, reason: '$scale $value');
      }
    });

    test('the v7 clause exertion_value BETWEEN 0 AND 10 is gone', () {
      final create =
          v8.raw
                  .select(
                    "SELECT sql FROM sqlite_master WHERE name = 'session_sets'",
                  )
                  .first['sql']!
              as String;
      expect(
        create,
        isNot(contains('exertion_value IS NULL OR exertion_value BETWEEN')),
      );
      expect(create, contains("exertion_scale = 'rir'"));
    });
  });

  group('exercises', () {
    bool exercise(Map<String, Object?> extra) {
      final (sql, args) = exerciseInsert('e', extra);
      return v8.accepts(sql, args);
    }

    test('source is required and one of system, user, imported', () {
      for (final s in ExerciseSource.values) {
        expect(
          exercise({
            'source': s.name,
            if (s == ExerciseSource.system) ...{
              'provider_id': 'repforge',
              'revision': 1,
            },
          }),
          isTrue,
          reason: s.name,
        );
      }
      for (final s in [null, '', 'System', 'USER', 'legacy', 'supplied']) {
        expect(exercise({'source': s}), isFalse, reason: '$s');
      }
    });

    test('source has no default (owner R-15)', () {
      expect(
        v8.accepts(
          'INSERT INTO exercises (id, created_at, updated_at, name, type, '
          "category) VALUES ('e', ?, ?, 'n', 'weighted', 'push')",
          [stamp, stamp],
        ),
        isFalse,
      );
    });

    test('revision is NULL or at least 1', () {
      expect(exercise({'revision': null}), isTrue);
      expect(exercise({'revision': 1}), isTrue);
      expect(exercise({'revision': 7}), isTrue);
      expect(exercise({'revision': 0}), isFalse);
      expect(exercise({'revision': -1}), isFalse);
    });

    test('mechanics, laterality, difficulty: the owner lists or NULL', () {
      final lists = <String, List<String>>{
        'mechanics': [for (final v in Mechanics.values) v.name],
        'laterality': [for (final v in Laterality.values) v.name],
        'difficulty': [for (final v in Difficulty.values) v.name],
      };
      for (final MapEntry(key: column, value: values) in lists.entries) {
        expect(exercise({column: null}), isTrue, reason: column);
        for (final v in values) {
          expect(exercise({column: v}), isTrue, reason: '$column $v');
          expect(
            exercise({column: v.toUpperCase()}),
            isFalse,
            reason: '$column ${v.toUpperCase()}',
          );
        }
        for (final bad in ['', ' ', 'none', 'notApplicable', 'other']) {
          expect(exercise({column: bad}), isFalse, reason: '$column "$bad"');
        }
      }
    });

    group('the seven attributes (ADR-0008 clarification A)', () {
      String column(ExerciseAttribute a) => a.name.replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '_${m.group(0)!.toLowerCase()}',
      );

      test('every approved value is accepted, NULL is accepted', () {
        for (final a in ExerciseAttribute.values) {
          expect(exercise({column(a): null}), isTrue, reason: a.name);
          for (final v in AttributeVocabulary.values[a]!) {
            expect(
              exercise({column(a): v.value}),
              isTrue,
              reason: '${a.name} ${v.value}',
            );
          }
        }
      });

      test("'' , case variants, padded and foreign values are refused", () {
        for (final a in ExerciseAttribute.values) {
          final own = {for (final v in AttributeVocabulary.values[a]!) v.value};
          final foreign = {
            for (final other in ExerciseAttribute.values)
              for (final v in AttributeVocabulary.values[other]!)
                if (!own.contains(v.value)) v.value,
          };
          for (final bad in [
            '',
            ' ',
            for (final v in own) ...[
              v.toUpperCase(),
              '${v[0].toUpperCase()}${v.substring(1)}',
              ' $v',
              '$v ',
            ],
            ...foreign,
            'notApplicable',
            'none',
          ]) {
            if (own.contains(bad)) continue;
            expect(
              exercise({column(a): bad}),
              isFalse,
              reason: '${a.name} "$bad"',
            );
          }
        }
      });

      test('each stored CHECK is the ADR-0008 section A text', () {
        final adr = File(
          '../docs/adr/ADR-0008-exercise-library-domain-model.md',
        ).readAsStringSync();
        final adrChecks = {
          for (final m in RegExp(
            r'`([a-z_]+) TEXT (CHECK \([^`]*\))`',
          ).allMatches(adr))
            m.group(1)!: m.group(2)!,
        };
        expect(adrChecks.keys.toSet(), {
          for (final a in ExerciseAttribute.values) column(a),
        });
        final create = collapseSql(
          v8.raw
                  .select(
                    "SELECT sql FROM sqlite_master WHERE name = 'exercises'",
                  )
                  .first['sql']!
              as String,
        );
        for (final MapEntry(key: col, value: check) in adrChecks.entries) {
          expect(create, contains('$col TEXT $check'), reason: col);
        }
      });

      test('no attribute or classification column has a default', () {
        final info = v8.raw.select('PRAGMA table_info(exercises)');
        for (final name in [
          'mechanics',
          'laterality',
          'difficulty',
          for (final a in ExerciseAttribute.values) column(a),
        ]) {
          final col = info.firstWhere((r) => r['name'] == name);
          expect(col['dflt_value'], isNull, reason: name);
          expect(col['notnull'], 0, reason: name);
        }
      });
    });
  });

  group('exercise_equipment (ADR-0008 clarification B)', () {
    setUp(() => insertExercise(v8, 'e1'));

    bool link(
      String item, {
      int ordinal = 0,
      Object? role,
      Object? note,
      String exercise = 'e1',
    }) => v8.accepts(
      'INSERT INTO exercise_equipment (exercise_id, equipment_id, ordinal, '
      'role_override, override_note) VALUES (?, ?, ?, ?, ?)',
      [exercise, item, ordinal, role, note],
    );

    test('no override, with or without a note (owner R-22)', () {
      expect(link('barbell'), isTrue);
      expect(link('barbell', note: 'A note without an override.'), isTrue);
    });

    test('an override is load or support and needs a note', () {
      expect(link('barbell', role: 'support', note: 'Fixed in a rack.'), true);
      expect(link('bench', role: 'load', note: 'Loaded bench.'), isTrue);
      expect(link('barbell', role: 'support', note: ' x '), isTrue);
      expect(link('barbell', role: 'support'), isFalse);
      expect(link('barbell', role: 'support', note: ''), isFalse);
      for (final ws in [' ', '   ', '\t', '\n', '\r', ' \t\r\n ']) {
        expect(
          link('barbell', role: 'support', note: ws),
          isFalse,
          reason: 'whitespace ${ws.codeUnits}',
        );
      }
      for (final role in [
        'cardio',
        'implement',
        'Load',
        'SUPPORT',
        '',
        'none',
      ]) {
        expect(
          link('barbell', role: role, note: 'n'),
          isFalse,
          reason: role,
        );
      }
    });

    test('the note CHECK strips space, tab, LF and CR only; the domain '
        '(Dart trim) is the authority for other whitespace', () {
      // U+00A0 is whitespace to Dart's trim, not to the CHECK.
      expect(link('barbell', role: 'support', note: ' '), isTrue);
      expect(' '.trim(), isEmpty);
    });

    test('an override on a cardio or implement item is not refused by the '
        'schema; the domain IC-315 check refuses it (owner R-19)', () {
      expect(link('treadmill', role: 'support', note: 'n'), isTrue);
      expect(link('skippingRope', role: 'load', note: 'n', ordinal: 1), true);
    });

    test('keys: one row per item, one per ordinal, known items, ordinal '
        '>= 0', () {
      expect(link('barbell'), isTrue);
      v8.run(
        'INSERT INTO exercise_equipment (exercise_id, equipment_id, ordinal) '
        "VALUES ('e1', 'barbell', 0)",
      );
      expect(link('barbell', ordinal: 1), isFalse, reason: 'listed twice');
      expect(link('bench'), isFalse, reason: 'ordinal 0 taken');
      expect(link('bench', ordinal: 1), isTrue);
      expect(link('hoverboard', ordinal: 2), isFalse, reason: 'unknown item');
      expect(link('bench', ordinal: -1), isFalse);
      expect(link('bench', ordinal: 1, exercise: 'nope'), isFalse);
    });
  });

  group('exercise_targets', () {
    setUp(() => insertExercise(v8, 'e1'));
    bool target(String node, String role, int ordinal) => v8.accepts(
      'INSERT INTO exercise_targets VALUES (?, ?, ?, ?)',
      ['e1', node, role, ordinal],
    );

    test('role, node once, ordinal unique and >= 0, node exists', () {
      expect(target('chest', 'primary', 0), isTrue);
      v8.run(
        "INSERT INTO exercise_targets VALUES ('e1', 'chest', 'primary', 0)",
      );
      expect(target('chest', 'secondary', 1), isFalse, reason: 'node twice');
      expect(target('triceps', 'secondary', 0), isFalse, reason: 'ordinal');
      expect(target('triceps', 'secondary', 1), isTrue);
      expect(target('triceps', 'Secondary', 1), isFalse);
      expect(target('triceps', 'tertiary', 1), isFalse);
      expect(target('triceps', 'secondary', -1), isFalse);
      expect(target('rotatorCuff', 'secondary', 1), isFalse, reason: 'FK');
    });
  });

  group('reference tables', () {
    bool node(String id, Object? parent, int level, {bool non = false}) =>
        v8.accepts(
          'INSERT INTO anatomy_nodes (id, parent_id, level, non_anatomical, '
          "sort_order, provider_id) VALUES (?, ?, ?, ?, 10, 'repforge')",
          [id, parent, level, if (non) 1 else 0],
        );

    test('anatomy: level 1-4, parent exactly below level 1, no self parent, '
        'non-anatomical only at level 1, parent exists', () {
      expect(node('regionNeck', null, 1), isTrue);
      expect(node('pectoralisMajor', 'chest', 3), isTrue);
      expect(node('x', null, 0), isFalse);
      expect(node('x', 'deltoid', 5), isFalse);
      expect(node('x', 'chest', 1), isFalse);
      expect(node('x', null, 2), isFalse);
      expect(node('x', 'x', 2), isFalse);
      expect(node('x', 'chest', 3, non: true), isFalse);
      expect(node('x', null, 1, non: true), isTrue);
      expect(node('x', 'nowhere', 3), isFalse);
    });

    test('equipment default role: load, support, cardio, implement', () {
      bool item(String id, Object? role) => v8.accepts(
        'INSERT INTO equipment_items (id, sort_order, default_role, '
        "provider_id) VALUES (?, 1, ?, 'repforge')",
        [id, role],
      );
      for (final r in EquipmentDefaultRole.values) {
        expect(item('new-${r.name}', r.name), isTrue, reason: r.name);
      }
      for (final r in [null, '', 'Load', 'other', 'bodyweight']) {
        expect(item('bad', r), isFalse, reason: '$r');
      }
    });

    test('exercise_names holds other locales only', () {
      insertExercise(v8, 'e1');
      bool name(String locale) => v8.accepts(
        'INSERT INTO exercise_names (exercise_id, locale, name) '
        "VALUES ('e1', ?, 'n')",
        [locale],
      );
      expect(name('de-DE'), isTrue);
      expect(name('en-GB'), isFalse);
    });
  });
}
