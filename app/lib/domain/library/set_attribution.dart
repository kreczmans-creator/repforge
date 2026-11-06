import 'package:meta/meta.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';

/// The wording that accompanies every per-muscle figure (OQ-19, approved and
/// confirmed 2026-11-05): the figures attribute recorded sets to targets; they
/// are not physiological measurements of muscle stimulus. Reports and
/// documentation show the distinction.
const String attributedSetCountsNotice =
    'Attributed set counts, not physiological measurements of muscle '
    'stimulus. A primary muscle receives full attribution of each recorded '
    'exercise set; a secondary muscle is reported separately and excluded '
    'from primary totals.';

/// One exercise with the sets recorded for it, the input of the attribution.
@immutable
final class AttributedExercise {
  const AttributedExercise({
    required this.targets,
    required this.sets,
    this.volumeKg = 0,
  });

  /// The exercise's targets.
  final List<ExerciseTarget> targets;

  /// Recorded working sets of the exercise (the caller applies the WP 9 rules
  /// for which sets count: warm-up sets are excluded upstream).
  final int sets;

  /// Volume in kg of those sets (TRN-027(3)); attributed like the sets.
  final double volumeKg;
}

/// Sets and kg volume attributed to one node.
@immutable
final class AttributedTotals {
  const AttributedTotals(this.sets, this.volumeKg);

  final int sets;
  final double volumeKg;

  AttributedTotals plus(int moreSets, double moreVolume) =>
      AttributedTotals(sets + moreSets, volumeKg + moreVolume);

  @override
  bool operator ==(Object other) =>
      other is AttributedTotals &&
      other.sets == sets &&
      other.volumeKg == volumeKg;

  @override
  int get hashCode => Object.hash(sets, volumeKg);

  @override
  String toString() => '$sets sets, $volumeKg kg';
}

/// The OQ-19 result. [primary] and [secondary] hold anatomical nodes only;
/// the non-anatomical `fullBody` is reported separately and never enters an
/// anatomical roll-up, total or coverage figure (ADR-0010 rule 3).
@immutable
final class AttributedSetCounts {
  const AttributedSetCounts({
    required this.primary,
    required this.secondary,
    required this.nonAnatomicalPrimary,
    required this.nonAnatomicalSecondary,
  });

  /// Attribution to primary targets: each recorded set counts in full for
  /// every distinct primary target of its exercise.
  final Map<AnatomyNodeId, AttributedTotals> primary;

  /// Attribution to secondary targets, reported separately and excluded from
  /// [primary].
  final Map<AnatomyNodeId, AttributedTotals> secondary;

  /// `fullBody` as a primary target (the one allowed use), labelled
  /// non-anatomical.
  final Map<AnatomyNodeId, AttributedTotals> nonAnatomicalPrimary;

  /// A stored `fullBody` secondary (kept historically, ADR-0010 rule 5).
  final Map<AnatomyNodeId, AttributedTotals> nonAnatomicalSecondary;

  /// The notice every display of these figures carries.
  String get notice => attributedSetCountsNotice;
}

/// Attributes recorded sets to anatomy targets (OQ-19, plan section 8).
///
/// Each **primary** target receives the full set count (and the kg volume of
/// those sets) of the exercise; a set is attributed once per distinct primary
/// target. **Secondary** targets are accumulated separately and are not part
/// of the primary totals. Non-anatomical nodes (`fullBody`) go to the
/// separate non-anatomical maps and are excluded from anatomical figures.
///
/// With [rollUpToLevel], a target deeper than that level is attributed to its
/// ancestor at the level, once per distinct ancestor per exercise (two primary
/// heads of one muscle give that muscle the sets once, not twice). Without
/// it, each node receives its own figures. These are **attributed set
/// counts, not physiological measurements** ([attributedSetCountsNotice]).
AttributedSetCounts attributeSetCounts(
  Iterable<AttributedExercise> entries,
  AnatomyTree tree, {
  int? rollUpToLevel,
}) {
  final primary = <AnatomyNodeId, AttributedTotals>{};
  final secondary = <AnatomyNodeId, AttributedTotals>{};
  final nonPrimary = <AnatomyNodeId, AttributedTotals>{};
  final nonSecondary = <AnatomyNodeId, AttributedTotals>{};

  void add(
    Map<AnatomyNodeId, AttributedTotals> into,
    Set<AnatomyNodeId> nodes,
    AttributedExercise e,
  ) {
    for (final n in nodes) {
      into.update(
        n,
        (t) => t.plus(e.sets, e.volumeKg),
        ifAbsent: () => AttributedTotals(e.sets, e.volumeKg),
      );
    }
  }

  AnatomyNodeId place(AnatomyNodeId node) {
    if (rollUpToLevel == null) return node;
    return tree.atLevel(node, rollUpToLevel) ?? node;
  }

  for (final e in entries) {
    final p = <AnatomyNodeId>{};
    final s = <AnatomyNodeId>{};
    final np = <AnatomyNodeId>{};
    final ns = <AnatomyNodeId>{};
    for (final t in e.targets) {
      final anatomical = tree.isAnatomical(t.node);
      final target = anatomical ? place(t.node) : t.node;
      if (anatomical) {
        (t.isPrimary ? p : s).add(target);
      } else {
        (t.isPrimary ? np : ns).add(target);
      }
    }
    add(primary, p, e);
    add(secondary, s, e);
    add(nonPrimary, np, e);
    add(nonSecondary, ns, e);
  }
  return AttributedSetCounts(
    primary: Map.unmodifiable(primary),
    secondary: Map.unmodifiable(secondary),
    nonAnatomicalPrimary: Map.unmodifiable(nonPrimary),
    nonAnatomicalSecondary: Map.unmodifiable(nonSecondary),
  );
}
