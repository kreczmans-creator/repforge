@Tags(['heavy'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/data/repositories/v8/drift_library_repository_v8.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/legacy_v8_mapping.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:sqlite3/sqlite3.dart';

import '../migration_trial/trial_fixture.dart' show buildV7Fixture;
import 'harness_v7_db.dart' show strictSchema;
import 'migration_digest.dart' as digest;
import 'v8_migration_support.dart';

/// WP 8 sub-stage 3b-4, large profile (tag `heavy`, skipped by default):
/// the deterministic 3b trial fixture (5,000 exercises, 100,000 sets, seed
/// 20261106; `test/migration_trial/trial_fixture.dart`, used read-only)
/// migrated v7 → v8 by `AppDatabaseV8`.
///
/// Run: `flutter test --concurrency=1 --run-skipped --tags heavy
/// test/migration_v8/v8_large_profile_test.dart`. Host timing only; it is
/// not device evidence (3b-9).
void main() {
  test('large profile: v7 → v8 completes, values and findings equal, '
      'report reconciles, schema equals a fresh v8', () async {
    await inTempDir((dir) async {
      final v7 = File('${dir.path}/large_v7.sqlite');
      await buildV7Fixture(v7.path);
      // The unreadable-data reasons (owner decision 2026-11-06): the trial
      // fixture already holds unreadable secondaries ("traps"); unreadable
      // type, category, aliases and equipment are added to this temporary
      // copy (the trial generator is used read-only), so every block reason
      // occurs.
      final damage = sqlite3.open(v7.path);
      try {
        damage
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
          // And unreadable equipment, which the trial fixture lacks.
          ..execute(
            "UPDATE exercises SET equipment_json = 'barbell, bench' "
            'WHERE rowid % 431 = 4',
          );
      } finally {
        damage.close();
      }
      final f = v7.copySync('${dir.path}/large.sqlite');

      // Independent expectations from the v7 file.
      final before = sqlite3.open(v7.path, mode: OpenMode.readOnly);
      final int exercises;
      final int sets;
      final int legacy;
      var blocked = 0;
      final byReason = <String, int>{};
      final blockedIds = <String>{};
      var cleared = 0;
      var newQuarantine = 0;
      final Map<String, Object?> digestsBefore;
      final Set<String> findingsBefore;
      try {
        exercises =
            before.select('SELECT count(*) c FROM exercises').single['c']!
                as int;
        sets =
            before.select('SELECT count(*) c FROM session_sets').single['c']!
                as int;
        legacy =
            before
                    .select('SELECT count(*) c FROM legacy_quarantine')
                    .single['c']!
                as int;
        for (final r in before.select(
          'SELECT id, type, category, aliases_json, primary_muscle, '
          'secondary_muscles_json, equipment_json, supplied FROM exercises',
        )) {
          final m = mapLegacyExercise(
            LegacyExerciseRow(
              id: r['id']! as String,
              type: r['type'],
              category: r['category'],
              aliasesJson: r['aliases_json'],
              primaryMuscle: r['primary_muscle'],
              secondaryMusclesJson: r['secondary_muscles_json'],
              equipmentJson: r['equipment_json'],
              supplied: r['supplied'],
            ),
          );
          if (m.isBlocked) {
            blocked++;
            blockedIds.add(m.id.value);
          }
          for (final b in m.blocks) {
            byReason.update(b.reason.name, (n) => n + 1, ifAbsent: () => 1);
          }
          newQuarantine += m.quarantine.length;
        }
        for (final r in before.select(
          'SELECT id, exertion_scale, exertion_value FROM session_sets',
        )) {
          final c = classifyLegacyExertion(
            setId: r['id']! as String,
            scale: r['exertion_scale'],
            value: r['exertion_value'],
          );
          if (!c.isValid) cleared++;
        }
        newQuarantine += cleared;
        digestsBefore = digest.tableDigests(before);
        findingsBefore = findingsOf(before).keys.toSet();
      } finally {
        before.close();
      }

      final watch = Stopwatch()..start();
      final error = await openV8(f);
      watch.stop();
      expect(error, isNull);
      // Host timing for the record only (not an assertion).
      // ignore: avoid_print
      print(
        'large profile v7 → v8: ${watch.elapsedMilliseconds} ms, '
        '$exercises exercises, $sets sets, ${f.lengthSync()} bytes',
      );

      final raw = sqlite3.open(f.path, mode: OpenMode.readOnly);
      try {
        expect(digest.userVersion(raw), 8);
        expect(digest.integrityCheck(raw), 'ok');
        expect(findingsOf(raw).keys.toSet(), findingsBefore);
        int one(String sql) => raw.select(sql).single.values.first! as int;
        expect(one('SELECT count(*) FROM exercises'), exercises);
        expect(one('SELECT count(*) FROM session_sets'), sets);
        expect(
          one('SELECT count(DISTINCT exercise_id) FROM exercise_blocks'),
          blocked,
        );
        // Every reason occurs and equals the independent mapping count;
        // one blocked entry per block row (R-01).
        expect(byReason.keys.toSet(), {
          for (final r in BlockReason.values) r.name,
        });
        expect({
          for (final r in raw.select(
            'SELECT reason, count(*) AS n FROM exercise_blocks GROUP BY reason',
          ))
            r['reason']! as String: r['n']! as int,
        }, byReason);
        expect(
          one(
            'SELECT count(*) FROM migration_report_entries '
            "WHERE run_id = 'run-1' AND disposition = 'blocked'",
          ),
          one('SELECT count(*) FROM exercise_blocks'),
        );
        expect(
          one('SELECT count(*) FROM legacy_quarantine'),
          legacy + newQuarantine,
        );
        expect(
          one(
            'SELECT count(DISTINCT record_id) FROM migration_report_entries '
            "WHERE source_table = 'session_sets' AND disposition = 'cleared'",
          ),
          cleared,
        );
        // Untouched tables are equal row for row.
        final after = digest.tableDigests(raw);
        for (final t in digestsBefore.keys) {
          if (const {
            'exercises',
            'session_sets',
            'legacy_quarantine',
            'sqlite_sequence',
          }.contains(t)) {
            continue;
          }
          expect(after[t], digestsBefore[t], reason: t);
        }
        // The stored report reconciles.
        final counts = <String, int>{
          for (final r in raw.select('SELECT * FROM migration_report_counts'))
            '${r['run_id']}|${r['source_table']}|${r['dimension']}|'
                    '${r['code']}':
                r['record_count']! as int,
        };
        expect(counts['run-1|exercises|category|examined'], exercises);
        expect(counts['run-1|session_sets|category|examined'], sets);
        final groups = {
          for (final k in counts.keys) k.split('|').take(2).join('|'),
        };
        for (final g in groups) {
          final outcomes = [
            for (final o in ReportCategory.outcomes)
              counts['$g|category|${o.code}']!,
          ].fold(0, (a, b) => a + b);
          expect(outcomes, counts['$g|category|examined'], reason: g);
          final parts = g.split('|');
          for (final a in ReportAction.values) {
            expect(
              one(
                'SELECT count(*) FROM migration_report_entries WHERE '
                "run_id = '${parts[0]}' AND source_table = '${parts[1]}' "
                "AND disposition = '${a.name}'",
              ),
              counts['$g|disposition|${a.name}'],
              reason: '$g ${a.name}',
            );
          }
        }
        // Blocked exercises are never selectable; their history stays
        // readable (sets of the first blocked exercise of each reason).
        final lib = AppDatabaseV8(NativeDatabase(f));
        try {
          final library = DriftLibraryRepositoryV8(
            lib,
            clock: v8Clock,
            newId: () => 'unused',
            appVersion: appVersion,
            installLabel: installLabel,
          );
          final selectable = {
            for (final e in await library.selectable()) e.id.value,
          };
          expect(selectable.intersection(blockedIds), isEmpty);
          expect(selectable, isNotEmpty);
          for (final r in BlockReason.values) {
            final id =
                raw.select(
                      'SELECT exercise_id FROM exercise_blocks b WHERE '
                      'reason = ? AND EXISTS (SELECT 1 FROM session_sets '
                      's WHERE s.exercise_id = b.exercise_id) '
                      'ORDER BY exercise_id LIMIT 1',
                      [r.name],
                    ).single['exercise_id']!
                    as String;
            final history = await library.history(id);
            expect(
              history.fold(0, (n, x) => n + x.sets.length),
              one(
                "SELECT count(*) FROM session_sets WHERE exercise_id = '$id'",
              ),
              reason: '${r.name} $id',
            );
            expect(
              (await library.requireNewWork(id)) is Err,
              isTrue,
              reason: id,
            );
          }
        } finally {
          await lib.close();
        }
        // Structure equals a fresh v8.
        final freshRaw = sqlite3.openInMemory();
        final fresh = AppDatabaseV8(NativeDatabase.opened(freshRaw));
        await fresh.customSelect('SELECT 1').get();
        expect(strictSchema(raw), strictSchema(freshRaw));
        await fresh.close();
      } finally {
        raw.close();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 20)));
}
