import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:repforge/domain/library/accepted_gaps.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/catalogue_records.dart';
import 'package:repforge/domain/library/content_rules.dart';
import 'package:repforge/domain/library/coverage_evaluation.dart';
import 'package:repforge/domain/library/coverage_spec.dart';
import 'package:repforge/domain/library/duplicate_detection.dart';
import 'package:repforge/domain/library/exercise_relationship.dart';
import 'package:repforge/domain/library/exercise_rules.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/name_rules.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/reference_validation.dart';
import 'package:repforge/domain/library/relationship_rules.dart';

/// Schema id of the integrity report JSON (`quality-and-duplicates.md`
/// section 3).
const String integrityReportSchema = 'repforge.integrityReport/1';

/// A retirement listed in a release (IC-110, IC-112).
@immutable
final class Retirement {
  const Retirement(this.id, this.reason, {this.replacedBy});

  final ExerciseId id;
  final String reason;
  final ExerciseId? replacedBy;
}

/// The exercise ids that user data and history refer to (IC-900), passed in as
/// id sets because the check never reads a database. Retired exercises are
/// part of the catalogue and must resolve.
@immutable
final class ExerciseReferences {
  const ExerciseReferences({
    this.sessionSetExerciseIds = const {},
    this.sessionExerciseIds = const {},
    this.planExerciseIds = const {},
    this.userStateExerciseIds = const {},
    this.quarantinedExerciseIds = const {},
  });

  /// `session_sets.exercise_id`.
  final Set<ExerciseId> sessionSetExerciseIds;

  /// `session_exercises.exercise_id`.
  final Set<ExerciseId> sessionExerciseIds;

  /// `plan_exercises.exercise_id`.
  final Set<ExerciseId> planExerciseIds;

  /// Exercise ids in user exercise state (favourites and similar).
  final Set<ExerciseId> userStateExerciseIds;

  /// Exercise ids found inside `legacy_quarantine.original_json`.
  final Set<ExerciseId> quarantinedExerciseIds;
}

/// The state before a release or a migration, for IC-104, IC-105, IC-106,
/// IC-904 and IC-906.
@immutable
final class PreviousCatalogue {
  const PreviousCatalogue({
    required this.exercises,
    this.relationships = const [],
    this.content = const [],
    this.media = const [],
    this.anatomy = const [],
    this.patterns = const [],
    this.equipment = const [],
    this.ledger = const [],
  });

  final List<CatalogueExercise> exercises;
  final List<ExerciseRelationship> relationships;
  final List<ContentSection> content;
  final List<MediaReference> media;
  final List<AnatomyNode> anatomy;
  final List<MovementPattern> patterns;
  final List<EquipmentItem> equipment;
  final List<LedgerEntry> ledger;
}

/// Options of the integrity run.
@immutable
final class IntegrityOptions {
  const IntegrityOptions({
    this.patternsMissingIsError = true,
    this.missingContentIsError = false,
    this.completeTranches = const {},
    this.includeCoverageFindings = false,
    this.duplicates = const DuplicateOptions(),
    this.inProgressTranches = const {},
  });

  /// IC-205: error, or warning before a tranche is in progress.
  final bool patternsMissingIsError;

  /// IC-210: error once the exercise's tranche is complete.
  final bool missingContentIsError;

  /// Tranches marked `complete`: their open coverage gaps are errors (IC-950).
  final Set<String> completeTranches;

  /// Tranches marked `inProgress`, listed in the report summary.
  final Set<String> inProgressTranches;

  /// When true, open coverage gaps outside complete tranches are listed as
  /// IC-950 infos; otherwise the coverage section carries the figures only.
  final bool includeCoverageFindings;
  final DuplicateOptions duplicates;
}

/// Everything the integrity checks read. All of it is in memory: reference
/// data, exercises, relationships, content, media, providers, ids from user
/// data and history, and the previous state. Nothing is read from a database
/// or a file.
@immutable
final class IntegrityInput {
  const IntegrityInput({
    required this.anatomy,
    required this.patterns,
    required this.equipment,
    required this.exercises,
    this.relationships = const [],
    this.content = const [],
    this.media = const [],
    this.providers = const [],
    this.userStates = const [],
    this.release,
    this.contentHash,
    this.previous,
    this.retirements = const [],
    this.retiredExerciseLedger = const {},
    this.ledger,
    this.coverage,
    this.history,
    this.systemRowsBefore,
    this.acceptedGaps = AcceptedGaps.none,
    this.options = const IntegrityOptions(),
  });

