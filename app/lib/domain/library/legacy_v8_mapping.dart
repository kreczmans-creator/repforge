import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/library/preserved_ids.dart';
import 'package:repforge/domain/training/training.dart'
    show Exertion, ExertionScale;

/// Deterministic, side-effect-free mapping of one v7 row to its v8 values
/// and report events (plan section 6 steps 3, 5 and 6; ADR-0008 sections B
/// and E; ADR-0010 rule 5; `quality-and-duplicates.md` section 4; D04
/// section 7, 2026-11-06 and register R-01 to R-11). No SQL and no storage:
/// the migration engine writes what this returns.
///
/// Rules that hold for every function here:
/// - stored values match the preserved ids **exactly** (case and spelling);
///   no synonym, label, case folding or "none" matching;
/// - nothing is invented: no placeholder target, no inferred item;
/// - nothing is silently corrected, rounded or dropped: every value that
///   does not migrate one to one gets its own [ReportEvent];
/// - the same input always gives the same output.

/// Table and column names of the v7 rows this file reads.
abstract final class LegacyV7Columns {
  static const String exercisesTable = 'exercises';
  static const String primaryMuscle = 'primary_muscle';
  static const String secondaryMuscles = 'secondary_muscles_json';
  static const String equipment = 'equipment_json';
  static const String sessionSetsTable = 'session_sets';
  static const String exertionScale = 'exertion_scale';
  static const String exertionValue = 'exertion_value';
}

/// The columns of a v7 `exercises` row that the v8 mapping reads, as stored
/// SQLite values (TEXT as [String], INTEGER as [int]). Values are typed
/// [Object?] so that legacy or restored data of any shape can be reported.
@immutable
final class LegacyExerciseRow {
  const LegacyExerciseRow({
    required this.id,
    required this.primaryMuscle,
    required this.secondaryMusclesJson,
    required this.equipmentJson,
    required this.supplied,
  });

  final String id;
  final Object? primaryMuscle;
  final Object? secondaryMusclesJson;
  final Object? equipmentJson;

  /// v7 `supplied`: 0 or 1 (the v7 CHECK guarantees it), or a bool.
  final Object? supplied;
}

/// One `exercise_equipment` row of the v8 mapping: the item and its ordinal
/// among the kept elements. `role_override` and `override_note` stay NULL,
/// because v7 holds no role data (ADR-0008 section B step 8).
@immutable
final class LegacyEquipmentLink {
  const LegacyEquipmentLink(this.item, this.ordinal);

  final EquipmentItemId item;
  final int ordinal;

  @override
  bool operator ==(Object other) =>
      other is LegacyEquipmentLink &&
      other.item == item &&
      other.ordinal == ordinal;

  @override
  int get hashCode => Object.hash(item, ordinal);

  @override
  String toString() => '$item@$ordinal';
}

/// A block of one exercise for one reason (R-01: one row per exercise and
/// reason). [detail] names what blocked it, for example the unknown
/// equipment (ADR-0008 Q12).
@immutable
final class BlockDecision {
  const BlockDecision(this.reason, this.detail);

  final BlockReason reason;
  final String detail;

  @override
  bool operator ==(Object other) =>
      other is BlockDecision &&
      other.reason == reason &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(reason, detail);

  @override
  String toString() => '${reason.name}: $detail';
}

/// A request to copy an original value to `legacy_quarantine` because its
/// conversion is incomplete (plan section 6 step 5; ADR-0008 section E,
/// clarification 3). One request per record and column.
@immutable
final class QuarantineRequest {
  QuarantineRequest({
    required this.table,
    required this.recordId,
    required this.reason,
    required Map<String, Object?> original,
  }) : original = Map.unmodifiable(original);

  /// `legacy_quarantine.source_table`.
  final String table;

  /// `legacy_quarantine.row_id`.
  final String recordId;

  /// `legacy_quarantine.reason`: plain sentences.
  final String reason;

