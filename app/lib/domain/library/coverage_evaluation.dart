import 'package:meta/meta.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/coverage_spec.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/training/training.dart' show ExerciseCategory;

/// Dimension of a gap report row (`coverage-matrix.md` section 12).
enum GapDimension {
  slot,
  total,
  mechanics,
  laterality,
  equipmentClass,
  variationFamilies,
  difficulty,
  diversity,
  primariesPerExercise,
  completeness,
}

/// Status of a gap report row.
enum GapStatus { met, gap, notRecorded, notApplicable, accepted }

/// One row of the gap report: a group or set, a dimension and an item with the
/// requirement, the actual count and the gap (never below zero; for a cap the
/// excess).
@immutable
final class GapRow {
  const GapRow({
    required this.tranche,
    required this.group,
    required this.dimension,
    required this.item,
    required this.required,
    required this.actual,
    required this.gap,
    required this.status,
    this.note,
  });

  final String tranche;
  final String group;
  final GapDimension dimension;
  final String item;
  final num? required;
  final num? actual;
  final num gap;
  final GapStatus status;
  final String? note;

  bool get isOpen => status == GapStatus.gap || status == GapStatus.notRecorded;

  GapRow withStatus(GapStatus status, String note) => GapRow(
    tranche: tranche,
    group: group,
    dimension: dimension,
    item: item,
    required: required,
    actual: actual,
    gap: gap,
    status: status,
    note: note,
  );
}

/// How one coverage group is filled.
@immutable
final class GroupCoverage {
  const GroupCoverage({
    required this.group,
    required this.slotFills,
    required this.candidates,
  });

  final CoverageGroup group;

  /// Exercises assigned to each slot by maximum matching, by slot id.
  final Map<String, List<ExerciseId>> slotFills;

  /// Exercises that satisfy the group rule (primary target in the group,
  /// primary pattern a slot pattern, category push, pull, legs or core).
  final List<ExerciseId> candidates;

  int get required => group.slotTotal;
  int get filled => slotFills.values.fold(0, (n, l) => n + l.length);

  /// The exercises that fill a slot.
  Set<ExerciseId> get matched => {for (final l in slotFills.values) ...l};
}

/// How one conditioning, power or mobility set is filled.
@immutable
final class SetCoverage {
  const SetCoverage({required this.set, required this.exercises});

  final CoverageSet set;

  /// Exercises that count toward the set (for `eachGroup` sets, one per
  /// group by matching), capped at the minimum.
  final List<ExerciseId> exercises;

  int get required => set.min;
  int get filled => exercises.length > set.min ? set.min : exercises.length;
}

/// The coverage evaluation: gap rows plus the per-group and per-set fills.
@immutable
final class CoverageReport {
  const CoverageReport({
    required this.rows,
    required this.groups,
    required this.sets,
  });

  final List<GapRow> rows;
  final List<GroupCoverage> groups;
  final List<SetCoverage> sets;

  /// Required slot fills over all groups (325 for the approved inventory).
  int get slotRequired => groups.fold(0, (n, g) => n + g.required);

  /// Slot fills achieved (67 on the approved seed baseline).
  int get slotFilled => groups.fold(0, (n, g) => n + g.filled);

  /// Required entries over all sets (70).
  int get setRequired => sets.fold(0, (n, s) => n + s.required);

  /// Set entries achieved (20 on the approved seed baseline).
  int get setFilled => sets.fold(0, (n, s) => n + s.filled);

  List<GapRow> get openGaps => [
    for (final r in rows)
      if (r.isOpen) r,
  ];

  List<GapRow> rowsFor(GapDimension d) => [
    for (final r in rows)
      if (r.dimension == d) r,
  ];

  GroupCoverage? group(String id) {
    for (final g in groups) {
      if (g.group.id == id) return g;
    }
    return null;
  }

  SetCoverage? set(String id) {
    for (final s in sets) {
      if (s.set.id == id) return s;
    }
    return null;
  }
}

