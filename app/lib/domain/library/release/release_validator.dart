import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/accepted_gaps.dart';
import 'package:repforge/domain/library/coverage_spec.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/integrity_report.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/reference_parsers.dart';
import 'package:repforge/domain/library/reference_validation.dart';
import 'package:repforge/domain/library/release/release_format.dart';
import 'package:repforge/domain/library/release/release_hash.dart';
import 'package:repforge/domain/library/release/release_parser.dart';

Finding _rf(String code, String message, {String? field}) => Finding(
  code: code,
  severity: Severity.error,
  message: message,
  field: field,
);

/// The approved reference data a release is validated against, parsed from
/// the exact bytes of the approved files, with the hash of each file.
@immutable
final class ApprovedReferenceSet {
  const ApprovedReferenceSet({
    required this.anatomy,
    required this.patterns,
    required this.equipment,
    required this.ledger,
    required this.coverage,
    required this.hashes,
  });

  final AnatomyReference anatomy;
  final PatternReference patterns;
  final EquipmentReference equipment;
  final List<LedgerEntry> ledger;
  final CoverageSpec coverage;

  /// SHA-256 (lowercase hex) of each file's exact bytes.
  final Map<ReleaseReferenceName, String> hashes;

  ReferenceData get data => ReferenceData(
    anatomy: AnatomyTree(anatomy.nodes),
    patterns: PatternTree(patterns.nodes),
    equipment: EquipmentCatalogue(equipment.items),
  );
}

/// Parses the five approved reference files from their exact bytes. Every
/// problem becomes a finding (RF-008 file not supplied, RF-011 unreadable or
/// invalid); [ApprovedReferenceSet] is set when there is none.
({ApprovedReferenceSet? set, List<Finding> findings}) loadApprovedReferenceSet(
  Map<ReleaseReferenceName, List<int>> files,
) {
  final findings = <Finding>[];
  final hashes = <ReleaseReferenceName, String>{};
  final decoded = <ReleaseReferenceName, Object?>{};
  for (final name in ReleaseReferenceName.values) {
    final bytes = files[name];
    if (bytes == null) {
      findings.add(
        _rf(
          'RF-008',
          'The reference file for ${name.wire} was not supplied.',
          field: 'reference.${name.wire}',
        ),
      );
      continue;
    }
    hashes[name] = releaseContentHash(bytes);
    try {
      decoded[name] = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      findings.add(
        _rf(
          'RF-011',
          'The reference file for ${name.wire} is not valid UTF-8 JSON: '
              '${e.message}.',
          field: 'reference.${name.wire}',
        ),
      );
    }
  }
  if (findings.isNotEmpty) return (set: null, findings: findings);

  T? take<T>(ReleaseReferenceName name, Result<T> result) {
    if (result case Ok<T>(:final value)) return value;
    findings.add(
      _rf(
        'RF-011',
        'The reference file for ${name.wire} is invalid: '
            '${(result as Err<T>).error.message}',
        field: 'reference.${name.wire}',
      ),
    );
    return null;
  }

  final anatomy = take(
    ReleaseReferenceName.anatomy,
    parseAnatomyReference(decoded[ReleaseReferenceName.anatomy]),
  );
  final patterns = take(
    ReleaseReferenceName.movementPatterns,
    parsePatternReference(decoded[ReleaseReferenceName.movementPatterns]),
  );
  final equipment = take(
    ReleaseReferenceName.equipment,
    parseEquipmentReference(decoded[ReleaseReferenceName.equipment]),
  );
  final ledger = take(
    ReleaseReferenceName.ledger,
    parseLedger(decoded[ReleaseReferenceName.ledger]),
  );
  final coverage = take(
    ReleaseReferenceName.coverage,
    parseCoverageSpec(decoded[ReleaseReferenceName.coverage]),
  );
  if (anatomy == null ||
      patterns == null ||
      equipment == null ||
      ledger == null ||
      coverage == null) {
    return (set: null, findings: findings);
  }
  return (
    set: ApprovedReferenceSet(
      anatomy: anatomy,
      patterns: patterns,
      equipment: equipment,
      ledger: ledger,
      coverage: coverage,
      hashes: Map.unmodifiable(hashes),
    ),
    findings: findings,
  );
}

/// A release that passed validation: the only input the planner accepts. It
/// can be created by [validateRelease] and nowhere else.
@immutable
final class ValidatedRelease {
  const ValidatedRelease._({
    required this.document,
    required this.contentHash,
    required this.reference,
    required this.report,
  });

  final ReleaseDocument document;

  /// SHA-256 of the exact bundled bytes, lowercase hex (R-10).
  final String contentHash;
  final ApprovedReferenceSet reference;
  final IntegrityReport report;
}

/// The outcome of validating a release: the complete list of findings, and a
/// [release] exactly when none of them is an error.
@immutable
final class ReleaseValidation {
  const ReleaseValidation({
    required this.findings,
    this.release,
    this.report,
    this.contentHash,
  });

  final List<Finding> findings;
  final ValidatedRelease? release;

  /// The integrity report; null when the release could not be parsed.
  final IntegrityReport? report;
  final String? contentHash;

  bool get isValid => release != null;

