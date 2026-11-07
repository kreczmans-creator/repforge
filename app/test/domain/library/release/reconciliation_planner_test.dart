import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/release/reconciliation_planner.dart';
import 'package:repforge/domain/library/release/release_validator.dart';

import 'support/release_support.dart';

ExerciseId _id(String v) => ExerciseId(v);

const _ids = [
  'lib-back-squat',
  'lib-front-squat',
  'lib-bench-press',
  'lib-deadlift',
];

List<String> _refusalCodes(ReconciliationPlan p) => [
  for (final f in p.refusals) f.code,
];

CatalogueStateSnapshot _snap(
  Iterable<ExerciseStateEntry> entries, {
  Map<ProviderId, int> applied = const {},
  Map<EquipmentItemId, EquipmentDefaultRole> roles = const {},
}) => CatalogueStateSnapshot(
  exercises: entries,
  latestAppliedRelease: applied,
  equipmentDefaultRoles: roles,
);

/// A snapshot row the planner must refuse.
ExerciseStateEntry _defect(Random rnd, String id, int releaseRevision) =>
    switch (rnd.nextInt(4)) {
      0 => ExerciseStateEntry(id: _id(id), source: ExerciseSource.user),
      1 => ExerciseStateEntry(id: _id(id), source: ExerciseSource.imported),
      2 => ExerciseStateEntry.system(
        _id(id),
        revision: releaseRevision,
        retired: true,
      ),
      _ => ExerciseStateEntry.system(_id(id), revision: releaseRevision + 1),
    };