  /// Column → stored value, in column order.
  final Map<String, Object?> original;

  /// `legacy_quarantine.original_json` ([encodeStoredRow], R-06).
  String get originalJson => encodeStoredRow(original);

  @override
  bool operator ==(Object other) =>
      other is QuarantineRequest &&
      other.table == table &&
      other.recordId == recordId &&
      other.reason == reason &&
      other.originalJson == originalJson;

  @override
  int get hashCode => Object.hash(table, recordId, reason, originalJson);
}

/// The v8 values of one v7 exercise and everything the report needs.
@immutable
final class LegacyExerciseMapping {
  LegacyExerciseMapping({
    required this.id,
    required this.source,
    required this.providerId,
    required this.revision,
    required List<ExerciseTarget> targets,
    required List<LegacyEquipmentLink> equipment,
    required List<BlockDecision> blocks,
    required List<ReportEvent> events,
    required List<QuarantineRequest> quarantine,
  }) : targets = List.unmodifiable(targets),
       equipment = List.unmodifiable(equipment),
       blocks = List.unmodifiable(blocks),
       events = List.unmodifiable(events),
       quarantine = List.unmodifiable(quarantine);

  final ExerciseId id;

  /// From `supplied`: `system` (1) or `user` (0) (plan section 6 step 3).
  final ExerciseSource source;

  /// `repforge` for a system exercise, else null.
  final ProviderId? providerId;

  /// 1 for a system exercise, else null.
  final int? revision;

  /// `exercise_targets` rows: the primary at ordinal 0 when it maps, then the
  /// kept secondaries in stored order, contiguous with no gap (IC-309, R-11).
  final List<ExerciseTarget> targets;

  /// `exercise_equipment` rows, ordinal from 0 over the kept elements.
  final List<LegacyEquipmentLink> equipment;

  /// Active block reasons, in [BlockReason] order; empty when not blocked.
  final List<BlockDecision> blocks;

  /// Report events, in [ReportEvent.compare] order; empty for a clean row.
  final List<ReportEvent> events;

  /// Originals to quarantine; empty when every value migrated faithfully.
  final List<QuarantineRequest> quarantine;

  bool get isBlocked => blocks.isNotEmpty;

  /// The record outcome (R-04); clean exercises count as migrated.
  ReportCategory get outcome =>
      recordOutcome(events, cleanOutcome: ReportCategory.migrated);
}

final Set<String> _muscleIds = {
  for (final p in preservedMuscleNodes) p.id.value,
};
final Set<String> _equipmentIds = {
  for (final e in existingEquipmentIds) e.value,
};

/// Result of reading a stored JSON array column.
sealed class _JsonList {
  const _JsonList();
}

final class _Array extends _JsonList {
  const _Array(this.elements);
  final List<Object?> elements;
}

final class _NotArray extends _JsonList {
  const _NotArray(this.why);
  final String why;
}

_JsonList _readArray(Object? stored) {
  if (stored is! String) {
    return _NotArray(
      stored == null ? 'it is NULL' : 'it is not text (${_kind(stored)})',
    );
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(stored);
  } on FormatException {
    return const _NotArray('it is not valid JSON');
  }
  if (decoded is! List) return const _NotArray('it is not a JSON array');
  return _Array(decoded);
}

String _kind(Object? v) => switch (v) {
  null => 'null',
  String() => 'a string',
  int() => 'an integer',
  double() => 'a real number',
  bool() => 'a boolean',
  List() => 'an array',
  Map() => 'an object',
  _ => 'a value',
};

/// Switches for mapping choices that wait for an owner decision. The default
/// is the behaviour delivered for review; nothing else may depend on a
/// switch being on until the owner approves it.
@immutable
final class LegacyMappingOptions {
  const LegacyMappingOptions({this.blockInvalidSecondaryTargets = false});