  List<Finding> get errors => [
    for (final f in findings)
      if (f.severity == Severity.error) f,
  ];
}

/// Parses and validates the exact bytes of a release (all or nothing). A
/// release that cannot be parsed reports its parse findings; the catalogue
/// checks need a document and run once it parses.
ReleaseValidation validateReleaseBytes({
  required List<int> bytes,
  required ApprovedReferenceSet reference,
  String? expectedContentHash,
  PreviousCatalogue? previous,
  Set<ExerciseId> retiredExerciseLedger = const {},
  AcceptedGaps acceptedGaps = AcceptedGaps.none,
  IntegrityOptions options = const IntegrityOptions(),
}) {
  final parsed = parseReleaseBytes(bytes);
  final document = parsed.document;
  if (document == null) {
    return ReleaseValidation(
      findings: parsed.findings,
      contentHash: parsed.contentHash,
    );
  }
  return validateRelease(
    document: document,
    contentHash: parsed.contentHash!,
    reference: reference,
    expectedContentHash: expectedContentHash,
    previous: previous,
    retiredExerciseLedger: retiredExerciseLedger,
    acceptedGaps: acceptedGaps,
    options: options,
  );
}

/// Validates a parsed release against the approved reference data, reusing
/// the 3a integrity checks. All or nothing: the result carries every finding
/// and a [ValidatedRelease] only when no finding is an error.
ReleaseValidation validateRelease({
  required ReleaseDocument document,
  required String contentHash,
  required ApprovedReferenceSet reference,
  String? expectedContentHash,
  PreviousCatalogue? previous,
  Set<ExerciseId> retiredExerciseLedger = const {},
  AcceptedGaps acceptedGaps = AcceptedGaps.none,
  IntegrityOptions options = const IntegrityOptions(),
}) {
  final findings = <Finding>[];
  if (expectedContentHash != null && expectedContentHash != contentHash) {
    findings.add(
      _rf(
        'RF-010',
        'The content hash is $contentHash; $expectedContentHash was expected.',
      ),
    );
  }
  for (final name in ReleaseReferenceName.values) {
    final declared = document.reference[name];
    final actual = reference.hashes[name];
    if (declared != null && declared.sha256 != actual) {
      findings.add(
        _rf(
          'RF-008',
          'The release declares ${declared.sha256} for ${name.wire} but the '
              'approved file hashes to ${actual ?? 'nothing (not supplied)'}.',
          field: 'reference.${name.wire}',
        ),
      );
    }
  }
  final providers = {
    ReleaseReferenceName.anatomy: reference.anatomy.provider,
    ReleaseReferenceName.movementPatterns: reference.patterns.provider,
    ReleaseReferenceName.equipment: reference.equipment.provider,
  };
  for (final e in providers.entries) {
    if (e.value != document.provider.id) {
      findings.add(
        _rf(
          'RF-009',
          'The ${e.key.wire} reference file belongs to provider ${e.value} '
              'but the release belongs to ${document.provider.id}.',
          field: 'reference.${e.key.wire}',
        ),
      );
    }
  }

  final report = runIntegrityChecks(
    IntegrityInput(
      anatomy: reference.anatomy.nodes,
      patterns: reference.patterns.nodes,
      equipment: reference.equipment.items,
      exercises: document.exercises,
      relationships: document.relationships,
      content: document.content,
      media: document.media,
      providers: [document.provider],
      release: document.release,
      contentHash: contentHash,
      previous: previous,
      retirements: document.retirements,
      retiredExerciseLedger: retiredExerciseLedger,
      ledger: reference.ledger,
      coverage: reference.coverage,
      acceptedGaps: acceptedGaps,
      options: IntegrityOptions(
        patternsMissingIsError: options.patternsMissingIsError,
        missingContentIsError: options.missingContentIsError,
        completeTranches: {
          ...options.completeTranches,
          for (final t in document.tranches.entries)
            if (t.value == 'complete') t.key,
        },
        inProgressTranches: {
          ...options.inProgressTranches,
          for (final t in document.tranches.entries)
            if (t.value == 'inProgress') t.key,
        },
        includeCoverageFindings: options.includeCoverageFindings,
        duplicates: options.duplicates,
      ),
    ),
  );
  findings.addAll(report.findings);
  final sorted = sortedFindings(findings);
  final valid = !sorted.any((f) => f.severity == Severity.error);
  return ReleaseValidation(
    findings: sorted,
    report: report,
    contentHash: contentHash,
    release: valid
        ? ValidatedRelease._(
            document: document,
            contentHash: contentHash,
            reference: reference,
            report: report,
          )
        : null,
  );
}

/// What the next release of the same provider is compared with: this
/// release's catalogue and reference data (IC-104, IC-105, IC-110, IC-801 to
/// IC-811).
PreviousCatalogue previousCatalogueOf(ValidatedRelease release) =>
    PreviousCatalogue(
      exercises: release.document.exercises,
      relationships: release.document.relationships,
      content: release.document.content,
      media: release.document.media,
      anatomy: release.reference.anatomy.nodes,
      patterns: release.reference.patterns.nodes,
      equipment: release.reference.equipment.items,
      ledger: release.reference.ledger,
    );
