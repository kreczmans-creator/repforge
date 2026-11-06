import 'package:meta/meta.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/exercise_relationship.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/text_normalisation.dart';
import 'package:repforge/domain/training/training.dart'
    show ExerciseCategory, ExerciseType;

/// How IC-412 treats the name-token gate when recorded attributes differ.
///
/// The three readings differ on the approved seed:
/// [always] 16 pairs (the documented figure, before X2);
/// [whenAnyAttributeDiffers] 30 pairs (the literal X2 rule: skip the gate when
/// any recorded attribute differs);
/// [whenAttributesDifferAndLoadsEqual] 19 pairs (the narrow rule: skip the
/// gate only for a pair that differs by attributes alone, with equal load
/// items). The owner chose the narrow rule as the default on 2026-11-06.
enum TokenGateRule {
  /// The token share is always required.
  always,

  /// Skip the token gate when any recorded attribute differs (literal X2).
  whenAnyAttributeDiffers,

  /// Skip the token gate only when attributes differ and load items are
  /// equal (narrow X2).
  whenAttributesDifferAndLoadsEqual,
}

/// Weights and thresholds of the structural near-duplicate score (IC-600).
/// The thresholds are the owner-approved starting point (0.95, 0.85, 0.75);
/// the 5.1 pilot may tune them.
@immutable
final class DuplicateOptions {
  const DuplicateOptions({
    this.probableThreshold = 0.95,
    this.closeThreshold = 0.85,
    this.similarThreshold = 0.75,
    this.tokenShareThreshold = 0.4,
    this.tokenGate = TokenGateRule.whenAttributesDifferAndLoadsEqual,
  });

  /// Score from which a pair is a probable duplicate (IC-601).
  final double probableThreshold;

  /// Score from which a pair is a close match (IC-602).
  final double closeThreshold;

  /// Score from which a pair is similar (IC-603).
  final double similarThreshold;

  /// Share of name tokens (Jaccard) two names must have for IC-412.
  final double tokenShareThreshold;

  /// X2: the IC-412 token gate rule. The default is the narrow rule (19
  /// pairs on release 2), decided by the owner on 2026-11-06
  /// ([TokenGateRule]).
  final TokenGateRule tokenGate;
}

/// The structural signature of one exercise (IC-600 inputs).
@immutable
final class StructuralSignature {
  const StructuralSignature({
    required this.id,
    required this.category,
    required this.type,
    required this.liftedPrimaries,
    required this.primaryPattern,
    required this.loadItems,
    required this.laterality,
    required this.mechanics,
    required this.attributes,
    required this.tokens,
  });

  /// Builds the signature of [e]: primary targets lifted to their level 2
  /// group, only load-role equipment, and the name tokens.
  factory StructuralSignature.of(CatalogueExercise e, ReferenceData ref) =>
      StructuralSignature(
        id: e.id,
        category: e.category,
        type: e.type,
        liftedPrimaries: {
          for (final t in e.primaryTargets) ref.anatomy.lift(t.node),
        },
        primaryPattern: e.primaryPattern,
        loadItems: e.loadItems(ref.equipment),
        laterality: e.laterality,
        mechanics: e.mechanics,
        attributes: e.attributes,
        tokens: nameTokens(e.name),
      );

  final ExerciseId id;
  final ExerciseCategory category;
  final ExerciseType type;
  final Set<AnatomyNodeId> liftedPrimaries;
  final MovementPatternId? primaryPattern;
  final Set<EquipmentItemId> loadItems;
  final Laterality? laterality;
  final Mechanics? mechanics;
  final Map<ExerciseAttribute, String> attributes;
  final Set<String> tokens;

  /// True when both record an attribute and the values differ. An unrecorded
  /// attribute never distinguishes a pair.
  bool distinguishedFrom(StructuralSignature other) {
    for (final MapEntry(key: attribute, :value) in attributes.entries) {
      final theirs = other.attributes[attribute];
      if (theirs != null && theirs != value) return true;
    }
    return false;
  }

  /// The score of the pair (IC-600): 0.25 lifted primaries, 0.20 same primary
  /// pattern, 0.20 load items, 0.05 each laterality, mechanics, logging type
  /// and category, 0.15 name tokens.
  double scoreWith(StructuralSignature o) {
    final samePattern =
        primaryPattern != null && primaryPattern == o.primaryPattern;
    return 0.25 * jaccard(liftedPrimaries, o.liftedPrimaries) +
        0.20 * (samePattern ? 1 : 0) +
        0.20 * jaccard(loadItems, o.loadItems) +
        0.05 * (laterality == o.laterality ? 1 : 0) +
        0.05 * (mechanics == o.mechanics ? 1 : 0) +
        0.05 * (type == o.type ? 1 : 0) +
        0.05 * (category == o.category ? 1 : 0) +
        0.15 * jaccard(tokens, o.tokens);
  }
}

