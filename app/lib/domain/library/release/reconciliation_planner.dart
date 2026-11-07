import 'package:meta/meta.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/catalogue_records.dart';
import 'package:repforge/domain/library/exercise_relationship.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/release/release_validator.dart';

/// What the catalogue holds for one exercise id (ids, source, provider,
/// revision, retired flag). One entry per exercise of any source: the planner
/// must know about user and imported exercises and custom copies to keep its
/// hands off them. Not a database row: callers build it from whatever they
/// read.
@immutable
final class ExerciseStateEntry {
  const ExerciseStateEntry({
    required this.id,
    required this.source,
    this.providerId,
    this.revision,
    this.retired = false,
    this.copiedFromId,
  });

  /// A system exercise of [providerId] at [revision].
  const ExerciseStateEntry.system(
    this.id, {
    required this.revision,
    this.providerId = ProviderId.repforge,
    this.retired = false,
  }) : source = ExerciseSource.system,
       copiedFromId = null;

  final ExerciseId id;
  final ExerciseSource source;
  final ProviderId? providerId;

  /// Revision of a system exercise; null for user and imported exercises.
  final int? revision;
  final bool retired;

  /// For a custom copy: the exercise it was copied from.
  final ExerciseId? copiedFromId;

  bool get isSystem => source == ExerciseSource.system;
}

/// An immutable snapshot of the current catalogue state: the input of the
/// planner. It is data handed in; nothing here reads a database.
@immutable
final class CatalogueStateSnapshot {
  CatalogueStateSnapshot({
    Iterable<ExerciseStateEntry> exercises = const [],
    Map<EquipmentItemId, EquipmentDefaultRole> equipmentDefaultRoles = const {},
    Map<ProviderId, int> latestAppliedRelease = const {},
  }) : equipmentDefaultRoles = Map.unmodifiable(equipmentDefaultRoles),
       latestAppliedRelease = Map.unmodifiable(latestAppliedRelease) {
    for (final e in exercises) {
      _byId.putIfAbsent(e.id, () => e);
    }
  }

  /// A device that has applied nothing.
  static final CatalogueStateSnapshot empty = CatalogueStateSnapshot();

  final Map<ExerciseId, ExerciseStateEntry> _byId = {};

  /// Default role of every equipment item already in the catalogue (R-20).
  final Map<EquipmentItemId, EquipmentDefaultRole> equipmentDefaultRoles;

  /// The highest release number applied per provider.
  final Map<ProviderId, int> latestAppliedRelease;

  Iterable<ExerciseStateEntry> get exercises => _byId.values;

  ExerciseStateEntry? entry(ExerciseId id) => _byId[id];
}

/// A new system exercise with its content and media references.
@immutable
final class PlannedInsert {
  const PlannedInsert({
    required this.exercise,
    this.content = const [],
    this.media = const [],
  });

  final CatalogueExercise exercise;
  final List<ContentSection> content;
  final List<MediaReference> media;

  ExerciseId get id => exercise.id;
}

/// A system exercise whose release revision is higher than the stored one:
/// all system-owned fields (and their child rows, replaced by delete and
/// insert, R-29) take the release values. There is deliberately no source
/// field: source is never updated (R-26).
@immutable
final class PlannedUpdate {
  const PlannedUpdate({
    required this.exercise,
    required this.fromRevision,
    required this.toRevision,
    this.content = const [],
    this.media = const [],
  });

  final CatalogueExercise exercise;
  final int fromRevision;
  final int toRevision;
  final List<ContentSection> content;
  final List<MediaReference> media;

  ExerciseId get id => exercise.id;
}

/// A system exercise the release retires.
@immutable
final class PlannedRetirement {
  const PlannedRetirement(this.id, this.reason, {this.replacedBy});

  final ExerciseId id;
  final String reason;
  final ExerciseId? replacedBy;
}

/// Why nothing is written for an id.
enum NoOpReason {
  /// The stored revision equals the release revision.
  sameRevision,

  /// The retired id is already retired.
  alreadyRetired,

  /// The retired id is not in the catalogue on this device.
  notInCatalogue,
}

/// An id the release mentions and the plan leaves alone.
@immutable
final class PlannedNoOp {
  const PlannedNoOp(this.id, this.reason);

  final ExerciseId id;
  final NoOpReason reason;
}

/// For information only: a custom copy whose source exercise is updated by the
/// release. The plan writes nothing to the copy (ADR-0009 decision 4); how a
/// "source updated" marker is stored or derived is register item R-25 and is
/// not decided here.
@immutable
final class SourceUpdatedNotice {
  const SourceUpdatedNotice({
    required this.copyId,
    required this.sourceId,
    required this.sourceRevision,
  });

  final ExerciseId copyId;
  final ExerciseId sourceId;
  final int sourceRevision;
}

