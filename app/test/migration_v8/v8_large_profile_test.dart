@Tags(['heavy'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
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
      final f = v7.copySync('${dir.path}/large.sqlite');

      // Independent expectations from the v7 file.
      final before = sqlite3.open(v7.path, mode: OpenMode.readOnly);
      final int exercises;
      final int sets;
      final int legacy;
      var blocked = 0;
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
          'SELECT id, primary_muscle, secondary_muscles_json, equipment_json, '
          'supplied FROM exercises',
        )) {
          final m = mapLegacyExercise(
            LegacyExerciseRow(
              id: r['id']! as String,
              primaryMuscle: r['primary_muscle'],
              secondaryMusclesJson: r['secondary_muscles_json'],
              equipmentJson: r['equipment_json'],
              supplied: r['supplied'],
            ),
          );
          if (m.isBlocked) blocked++;
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
