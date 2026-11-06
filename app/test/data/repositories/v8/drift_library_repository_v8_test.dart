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
        'then its primary; one of two reasons keeps it blocked; history '
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
      expect(second.stillBlocked, isFalse);
      expect(second.exercise.availability.canEnterNewWork, isTrue);
      expect(await selectableIds(), contains('ex-rotator'));
      expect(await targetRows('ex-rotator'), ['shoulders:primary@0']);
      final blocks = second.exercise.availability.blocks;
      expect(blocks, hasLength(2));
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

    test('the report entry records the field before and after (R-06) in its '
        'own run; the run reconciles', () async {
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
      expect(outcome.stillBlocked, isFalse);
      expect(await h.report.runs(), hasLength(runsBefore + 1));
      final run = (await h.report.run(outcome.runId))!;
      expect(run.trigger, CorrectionReportContract.trigger.name);
      expect(run.provenanceKind, 'device');
      final entry = (await h.report.entries(runId: outcome.runId))
          .entries
          .single;
      expect(entry.eventId, outcome.eventIds.single);
      expect(entry.recordId, 'ex-garbage');
      expect(entry.exerciseId, 'ex-garbage');
      expect(entry.field, 'equipment');
      expect(entry.disposition, 'mapped');
      expect(entry.category, 'migrated');
      expect(entry.rule, MigrationRuleCodes.invalidEquipmentBlock);
      expect(decodeStoredValue(entry.originalValue), '[]');
      expect(jsonDecode(decodeStoredValue(entry.resultingValue)! as String), [
        {'item': 'barbell', 'roleOverride': null, 'overrideNote': null},
      ]);
      final t = (await h.report.totals(outcome.runId)).tables['exercises']!;
      expect(t.category('examined'), 1);
      expect(t.category('migrated'), 1);
      expect(t.disposition('mapped'), 1);
      expect(
        reconcileReport(await h.report.storedReport(outcome.runId)).reconciles,
        isTrue,
      );
      // The migration run that blocked it is unchanged.
      expect(
        (await h.report.entries(exerciseId: 'ex-garbage')).entries
            .where((e) => e.disposition == 'blocked'),
        hasLength(1),
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
      // R-C3: invalidSecondaryTarget has no route (and v8 never stores it).
      expect(
        await fieldOf(
          'ex-rotator',
          BlockReason.invalidSecondaryTarget,
          toDumbbell,
        ),
        'reason',
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
        'exerciseId',
      );
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
