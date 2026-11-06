import 'package:meta/meta.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/exercise_relationship.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';

/// Longest `progressionOf` chain accepted without a reviewer note (IC-414).
const int maxProgressionSteps = 6;

/// Result of checking the relationship graph (IC-400).
@immutable
final class RelationshipAnalysis {
  const RelationshipAnalysis({
    required this.findings,
    required this.familyRoots,
    required this.families,
    required this.maxDepth,
    required this.longestProgression,
    required this.cycles,
  });

  final List<Finding> findings;

  /// For every exercise in a `variationOf` family, the family root.
  final Map<ExerciseId, ExerciseId> familyRoots;

  /// Families with a root and at least one variation.
  final int families;

  /// Longest `variationOf` hop count to a root (1 when the forest is valid).
  final int maxDepth;

  /// Longest `progressionOf` chain in edges.
  final int longestProgression;

  /// Distinct cycles found in `variationOf` and `progressionOf`.
  final int cycles;

  /// True when [a] and [b] belong to one `variationOf` family.
  bool sameFamily(ExerciseId a, ExerciseId b) {
    final ra = familyRoots[a];
    return ra != null && ra == familyRoots[b];
  }
}

/// Checks the relationship graph over [exercises] (IC-401 to IC-410, IC-413,
/// IC-414). IC-411 and IC-412 are structural and live in the duplicate
/// detection.
///
/// Rules: no self-reference; both ends exist; no duplicate (same from, to,
/// kind) and no inverse duplicate; symmetric kinds stored once with ids in
/// order; a stored `regressionOf` is refused (it is a derived view);
/// `variationOf` has at most one target per exercise, the target is a family
/// root and the graph is a forest; `progressionOf` is acyclic;
/// `unilateralCounterpartOf` joins a bilateral and a unilateral or
/// alternating entry.
RelationshipAnalysis analyseRelationships(
  Iterable<CatalogueExercise> exercises,
  Iterable<ExerciseRelationship> relationships,
) {
  final byId = {for (final e in exercises) e.id: e};
  final rels = relationships.toList();
  final out = <Finding>[];

  Finding err(
    String code,
    String message,
    ExerciseRelationship r, {
    Severity severity = Severity.error,
  }) => Finding(
    code: code,
    severity: severity,
    message: message,
    subjectId: r.from.value,
    related: [r.to.value],
  );

  final seenKeys = <String>{};
  for (final r in rels) {
    if (r.from == r.to) {
      out.add(err('IC-401', 'The exercise ${r.from} is related to itself.', r));
    }
    if (!r.kind.isStored) {
      out.add(
        err(
          'IC-404',
          'regressionOf is a derived view and is not stored; store the inverse '
              'progressionOf (${r.from} ${r.kind.name} ${r.to}).',
          r,
        ),
      );
    } else if (r.kind.isSymmetric && r.from.compareTo(r.to) > 0) {
      out.add(
        err(
          'IC-404',
          'The symmetric ${r.kind.name} between ${r.from} and ${r.to} must be '
              'stored once with the ids in alphabetical order.',
          r,
        ),
      );
    }
    final missing = [
      if (!byId.containsKey(r.from)) r.from,
      if (!byId.containsKey(r.to)) r.to,
    ];
    if (missing.isNotEmpty) {
      out.add(
        err(
          'IC-402',
          'The relationship ${r.from} ${r.kind.name} ${r.to} names a missing '
              'exercise (${missing.join(', ')}).',
          r,
        ),
      );
    }
    if (r.source == ExerciseSource.system) {
      final retiredEnds = [
        if (byId[r.from] != null && !byId[r.from]!.isActive) r.from,
        if (byId[r.to] != null && !byId[r.to]!.isActive) r.to,
      ];
      if (retiredEnds.isNotEmpty) {
        out.add(
          err(
            'IC-402',
            'The system relationship ${r.from} ${r.kind.name} ${r.to} has a '
                'retired end (${retiredEnds.join(', ')}); both ends must be '
                'active in the release.',
            r,
          ),
        );
      }
    }
    if (!seenKeys.add('${r.from}|${r.to}|${r.kind.name}')) {
      out.add(
        err(
          'IC-403',
          'The relationship ${r.from} ${r.kind.name} ${r.to} is stored twice.',
          r,
        ),
      );
    }
    final from = byId[r.from];
    final to = byId[r.to];
    if (from != null && to != null) {
      final fromActiveSystem = from.isActive && from.isSystem;
      final toActiveSystem = to.isActive && to.isSystem;
      if ((fromActiveSystem && !to.isActive) ||
          (toActiveSystem && !from.isActive)) {
        out.add(
          err(
            'IC-413',
            'The relationship ${r.from} ${r.kind.name} ${r.to} links an active '
                'system exercise to a retired exercise.',
            r,
          ),
        );
      }
    }
  }

  // IC-404: inverse duplicate of a progression.
  final progressions = {
    for (final r in rels)
      if (r.kind == RelationshipKind.progressionOf && r.from != r.to)
        '${r.from}|${r.to}',
  };
  final reportedInverse = <String>{};
  for (final r in rels) {
    if (r.kind != RelationshipKind.progressionOf || r.from == r.to) continue;
    if (progressions.contains('${r.to}|${r.from}')) {
      final pair = [r.from.value, r.to.value]..sort();
      if (reportedInverse.add(pair.join('|'))) {
        out.add(
          err(
            'IC-404',
            'progressionOf is stored in both directions between ${pair[0]} and '
                '${pair[1]}.',
            r,
          ),
        );
      }
    }
  }

  // IC-405: variationOf forest.
  final variationTargets = <ExerciseId, List<ExerciseId>>{};
  for (final r in rels) {
    if (r.kind == RelationshipKind.variationOf && r.from != r.to) {
      variationTargets.putIfAbsent(r.from, () => []).add(r.to);
    }
  }
  var cycles = 0;
  for (final MapEntry(key: from, value: targets) in variationTargets.entries) {
    if (targets.length > 1) {
      out.add(
        Finding(
          code: 'IC-405',
          severity: Severity.error,
          message:
              'The exercise $from is a variationOf more than one exercise '
              '(${targets.join(', ')}).',
          subjectId: from.value,
          related: [for (final t in targets) t.value],
        ),
      );
    }
  }
  final firstTarget = {
    for (final e in variationTargets.entries) e.key: e.value.first,
  };
  for (final MapEntry(key: from, value: to) in firstTarget.entries) {
    if (firstTarget.containsKey(to)) {
      out.add(
        Finding(
          code: 'IC-405',
          severity: Severity.error,
          message:
              'The exercise $from is a variationOf $to, which is itself a '
              'variation; a variation points to the family root.',
          subjectId: from.value,
          related: [to.value],
        ),
      );
    }
  }
  final reportedCycles = <ExerciseId>{};
  for (final start in firstTarget.keys) {
    final path = <ExerciseId>[];
    ExerciseId? at = start;
    while (at != null && !path.contains(at)) {
      path.add(at);
      at = firstTarget[at];
    }
    if (at == null) continue;
    final cycle = path.sublist(path.indexOf(at));
    final smallest = cycle.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    if (reportedCycles.add(smallest)) {
      cycles++;
      out.add(
        Finding(
          code: 'IC-405',
          severity: Severity.error,
          message: 'variationOf forms a cycle: ${cycle.join(' > ')}.',
          subjectId: smallest.value,
          related: [for (final c in cycle) c.value],
        ),
      );
    }
  }

  // Family roots: follow first targets; cyclic members get no root.
  final familyRoots = <ExerciseId, ExerciseId>{};
  for (final start in byId.keys) {
    var at = start;
    final seen = <ExerciseId>{start};
    var cyclic = false;
    while (firstTarget.containsKey(at)) {
      at = firstTarget[at]!;
      if (!seen.add(at)) {
        cyclic = true;
        break;
      }
    }
    if (!cyclic &&
        (at != start ||
            variationTargets.values.any((t) => t.contains(start)))) {
      familyRoots[start] = at;
    }
  }
  final rootsWithVariations = {
    for (final e in firstTarget.entries)
      if (familyRoots.containsKey(e.key)) familyRoots[e.key]!,
  };

  // IC-407: progressionOf acyclic; IC-414 longest chain.
  final next = <ExerciseId, List<ExerciseId>>{};
  for (final r in rels) {
    if (r.kind == RelationshipKind.progressionOf && r.from != r.to) {
      next.putIfAbsent(r.from, () => []).add(r.to);
    }
  }
  final state = <ExerciseId, int>{}; // 1 on stack, 2 done
  final longest = <ExerciseId, int>{};
  final stack = <ExerciseId>[];
  final progressionCycles = <ExerciseId>{};
  void dfs(ExerciseId node) {
    state[node] = 1;
    stack.add(node);
    var best = 0;
    for (final to in next[node] ?? const <ExerciseId>[]) {
      final s = state[to];
      if (s == 1) {
        final cycle = stack.sublist(stack.indexOf(to));
        final smallest = cycle.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
        if (progressionCycles.add(smallest)) {
          cycles++;
          out.add(
            Finding(
              code: 'IC-407',
              severity: Severity.error,
              message: 'progressionOf forms a cycle: ${cycle.join(' > ')}.',
              subjectId: smallest.value,
              related: [for (final c in cycle) c.value],
            ),
          );
        }
        continue;
      }
      if (s == null) dfs(to);
      final length = 1 + (longest[to] ?? 0);
      if (length > best) best = length;
    }
    stack.removeLast();
    state[node] = 2;
    longest[node] = best;
  }

  for (final start in (next.keys.toList()..sort())) {
    if (state[start] == null) dfs(start);
  }
  var longestChain = 0;
  ExerciseId? longestStart;
  for (final e in longest.entries) {
    if (e.value > longestChain ||
        (e.value == longestChain &&
            longestStart != null &&
            e.key.compareTo(longestStart) < 0)) {
      longestChain = e.value;
      longestStart = e.key;
    }
  }
  if (longestChain > maxProgressionSteps) {
    out.add(
      Finding(
        code: 'IC-414',
        severity: Severity.warning,
        message:
            'The longest progressionOf chain has $longestChain steps '
            '(more than $maxProgressionSteps); a reviewer note is required '
            'that it is a real ladder.',
        subjectId: longestStart?.value,
      ),
    );
  }

  // IC-408, IC-409, IC-410.
  for (final r in rels) {
    final from = byId[r.from];
    final to = byId[r.to];
    if (from == null || to == null || r.from == r.to) continue;
    switch (r.kind) {
      case RelationshipKind.unilateralCounterpartOf:
        final a = from.laterality;
        final b = to.laterality;
        if (a != null && b != null) {
          final oneBilateral =
              (a == Laterality.bilateral) != (b == Laterality.bilateral);
          if (!oneBilateral) {
            out.add(
              err(
                'IC-408',
                'unilateralCounterpartOf must join one bilateral entry and one '
                    'unilateral or alternating entry (${r.from} is ${a.name}, '
                    '${r.to} is ${b.name}).',
                r,
              ),
            );
          }
        }
      case RelationshipKind.alternativeTo:
        final ra = familyRoots[r.from];
        if (ra != null && ra == familyRoots[r.to]) {
          out.add(
            err(
              'IC-409',
              'alternativeTo joins two members of one variationOf family; the '
                  'family already links them.',
              r,
              severity: Severity.warning,
            ),
          );
        }
      case RelationshipKind.variationOf:
        final pa = from.primaryPattern;
        final pb = to.primaryPattern;
        final nodesA = {for (final t in from.primaryTargets) t.node};
        final nodesB = {for (final t in to.primaryTargets) t.node};
        if (pa != null &&
            pb != null &&
            pa != pb &&
            nodesA.intersection(nodesB).isEmpty) {
          out.add(
            err(
              'IC-410',
              'The variationOf pair has different primary patterns and no '
                  'shared primary target; it is probably not the same '
                  'movement.',
              r,
              severity: Severity.warning,
            ),
          );
        }
      case RelationshipKind.progressionOf || RelationshipKind.regressionOf:
        break;
    }
  }

  var maxDepth = 0;
  for (final start in firstTarget.keys) {
    var hops = 0;
    var at = start;
    final seen = <ExerciseId>{start};
    while (firstTarget.containsKey(at)) {
      at = firstTarget[at]!;
      hops++;
      if (!seen.add(at)) break;
    }
    if (hops > maxDepth) maxDepth = hops;
  }

  return RelationshipAnalysis(
    findings: out,
    familyRoots: Map.unmodifiable(familyRoots),
    families: rootsWithVariations.length,
    maxDepth: maxDepth,
    longestProgression: longestChain,
    cycles: cycles,
  );
}