  /// **OPEN (review WS4 H1, owner decision pending).** v7 hides an exercise
  /// whose `secondary_muscles_json` is not a JSON array, holds a non-string
  /// element or names an unknown muscle (`TrainingMappers.exerciseToEntity`
  /// returns null). With this switch off (the default) the v8 mapping
  /// quarantines those values and the exercise stays available: a visibility
  /// change against v7. With it on, each such exercise is also blocked with
  /// [BlockReason.invalidSecondaryTarget], like `unknownEquipment` (ADR-0008
  /// Q12). Repeated secondaries and a secondary equal to the primary are
  /// accepted by v7 and never block.
  final bool blockInvalidSecondaryTargets;
}

/// **OPEN (review WS4 L9, for the owner alongside H1).** v7 also hides an
/// exercise whose `type` or `category` is not a known identifier, or whose
/// `aliases_json` is not a JSON array of strings. This mapping does not read
/// those columns; whether v8 blocks such exercises is not decided here, and
/// no behaviour is implemented for it.
///
/// Maps one v7 exercise row to v8 (plan section 6 step 3; ADR-0008 section
/// B; ADR-0010 rule 5; D04 2026-11-06 no-primary disposition; R-01, R-02,
/// R-11).
///
/// Targets:
/// - `primary_muscle` that is exactly one of the 19 preserved ids becomes
///   the primary target at ordinal 0. Anything else (unknown text, empty
///   text, NULL, a non-string) is quarantined (IC-301) and the exercise is
///   blocked with `noPrimaryTarget` (IC-204). No placeholder is created.
/// - Each element of `secondary_muscles_json`, in stored order, at its
///   zero-based position:
///   - not a string → quarantined (WP8-D3);
///   - a string that is not a preserved id → quarantined (IC-301);
///   - equal to the mapped primary → skipped (IC-305), not duplicated;
///   - equal to an earlier kept secondary → skipped (IC-302);
///   - `fullBody` → kept as a secondary target and reported as a warning
///     for review (ADR-0010 rule 5; action `retained`);
///   - otherwise → kept, with no event.
/// - Text that is not a JSON array → quarantined whole (WP8-D3); no
///   secondary is kept.
/// - None of these blocks the exercise unless
///   [LegacyMappingOptions.blockInvalidSecondaryTargets] is on (OPEN, H1):
///   then any quarantined secondary value adds a block
///   `invalidSecondaryTarget` with its own entry (rule
///   [MigrationRuleCodes.invalidSecondaryTargetBlock]).
/// - Ordinals are contiguous: the primary 0, the kept secondaries 1..n; with
///   no mapped primary the kept secondaries take 0..n-1 (IC-309).
/// - A secondary that the OQ-19 roll-up would suppress is an ordinary kept
///   secondary: no event (see `migration_report.dart`).
///
/// Equipment (`equipment_json`), elements matched exactly against the 21
/// ids:
/// - a known id, first occurrence → kept, ordinal from 0 over kept elements;
/// - a known id repeated → skipped (IC-307), with its position and id
///   (ADR-0008 Q10); the first occurrence stays;
/// - a string that is not one of the 21 ids → quarantined (IC-307) and the
///   exercise blocked with `unknownEquipment`, naming the ids (block entry
///   rule ADR-0008-Q12);
/// - a non-string element → quarantined (WP8-D3) and the exercise blocked
///   with `invalidEquipment` (block entry rule R-02);
/// - text that is not a JSON array → a whole-column `quarantined` entry
///   (WP8-D3) and a `blocked` entry `invalidEquipment` (R-02); no item is
///   linked. The two entries differ by rule, so their event ids differ.
/// The original `equipment_json` is quarantined whenever an element is
/// unknown or invalid or the text is not an array; a list with only repeats
/// migrates faithfully and is not quarantined (ADR-0008 clarification 3).
/// Known items of a blocked exercise are still linked (section B step 18).
///
/// `supplied` → `source` `system` with provider `repforge` and revision 1,
/// or `user` with neither. A `supplied` value other than 0, 1 or a bool is
/// outside the v7 CHECK and throws [ArgumentError].
LegacyExerciseMapping mapLegacyExercise(
  LegacyExerciseRow row, {
  LegacyMappingOptions options = const LegacyMappingOptions(),
}) {
  const table = LegacyV7Columns.exercisesTable;
  final id = row.id;
  if (id.isEmpty) throw ArgumentError.value(id, 'row.id', 'empty');

  // Type-strict: a REAL 1.0 is not the v7 INTEGER 1 (1.0 == 1 in Dart).
  final supplied = row.supplied;
  final ExerciseSource source;
  if (supplied == true || (supplied is int && supplied == 1)) {
    source = ExerciseSource.system;
  } else if (supplied == false || (supplied is int && supplied == 0)) {
    source = ExerciseSource.user;
  } else {
    throw ArgumentError.value(
      supplied,
      'row.supplied',
      'v7 supplied must be 0 or 1',
    );
  }

  final events = <ReportEvent>[];
  final quarantine = <QuarantineRequest>[];
  final blocks = <BlockDecision>[];
  final targets = <ExerciseTarget>[];

  ReportEvent event({
    required String field,
    required Object? original,
    required ReportAction action,
    required String rule,
    required ReportCategory category,
    required String reason,
    int? position,
    Object? element = _noElement,
    String? resulting,
    BlockReason? blockReason,
  }) => ReportEvent(
    table: table,
    recordId: id,
    field: field,
    position: position,
    originalValue: encodeStoredValue(original),
    element: identical(element, _noElement) ? null : jsonEncode(element),
    resultingValue: resulting,
    action: action,
    rule: rule,
    category: category,
    reason: reason,
    blockReason: blockReason,
  );

  // Primary.
  final primary = row.primaryMuscle;
  final primaryMaps = primary is String && _muscleIds.contains(primary);
  if (primaryMaps) {
    targets.add(
      ExerciseTarget(
        node: AnatomyNodeId(primary),
        role: TargetRole.primary,
        ordinal: 0,
      ),
    );
  } else {
    final shown = primary is String ? '"$primary"' : _kind(primary);
    events
      ..add(
        event(
          field: LegacyV7Columns.primaryMuscle,
          original: primary,
          action: ReportAction.quarantined,
          rule: MigrationRuleCodes.unknownNode,
          category: ReportCategory.quarantinedOrUnresolved,
          reason:
              'The primary muscle $shown is not one of the 19 preserved '
              'muscle ids; the original is quarantined and no target is '
              'created.',
        ),
      )
      ..add(
        event(
          field: LegacyV7Columns.primaryMuscle,
          original: primary,
          action: ReportAction.blocked,
          rule: MigrationRuleCodes.noPrimaryTarget,
          category: ReportCategory.rejectedOrBlocked,
          blockReason: BlockReason.noPrimaryTarget,
          reason:
              'The exercise has no primary target, so it is blocked from new '
              'use; its id, history and original data are kept.',
        ),
      );
    quarantine.add(
      QuarantineRequest(
        table: table,
        recordId: id,
        reason:
            'Unmapped primary muscle (IC-301); exercise blocked: '
            'noPrimaryTarget.',
        original: {LegacyV7Columns.primaryMuscle: primary},
      ),
    );
    blocks.add(
      BlockDecision(
        BlockReason.noPrimaryTarget,
        'primary_muscle $shown does not map to an anatomy node',
      ),
    );
  }

  // Secondaries.
  final secondaryStored = row.secondaryMusclesJson;
  final secondaries = _readArray(secondaryStored);
  var secondaryQuarantined = false;
  switch (secondaries) {
    case _NotArray(:final why):
      secondaryQuarantined = true;
      events.add(
        event(
          field: LegacyV7Columns.secondaryMuscles,
          original: secondaryStored,
          action: ReportAction.quarantined,
          rule: MigrationRuleCodes.legacyData,
          category: ReportCategory.quarantinedOrUnresolved,
          reason:
              'The secondary muscle list cannot be read because $why; the '
              'original is quarantined and no secondary target is created.',
        ),
      );
    case _Array(:final elements):
      final kept = <String>{};
      for (var i = 0; i < elements.length; i++) {
        final m = elements[i];
        if (m is! String) {
          secondaryQuarantined = true;
          events.add(
            event(
              field: LegacyV7Columns.secondaryMuscles,
              position: i,
              element: m,
              original: secondaryStored,
              action: ReportAction.quarantined,
              rule: MigrationRuleCodes.legacyData,
              category: ReportCategory.quarantinedOrUnresolved,
              reason:
                  'Secondary muscle at position $i is ${_kind(m)}, not a '
                  'muscle id; the original list is quarantined.',
            ),
          );
        } else if (!_muscleIds.contains(m)) {
          secondaryQuarantined = true;
          events.add(
            event(
              field: LegacyV7Columns.secondaryMuscles,
              position: i,
              element: m,
              original: secondaryStored,
              action: ReportAction.quarantined,
              rule: MigrationRuleCodes.unknownNode,
              category: ReportCategory.quarantinedOrUnresolved,
              reason:
                  'Secondary muscle "$m" at position $i is not one of the 19 '
                  'preserved muscle ids; the original list is quarantined.',
            ),
          );
        } else if (primaryMaps && m == primary) {
          events.add(
            event(
              field: LegacyV7Columns.secondaryMuscles,
              position: i,
              element: m,
              original: secondaryStored,
              action: ReportAction.skipped,
              rule: MigrationRuleCodes.primaryAsSecondary,
              category: ReportCategory.migrated,
              reason:
                  'Secondary muscle "$m" at position $i equals the primary '
                  'target; it is not duplicated.',
            ),
          );
        } else if (!kept.add(m)) {
          events.add(
            event(
              field: LegacyV7Columns.secondaryMuscles,
              position: i,
              element: m,
              original: secondaryStored,
              action: ReportAction.skipped,
              rule: MigrationRuleCodes.repeatedNode,
              category: ReportCategory.migrated,
              reason:
                  'Secondary muscle "$m" at position $i repeats an earlier '
                  'entry of the list; the first occurrence is kept.',
            ),
          );
        } else {
          targets.add(
            ExerciseTarget(
              node: AnatomyNodeId(m),
              role: TargetRole.secondary,
              ordinal: targets.length,
            ),
          );
          if (m == fullBodyNodeId.value) {
            events.add(
              event(
                field: LegacyV7Columns.secondaryMuscles,
                position: i,
                element: m,
                original: secondaryStored,
                action: ReportAction.retained,
                rule: MigrationRuleCodes.fullBodySecondary,
                category: ReportCategory.warningForReview,
                reason:
                    'fullBody at position $i is kept as a secondary target '
                    'historically; ADR-0010 allows it only as a single '
                    'primary, so it needs review.',
              ),
            );
          }
        }
      }
  }
  if (secondaryQuarantined && options.blockInvalidSecondaryTargets) {
    blocks.add(
      const BlockDecision(
        BlockReason.invalidSecondaryTarget,
        'secondary_muscles_json is not fully mappable',
      ),
    );
    events.add(
      event(
        field: LegacyV7Columns.secondaryMuscles,
        original: secondaryStored,
        action: ReportAction.blocked,
        rule: MigrationRuleCodes.invalidSecondaryTargetBlock,
        category: ReportCategory.rejectedOrBlocked,
        blockReason: BlockReason.invalidSecondaryTarget,
        reason:
            'The secondary muscle list holds a value v7 could not read, so '
            'the exercise is blocked from new use; its id, history and '
            'original data are kept.',
      ),
    );
  }
  if (secondaryQuarantined) {
    quarantine.add(
      QuarantineRequest(
        table: table,
        recordId: id,
        reason:
            'Secondary muscle list not fully mappable (IC-301 or '
            'WP8-D3); mapped entries migrated.',
        original: {LegacyV7Columns.secondaryMuscles: secondaryStored},
      ),
    );
  }

  // Equipment.
  final equipmentStored = row.equipmentJson;
  final equipment = <LegacyEquipmentLink>[];
  final unknown = <String>[];
  final invalid = <String>[];
  switch (_readArray(equipmentStored)) {
    case _NotArray(:final why):
      invalid.add('equipment_json: $why');
      events.add(
        event(
          field: LegacyV7Columns.equipment,
          original: equipmentStored,
          action: ReportAction.quarantined,
          rule: MigrationRuleCodes.legacyData,
          category: ReportCategory.quarantinedOrUnresolved,
          reason:
              'The equipment list cannot be read because $why; the original '
              'is quarantined and no item is linked.',
        ),
      );
    case _Array(:final elements):
      final seen = <String>{};
      for (var i = 0; i < elements.length; i++) {
        final q = elements[i];
        if (q is! String) {
          invalid.add('position $i: ${_kind(q)}');
          events.add(
            event(
              field: LegacyV7Columns.equipment,
              position: i,
              element: q,
              original: equipmentStored,
              action: ReportAction.quarantined,
              rule: MigrationRuleCodes.legacyData,
              category: ReportCategory.quarantinedOrUnresolved,
              reason:
                  'Equipment at position $i is ${_kind(q)}, not an equipment '
                  'id; the original list is quarantined.',
            ),
          );
        } else if (!_equipmentIds.contains(q)) {
          unknown.add(q);
          events.add(
            event(
              field: LegacyV7Columns.equipment,
              position: i,
              element: q,
              original: equipmentStored,
              action: ReportAction.quarantined,
              rule: MigrationRuleCodes.equipment,
              category: ReportCategory.quarantinedOrUnresolved,
              reason:
                  'Equipment "$q" at position $i is not one of the 21 '
                  'equipment ids; the original list is quarantined.',
            ),
          );
        } else if (!seen.add(q)) {
          events.add(
            event(
              field: LegacyV7Columns.equipment,
              position: i,
              element: q,
              original: equipmentStored,
              action: ReportAction.skipped,
              rule: MigrationRuleCodes.equipment,
              category: ReportCategory.migrated,
              reason:
                  'Equipment "$q" at position $i repeats an earlier entry; '
                  'the first occurrence is kept.',
            ),
          );
        } else {
          equipment.add(
            LegacyEquipmentLink(EquipmentItemId(q), equipment.length),
          );
        }
      }
  }
  if (unknown.isNotEmpty) {
    final names = unknown.map((u) => '"$u"').join(', ');
    blocks.add(BlockDecision(BlockReason.unknownEquipment, names));
    events.add(
      event(
        field: LegacyV7Columns.equipment,
        original: equipmentStored,
        action: ReportAction.blocked,
        rule: MigrationRuleCodes.unknownEquipmentBlock,
        category: ReportCategory.rejectedOrBlocked,
        blockReason: BlockReason.unknownEquipment,
        reason:
            'The exercise uses unknown equipment $names, so it is blocked '
            'from new use; its id, history and original data are kept.',
      ),
    );
  }
  if (invalid.isNotEmpty) {
    final detail = invalid.join('; ');
    blocks.add(BlockDecision(BlockReason.invalidEquipment, detail));
    events.add(
      event(
        field: LegacyV7Columns.equipment,
        original: equipmentStored,
        action: ReportAction.blocked,
        rule: MigrationRuleCodes.invalidEquipmentBlock,
        category: ReportCategory.rejectedOrBlocked,
        blockReason: BlockReason.invalidEquipment,
        reason:
            'The equipment list cannot be read ($detail), so the exercise is '
            'blocked from new use; the original is quarantined.',
      ),
    );
  }
  if (unknown.isNotEmpty || invalid.isNotEmpty) {
    final causes = [
      if (unknown.isNotEmpty) 'Unknown equipment (IC-307)',
      if (invalid.isNotEmpty) 'Invalid equipment (WP8-D3)',
    ];
    quarantine.add(
      QuarantineRequest(
        table: table,
        recordId: id,
        reason: '${causes.join('; ')}; exercise blocked.',
        original: {LegacyV7Columns.equipment: equipmentStored},
      ),
    );
  }

  events.sort(ReportEvent.compare);
  return LegacyExerciseMapping(
    id: ExerciseId(id),
    source: source,
    providerId: source == ExerciseSource.system ? ProviderId.repforge : null,
    revision: source == ExerciseSource.system ? 1 : null,
    targets: targets,
    equipment: equipment,
    blocks: blocks,
    events: events,
    quarantine: quarantine,
  );
}

