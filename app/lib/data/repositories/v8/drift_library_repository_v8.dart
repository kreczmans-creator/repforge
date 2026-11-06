import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart' hide ExerciseNames;
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/core/search_key.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/exercise_availability.dart';
import 'package:repforge/domain/library/exercise_rules.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/training/training.dart'
    show
        ExerciseCategory,
        ExerciseType,
        PlanExercise,
        SessionExercise,
        exerciseSearchKey;
import 'package:repforge/domain/training/training_validation.dart'
    show normaliseExerciseSearch, validatePlanExercise;

/// The exercise library over schema v8 (WP 8 sub-stage 3b-8): selection,
/// reads, the new-work guards, the correction route of blocked exercises,
/// user classifications (ADR-0008 E Q14) and custom copies (Q16).
///
/// **Not connected to the app.** Only isolated tests reach it; production
/// stays on schema 7 (`AppDatabase`) and its repositories, providers, use
/// cases and screens are unchanged (D04 §7, 2026-11-06, "3B-ACC-01"). The
/// architecture test `schema_v8_isolation_test.dart` keeps
/// `lib/data/repositories/v8/` inside the isolated zone.
///
/// Rules (sources in `exercise_availability.dart`, the methods and the
/// register `docs/v8-library-use-cases.md`):
/// - [selectable] offers only discoverable exercises: never a blocked,
///   retired, archived or deleted one;
/// - [byId], [history] and [planEntries] read every exercise, whatever its
///   availability, so history stays readable;
/// - [addPlanExercise] and [addSessionExercise] (the v8 equivalents of the
///   WP 9 write paths that add an exercise to new work) refuse a blocked,
///   archived or deleted exercise and write nothing; a retired one is not
///   refused (register R-C8);
/// - [correctBlockedReason] sets the field behind a block (targets or
///   equipment) in one transaction, validated by the 3a exercise rules,
///   resolves every active reason of that field (R-C4), and never touches
///   plans, sessions, entries or sets.
final class DriftLibraryRepositoryV8 {
  DriftLibraryRepositoryV8(
    this._db, {
    required this._clock,
    required this._newId,
    required this.appVersion,
    required this.installLabel,
  });

  final AppDatabaseV8 _db;
  final Clock _clock;
  final IdGenerator _newId;

  /// Recorded on each correction run (R-08: app version is never NULL).
  final String appVersion;

  /// The device source label of a correction run (R-08 `provenance_source`).
  final String installLabel;

  // ---- Reads ---------------------------------------------------------------

  /// Exercises that selection and discovery offer, matching [query],
  /// ordered by name (ignoring case and diacritics), then id.
  ///
  /// Excluded: deleted, retired, archived and blocked exercises (any active
  /// block row, R-01), and exercises whose stored type, category or alias
  /// list the library cannot read (see [LibraryExerciseV8.exercise]). The
  /// exclusion is applied twice, independently: in SQL
  /// ([selectionCandidateIds]) and through the domain predicate
  /// [ExerciseAvailability.isDiscoverable].
  Future<List<CatalogueExercise>> selectable([
    LibrarySelectionQuery query = const LibrarySelectionQuery(),
  ]) async {
    final candidates = await _load(
      await selectionCandidateIds(includeArchived: query.includeArchived),
    );
    final reference = await _referenceData();
    final out = [
      for (final c in candidates)
        if (c.availability.discoverable(
              includeArchived: query.includeArchived,
            ) &&
            c.exercise != null)
          if (query.matches(c, reference.anatomy)) c.exercise!,
    ]..sort(_byName);
    return out;
  }