/// Which duplicate band a pair falls in.
enum DuplicateBand {
  /// IC-601, probable duplicate.
  probable,

  /// IC-602, close match.
  close,

  /// IC-603, similar.
  similar,
}

/// A flagged pair of exercises. `a` sorts before `b`.
@immutable
final class DuplicatePair {
  const DuplicatePair({
    required this.a,
    required this.b,
    required this.score,
    required this.band,
    this.disposition,
  });

  final ExerciseId a;
  final ExerciseId b;
  final double score;
  final DuplicateBand band;

  /// Why the pair is cleared: `relationship`, or a recorded disposition.
  final String? disposition;

  bool get cleared => disposition != null;
}

/// The canonical key of an unordered pair, for dispositions.
String duplicatePairKey(ExerciseId a, ExerciseId b) =>
    a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

/// Result of the near-duplicate analysis.
@immutable
final class DuplicateAnalysis {
  const DuplicateAnalysis({
    required this.findings,
    required this.pairs,
    required this.familyLinkCandidates,
    required this.pairsCompared,
  });

  final List<Finding> findings;

  /// IC-601 to IC-603 pairs (not distinguished by attributes), sorted.
  final List<DuplicatePair> pairs;

  /// IC-412 pairs: probable variations without a family link, sorted, each as
  /// `a`, `b` and the structural score.
  final List<({ExerciseId a, ExerciseId b, double score})> familyLinkCandidates;

  /// Number of pairs scored (pairs with the same primary pattern).
  final int pairsCompared;

  List<DuplicatePair> pairsIn(DuplicateBand band) => [
    for (final p in pairs)
      if (p.band == band) p,
  ];
}