const Object _noElement = Object();

// ---------------------------------------------------------------------------
// TRN-020 exertion on `session_sets`.

/// Why a stored exertion pair breaks TRN-020. Stored identifier: [name].
enum ExertionDefect {
  /// A scale without a value.
  scaleWithoutValue,

  /// A value without a scale.
  valueWithoutScale,

  /// A scale other than exactly `rpe` or `rir` (for example `borg`, `RPE`).
  unknownScale,

  /// A value that is not a number (text, blob).
  valueNotNumber,

  /// RPE outside 1–10 or not a 0.5 step (including NaN and infinity).
  rpeOutsideRule,

  /// RIR outside 0–5 or not a whole number (including NaN and infinity).
  rirOutsideRule,
}

/// RPE and RIR bounds of TRN-020. They equal `TrainingRules` (rpeMin,
/// rpeMax, rpeStep, rirMin, rirMax); the library domain may not import that
/// file (architecture test), so a property test proves the equality.
abstract final class _Trn020 {
  static const rpeMin = 1;
  static const rpeMax = 10;
  static const rpeStep = 0.5;
  static const rirMin = 0;
  static const rirMax = 5;
}

/// TRN-020 for one exertion: the same decision as
/// `TrainingRules.validExertion` (a property test proves equality).
bool exertionMeetsTrn020(Exertion e) {
  final v = e.value;
  if (v.isNaN || v.isInfinite) return false;
  return switch (e.scale) {
    ExertionScale.rpe =>
      v / _Trn020.rpeStep == (v / _Trn020.rpeStep).roundToDouble() &&
          v >= _Trn020.rpeMin &&
          v <= _Trn020.rpeMax,
    ExertionScale.rir =>
      v == v.roundToDouble() && v >= _Trn020.rirMin && v <= _Trn020.rirMax,
  };
}

