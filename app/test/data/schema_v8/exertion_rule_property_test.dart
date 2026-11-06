import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/v8/exertion_rule_sql.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_rules.dart';

import 'v8_support.dart';

/// WP 8 stage 3b-2: the TRN-020 rule in SQL (the schema v8 CHECK) gives the
/// same verdict as the domain rule `TrainingRules.validExertion` on a value
/// grid and on random values, for both scales. D04 defines no conversion
/// between RPE and RIR; neither rule has one.
void main() {
  late FreshV8 v8;
  setUpAll(() async {
    v8 = await FreshV8.open()
      ..run(
        'INSERT INTO workout_sessions (id, created_at, updated_at, name, '
        "started_at) VALUES ('s1', ?, ?, 'S', ?)",
        [stamp, stamp, stamp],
      );
  });
  tearDownAll(() => v8.close());

  final values = <double>{
    // -2 to 12 in steps of 0.05 (exact k / 20 doubles).
    for (var k = -40; k <= 240; k++) k / 20,
    // Quarters and thirds.
    for (var k = -8; k <= 48; k++) k / 4,
    for (var k = -6; k <= 36; k++) k / 3,
    // Near the boundaries.
    for (final b in [0.0, 1.0, 5.0, 10.0])
      for (final d in [1e-9, 1e-12, 0.0001]) ...[b - d, b + d],
    // Random values (seeded).
    ...() {
      final r = Random(20261106);
      return [for (var i = 0; i < 400; i++) r.nextDouble() * 14 - 2];
    }(),
  };

  bool sqlVerdict(String scale, double value) =>
      v8.raw.select(
        'SELECT ${exertionRuleSql(scale: '?1', value: '?2')} AS ok',
        [scale, value],
      ).first['ok'] ==
      1;

  bool tableVerdict(String scale, double value) => v8.accepts(
    'INSERT INTO session_sets (id, session_id, exercise_id, exercise_order, '
    "set_order, type, exertion_scale, exertion_value) VALUES ('x', 's1', "
    "'e1', 0, 0, 'weighted', ?, ?)",
    [scale, value],
  );

  test('SQL expression and table CHECK equal the domain rule '
      '(${values.length} values, both scales)', () {
    var accepted = 0;
    for (final scale in ExertionScale.values) {
      for (final v in values) {
        final domain = TrainingRules.validExertion(
          Exertion(scale: scale, value: v),
        );
        expect(sqlVerdict(scale.name, v), domain, reason: '${scale.name} $v');
        expect(tableVerdict(scale.name, v), domain, reason: '${scale.name} $v');
        if (domain) accepted++;
      }
    }
    // RPE 1..10 in halves (19) and RIR 0..5 (6) are all on the grid.
    expect(accepted, greaterThanOrEqualTo(25));
  });

  test('every valid value is in the grid exactly as the rule lists it', () {
    for (var k = 2; k <= 20; k++) {
      expect(sqlVerdict('rpe', k / 2), isTrue, reason: 'rpe ${k / 2}');
    }
    for (var k = 0; k <= 5; k++) {
      expect(sqlVerdict('rir', k.toDouble()), isTrue, reason: 'rir $k');
    }
  });

  test('both NULL is accepted; a single NULL never is', () {
    expect(
      v8.raw
          .select('SELECT ${exertionRuleSql(scale: 'NULL', value: 'NULL')}')
          .first
          .values
          .first,
      1,
    );
    for (final (s, v) in [("'rpe'", 'NULL'), ('NULL', '8')]) {
      expect(
        v8.raw
            .select('SELECT ${exertionRuleSql(scale: s, value: v)}')
            .first
            .values
            .first,
        0,
        reason: '$s $v',
      );
    }
  });
}