  final List<AnatomyNode> anatomy;
  final List<MovementPattern> patterns;
  final List<EquipmentItem> equipment;
  final List<CatalogueExercise> exercises;
  final List<ExerciseRelationship> relationships;
  final List<ContentSection> content;
  final List<MediaReference> media;
  final List<ContentProvider> providers;
  final List<UserExerciseState> userStates;
  final ReleaseId? release;
  final String? contentHash;

  /// The previous release (IC-104 to IC-106, IC-808).
  final PreviousCatalogue? previous;
  final List<Retirement> retirements;

  /// Ids of exercises retired in earlier releases (IC-111).
  final Set<ExerciseId> retiredExerciseLedger;

  /// The reference ledger (IC-810).
  final List<LedgerEntry>? ledger;

  /// The coverage specification (IC-811, IC-950).
  final CoverageSpec? coverage;

  /// Ids referenced from user data and history (IC-901 to IC-907).
  final ExerciseReferences? history;

  /// The system exercise ids and the row count before applying a release
  /// (IC-904, IC-906): `(systemIds, rowCount)`.
  final ({Set<ExerciseId> systemIds, int rowCount})? systemRowsBefore;
  final AcceptedGaps acceptedGaps;
  final IntegrityOptions options;
}

/// How an IC check is evaluated by this implementation.
enum CheckEvaluation {
  /// Always evaluated on the input.
  always,

  /// Evaluated when the optional input it needs is present.
  withInput,

  /// The rule is enforced by the types of the model; the raw-file form of the
  /// check belongs to the release parser (3c).
  byType,
}

/// A registered check: code, title, default severity and how it is evaluated.
@immutable
final class IntegrityCheck {
  const IntegrityCheck(
    this.code,
    this.title,
    this.severity,
    this.evaluation, {
    this.needs,
  });

  final String code;
  final String title;
  final Severity severity;
  final CheckEvaluation evaluation;

  /// For [CheckEvaluation.withInput]: which input enables it.
  final String? needs;
}