void main() {
  group('inserts, updates, no-ops', () {
    test('an empty device gets every exercise as an insert, in id order', () {
      final plan = planReconciliation(
        release: validatedSubset(_ids),
        snapshot: CatalogueStateSnapshot.empty,
      );
      expect(plan.canApply, isTrue);
      expect([for (final i in plan.inserts) i.id.value], [..._ids]..sort());
      expect(plan.updates, isEmpty);
      expect(plan.retirements, isEmpty);
      expect(plan.noOps, isEmpty);
      expect(plan.recordsRelease, isTrue);
      expect(plan.writesNothing, isFalse);
      expect(plan.insertedCount, 4);
      expect(plan.contentHash, hasLength(64));
      expect(plan.release.number, 2);
      expect(plan.provider.id, ProviderId.repforge);
      expect(
        plan.inserts.every((i) => i.exercise.source == ExerciseSource.system),
        isTrue,
      );
    });

    test('a higher revision is an update; equal is a no-op', () {
      final plan = planReconciliation(
        release: validatedSubset(
          _ids,
          revisions: {'lib-back-squat': 3, 'lib-deadlift': 2},
          release: 3,
        ),
        snapshot: _snap(
          [
            const ExerciseStateEntry.system(
              ExerciseId('lib-back-squat'),
              revision: 2,
            ),
            const ExerciseStateEntry.system(
              ExerciseId('lib-front-squat'),
              revision: 1,
            ),
            const ExerciseStateEntry.system(
              ExerciseId('lib-bench-press'),
              revision: 1,
            ),
            const ExerciseStateEntry.system(
              ExerciseId('lib-deadlift'),
              revision: 2,
            ),
          ],
          applied: {ProviderId.repforge: 2},
        ),
      );
      expect(plan.canApply, isTrue);
      expect(plan.updates, hasLength(1));
      expect(plan.updates.single.id.value, 'lib-back-squat');
      expect(plan.updates.single.fromRevision, 2);
      expect(plan.updates.single.toRevision, 3);
      expect(plan.inserts, isEmpty);
      expect(
        [for (final n in plan.noOps) n.id.value],
        ['lib-bench-press', 'lib-deadlift', 'lib-front-squat'],
      );
      expect(
        plan.noOps.every((n) => n.reason == NoOpReason.sameRevision),
        isTrue,
      );
      expect(plan.writtenExerciseIds, {_id('lib-back-squat')});
      expect(plan.recordsRelease, isTrue);
    });

    test('a lower revision refuses the whole plan', () {
      final plan = planReconciliation(
        release: validatedSubset(_ids),
        snapshot: _snap([
          const ExerciseStateEntry.system(
            ExerciseId('lib-back-squat'),
            revision: 4,
          ),
        ]),
      );
      expect(_refusalCodes(plan), ['RP-003']);
      expect(plan.canApply, isFalse);
      expect(plan.inserts, isEmpty, reason: 'all or nothing');
      expect(plan.writtenExerciseIds, isEmpty);
      expect(plan.recordsRelease, isFalse);
      expect(plan.writesNothing, isFalse);
    });

    test('re-running an applied release writes nothing', () {
      final release = validatedSubset(_ids);
      final first = planReconciliation(
        release: release,
        snapshot: CatalogueStateSnapshot.empty,
      );
      final after = applyPlan(CatalogueStateSnapshot.empty, first);
      final second = planReconciliation(release: release, snapshot: after);
      expect(second.canApply, isTrue);
      expect(second.writesNothing, isTrue);
      expect(second.recordsRelease, isFalse);
      expect(second.writtenExerciseIds, isEmpty);
      expect(second.noOps, hasLength(4));
    });

    test('a new release number with unchanged exercises records only the '
        'release', () {
      final snapshot = _snap(
        [
          for (final id in _ids)
            ExerciseStateEntry.system(_id(id), revision: 1),
        ],
        applied: {ProviderId.repforge: 2},
      );
      final plan = planReconciliation(
        release: validatedSubset(_ids, release: 3),
        snapshot: snapshot,
      );
      expect(plan.canApply, isTrue);
      expect(plan.recordsRelease, isTrue);
      expect(plan.writtenExerciseIds, isEmpty);
      expect(plan.writesNothing, isFalse);
    });

    test('an older release number is refused (RP-008)', () {
      final plan = planReconciliation(
        release: validatedSubset(_ids),
        snapshot: _snap(const [], applied: {ProviderId.repforge: 5}),
      );
      expect(_refusalCodes(plan), ['RP-008']);
    });

    test('content and media travel with the insert', () {
      final release = validatedSubset(
        _ids,
        edit: (map) {
          exercisesOf(map).first['content'] = {
            'en-GB': {
              'setup': [
                'Set the bar at upper chest height in the rack.',
                'Stand under the bar with your feet shoulder-width apart.',
              ],
            },
          };
        },
      );
      final plan = planReconciliation(
        release: release,
        snapshot: CatalogueStateSnapshot.empty,
      );
      final withContent = plan.inserts.where((i) => i.content.isNotEmpty);
      expect(withContent, hasLength(1));
      expect(withContent.single.content, hasLength(2));
    });
  });

  group('retirements and omissions', () {
    test('a listed system exercise is retired, never deleted', () {
      final plan = planReconciliation(
        release: validatedSubset(
          ['lib-back-squat'],
          release: 3,
          retirements: [
            {'id': 'lib-front-squat', 'reason': 'Merged.'},
          ],
        ),
        snapshot: _snap(
          [
            const ExerciseStateEntry.system(
              ExerciseId('lib-back-squat'),
              revision: 1,
            ),
            const ExerciseStateEntry.system(
              ExerciseId('lib-front-squat'),
              revision: 1,
            ),
          ],
          applied: {ProviderId.repforge: 2},
        ),
      );
      expect(plan.canApply, isTrue);
      expect(plan.retirements.single.id.value, 'lib-front-squat');
      expect(plan.retirements.single.reason, 'Merged.');
      expect(plan.retiredCount, 1);
      expect(plan.writtenExerciseIds, {_id('lib-front-squat')});
    });

    test('an already retired or unknown id is a no-op', () {
      final plan = planReconciliation(
        release: validatedSubset(
          ['lib-back-squat'],
          release: 3,
          retirements: [
            {'id': 'lib-front-squat', 'reason': 'Merged.'},
            {'id': 'lib-never-had', 'reason': 'Dropped.'},
          ],
        ),
        snapshot: _snap(
          [
            const ExerciseStateEntry.system(
              ExerciseId('lib-back-squat'),
              revision: 1,
            ),
            const ExerciseStateEntry.system(
              ExerciseId('lib-front-squat'),
              revision: 1,
              retired: true,
            ),
          ],
          applied: {ProviderId.repforge: 2},
        ),
      );
      expect(plan.canApply, isTrue);
      expect(plan.retirements, isEmpty);
      expect(
        {for (final n in plan.noOps) n.id.value: n.reason},
        {
          'lib-back-squat': NoOpReason.sameRevision,
          'lib-front-squat': NoOpReason.alreadyRetired,
          'lib-never-had': NoOpReason.notInCatalogue,
        },
      );
    });

    test('retiring a user exercise is refused (RP-006)', () {
      final plan = planReconciliation(
        release: validatedSubset(
          ['lib-back-squat'],
          retirements: [
            {'id': 'custom-1', 'reason': 'Merged.'},
          ],
        ),
        snapshot: _snap([
          const ExerciseStateEntry(
            id: ExerciseId('custom-1'),
            source: ExerciseSource.user,
          ),
        ]),
      );
      expect(_refusalCodes(plan), ['RP-006']);
    });

    test('omitting a known system id without retiring it is refused '
        '(RP-005, IC-110)', () {
      final plan = planReconciliation(
        release: validatedSubset(['lib-back-squat'], release: 3),
        snapshot: _snap([
          const ExerciseStateEntry.system(
            ExerciseId('lib-back-squat'),
            revision: 1,
          ),
          const ExerciseStateEntry.system(
            ExerciseId('lib-front-squat'),
            revision: 1,
          ),
          const ExerciseStateEntry.system(
            ExerciseId('lib-old'),
            revision: 1,
            retired: true,
          ),
        ]),
      );
      expect(_refusalCodes(plan), ['RP-005']);
      expect(plan.refusals.single.subjectId, 'lib-front-squat');
    });

    test("omission by another provider is not this release's business", () {
      final plan = planReconciliation(
        release: validatedSubset(['lib-back-squat']),
        snapshot: _snap([
          const ExerciseStateEntry.system(
            ExerciseId('other-1'),
            revision: 1,
            providerId: ProviderId('other'),
          ),
        ]),
      );
      expect(plan.canApply, isTrue);
    });

    test('a retired id in the release is refused (RP-004, IC-111)', () {
      final plan = planReconciliation(
        release: validatedSubset(['lib-back-squat']),
        snapshot: _snap([
          const ExerciseStateEntry.system(
            ExerciseId('lib-back-squat'),
            revision: 1,
            retired: true,
          ),
        ]),
      );
      expect(_refusalCodes(plan), ['RP-004']);
    });
  });

  group('user-owned data is never planned', () {
    test('an id used by a user, imported or custom exercise is refused '
        '(RP-001) and nothing else is planned', () {
      for (final source in [ExerciseSource.user, ExerciseSource.imported]) {
        final plan = planReconciliation(
          release: validatedSubset(_ids),
          snapshot: _snap([
            ExerciseStateEntry(id: _id('lib-deadlift'), source: source),
          ]),
        );
        expect(_refusalCodes(plan), ['RP-001'], reason: source.name);
        expect(plan.inserts, isEmpty);
        expect(plan.writtenExerciseIds, isEmpty);
      }
    });

    test('a different provider owns the id (RP-002)', () {
      final plan = planReconciliation(
        release: validatedSubset(_ids),
        snapshot: _snap([
          const ExerciseStateEntry.system(
            ExerciseId('lib-deadlift'),
            revision: 1,
            providerId: ProviderId('other'),
          ),
        ]),
      );
      expect(_refusalCodes(plan), ['RP-002']);
    });

    test('a system exercise without a stored revision is refused '
        '(RP-011)', () {
      final plan = planReconciliation(
        release: validatedSubset(_ids),
        snapshot: _snap([
          const ExerciseStateEntry(
            id: ExerciseId('lib-deadlift'),
            source: ExerciseSource.system,
            providerId: ProviderId.repforge,
          ),
        ]),
      );
      expect(_refusalCodes(plan), ['RP-011']);
    });

    test('custom copies are left alone; the plan only reports that their '
        'source was updated', () {
      final snapshot = _snap(
        [
          const ExerciseStateEntry.system(
            ExerciseId('lib-back-squat'),
            revision: 1,
          ),
          const ExerciseStateEntry(
            id: ExerciseId('copy-b'),
            source: ExerciseSource.user,
            copiedFromId: ExerciseId('lib-back-squat'),
          ),
          const ExerciseStateEntry(
            id: ExerciseId('copy-a'),
            source: ExerciseSource.user,
            copiedFromId: ExerciseId('lib-back-squat'),
          ),
          const ExerciseStateEntry(
            id: ExerciseId('copy-of-other'),
            source: ExerciseSource.user,
            copiedFromId: ExerciseId('lib-front-squat'),
          ),
        ],
        applied: {ProviderId.repforge: 2},
      );
      final plan = planReconciliation(
        release: validatedSubset(
          ['lib-back-squat', 'lib-front-squat'],
          revisions: {'lib-back-squat': 2},
          release: 3,
        ),
        snapshot: snapshot,
      );
      expect(plan.canApply, isTrue);
      expect(
        [for (final n in plan.sourceUpdatedNotices) n.copyId.value],
        ['copy-a', 'copy-b'],
      );
      expect(plan.sourceUpdatedNotices.first.sourceRevision, 2);
      expect(plan.writtenExerciseIds, {
        _id('lib-back-squat'),
        _id('lib-front-squat'),
      });
      expect(plan.writtenExerciseIds.contains(_id('copy-a')), isFalse);
    });

    test('a relationship ending on a user exercise is refused (RP-009)', () {
      final release = validatedSubset(
        ['lib-back-squat', 'lib-front-squat'],
        edit: (map) {
          exercisesOf(map)[0]['relationships'] = [
            {'kind': 'alternativeTo', 'to': 'lib-front-squat'},
          ];
        },
      );
      final plan = planReconciliation(
        release: release,
        snapshot: _snap([
          const ExerciseStateEntry(
            id: ExerciseId('lib-front-squat'),
            source: ExerciseSource.imported,
          ),
        ]),
      );
      expect(_refusalCodes(plan), contains('RP-009'));
      expect(plan.relationships, isEmpty);
    });

    test('system relationships touching a changed exercise are planned', () {
      final release = validatedSubset(
        ['lib-back-squat', 'lib-front-squat', 'lib-deadlift'],
        edit: (map) {
          exercisesOf(map)[0]['relationships'] = [
            {'kind': 'alternativeTo', 'to': 'lib-front-squat'},
          ];
        },
      );
      final plan = planReconciliation(
        release: release,
        snapshot: _snap(
          [
            const ExerciseStateEntry.system(
              ExerciseId('lib-back-squat'),
              revision: 1,
            ),
            const ExerciseStateEntry.system(
              ExerciseId('lib-front-squat'),
              revision: 1,
            ),
          ],
          applied: {ProviderId.repforge: 1},
        ),
      );
      expect(plan.inserts.map((i) => i.id.value), ['lib-deadlift']);
      expect(plan.relationships, isEmpty, reason: 'both ends unchanged');
      final all = planReconciliation(
        release: release,
        snapshot: CatalogueStateSnapshot.empty,
      );
      expect(all.relationships, hasLength(1));
    });
  });

  group('default roles are immutable (R-20)', () {
    test('a stored role that differs refuses the release', () {
      final release = validatedSubset(_ids);
      final plan = planReconciliation(
        release: release,
        snapshot: _snap(
          const [],
          roles: {
            const EquipmentItemId('barbell'): EquipmentDefaultRole.support,
          },
        ),
      );
      expect(_refusalCodes(plan), ['RP-007']);
      expect(plan.refusals.single.subjectId, 'barbell');
    });

    test('the approved roles themselves pass', () {
      final release = validatedSubset(_ids);
      final roles = {
        for (final i in release.reference.equipment.items) i.id: i.defaultRole,
      };
      final plan = planReconciliation(
        release: release,
        snapshot: _snap(const [], roles: roles),
      );
      expect(plan.canApply, isTrue);
    });
  });

  group('release 2 against a migrated device', () {
    test('a snapshot of the 89 migrated rows at revision 1 plus release 2 '
        'gives 89 updates, not 89 no-ops', () {
      final release = validateReleaseBytes(
        bytes: release2Bytes(),
        reference: approvedSet(),
      ).release!;
      final snapshot = _snap(
        [
          for (final e in release.document.exercises)
            ExerciseStateEntry.system(e.id, revision: 1),
        ],
        // Release 1 was recorded by the migration (R-30), without counts.
        applied: {ProviderId.repforge: 1},
      );
      final plan = planReconciliation(release: release, snapshot: snapshot);
      expect(plan.canApply, isTrue);
      expect(plan.updates, hasLength(89));
      expect(plan.noOps, isEmpty);
      expect(plan.inserts, isEmpty);
      expect(plan.recordsRelease, isTrue);
      expect(plan.updates.every((u) => u.fromRevision == 1), isTrue);
      expect(plan.updates.every((u) => u.toRevision == 2), isTrue);
      // And a second run is then a no-op.
      final again = planReconciliation(
        release: release,
        snapshot: applyPlan(snapshot, plan),
      );
      expect(again.writesNothing, isTrue);
      expect(again.noOps, hasLength(89));
    });
  });

  group('the same release number must be the same file', () {
    final release = validatedSubset(_ids);
    final other = validatedSubset(
      _ids,
      edit: (m) => (m['provider']! as Map<String, Object?>)['name'] = 'Other',
    );

    test('a different hash for an applied number is refused (RP-012)', () {
      expect(other.contentHash, isNot(release.contentHash));
      final applied = applyPlan(
        CatalogueStateSnapshot.empty,
        planReconciliation(
          release: release,
          snapshot: CatalogueStateSnapshot.empty,
        ),
      );
      final plan = planReconciliation(release: other, snapshot: applied);
      expect(_refusalCodes(plan), ['RP-012']);
      expect(plan.writtenExerciseIds, isEmpty);
    });

    test('equal hashes are a no-op; an applied number without a recorded '
        'hash cannot be shown to be the same (RP-013)', () {
      final applied = applyPlan(
        CatalogueStateSnapshot.empty,
        planReconciliation(
          release: release,
          snapshot: CatalogueStateSnapshot.empty,
        ),
      );
      expect(
        planReconciliation(release: release, snapshot: applied).writesNothing,
        isTrue,
      );
      final unknownHash = _snap(
        applied.exercises,
        applied: {ProviderId.repforge: 2},
      );
      expect(
        _refusalCodes(
          planReconciliation(release: release, snapshot: unknownHash),
        ),
        ['RP-013'],
      );
    });
  });

  test('a snapshot with a duplicate id is rejected', () {
    expect(
      () => CatalogueStateSnapshot(
        exercises: const [
          ExerciseStateEntry.system(ExerciseId('a'), revision: 1),
          ExerciseStateEntry(id: ExerciseId('a'), source: ExerciseSource.user),
        ],
      ),
      throwsArgumentError,
    );
  });

  group('invariants over many snapshots', () {
    test('a plan writes only new or system exercises of the provider, '
        'never anything else (ADR-0009 decision 4, R-26)', () {
      final release = validatedSubset(
        _ids,
        revisions: {'lib-back-squat': 2, 'lib-deadlift': 3},
        release: 4,
        retirements: [
          {'id': 'lib-old-1', 'reason': 'Merged.'},
        ],
      );
      final pool = [..._ids, 'lib-old-1', 'lib-old-2', 'user-1', 'user-2'];
      var applicable = 0;
      for (var seed = 0; seed < 300; seed++) {
        final rnd = Random(seed);
        final entries = <ExerciseStateEntry>[];
        // Biased towards snapshots a real device could hold: most draws are
        // absent or a valid system row; about one in ten is a defect.
        for (final id in pool) {
          final roll = rnd.nextInt(10);
          final releaseRevision = switch (id) {
            'lib-back-squat' => 2,
            'lib-deadlift' => 3,
            _ => 1,
          };
          ExerciseStateEntry? entry;
          if (_ids.contains(id)) {
            entry = switch (roll) {
              < 3 => null,
              < 9 => ExerciseStateEntry.system(
                _id(id),
                revision: 1 + rnd.nextInt(releaseRevision),
              ),
              _ => _defect(rnd, id, releaseRevision),
            };
          } else if (id == 'lib-old-1') {
            entry = switch (roll) {
              < 4 => null,
              < 7 => ExerciseStateEntry.system(_id(id), revision: 1),
              7 => ExerciseStateEntry.system(
                _id(id),
                revision: 1,
                retired: true,
              ),
              _ => _defect(rnd, id, 1),
            };
          } else if (id == 'lib-old-2') {
            entry = roll < 9
                ? null
                : ExerciseStateEntry.system(_id(id), revision: 1);
          } else {
            entry = roll < 7
                ? null
                : ExerciseStateEntry(
                    id: _id(id),
                    source: ExerciseSource.user,
                    copiedFromId: rnd.nextBool() ? _id(_ids.first) : null,
                  );
          }
          if (entry != null) entries.add(entry);
        }
        final snapshot = _snap(entries, applied: {ProviderId.repforge: 3});
        final plan = planReconciliation(release: release, snapshot: snapshot);
        final nonSystem = {
          for (final e in snapshot.exercises)
            if (!e.isSystem) e.id,
        };
        expect(
          plan.writtenExerciseIds.intersection(nonSystem),
          isEmpty,
          reason: 'seed $seed',
        );
        for (final id in plan.writtenExerciseIds) {
          final stored = snapshot.entry(id);
          expect(
            stored == null || (stored.isSystem && !stored.retired),
            isTrue,
            reason: 'seed $seed $id',
          );
        }
        for (final i in plan.inserts) {
          expect(snapshot.entry(i.id), isNull, reason: 'seed $seed');
        }
        for (final u in plan.updates) {
          expect(u.toRevision, greaterThan(u.fromRevision));
          expect(u.exercise.source, ExerciseSource.system);
        }
        if (!plan.canApply) {
          expect(plan.writtenExerciseIds, isEmpty, reason: 'seed $seed');
          expect(plan.noOps, isEmpty);
          expect(plan.relationships, isEmpty);
        } else {
          applicable++;
          // Idempotence: after applying, the same release plans no write.
          final again = planReconciliation(
            release: release,
            snapshot: applyPlan(snapshot, plan),
          );
          expect(again.canApply, isTrue, reason: 'seed $seed');
          expect(again.writesNothing, isTrue, reason: 'seed $seed');
        }
        // Deterministic.
        final twice = planReconciliation(release: release, snapshot: snapshot);
        expect(
          [for (final f in twice.refusals) f.toString()],
          [for (final f in plan.refusals) f.toString()],
        );
        expect(twice.writtenExerciseIds, plan.writtenExerciseIds);
      }
      expect(
        applicable,
        greaterThanOrEqualTo(100),
        reason:
            'the generator must produce mostly valid snapshots, or the '
            'idempotence assertion proves little',
      );
    });
  });
}