/// The result of planning: operations on system exercises only, or refusals.
///
/// All or nothing: when there is any refusal the plan holds no operation.
/// There is no operation type for user and imported exercises, custom copies,
/// user state, user relationships, plans, sessions or history, so the plan
/// cannot express a write to them (ADR-0009 decision 4).
@immutable
final class ReconciliationPlan {
  ReconciliationPlan({
    required this.provider,
    required this.release,
    required this.contentHash,
    required this.recordsRelease,
    List<PlannedInsert> inserts = const [],
    List<PlannedUpdate> updates = const [],
    List<PlannedRetirement> retirements = const [],
    List<PlannedNoOp> noOps = const [],
    List<ExerciseRelationship> relationships = const [],
    List<SourceUpdatedNotice> sourceUpdatedNotices = const [],
    List<Finding> refusals = const [],
  }) : inserts = List.unmodifiable(inserts),
       updates = List.unmodifiable(updates),
       retirements = List.unmodifiable(retirements),
       noOps = List.unmodifiable(noOps),
       relationships = List.unmodifiable(relationships),
       sourceUpdatedNotices = List.unmodifiable(sourceUpdatedNotices),
       refusals = List.unmodifiable(refusals);

  final ContentProvider provider;
  final ReleaseId release;

  /// SHA-256 of the exact release bytes, lowercase hex (R-10).
  final String contentHash;

  /// True when the release log row (and the provider record) is to be
  /// written: the release number is not yet the provider's latest applied.
  final bool recordsRelease;
  final List<PlannedInsert> inserts;
  final List<PlannedUpdate> updates;
  final List<PlannedRetirement> retirements;
  final List<PlannedNoOp> noOps;

  /// System relationships with an end on an inserted or updated exercise.
  final List<ExerciseRelationship> relationships;
  final List<SourceUpdatedNotice> sourceUpdatedNotices;

  /// Reasons the release must not be applied (codes `RP-xxx`).
  final List<Finding> refusals;

  bool get canApply => refusals.isEmpty;

  int get insertedCount => inserts.length;
  int get updatedCount => updates.length;
  int get retiredCount => retirements.length;

  /// True when applying the plan would write nothing at all: the re-run of an
  /// applied release (idempotence).
  bool get writesNothing =>
      canApply &&
      !recordsRelease &&
      inserts.isEmpty &&
      updates.isEmpty &&
      retirements.isEmpty;

  /// Every exercise id the plan writes, all of them system exercises.
  Set<ExerciseId> get writtenExerciseIds => {
    for (final i in inserts) i.id,
    for (final u in updates) u.id,
    for (final r in retirements) r.id,
  };
}

Finding _refuse(
  String code,
  String message, {
  String? subjectId,
  List<String> related = const [],
}) => Finding(
  code: code,
  severity: Severity.error,
  message: message,
  subjectId: subjectId,
  related: related,
);