  /// The SQL half of [selectable]: ids of exercises that are not deleted,
  /// archived (unless [includeArchived]) or retired and have no unresolved
  /// block row, in id order.
  @visibleForTesting
  Future<List<String>> selectionCandidateIds({
    bool includeArchived = false,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT e.id FROM exercises e '
          'WHERE e.deleted_at IS NULL '
          '${includeArchived ? '' : 'AND e.archived = 0 '}'
          'AND e.retired_at IS NULL AND NOT EXISTS ( '
          'SELECT 1 FROM exercise_blocks b WHERE b.exercise_id = e.id '
          'AND b.resolved_at IS NULL) ORDER BY e.id',
          readsFrom: {_db.exercisesV8, _db.exerciseBlocks},
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  static int _byName(CatalogueExercise a, CatalogueExercise b) {
    final n = normaliseSearchKey(a.name).compareTo(normaliseSearchKey(b.name));
    return n != 0 ? n : a.id.compareTo(b.id);
  }

  /// The stored exercise with [id], whatever its availability (blocked,
  /// retired, archived and deleted included); null when no row exists.
  Future<LibraryExerciseV8?> byId(String id) async =>
      (await _load([id])).firstOrNull;

  /// The availability of [id]; null when no row exists.
  Future<ExerciseAvailability?> availability(String id) async =>
      (await byId(id))?.availability;

  /// Every session in which [exerciseId] has an entry or a set, with that
  /// exercise's entries and sets, oldest first (start, then id). Deleted
  /// sessions are included and flagged by their `deletedAt`; nothing is
  /// filtered by the exercise's availability.
  Future<List<ExerciseHistorySessionV8>> history(String exerciseId) async {
    final entries = await (_db.select(
      _db.sessionExercises,
    )..where((t) => t.exerciseId.equals(exerciseId))).get();
    final sets = await (_db.select(
      _db.sessionSetsV8,
    )..where((t) => t.exerciseId.equals(exerciseId))).get();
    final sessionIds = {
      for (final e in entries) e.sessionId,
      for (final s in sets) s.sessionId,
    };
    if (sessionIds.isEmpty) return const [];
    final sessions =
        await (_db.select(_db.workoutSessions)
              ..where((t) => t.id.isIn(sessionIds))
              ..orderBy([
                (t) => OrderingTerm.asc(t.startedAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [
      for (final s in sessions)
        ExerciseHistorySessionV8(
          session: s,
          entries: [
            for (final e in entries)
              if (e.sessionId == s.id) e,
          ]..sort((a, b) => a.position.compareTo(b.position)),
          sets: [
            for (final x in sets)
              if (x.sessionId == s.id) x,
          ]..sort(_setOrder),
        ),
    ];
  }

  static int _setOrder(SessionSetV8Row a, SessionSetV8Row b) {
    var c = a.exerciseOrder.compareTo(b.exerciseOrder);
    if (c != 0) return c;
    c = a.setOrder.compareTo(b.setOrder);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  /// Every plan entry that lists [exerciseId], in any plan (deleted and
  /// archived plans included), by plan then sort order.
  Future<List<PlanExerciseRow>> planEntries(String exerciseId) =>
      (_db.select(_db.planExercises)
            ..where((t) => t.exerciseId.equals(exerciseId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.planId),
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  // ---- New-work guards -----------------------------------------------------

  /// Ok with the exercise when [exerciseId] may enter new work; otherwise
  /// the refusal: [NotFoundError] for a missing or deleted exercise, a
  /// [ValidationError] on field `exerciseId` for a blocked or archived one
  /// or one the library cannot read. `fieldErrors` carries `availability`
  /// (`blocked`, `archived` or `unreadable`) and, when blocked,
  /// `blockReasons` (the active reasons, comma-separated, R-01). A retired
  /// exercise is **not** refused: retirement hides it from discovery only
  /// (ADR-0009 decision 4; owner question R-C8).
  Future<Result<LibraryExerciseV8>> requireNewWork(String exerciseId) async {
    final stored = await byId(exerciseId);
    return _newWork(stored);
  }

  static Result<LibraryExerciseV8> _newWork(LibraryExerciseV8? stored) {
    if (stored == null || stored.availability.isDeleted) {
      return const Err(NotFoundError('That exercise no longer exists.'));
    }
    final a = stored.availability;
    if (!a.canEnterNewWork) {
      // Blocked wins over archived: unarchiving never unblocks (R-01).
      final state = a.isBlocked
          ? ExerciseAvailabilityState.blocked
          : ExerciseAvailabilityState.archived;
      final message = a.isBlocked
          ? 'This exercise is blocked '
                '(${a.blockReasons.map((r) => r.name).join(', ')}) and cannot '
                'be used for new work. Its history stays readable.'
          : 'An archived exercise cannot be used. Restore it first.';
      return Err(
        ValidationError(
          message,
          field: 'exerciseId',
          fieldErrors: {
            'exerciseId': message,
            'availability': state.name,
            if (a.isBlocked)
              'blockReasons': a.blockReasons.map((r) => r.name).join(','),
          },
        ),
      );
    }
    if (stored.exercise == null) {
      const message =
          'The stored type, category or alias list of this exercise cannot be '
          'read, so it cannot be used for new work.';
      return const Err(
        ValidationError(
          message,
          field: 'exerciseId',
          fieldErrors: {'exerciseId': message, 'availability': 'unreadable'},
        ),
      );
    }
    return Ok(stored);
  }

  /// Adds [entry] to the end of plan [planId] (the v8 equivalent of the WP 9
  /// write path that adds an exercise to a plan). The exercise must be able
  /// to enter new work ([requireNewWork]) and the entry passes
  /// `validatePlanExercise` with the exercise's type, as in WP 9. The plan
  /// must exist and not be deleted. A blank entry id gets a new one; the
  /// sort order is the next free one. A refusal writes nothing; the check
  /// and the write share one transaction.
  Future<Result<PlanExercise>> addPlanExercise({
    required String planId,
    required PlanExercise entry,
  }) async {
    try {
      return await _db.transaction(() async {
        final plan =
            await (_db.select(_db.workoutPlans)
                  ..where((t) => t.id.equals(planId) & t.deletedAt.isNull()))
                .getSingleOrNull();
        if (plan == null) {
          return const Err<PlanExercise>(
            NotFoundError('That plan no longer exists.'),
          );
        }
        final usable = await requireNewWork(entry.exerciseId);
        final LibraryExerciseV8 stored;
        switch (usable) {
          case Err(:final error):
            return Err<PlanExercise>(error);
          case Ok(:final value):
            stored = value;
        }
        final siblings = await (_db.select(
          _db.planExercises,
        )..where((t) => t.planId.equals(planId))).get();
        final next = siblings.isEmpty
            ? 0
            : siblings.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b) +
                  1;
        final checked = validatePlanExercise(
          entry.copyWith(
            sortOrder: next,
            id: entry.id.isEmpty ? _newId() : entry.id,
          ),
          type: stored.exercise!.type,
        );
        if (checked case Err(:final error)) return Err<PlanExercise>(error);
        final value = (checked as Ok<PlanExercise>).value;
        await _db
            .into(_db.planExercises)
            .insert(
              PlanExercisesCompanion.insert(
                id: value.id,
                planId: planId,
                exerciseId: value.exerciseId,
                sortOrder: value.sortOrder,
                targetSets: value.targetSets,
                repsMin: Value(value.repsMin),
                repsMax: Value(value.repsMax),
                targetLoadKg: Value(value.targetLoad?.value),
                targetDurationSec: Value(value.targetDuration?.inSeconds),
                targetMetres: Value(value.targetMetres),
                restSeconds: Value(value.restSeconds),
              ),
            );
        return Ok(value);
      });
    } on Object catch (e) {
      return Err(StorageError('Could not save the plan.', cause: e));
    }
  }

  /// Adds [exerciseId] as a new entry at the end of session [sessionId] (the
  /// v8 equivalent of WP 9 `AddSessionExercise`). The session must exist and
  /// not be deleted; the exercise must be able to enter new work. A refusal
  /// writes nothing; the check and the write share one transaction.
  Future<Result<SessionExercise>> addSessionExercise({
    required String sessionId,
    required String exerciseId,
    String? note,
  }) async {
    try {
      return await _db.transaction(() async {
        final session =
            await (_db.select(_db.workoutSessions)
                  ..where((t) => t.id.equals(sessionId) & t.deletedAt.isNull()))
                .getSingleOrNull();
        if (session == null) {
          return const Err<SessionExercise>(
            NotFoundError('That session no longer exists.'),
          );
        }
        final usable = await requireNewWork(exerciseId);
        if (usable case Err(:final error)) {
          return Err<SessionExercise>(error);
        }
        final entries = await (_db.select(
          _db.sessionExercises,
        )..where((t) => t.sessionId.equals(sessionId))).get();
        final position = entries.isEmpty
            ? 0
            : entries.map((e) => e.position).reduce((a, b) => a > b ? a : b) +
                  1;
        final entry = SessionExercise(
          id: _newId(),
          sessionId: sessionId,
          exerciseId: exerciseId,
          position: position,
          note: note,
        );
        await _db
            .into(_db.sessionExercises)
            .insert(
              SessionExercisesCompanion.insert(
                id: entry.id,
                sessionId: sessionId,
                position: position,
                exerciseId: exerciseId,
                note: Value(note),
              ),
            );
        return Ok(entry);
      });
    } on Object catch (e) {
      return Err(StorageError('Could not save the session.', cause: e));
    }
  }

  // ---- Correction route ----------------------------------------------------

  /// Corrects the field behind the active block [reason] of [exerciseId]
  /// with [fix], in one transaction (D04 §7, 2026-11-06: "Provide a route to
  /// correct the record later without rewriting historical sessions"; R-01).
  ///
  /// - The exercise must be a `user` or `imported` exercise. A blocked
  ///   `system` exercise has no route in stage 3b: system content is
  ///   read-only for users and only a catalogue release writes it (ADR-0009
  ///   decision 4 and rationale); how a release clears a block is a stage 3c
  ///   requirement (register R-C9).
  /// - [reason] must be active. Its field takes the matching fix:
  ///   `noPrimaryTarget` → [SetTargetsCorrection]; `unknownEquipment` and
  ///   `invalidEquipment` → [SetEquipmentCorrection]. `invalidSecondaryTarget`
  ///   has no route (register R-C3).
  /// - The fix **sets the whole field**: the given list replaces the stored
  ///   one (rows deleted and inserted in this transaction, as register R-29
  ///   prescribes for reordering). Targets are stored primaries first, then
  ///   secondaries, each group in the given order, ordinals contiguous from 0
  ///   (IC-309), so a kept secondary can become the primary. The equipment
  ///   list may be **empty**: an exercise that needs no item has no rows
  ///   (`equipment.md` section 1 rule 2), which corrects a legacy
  ///   `"bodyweight"` or `"None"` faithfully. Nothing is inferred.
  /// - The corrected exercise is checked with the 3a rules
  ///   (`validateExercise`): no error-severity finding may remain on the
  ///   corrected field (`targets`: IC-204 at least one primary, IC-301 to
  ///   IC-305, IC-309; `equipment`: IC-307, IC-315 including Q6). Findings on
  ///   untouched fields are not this correction's concern (register C-5).
  /// - Every active reason tied to the corrected field is resolved
  ///   ([BlockedField]; register R-C4); a reason of another field keeps the
  ///   exercise blocked (R-01).
  /// - Writes: the field's rows, `resolved_at` of the resolved block rows,
  ///   `updated_at` of the exercise, and one report run with one entry per
  ///   resolved reason, recording the field's value before and after (R-06),
  ///   and its counts ([CorrectionReportContract], **provisional, owner
  ///   decision C-1**). Plans, sessions, entries and sets are never touched.
  /// - Any refusal or failure writes nothing.
  Future<Result<BlockCorrectionOutcome>> correctBlockedReason(
    String exerciseId,
    BlockReason reason,
    BlockCorrection fix,
  ) async {
    try {
      return await _db.transaction(() async {
        final stored = await byId(exerciseId);
        if (stored == null || stored.availability.isDeleted) {
          return const Err<BlockCorrectionOutcome>(
            NotFoundError('That exercise no longer exists.'),
          );
        }
        final current = stored.exercise;
        if (current == null) {
          return const Err<BlockCorrectionOutcome>(
            ValidationError(
              'The stored type, category or alias list of this exercise '
              'cannot be read; it cannot be corrected here.',
              field: 'exerciseId',
            ),
          );
        }
        if (current.isSystem) {
          return const Err<BlockCorrectionOutcome>(
            ValidationError(
              'A system exercise is corrected by a catalogue release, not by '
              'the user.',
              field: 'source',
            ),
          );
        }
        if (!stored.availability.blockReasons.contains(reason)) {
          final wasBlocked = stored.availability.blocks.any(
            (b) => b.reason == reason,
          );
          return Err<BlockCorrectionOutcome>(
            ValidationError(
              wasBlocked
                  ? 'The block ${reason.name} is already resolved.'
                  : 'The exercise is not blocked for ${reason.name}.',
              field: 'reason',
            ),
          );
        }
        final field = BlockedField.of(reason);
        if (field == null) {
          return Err<BlockCorrectionOutcome>(
            ValidationError(
              'The block reason ${reason.name} has no correction route.',
              field: 'reason',
            ),
          );
        }
        final CatalogueExercise corrected;
        switch ((field, fix)) {
          case (BlockedField.targets, SetTargetsCorrection(:final targets)):
            final ordered = [
              for (final t in targets)
                if (t.role == TargetRole.primary) t,
              for (final t in targets)
                if (t.role != TargetRole.primary) t,
            ];
            corrected = current.copyWith(
              targets: [
                for (var i = 0; i < ordered.length; i++)
                  ExerciseTarget(
                    node: ordered[i].node,
                    role: ordered[i].role,
                    ordinal: i,
                  ),
              ],
            );
          case (BlockedField.equipment, SetEquipmentCorrection(:final items)):
            corrected = current.copyWith(equipment: items);
          default:
            return Err<BlockCorrectionOutcome>(
              ValidationError(
                'A ${fix.runtimeType} does not correct the block '
                '${reason.name}.',
                field: 'fix',
              ),
            );
        }
        final ctx = await _ruleContext();
        final problems = _errorsOn(validateExercise(corrected, ctx), {
          field.name,
        });
        if (problems != null) return Err<BlockCorrectionOutcome>(problems);

        final now = _clock.now().toUtc();
        final resolution = resolveField(stored.availability.blocks, field, now);
        if (field == BlockedField.targets) {
          await (_db.delete(
            _db.exerciseTargets,
          )..where((t) => t.exerciseId.equals(exerciseId))).go();
          await _insertTargets(exerciseId, corrected.targets);
        } else {
          await (_db.delete(
            _db.exerciseEquipmentLinks,
          )..where((t) => t.exerciseId.equals(exerciseId))).go();
          await _insertEquipment(
            exerciseId,
            corrected.equipment,
            firstOrdinal: 0,
          );
        }
        for (final r in resolution.resolved) {
          final changed =
              await (_db.update(_db.exerciseBlocks)..where(
                    (t) =>
                        t.exerciseId.equals(exerciseId) &
                        t.reason.equals(r.name) &
                        t.resolvedAt.isNull(),
                  ))
                  .write(ExerciseBlocksCompanion(resolvedAt: Value(now)));
          if (changed != 1) {
            throw StateError('block $exerciseId/${r.name} changed');
          }
        }
        await (_db.update(_db.exercisesV8)
              ..where((t) => t.id.equals(exerciseId)))
            .write(ExercisesV8Companion(updatedAt: Value(now)));

        final before = field == BlockedField.targets
            ? _targetsJson(current.targets)
            : _equipmentJson(current.equipment);
        final after = field == BlockedField.targets
            ? _targetsJson(corrected.targets)
            : _equipmentJson(corrected.equipment);
        final events = [
          for (final r in BlockReason.values)
            if (resolution.resolved.contains(r))
              ReportEvent(
                table: CorrectionReportContract.table,
                recordId: exerciseId,
                field: field.name,
                originalValue: encodeStoredValue(before),
                resultingValue: encodeStoredValue(after),
                action: CorrectionReportContract.action,
                rule: CorrectionReportContract.ruleFor(r)!,
                category: CorrectionReportContract.category,
                reason:
                    'The block ${r.name} was resolved by a user correction '
                    'of ${field.name}; historical sessions are unchanged.',
              ),
        ];
        final runId = CorrectionReportContract.runIdFor(_newId());
        final eventIds = await _writeCorrectionRun(
          runId,
          now,
          exerciseId,
          events,
        );
        final afterRow = await byId(exerciseId);
        return Ok(
          BlockCorrectionOutcome(
            exercise: afterRow!,
            resolved: resolution.resolved,
            runId: runId,
            eventIds: eventIds,
          ),
        );
      });
    } on Object catch (e) {
      return Err(StorageError('Could not correct the exercise.', cause: e));
    }
  }

  Future<List<String>> _writeCorrectionRun(
    String runId,
    DateTime at,
    String exerciseId,
    List<ReportEvent> events,
  ) async {
    final builder =
        MigrationReportBuilder(
          ReportRun(
            runId: runId,
            trigger: CorrectionReportContract.trigger,
            generatedAt: at,
            appVersion: appVersion,
          ),
        )..examine(
          table: CorrectionReportContract.table,
          recordId: exerciseId,
          cleanOutcome: ReportCategory.migrated,
          events: events,
        );
    final report = builder.build();
    await _db
        .into(_db.migrationRuns)
        .insert(
          MigrationRunsCompanion.insert(
            id: runId,
            triggerKind: CorrectionReportContract.trigger.name,
            generatedAt: at,
            appVersion: appVersion,
            provenanceKind: 'device',
            provenanceSource: installLabel,
          ),
        );
    for (final entry in report.entries) {
      final e = entry.event;
      await _db
          .into(_db.migrationReportEntries)
          .insert(
            MigrationReportEntriesCompanion.insert(
              eventId: entry.eventId,
              runId: runId,
              sourceTable: e.table,
              recordId: e.recordId,
              exerciseId: Value(exerciseId),
              field: e.field,
              position: Value(e.position),
              originalValue: e.originalValue,
              resultingValue: e.resultingValue ?? encodeStoredValue(null),
              element: Value(e.element),
              disposition: e.action.name,
              blockReason: Value(e.blockReason?.name),
              rule: e.rule,
              reason: e.reason,
              category: e.category.code,
            ),
          );
    }
    for (final c in report.counts.values) {
      final rows = <(String, String, int)>[
        ('category', 'examined', c.examined),
        for (final o in ReportCategory.outcomes)
          ('category', o.code, c.count(o)),
        (
          'category',
          ReportCategory.warningForReview.code,
          c.recordsWithWarnings,
        ),
        for (final a in ReportAction.values)
          ('disposition', a.name, c.entries(a)),
      ];
      for (final (dimension, code, n) in rows) {
        await _db
            .into(_db.migrationReportCounts)
            .insert(
              MigrationReportCountsCompanion.insert(
                runId: runId,
                sourceTable: c.table,
                dimension: dimension,
                code: code,
                recordCount: n,
              ),
            );
      }
    }
    return [for (final e in report.entries) e.eventId];
  }

  static String _targetsJson(List<ExerciseTarget> targets) => jsonEncode([
    for (final t in targets)
      {'node': t.node.value, 'role': t.role.name, 'ordinal': t.ordinal},
  ]);

  static String _equipmentJson(List<ExerciseEquipment> equipment) =>
      jsonEncode([
        for (final e in equipment)
          {
            'item': e.item.value,
            'roleOverride': e.roleOverride?.name,
            'overrideNote': e.overrideNote,
          },
      ]);

  // ---- User classifications (ADR-0008 E Q14) -------------------------------

  /// Sets attributes and equipment role overrides of a `user` or `imported`
  /// exercise under the same value, role and note checks as system content
  /// (ADR-0008 section E, Q14; IC-316, IC-315 with Q6; R-22: a note without
  /// an override is allowed).
  ///
  /// [attributes]: a key with a value sets it; a key with null clears it;
  /// an absent key keeps it. [equipmentRoles]: the override and note of an
  /// item already linked to the exercise (an item not in its list is
  /// refused, IC-315). A system exercise is refused (ADR-0009: users edit a
  /// copy). Any error on `attributes` or `equipment` refuses the whole
  /// change; nothing is written. Availability is unchanged: this never
  /// resolves a block.
  Future<Result<CatalogueExercise>> setUserClassification(
    String exerciseId, {
    Map<ExerciseAttribute, String?> attributes = const {},
    Map<EquipmentItemId, EquipmentRoleChange> equipmentRoles = const {},
  }) async {
    try {
      return await _db.transaction(() async {
        final stored = await byId(exerciseId);
        if (stored == null || stored.availability.isDeleted) {
          return const Err<CatalogueExercise>(
            NotFoundError('That exercise no longer exists.'),
          );
        }
        final current = stored.exercise;
        if (current == null) {
          return const Err<CatalogueExercise>(
            ValidationError(
              'The stored type, category or alias list of this exercise '
              'cannot be read.',
              field: 'exerciseId',
            ),
          );
        }
        if (current.isSystem) {
          return const Err<CatalogueExercise>(
            ValidationError(
              'A system exercise cannot be edited; edit a custom copy.',
              field: 'source',
            ),
          );
        }
        final linked = {for (final e in current.equipment) e.item};
        for (final item in equipmentRoles.keys) {
          if (!linked.contains(item)) {
            return Err<CatalogueExercise>(
              ValidationError(
                'The override names $item, which is not in the equipment '
                'list of the exercise (IC-315).',
                field: 'equipment',
                fieldErrors: {
                  'IC-315:equipment':
                      'The override names $item, which is '
                      'not in the equipment list of the exercise.',
                },
              ),
            );
          }
        }
        final nextAttributes = {...current.attributes};
        for (final MapEntry(:key, :value) in attributes.entries) {
          if (value == null) {
            nextAttributes.remove(key);
          } else {
            nextAttributes[key] = value;
          }
        }
        final next = current.copyWith(
          attributes: nextAttributes,
          equipment: [
            for (final e in current.equipment)
              if (equipmentRoles[e.item] case final change?)
                ExerciseEquipment(
                  e.item,
                  roleOverride: change.role,
                  overrideNote: change.note,
                )
              else
                e,
          ],
        );
        final ctx = await _ruleContext();
        final problems = _errorsOn(validateExercise(next, ctx), {
          'attributes',
          'equipment',
        });
        if (problems != null) return Err<CatalogueExercise>(problems);
        final now = _clock.now().toUtc();
        String? attr(ExerciseAttribute a) => next.attributes[a];
        await (_db.update(
          _db.exercisesV8,
        )..where((t) => t.id.equals(exerciseId))).write(
          ExercisesV8Companion(
            angle: Value(attr(ExerciseAttribute.angle)),
            armPosition: Value(attr(ExerciseAttribute.armPosition)),
            bodyPosition: Value(attr(ExerciseAttribute.bodyPosition)),
            grip: Value(attr(ExerciseAttribute.grip)),
            gripWidth: Value(attr(ExerciseAttribute.gripWidth)),
            kneePosition: Value(attr(ExerciseAttribute.kneePosition)),
            stance: Value(attr(ExerciseAttribute.stance)),
            updatedAt: Value(now),
          ),
        );
        for (final MapEntry(key: item, value: change)
            in equipmentRoles.entries) {
          await (_db.update(_db.exerciseEquipmentLinks)..where(
                (t) =>
                    t.exerciseId.equals(exerciseId) &
                    t.equipmentId.equals(item.value),
              ))
              .write(
                ExerciseEquipmentLinksCompanion(
                  roleOverride: Value(change.role?.name),
                  overrideNote: Value(change.note),
                ),
              );
        }
        return Ok((await byId(exerciseId))!.exercise!);
      });
    } on Object catch (e) {
      return Err(StorageError('Could not update the exercise.', cause: e));
    }
  }

  // ---- Custom copies (ADR-0008 E Q16) --------------------------------------

  /// Creates the custom copy of the system exercise [sourceId] (WP 9 rule:
  /// only a supplied, now `system`, exercise is copied; edit your own
  /// directly).
  ///
  /// The copy is a new `user` exercise with a new id, `copied_from_id` =
  /// [sourceId], no provider and no revision. It takes **values**, never
  /// shared associations (ADR-0008 section E, Q16; plan section 8): name
  /// ([name] or the source's), aliases, type, category, mechanics,
  /// laterality, difficulty, the seven attributes, the targets, the
  /// patterns and the equipment links with their role overrides and notes,
  /// each as its own new row. User state and other-locale names are not
  /// copied. A blocked source is refused: its copy would make the exercise
  /// newly visible (ADR-0008 E Q12). The copy is checked with the 3a rules
  /// for user content; an error refuses it and nothing is written.
  Future<Result<CatalogueExercise>> createCustomCopy(
    String sourceId, {
    String? name,
  }) async {
    try {
      return await _db.transaction(() async {
        final stored = await byId(sourceId);
        if (stored == null || stored.availability.isDeleted) {
          return const Err<CatalogueExercise>(
            NotFoundError('That exercise no longer exists.'),
          );
        }
        final source = stored.exercise;
        if (source == null || !source.isSystem) {
          return const Err<CatalogueExercise>(
            ValidationError(
              'Only a system exercise is copied; edit your own directly.',
              field: 'id',
            ),
          );
        }
        if (stored.availability.isBlocked) {
          final reasons = stored.availability.blockReasons
              .map((r) => r.name)
              .join(', ');
          return Err<CatalogueExercise>(
            ValidationError(
              'A blocked exercise cannot be copied ($reasons).',
              field: 'id',
              fieldErrors: {'availability': 'blocked'},
            ),
          );
        }
        final now = _clock.now().toUtc();
        final copyName = (name ?? source.name).trim();
        final copy = CatalogueExercise(
          id: ExerciseId(_newId()),
          names: ExerciseNames.english(copyName, aliases: source.aliases),
          type: source.type,
          category: source.category,
          source: ExerciseSource.user,
          createdAt: now,
          updatedAt: now,
          targets: [
            for (final t in source.targets)
              ExerciseTarget(node: t.node, role: t.role, ordinal: t.ordinal),
          ],
          patterns: [...source.patterns],
          equipment: [
            for (final e in source.equipment)
              ExerciseEquipment(
                e.item,
                roleOverride: e.roleOverride,
                overrideNote: e.overrideNote,
              ),
          ],
          mechanics: source.mechanics,
          laterality: source.laterality,
          difficulty: source.difficulty,
          attributes: {...source.attributes},
          copiedFromId: source.id,
        );
        final ctx = await _ruleContext();
        final problems = _errorsOn(validateExercise(copy, ctx), null);
        if (problems != null) return Err<CatalogueExercise>(problems);
        String? attr(ExerciseAttribute a) => copy.attributes[a];
        await _db
            .into(_db.exercisesV8)
            .insert(
              ExercisesV8Companion.insert(
                id: copy.id.value,
                createdAt: now,
                updatedAt: now,
                name: copyName,
                type: copy.type.name,
                category: copy.category.name,
                aliasesJson: Value(jsonEncode(copy.aliases)),
                searchKey: Value(exerciseSearchKey(copyName, copy.aliases)),
                copiedFromId: Value(source.id.value),
                source: ExerciseSource.user.name,
                mechanics: Value(copy.mechanics?.name),
                laterality: Value(copy.laterality?.name),
                difficulty: Value(copy.difficulty?.name),
                angle: Value(attr(ExerciseAttribute.angle)),
                armPosition: Value(attr(ExerciseAttribute.armPosition)),
                bodyPosition: Value(attr(ExerciseAttribute.bodyPosition)),
                grip: Value(attr(ExerciseAttribute.grip)),
                gripWidth: Value(attr(ExerciseAttribute.gripWidth)),
                kneePosition: Value(attr(ExerciseAttribute.kneePosition)),
                stance: Value(attr(ExerciseAttribute.stance)),
              ),
            );
        await _insertTargets(copy.id.value, copy.targets);
        for (var i = 0; i < copy.patterns.length; i++) {
          await _db
              .into(_db.exercisePatterns)
              .insert(
                ExercisePatternsCompanion.insert(
                  exerciseId: copy.id.value,
                  patternId: copy.patterns[i].value,
                  ordinal: i,
                ),
              );
        }
        await _insertEquipment(copy.id.value, copy.equipment, firstOrdinal: 0);
        return Ok((await byId(copy.id.value))!.exercise!);
      });
    } on Object catch (e) {
      return Err(StorageError('Could not copy the exercise.', cause: e));
    }
  }

  // ---- Writing helpers -----------------------------------------------------

  Future<void> _insertTargets(
    String exerciseId,
    Iterable<ExerciseTarget> targets,
  ) async {
    for (final t in targets) {
      await _db
          .into(_db.exerciseTargets)
          .insert(
            ExerciseTargetsCompanion.insert(
              exerciseId: exerciseId,
              nodeId: t.node.value,
              role: t.role.name,
              ordinal: t.ordinal,
            ),
          );
    }
  }

  Future<void> _insertEquipment(
    String exerciseId,
    Iterable<ExerciseEquipment> items, {
    required int firstOrdinal,
  }) async {
    var ordinal = firstOrdinal;
    for (final e in items) {
      await _db
          .into(_db.exerciseEquipmentLinks)
          .insert(
            ExerciseEquipmentLinksCompanion.insert(
              exerciseId: exerciseId,
              equipmentId: e.item.value,
              ordinal: ordinal++,
              roleOverride: Value(e.roleOverride?.name),
              overrideNote: Value(e.overrideNote),
            ),
          );
    }
  }

  /// A [ValidationError] for the error-severity findings of [findings] on
  /// [fields] (every field when null); null when there is none. The
  /// `fieldErrors` keys are `code:field`, as `requireValidExercise` builds
  /// them.
  static ValidationError? _errorsOn(
    List<Finding> findings,
    Set<String>? fields,
  ) {
    final errors = [
      for (final f in findings)
        if (f.severity == Severity.error &&
            (fields == null || fields.contains(f.field)))
          f,
    ];
    if (errors.isEmpty) return null;
    final fieldErrors = <String, String>{};
    for (final x in errors) {
      fieldErrors.update(
        '${x.code}:${x.field ?? ''}',
        (m) => '$m ${x.message}',
        ifAbsent: () => x.message,
      );
    }
    return ValidationError(
      errors.first.message,
      field: errors.first.field,
      fieldErrors: fieldErrors,
    );
  }

  // ---- Loading -------------------------------------------------------------

  /// The reference data stored in v8, for the 3a rules. Reference lifecycle
  /// waits for stage 3c (R-21), so every row is active. Labels are not
  /// read (the rules do not use them). v8 stores no equipment class (owner
  /// decision Q11, stage 3c): the domain type needs one, so the items carry
  /// [EquipmentClass.other] as an inert placeholder; `validateExercise` never
  /// reads the class. This reference data is private to the rule checks
  /// here and is never returned.
  Future<ReferenceData> _referenceData() async {
    final nodes = await _db.select(_db.anatomyNodes).get();
    final patterns = await _db.select(_db.movementPatterns).get();
    final items = await _db.select(_db.equipmentItems).get();
    return ReferenceData(
      anatomy: AnatomyTree([
        for (final n in nodes)
          AnatomyNode(
            id: AnatomyNodeId(n.id),
            parentId: n.parentId == null ? null : AnatomyNodeId(n.parentId!),
            level: n.level,
            sort: n.sortOrder,
            labels: const {},
            nonAnatomical: n.nonAnatomical,
            providerId: ProviderId(n.providerId),
          ),
      ]),
      patterns: PatternTree([
        for (final p in patterns)
          MovementPattern(
            id: MovementPatternId(p.id),
            parentId: p.parentId == null
                ? null
                : MovementPatternId(p.parentId!),
            level: p.parentId == null ? 1 : 2,
            sort: p.sortOrder,
            labels: const {},
            providerId: ProviderId(p.providerId),
          ),
      ]),
      equipment: EquipmentCatalogue([
        for (final i in items)
          EquipmentItem(
            id: EquipmentItemId(i.id),
            sort: i.sortOrder,
            labels: const {},
            equipmentClass: EquipmentClass.other,
            defaultRole: _defaultRole(i.defaultRole),
            providerId: ProviderId(i.providerId),
          ),
      ]),
    );
  }

  static EquipmentDefaultRole _defaultRole(String stored) =>
      enumByName(EquipmentDefaultRole.values, stored) ??
      (throw StateError('equipment default role $stored'));

  Future<ExerciseRuleContext> _ruleContext() async {
    final providers = await _db.select(_db.contentProviders).get();
    return ExerciseRuleContext(
      reference: await _referenceData(),
      providers: {for (final p in providers) ProviderId(p.id)},
    );
  }

  Future<List<LibraryExerciseV8>> _load(List<String> ids) async {
    if (ids.isEmpty) return const [];
    // Large selections read the child tables whole instead of binding
    // thousands of parameters.
    final all = ids.length > 500;
    final rows = all
        ? await _db.select(_db.exercisesV8).get()
        : await (_db.select(
            _db.exercisesV8,
          )..where((t) => t.id.isIn(ids))).get();
    final wanted = ids.toSet();
    final targets = await (all
        ? _db.select(_db.exerciseTargets).get()
        : (_db.select(
            _db.exerciseTargets,
          )..where((t) => t.exerciseId.isIn(ids))).get());
    final patterns = await (all
        ? _db.select(_db.exercisePatterns).get()
        : (_db.select(
            _db.exercisePatterns,
          )..where((t) => t.exerciseId.isIn(ids))).get());
    final equipment = await (all
        ? _db.select(_db.exerciseEquipmentLinks).get()
        : (_db.select(
            _db.exerciseEquipmentLinks,
          )..where((t) => t.exerciseId.isIn(ids))).get());
    final names = await (all
        ? _db.select(_db.exerciseNames).get()
        : (_db.select(
            _db.exerciseNames,
          )..where((t) => t.exerciseId.isIn(ids))).get());
    final blocks = await (all
        ? _db.select(_db.exerciseBlocks).get()
        : (_db.select(
            _db.exerciseBlocks,
          )..where((t) => t.exerciseId.isIn(ids))).get());
    Map<String, List<T>> group<T>(List<T> list, String Function(T) key) {
      final out = <String, List<T>>{};
      for (final x in list) {
        out.putIfAbsent(key(x), () => []).add(x);
      }
      return out;
    }

    final targetsBy = group(targets, (t) => t.exerciseId);
    final patternsBy = group(patterns, (p) => p.exerciseId);
    final equipmentBy = group(equipment, (e) => e.exerciseId);
    final namesBy = group(names, (n) => n.exerciseId);
    final blocksBy = group(blocks, (b) => b.exerciseId);
    final byId = {
      for (final r in rows)
        if (wanted.contains(r.id))
          r.id: _toStored(
            r,
            targetsBy[r.id] ?? const [],
            patternsBy[r.id] ?? const [],
            equipmentBy[r.id] ?? const [],
            namesBy[r.id] ?? const [],
            blocksBy[r.id] ?? const [],
          ),
    };
    return [for (final id in ids) ?byId[id]];
  }

  static LibraryExerciseV8 _toStored(
    ExerciseV8Row r,
    List<ExerciseTargetRow> targets,
    List<ExercisePatternRow> patterns,
    List<ExerciseEquipmentRow> equipment,
    List<ExerciseNameRow> names,
    List<ExerciseBlockRow> blocks,
  ) {
    final availability = ExerciseAvailability(
      exerciseId: r.id,
      blocks: [
        for (final b in blocks)
          ExerciseBlock(
            reason:
                enumByName(BlockReason.values, b.reason) ??
                (throw StateError('block reason ${b.reason}')),
            blockedAt: b.blockedAt,
            resolvedAt: b.resolvedAt,
          ),
      ],
      archived: r.archived,
      retiredAt: r.retiredAt,
      deletedAt: r.deletedAt,
    );
    final source =
        enumByName(ExerciseSource.values, r.source) ??
        (throw StateError('source ${r.source}'));
    final type = enumByName(ExerciseType.values, r.type);
    final category = enumByName(ExerciseCategory.values, r.category);
    final aliases = _stringList(r.aliasesJson);
    CatalogueExercise? exercise;
    if (type != null && category != null && aliases != null) {
      final sortedTargets = [...targets]
        ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
      final sortedPatterns = [...patterns]
        ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
      final sortedEquipment = [...equipment]
        ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
      exercise = CatalogueExercise(
        id: ExerciseId(r.id),
        names: ExerciseNames({
          canonicalLocale: LocalizedName(r.name, aliases: aliases),
          for (final n in names)
            n.locale: LocalizedName(
              n.name,
              aliases: _stringList(n.aliasesJson) ?? const [],
            ),
        }),
        type: type,
        category: category,
        source: source,
        providerId: r.providerId == null ? null : ProviderId(r.providerId!),
        revision: r.revision,
        targets: [
          for (final t in sortedTargets)
            ExerciseTarget(
              node: AnatomyNodeId(t.nodeId),
              role:
                  enumByName(TargetRole.values, t.role) ??
                  (throw StateError('target role ${t.role}')),
              ordinal: t.ordinal,
            ),
        ],
        patterns: [
          for (final p in sortedPatterns) MovementPatternId(p.patternId),
        ],
        equipment: [
          for (final e in sortedEquipment)
            ExerciseEquipment(
              EquipmentItemId(e.equipmentId),
              roleOverride: enumByName(EquipmentRole.values, e.roleOverride),
              overrideNote: e.overrideNote,
            ),
        ],
        mechanics: enumByName(Mechanics.values, r.mechanics),
        laterality: enumByName(Laterality.values, r.laterality),
        difficulty: enumByName(Difficulty.values, r.difficulty),
        attributes: {
          ExerciseAttribute.angle: ?r.angle,
          ExerciseAttribute.armPosition: ?r.armPosition,
          ExerciseAttribute.bodyPosition: ?r.bodyPosition,
          ExerciseAttribute.grip: ?r.grip,
          ExerciseAttribute.gripWidth: ?r.gripWidth,
          ExerciseAttribute.kneePosition: ?r.kneePosition,
          ExerciseAttribute.stance: ?r.stance,
        },
        retiredAt: r.retiredAt,
        copiedFromId: r.copiedFromId == null
            ? null
            : ExerciseId(r.copiedFromId!),
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );
    }
    return LibraryExerciseV8(
      id: r.id,
      name: r.name,
      storedType: r.type,
      storedCategory: r.category,
      source: source,
      searchKey: r.searchKey,
      availability: availability,
      exercise: exercise,
    );
  }

  static List<String>? _stringList(String json) {
    try {
      final v = jsonDecode(json);
      if (v is! List) return null;
      final out = <String>[];
      for (final x in v) {
        if (x is! String) return null;
        out.add(x);
      }
      return out;
    } on FormatException {
      return null;
    }
  }
}

/// A stored exercise as the v8 library reads it, whatever its availability.
final class LibraryExerciseV8 {
  const LibraryExerciseV8({
    required this.id,
    required this.name,
    required this.storedType,
    required this.storedCategory,
    required this.source,
    required this.searchKey,
    required this.availability,
    required this.exercise,
  });

  /// Stable id.
  final String id;

  /// The en-GB name as stored.
  final String name;

  /// `type` and `category` exactly as stored.
  final String storedType;
  final String storedCategory;
  final ExerciseSource source;

  /// The stored search key (name and aliases, normalised).
  final String searchKey;
  final ExerciseAvailability availability;

  /// The domain exercise; null when the stored `type`, `category` or
  /// `aliases_json` is not a known identifier or a JSON list of strings.
  /// v7 hides such an exercise; whether v8 blocks it is open (WS4 review L9,
  /// owner). It is never selectable and is refused by the guards, but it
  /// is still read by id and its history stays readable.
  final CatalogueExercise? exercise;
}

/// One session in the history of an exercise: the session row, the
/// exercise's entries in it and its sets in it, as stored.
final class ExerciseHistorySessionV8 {
  const ExerciseHistorySessionV8({
    required this.session,
    required this.entries,
    required this.sets,
  });

  final WorkoutSessionRow session;
  final List<SessionExerciseRow> entries;
  final List<SessionSetV8Row> sets;
}

/// Filter of [DriftLibraryRepositoryV8.selectable]. Every field is
/// optional; an unset field does not filter.
final class LibrarySelectionQuery {
  const LibrarySelectionQuery({
    this.text = '',
    this.category,
    this.type,
    this.target,
    this.availableEquipment,
    this.sources,
    this.includeArchived = false,
  });

  /// Every word must occur in the stored search key (name and aliases,
  /// ignoring case and diacritics; TRN-008(3)).
  final String text;
  final ExerciseCategory? category;
  final ExerciseType? type;

  /// A primary or secondary target at this node or below it (TRN-010(2):
  /// filtering by a node includes its descendants).
  final AnatomyNodeId? target;

  /// Equipment the user has: every listed item of the exercise must be in
  /// it, support items included (`equipment.md` section 1 rule 2); an
  /// exercise with no equipment always passes.
  final Set<EquipmentItemId>? availableEquipment;
  final Set<ExerciseSource>? sources;

  /// Also offer archived exercises (WP 9 history views, TRN-012(2)); never
  /// blocked, retired or deleted ones.
  final bool includeArchived;

  bool matches(LibraryExerciseV8 stored, AnatomyTree anatomy) {
    final e = stored.exercise;
    if (e == null) return false;
    if (category != null && e.category != category) return false;
    if (type != null && e.type != type) return false;
    if (sources != null && !sources!.contains(e.source)) return false;
    final node = target;
    if (node != null) {
      final wanted = anatomy.selfAndDescendantIds(node);
      if (!e.targets.any((t) => wanted.contains(t.node))) return false;
    }
    final available = availableEquipment;
    if (available != null &&
        !e.equipment.every((x) => available.contains(x.item))) {
      return false;
    }
    final tokens = normaliseExerciseSearch(text);
    if (tokens.isNotEmpty) {
      for (final token in tokens.split(' ')) {
        if (!stored.searchKey.contains(token)) return false;
      }
    }
    return true;
  }
}

/// A fix for the field behind a block reason (see
/// [DriftLibraryRepositoryV8.correctBlockedReason]). Each fix sets the whole
/// field.
sealed class BlockCorrection {
  const BlockCorrection();
}

/// Sets the full target list (for `noPrimaryTarget`). Stored primaries
/// first, then secondaries, each group in the given order, ordinals
/// contiguous from 0 (IC-309); a kept secondary can become the primary.
final class SetTargetsCorrection extends BlockCorrection {
  const SetTargetsCorrection(this.targets);

  final List<({AnatomyNodeId node, TargetRole role})> targets;
}

/// Sets the full equipment list (for `unknownEquipment` and
/// `invalidEquipment`), with optional role overrides and notes (IC-315).
/// The list may be empty: an exercise that needs no item has none
/// (`equipment.md` section 1 rule 2).
final class SetEquipmentCorrection extends BlockCorrection {
  const SetEquipmentCorrection(this.items);

  final List<ExerciseEquipment> items;
}

/// The result of a correction: the exercise after it, the reasons resolved
/// (every active reason of the corrected field, R-C4), and the report run
/// and entries (one per resolved reason) that record it.
final class BlockCorrectionOutcome {
  const BlockCorrectionOutcome({
    required this.exercise,
    required this.resolved,
    required this.runId,
    required this.eventIds,
  });

  final LibraryExerciseV8 exercise;
  final Set<BlockReason> resolved;
  final String runId;
  final List<String> eventIds;

  /// True when another reason keeps the exercise blocked (R-01).
  bool get stillBlocked => exercise.availability.isBlocked;
}

/// A role override and note for an item already linked to a user exercise
/// (ADR-0008 E Q14). A null [role] removes the override; a note without an
/// override is allowed (R-22).
final class EquipmentRoleChange {
  const EquipmentRoleChange({this.role, this.note});

  final EquipmentRole? role;
  final String? note;
}

/// How a correction is recorded in the migration report.
///
/// **PROVISIONAL — owner decision required (register C-1 in
/// `docs/v8-library-use-cases.md`). Not a decided contract.** The approved
/// report vocabulary (`quality-and-duplicates.md` section 4.2, R-03, R-05;
/// the `migration_runs` and `migration_report_entries` CHECKs) has no
/// trigger and no action for a user correction. Until the owner decides, a
/// correction is written inside the existing vocabulary, so nothing in the
/// schema changes:
/// - its own run per correction (`correction:<id>`), trigger
///   `integrityCheck`, provenance `device`, so the migration run that
///   blocked the exercise is never changed;
/// - one entry per resolved reason: table `exercises`, record and exercise
///   = the exercise, field `targets` or `equipment`, action `mapped`,
///   category `migrated` (an allowed pair, `ReportEvent.allowedCategories`),
///   rule = the rule of that reason's block entry (IC-204, ADR-0008-Q12 or
///   R-02, so the event ids differ), `original_value` and `resulting_value`
///   = the whole field before and after, as JSON text (R-06);
/// - counts for that table in both dimensions, as the migration writes
///   them, so the run reconciles (R-04).
/// A different decision (for example a new trigger `correction` or action
/// `corrected`) is a schema and report-contract change; only this class and
/// its tests change with it.
abstract final class CorrectionReportContract {
  static const ReportTrigger trigger = ReportTrigger.integrityCheck;
  static const ReportAction action = ReportAction.mapped;
  static const ReportCategory category = ReportCategory.migrated;
  static const String table = 'exercises';

  static String runIdFor(String id) => 'correction:$id';

  /// The rule cited by the block entry of [reason]; null for a reason v8
  /// does not store.
  static String? ruleFor(BlockReason reason) => switch (reason) {
    BlockReason.noPrimaryTarget => MigrationRuleCodes.noPrimaryTarget,
    BlockReason.unknownEquipment => MigrationRuleCodes.unknownEquipmentBlock,
    BlockReason.invalidEquipment => MigrationRuleCodes.invalidEquipmentBlock,
    BlockReason.invalidSecondaryTarget => null,
  };
}
