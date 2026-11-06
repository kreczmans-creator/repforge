import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/migration_report.dart';

import 'v8_support.dart';

/// WP 8 stage 3b-2: the owner's register decisions of 2026-11-06 (D04 §7,
/// "3b-2 register R-01 to R-11 approved" and "register R-12, R-14, R-15,
/// R-19 to R-24 decided") as schema v8 constraints, and Review A finding M1.
void main() {
  late FreshV8 v8;
  setUp(() async => v8 = await FreshV8.open());
  tearDown(() => v8.close());

  bool exercise(Map<String, Object?> extra) {
    final (sql, args) = exerciseInsert('e', extra);
    return v8.accepts(sql, args);
  }

  test('R-14: a system exercise needs provider and revision; R-12: the '
      'provider must exist', () {
    expect(exercise({'source': 'system'}), isFalse);
    expect(exercise({'source': 'system', 'provider_id': 'repforge'}), isFalse);
    expect(exercise({'source': 'system', 'revision': 1}), isFalse);
    expect(
      exercise({'source': 'system', 'provider_id': 'nobody', 'revision': 1}),
      isFalse,
    );
    expect(
      exercise({'source': 'system', 'provider_id': 'repforge', 'revision': 1}),
      isTrue,
    );
    expect(exercise({'source': 'user'}), isTrue);
    expect(exercise({'source': 'imported'}), isTrue);
    expect(exercise({'source': 'user', 'provider_id': 'nobody'}), isFalse);
  });

  group('R-12 keys', () {
    void seedPatterns() => v8
      ..run(
        'INSERT INTO movement_patterns (id, parent_id, sort_order, '
        "provider_id) VALUES ('lowerBody', NULL, 10, 'repforge')",
      )
      ..run(
        'INSERT INTO movement_patterns (id, parent_id, sort_order, '
        "provider_id) VALUES ('squat', 'lowerBody', 10, 'repforge')",
      )
      ..run(
        'INSERT INTO movement_patterns (id, parent_id, sort_order, '
        "provider_id) VALUES ('unused', 'lowerBody', 20, 'repforge')",
      );

    void seedChildren(String e) {
      v8
        ..run('INSERT INTO exercise_targets VALUES (?, ?, ?, 0)', [
          e,
          'quadriceps',
          'primary',
        ])
        ..run('INSERT INTO exercise_targets VALUES (?, ?, ?, 1)', [
          e,
          'glutes',
          'secondary',
        ])
        ..run("INSERT INTO exercise_patterns VALUES (?, 'squat', 0)", [e])
        ..run(
          'INSERT INTO exercise_equipment (exercise_id, equipment_id, '
          "ordinal) VALUES (?, 'barbell', 0)",
          [e],
        )
        ..run(
          'INSERT INTO exercise_equipment (exercise_id, equipment_id, '
          "ordinal) VALUES (?, 'squatRack', 1)",
          [e],
        )
        ..run(
          'INSERT INTO exercise_names (exercise_id, locale, name) '
          "VALUES (?, 'de-DE', 'Kniebeuge')",
          [e],
        );
      for (final r in ['noPrimaryTarget', 'invalidEquipment']) {
        v8.run(
          'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
          "blocked_at) VALUES (?, ?, '{}', ?)",
          [e, r, stamp],
        );
      }
      v8.run('INSERT INTO exercise_user_state (exercise_id) VALUES (?)', [e]);
    }

    int count(String table, String exercise) =>
        v8.raw
                .select('SELECT count(*) FROM $table WHERE exercise_id = ?', [
                  exercise,
                ])
                .first
                .values
                .first!
            as int;

    const owned = [
      'exercise_targets',
      'exercise_patterns',
      'exercise_equipment',
      'exercise_names',
      'exercise_blocks',
    ];

    test('deleting an exercise with several child records cascades to every '
        'exercise-owned table, and only those', () {
      seedPatterns();
      insertExercise(v8, 'e1');
      insertExercise(v8, 'e2');
      seedChildren('e1');
      seedChildren('e2');
      v8
        ..run(
          'INSERT INTO workout_sessions (id, created_at, updated_at, name, '
          "started_at) VALUES ('s1', ?, ?, 'S', ?)",
          [stamp, stamp, stamp],
        )
        ..run(
          'INSERT INTO session_sets (id, session_id, exercise_id, '
          "exercise_order, set_order, type) VALUES ('set1', 's1', 'e1', 0, 0, "
          "'weighted')",
        );
      for (final t in owned) {
        expect(count(t, 'e1'), greaterThan(0), reason: t);
      }
      v8.run("DELETE FROM exercises WHERE id = 'e1'");
      for (final t in owned) {
        expect(count(t, 'e1'), 0, reason: t);
        expect(count(t, 'e2'), greaterThan(0), reason: t);
      }
      // User state has no key (IC-902 reports the orphan); the database
      // never deletes history.
      expect(count('exercise_user_state', 'e1'), 1);
      expect(count('session_sets', 'e1'), 1);
      expect(v8.raw.select('PRAGMA foreign_key_check'), isEmpty);
    });

    test('a referenced catalogue row cannot be deleted', () {
      seedPatterns();
      insertExercise(
        v8,
        'sys',
        extra: {'source': 'system', 'provider_id': 'repforge', 'revision': 1},
      );
      seedChildren('sys');
      for (final sql in [
        "DELETE FROM equipment_items WHERE id = 'barbell'",
        "DELETE FROM anatomy_nodes WHERE id = 'quadriceps'",
        "DELETE FROM anatomy_nodes WHERE id = 'regionThigh'",
        "DELETE FROM movement_patterns WHERE id = 'squat'",
        "DELETE FROM movement_patterns WHERE id = 'lowerBody'",
        "DELETE FROM content_providers WHERE id = 'repforge'",
      ]) {
        expect(v8.accepts(sql), isFalse, reason: sql);
      }
      // An unreferenced catalogue row is not protected by a key.
      expect(
        v8.accepts("DELETE FROM movement_patterns WHERE id = 'unused'"),
        isTrue,
      );
    });

    test('catalogue keys refuse unknown references; user state has no '
        'key', () {
      seedPatterns();
      insertExercise(v8, 'e1');
      const sql0 =
          'INSERT INTO movement_patterns (id, parent_id, sort_order, '
          "provider_id) VALUES ('x', 'nowhere', 1, 'repforge')";
      const sql1 =
          'INSERT INTO movement_patterns (id, parent_id, sort_order, '
          "provider_id) VALUES ('x', NULL, 1, 'nobody')";
      const sql2 =
          'INSERT INTO anatomy_nodes (id, parent_id, level, non_anatomical, '
          "sort_order, provider_id) VALUES ('x', NULL, 1, 0, 1, 'nobody')";
      const sql3 =
          'INSERT INTO equipment_items (id, sort_order, default_role, '
          "provider_id) VALUES ('x', 1, 'load', 'nobody')";
      const sql4 = "INSERT INTO exercise_patterns VALUES ('e1', 'nowhere', 0)";
      const sql5 =
          "INSERT INTO exercise_patterns VALUES ('missing', 'squat', 0)";
      const sql6 =
          'INSERT INTO exercise_names (exercise_id, locale, name) '
          "VALUES ('missing', 'de-DE', 'n')";
      const refused = [sql0, sql1, sql2, sql3, sql4, sql5, sql6];
      for (final sql in refused) {
        expect(v8.accepts(sql), isFalse, reason: sql);
      }
      expect(
        v8.accepts(
          "INSERT INTO exercise_user_state (exercise_id) VALUES ('missing')",
        ),
        isTrue,
      );
    });
  });

  test('R-10: a release states SHA-256 in lowercase hex; provider key', () {
    final hex = 'ab' * 32;
    bool release(
      String provider,
      Object? algorithm,
      Object? encoding,
      Object? hash,
    ) => v8.accepts(
      'INSERT INTO catalogue_releases (provider_id, "release", applied_at, '
      'applied_at_source, content_hash_algorithm, content_hash_encoding, '
      'content_hash, inserted, updated, retired) VALUES '
      "(?, 1, ?, 'test', ?, ?, ?, 0, 0, 0)",
      [provider, stamp, algorithm, encoding, hash],
    );
    expect(release('repforge', 'sha256', 'hex-lower', hex), isTrue);
    for (final (p, a, e, h) in <(String, Object?, Object?, Object?)>[
      ('nobody', 'sha256', 'hex-lower', hex),
      ('repforge', 'md5', 'hex-lower', hex),
      ('repforge', null, 'hex-lower', hex),
      ('repforge', 'sha256', 'base64', hex),
      ('repforge', 'sha256', null, hex),
      ('repforge', 'sha256', 'hex-lower', hex.toUpperCase()),
      ('repforge', 'sha256', 'hex-lower', 'ab' * 31),
      ('repforge', 'sha256', 'hex-lower', 'sha256:$hex'),
      ('repforge', 'sha256', 'hex-lower', 'g' * 64),
      ('repforge', 'sha256', 'hex-lower', null),
    ]) {
      expect(release(p, a, e, h), isFalse, reason: '$p $a $e $h');
    }
  });

  test('R-30 option b: counts are NULL (unknown) or at least 0; the '
      'applied_at source is stated, never NULL or empty', () {
    final hex = 'cd' * 32;
    var n = 0;
    bool release({
      Object? inserted,
      Object? updated,
      Object? retired,
      Object? source = 'seedExercisesVersion.updated_at',
    }) => v8.accepts(
      'INSERT INTO catalogue_releases (provider_id, "release", applied_at, '
      'applied_at_source, content_hash_algorithm, content_hash_encoding, '
      'content_hash, inserted, updated, retired) VALUES '
      "('repforge', ?, ?, ?, 'sha256', 'hex-lower', ?, ?, ?, ?)",
      [++n, stamp, source, hex, inserted, updated, retired],
    );
    expect(release(), isTrue, reason: 'all three NULL');
    expect(release(inserted: 0, updated: 0, retired: 0), isTrue);
    expect(release(inserted: 89, retired: 2), isTrue);
    expect(release(inserted: -1), isFalse);
    expect(release(updated: -1), isFalse);
    expect(release(retired: -1), isFalse);
    expect(release(source: null), isFalse);
    expect(release(source: ''), isFalse);
    // NULL stays NULL: never read back as 0.
    v8.run(
      'INSERT INTO catalogue_releases (provider_id, "release", applied_at, '
      'applied_at_source, content_hash_algorithm, content_hash_encoding, '
      'content_hash, inserted, updated, retired) VALUES '
      "('repforge', 1, ?, 's', 'sha256', 'hex-lower', ?, NULL, NULL, NULL)",
      [stamp, hex],
    );
    final row = v8.raw
        .select(
          'SELECT inserted, updated, retired FROM catalogue_releases '
          'WHERE "release" = 1',
        )
        .single;
    expect(
      [row['inserted'], row['updated'], row['retired']],
      [null, null, null],
    );
  });

  group('R-01, R-02: exercise_blocks', () {
    setUp(() => insertExercise(v8, 'e1'));
    bool block(String reason, {String exercise = 'e1'}) => v8.accepts(
      'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
      "blocked_at) VALUES (?, ?, '{}', ?)",
      [exercise, reason, stamp],
    );
    bool blocked(String exercise) =>
        v8.raw.select(
          'SELECT EXISTS (SELECT 1 FROM exercise_blocks WHERE '
          'exercise_id = ? AND resolved_at IS NULL) AS b',
          [exercise],
        ).first['b'] ==
        1;

    test('reasons: noPrimaryTarget, unknownEquipment, invalidEquipment and '
        'the three unreadable-data reasons', () {
      for (final r in [
        'noPrimaryTarget',
        'unknownEquipment',
        'invalidEquipment',
        'invalidSecondaryTarget',
        'invalidClassification',
        'invalidAliases',
      ]) {
        expect(block(r), isTrue, reason: r);
      }
      for (final r in [
        '',
        'NoPrimaryTarget',
        'equipment',
        'other',
        'invalidType',
      ]) {
        expect(block(r), isFalse, reason: r);
      }
      // The stored list covers every reason of the domain enum.
      insertExercise(v8, 'e2');
      for (final r in BlockReason.values) {
        expect(block(r.name, exercise: 'e2'), isTrue, reason: r.name);
      }
      expect(block('noPrimaryTarget', exercise: 'missing'), isFalse);
    });

    test('one row per exercise and reason; resolving one reason keeps the '
        'exercise blocked while another is active', () {
      for (final r in ['noPrimaryTarget', 'unknownEquipment']) {
        v8.run(
          'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
          "blocked_at) VALUES ('e1', ?, '{}', ?)",
          [r, stamp],
        );
      }
      expect(block('noPrimaryTarget'), isFalse, reason: 'same reason twice');
      expect(blocked('e1'), isTrue);
      v8.run(
        "UPDATE exercise_blocks SET resolved_at = ? WHERE exercise_id = 'e1' "
        "AND reason = 'noPrimaryTarget'",
        [stamp],
      );
      expect(blocked('e1'), isTrue);
      v8.run(
        "UPDATE exercise_blocks SET resolved_at = ? WHERE exercise_id = 'e1' "
        "AND reason = 'unknownEquipment'",
        [stamp],
      );
      expect(blocked('e1'), isFalse);
      // Resolved rows stay as the record of the correction.
      expect(
        v8.raw
            .select('SELECT count(*) FROM exercise_blocks')
            .first
            .values
            .first,
        2,
      );
    });
  });

  group('migration report', () {
    setUp(
      () => v8.run(
        'INSERT INTO migration_runs (id, trigger_kind, from_version, '
        'to_version, generated_at, app_version, provenance_kind, '
        "provenance_source) VALUES ('r1', 'migration', 7, 8, ?, '1.0.0', "
        "'device', 'install-label')",
        [stamp],
      ),
    );

    bool entry(
      String eventId, {
      String category = 'quarantinedOrUnresolved',
      String disposition = 'quarantined',
      String runId = 'r1',
      Object? position,
      Object? original = '7.3',
      Object? resulting = 'null',
      Object? element,
      Object? blockReason,
    }) => v8.accepts(
      'INSERT INTO migration_report_entries (event_id, run_id, source_table, '
      'record_id, field, position, original_value, resulting_value, '
      'element, disposition, block_reason, rule, reason, category) VALUES '
      "(?, ?, 'session_sets', 'set-1', 'exertion_value', ?, ?, ?, ?, ?, ?, "
      "'TRN-020', 'Outside the rule.', ?)",
      [
        eventId,
        runId,
        position,
        original,
        resulting,
        element,
        disposition,
        blockReason,
        category,
      ],
    );

    test('R-05: the five category codes, and nothing else', () {
      for (final (i, c) in [
        'migrated',
        'preserved',
        'quarantinedOrUnresolved',
        'rejectedOrBlocked',
        'warningForReview',
      ].indexed) {
        expect(entry('ev-$i', category: c), isTrue, reason: c);
      }
      for (final c in ['', 'warning', 'Migrated', 'blocked', 'examined']) {
        expect(entry('ev-x', category: c), isFalse, reason: c);
      }
    });

    test('R-07: the event id is unique (no duplicate on a repeat)', () {
      expect(entry('ev-1'), isTrue);
      v8.run(
        'INSERT INTO migration_report_entries (event_id, run_id, '
        'source_table, record_id, field, original_value, resulting_value, '
        "disposition, rule, reason, category) VALUES ('ev-1', 'r1', 't', 'r', "
        "'f', '\"v\"', 'null', 'none', 'x', 'y', 'migrated')",
      );
      expect(entry('ev-1'), isFalse);
      expect(entry('ev-2'), isTrue);
    });

    test('R-03, C-1: dispositions are the section 4.2 actions, blocked and '
        'corrected', () {
      for (final (i, d) in [
        'quarantined',
        'cleared',
        'retained',
        'mapped',
        'markerAdded',
        'skipped',
        'rejected',
        'blocked',
        'none',
        'corrected',
      ].indexed) {
        expect(
          entry(
            'd-$i',
            disposition: d,
            blockReason: d == 'blocked' ? 'noPrimaryTarget' : null,
          ),
          isTrue,
          reason: d,
        );
      }
      for (final d in ['', 'Skipped', 'deleted']) {
        expect(entry('d-x', disposition: d), isFalse, reason: d);
      }
    });

    test('WS4 contract: block_reason is set exactly for blocked entries, '
        'from the block reasons', () {
      for (final (i, r) in [
        for (final r in BlockReason.values) r.name,
      ].indexed) {
        expect(
          entry('b-$i', disposition: 'blocked', blockReason: r),
          isTrue,
          reason: r,
        );
      }
      expect(entry('b-x', disposition: 'blocked'), isFalse);
      expect(entry('b-y', blockReason: 'noPrimaryTarget'), isFalse);
      for (final r in ['', 'invalidType', 'NoPrimaryTarget']) {
        expect(
          entry('b-z', disposition: 'blocked', blockReason: r),
          isFalse,
          reason: r,
        );
      }
    });

    test('WS4 contract: element is NULL or compact JSON of the offending '
        'array element', () {
      for (final (i, e) in ['"hoverboard"', '7', 'null', '{"a":1}'].indexed) {
        expect(entry('e-$i', position: 2, element: e), isTrue, reason: e);
      }
      expect(entry('e-n'), isTrue);
      for (final e in ['', 'hoverboard', '[']) {
        expect(entry('e-x', element: e), isFalse, reason: e);
      }
    });

    test('R-06: values are JSON text; SQL NULL, the text "null", strings '
        'and numbers stay distinct; never NULL or empty', () {
      // SQL NULL -> null; TEXT 'null' -> "null"; TEXT '' -> ""; REAL 7.3 ->
      // 7.3; TEXT '7.3' -> "7.3"; BLOB -> {"blob": base64}; a JSON array
      // text is a JSON string like any text.
      const encoded = [
        'null',
        '"null"',
        '""',
        '7.3',
        '"7.3"',
        '0',
        '{"blob":"AAE="}',
        r'"[\"chest\",\"fullBody\"]"',
      ];
      expect(encoded.toSet().length, encoded.length);
      for (final (i, v) in encoded.indexed) {
        expect(entry('j-$i', original: v), isTrue, reason: v);
        expect(entry('k-$i', resulting: v), isTrue, reason: v);
      }
      for (final v in [null, '', 'chest', '7,3', '{']) {
        expect(entry('j-x', original: v), isFalse, reason: '$v');
        expect(entry('k-x', resulting: v), isFalse, reason: '$v');
      }
    });

    test('N-M1: an element row keeps the whole stored field in '
        'original_value and the element in element; a JSON null element and '
        'a SQL NULL field never share a column', () {
      // secondary_muscles_json stored as the text ["chest",null]: element 1
      // is a JSON null.
      const wholeField = r'"[\"chest\",null]"';
      v8
        ..run(
          'INSERT INTO migration_report_entries (event_id, run_id, '
          'source_table, record_id, field, position, original_value, '
          'resulting_value, element, disposition, rule, reason, category) '
          "VALUES ('el-1', 'r1', 'exercises', 'e1', 'secondary_muscles_json', "
          "1, ?, 'null', 'null', 'skipped', 'WP8-D3', 'r', 'migrated')",
          [wholeField],
        )
        // A field whose stored value is SQL NULL: no element.
        ..run(
          'INSERT INTO migration_report_entries (event_id, run_id, '
          'source_table, record_id, field, original_value, resulting_value, '
          "disposition, rule, reason, category) VALUES ('nf-1', 'r1', "
          "'session_sets', 's1', 'exertion_value', 'null', 'null', 'cleared', "
          "'TRN-020', 'r', 'quarantinedOrUnresolved')",
        );
      final rows = {
        for (final r in v8.raw.select(
          'SELECT event_id, position, original_value, element '
          "FROM migration_report_entries WHERE event_id IN ('el-1', 'nf-1')",
        ))
          r['event_id']: Map<String, Object?>.of(r),
      };
      expect(rows['el-1'], {
        'event_id': 'el-1',
        'position': 1,
        'original_value': wholeField,
        'element': 'null',
      });
      expect(rows['nf-1'], {
        'event_id': 'nf-1',
        'position': null,
        'original_value': 'null',
        'element': null,
      });
      // The JSON null element is in `element`; the SQL NULL field is in
      // `original_value`: distinct columns, distinct rows.
      expect(rows['el-1']!['original_value'], isNot('null'));
      expect(rows['nf-1']!['element'], isNull);
    });

    test('position for list elements; the run must exist', () {
      expect(entry('p-1', position: 2), isTrue);
      expect(entry('p-2', position: -1), isFalse);
      expect(entry('p-3', runId: 'missing'), isFalse);
    });

    test('runs: trigger list, a migration states from < to; R-08 '
        'provenance is structured', () {
      bool runRow(
        String id,
        String trigger,
        Object? from,
        Object? to, {
        Object? kind = 'device',
        Object? merged,
        Object? source = 'install-label',
        Object? appVersion = '1.0.0',
      }) => v8.accepts(
        'INSERT INTO migration_runs (id, trigger_kind, from_version, '
        'to_version, generated_at, app_version, provenance_kind, '
        'provenance_source, merged_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [id, trigger, from, to, stamp, appVersion, kind, source, merged],
      );
      expect(runRow('a', 'migration', 7, 8), isTrue);
      expect(runRow('b', 'restore', null, null), isTrue);
      expect(runRow('c', 'integrityCheck', null, null), isTrue);
      expect(runRow('d', 'catalogueUpdate', null, null), isTrue);
      expect(runRow('d2', 'userCorrection', null, null), isTrue);
      expect(runRow('d3', 'correction', null, null), isFalse);
      expect(runRow('e', 'migration', null, 8), isFalse);
      expect(runRow('f', 'migration', 8, 8), isFalse);
      expect(runRow('g', 'upgrade', 7, 8), isFalse);
      expect(
        runRow('h', 'migration', 7, 8, kind: 'backup', merged: stamp),
        isTrue,
      );
      expect(runRow('i', 'migration', 7, 8, kind: 'backup'), isFalse);
      expect(runRow('j', 'migration', 7, 8, merged: stamp), isFalse);
      expect(runRow('k', 'migration', 7, 8, kind: 'cloud'), isFalse);
      expect(runRow('l', 'migration', 7, 8, kind: null), isFalse);
      // N-L1: source and app version are always stated.
      expect(runRow('m', 'migration', 7, 8, source: null), isFalse);
      expect(runRow('n', 'migration', 7, 8, appVersion: null), isFalse);
      expect(
        runRow(
          'o',
          'restore',
          null,
          null,
          kind: 'backup',
          merged: stamp,
          source: 'repforge-backup-2026-11-06.json',
        ),
        isTrue,
      );
    });

    test('R-04 and M1: counts by category and by disposition, never '
        'negative', () {
      bool count(String dimension, String code, int n) => v8.accepts(
        'INSERT INTO migration_report_counts VALUES '
        "('r1', 'exercises', ?, ?, ?)",
        [dimension, code, n],
      );
      for (final c in [
        'examined',
        'migrated',
        'preserved',
        'quarantinedOrUnresolved',
        'rejectedOrBlocked',
        'warningForReview',
      ]) {
        expect(count('category', c, 3), isTrue, reason: c);
        expect(count('disposition', c, 3), isFalse, reason: c);
      }
      for (final d in [
        'quarantined',
        'cleared',
        'retained',
        'mapped',
        'markerAdded',
        'skipped',
        'rejected',
        'blocked',
        'none',
        'corrected',
      ]) {
        expect(count('disposition', d, 1), isTrue, reason: d);
        expect(count('category', d, 1), isFalse, reason: d);
      }
      expect(count('category', 'examined', -1), isFalse);
      expect(count('outcome', 'examined', 1), isFalse);
    });

    test('R-04: the reconciliation the writer must satisfy reads from the '
        'stored rows (four outcomes = examined; warnings apart; disposition '
        'counts = entries)', () {
      for (final (code, n) in [
        ('examined', 10),
        ('migrated', 6),
        ('preserved', 1),
        ('quarantinedOrUnresolved', 2),
        ('rejectedOrBlocked', 1),
        ('warningForReview', 3),
      ]) {
        v8.run(
          'INSERT INTO migration_report_counts VALUES '
          "('r1', 'exercises', 'category', ?, ?)",
          [code, n],
        );
      }
      v8
        ..run(
          'INSERT INTO migration_report_counts VALUES '
          "('r1', 'session_sets', 'disposition', 'quarantined', 2)",
        )
        ..run(
          'INSERT INTO migration_report_entries (event_id, run_id, '
          'source_table, record_id, field, original_value, resulting_value, '
          "disposition, rule, reason, category) VALUES ('q-1', 'r1', "
          "'session_sets', 's1', 'exertion_value', '7.3', 'null', "
          "'quarantined', 'TRN-020', 'r', 'quarantinedOrUnresolved'), "
          "('q-2', 'r1', 'session_sets', 's2', 'exertion_value', '9.75', "
          "'null', 'quarantined', 'TRN-020', 'r', 'quarantinedOrUnresolved')",
        );
      final row = v8.raw
          .select(
            'SELECT '
            "sum(CASE WHEN code = 'examined' THEN record_count END) "
            'AS examined, '
            "sum(CASE WHEN code IN ('migrated', 'preserved', "
            "'quarantinedOrUnresolved','rejectedOrBlocked') "
            'THEN record_count END) '
            'AS outcomes FROM migration_report_counts '
            "WHERE run_id = 'r1' AND source_table = 'exercises' "
            "AND dimension = 'category'",
          )
          .first;
      expect(row['outcomes'], row['examined']);
      final breakdown = v8.raw
          .select(
            'SELECT c.record_count AS counted, (SELECT count(*) FROM '
            'migration_report_entries e WHERE e.run_id = c.run_id AND '
            'e.source_table = c.source_table AND e.disposition = c.code) '
            'AS listed '
            "FROM migration_report_counts c WHERE c.dimension = 'disposition'",
          )
          .first;
      expect(breakdown['counted'], breakdown['listed']);
    });
  });
}