const Set<ExerciseCategory> _anatomicalCategories = {
  ExerciseCategory.push,
  ExerciseCategory.pull,
  ExerciseCategory.legs,
  ExerciseCategory.core,
};

/// Evaluates [spec] against [exercises] (`coverage-matrix.md` section 2).
///
/// An exercise counts toward a group when it is an active **system** exercise
/// of category push, pull, legs or core, one of its **primary** targets is a
/// node of the group or a descendant (`fullBody` is non-anatomical and never
/// counts), and its primary pattern is a pattern of one of the group's slots.
/// It fills at most one slot per group; a slot accepts it when its primary
/// pattern is a slot pattern and every discriminator holds (an unrecorded
/// attribute or mechanics never matches). The assignment is a deterministic
/// maximum bipartite matching (exercises in id order, slots in file order),
/// each slot taking up to its minimum.
///
/// Conditioning, power and mobility sets count by primary pattern (and the
/// categories of the set, where given); the static stretch set counts one
/// exercise per coverage group by matching.
///
/// [familyRoots] (from the relationship analysis) feeds the variation family
/// dimension. [newExerciseIds], when given, restricts the primaries per
/// exercise metric to the exercises new in the tranche.
CoverageReport evaluateCoverage({
  required CoverageSpec spec,
  required ReferenceData reference,
  required Iterable<CatalogueExercise> exercises,
  Map<ExerciseId, ExerciseId> familyRoots = const {},
  Set<ExerciseId>? newExerciseIds,
}) {
  final eligible = [
    for (final e in exercises)
      if (e.isSystem && e.isActive) e,
  ]..sort((a, b) => a.id.compareTo(b.id));
  final byId = {for (final e in eligible) e.id: e};
  final tree = reference.anatomy;

  bool primaryInNodes(CatalogueExercise e, Iterable<AnatomyNodeId> nodes) {
    for (final t in e.primaryTargets) {
      if (!tree.contains(t.node) || !tree.isAnatomical(t.node)) continue;
      if (nodes.any((n) => tree.isSelfOrDescendantOf(t.node, n))) return true;
    }
    return false;
  }

  bool accepts(CoverageSlot slot, CatalogueExercise e) {
    final pattern = e.primaryPattern;
    if (pattern == null || !slot.patterns.contains(pattern)) return false;
    for (final d in slot.discriminators) {
      final ok = switch (d) {
        AttributeDiscriminator() =>
          e.attributes[d.attribute] != null &&
              d.values.contains(e.attributes[d.attribute]),
        EquipmentClassDiscriminator() => d.classes.contains(
          equipmentClassOf(e, reference.equipment),
        ),
        LateralityDiscriminator() =>
          e.laterality != null && d.values.contains(e.laterality),
        MechanicsDiscriminator() =>
          e.mechanics != null && d.values.contains(e.mechanics),
        SubTargetDiscriminator() => e.targets.any(
          (t) =>
              (!d.primaryOnly || t.isPrimary) &&
              tree.isSelfOrDescendantOf(t.node, d.node),
        ),
      };
      if (!ok) return false;
    }
    return true;
  }

  final groupResults = <GroupCoverage>[];
  for (final g in spec.groups) {
    final patterns = g.patterns;
    final candidates = [
      for (final e in eligible)
        if (_anatomicalCategories.contains(e.category) &&
            e.primaryPattern != null &&
            patterns.contains(e.primaryPattern) &&
            primaryInNodes(e, g.nodes))
          e,
    ];
    final adjacency = [
      for (final e in candidates)
        [
          for (var s = 0; s < g.slots.length; s++)
            if (accepts(g.slots[s], e)) s,
        ],
    ];
    final assignment = _maxMatching(adjacency, [
      for (final s in g.slots) s.min,
    ]);
    groupResults.add(
      GroupCoverage(
        group: g,
        slotFills: {
          for (var s = 0; s < g.slots.length; s++)
            g.slots[s].id: [for (final l in assignment[s]) candidates[l].id],
        },
        candidates: [for (final e in candidates) e.id],
      ),
    );
  }

  final setResults = <SetCoverage>[];
  for (final s in spec.sets) {
    final candidates = [
      for (final e in eligible)
        if (e.primaryPattern != null &&
            s.patterns.contains(e.primaryPattern) &&
            (s.categories.isEmpty || s.categories.contains(e.category.name)))
          e,
    ];
    if (s.eachGroup) {
      final adjacency = [
        for (final e in candidates)
          [
            for (var gi = 0; gi < spec.groups.length; gi++)
              if (primaryInNodes(e, spec.groups[gi].nodes)) gi,
          ],
      ];
      final assignment = _maxMatching(
        adjacency,
        List.filled(spec.groups.length, 1),
      );
      final ids = {
        for (final list in assignment)
          for (final l in list) l,
      }..toList();
      setResults.add(
        SetCoverage(
          set: s,
          exercises: [
            for (var i = 0; i < candidates.length; i++)
              if (ids.contains(i)) candidates[i].id,
          ],
        ),
      );
    } else {
      setResults.add(
        SetCoverage(set: s, exercises: [for (final e in candidates) e.id]),
      );
    }
  }

  final rows = <GapRow>[
    ..._groupRows(spec, reference, groupResults, byId, familyRoots),
    ..._trancheRows(spec, reference, groupResults, byId, newExerciseIds),
    ..._setRows(spec, reference, setResults, byId),
  ];
  return CoverageReport(
    rows: List.unmodifiable(rows),
    groups: List.unmodifiable(groupResults),
    sets: List.unmodifiable(setResults),
  );
}