/// Every check of `quality-and-duplicates.md` plus the editorial rules ED-501
/// (functional double tags), ED-701 (content for an unknown exercise), ED-702
/// (incomplete media reference) and ED-901 (stale accepted-gaps entry).
///
/// **What 3a evaluates and what is left for 3b and 3c.** Every IC check is
/// evaluated here on in-memory input; nothing reads a database or a file.
/// Checks that need data this stage does not hold run when the input is
/// supplied (`CheckEvaluation.withInput`), and are reported `notEvaluated`
/// otherwise:
///
/// - IC-104, IC-105, IC-106, IC-110, IC-808: need the previous release.
/// - IC-810, IC-811: need the ledger and the coverage specification.
/// - IC-901, IC-902, IC-907: need the id sets read from `session_sets`,
///   `session_exercises`, `plan_exercises`, user state and
///   `legacy_quarantine`. **Evaluated in 3b**, which reads the tables (IC-903
///   and IC-905 read the catalogue itself and always run).
/// - IC-904, IC-906: need the system ids and the row count before applying a
///   release. **Evaluated in 3b/3c** (reconciler).
/// - IC-950: needs the coverage specification; the tranche statuses
///   (`planned`, `inProgress`, `complete`) come from release metadata in 3c.
///
/// Rules enforced by the types of the model (`CheckEvaluation.byType`):
/// IC-202 and IC-203 (the `ExerciseType` and `ExerciseCategory` enums), IC-206
/// (the equipment list is never null) and the enum half of IC-308 (mechanics,
/// laterality, difficulty, relationship kinds, equipment roles). The raw-file
/// form of these checks (an unknown string in a release file) belongs to the
/// release parser of 3c. Content section kinds and attribute values are text,
/// so IC-308 and IC-316 are checked on the values here.
///
/// Not in 3a: the content hash of a release (`sha256`, 3c), loading the
/// accepted-gaps file from the repository (3c; the format is parsed and
/// applied here) and the migration report (3b; `quality-and-duplicates.md`
/// section 4).
const List<IntegrityCheck> integrityChecks = [
  IntegrityCheck(
    'IC-101',
    'Exercise id pattern',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-102',
    'Ids unique',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-103',
    'Revision at least 1',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-104',
    'Revision never lowers',
    Severity.error,
    CheckEvaluation.withInput,
    needs: 'previous',
  ),
  IntegrityCheck(
    'IC-105',
    'Changed content needs a higher revision',
    Severity.error,
    CheckEvaluation.withInput,
    needs: 'previous',
  ),
  IntegrityCheck(
    'IC-106',
    'Revision raised, content unchanged',
    Severity.warning,
    CheckEvaluation.withInput,
    needs: 'previous',
  ),
  IntegrityCheck(
    'IC-110',
    'Previous ids present or retired',
    Severity.error,
    CheckEvaluation.withInput,
    needs: 'previous',
  ),
  IntegrityCheck(
    'IC-111',
    'Retired ids never reappear',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-112',
    'Retirement reason and replacement',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-201',
    'Name en-GB 1 to 60 characters',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-202',
    'Logging type valid',
    Severity.error,
    CheckEvaluation.byType,
  ),
  IntegrityCheck(
    'IC-203',
    'Category valid',
    Severity.error,
    CheckEvaluation.byType,
  ),
  IntegrityCheck(
    'IC-204',
    'At least one primary target',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-205',
    'At least one pattern',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-206',
    'Equipment list present',
    Severity.error,
    CheckEvaluation.byType,
  ),
  IntegrityCheck(
    'IC-207',
    'Mechanics present (not cardio, mobility)',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-208',
    'Laterality present',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-209',
    'Difficulty present',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-210',
    'Four instruction sections',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-211',
    'Aliases present',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-212',
    'Provider registered, author recorded',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-301',
    'Target node exists',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-302',
    'Node once per exercise',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-303',
    'No node with its ancestor or descendant',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-304',
    'fullBody rules (ADR-0010)',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-305',
    'Primary not repeated as secondary',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-306',
    'Pattern exists and is a leaf',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-307',
    'Equipment exists',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-308',
    'Enum values valid',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-309',
    'Ordinals contiguous from 0',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-310',
    'Too many targets',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-311',
    'Category and pattern family',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-312',
    'Logging type and pattern',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-313',
    'No retired reference from an active exercise',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-314',
    'Non-anatomical node with a category',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-315',
    'Equipment role override note',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-316',
    'Attribute value in the controlled list',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-401',
    'No self-reference',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-402',
    'Both ends exist',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-403',
    'No duplicate relationship',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-404',
    'No inverse duplicate, normalised',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-405',
    'variationOf is a forest to roots',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-407',
    'progressionOf acyclic',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-408',
    'unilateralCounterpartOf laterality',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-409',
    'alternativeTo inside a family',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-410',
    'variationOf pair unrelated',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-411',
    'Unilateral entry with bilateral twin',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-412',
    'Probable variation without family link',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-413',
    'Relationship to a retired exercise',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-414',
    'Progression chain over 6 steps',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-501',
    'Normalised names unique',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-502',
    'Squashed names unique',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-503',
    'Alias collisions',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-504',
    'Alias equals own name',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-505',
    'Alias count and length',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-506',
    'Blocked words',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-507',
    'Sentence case and UK spelling',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-508',
    'Names within edit distance 2',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-509',
    'UK/US synonym names',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-601',
    'Probable duplicate',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-602',
    'Close match',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck('IC-603', 'Similar', Severity.info, CheckEvaluation.always),
  IntegrityCheck(
    'IC-701',
    'Item length',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-702',
    'Item counts per section',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-703',
    'Sentence over 20 words',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-704',
    'Medical or outcome claims',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-705',
    'Prescription numbers',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-706',
    'US spelling or non-metric units',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-707',
    'Possible passive voice',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-708',
    'Near-identical items',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-709',
    'Locale without en-GB counterpart',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-710',
    'Mistake without a fix',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-801',
    'Anatomy hierarchy',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-802',
    'Sibling sort unique',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-803',
    'fullBody node',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-804',
    '19 preserved ids',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-805',
    'Pattern hierarchy',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-806',
    '21 existing equipment ids',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-807',
    'Reference texts present',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-808',
    'No removed or moved reference id',
    Severity.error,
    CheckEvaluation.withInput,
    needs: 'previous',
  ),
  IntegrityCheck(
    'IC-809',
    'Labels unique',
    Severity.warning,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-810',
    'Reference ledger',
    Severity.error,
    CheckEvaluation.withInput,
    needs: 'ledger',
  ),
  IntegrityCheck(
    'IC-811',
    'Coverage references resolve',
    Severity.error,
    CheckEvaluation.withInput,
    needs: 'coverage',
  ),
  IntegrityCheck(
    'IC-901',
    'Session references resolve',
    Severity.error,
    CheckEvaluation.withInput,
    needs: 'history',
  ),
  IntegrityCheck(
    'IC-902',
    'Plan and state references resolve',
    Severity.error,
    CheckEvaluation.withInput,
    needs: 'history',
  ),
  IntegrityCheck(
    'IC-903',
    'copied_from_id resolves',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-904',
    'System exercises never deleted',
    Severity.error,
    CheckEvaluation.withInput,
    needs: 'systemRowsBefore',
  ),
  IntegrityCheck(
    'IC-905',
    'User relationship ends resolve',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'IC-906',
    'Row count never decreases',
    Severity.error,
    CheckEvaluation.withInput,
    needs: 'systemRowsBefore',
  ),
  IntegrityCheck(
    'IC-907',
    'Unresolved ids in quarantine',
    Severity.info,
    CheckEvaluation.withInput,
    needs: 'history',
  ),
  IntegrityCheck(
    'IC-950',
    'Coverage gaps',
    Severity.info,
    CheckEvaluation.withInput,
    needs: 'coverage',
  ),
  IntegrityCheck(
    'ED-501',
    'Functional double tags',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'ED-701',
    'Content for an unknown exercise',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'ED-702',
    'Media reference complete',
    Severity.error,
    CheckEvaluation.always,
  ),
  IntegrityCheck(
    'ED-901',
    'Stale accepted-gaps entry',
    Severity.info,
    CheckEvaluation.always,
  ),
];

/// Outcome of one registered check in a report.
@immutable
final class CheckResult {
  const CheckResult({
    required this.code,
    required this.title,
    required this.severity,
    required this.status,
    required this.count,
  });

  final String code;
  final String title;
  final Severity severity;

  /// `passed`, `failed` (an error), `warned` (warnings only), `reported`
  /// (infos only), `enforcedByType` or `notEvaluated` (its input is absent).
  final String status;
  final int count;
}

/// The structured integrity report (`quality-and-duplicates.md` section 3).
@immutable
final class IntegrityReport {
  const IntegrityReport({
    required this.provider,
    required this.release,
    required this.contentHash,
    required this.exerciseCount,
    required this.retiredCount,
    required this.anatomyNodes,
    required this.patterns,
    required this.equipment,
    required this.tranches,
    required this.checks,
    required this.findings,
    required this.duplicatePairs,
    required this.families,
    required this.maxDepth,
    required this.longestProgression,
    required this.cycles,
    required this.retirements,
    required this.coverage,
  });

  final String? provider;
  final int? release;
  final String? contentHash;
  final int exerciseCount;
  final int retiredCount;
  final int anatomyNodes;
  final int patterns;
  final int equipment;
  final Map<String, String> tranches;
  final List<CheckResult> checks;

  /// Every finding in deterministic order, with dispositions applied.
  final List<Finding> findings;
  final List<DuplicatePair> duplicatePairs;
  final int families;
  final int maxDepth;
  final int longestProgression;
  final int cycles;
  final List<Retirement> retirements;
  final CoverageReport? coverage;

  List<Finding> bySeverity(Severity s) => [
    for (final f in findings)
      if (f.severity == s) f,
  ];

  int get errors => bySeverity(Severity.error).length;
  int get warnings => bySeverity(Severity.warning).length;
  int get infos => bySeverity(Severity.info).length;

  /// True when there is no error: the release may be applied.
  bool get passed => errors == 0;

  /// Count of findings per check code.
  Map<String, int> get countsByCode {
    final m = <String, int>{};
    for (final f in findings) {
      m.update(f.code, (n) => n + 1, ifAbsent: () => 1);
    }
    return Map.fromEntries(
      m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  List<Finding> findingsFor(String code) => [
    for (final f in findings)
      if (f.code == code) f,
  ];

  /// The JSON form. Deterministic: the same input gives the same map.
  Map<String, Object?> toJson() => {
    'schema': integrityReportSchema,
    'catalogue': {
      'provider': provider,
      'release': release,
      'contentHash': contentHash,
      'exercises': exerciseCount,
      'retired': retiredCount,
    },
    'referenceData': {
      'anatomyNodes': anatomyNodes,
      'patterns': patterns,
      'equipment': equipment,
    },
    'summary': {
      'errors': errors,
      'warnings': warnings,
      'infos': infos,
      'tranches': tranches,
    },
    'checks': [
      for (final c in checks)
        {
          'code': c.code,
          'severity': c.severity.name,
          'status': c.status,
          'count': c.count,
        },
    ],
    'findings': [
      for (final f in findings)
        {
          'code': f.code,
          'severity': f.severity.name,
          'exerciseId': f.subjectId,
          'field': f.field,
          'message': f.message,
          'related': f.related,
          'disposition': f.disposition,
        },
    ],
    'duplicates': {
      'pairs': [
        for (final p in duplicatePairs)
          {
            'a': p.a.value,
            'b': p.b.value,
            'score': double.parse(p.score.toStringAsFixed(3)),
            'cleared': p.cleared,
          },
      ],
    },
    'relationships': {
      'families': families,
      'maxDepth': maxDepth,
      'longestProgression': longestProgression,
      'cycles': cycles,
    },
    'retirements': [
      for (final r in retirements)
        {
          'id': r.id.value,
          'reason': r.reason,
          'replacedBy': r.replacedBy?.value,
        },
    ],
    'coverage': coverage == null
        ? null
        : {
            'slotRequired': coverage!.slotRequired,
            'slotFilled': coverage!.slotFilled,
            'setRequired': coverage!.setRequired,
            'setFilled': coverage!.setFilled,
            'openGaps': coverage!.openGaps.length,
          },
  };

  /// The JSON text of [toJson].
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// The Markdown form for people: header, summary table, errors, warnings by
  /// code with exercise ids, duplicate pairs, retirements, coverage summary.
  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# Integrity report')
      ..writeln()
      ..writeln(
        'Catalogue: ${provider ?? '-'} release ${release ?? '-'}, '
        '$exerciseCount exercises ($retiredCount retired), '
        'content hash ${contentHash ?? '-'}.',
      )
      ..writeln(
        'Reference data: $anatomyNodes anatomy nodes, $patterns movement '
        'patterns, $equipment equipment items.',
      )
      ..writeln()
      ..writeln('| Errors | Warnings | Infos |')
      ..writeln('|---|---|---|')
      ..writeln('| $errors | $warnings | $infos |')
      ..writeln();
    void section(String title, List<Finding> list) {
      b.writeln('## $title');
      if (list.isEmpty) {
        b
          ..writeln('None.')
          ..writeln();
        return;
      }
      final byCode = <String, List<Finding>>{};
      for (final f in list) {
        byCode.putIfAbsent(f.code, () => []).add(f);
      }
      for (final e in byCode.entries) {
        b.writeln('### ${e.key} (${e.value.length})');
        for (final f in e.value) {
          final disp = f.disposition == null ? '' : ' [${f.disposition}]';
          b.writeln('- `${f.subjectId ?? '-'}`: ${f.message}$disp');
        }
      }
      b.writeln();
    }

    section('Errors', bySeverity(Severity.error));
    section('Warnings', bySeverity(Severity.warning));
    b.writeln('## Duplicate pairs');
    if (duplicatePairs.isEmpty) {
      b.writeln('None.');
    } else {
      b
        ..writeln('| A | B | Score | Band | Cleared |')
        ..writeln('|---|---|---|---|---|');
      for (final p in duplicatePairs) {
        b.writeln(
          '| ${p.a} | ${p.b} | ${p.score.toStringAsFixed(3)} | '
          '${p.band.name} | ${p.cleared ? 'yes' : 'no'} |',
        );
      }
    }
    b
      ..writeln()
      ..writeln('## Retirements');
    if (retirements.isEmpty) {
      b.writeln('None.');
    } else {
      for (final r in retirements) {
        b.writeln('- ${r.id}: ${r.reason}');
      }
    }
    final c = coverage;
    b
      ..writeln()
      ..writeln('## Coverage');
    if (c == null) {
      b.writeln('Not evaluated.');
    } else {
      b.writeln(
        'Slots filled ${c.slotFilled} of ${c.slotRequired}; conditioning, '
        'power and mobility entries ${c.setFilled} of ${c.setRequired}; '
        '${c.openGaps.length} open gap rows.',
      );
    }
    return b.toString();
  }
}

/// Runs every check that can be evaluated on [input] and returns the report.
///
/// Order: reference data, then per-exercise schema and references, identity
/// and revisions, the relationship graph, names, near-duplicates, content and
/// media, references from history, coverage. Every finding is listed even
/// after the first error. No network, no randomness, no clock.
IntegrityReport runIntegrityChecks(IntegrityInput input) {
  final findings = <Finding>[];
  final opts = input.options;
  final reference = ReferenceData(
    anatomy: AnatomyTree(input.anatomy),
    patterns: PatternTree(input.patterns),
    equipment: EquipmentCatalogue(input.equipment),
  );
  final evaluated = <String>{};

  // Reference data (IC-801 to IC-811).
  findings
    ..addAll(validateAnatomy(input.anatomy))
    ..addAll(validatePreservedAnatomy(reference.anatomy))
    ..addAll(validatePatterns(input.patterns))
    ..addAll(validateEquipmentItems(input.equipment))
    ..addAll(
      validateReferenceTexts(anatomy: input.anatomy, patterns: input.patterns),
    )
    ..addAll(
      validateReferenceLabels(
        anatomy: input.anatomy,
        patterns: input.patterns,
        equipment: input.equipment,
      ),
    );
  final previous = input.previous;
  if (previous != null) {
    evaluated.addAll(['previous']);
    findings.addAll(
      validateReferenceAgainstPrevious(
        previousAnatomy: previous.anatomy,
        anatomy: input.anatomy,
        previousPatterns: previous.patterns,
        patterns: input.patterns,
        previousEquipment: previous.equipment,
        equipment: input.equipment,
      ),
    );
  }
  final ledger = input.ledger;
  if (ledger != null) {
    evaluated.add('ledger');
    findings.addAll(
      validateLedger(
        ledger: ledger,
        anatomy: input.anatomy,
        patterns: input.patterns,
        equipment: input.equipment,
        previousLedger: previous?.ledger ?? const [],
      ),
    );
  }
  final spec = input.coverage;
  if (spec != null) {
    evaluated.add('coverage');
    findings.addAll(validateCoverageSpec(spec, reference));
  }

  // Exercises.
  final ctx = ExerciseRuleContext(
    reference: reference,
    providers: input.providers.isEmpty
        ? null
        : {for (final p in input.providers) p.id},
    patternsMissingIsError: opts.patternsMissingIsError,
  );
  for (final e in input.exercises) {
    findings.addAll(validateExercise(e, ctx));
  }
  findings.addAll(_identity(input, evaluated));

  // Relationships.
  final analysis = analyseRelationships(input.exercises, input.relationships);
  // Names, duplicates, content, media.
  findings
    ..addAll(analysis.findings)
    ..addAll(validateNames(input.exercises))
    ..addAll(
      validateContent(
        input.exercises,
        input.content,
        missingContentIsError: opts.missingContentIsError,
      ),
    )
    ..addAll(_media(input));
  final dispositions = input.acceptedGaps.duplicateDispositions(
    release: input.release?.number,
  );
  final duplicates = detectDuplicates(
    exercises: input.exercises,
    reference: reference,
    relationships: input.relationships,
    familyRoots: analysis.familyRoots,
    dispositions: dispositions,
    options: opts.duplicates,
  );
  // References from history (IC-900).
  findings
    ..addAll(duplicates.findings)
    ..addAll(_references(input, evaluated));

  // Coverage (IC-950).
  CoverageReport? coverage;
  if (spec != null) {
    coverage = evaluateCoverage(
      spec: spec,
      reference: reference,
      exercises: input.exercises,
      familyRoots: analysis.familyRoots,
    );
  }
  var rows = coverage?.rows ?? const <GapRow>[];
  final applied = input.acceptedGaps.apply(
    findings,
    rows,
    release: input.release?.number,
  );
  var all = applied.findings;
  rows = applied.rows;
  if (coverage != null) {
    coverage = CoverageReport(
      rows: rows,
      groups: coverage.groups,
      sets: coverage.sets,
    );
    for (final r in rows.where((r) => r.isOpen)) {
      final complete = opts.completeTranches.contains(r.tranche);
      if (complete || opts.includeCoverageFindings) {
        all = [
          ...all,
          Finding(
            code: 'IC-950',
            severity: complete ? Severity.error : Severity.info,
            message:
                '${r.group} ${r.dimension.name} ${r.item}: required '
                '${r.required}, actual ${r.actual}.',
            subjectId: r.group,
            field: r.dimension.name,
          ),
        ];
      }
    }
  }
  final sorted = sortedFindings(all);

  final active = input.exercises.where((e) => e.isActive).length;
  return IntegrityReport(
    provider: input.release?.provider.value,
    release: input.release?.number,
    contentHash: input.contentHash,
    exerciseCount: active,
    retiredCount: input.exercises.length - active,
    anatomyNodes: reference.anatomy.length,
    patterns: reference.patterns.length,
    equipment: reference.equipment.length,
    tranches: {
      for (final t in opts.inProgressTranches) t: 'inProgress',
      for (final t in opts.completeTranches) t: 'complete',
    },
    checks: _checkResults(sorted, evaluated, input),
    findings: sorted,
    duplicatePairs: duplicates.pairs,
    families: analysis.families,
    maxDepth: analysis.maxDepth,
    longestProgression: analysis.longestProgression,
    cycles: analysis.cycles,
    retirements: input.retirements,
    coverage: coverage,
  );
}

List<CheckResult> _checkResults(
  List<Finding> findings,
  Set<String> evaluated,
  IntegrityInput input,
) {
  final byCode = <String, List<Finding>>{};
  for (final f in findings) {
    byCode.putIfAbsent(f.code, () => []).add(f);
  }
  return [
    for (final c in integrityChecks)
      () {
        final list = byCode[c.code] ?? const <Finding>[];
        final String status;
        if (c.evaluation == CheckEvaluation.byType && list.isEmpty) {
          status = 'enforcedByType';
        } else if (c.evaluation == CheckEvaluation.withInput &&
            !evaluated.contains(c.needs)) {
          status = 'notEvaluated';
        } else if (list.any((f) => f.severity == Severity.error)) {
          status = 'failed';
        } else if (list.any((f) => f.severity == Severity.warning)) {
          status = 'warned';
        } else if (list.isNotEmpty) {
          status = 'reported';
        } else {
          status = 'passed';
        }
        return CheckResult(
          code: c.code,
          title: c.title,
          severity: c.severity,
          status: status,
          count: list.length,
        );
      }(),
  ];
}

/// Fingerprint of the system-owned content of an exercise, for IC-105 and
/// IC-106: classifications, names, targets, patterns, equipment, attributes,
/// content, media and outgoing relationships.
String _fingerprint(
  CatalogueExercise e,
  Iterable<ContentSection> content,
  Iterable<MediaReference> media,
  Iterable<ExerciseRelationship> relationships,
) {
  final b = StringBuffer()
    ..write(e.id)
    ..write('|${e.type.name}|${e.category.name}')
    ..write(
      '|${e.mechanics?.name}|${e.laterality?.name}|${e.difficulty?.name}',
    );
  for (final MapEntry(key: locale, value: n)
      in (e.names.byLocale.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)))) {
    b.write('|n:$locale:${n.name}:${n.aliases.join(',')}');
  }
  for (final t in e.targets) {
    b.write('|t:${t.node}:${t.role.name}:${t.ordinal}');
  }
  b.write('|p:${e.patterns.join(',')}');
  for (final u in e.equipment) {
    b.write('|e:${u.item}:${u.roleOverride?.name}:${u.overrideNote}');
  }
  final attrs = e.attributes.entries.toList()
    ..sort((a, b) => a.key.index.compareTo(b.key.index));
  for (final a in attrs) {
    b.write('|a:${a.key.name}=${a.value}');
  }
  final c = content.where((x) => x.exerciseId == e.id).toList()
    ..sort((a, b) {
      final k = '${a.locale}|${a.kind}|${a.ordinal.toString().padLeft(4, '0')}';
      return k.compareTo(
        '${b.locale}|${b.kind}|${b.ordinal.toString().padLeft(4, '0')}',
      );
    });
  for (final x in c) {
    b.write('|c:${x.locale}:${x.kind}:${x.ordinal}:${x.body}');
  }
  final m = media.where((x) => x.exerciseId == e.id).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  for (final x in m) {
    b.write('|m:${x.id}:${x.kind}:${x.locator}:${x.licence}:${x.attribution}');
  }
  final r =
      relationships
          .where((x) => x.from == e.id && x.source == ExerciseSource.system)
          .toList()
        ..sort();
  for (final x in r) {
    b.write('|r:${x.kind.name}:${x.to}');
  }
  return b.toString();
}