/// Detects structural near-duplicates (IC-601 to IC-603) and the family-link
/// rules IC-411 and IC-412 over the active [exercises].
///
/// Only pairs with the same primary pattern are scored: the pattern term is
/// worth 0.20, so a pair with another pattern cannot reach 0.85 (the best it
/// can score is 0.80), and IC-411 and IC-412 require the same pattern. This is
/// exact for the approved weights.
///
/// A pair is *distinguished* (cleared from IC-601 to IC-603 only) when both
/// record an attribute and the values differ. A pair is *cleared* when any
/// relationship joins it or [dispositions] holds a decision for it
/// (`duplicatePairKey`).
///
/// IC-412 (family link): same lifted primaries, primary pattern, laterality
/// and mechanics; not in one `variationOf` family; and load-item sets differ
/// or recorded attributes differ; and the name-token share is at least
/// [DuplicateOptions.tokenShareThreshold], **unless** a recorded attribute
/// differs (X2, [DuplicateOptions.tokenGate]). A recorded
/// attribute difference does not clear IC-412.
DuplicateAnalysis detectDuplicates({
  required Iterable<CatalogueExercise> exercises,
  required ReferenceData reference,
  Iterable<ExerciseRelationship> relationships = const [],
  Map<ExerciseId, ExerciseId> familyRoots = const {},
  Map<String, String> dispositions = const {},
  DuplicateOptions options = const DuplicateOptions(),
}) {
  final sigs = [
    for (final e in exercises)
      if (e.isActive) StructuralSignature.of(e, reference),
  ]..sort((a, b) => a.id.compareTo(b.id));
  final linked = <String>{};
  final counterparts = <String>{};
  for (final r in relationships) {
    final key = duplicatePairKey(r.from, r.to);
    linked.add(key);
    if (r.kind == RelationshipKind.unilateralCounterpartOf) {
      counterparts.add(key);
    }
  }
  final byPattern = <MovementPatternId, List<StructuralSignature>>{};
  for (final s in sigs) {
    final p = s.primaryPattern;
    if (p != null) byPattern.putIfAbsent(p, () => []).add(s);
  }
  final findings = <Finding>[];
  final pairs = <DuplicatePair>[];
  final candidates = <({ExerciseId a, ExerciseId b, double score})>[];
  var compared = 0;
  bool sameLift(StructuralSignature a, StructuralSignature b) =>
      a.liftedPrimaries.length == b.liftedPrimaries.length &&
      a.liftedPrimaries.containsAll(b.liftedPrimaries);

  for (final group in byPattern.values) {
    for (var i = 0; i < group.length; i++) {
      for (var j = i + 1; j < group.length; j++) {
        final a = group[i];
        final b = group[j];
        compared++;
        final score = a.scoreWith(b);
        final distinguished = a.distinguishedFrom(b);
        final key = duplicatePairKey(a.id, b.id);
        final disposition = linked.contains(key)
            ? 'relationship'
            : dispositions[key];
        if (!distinguished) {
          DuplicateBand? band;
          if (score >= options.probableThreshold) {
            band = DuplicateBand.probable;
          } else if (score >= options.closeThreshold) {
            band = DuplicateBand.close;
          } else if (score >= options.similarThreshold) {
            band = DuplicateBand.similar;
          }
          if (band != null) {
            pairs.add(
              DuplicatePair(
                a: a.id,
                b: b.id,
                score: score,
                band: band,
                disposition: disposition,
              ),
            );
            final (code, severity, label) = switch (band) {
              DuplicateBand.probable => (
                'IC-601',
                Severity.warning,
                'probable duplicate',
              ),
              DuplicateBand.close => (
                'IC-602',
                Severity.warning,
                'close match',
              ),
              DuplicateBand.similar => ('IC-603', Severity.info, 'similar'),
            };
            findings.add(
              Finding(
                code: code,
                severity: severity,
                message:
                    '${a.id} and ${b.id} are a $label '
                    '(score ${score.toStringAsFixed(3)}).',
                subjectId: a.id.value,
                field: 'signature',
                related: [b.id.value],
                disposition: disposition,
              ),
            );
          }
        }
        final sameStructure = sameLift(a, b) && a.mechanics == b.mechanics;
        final loadsDiffer =
            !(a.loadItems.length == b.loadItems.length &&
                a.loadItems.containsAll(b.loadItems));
        if (sameStructure && a.laterality == b.laterality) {
          // IC-412.
          final sameFamily =
              familyRoots[a.id] != null &&
              familyRoots[a.id] == familyRoots[b.id];
          if (!sameFamily && (loadsDiffer || distinguished)) {
            final tokens = jaccard(a.tokens, b.tokens);
            final skipGate = switch (options.tokenGate) {
              TokenGateRule.always => false,
              TokenGateRule.whenAnyAttributeDiffers => distinguished,
              TokenGateRule.whenAttributesDifferAndLoadsEqual =>
                distinguished && !loadsDiffer,
            };
            final gateOpen = tokens >= options.tokenShareThreshold || skipGate;
            if (gateOpen) {
              candidates.add((a: a.id, b: b.id, score: score));
              findings.add(
                Finding(
                  code: 'IC-412',
                  severity: Severity.warning,
                  message:
                      '${a.id} and ${b.id} look like variations without a '
                      'family link (score ${score.toStringAsFixed(3)}).',
                  subjectId: a.id.value,
                  field: 'relationships',
                  related: [b.id.value],
                  disposition: dispositions[key],
                ),
              );
            }
          }
        }
        // IC-411: a unilateral or alternating entry with a bilateral twin by
        // structure (same lift, pattern, load items and mechanics).
        final la = a.laterality;
        final lb = b.laterality;
        if (sameStructure &&
            !loadsDiffer &&
            la != null &&
            lb != null &&
            (la == Laterality.bilateral) != (lb == Laterality.bilateral) &&
            !counterparts.contains(key)) {
          findings.add(
            Finding(
              code: 'IC-411',
              severity: Severity.warning,
              message:
                  '${a.id} and ${b.id} are a unilateral entry and its '
                  'bilateral twin without a unilateralCounterpartOf link.',
              subjectId: a.id.value,
              field: 'relationships',
              related: [b.id.value],
              disposition: dispositions[key],
            ),
          );
        }
      }
    }
  }
  pairs.sort((x, y) {
    final c = x.a.compareTo(y.a);
    return c != 0 ? c : x.b.compareTo(y.b);
  });
  candidates.sort((x, y) {
    final c = x.a.compareTo(y.a);
    return c != 0 ? c : x.b.compareTo(y.b);
  });
  return DuplicateAnalysis(
    findings: sortedFindings(findings),
    pairs: List.unmodifiable(pairs),
    familyLinkCandidates: List.unmodifiable(candidates),
    pairsCompared: compared,
  );
}
