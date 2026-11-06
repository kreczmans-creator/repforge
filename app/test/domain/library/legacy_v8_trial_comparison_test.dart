import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/legacy_v8_mapping.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/library/preserved_ids.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../migration_trial/trial_db.dart' show exertionRuleSql;
import '../../migration_trial/trial_fixture.dart';

/// WS4 against the 3b trial fixture (seed 20261106: 5,000 exercises,
/// 100,000 sets; `test/migration_trial/trial_fixture.dart`, read only). The
/// expectations come from the trial's own SQL, which is independent of the
/// WS4 mapping (review WS4 probes).
void main() {
  late Directory dir;
  late Database db;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('ws4trial');
    final path = '${dir.path}/v7.sqlite';
    await buildV7Fixture(path);
    db = sqlite3.open(path)
      ..execute('CREATE TEMP TABLE anatomy_nodes (id TEXT PRIMARY KEY)');
    for (final m in muscleIds) {
      db.execute('INSERT INTO anatomy_nodes VALUES (?)', [m]);
    }
  });

  tearDownAll(() {
    db.close();
    dir.deleteSync(recursive: true);
  });

  int count(String sql) => db.select(sql).first['c']! as int;

  List<LegacyExerciseMapping> mapAll() => [
    for (final r in db.select(
      'SELECT id, primary_muscle, secondary_muscles_json, equipment_json, '
      'supplied FROM exercises ORDER BY id',
    ))
      mapLegacyExercise(
        LegacyExerciseRow(
          id: r['id'] as String,
          primaryMuscle: r['primary_muscle'],
          secondaryMusclesJson: r['secondary_muscles_json'],
          equipmentJson: r['equipment_json'],
          supplied: r['supplied'],
        ),
      ),
  ];

  test('targets equal the trial backfill for every exercise; ordinals are '
      'contiguous (R-11)', () {
    final trial = <String, List<String>>{};
    for (final row in db.select('''
SELECT id AS e, primary_muscle AS n, 'primary' AS r, 0 AS o FROM exercises
WHERE primary_muscle IN (SELECT id FROM anatomy_nodes)
UNION ALL
SELECT e.id, j.value, 'secondary', MIN(j.key) + 1
FROM exercises e, json_each(e.secondary_muscles_json) j
WHERE j.value IN (SELECT id FROM anatomy_nodes)
  AND j.value <> e.primary_muscle
GROUP BY e.id, j.value
ORDER BY 1, 4''')) {
      trial
          .putIfAbsent(row['e'] as String, () => [])
          .add('${row['n']}:${row['r']}');
    }
    final mappings = mapAll();
    expect(mappings, hasLength(5000));
    var compared = 0;
    for (final m in mappings) {
      final ws4 = [for (final t in m.targets) '${t.node.value}:${t.role.name}'];
      expect(ws4, trial[m.id.value] ?? const <String>[], reason: '${m.id}');
      expect(
        [for (final t in m.targets) t.ordinal],
        [for (var i = 0; i < m.targets.length; i++) i],
      );
      compared++;
    }
    expect(compared, 5000);
  });

  test('blocked, quarantined, skipped and warning counts equal the trial '
      'SQL', () {
    final mappings = mapAll();
    final trialNoPrimary = {
      for (final r in db.select(
        'SELECT id FROM exercises WHERE primary_muscle NOT IN '
        '(SELECT id FROM anatomy_nodes)',
      ))
        r['id'] as String,
    };
    expect(trialNoPrimary, hasLength(303));
    final ws4NoPrimary = {
      for (final m in mappings)
        if (m.blocks.any((b) => b.reason == BlockReason.noPrimaryTarget))
          m.id.value,
    };
    expect(ws4NoPrimary, trialNoPrimary);

    int events(bool Function(ReportEvent e) test) =>
        [for (final m in mappings) ...m.events.where(test)].length;

    expect(
      events((e) => e.field == 'secondary_muscles_json' && e.rule == 'IC-301'),
      count(
        'SELECT count(*) c FROM exercises e, '
        'json_each(e.secondary_muscles_json) j '
        'WHERE j.value NOT IN (SELECT id FROM anatomy_nodes)',
      ),
    );
    expect(
      events((e) => e.rule == 'IC-305'),
      count(
        'SELECT count(*) c FROM exercises e, '
        'json_each(e.secondary_muscles_json) j '
        'WHERE j.value = e.primary_muscle',
      ),
    );
    expect(events((e) => e.rule == 'IC-305'), 752);
    // Every stored fullBody secondary is reported exactly once: retained
    // (warning), or skipped because it equals the primary or repeats.
    final trialFullBody = count(
      'SELECT count(*) c FROM exercises e, '
      "json_each(e.secondary_muscles_json) j WHERE j.value = 'fullBody'",
    );
    expect(trialFullBody, 557);
    final retained = events((e) => e.rule == 'ADR-0010');
    final skippedFullBody = events(
      (e) => e.action == ReportAction.skipped && e.element == '"fullBody"',
    );
    expect(retained + skippedFullBody, trialFullBody);
    expect(
      skippedFullBody,
      count(
        'SELECT count(*) c FROM exercises e, '
        'json_each(e.secondary_muscles_json) j '
        "WHERE j.value = 'fullBody' AND e.primary_muscle = 'fullBody'",
      ),
    );
    // The trial fixture lists `bodyweight`, which is not one of the 21
    // equipment ids (v7 hides such exercises): each element is quarantined
    // (IC-307) and each exercise blocked as unknownEquipment.
    final known = existingEquipmentIds.map((e) => "'${e.value}'").join(',');
    expect(
      events((e) => e.action == ReportAction.quarantined && e.rule == 'IC-307'),
      count(
        'SELECT count(*) c FROM exercises e, json_each(e.equipment_json) j '
        'WHERE j.value NOT IN ($known)',
      ),
    );
    final trialUnknownEquipment = {
      for (final r in db.select(
        'SELECT DISTINCT e.id FROM exercises e, json_each(e.equipment_json) j '
        'WHERE j.value NOT IN ($known)',
      ))
        r['id'] as String,
    };
    expect(trialUnknownEquipment, isNotEmpty);
    expect({
      for (final m in mappings)
        if (m.blocks.any((b) => b.reason == BlockReason.unknownEquipment))
          m.id.value,
    }, trialUnknownEquipment);
    expect(
      events(
        (e) =>
            e.field == 'equipment_json' &&
            e.rule != 'IC-307' &&
            e.rule != 'ADR-0008-Q12',
      ),
      0,
      reason: 'no repeated, non-string or non-array equipment in the fixture',
    );
    expect(
      {
        for (final m in mappings)
          if (m.isBlocked) m.id.value,
      },
      {...trialNoPrimary, ...trialUnknownEquipment},
    );
  });

  test('TRN-020: the invalid sets are exactly the trial SQL rule', () {
    final bad = '(${exertionRuleSql()}) = 0';
    final trialBad = {
      for (final r in db.select('SELECT id FROM session_sets WHERE $bad'))
        r['id'] as String,
    };
    expect(trialBad, hasLength(2088));
    final ws4Bad = <String>{};
    for (final r in db.select(
      'SELECT id, exertion_scale s, exertion_value v FROM session_sets',
    )) {
      final c = classifyLegacyExertion(
        setId: r['id'] as String,
        scale: r['s'],
        value: r['v'],
      );
      if (!c.isValid) ws4Bad.add(r['id'] as String);
    }
    expect(ws4Bad, trialBad);
  });

  test('the full report reconciles against independent counts and the '
      'mapping quarantine and block lists (section 4.4)', () {
    final b = MigrationReportBuilder(
      ReportRun(
        runId: 'trial-run',
        trigger: ReportTrigger.migration,
        generatedAt: DateTime.utc(2026, 11, 6),
        appVersion: 'test',
        fromSchemaVersion: 7,
        toSchemaVersion: 8,
      ),
    );
    final blocked = <String>{};
    final quarantined = <String>{};
    final warned = <String>{};
    for (final m in mapAll()) {
      b.examine(
        table: 'exercises',
        recordId: m.id.value,
        cleanOutcome: ReportCategory.migrated,
        events: m.events,
      );
      if (m.blocks.isNotEmpty) {
        blocked.add(m.id.value);
      } else if (m.quarantine.isNotEmpty) {
        quarantined.add(m.id.value);
      }
      if (m.targets.any((t) => !t.isPrimary && t.node.value == 'fullBody')) {
        warned.add(m.id.value);
      }
    }
    final badSets = <String>{};
    for (final r in db.select(
      'SELECT id, exertion_scale s, exertion_value v FROM session_sets',
    )) {
      final id = r['id'] as String;
      final c = classifyLegacyExertion(setId: id, scale: r['s'], value: r['v']);
      if (c.quarantine != null) badSets.add(id);
      b.examine(
        table: 'session_sets',
        recordId: id,
        cleanOutcome: ReportCategory.preserved,
        events: c.events,
      );
    }
    final report = b.build();
    final result = reconcileReport(
      report,
      examinedByTable: {
        'exercises': count('SELECT count(*) c FROM exercises'),
        'session_sets': count('SELECT count(*) c FROM session_sets'),
      },
      affectedByTable: {
        'exercises': {
          ReportCategory.rejectedOrBlocked: blocked,
          ReportCategory.quarantinedOrUnresolved: quarantined,
          ReportCategory.warningForReview: warned,
        },
        'session_sets': {
          ReportCategory.quarantinedOrUnresolved: badSets,
          ReportCategory.rejectedOrBlocked: const {},
          ReportCategory.warningForReview: const {},
        },
      },
    );
    expect(result.problems, isEmpty);
    expect(report.counts['exercises']!.blocked, blocked.length);
    expect(blocked.length, greaterThanOrEqualTo(303));
    expect(report.counts['session_sets']!.quarantinedOrUnresolved, 2088);
  });
}