List<Finding> _identity(IntegrityInput input, Set<String> evaluated) {
  final out = <Finding>[];
  final ids = <ExerciseId>{};
  final dup = <ExerciseId>{};
  for (final e in input.exercises) {
    if (!ids.add(e.id) && dup.add(e.id)) {
      out.add(
        Finding(
          code: 'IC-102',
          severity: Severity.error,
          message: 'The exercise id ${e.id} is used more than once.',
          subjectId: e.id.value,
        ),
      );
    }
  }
  final byId = {for (final e in input.exercises) e.id: e};
  // IC-111: ids never reappear as active.
  for (final id in input.retiredExerciseLedger) {
    final e = byId[id];
    if (e != null && e.isActive) {
      out.add(
        Finding(
          code: 'IC-111',
          severity: Severity.error,
          message: 'The retired id $id appears again as an active exercise.',
          subjectId: id.value,
        ),
      );
    }
  }
  // IC-112: retirements.
  for (final r in input.retirements) {
    if (r.reason.trim().isEmpty) {
      out.add(
        Finding(
          code: 'IC-112',
          severity: Severity.error,
          message: 'The retirement of ${r.id} names no reason.',
          subjectId: r.id.value,
        ),
      );
    }
    final target = r.replacedBy;
    if (target != null) {
      final replacement = byId[target];
      if (replacement == null || !replacement.isActive) {
        out.add(
          Finding(
            code: 'IC-112',
            severity: Severity.error,
            message:
                'The replacement $target of ${r.id} does not exist or is '
                'not active.',
            subjectId: r.id.value,
            related: [target.value],
          ),
        );
      }
    }
  }
  final previous = input.previous;
  if (previous != null) {
    final retiredIds = {for (final r in input.retirements) r.id};
    final before = {
      for (final e in previous.exercises)
        if (e.isSystem) e.id: e,
    };
    for (final MapEntry(key: id, value: old) in before.entries) {
      final now = byId[id];
      if (now == null) {
        if (!retiredIds.contains(id)) {
          out.add(
            Finding(
              code: 'IC-110',
              severity: Severity.error,
              message:
                  'The previous id $id is absent and not listed under '
                  'retirements.',
              subjectId: id.value,
            ),
          );
        }
        continue;
      }
      final oldRev = old.revision ?? 0;
      final newRev = now.revision ?? 0;
      if (newRev < oldRev) {
        out.add(
          Finding(
            code: 'IC-104',
            severity: Severity.error,
            message: 'The revision of $id lowered from $oldRev to $newRev.',
            subjectId: id.value,
            field: 'revision',
          ),
        );
        continue;
      }
      final changed =
          _fingerprint(
            old,
            previous.content,
            previous.media,
            previous.relationships,
          ) !=
          _fingerprint(now, input.content, input.media, input.relationships);
      if (changed && newRev <= oldRev) {
        out.add(
          Finding(
            code: 'IC-105',
            severity: Severity.error,
            message:
                'System-owned content of $id changed without a higher '
                'revision.',
            subjectId: id.value,
            field: 'revision',
          ),
        );
      }
      if (!changed && newRev > oldRev) {
        out.add(
          Finding(
            code: 'IC-106',
            severity: Severity.warning,
            message: 'The revision of $id was raised but nothing changed.',
            subjectId: id.value,
            field: 'revision',
          ),
        );
      }
    }
  }
  final before = input.systemRowsBefore;
  if (before != null) {
    evaluated.add('systemRowsBefore');
    for (final id in before.systemIds) {
      if (!byId.containsKey(id)) {
        out.add(
          Finding(
            code: 'IC-904',
            severity: Severity.error,
            message: 'The system exercise $id was deleted; retire it instead.',
            subjectId: id.value,
          ),
        );
      }
    }
    if (input.exercises.length < before.rowCount) {
      out.add(
        Finding(
          code: 'IC-906',
          severity: Severity.error,
          message:
              'The row count fell from ${before.rowCount} to '
              '${input.exercises.length}; nothing may be deleted.',
        ),
      );
    }
  }
  return out;
}

