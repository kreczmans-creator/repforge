import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/library_enums.dart';

import 'v8_support.dart';

/// WP 8 stage 3b-2, ADR-0008 section E, implementation clarification 1 and
/// owner decision Q5: NULL means "no recorded or applicable value". One
/// database state covers both "not recorded" and "not applicable"; nothing
/// may read NULL as evidence that an attribute does not apply, and nothing
/// infers a value.
void main() {
  late FreshV8 v8;
  setUp(() async => v8 = await FreshV8.open());
  tearDown(() => v8.close());

  String column(ExerciseAttribute a) => a.name.replaceAllMapped(
    RegExp('[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );

  final optionalColumns = [
    'mechanics',
    'laterality',
    'difficulty',
    for (final a in ExerciseAttribute.values) column(a),
  ];

  test('a new exercise that states nothing stores NULL in every attribute '
      'and classification: no default, no inference', () {
    insertExercise(
      v8,
      'e1',
      extra: {'name': 'Incline barbell bench press, wide grip, standing'},
    );
    final row = v8.raw
        .select('SELECT ${optionalColumns.join(', ')} FROM exercises')
        .first;
    for (final c in optionalColumns) {
      expect(row[c], isNull, reason: c);
    }
  });

  test('the schema has no "not applicable" value: no list holds one and '
      'every such spelling is refused', () {
    const naSpellings = [
      'notApplicable',
      'not applicable',
      'n/a',
      'N/A',
      'na',
      'none',
      'null',
      'NULL',
      '',
    ];
    for (final a in ExerciseAttribute.values) {
      final values = {for (final v in AttributeVocabulary.values[a]!) v.value};
      expect(values.intersection(naSpellings.toSet()), isEmpty);
    }
    for (final c in optionalColumns) {
      for (final na in naSpellings) {
        final (sql, args) = exerciseInsert('e-$c', {c: na});
        expect(v8.accepts(sql, args), isFalse, reason: '$c "$na"');
      }
    }
  });

  test('no column, trigger, view or generated column derives a value from '
      'NULL', () {
    expect(
      v8.raw.select(
        "SELECT name FROM sqlite_master WHERE type IN ('trigger', 'view')",
      ),
      isEmpty,
    );
    final info = v8.raw.select('PRAGMA table_xinfo(exercises)');
    // hidden = 0: ordinary column; 2 or 3 would be a generated column.
    expect(info.every((r) => r['hidden'] == 0), isTrue);
    final names = {for (final r in info) r['name']};
    for (final n in names) {
      expect(
        (n! as String).toLowerCase(),
        isNot(anyOf(contains('applicable'), contains('recorded'))),
      );
    }
  });

  test('"not recorded" and "not applicable" are the same state: two '
      'exercises with no value cannot be told apart by the attribute', () {
    insertExercise(v8, 'cardio', extra: {'category': 'cardio'});
    insertExercise(v8, 'press', extra: {'category': 'push'});
    final rows = v8.raw.select(
      'SELECT ${optionalColumns.join(', ')} FROM exercises ORDER BY id',
    );
    expect(Map<String, Object?>.of(rows[0]), Map<String, Object?>.of(rows[1]));
    // A query for "applies but unrecorded" has nothing to select on.
    expect(
      v8.raw
          .select('SELECT count(*) FROM exercises WHERE angle IS NULL')
          .first
          .values
          .first,
      2,
    );
  });

  test('the domain enums of the closed classifications carry no "not '
      'applicable" member either', () {
    for (final values in [
      Mechanics.values,
      Laterality.values,
      Difficulty.values,
    ]) {
      expect(
        values.map((v) => v.name.toLowerCase()),
        isNot(anyOf(contains('notapplicable'), contains('none'))),
      );
    }
  });
}