/// Maximum bipartite matching with capacities (Kuhn's algorithm). Returns,
/// for each right vertex, the left vertices assigned to it. Deterministic:
/// left vertices are tried in order and rights in adjacency order.
List<List<int>> _maxMatching(List<List<int>> adjacency, List<int> capacity) {
  final assigned = List.generate(capacity.length, (_) => <int>[]);
  bool tryAssign(int left, Set<int> visited) {
    for (final right in adjacency[left]) {
      if (!visited.add(right)) continue;
      if (assigned[right].length < capacity[right]) {
        assigned[right].add(left);
        return true;
      }
      for (final other in assigned[right].toList()) {
        if (tryAssign(other, visited)) {
          assigned[right].remove(other);
          assigned[right].add(left);
          return true;
        }
      }
    }
    return false;
  }

  for (var l = 0; l < adjacency.length; l++) {
    tryAssign(l, <int>{});
  }
  for (final list in assigned) {
    list.sort();
  }
  return assigned;
}

GapRow _row(
  String tranche,
  String group,
  GapDimension dimension,
  String item,
  num? required,
  num? actual, {
  GapStatus? status,
  String? note,
  bool recordedGap = false,
}) {
  final req = required ?? 0;
  final act = actual ?? 0;
  final met = act >= req;
  return GapRow(
    tranche: tranche,
    group: group,
    dimension: dimension,
    item: item,
    required: required,
    actual: actual,
    gap: met ? 0 : req - act,
    status:
        status ??
        (met
            ? GapStatus.met
            : (recordedGap ? GapStatus.notRecorded : GapStatus.gap)),
    note: note,
  );
}

