import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/repositories/v8/drift_library_repository_v8.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/core/search_key.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/exercise_availability.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_validation.dart' as wp9;
import 'package:sqlite3/sqlite3.dart';

import 'v8_library_support.dart';

/// WP 8 sub-stage 3b-8 (D04 §7, 2026-11-06, "3b check scope"): blocking at
/// the data layer over a database migrated by the real 3b-4 step.
///
/// - blocked exercises never appear in selection and are refused by the
///   write guards, which then write nothing;
/// - by-id and history reads include every exercise; the history of a
///   blocked exercise reads back equal to its v7 rows;
/// - the correction route resolves one reason at a time (R-01), is checked
///   by the 3a rules, and leaves every plan, session, entry and set
///   unchanged;
/// - users may set attributes and overrides under the same checks (ADR-0008
///   E Q14); a custom copy copies values (Q16).
void main() {
  late V8LibraryHarness h;

  setUp(() async => h = await V8LibraryHarness.open());
  tearDown(() => h.close());
  tearDownAll(V8LibraryFixture.dispose);

  T ok<T>(Result<T> r) => switch (r) {
    Ok(:final value) => value,
    Err(:final error) => fail('expected Ok, got ${error.message}'),
  };

  AppError err<T>(Result<T> r) => switch (r) {
    Ok() => fail('expected Err'),
    Err(:final error) => error,
  };

  Future<void> sql(String statement, [List<Object?> args = const []]) =>
      h.db.customStatement(statement, args);

  /// Runs [action] and proves that no table changed.
  Future<R> writesNothing<R>(Future<R> Function() action) async {
    final before = await h.dump();
    final result = await action();
    expect(await h.dump(), before, reason: 'something was written');
    return result;
  }

  Future<Set<String>> selectableIds([
    LibrarySelectionQuery query = const LibrarySelectionQuery(),
  ]) async => {for (final e in await h.library.selectable(query)) e.id.value};

  /// Every exercise id, read plainly (no availability logic).
  Future<Set<String>> allIds() async => {
    for (final r in await h.db.customSelect('SELECT id FROM exercises').get())
      r.read<String>('id'),
  };

  group('selection never offers a blocked exercise', () {
    test('the migration blocked the fixture exercises, one row per '
        'reason (R-01)', () async {
      final blocked = await h.report.blockedExercises();
      expect({
        for (final b in blocked)
          b.exerciseId: {for (final r in b.activeReasons) r.name},
      }, V8LibraryFixture.blocked);
    });

    test('selection excludes blocked, archived, retired, deleted and '
        'unreadable exercises and offers every other one; the SQL '
        'candidates and the domain predicate are checked separately '
        '(non-circular expectations from the fixture)', () async {
      await sql("UPDATE exercises SET archived = 1 WHERE id = 'lib-leg-press'");
      await sql('UPDATE exercises SET retired_at = ? WHERE id = ?', [
        V8LibraryFixture.now.toIso8601String(),
        'lib-hack-squat',
      ]);
      // Known from the fixture and the two updates above, not computed by
      // any availability logic.
      final blocked = V8LibraryFixture.blocked.keys.toSet();
      const archived = {'lib-leg-press'};
      const retired = {'lib-hack-squat'};
      const deleted = {'ex-deleted'};
      const unreadable = {'ex-unmapped-enums'}; // type 'Aerobic' (WS4 L9)
      final all = await allIds();
      expect(all, containsAll([...blocked, ...archived, ...retired]));
      final hidden = {...blocked, ...archived, ...retired, ...deleted};

      // 1. The SQL half alone.
      expect(
        (await h.library.selectionCandidateIds()).toSet(),
        all.difference(hidden),
      );
      expect(
        (await h.library.selectionCandidateIds(includeArchived: true)).toSet(),
        all.difference({...blocked, ...retired, ...deleted}),
      );
      // 2. The domain predicate alone, on every exercise.
      for (final id in all) {
        final a = (await h.library.availability(id))!;
        expect(a.isDiscoverable, !hidden.contains(id), reason: id);
        expect(
          a.canEnterNewWork,
          !{...blocked, ...archived, ...deleted}.contains(id),
          reason: id,
        );
      }
      // 3. The combination, which also drops unreadable rows.
      final ids = await selectableIds();
      expect(ids, all.difference({...hidden, ...unreadable}));
      expect(ids, containsAll(['ex-bench', 'ex-row', 'lib-back-squat']));
      final withArchived = await selectableIds(
        const LibrarySelectionQuery(includeArchived: true),
      );
      expect(withArchived, {...ids, ...archived});
    });

    test('no query can reach a blocked exercise', () async {
      final queries = [
        const LibrarySelectionQuery(text: 'External rotation'),
        const LibrarySelectionQuery(text: 'rotation'),
        const LibrarySelectionQuery(text: 'No muscle'),
        const LibrarySelectionQuery(text: 'Garbage'),
        const LibrarySelectionQuery(category: ExerciseCategory.push),
        const LibrarySelectionQuery(category: ExerciseCategory.core),
        const LibrarySelectionQuery(type: ExerciseType.weighted),
        const LibrarySelectionQuery(type: ExerciseType.bodyweight),
        const LibrarySelectionQuery(target: AnatomyNodeId('regionChest')),
        LibrarySelectionQuery(
          availableEquipment: {
            for (final i in const ['dumbbell', 'cable', 'barbell', 'bench'])
              EquipmentItemId(i),
          },
        ),
        const LibrarySelectionQuery(sources: {ExerciseSource.user}),
      ];
      for (final q in queries) {
        final ids = await selectableIds(q);
        expect(
          ids.intersection(V8LibraryFixture.blocked.keys.toSet()),
          isEmpty,
        );
      }
    });

    test('the filters work on the exercises that remain', () async {
      expect(
        await selectableIds(const LibrarySelectionQuery(text: 'squat')),
        containsAll(['lib-back-squat', 'lib-front-squat', 'ex-squat']),
      );
      expect(
        await selectableIds(const LibrarySelectionQuery(text: 'squat')),
        isNot(contains('ex-bench')),
      );
      final thigh = await selectableIds(
        const LibrarySelectionQuery(target: AnatomyNodeId('regionThigh')),
      );
      expect(thigh, containsAll(['lib-back-squat', 'lib-leg-curl']));
      expect(thigh, isNot(contains('ex-bench')));
      final machineOnly = await selectableIds(
        LibrarySelectionQuery(
          availableEquipment: {const EquipmentItemId('machine')},
        ),
      );
      expect(machineOnly, contains('lib-leg-press'));
      expect(machineOnly, isNot(contains('lib-back-squat')));
      expect(machineOnly, contains('ex-full')); // no equipment
      final systemPush = await selectableIds(
        const LibrarySelectionQuery(
          sources: {ExerciseSource.system},
          category: ExerciseCategory.legs,
          type: ExerciseType.weighted,
        ),
      );
      expect(systemPush.every((id) => id.startsWith('lib-')), isTrue);
      final names = [
        for (final e in await h.library.selectable())
          normaliseSearchKey(e.name),
      ];
      expect(names, [...names]..sort());
    });
  });

  group('by-id and history reads include every exercise', () {
    test('byId reads blocked, archived, retired and deleted exercises with '
        'their availability', () async {
      for (final MapEntry(key: id, value: reasons)
          in V8LibraryFixture.blocked.entries) {
        final s = (await h.library.byId(id))!;
        expect(s.availability.state, ExerciseAvailabilityState.blocked);
        expect({for (final r in s.availability.blockReasons) r.name}, reasons);
        expect(s.availability.canEnterNewWork, isFalse);
      }
      final deleted = (await h.library.byId('ex-deleted'))!;
      expect(deleted.availability.isDeleted, isTrue);
      expect(deleted.exercise, isNotNull);
      final unreadable = (await h.library.byId('ex-unmapped-enums'))!;
      expect(unreadable.exercise, isNull);
      expect(unreadable.storedType, 'Aerobic');
      expect(await h.library.byId('no-such'), isNull);
      expect(
        (await h.library.availability('ex-bench'))!.canEnterNewWork,
        isTrue,
      );
    });

    test('the history of a blocked exercise reads back equal to its v7 '
        'rows', () async {
      final v7 = sqlite3.open(
        V8LibraryFixture.v7Template().path,
        mode: OpenMode.readOnly,
      );
      try {
        for (final id in ['ex-rotator', 'ex-empty']) {
          final history = await h.library.history(id);
          final v7Sets = v7.select(
            'SELECT * FROM session_sets WHERE exercise_id = ? '
            'ORDER BY exercise_order, set_order, id',
            [id],
          );
          final v7Entries = v7.select(
            'SELECT * FROM session_exercises WHERE exercise_id = ? '
            'ORDER BY position',
            [id],
          );
          final v7Sessions = v7.select(
            'SELECT * FROM workout_sessions WHERE id IN (SELECT session_id '
            'FROM session_sets WHERE exercise_id = ? UNION SELECT session_id '
            'FROM session_exercises WHERE exercise_id = ?) ORDER BY '
            'started_at, id',
            [id, id],
          );
          expect(v7Sets, isNotEmpty);
          expect(
            [for (final s in history) s.session.id],
            [for (final r in v7Sessions) r['id']],
          );
          expect(
            [
              for (final s in history)
                [
                  s.session.name,
                  s.session.notes,
                  s.session.startedAt.toIso8601String(),
                  s.session.endedAt?.toIso8601String(),
                ],
            ],
            [
              for (final r in v7Sessions)
                [r['name'], r['notes'], r['started_at'], r['ended_at']],
            ],
          );
          expect(
            [
              for (final s in history)
                for (final e in s.entries) [e.id, e.position, e.note],
            ],
            [
              for (final r in v7Entries) [r['id'], r['position'], r['note']],
            ],
          );
          expect(
            [
              for (final s in history)
                for (final x in s.sets)
                  [
                    x.id,
                    x.sessionId,
                    x.exerciseId,
                    x.exerciseOrder,
                    x.setOrder,
                    x.type,
                    x.loadKg,
                    x.reps,
                    if (x.completed) 1 else 0,
                    x.exertionScale,
                    x.exertionValue,
                    x.setKind,
                    x.sessionExerciseId,
                  ],
            ],
            [
              for (final r in v7Sets)
                [
                  r['id'],
                  r['session_id'],
                  r['exercise_id'],
                  r['exercise_order'],
                  r['set_order'],
                  r['type'],
                  r['load_kg'],
                  r['reps'],
                  r['completed'],
                  r['exertion_scale'],
                  r['exertion_value'],
                  r['set_kind'],
                  r['session_exercise_id'],
                ],
            ],
          );
          final plans = await h.library.planEntries(id);
          final v7Plans = v7.select(
            'SELECT id, plan_id, sort_order, target_sets FROM plan_exercises '
            'WHERE exercise_id = ? ORDER BY plan_id, sort_order, id',
            [id],
          );
          expect(
            [
              for (final p in plans)
                [p.id, p.planId, p.sortOrder, p.targetSets],
            ],
            [
              for (final r in v7Plans)
                [r['id'], r['plan_id'], r['sort_order'], r['target_sets']],
            ],
          );
        }
        expect(await h.library.history('never-used'), isEmpty);
      } finally {
        v7.close();
      }
    });
  });

  group('write guards refuse a blocked exercise and write nothing', () {
    test(
      'addPlanExercise and addSessionExercise refuse every blocked id',
      () async {
        for (final MapEntry(key: id, value: reasons)
            in V8LibraryFixture.blocked.entries) {
          final planErr = await writesNothing(
            () => h.library.addPlanExercise(
              planId: 'plan-01',
              entry: PlanExercise(
                id: '',
                exerciseId: id,
                sortOrder: 0,
                targetSets: 3,
                repsMin: 5,
                repsMax: 5,
              ),
            ),
          );
          final e1 = err(planErr) as ValidationError;
          expect(e1.field, 'exerciseId');
          expect(e1.fieldErrors['availability'], 'blocked');
          expect(e1.fieldErrors['blockReasons']!.split(',').toSet(), reasons);
          final sessionErr = await writesNothing(
            () => h.library.addSessionExercise(
              sessionId: 'sess-01',
              exerciseId: id,
            ),
          );
          final e2 = err(sessionErr) as ValidationError;
          expect(e2.fieldErrors['availability'], 'blocked');
        }
      },
    );

    test('archived, deleted, unreadable and missing exercises are refused '
        'too; a retired one is not (ADR-0009: hidden from discovery only; '
        'R-C8)', () async {
      await sql("UPDATE exercises SET archived = 1 WHERE id = 'lib-leg-press'");
      await sql('UPDATE exercises SET retired_at = ? WHERE id = ?', [
        V8LibraryFixture.now.toIso8601String(),
        'lib-hack-squat',
      ]);
      // ex-unmapped-enums is blocked by the migration (invalidClassification);
      // with its block row removed, the unreadable guard still refuses it (a
      // second line of defence for rows no migration examined).
      await sql(
        "DELETE FROM exercise_blocks WHERE exercise_id = 'ex-unmapped-enums'",
      );
      final cases = {
        'lib-leg-press': 'archived',
        'ex-unmapped-enums': 'unreadable',
      };
      for (final MapEntry(key: id, value: state) in cases.entries) {
        final r = await writesNothing(
          () => h.library.addSessionExercise(
            sessionId: 'sess-01',
            exerciseId: id,
          ),
        );
        expect((err(r) as ValidationError).fieldErrors['availability'], state);
      }
      ok(
        await h.library.addSessionExercise(
          sessionId: 'sess-01',
          exerciseId: 'lib-hack-squat',
        ),
      );
      for (final id in ['ex-deleted', 'no-such']) {
        final r = await writesNothing(
          () => h.library.addSessionExercise(
            sessionId: 'sess-01',
            exerciseId: id,
          ),
        );
        expect(err(r), isA<NotFoundError>());
      }
      expect(
        err(
          await writesNothing(
            () => h.library.addSessionExercise(
              sessionId: 'no-session',
              exerciseId: 'ex-bench',
            ),
          ),
        ),
        isA<NotFoundError>(),
      );
      expect(
        err(
          await writesNothing(
            () => h.library.addPlanExercise(
              planId: 'plan-02', // deleted
              entry: const PlanExercise(
                id: '',
                exerciseId: 'ex-bench',
                sortOrder: 0,
                targetSets: 3,
              ),
            ),
          ),
        ),
        isA<NotFoundError>(),
      );
    });

    test('a selectable exercise is added, exactly once, with the WP 9 '
        'validation', () async {
      final before = await h.tableCounts();
      final entry = ok(
        await h.library.addPlanExercise(
          planId: 'plan-01',
          entry: const PlanExercise(
            id: '',
            exerciseId: 'lib-goblet-squat',
            sortOrder: 0,
            targetSets: 3,
            repsMin: 8,
            repsMax: 12,
          ),
        ),
      );
      expect(entry.sortOrder, 4); // after the four plan-01 entries
      expect(entry.id, 'new-1');
      final session = ok(
        await h.library.addSessionExercise(
          sessionId: 'sess-01',
          exerciseId: 'lib-goblet-squat',
          note: 'new',
        ),
      );
      expect(session.position, greaterThan(0));
      final after = await h.tableCounts();
      expect(after['plan_exercises'], before['plan_exercises']! + 1);
      expect(after['session_exercises'], before['session_exercises']! + 1);
      expect(after['session_sets'], before['session_sets']);
      // The WP 9 validation still applies (target sets 1 to 20).
      final timed = await writesNothing(
        () => h.library.addPlanExercise(
          planId: 'plan-01',
          entry: const PlanExercise(
            id: 'x',
            exerciseId: 'lib-back-squat',
            sortOrder: 0,
            targetSets: 0,
          ),
        ),
      );
      expect(err(timed), isA<ValidationError>());
      expect(ok(await h.library.requireNewWork('ex-bench')).id, 'ex-bench');
    });
  });

  group('correction route sets the field (R-01; R-C4; history unchanged)', () {
    Future<List<String>> targetRows(String id) async => [
      for (final r
          in await h.db
              .customSelect(
                'SELECT node_id, role, ordinal FROM exercise_targets '
                'WHERE exercise_id = ? ORDER BY ordinal',
                variables: [Variable<String>(id)],
              )
              .get())
        [
          '${r.read<String>('node_id')}:${r.read<String>('role')}',
          r.read<int>('ordinal'),
        ].join('@'),
    ];

    Future<List<String>> equipmentRows(String id) async => [
      for (final r
          in await h.db
              .customSelect(
                'SELECT equipment_id, ordinal FROM exercise_equipment '
                'WHERE exercise_id = ? ORDER BY ordinal',
                variables: [Variable<String>(id)],
              )
              .get())
        '${r.read<String>('equipment_id')}@${r.read<int>('ordinal')}',
    ];

    test('ex-rotator: "Dumbbells","None","Pulley" corrected faithfully, '
        'then its targets (primary and unreadable secondary together, '
        'R-C4); the reasons of the other field keep it blocked; history '
        'digests never change', () async {
      final history = await h.historyDigests();
      final first = ok(
        await h.library.correctBlockedReason(
          'ex-rotator',
          BlockReason.unknownEquipment,
          const SetEquipmentCorrection([
            ExerciseEquipment(EquipmentItemId('dumbbell')),
            ExerciseEquipment(EquipmentItemId('cable')),
          ]),
        ),
      );
      expect(first.resolved, {BlockReason.unknownEquipment});
      expect(first.stillBlocked, isTrue);
      expect(first.exercise.availability.blockReasons, {
        BlockReason.noPrimaryTarget,
        BlockReason.invalidSecondaryTarget,
      });
      expect(await equipmentRows('ex-rotator'), ['dumbbell@0', 'cable@1']);
      expect(await selectableIds(), isNot(contains('ex-rotator')));
      expect(
        err(
          await writesNothing(
            () => h.library.addSessionExercise(
              sessionId: 'sess-01',
              exerciseId: 'ex-rotator',
            ),
          ),
        ),
        isA<ValidationError>(),
      );
      final second = ok(
        await h.library.correctBlockedReason(
          'ex-rotator',
          BlockReason.noPrimaryTarget,
          const SetTargetsCorrection([
            (node: AnatomyNodeId('shoulders'), role: TargetRole.primary),
          ]),
        ),
      );
      expect(second.resolved, {
        BlockReason.noPrimaryTarget,
        BlockReason.invalidSecondaryTarget,
      });
      expect(second.stillBlocked, isFalse);
      expect(second.exercise.availability.canEnterNewWork, isTrue);
      expect(await selectableIds(), contains('ex-rotator'));
      expect(await targetRows('ex-rotator'), ['shoulders:primary@0']);
      final blocks = second.exercise.availability.blocks;
      expect(blocks, hasLength(3));
      expect(blocks.every((b) => b.resolvedAt == V8LibraryFixture.now), isTrue);
      expect(await h.historyDigests(), history);
      expect(
        [for (final s in await h.library.history('ex-rotator')) s.session.id],
        [V8LibraryFixture.legacySession],
      );
    });

    test('ex-dup: legacy "bodyweight" corrected faithfully with an empty '
        'equipment list (equipment.md section 1 rule 2)', () async {
      final history = await h.historyDigests();
      expect(await equipmentRows('ex-dup'), isEmpty);
      final r = ok(
        await h.library.correctBlockedReason(
          'ex-dup',
          BlockReason.unknownEquipment,
          const SetEquipmentCorrection([]),
        ),
      );
      expect(r.resolved, {BlockReason.unknownEquipment});
      expect(r.stillBlocked, isFalse);
      expect(r.exercise.exercise!.equipment, isEmpty);
      expect(await equipmentRows('ex-dup'), isEmpty);
      expect(await selectableIds(), contains('ex-dup'));
      expect(await h.historyDigests(), history);
    });

    test('a kept secondary becomes the primary: primaries first, ordinals '
        'contiguous', () async {
      expect(await targetRows('ex-sec-only'), [
        'rearDelts:secondary@0',
        'upperBack:secondary@1',
      ]);
      final r = ok(
        await h.library.correctBlockedReason(
          'ex-sec-only',
          BlockReason.noPrimaryTarget,
          const SetTargetsCorrection([
            (node: AnatomyNodeId('upperBack'), role: TargetRole.secondary),
            (node: AnatomyNodeId('rearDelts'), role: TargetRole.primary),
          ]),
        ),
      );
      expect(r.stillBlocked, isFalse);
      expect(await targetRows('ex-sec-only'), [
        'rearDelts:primary@0',
        'upperBack:secondary@1',
      ]);
      // The full list replaces the old one: a target can also be removed.
      await sql(
        'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
        "blocked_at, resolved_at) VALUES ('ex-squat', 'noPrimaryTarget', "
        "'{}', ?, NULL)",
        [V8LibraryFixture.now.toIso8601String()],
      );
      ok(
        await h.library.correctBlockedReason(
          'ex-squat',
          BlockReason.noPrimaryTarget,
          const SetTargetsCorrection([
            (node: AnatomyNodeId('glutes'), role: TargetRole.primary),
          ]),
        ),
      );
      expect(await targetRows('ex-squat'), ['glutes:primary@0']);
    });

    test('an equipment correction resolves unknownEquipment and '
        'invalidEquipment together (R-C4); a target reason stays', () async {
      await sql(
        'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
        "blocked_at, resolved_at) VALUES ('ex-rotator', 'invalidEquipment', "
        "'{}', ?, NULL)",
        [V8LibraryFixture.now.toIso8601String()],
      );
      final r = ok(
        await h.library.correctBlockedReason(
          'ex-rotator',
          BlockReason.invalidEquipment,
          const SetEquipmentCorrection([
            ExerciseEquipment(EquipmentItemId('dumbbell')),
          ]),
        ),
      );
      expect(r.resolved, {
        BlockReason.unknownEquipment,
        BlockReason.invalidEquipment,
      });
      expect(r.exercise.availability.blockReasons, {
        BlockReason.noPrimaryTarget,
        BlockReason.invalidSecondaryTarget,
      });
      // One report entry per resolved reason, each with its rule.
      final page = await h.report.entries(runId: r.runId);
      expect(page.entries.map((e) => e.eventId).toSet(), r.eventIds.toSet());
      expect(
        {for (final e in page.entries) e.rule},
        {
          MigrationRuleCodes.unknownEquipmentBlock,
          MigrationRuleCodes.invalidEquipmentBlock,
        },
      );
      expect(
        reconcileReport(await h.report.storedReport(r.runId)).reconciles,
        isTrue,
      );
    });

    test('C-1: the report entry (action corrected, trigger userCorrection) '
        'records the field before and after (R-06) in its own run; the run '
        'reconciles', () async {
      final runsBefore = (await h.report.runs()).length;
      final outcome = ok(
        await h.library.correctBlockedReason(
          'ex-garbage',
          BlockReason.invalidEquipment,
          const SetEquipmentCorrection([
            ExerciseEquipment(EquipmentItemId('barbell')),
          ]),
        ),
      );
      // The unreadable secondaries keep it blocked (R-01).
      expect(outcome.stillBlocked, isTrue);
      expect(outcome.exercise.availability.blockReasons, {
        BlockReason.invalidSecondaryTarget,
      });
      expect(await h.report.runs(), hasLength(runsBefore + 1));
      final run = (await h.report.run(outcome.runId))!;
      expect(run.trigger, 'userCorrection');
      expect(run.trigger, CorrectionReportContract.trigger.name);
      expect(run.provenanceKind, 'device');
      final entry = (await h.report.entries(runId: outcome.runId))
          .entries
          .single;
      expect(entry.eventId, outcome.eventIds.single);
      expect(entry.recordId, 'ex-garbage');
      expect(entry.exerciseId, 'ex-garbage');
      expect(entry.field, 'equipment');
      expect(entry.disposition, 'corrected');
      expect(entry.category, 'migrated');
      expect(entry.rule, MigrationRuleCodes.invalidEquipmentBlock);
      expect(decodeStoredValue(entry.originalValue), '[]');
      expect(jsonDecode(decodeStoredValue(entry.resultingValue)! as String), [
        {'item': 'barbell', 'roleOverride': null, 'overrideNote': null},
      ]);
      final t = (await h.report.totals(outcome.runId)).tables['exercises']!;
      expect(t.category('examined'), 1);
      expect(t.category('migrated'), 1);
      expect(t.disposition('corrected'), 1);
      expect(t.disposition('mapped'), 0);
      expect(
        reconcileReport(await h.report.storedReport(outcome.runId)).reconciles,
        isTrue,
      );
      // The migration run that blocked it is unchanged.
      expect(
        (await h.report.entries(exerciseId: 'ex-garbage')).entries
            .where((e) => e.disposition == 'blocked')
            .map((e) => e.blockReason)
            .toSet(),
        {'invalidEquipment', 'invalidSecondaryTarget'},
      );
    });

    test('invalid corrections are refused by the 3a rules and write '
        'nothing', () async {
      final cases = <(String, BlockReason, BlockCorrection, String)>[
        (
          'ex-empty',
          BlockReason.noPrimaryTarget,
          const SetTargetsCorrection([
            (node: AnatomyNodeId('abs'), role: TargetRole.secondary),
          ]),
          'IC-204:targets',
        ),
        (
          'ex-empty',
          BlockReason.noPrimaryTarget,
          const SetTargetsCorrection([]),
          'IC-204:targets',
        ),
        (
          'ex-empty',
          BlockReason.noPrimaryTarget,
          const SetTargetsCorrection([
            (node: AnatomyNodeId('rotatorCuff'), role: TargetRole.primary),
          ]),
          'IC-301:targets',
        ),
        (
          'ex-empty',
          BlockReason.noPrimaryTarget,
          const SetTargetsCorrection([
            (node: AnatomyNodeId('abs'), role: TargetRole.primary),
            (node: AnatomyNodeId('abs'), role: TargetRole.secondary),
          ]),
          'IC-305:targets',
        ),
        (
          'ex-empty',
          BlockReason.noPrimaryTarget,
          const SetTargetsCorrection([
            (node: AnatomyNodeId('shoulders'), role: TargetRole.primary),
            (node: AnatomyNodeId('rearDelts'), role: TargetRole.secondary),
          ]),
          'IC-303:targets',
        ),
        (
          'ex-dup',
          BlockReason.unknownEquipment,
          const SetEquipmentCorrection([
            ExerciseEquipment(
              EquipmentItemId('bench'),
              roleOverride: EquipmentRole.load,
            ),
          ]),
          'IC-315:equipment',
        ),
        (
          'ex-dup',
          BlockReason.unknownEquipment,
          const SetEquipmentCorrection([
            ExerciseEquipment(
              EquipmentItemId('treadmill'),
              roleOverride: EquipmentRole.load,
              overrideNote: 'why',
            ),
          ]),
          'IC-315:equipment',
        ),
        (
          'ex-dup',
          BlockReason.unknownEquipment,
          const SetEquipmentCorrection([
            ExerciseEquipment(EquipmentItemId('bodyweight')),
          ]),
          'IC-307:equipment',
        ),
        (
          'ex-rotator',
          BlockReason.unknownEquipment,
          const SetEquipmentCorrection([
            ExerciseEquipment(EquipmentItemId('dumbbell')),
            ExerciseEquipment(EquipmentItemId('dumbbell')),
          ]),
          'IC-307:equipment',
        ),
      ];
      for (final (id, reason, fix, code) in cases) {
        final r = await writesNothing(
          () => h.library.correctBlockedReason(id, reason, fix),
        );
        expect(
          (err(r) as ValidationError).fieldErrors.keys,
          contains(code),
          reason: '$id $code',
        );
      }
    });

    test('one transaction: a failure in the last write (the report run) '
        'undoes the field and the block resolution', () async {
      await sql(
        'INSERT INTO migration_runs (id, trigger_kind, generated_at, '
        'app_version, provenance_kind, provenance_source) VALUES '
        "('correction:new-1', 'integrityCheck', ?, 'x', 'device', 'x')",
        [V8LibraryFixture.now.toIso8601String()],
      );
      final r = await writesNothing(
        () => h.library.correctBlockedReason(
          'ex-sec-only',
          BlockReason.noPrimaryTarget,
          const SetTargetsCorrection([
            (node: AnatomyNodeId('rearDelts'), role: TargetRole.primary),
          ]),
        ),
      );
      expect(err(r), isA<StorageError>());
      expect((await h.library.availability('ex-sec-only'))!.isBlocked, isTrue);
    });

    test('mismatched, inactive, unrouted, system and missing corrections are '
        'refused and write nothing', () async {
      const toDumbbell = SetEquipmentCorrection([
        ExerciseEquipment(EquipmentItemId('dumbbell')),
      ]);
      Future<AppError> refused(
        String id,
        BlockReason reason,
        BlockCorrection fix,
      ) async => err(
        await writesNothing(
          () => h.library.correctBlockedReason(id, reason, fix),
        ),
      );
      Future<String?> fieldOf(
        String id,
        BlockReason reason,
        BlockCorrection fix,
      ) async => (await refused(id, reason, fix) as ValidationError).field;

      expect(
        await fieldOf('ex-rotator', BlockReason.noPrimaryTarget, toDumbbell),
        'fix',
      );
      expect(
        await fieldOf(
          'ex-dup',
          BlockReason.unknownEquipment,
          const SetTargetsCorrection([]),
        ),
        'fix',
      );
      expect(
        await fieldOf('ex-empty', BlockReason.unknownEquipment, toDumbbell),
        'reason',
      );
      // invalidSecondaryTarget is corrected through the targets only.
      expect(
        await fieldOf(
          'ex-rotator',
          BlockReason.invalidSecondaryTarget,
          toDumbbell,
        ),
        'fix',
      );
      // Classification and aliases take only their own fix.
      expect(
        await fieldOf(
          'ex-unmapped-enums',
          BlockReason.invalidClassification,
          const SetAliasesCorrection([]),
        ),
        'fix',
      );
      expect(
        await fieldOf(
          'ex-bad-aliases',
          BlockReason.invalidAliases,
          const SetClassificationCorrection(
            type: ExerciseType.weighted,
            category: ExerciseCategory.push,
          ),
        ),
        'fix',
      );
      expect(
        await refused('ex-deleted', BlockReason.noPrimaryTarget, toDumbbell),
        isA<NotFoundError>(),
      );
      expect(
        await refused('no-such', BlockReason.noPrimaryTarget, toDumbbell),
        isA<NotFoundError>(),
      );
      expect(
        await fieldOf(
          'ex-unmapped-enums',
          BlockReason.noPrimaryTarget,
          toDumbbell,
        ),
        'reason',
      );
      // Targets and equipment need a readable exercise: while the
      // classification is unreadable they are refused until it is corrected.
      await sql(
        'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
        "blocked_at, resolved_at) VALUES ('ex-unmapped-enums', "
        "'noPrimaryTarget', '{}', ?, NULL)",
        [V8LibraryFixture.now.toIso8601String()],
      );
      final unreadable = await refused(
        'ex-unmapped-enums',
        BlockReason.noPrimaryTarget,
        const SetTargetsCorrection([
          (node: AnatomyNodeId('chest'), role: TargetRole.primary),
        ]),
      ) as ValidationError;
      expect(unreadable.field, 'exerciseId');
      expect(unreadable.message, contains('classification'));
      // A blocked system exercise has no route in 3b (ADR-0009; R-C9).
      await sql(
        'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
        "blocked_at, resolved_at) VALUES ('lib-leg-press', "
        "'unknownEquipment', '{}', ?, NULL)",
        [V8LibraryFixture.now.toIso8601String()],
      );
      expect(
        await fieldOf(
          'lib-leg-press',
          BlockReason.unknownEquipment,
          toDumbbell,
        ),
        'source',
      );
      // Already resolved.
      ok(
        await h.library.correctBlockedReason(
          'ex-dup',
          BlockReason.unknownEquipment,
          const SetEquipmentCorrection([]),
        ),
      );
      expect(
        (await refused(
          'ex-dup',
          BlockReason.unknownEquipment,
          toDumbbell,
        )).message,
        contains('already resolved'),
      );
    });
  });

  group('unreadable data: blocked, history readable, corrected field by '
      'field (owner decisions 2026-11-06: unreadable data, C-1, R-C4)', () {
    Future<Map<String, Object?>> row(String id) async =>
        (await h.db
                .customSelect(
                  'SELECT * FROM exercises WHERE id = ?',
                  variables: [Variable<String>(id)],
                )
                .getSingle())
            .data;

    Future<void> expectCorrectionEntries(
      BlockCorrectionOutcome o, {
      required String field,
      required Map<BlockReason, String> rules,
    }) async {
      final run = (await h.report.run(o.runId))!;
      expect(run.trigger, 'userCorrection');
      final entries = (await h.report.entries(runId: o.runId)).entries;
      expect({for (final e in entries) e.rule}, rules.values.toSet());
      for (final e in entries) {
        expect(e.disposition, 'corrected');
        expect(e.category, 'migrated');
        expect(e.field, field);
        expect(e.blockReason, isNull);
        expect(e.recordId, o.exercise.id);
      }
      final t = (await h.report.totals(o.runId)).tables['exercises']!;
      expect(t.category('examined'), 1);
      expect(t.disposition('corrected'), rules.length);
      expect(
        reconcileReport(await h.report.storedReport(o.runId)).problems,
        isEmpty,
      );
    }

    test('each unreadable exercise is blocked for its reason, never '
        'selectable, refused for new work, and its history stays '
        'readable', () async {
      final selectable = await selectableIds();
      for (final (i, id) in V8LibraryFixture.unreadableHistory.indexed) {
        final stored = (await h.library.byId(id))!;
        expect(
          {for (final r in stored.availability.blockReasons) r.name},
          V8LibraryFixture.blocked[id],
          reason: id,
        );
        expect(selectable, isNot(contains(id)));
        final refused = err(await h.library.requireNewWork(id));
        expect(
          (refused as ValidationError).fieldErrors['availability'],
          'blocked',
        );
        final history = await h.library.history(id);
        expect(history.single.session.id, V8LibraryFixture.unreadableSession);
        expect(history.single.entries.single.id, 'se-unr-$i');
        expect(history.single.sets.single.id, 'set-unr-$i');
        expect(history.single.sets.single.loadKg, 20.0);
      }
      // The classification and alias originals stay readable by id.
      final enums = (await h.library.byId('ex-unmapped-enums'))!;
      expect(
        (enums.storedType, enums.storedCategory),
        ('Aerobic', 'Plyometrics'),
      );
      expect(enums.exercise, isNull);
      expect((await h.library.byId('ex-bad-aliases'))!.exercise, isNull);
      expect((await h.library.byId('ex-trapsec'))!.exercise, isNotNull);
    });

    test('SetClassificationCorrection resolves invalidClassification only, '
        'sets type and category to domain values (the type of its recorded '
        'set, WP 9), reports corrected', () async {
      final history = await h.historyDigests();
      final before = await row('ex-unmapped-enums');
      final o = ok(
        await h.library.correctBlockedReason(
          'ex-unmapped-enums',
          BlockReason.invalidClassification,
          const SetClassificationCorrection(
            type: ExerciseType.weighted,
            category: ExerciseCategory.legs,
          ),
        ),
      );
      expect(o.resolved, {BlockReason.invalidClassification});
      expect(o.stillBlocked, isFalse);
      final after = await row('ex-unmapped-enums');
      expect((after['type'], after['category']), ('weighted', 'legs'));
      expect(after['aliases_json'], before['aliases_json']);
      expect(after['search_key'], before['search_key']);
      expect(o.exercise.exercise!.type, ExerciseType.weighted);
      expect(await selectableIds(), contains('ex-unmapped-enums'));
      ok(await h.library.requireNewWork('ex-unmapped-enums'));
      await expectCorrectionEntries(
        o,
        field: 'classification',
        rules: {
          BlockReason.invalidClassification: 'D04-UNREADABLE-CLASSIFICATION',
        },
      );
      final entry = (await h.report.entries(runId: o.runId)).entries.single;
      expect(
        decodeStoredValue(entry.originalValue),
        '{"type":"Aerobic","category":"Plyometrics"}',
      );
      expect(
        decodeStoredValue(entry.resultingValue),
        '{"type":"weighted","category":"legs"}',
      );
      expect(await h.historyDigests(), history);
      expect(
        (await h.library.history('ex-unmapped-enums')).single.sets.single.id,
        'set-unr-0',
      );
    });

    test('SetAliasesCorrection refuses what a WP 9 save refuses (an alias '
        'too long, more than 20 aliases) and writes nothing', () async {
      for (final (aliases, why) in <(List<String>, String)>[
        (['Press', 'x' * 101], 'too long'),
        ([for (var i = 0; i < 21; i++) 'a$i'], 'At most 20'),
        ([for (var i = 0; i < 21; i++) ' a$i '], 'At most 20'),
      ]) {
        final e = err(
          await writesNothing(
            () => h.library.correctBlockedReason(
              'ex-bad-aliases',
              BlockReason.invalidAliases,
              SetAliasesCorrection(aliases),
            ),
          ),
        );
        expect((e as ValidationError).field, 'aliases', reason: '$aliases');
        expect(e.message, contains(why), reason: '$aliases');
      }
    });

    test('normaliseAliases stores exactly what a WP 9 save stores '
        '(validateExercise of TRN-012(1)), refusals included', () {
      final cases = <List<String>>[
        [],
        ['Press'],
        ['Press', ''],
        ['Press', '  ', '\t'],
        [' Press ', 'press', 'PRESS'],
        ['Pressé', 'Presse', 'Bodenpresse'],
        ['Floor  press', 'floor press'],
        ['x' * 100, 'y'],
        ['x' * 101],
        [' ${'x' * 100} '],
        [for (var i = 0; i < 20; i++) 'a$i'],
        [for (var i = 0; i < 21; i++) 'a$i'],
        [
          ...[for (var i = 0; i < 20; i++) 'a$i'],
          'A0',
          ' a1',
          '',
        ],
      ];
      for (final given in cases) {
        final ours = DriftLibraryRepositoryV8.normaliseAliases(given);
        final theirs = wp9.validateExercise(
          Exercise(
            id: 'x',
            name: 'Probe',
            type: ExerciseType.weighted,
            category: ExerciseCategory.push,
            primaryMuscle: MuscleGroup.chest,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            aliases: given,
          ),
        );
        switch ((ours, theirs)) {
          case (Ok(value: final a), Ok(value: final b)):
            expect(a, b.aliases, reason: '$given');
          case (Err(error: final a), Err(error: final b)):
            expect(a.message, b.message, reason: '$given');
            expect((a as ValidationError).field, 'aliases');
          default:
            fail('$given: $ours vs $theirs');
        }
      }
    });

    test('SetAliasesCorrection stores the list as a WP 9 save does (trimmed, '
        'empty and duplicate aliases dropped) and records the list given '
        'and the list stored', () async {
      const given = [' Press ', '', 'press', 'Pressé', 'Presse', 'Bodenpresse'];
      final o = ok(
        await h.library.correctBlockedReason(
          'ex-bad-aliases',
          BlockReason.invalidAliases,
          const SetAliasesCorrection(given),
        ),
      );
      final after = await row('ex-bad-aliases');
      expect(after['aliases_json'], '["Press","Pressé","Bodenpresse"]');
      expect(
        after['search_key'],
        exerciseSearchKey('Floor press', ['Press', 'Pressé', 'Bodenpresse']),
      );
      final entry = (await h.report.entries(runId: o.runId)).entries.single;
      expect(decodeStoredValue(entry.originalValue), '["Press",7]');
      expect(
        decodeStoredValue(entry.resultingValue),
        '["Press","Pressé","Bodenpresse"]',
      );
      expect(entry.reason, contains(jsonEncode(given)));
      expect(entry.reason, contains('["Press","Pressé","Bodenpresse"]'));
    });

    test(
      'SetAliasesCorrection stores a clean list unchanged, recomputes the '
      'search key, resolves invalidAliases only, reports corrected',
      () async {
        final history = await h.historyDigests();
        final o = ok(
          await h.library.correctBlockedReason(
            'ex-bad-aliases',
            BlockReason.invalidAliases,
            const SetAliasesCorrection(['Press', 'Bodenpresse']),
          ),
        );
        expect(o.resolved, {BlockReason.invalidAliases});
        expect(o.stillBlocked, isFalse);
        final after = await row('ex-bad-aliases');
        expect(after['aliases_json'], '["Press","Bodenpresse"]');
        expect(
          after['search_key'],
          exerciseSearchKey('Floor press', ['Press', 'Bodenpresse']),
        );
        expect(o.exercise.exercise!.aliases, ['Press', 'Bodenpresse']);
        expect(
          await selectableIds(const LibrarySelectionQuery(text: 'bodenpresse')),
          {'ex-bad-aliases'},
        );
        await expectCorrectionEntries(
          o,
          field: 'aliases',
          rules: {BlockReason.invalidAliases: 'D04-UNREADABLE-ALIASES'},
        );
        final entry = (await h.report.entries(runId: o.runId)).entries.single;
        expect(decodeStoredValue(entry.originalValue), '["Press",7]');
        expect(
          decodeStoredValue(entry.resultingValue),
          '["Press","Bodenpresse"]',
        );
        expect(await h.historyDigests(), history);
        // An empty list is a valid correction too.
        await sql(
          "UPDATE exercises SET aliases_json = 'oops' WHERE id = 'ex-row'",
        );
        await sql(
          'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
          "blocked_at, resolved_at) VALUES ('ex-row', 'invalidAliases', '{}', "
          '?, NULL)',
          [V8LibraryFixture.now.toIso8601String()],
        );
        ok(
          await h.library.correctBlockedReason(
            'ex-row',
            BlockReason.invalidAliases,
            const SetAliasesCorrection([]),
          ),
        );
        expect((await row('ex-row'))['aliases_json'], '[]');
      },
    );

    test('SetTargetsCorrection resolves invalidSecondaryTarget alone '
        '(ex-trapsec) and with noPrimaryTarget (ex-neck)', () async {
      final history = await h.historyDigests();
      final trap = ok(
        await h.library.correctBlockedReason(
          'ex-trapsec',
          BlockReason.invalidSecondaryTarget,
          const SetTargetsCorrection([
            (node: AnatomyNodeId('rearDelts'), role: TargetRole.primary),
            (node: AnatomyNodeId('upperBack'), role: TargetRole.secondary),
          ]),
        ),
      );
      expect(trap.resolved, {BlockReason.invalidSecondaryTarget});
      expect(trap.stillBlocked, isFalse);
      await expectCorrectionEntries(
        trap,
        field: 'targets',
        rules: {BlockReason.invalidSecondaryTarget: 'D04-UNREADABLE-SECONDARY'},
      );
      final neck = ok(
        await h.library.correctBlockedReason(
          'ex-neck',
          BlockReason.invalidSecondaryTarget,
          const SetTargetsCorrection([
            (node: AnatomyNodeId('upperBack'), role: TargetRole.primary),
          ]),
        ),
      );
      expect(neck.resolved, {
        BlockReason.noPrimaryTarget,
        BlockReason.invalidSecondaryTarget,
      });
      expect(neck.stillBlocked, isFalse);
      await expectCorrectionEntries(
        neck,
        field: 'targets',
        rules: {
          BlockReason.noPrimaryTarget: 'IC-204',
          BlockReason.invalidSecondaryTarget: 'D04-UNREADABLE-SECONDARY',
        },
      );
      expect(await h.historyDigests(), history);
    });

    test('corrections resolve only their own field: classification and '
        'aliases on one exercise, in either order (R-01)', () async {
      // ex-unmapped-enums also gets an unreadable alias list and its block.
      await sql(
        "UPDATE exercises SET aliases_json = '[1]' "
        "WHERE id = 'ex-unmapped-enums'",
      );
      await sql(
        'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
        "blocked_at, resolved_at) VALUES ('ex-unmapped-enums', "
        "'invalidAliases', '{}', ?, NULL)",
        [V8LibraryFixture.now.toIso8601String()],
      );
      // Aliases first, while the classification is still unreadable.
      final a = ok(
        await h.library.correctBlockedReason(
          'ex-unmapped-enums',
          BlockReason.invalidAliases,
          const SetAliasesCorrection(['Hops']),
        ),
      );
      expect(a.resolved, {BlockReason.invalidAliases});
      expect(a.exercise.availability.blockReasons, {
        BlockReason.invalidClassification,
      });
      expect(a.exercise.exercise, isNull, reason: 'type still unreadable');
      expect(await selectableIds(), isNot(contains('ex-unmapped-enums')));
      final c = ok(
        await h.library.correctBlockedReason(
          'ex-unmapped-enums',
          BlockReason.invalidClassification,
          const SetClassificationCorrection(
            type: ExerciseType.weighted,
            category: ExerciseCategory.legs,
          ),
        ),
      );
      expect(c.resolved, {BlockReason.invalidClassification});
      expect(c.stillBlocked, isFalse);
      expect(c.exercise.exercise!.aliases, ['Hops']);
      // Two correction runs, each reconciled; the migration run unchanged.
      expect(a.runId, isNot(c.runId));
      expect(
        reconcileReport(await h.report.storedReport('run-1')).problems,
        isEmpty,
      );
    });
  });

  group('classification correction keeps the WP 9 type rules '
      '(validateSetForExercise; SaveCustomExercise)', () {
    Future<void> refusedType(
      String id,
      ExerciseType type,
      String message,
    ) async {
      final e = err(
        await writesNothing(
          () => h.library.correctBlockedReason(
            id,
            BlockReason.invalidClassification,
            SetClassificationCorrection(
              type: type,
              category: ExerciseCategory.legs,
            ),
          ),
        ),
      );
      expect((e as ValidationError).field, 'type', reason: '$id $type');
      expect(e.message, contains(message), reason: '$id $type');
    }

    Future<void> block(String id) => sql(
      'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
      "blocked_at, resolved_at) VALUES (?, 'invalidClassification', '{}', "
      '?, NULL)',
      [id, V8LibraryFixture.now.toIso8601String()],
    );

    test('an unreadable type is refused unless it equals the type of the '
        'recorded sets (bodyweight, timed or any other over a weighted '
        'set)', () async {
      for (final t in ExerciseType.values) {
        if (t == ExerciseType.weighted) continue;
        await refusedType(
          'ex-unmapped-enums',
          t,
          'Sets of type weighted have been recorded',
        );
      }
      ok(
        await h.library.correctBlockedReason(
          'ex-unmapped-enums',
          BlockReason.invalidClassification,
          const SetClassificationCorrection(
            type: ExerciseType.weighted,
            category: ExerciseCategory.legs,
          ),
        ),
      );
    });

    test('sets of a deleted session do not count (as WP 9 hasHistory); '
        'sets of several types match no type', () async {
      await sql('UPDATE workout_sessions SET deleted_at = ? WHERE id = ?', [
        V8LibraryFixture.now.toIso8601String(),
        V8LibraryFixture.unreadableSession,
      ]);
      ok(
        await h.library.correctBlockedReason(
          'ex-unmapped-enums',
          BlockReason.invalidClassification,
          const SetClassificationCorrection(
            type: ExerciseType.timed,
            category: ExerciseCategory.legs,
          ),
        ),
      );
      // ex-long has distance and cardio sets (v7 legacy data).
      await sql("UPDATE exercises SET type = 'Aerobic' WHERE id = 'ex-long'");
      await block('ex-long');
      for (final t in ExerciseType.values) {
        await refusedType('ex-long', t, 'Sets of several types');
      }
    });

    test('an unreadable type is refused while a plan uses the exercise '
        '(register C-10, most conservative until the owner decides), also '
        'when the entry has no type-specific target; a deleted plan does not '
        'count', () async {
      // ex-squat: weighted, in plan entries; no recorded sets.
      await sql("UPDATE exercises SET type = 'Aerobic' WHERE id = 'ex-squat'");
      await block('ex-squat');
      for (final t in ExerciseType.values) {
        await refusedType(
          'ex-squat',
          t,
          'The type cannot be set while a plan uses this exercise.',
        );
      }
      await sql(
        'UPDATE workout_plans SET deleted_at = ? WHERE id IN (SELECT plan_id '
        "FROM plan_exercises WHERE exercise_id = 'ex-squat')",
        [V8LibraryFixture.now.toIso8601String()],
      );
      ok(
        await h.library.correctBlockedReason(
          'ex-squat',
          BlockReason.invalidClassification,
          const SetClassificationCorrection(
            type: ExerciseType.distance,
            category: ExerciseCategory.legs,
          ),
        ),
      );
    });

    test('a readable type: changing it is refused once sets are recorded or '
        'while a plan uses the exercise (WP 9 messages); the same type and '
        'a category change pass', () async {
      // ex-bad-aliases (weighted) has one recorded set.
      await block('ex-bad-aliases');
      await sql(
        "UPDATE exercises SET aliases_json = '[]' WHERE id = 'ex-bad-aliases'",
      );
      await refusedType(
        'ex-bad-aliases',
        ExerciseType.bodyweight,
        'The type cannot change once sets have been recorded.',
      );
      // ex-squat (weighted): in a plan, no sets.
      await sql(
        "UPDATE exercises SET category = 'Lifts' WHERE id = 'ex-squat'",
      );
      await block('ex-squat');
      await refusedType(
        'ex-squat',
        ExerciseType.timed,
        'The type cannot change while a plan uses this exercise.',
      );
      final same = ok(
        await h.library.correctBlockedReason(
          'ex-squat',
          BlockReason.invalidClassification,
          const SetClassificationCorrection(
            type: ExerciseType.weighted,
            category: ExerciseCategory.legs,
          ),
        ),
      );
      expect(same.exercise.exercise!.type, ExerciseType.weighted);
      expect(same.exercise.exercise!.category, ExerciseCategory.legs);
    });

    test(
      'a readable type with no sets and no plan may change, as in WP 9',
      () async {
        // ex-dup (bodyweight): no sets, no plan.
        await sql(
          "UPDATE exercises SET category = 'Lifts' WHERE id = 'ex-dup'",
        );
        await block('ex-dup');
        final o = ok(
          await h.library.correctBlockedReason(
            'ex-dup',
            BlockReason.invalidClassification,
            const SetClassificationCorrection(
              type: ExerciseType.timed,
              category: ExerciseCategory.core,
            ),
          ),
        );
        expect(o.exercise.exercise!.type, ExerciseType.timed);
      },
    );
  });

  group('user attributes and overrides (ADR-0008 E Q14)', () {
    Future<Map<String, Object?>> exerciseRow(String id) async =>
        (await h.db
                .customSelect(
                  'SELECT * FROM exercises WHERE id = ?',
                  variables: [Variable<String>(id)],
                )
                .getSingle())
            .data;

    Future<List<Map<String, Object?>>> links(String id) async => [
      for (final r
          in await h.db
              .customSelect(
                'SELECT * FROM exercise_equipment WHERE exercise_id = ? '
                'ORDER BY ordinal',
                variables: [Variable<String>(id)],
              )
              .get())
        r.data,
    ];

    test('a user exercise takes valid attributes and overrides', () async {
      final e = ok(
        await h.library.setUserClassification(
          'ex-squat',
          attributes: {
            ExerciseAttribute.stance: 'wide',
            ExerciseAttribute.bodyPosition: 'standing',
          },
          equipmentRoles: {
            const EquipmentItemId('barbell'): const EquipmentRoleChange(
              role: EquipmentRole.support,
              note: 'held in the rack only',
            ),
          },
        ),
      );
      expect(e.attributes, {
        ExerciseAttribute.stance: 'wide',
        ExerciseAttribute.bodyPosition: 'standing',
      });
      final row = await exerciseRow('ex-squat');
      expect(row['stance'], 'wide');
      expect(row['body_position'], 'standing');
      expect(row['updated_at'], V8LibraryFixture.now.toIso8601String());
      expect((await links('ex-squat')).single['role_override'], 'support');
      // Clearing: null removes; an absent key keeps.
      final cleared = ok(
        await h.library.setUserClassification(
          'ex-squat',
          attributes: {ExerciseAttribute.stance: null},
          equipmentRoles: {
            const EquipmentItemId('barbell'): const EquipmentRoleChange(
              note: 'note kept without an override (R-22)',
            ),
          },
        ),
      );
      expect(cleared.attributes, {ExerciseAttribute.bodyPosition: 'standing'});
      final link = (await links('ex-squat')).single;
      expect(link['role_override'], isNull);
      expect(link['override_note'], 'note kept without an override (R-22)');
    });

    test('the same value, role and note checks apply; a refusal writes '
        'nothing', () async {
      final cases =
          <(String, Future<Result<CatalogueExercise>> Function(), String)>[
            (
              'IC-316 value outside the list',
              () => h.library.setUserClassification(
                'ex-squat',
                attributes: {ExerciseAttribute.stance: 'sideways'},
              ),
              'IC-316:attributes',
            ),
            (
              'IC-316 case must match',
              () => h.library.setUserClassification(
                'ex-squat',
                attributes: {ExerciseAttribute.angle: 'Flat'},
              ),
              'IC-316:attributes',
            ),
            (
              'IC-315 override without a note',
              () => h.library.setUserClassification(
                'ex-squat',
                equipmentRoles: {
                  const EquipmentItemId('barbell'): const EquipmentRoleChange(
                    role: EquipmentRole.support,
                    note: '   ',
                  ),
                },
              ),
              'IC-315:equipment',
            ),
            (
              'IC-315 item not in the list',
              () => h.library.setUserClassification(
                'ex-squat',
                equipmentRoles: {
                  const EquipmentItemId('bench'): const EquipmentRoleChange(
                    role: EquipmentRole.load,
                    note: 'x',
                  ),
                },
              ),
              'IC-315:equipment',
            ),
            (
              'Q6 override on a cardio item',
              () => h.library.setUserClassification(
                'ex-long',
                equipmentRoles: {
                  const EquipmentItemId('treadmill'): const EquipmentRoleChange(
                    role: EquipmentRole.load,
                    note: 'x',
                  ),
                },
              ),
              'IC-315:equipment',
            ),
          ];
      for (final (label, action, code) in cases) {
        final r = await writesNothing(action);
        expect(
          (err(r) as ValidationError).fieldErrors.keys,
          contains(code),
          reason: label,
        );
      }
      // A system exercise is edited through a copy (ADR-0009).
      final system = await writesNothing(
        () => h.library.setUserClassification(
          'lib-back-squat',
          attributes: {ExerciseAttribute.stance: 'wide'},
        ),
      );
      expect((err(system) as ValidationError).field, 'source');
      expect(
        err(
          await h.library.setUserClassification(
            'no-such',
            attributes: {ExerciseAttribute.stance: 'wide'},
          ),
        ),
        isA<NotFoundError>(),
      );
    });

    test('classifying a blocked exercise never unblocks it', () async {
      ok(
        await h.library.setUserClassification(
          'ex-dup',
          attributes: {ExerciseAttribute.grip: 'neutral'},
        ),
      );
      final a = (await h.library.availability('ex-dup'))!;
      expect(a.isBlocked, isTrue);
      expect(await selectableIds(), isNot(contains('ex-dup')));
    });
  });

  group('custom copies copy values (ADR-0008 E Q16)', () {
    /// Gives `lib-back-squat` the classifications release 2 would set.
    Future<void> classifySource() async {
      await sql(
        "UPDATE exercises SET stance = 'standard', knee_position = 'bent', "
        "mechanics = 'compound', laterality = 'bilateral', "
        "difficulty = 'intermediate' WHERE id = 'lib-back-squat'",
      );
      await sql(
        "UPDATE exercise_equipment SET role_override = 'load', "
        "override_note = 'editor note' WHERE exercise_id = 'lib-back-squat' "
        "AND equipment_id = 'squatRack'",
      );
      await sql(
        'INSERT INTO movement_patterns (id, parent_id, sort_order, '
        "provider_id) VALUES ('lowerBodyCompound', NULL, 10, 'repforge'), "
        "('squat', 'lowerBodyCompound', 10, 'repforge')",
      );
      await sql(
        'INSERT INTO exercise_patterns (exercise_id, pattern_id, ordinal) '
        "VALUES ('lib-back-squat', 'squat', 0)",
      );
    }

    test('the copy takes targets, patterns, equipment links with overrides, '
        'attributes and classifications as its own rows', () async {
      await classifySource();
      final source = (await h.library.byId('lib-back-squat'))!.exercise!;
      final copy = ok(
        await h.library.createCustomCopy('lib-back-squat', name: 'My squat'),
      );
      expect(copy.id, isNot(source.id));
      expect(copy.source, ExerciseSource.user);
      expect(copy.copiedFromId, source.id);
      expect(copy.providerId, isNull);
      expect(copy.revision, isNull);
      expect(copy.name, 'My squat');
      expect(copy.aliases, source.aliases);
      expect(copy.type, source.type);
      expect(copy.category, source.category);
      expect(copy.mechanics, Mechanics.compound);
      expect(copy.laterality, Laterality.bilateral);
      expect(copy.difficulty, Difficulty.intermediate);
      expect(copy.attributes, source.attributes);
      expect(copy.attributes, {
        ExerciseAttribute.stance: 'standard',
        ExerciseAttribute.kneePosition: 'bent',
      });
      expect(copy.targets, source.targets);
      expect(copy.patterns, [const MovementPatternId('squat')]);
      expect(copy.equipment, source.equipment);
      expect(
        copy.equipment.firstWhere((e) => e.item.value == 'squatRack'),
        const ExerciseEquipment(
          EquipmentItemId('squatRack'),
          roleOverride: EquipmentRole.load,
          overrideNote: 'editor note',
        ),
      );
      expect(await selectableIds(), contains(copy.id.value));
      // Values, never shared rows: each table holds separate rows.
      for (final table in [
        'exercise_targets',
        'exercise_equipment',
        'exercise_patterns',
      ]) {
        expect(
          await h.countFor(table, copy.id.value),
          await h.countFor(table, 'lib-back-squat'),
          reason: table,
        );
      }
      // Changing the copy leaves the source alone, and the other way round.
      ok(
        await h.library.setUserClassification(
          copy.id.value,
          attributes: {ExerciseAttribute.stance: 'wide'},
          equipmentRoles: {
            const EquipmentItemId('squatRack'): const EquipmentRoleChange(),
          },
        ),
      );
      expect((await h.library.byId('lib-back-squat'))!.exercise, source);
      await sql(
        "UPDATE exercises SET stance = 'narrow' WHERE id = 'lib-back-squat'",
      );
      final copyAgain = (await h.library.byId(copy.id.value))!.exercise!;
      expect(copyAgain.attributes[ExerciseAttribute.stance], 'wide');
      expect(
        copyAgain.equipment
            .firstWhere((e) => e.item.value == 'squatRack')
            .roleOverride,
        isNull,
      );
    });

    test(
      'one transaction: a failing child row leaves no partial copy',
      () async {
        await classifySource();
        // The copy's id will be `new-1`. An orphan target row with that id
        // (keys off only while it is planted) makes the target insert fail
        // after the exercise row of the copy was written.
        await sql('PRAGMA foreign_keys = OFF');
        await sql(
          'INSERT INTO exercise_targets (exercise_id, node_id, role, ordinal) '
          "VALUES ('new-1', 'quadriceps', 'primary', 0)",
        );
        await sql('PRAGMA foreign_keys = ON');
        final r = await writesNothing(
          () => h.library.createCustomCopy('lib-back-squat'),
        );
        expect(err(r), isA<StorageError>());
        expect(await h.library.byId('new-1'), isNull);
      },
    );

    test('a user, blocked, deleted or missing source is refused and '
        'nothing is written', () async {
      expect(
        (err(
          await writesNothing(() => h.library.createCustomCopy('ex-squat')),
        ) as ValidationError).field,
        'id',
      );
      await sql(
        'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
        "blocked_at, resolved_at) VALUES ('lib-leg-press', "
        "'unknownEquipment', '{}', ?, NULL)",
        [V8LibraryFixture.now.toIso8601String()],
      );
      final blocked = err(
        await writesNothing(() => h.library.createCustomCopy('lib-leg-press')),
      );
      expect(
        (blocked as ValidationError).fieldErrors['availability'],
        'blocked',
      );
      await sql('UPDATE exercises SET deleted_at = ? WHERE id = ?', [
        V8LibraryFixture.now.toIso8601String(),
        'lib-leg-curl',
      ]);
      expect(
        err(
          await writesNothing(() => h.library.createCustomCopy('lib-leg-curl')),
        ),
        isA<NotFoundError>(),
      );
      expect(
        err(await writesNothing(() => h.library.createCustomCopy('no-such'))),
        isA<NotFoundError>(),
      );
    });
  });
}