List<Finding> _media(IntegrityInput input) {
  final out = <Finding>[];
  final known = {for (final e in input.exercises) e.id};
  final ids = <String>{};
  for (final m in input.media) {
    void bad(String message) => out.add(
      Finding(
        code: 'ED-702',
        severity: Severity.error,
        message: 'Media ${m.id}: $message',
        subjectId: m.exerciseId.value,
        field: 'media',
      ),
    );
    if (!ids.add(m.id)) bad('the media id is used more than once.');
    if (!known.contains(m.exerciseId)) bad('the exercise does not exist.');
    for (final (name, value) in [
      ('kind', m.kind),
      ('locator', m.locator),
      ('licence', m.licence),
      ('attribution', m.attribution),
    ]) {
      if (value.trim().isEmpty) bad('$name is required.');
    }
  }
  return out;
}

List<Finding> _references(IntegrityInput input, Set<String> evaluated) {
  final out = <Finding>[];
  final known = {for (final e in input.exercises) e.id};
  void missing(String code, Severity s, ExerciseId id, String where) => out.add(
    Finding(
      code: code,
      severity: s,
      message: 'The exercise id $id in $where does not resolve.',
      subjectId: id.value,
      field: where,
    ),
  );
  // IC-903 and IC-905 read the catalogue itself.
  for (final e in input.exercises) {
    final from = e.copiedFromId;
    if (from != null && !known.contains(from)) {
      missing('IC-903', Severity.error, from, 'exercises.copied_from_id');
    }
  }
  for (final r in input.relationships) {
    if (r.source == ExerciseSource.system) continue;
    for (final id in [r.from, r.to]) {
      if (!known.contains(id)) {
        missing('IC-905', Severity.error, id, 'user relationship');
      }
    }
  }
  for (final s in input.userStates) {
    if (!known.contains(s.exerciseId)) {
      missing('IC-902', Severity.error, s.exerciseId, 'user exercise state');
    }
  }
  final h = input.history;
  if (h != null) {
    evaluated.add('history');
    for (final id in h.sessionSetExerciseIds.followedBy(h.sessionExerciseIds)) {
      if (!known.contains(id)) {
        missing(
          'IC-901',
          Severity.error,
          id,
          'session_sets / session_exercises',
        );
      }
    }
    for (final id in h.planExerciseIds.followedBy(h.userStateExerciseIds)) {
      if (!known.contains(id)) {
        missing('IC-902', Severity.error, id, 'plan_exercises / user state');
      }
    }
    for (final id in h.quarantinedExerciseIds) {
      if (!known.contains(id)) {
        missing('IC-907', Severity.info, id, 'legacy_quarantine.original_json');
      }
    }
  }
  return out;
}
