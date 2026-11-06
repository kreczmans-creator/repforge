import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/repositories/v8/drift_library_repository_v8.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/migration_report.dart';

import '../../../migration_v8/v8_migration_support.dart'
    show appVersion, installLabel;
import 'v8_library_support.dart';

/// WP 8 sub-stage 3b-8: the report reads over a database migrated by the
/// real 3b-4 step (`quality-and-duplicates.md` section 4; D04 §7,
/// 2026-11-06, "Report detail" and "3b check scope"; R-01, R-04, R-08).
void main() {
  late V8LibraryHarness h;

  setUp(() async => h = await V8LibraryHarness.open());
  tearDown(() => h.close());
  tearDownAll(V8LibraryFixture.dispose);

  const migrationRun = 'run-1';
  const integrityRun = 'run-1:integrity';

  Future<int> scalar(String sql, [List<Object> args = const []]) async =>
      (await h.db
              .customSelect(sql, variables: [for (final a in args) Variable(a)])
              .getSingle())
          .read<int>('n');

  group('runs and totals', () {
    test('runs carry trigger, versions and structured provenance', () async {
      final runs = await h.report.runs();
      expect(runs.map((r) => r.id), containsAll([migrationRun, integrityRun]));
      final m = (await h.report.run(migrationRun))!;
      expect(m.trigger, 'migration');
      expect((m.fromVersion, m.toVersion), (7, 8));
      expect(m.provenanceKind, 'device');
      expect(m.provenanceSource, installLabel);
      expect(m.appVersion, appVersion);
      expect(m.mergedAt, isNull);
      expect((await h.report.run(integrityRun))!.trigger, 'integrityCheck');
      expect(await h.report.run('no-such'), isNull);
    });

    test('totals equal the stored counts; the four outcomes sum to the '
        'records examined (R-04)', () async {
      for (final run in [migrationRun, integrityRun]) {
        final totals = await h.report.totals(run);
        expect(totals.tables, isNotEmpty);
        for (final t in totals.tables.values) {
          expect(t.outcomeTotal, t.category('examined'), reason: t.table);
          for (final MapEntry(key: code, value: n) in t.categories.entries) {
            expect(
              await scalar(
                'SELECT record_count AS n FROM migration_report_counts '
                'WHERE run_id = ? AND source_table = ? AND dimension = '
                "'category' AND code = ?",
                [run, t.table, code],
              ),
              n,
            );
          }
          // Each disposition count equals the stored entries with it.
          for (final a in ReportAction.values) {
            expect(
              t.disposition(a.name),
              await scalar(
                'SELECT COUNT(*) AS n FROM migration_report_entries '
                'WHERE run_id = ? AND source_table = ? AND disposition = ?',
                [run, t.table, a.name],
              ),
              reason: '${t.table} ${a.name}',
            );
          }
        }
        final entries = await scalar(
          'SELECT COUNT(*) AS n FROM migration_report_entries '
          'WHERE run_id = ?',
          [run],
        );
        expect(totals.entries, entries);
        expect(
          totals.entriesByDisposition.values.fold(0, (a, b) => a + b),
          entries,
        );
        expect(
          totals.entriesByCategory.values.fold(0, (a, b) => a + b),
          entries,
        );
        expect(totals.entriesByRule.values.fold(0, (a, b) => a + b), entries);
      }
      // The examined counts equal the input, counted independently.
      final m = await h.report.totals(migrationRun);
      expect(
        m.tables['exercises']!.category('examined'),
        await scalar('SELECT COUNT(*) AS n FROM exercises'),
      );
      expect(
        m.tables['session_sets']!.category('examined'),
        await scalar('SELECT COUNT(*) AS n FROM session_sets'),
      );
      expect(
        m.tables['exercises']!.disposition('blocked'),
        await scalar('SELECT COUNT(*) AS n FROM exercise_blocks'),
      );
    });

    test('totals reconcile with the stored report (reconcileReport)', () async {
      final examined = {
        'exercises': await scalar('SELECT COUNT(*) AS n FROM exercises'),
        'session_sets': await scalar('SELECT COUNT(*) AS n FROM session_sets'),
      };
      final report = await h.report.storedReport(migrationRun);
      final result = reconcileReport(
        report,
        examinedByTable:
            {
              for (final t in report.counts.keys)
                if (examined.containsKey(t)) t: examined[t]!,
            }..addAll({
              for (final t in report.counts.keys)
                if (!examined.containsKey(t)) t: report.counts[t]!.examined,
            }),
      );
      expect(result.reconciles, isTrue, reason: '$result');
      expect(
        report.counts['exercises']!.blocked,
        V8LibraryFixture.blocked.length,
      );
      expect(
        reconcileReport(await h.report.storedReport(integrityRun)).reconciles,
        isTrue,
      );
    });

    test('a tampered stored count no longer reconciles', () async {
      await h.db.customStatement(
        'UPDATE migration_report_counts SET record_count = record_count + 1 '
        "WHERE run_id = ? AND source_table = 'exercises' AND "
        "dimension = 'disposition' AND code = 'blocked'",
        [migrationRun],
      );
      final result = reconcileReport(await h.report.storedReport(migrationRun));
      expect(result.reconciles, isFalse);
      await h.db.customStatement(
        'UPDATE migration_report_counts SET record_count = record_count - 1 '
        "WHERE run_id = ? AND source_table = 'exercises' AND "
        "dimension = 'disposition' AND code = 'blocked'",
        [migrationRun],
      );
      await h.db.customStatement(
        'UPDATE migration_report_counts SET record_count = record_count + 1 '
        "WHERE run_id = ? AND source_table = 'exercises' AND "
        "dimension = 'category' AND code = 'migrated'",
        [migrationRun],
      );
      expect(
        reconcileReport(await h.report.storedReport(migrationRun)).reconciles,
        isFalse,
      );
    });

    test('a correction run reconciles and leaves the migration run '
        'unchanged', () async {
      final before = await h.report.storedReport(migrationRun);
      final beforeRows = await h.rowsOf(
        'migration_report_entries',
        orderBy: 'event_id',
      );
      final outcome = await h.library.correctBlockedReason(
        'ex-empty',
        BlockReason.noPrimaryTarget,
        const SetTargetsCorrection([
          (node: AnatomyNodeId('abs'), role: TargetRole.primary),
        ]),
      );
      final runId = (outcome as Ok<BlockCorrectionOutcome>).value.runId;
      final correction = await h.report.storedReport(runId);
      expect(reconcileReport(correction).reconciles, isTrue);
      expect(correction.entries.single.event.recordId, 'ex-empty');
      final after = await h.report.storedReport(migrationRun);
      expect(after.entries, before.entries);
      expect(
        (await h.rowsOf(
          'migration_report_entries',
          orderBy: 'event_id',
        )).where(beforeRows.contains).length,
        beforeRows.length,
      );
    });
  });

  group('entries', () {
    test('paging returns every entry once, in a stable order', () async {
      final all = await h.report.entries(limit: 10000);
      expect(
        all.total,
        await scalar('SELECT COUNT(*) AS n FROM migration_report_entries'),
      );
      expect(all.entries, hasLength(all.total));
      expect(all.hasMore, isFalse);
      final paged = <String>[];
      var offset = 0;
      while (true) {
        final page = await h.report.entries(limit: 7, offset: offset);
        expect(page.total, all.total);
        paged.addAll(page.entries.map((e) => e.eventId));
        if (!page.hasMore) break;
        offset += page.entries.length;
      }
      expect(paged, all.entries.map((e) => e.eventId).toList());
      expect(paged.toSet(), hasLength(paged.length));
      expect(() => h.report.entries(limit: 0), throwsArgumentError);
    });

    test('filters by run and by exercise', () async {
      final rotator = await h.report.entries(exerciseId: 'ex-rotator');
      expect(rotator.entries, isNotEmpty);
      expect(
        rotator.entries.every((e) => e.exerciseId == 'ex-rotator'),
        isTrue,
      );
      expect(
        [
          for (final e in rotator.entries)
            if (e.disposition == 'blocked') e.blockReason,
        ]..sort(),
        ['noPrimaryTarget', 'unknownEquipment'],
      );
      final run = await h.report.entries(runId: integrityRun, limit: 1000);
      expect(run.entries.every((e) => e.runId == integrityRun), isTrue);
    });
  });

  group('blocked exercises', () {
    test('every blocked exercise is listed with its stable id, name, each '
        'reason and its original value', () async {
      final list = await h.report.blockedExercises();
      expect([
        for (final b in list) b.exerciseId,
      ], [...V8LibraryFixture.blocked.keys]..sort());
      for (final b in list) {
        expect(b.name, isNotNull);
        expect({
          for (final r in b.activeReasons) r.name,
        }, V8LibraryFixture.blocked[b.exerciseId]);
        for (final x in b.blocks) {
          expect(x.originalJson, isNotEmpty);
          if (x.block.reason == BlockReason.noPrimaryTarget) {
            expect(x.originalJson, contains('primary_muscle'));
          } else {
            expect(x.originalJson, contains('equipment_json'));
          }
        }
      }
      final rotator = list.firstWhere((b) => b.exerciseId == 'ex-rotator');
      expect(rotator.name, 'External rotation');
      expect(
        rotator.blocks
            .firstWhere((x) => x.block.reason == BlockReason.noPrimaryTarget)
            .originalJson,
        contains('rotator cuff'),
      );
    });

    test('a partly corrected exercise stays listed; a fully corrected one '
        'is listed only with its resolved rows on request', () async {
      await h.library.correctBlockedReason(
        'ex-rotator',
        BlockReason.unknownEquipment,
        const SetEquipmentCorrection([
          ExerciseEquipment(EquipmentItemId('dumbbell')),
        ]),
      );
      var list = await h.report.blockedExercises();
      final rotator = list.firstWhere((b) => b.exerciseId == 'ex-rotator');
      expect(rotator.activeReasons, {BlockReason.noPrimaryTarget});
      expect(rotator.blocks, hasLength(2));
      await h.library.correctBlockedReason(
        'ex-rotator',
        BlockReason.noPrimaryTarget,
        const SetTargetsCorrection([
          (node: AnatomyNodeId('shoulders'), role: TargetRole.primary),
        ]),
      );
      list = await h.report.blockedExercises();
      expect(list.map((b) => b.exerciseId), isNot(contains('ex-rotator')));
      final all = await h.report.blockedExercises(includeResolved: true);
      final resolved = all.firstWhere((b) => b.exerciseId == 'ex-rotator');
      expect(resolved.isBlocked, isFalse);
      expect(resolved.blocks.every((x) => !x.block.isActive), isTrue);
    });
  });

  group('acknowledgement never deletes', () {
    test('acknowledging sets only acknowledged_at, once', () async {
      final quarantined = (await h.report.entries(limit: 1000)).entries
          .firstWhere((e) => e.quarantineId != null);
      final before = await h.dump();
      expect(
        await h.report.acknowledge(
          quarantined.eventId,
          at: V8LibraryFixture.now,
        ),
        isTrue,
      );
      expect(await h.report.acknowledge(quarantined.eventId), isFalse);
      expect(await h.report.acknowledge('no-such'), isFalse);
      final after = await h.dump();
      for (final table in after.keys) {
        if (table == 'migration_report_entries') continue;
        expect(after[table], before[table], reason: table);
      }
      expect(
        after['migration_report_entries'],
        hasLength(before['migration_report_entries']!.length),
      );
      final changed = after['migration_report_entries']!
          .where((r) => !before['migration_report_entries']!.contains(r))
          .toList();
      expect(changed.single, contains(quarantined.eventId));
      expect(
        changed.single,
        contains(
          '"acknowledged_at":"text:'
          '${V8LibraryFixture.now.toIso8601String()}"',
        ),
      );
      // The quarantined original is still there.
      expect(
        await scalar(
          'SELECT COUNT(*) AS n FROM legacy_quarantine WHERE id = ?',
          [quarantined.quarantineId!],
        ),
        1,
      );
      final totals = await h.report.totals(quarantined.runId);
      expect(totals.acknowledged, 1);
      final open = await h.report.entries(
        runId: quarantined.runId,
        includeAcknowledged: false,
        limit: 1000,
      );
      expect(open.total, totals.entries - 1);
      expect(
        open.entries.map((e) => e.eventId),
        isNot(contains(quarantined.eventId)),
      );
    });
  });
}