/// The TRN-020 decision for one stored set row.
@immutable
final class ExertionClassification {
  ExertionClassification._({
    required this.scale,
    required this.value,
    required this.defect,
    required List<ReportEvent> events,
    required this.quarantine,
  }) : events = List.unmodifiable(events);

  /// The operational `exertion_scale` after migration: unchanged when valid,
  /// NULL (Dart null) when the pair is cleared.
  final Object? scale;

  /// The operational `exertion_value` after migration.
  final Object? value;

  /// Null when the pair meets TRN-020 (or both are NULL).
  final ExertionDefect? defect;

  /// One `cleared` event per non-NULL column of an invalid pair; empty when
  /// valid.
  final List<ReportEvent> events;

  /// The original pair to quarantine; null when valid.
  final QuarantineRequest? quarantine;

  bool get isValid => defect == null;

  /// Valid pairs are preserved unchanged; cleared pairs are quarantined.
  ReportCategory get outcome =>
      recordOutcome(events, cleanOutcome: ReportCategory.preserved);
}

/// Classifies the stored exertion pair of one `session_sets` row (D04
/// TRN-020; plan section 6 step 6; owner decision 2026-11-06: keep valid
/// values, quarantine and report invalid ones, never round or correct).
///
/// Valid: both NULL; or scale exactly `rpe` with a finite number from 1 to
/// 10 in 0.5 steps; or scale exactly `rir` with a whole number from 0 to 5.
/// A valid pair is returned unchanged with no event.
///
/// Invalid: the original pair is quarantined, both columns are cleared to
/// NULL (exertion is optional), and each column that held a value gets a
/// `cleared` event (rule TRN-020, category quarantinedOrUnresolved). The set
/// row and its relationships are kept.
///
/// [scale] and [value] are the stored SQLite values. An INTEGER value (for
/// example from a restore) is read as its number.
ExertionClassification classifyLegacyExertion({
  required String setId,
  required Object? scale,
  required Object? value,
}) {
  if (setId.isEmpty) throw ArgumentError.value(setId, 'setId', 'empty');
  final defect = _exertionDefect(scale, value);
  if (defect == null) {
    return ExertionClassification._(
      scale: scale,
      value: value,
      defect: null,
      events: const [],
      quarantine: null,
    );
  }
  final pair = '(${encodeStoredValue(scale)}, ${encodeStoredValue(value)})';
  final why = switch (defect) {
    ExertionDefect.scaleWithoutValue => 'has a scale but no value',
    ExertionDefect.valueWithoutScale => 'has a value but no scale',
    ExertionDefect.unknownScale => 'has a scale other than rpe or rir',
    ExertionDefect.valueNotNumber => 'has a value that is not a number',
    ExertionDefect.rpeOutsideRule => 'has an RPE outside 1 to 10 in half steps',
    ExertionDefect.rirOutsideRule =>
      'has an RIR that is not a whole number from 0 to 5',
  };
  final reason =
      'The exertion pair $pair $why (TRN-020); the original is quarantined '
      'and the pair is cleared, never rounded or corrected.';
  final events = <ReportEvent>[
    for (final (field, original) in [
      (LegacyV7Columns.exertionScale, scale),
      (LegacyV7Columns.exertionValue, value),
    ])
      if (original != null)
        ReportEvent(
          table: LegacyV7Columns.sessionSetsTable,
          recordId: setId,
          field: field,
          originalValue: encodeStoredValue(original),
          resultingValue: encodeStoredValue(null),
          action: ReportAction.cleared,
          rule: MigrationRuleCodes.exertion,
          category: ReportCategory.quarantinedOrUnresolved,
          reason: reason,
        ),
  ];
  return ExertionClassification._(
    scale: null,
    value: null,
    defect: defect,
    events: events,
    quarantine: QuarantineRequest(
      table: LegacyV7Columns.sessionSetsTable,
      recordId: setId,
      reason:
          'TRN-020 exertion outside the rule (${defect.name}); pair '
          'cleared.',
      original: {
        LegacyV7Columns.exertionScale: scale,
        LegacyV7Columns.exertionValue: value,
      },
    ),
  );
}

ExertionDefect? _exertionDefect(Object? scale, Object? value) {
  if (scale == null && value == null) return null;
  if (value == null) return ExertionDefect.scaleWithoutValue;
  if (scale == null) return ExertionDefect.valueWithoutScale;
  final ExertionScale parsed;
  switch (scale) {
    case 'rpe':
      parsed = ExertionScale.rpe;
    case 'rir':
      parsed = ExertionScale.rir;
    default:
      return ExertionDefect.unknownScale;
  }
  if (value is! num) return ExertionDefect.valueNotNumber;
  final ok = exertionMeetsTrn020(
    Exertion(scale: parsed, value: value.toDouble()),
  );
  if (ok) return null;
  return parsed == ExertionScale.rpe
      ? ExertionDefect.rpeOutsideRule
      : ExertionDefect.rirOutsideRule;
}