/// Plans the reconciliation of a validated [release] against [snapshot].
///
/// Pure: reads nothing, writes nothing, ignores the clock.
/// - new id: insert as `system`;
/// - known system id with a higher revision: update;
/// - equal revision: no-op (idempotent re-run);
/// - id under `retirements`: retire (never delete);
/// - anything that would touch a non-system row, lower a revision, bring a
///   retired id back, omit an id without retiring it (IC-110), change an
///   equipment item's default role (R-20) or apply an older release is
///   refused, and a refusal refuses the whole plan.
ReconciliationPlan planReconciliation({
  required ValidatedRelease release,
  required CatalogueStateSnapshot snapshot,
}) {
  final doc = release.document;
  final providerId = doc.provider.id;
  final refusals = <Finding>[];
  final inserts = <PlannedInsert>[];
  final updates = <PlannedUpdate>[];
  final retirements = <PlannedRetirement>[];
  final noOps = <PlannedNoOp>[];

  final applied = snapshot.latestAppliedRelease[providerId];
  if (applied != null && doc.release.number < applied) {
    refusals.add(
      _refuse(
        'RP-008',
        'Release ${doc.release.number} of $providerId is older than the '
            'latest applied release $applied.',
      ),
    );
  }

  // R-20: a default role is immutable.
  for (final item in release.reference.equipment.items) {
    final stored = snapshot.equipmentDefaultRoles[item.id];
    if (stored != null && stored != item.defaultRole) {
      refusals.add(
        _refuse(
          'RP-007',
          'Equipment item ${item.id} has the stored default role '
              '${stored.name}; the release says ${item.defaultRole.name}. A '
              'role change needs a new stable equipment id.',
          subjectId: item.id.value,
        ),
      );
    }
  }

  List<ContentSection> contentOf(ExerciseId id) => [
    for (final c in doc.content)
      if (c.exerciseId == id) c,
  ];
  List<MediaReference> mediaOf(ExerciseId id) => [
    for (final m in doc.media)
      if (m.exerciseId == id) m,
  ];

  final retiringIds = {for (final r in doc.retirements) r.id};
  final releaseIds = doc.exerciseIds;
  final changed = <ExerciseId>{};

  final ordered = [...doc.exercises]..sort((a, b) => a.id.compareTo(b.id));
  for (final exercise in ordered) {
    final id = exercise.id;
    final revision = exercise.revision!;
    final stored = snapshot.entry(id);
    if (retiringIds.contains(id)) {
      refusals.add(
        _refuse(
          'RP-010',
          'The release lists $id as an exercise and as a retirement.',
          subjectId: id.value,
        ),
      );
      continue;
    }
    if (stored == null) {
      inserts.add(
        PlannedInsert(
          exercise: exercise,
          content: contentOf(id),
          media: mediaOf(id),
        ),
      );
      changed.add(id);
      continue;
    }
    if (!stored.isSystem) {
      refusals.add(
        _refuse(
          'RP-001',
          'The id $id belongs to a ${stored.source.name} exercise on this '
              'device. A release never writes user or imported exercises or '
              'custom copies.',
          subjectId: id.value,
        ),
      );
      continue;
    }
    if (stored.providerId != providerId) {
      refusals.add(
        _refuse(
          'RP-002',
          'The id $id belongs to provider ${stored.providerId} on this '
              'device, not $providerId.',
          subjectId: id.value,
        ),
      );
      continue;
    }
    if (stored.retired) {
      refusals.add(
        _refuse(
          'RP-004',
          'The id $id is retired; a retired id never comes back (IC-111).',
          subjectId: id.value,
        ),
      );
      continue;
    }
    final storedRevision = stored.revision;
    if (storedRevision == null) {
      refusals.add(
        _refuse(
          'RP-011',
          'The system exercise $id has no stored revision, so the release '
              'cannot be compared with it.',
          subjectId: id.value,
        ),
      );
    } else if (revision > storedRevision) {
      updates.add(
        PlannedUpdate(
          exercise: exercise,
          fromRevision: storedRevision,
          toRevision: revision,
          content: contentOf(id),
          media: mediaOf(id),
        ),
      );
      changed.add(id);
    } else if (revision == storedRevision) {
      noOps.add(PlannedNoOp(id, NoOpReason.sameRevision));
    } else {
      refusals.add(
        _refuse(
          'RP-003',
          'The release has revision $revision of $id; revision '
              '$storedRevision is stored. A revision never lowers (IC-104).',
          subjectId: id.value,
        ),
      );
    }
  }

  final retirementOrder = [...doc.retirements]
    ..sort((a, b) => a.id.compareTo(b.id));
  for (final r in retirementOrder) {
    final stored = snapshot.entry(r.id);
    if (stored == null) {
      noOps.add(PlannedNoOp(r.id, NoOpReason.notInCatalogue));
    } else if (!stored.isSystem || stored.providerId != providerId) {
      refusals.add(
        _refuse(
          'RP-006',
          'The release retires ${r.id}, which is not a $providerId system '
              'exercise on this device.',
          subjectId: r.id.value,
        ),
      );
    } else if (stored.retired) {
      noOps.add(PlannedNoOp(r.id, NoOpReason.alreadyRetired));
    } else {
      retirements.add(
        PlannedRetirement(r.id, r.reason, replacedBy: r.replacedBy),
      );
    }
  }

  // IC-110: absence alone retires nothing; it is refused.
  final omitted = [
    for (final e in snapshot.exercises)
      if (e.isSystem &&
          e.providerId == providerId &&
          !e.retired &&
          !releaseIds.contains(e.id) &&
          !retiringIds.contains(e.id))
        e.id,
  ]..sort();
  for (final id in omitted) {
    refusals.add(
      _refuse(
        'RP-005',
        'The release omits $id and does not list it under retirements '
            '(IC-110).',
        subjectId: id.value,
      ),
    );
  }

  // System relationships must not reach a non-system exercise.
  final relationships = <ExerciseRelationship>[];
  for (final rel in doc.relationships) {
    for (final end in [rel.from, rel.to]) {
      final stored = snapshot.entry(end);
      if (stored != null && !stored.isSystem) {
        refusals.add(
          _refuse(
            'RP-009',
            'The relationship ${rel.from} ${rel.kind.name} ${rel.to} has an '
                'end on $end, a ${stored.source.name} exercise.',
            subjectId: end.value,
            related: [rel.from.value, rel.to.value],
          ),
        );
      }
    }
    if (changed.contains(rel.from) || changed.contains(rel.to)) {
      relationships.add(rel);
    }
  }
  relationships.sort();

  final notices = [
    for (final e in snapshot.exercises)
      if (!e.isSystem &&
          e.copiedFromId != null &&
          updates.any((u) => u.id == e.copiedFromId))
        SourceUpdatedNotice(
          copyId: e.id,
          sourceId: e.copiedFromId!,
          sourceRevision: updates
              .firstWhere((u) => u.id == e.copiedFromId)
              .toRevision,
        ),
  ]..sort((a, b) => a.copyId.compareTo(b.copyId));

  final recordsRelease = applied == null || doc.release.number > applied;
  if (refusals.isNotEmpty) {
    return ReconciliationPlan(
      provider: doc.provider,
      release: doc.release,
      contentHash: release.contentHash,
      recordsRelease: false,
      refusals: sortedFindings(refusals),
    );
  }
  return ReconciliationPlan(
    provider: doc.provider,
    release: doc.release,
    contentHash: release.contentHash,
    recordsRelease: recordsRelease,
    inserts: inserts,
    updates: updates,
    retirements: retirements,
    noOps: noOps,
    relationships: relationships,
    sourceUpdatedNotices: notices,
  );
}
