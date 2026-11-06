import 'package:meta/meta.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/value_equality.dart';

/// Anatomy node (ADR-0008 decision 2, ADR-0010): level 1 region, 2 muscle
/// group, 3 anatomical muscle, 4 subdivision or head. `fullBody` is the one
/// non-anatomical, childless level 1 node.
@immutable
final class AnatomyNode extends ValueObject {
  const AnatomyNode({
    required this.id,
    required this.level,
    required this.sort,
    required this.labels,
    this.parentId,
    this.nonAnatomical = false,
    this.status = ReferenceStatus.active,
    this.providerId = ProviderId.repforge,
    this.definition,
    this.includes,
    this.excludes,
    this.note,
  });

  final AnatomyNodeId id;

  /// Null at level 1.
  final AnatomyNodeId? parentId;
  final int level;
  final bool nonAnatomical;

  /// Orders siblings (ascending).
  final int sort;

  /// Display labels by locale; `en-GB` is always present for shipped data.
  final Map<String, String> labels;
  final ReferenceStatus status;
  final ProviderId providerId;
  final String? definition;
  final String? includes;
  final String? excludes;
  final String? note;

  String get label => labels[canonicalLocale] ?? id.value;

  bool get isActive => status == ReferenceStatus.active;

  @override
  List<Object?> get props => [
    id,
    parentId,
    level,
    nonAnatomical,
    sort,
    labels,
    status,
    providerId,
    definition,
    includes,
    excludes,
    note,
  ];
}

/// Movement pattern (ADR-0008 decision 4): a family (no parent) or a pattern
/// (a family is its parent). Only leaf patterns are assigned to exercises.
@immutable
final class MovementPattern extends ValueObject {
  const MovementPattern({
    required this.id,
    required this.level,
    required this.sort,
    required this.labels,
    this.parentId,
    this.status = ReferenceStatus.active,
    this.providerId = ProviderId.repforge,
    this.relatedCategories = const [],
    this.definition,
    this.includes,
    this.excludes,
    this.note,
  });

  final MovementPatternId id;
  final MovementPatternId? parentId;

  /// 1 for a family, 2 for a pattern.
  final int level;
  final int sort;
  final Map<String, String> labels;
  final ReferenceStatus status;
  final ProviderId providerId;

  /// Categories (enum names) the family usually accompanies. Families only.
  final List<String> relatedCategories;
  final String? definition;
  final String? includes;
  final String? excludes;
  final String? note;

  bool get isFamily => parentId == null;
  bool get isActive => status == ReferenceStatus.active;
  String get label => labels[canonicalLocale] ?? id.value;

  @override
  List<Object?> get props => [
    id,
    parentId,
    level,
    sort,
    labels,
    status,
    providerId,
    relatedCategories,
    definition,
    includes,
    excludes,
    note,
  ];
}

/// Equipment item (ADR-0008 decision 4).
@immutable
final class EquipmentItem extends ValueObject {
  const EquipmentItem({
    required this.id,
    required this.sort,
    required this.labels,
    required this.equipmentClass,
    required this.defaultRole,
    this.existing = false,
    this.status = ReferenceStatus.active,
    this.providerId = ProviderId.repforge,
    this.note,
  });

  final EquipmentItemId id;
  final int sort;
  final Map<String, String> labels;
  final EquipmentClass equipmentClass;
  final EquipmentDefaultRole defaultRole;

  /// True for the 21 items that predate the catalogue (`status: existing`).
  final bool existing;
  final ReferenceStatus status;
  final ProviderId providerId;
  final String? note;

  bool get isActive => status == ReferenceStatus.active;
  String get label => labels[canonicalLocale] ?? id.value;

  @override
  List<Object?> get props => [
    id,
    sort,
    labels,
    equipmentClass,
    defaultRole,
    existing,
    status,
    providerId,
    note,
  ];
}

/// Read-only queries over a list of anatomy nodes. Never throws: duplicate ids
/// keep the first node, and traversals stop at a cycle, so a tree can be built
/// from invalid data in order to report on it.
final class AnatomyTree {
  AnatomyTree(Iterable<AnatomyNode> nodes) : nodes = List.unmodifiable(nodes) {
    for (final n in this.nodes) {
      _byId.putIfAbsent(n.id, () => n);
    }
    for (final n in _byId.values) {
      _children.putIfAbsent(n.parentId, () => []).add(n);
    }
    for (final list in _children.values) {
      list.sort(_bySortThenId);
    }
  }