Iterable<GapRow> _groupRows(
  CoverageSpec spec,
  ReferenceData reference,
  List<GroupCoverage> groups,
  Map<ExerciseId, CatalogueExercise> byId,
  Map<ExerciseId, ExerciseId> familyRoots,
) sync* {
  final m = spec.metrics;
  for (final gc in groups) {
    final g = gc.group;
    for (final slot in g.slots) {
      yield _row(
        g.tranche,
        g.id,
        GapDimension.slot,
        slot.id,
        slot.min,
        gc.slotFills[slot.id]!.length,
      );
    }
    final matched = [for (final id in gc.matched) byId[id]!];
    yield _row(
      g.tranche,
      g.id,
      GapDimension.total,
      'slotTotal',
      g.slotTotal,
      gc.filled,
    );

    int count(bool Function(CatalogueExercise) test) =>
        matched.where(test).length;
    final unsetMechanics = count((e) => e.mechanics == null) > 0;
    final unsetLaterality = count((e) => e.laterality == null) > 0;
    final d = g.derived;
    for (final (item, required, actual, unset) in [
      (
        'compound',
        d.compound,
        count((e) => e.mechanics == Mechanics.compound),
        unsetMechanics,
      ),
      (
        'isolation',
        d.isolation,
        count((e) => e.mechanics == Mechanics.isolation),
        unsetMechanics,
      ),
    ]) {
      yield _row(
        g.tranche,
        g.id,
        GapDimension.mechanics,
        item,
        required,
        actual,
        recordedGap: unset,
      );
    }
    for (final (item, required, actual) in [
      (
        'bilateral',
        d.bilateral,
        count((e) => e.laterality == Laterality.bilateral),
      ),
      (
        'unilateralOrAlternating',
        d.unilateralOrAlternating,
        count(
          (e) => e.laterality != null && e.laterality != Laterality.bilateral,
        ),
      ),
    ]) {
      yield _row(
        g.tranche,
        g.id,
        GapDimension.laterality,
        item,
        required,
        actual,
        recordedGap: unsetLaterality,
      );
    }
    final classCounts = <EquipmentClass, int>{};
    for (final e in matched) {
      classCounts.update(
        equipmentClassOf(e, reference.equipment),
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    for (final MapEntry(key: cls, value: required)
        in d.equipmentClasses.entries) {
      if (required > 0) {
        yield _row(
          g.tranche,
          g.id,
          GapDimension.equipmentClass,
          cls.name,
          required,
          classCounts[cls] ?? 0,
        );
      }
    }
    if (d.variationFamilies > 0) {
      final matchedIds = gc.matched;
      final members = <ExerciseId, int>{};
      for (final id in matchedIds) {
        final root = familyRoots[id];
        if (root != null && root != id && matchedIds.contains(root)) {
          members.update(root, (n) => n + 1, ifAbsent: () => 1);
        }
      }
      yield _row(
        g.tranche,
        g.id,
        GapDimension.variationFamilies,
        'familiesWithThreeVariations',
        d.variationFamilies,
        members.values.where((n) => n >= 3).length,
      );
    }
    // Diversity: the class cap, with the bodyweight exemption.
    final cap = classCapShare * g.slotTotal > classCapFloor
        ? classCapShare * g.slotTotal
        : classCapFloor.toDouble();
    var worstClass = '';
    var worst = 0;
    for (final MapEntry(key: cls, value: n) in classCounts.entries) {
      if (cls == EquipmentClass.bodyweight && g.bodyweightExempt) continue;
      if (n > worst || (n == worst && cls.name.compareTo(worstClass) < 0)) {
        worst = n;
        worstClass = cls.name;
      }
    }
    yield GapRow(
      tranche: g.tranche,
      group: g.id,
      dimension: GapDimension.diversity,
      item: worstClass.isEmpty ? 'equipmentClassCap' : worstClass,
      required: cap,
      actual: worst,
      gap: worst > cap ? worst - cap : 0,
      status: worst > cap ? GapStatus.gap : GapStatus.met,
      note:
          'At most max(55 %, 4) in one class'
          '${g.bodyweightExempt ? '; bodyweight exempt' : ''}.',
    );
    // Difficulty of the matched exercises of the group.
    final n = matched.length;
    final unsetDifficulty = count((e) => e.difficulty == null) > 0;
    int ofLevel(Difficulty d) => count((e) => e.difficulty == d);
    if (g.slotTotal >= 20) {
      yield* _shareRows(g.tranche, g.id, n, unsetDifficulty, [
        ('beginner', m.largeGroupBeginnerShare, ofLevel(Difficulty.beginner)),
        (
          'intermediate',
          m.largeGroupIntermediateShare,
          ofLevel(Difficulty.intermediate),
        ),
        ('advanced', m.largeGroupAdvancedShare, ofLevel(Difficulty.advanced)),
      ], advancedMinimum: m.largeGroupAdvancedMinimum);
    } else {
      yield _row(
        g.tranche,
        g.id,
        GapDimension.difficulty,
        'beginner',
        m.smallGroupBeginnerMinimum,
        ofLevel(Difficulty.beginner),
        recordedGap: unsetDifficulty,
      );
      yield _row(
        g.tranche,
        g.id,
        GapDimension.difficulty,
        'intermediate',
        m.smallGroupIntermediateMinimum,
        ofLevel(Difficulty.intermediate),
        recordedGap: unsetDifficulty,
      );
      if (ofLevel(Difficulty.advanced) == 0) {
        yield _row(
          g.tranche,
          g.id,
          GapDimension.difficulty,
          'advanced',
          null,
          0,
          status: GapStatus.notApplicable,
          note: 'Optional; record the reason if none.',
        );
      }
    }
  }
}

Iterable<GapRow> _shareRows(
  String tranche,
  String group,
  int total,
  bool unset,
  List<(String, double, int)> levels, {
  required int advancedMinimum,
}) sync* {
  for (final (item, share, count) in levels) {
    final actualShare = total == 0 ? 0.0 : count / total;
    var met = actualShare + 1e-9 >= share;
    if (item == 'advanced') met = met && count >= advancedMinimum;
    yield GapRow(
      tranche: tranche,
      group: group,
      dimension: GapDimension.difficulty,
      item: item,
      required: share,
      actual: actualShare,
      gap: met ? 0 : share - actualShare,
      status: met
          ? GapStatus.met
          : (unset ? GapStatus.notRecorded : GapStatus.gap),
      note: item == 'advanced'
          ? 'At least ${(share * 100).round()} % and $advancedMinimum '
                'exercises.'
          : 'At least ${(share * 100).round()} %.',
    );
  }
}

Iterable<GapRow> _trancheRows(
  CoverageSpec spec,
  ReferenceData reference,
  List<GroupCoverage> groups,
  Map<ExerciseId, CatalogueExercise> byId,
  Set<ExerciseId>? newExerciseIds,
) sync* {
  final m = spec.metrics;
  final tranches = <String, List<GroupCoverage>>{};
  for (final gc in groups) {
    tranches.putIfAbsent(gc.group.tranche, () => []).add(gc);
  }
  for (final MapEntry(key: tranche, value: tgroups) in tranches.entries) {
    final matched = {for (final g in tgroups) ...g.matched};
    final candidates = {for (final g in tgroups) ...g.candidates};
    final pool = [
      for (final id in candidates)
        if (newExerciseIds == null || newExerciseIds.contains(id)) byId[id]!,
    ];
    // Difficulty bands over the exercises that fill slots in the tranche.
    yield* _bandRows(tranche, 'tranche $tranche', [
      for (final id in matched) byId[id]!,
    ], m.regionalBands);
    // Primaries per exercise.
    if (pool.isNotEmpty) {
      final primaries = pool.map((e) => e.primaryTargets.length).toList();
      final mean = primaries.fold(0, (a, b) => a + b) / pool.length;
      final share = primaries.where((n) => n >= 2).length / pool.length;
      yield GapRow(
        tranche: tranche,
        group: 'tranche $tranche',
        dimension: GapDimension.primariesPerExercise,
        item: 'mean',
        required: m.primariesMeanMaximum,
        actual: mean,
        gap: mean > m.primariesMeanMaximum ? mean - m.primariesMeanMaximum : 0,
        status: mean > m.primariesMeanMaximum ? GapStatus.gap : GapStatus.met,
        note: 'At most ${m.primariesMeanMaximum} primary targets on average.',
      );
      yield GapRow(
        tranche: tranche,
        group: 'tranche $tranche',
        dimension: GapDimension.primariesPerExercise,
        item: 'shareWithTwoOrMore',
        required: m.primariesTwoOrMoreShareMaximum,
        actual: share,
        gap: share > m.primariesTwoOrMoreShareMaximum
            ? share - m.primariesTwoOrMoreShareMaximum
            : 0,
        status: share > m.primariesTwoOrMoreShareMaximum
            ? GapStatus.gap
            : GapStatus.met,
        note:
            'At most ${(m.primariesTwoOrMoreShareMaximum * 100).round()} % '
            'with two or more primary targets.',
      );
    }
    // Completeness of the classification of the tranche's candidates.
    final complete = pool
        .where(
          (e) =>
              e.patterns.isNotEmpty &&
              e.laterality != null &&
              e.difficulty != null &&
              e.mechanics != null,
        )
        .length;
    yield _row(
      tranche,
      'tranche $tranche',
      GapDimension.completeness,
      'pattern, mechanics, laterality, difficulty',
      pool.length,
      complete,
      recordedGap: true,
    );
  }
}

Iterable<GapRow> _bandRows(
  String tranche,
  String group,
  List<CatalogueExercise> exercises,
  DifficultyBands bands,
) sync* {
  final n = exercises.length;
  final unset = exercises.any((e) => e.difficulty == null);
  for (final (item, band, level) in [
    ('beginner', bands.beginner, Difficulty.beginner),
    ('intermediate', bands.intermediate, Difficulty.intermediate),
    ('advanced', bands.advanced, Difficulty.advanced),
  ]) {
    final count = exercises.where((e) => e.difficulty == level).length;
    final share = n == 0 ? 0.0 : count / n;
    if (n == 0) {
      yield GapRow(
        tranche: tranche,
        group: group,
        dimension: GapDimension.difficulty,
        item: item,
        required: band.low,
        actual: 0,
        gap: band.low,
        status: GapStatus.notApplicable,
        note: 'No counted exercises.',
      );
      continue;
    }
    final inBand = band.contains(share);
    yield GapRow(
      tranche: tranche,
      group: group,
      dimension: GapDimension.difficulty,
      item: item,
      required: band.low,
      actual: share,
      gap: inBand
          ? 0
          : (share < band.low ? band.low - share : share - band.high),
      status: inBand
          ? GapStatus.met
          : (unset ? GapStatus.notRecorded : GapStatus.gap),
      note:
          'Band ${(band.low * 100).round()} to ${(band.high * 100).round()} %.',
    );
  }
}

Iterable<GapRow> _setRows(
  CoverageSpec spec,
  ReferenceData reference,
  List<SetCoverage> sets,
  Map<ExerciseId, CatalogueExercise> byId,
) sync* {
  for (final sc in sets) {
    final s = sc.set;
    final missingItems = [
      for (final i in s.requiresEquipment)
        if (!reference.equipment.contains(i)) i.value,
    ];
    yield _row(
      s.tranche,
      s.id,
      GapDimension.slot,
      s.id,
      s.min,
      sc.filled,
      status: s.min == 0 ? GapStatus.notApplicable : null,
      note: missingItems.isEmpty
          ? s.note
          : 'Needs the equipment ${missingItems.join(', ')}.',
    );
  }
  final conditioning = <CatalogueExercise>{};
  final mobility = <CatalogueExercise>{};
  for (final sc in sets) {
    final target = sc.set.id.startsWith('mobility.') ? mobility : conditioning;
    for (final id in sc.exercises) {
      target.add(byId[id]!);
    }
  }
  const tranche = '5.7';
  yield* _bandRows(
    tranche,
    'conditioning',
    conditioning.toList(),
    spec.metrics.conditioningBands,
  );
  yield* _bandRows(
    tranche,
    'mobility',
    mobility.toList(),
    spec.metrics.mobilityBands,
  );
}