  static int _bySortThenId(AnatomyNode a, AnatomyNode b) {
    final c = a.sort.compareTo(b.sort);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  final List<AnatomyNode> nodes;
  final Map<AnatomyNodeId, AnatomyNode> _byId = {};
  final Map<AnatomyNodeId?, List<AnatomyNode>> _children = {};

  int get length => _byId.length;
  bool contains(AnatomyNodeId id) => _byId.containsKey(id);
  AnatomyNode? node(AnatomyNodeId id) => _byId[id];

  /// The level 1 nodes in sibling order.
  List<AnatomyNode> get roots => _children[null] ?? const [];

  /// Direct children in sibling order.
  List<AnatomyNode> children(AnatomyNodeId id) => _children[id] ?? const [];

  /// True for a node that names a muscle region or muscle (everything except
  /// non-anatomical nodes). Unknown ids count as anatomical.
  bool isAnatomical(AnatomyNodeId id) => !(_byId[id]?.nonAnatomical ?? false);

  /// Ancestors, nearest first. Stops at a missing parent or a cycle.
  List<AnatomyNode> ancestors(AnatomyNodeId id) {
    final out = <AnatomyNode>[];
    final seen = <AnatomyNodeId>{id};
    var parent = _byId[id]?.parentId;
    while (parent != null && seen.add(parent)) {
      final p = _byId[parent];
      if (p == null) break;
      out.add(p);
      parent = p.parentId;
    }
    return out;
  }

  /// Descendants in depth-first, sibling order. Filtering by a node includes
  /// its descendants (TRN-010(2)).
  List<AnatomyNode> descendants(AnatomyNodeId id) {
    final out = <AnatomyNode>[];
    final seen = <AnatomyNodeId>{id};
    void walk(AnatomyNodeId at) {
      for (final c in children(at)) {
        if (seen.add(c.id)) {
          out.add(c);
          walk(c.id);
        }
      }
    }

    walk(id);
    return out;
  }

  /// Ids of [id] and all its descendants: the filter set for [id].
  Set<AnatomyNodeId> selfAndDescendantIds(AnatomyNodeId id) => {
    id,
    for (final d in descendants(id)) d.id,
  };

  /// True when [id] is [ancestor] or lies below it.
  bool isSelfOrDescendantOf(AnatomyNodeId id, AnatomyNodeId ancestor) =>
      id == ancestor || ancestors(id).any((a) => a.id == ancestor);

  /// True when [a] and [b] are the same node or one is an ancestor of the
  /// other (IC-303).
  bool areRelated(AnatomyNodeId a, AnatomyNodeId b) =>
      isSelfOrDescendantOf(a, b) || isSelfOrDescendantOf(b, a);

  /// The ancestor of [id] at [level], or [id] itself when it is at or above
  /// that level. Null when the node is unknown.
  AnatomyNodeId? atLevel(AnatomyNodeId id, int level) {
    final n = _byId[id];
    if (n == null) return null;
    if (n.level <= level) return id;
    for (final a in ancestors(id)) {
      if (a.level == level) return a.id;
    }
    return id;
  }

  /// The ancestor lift of the near-duplicate signature: level 3 and 4 nodes
  /// become their level 2 muscle group; level 1 and 2 nodes stay.
  AnatomyNodeId lift(AnatomyNodeId id) => atLevel(id, 2) ?? id;
}

/// Read-only queries over movement patterns.
final class PatternTree {
  PatternTree(Iterable<MovementPattern> patterns)
    : patterns = List.unmodifiable(patterns) {
    for (final p in this.patterns) {
      _byId.putIfAbsent(p.id, () => p);
    }
  }

  final List<MovementPattern> patterns;
  final Map<MovementPatternId, MovementPattern> _byId = {};

  int get length => _byId.length;
  bool contains(MovementPatternId id) => _byId.containsKey(id);
  MovementPattern? pattern(MovementPatternId id) => _byId[id];

  List<MovementPattern> get families => [
    for (final p in _byId.values)
      if (p.isFamily) p,
  ];

  /// The family of [id]: the pattern itself when it is a family.
  MovementPattern? familyOf(MovementPatternId id) {
    final p = _byId[id];
    if (p == null) return null;
    if (p.isFamily) return p;
    return _byId[p.parentId];
  }

  List<MovementPattern> children(MovementPatternId familyId) => [
    for (final p in _byId.values)
      if (p.parentId == familyId) p,
  ]..sort((a, b) => a.sort.compareTo(b.sort));
}

/// Read-only queries over equipment items.
final class EquipmentCatalogue {
  EquipmentCatalogue(Iterable<EquipmentItem> items)
    : items = List.unmodifiable(items) {
    for (final i in this.items) {
      _byId.putIfAbsent(i.id, () => i);
    }
  }

  final List<EquipmentItem> items;
  final Map<EquipmentItemId, EquipmentItem> _byId = {};

  int get length => _byId.length;
  bool contains(EquipmentItemId id) => _byId.containsKey(id);
  EquipmentItem? item(EquipmentItemId id) => _byId[id];
}

/// The three reference lists an exercise is checked against.
@immutable
final class ReferenceData {
  const ReferenceData({
    required this.anatomy,
    required this.patterns,
    required this.equipment,
  });

  final AnatomyTree anatomy;
  final PatternTree patterns;
  final EquipmentCatalogue equipment;
}
