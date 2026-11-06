import 'package:meta/meta.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/preserved_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/text_normalisation.dart';

/// Which reference list a ledger entry belongs to.
enum ReferenceList {
  anatomy('anatomy'),
  movementPattern('movementPattern'),
  equipment('equipment');

  ReferenceList(this.wire);

  /// The text used in `reference/ledger.json`.
  final String wire;
}

/// One entry of the reference ledger (`reference/ledger.json`): the lifecycle
/// history of a reference id. An id is never reused or given a new meaning.
@immutable
final class LedgerEntry {
  const LedgerEntry({
    required this.list,
    required this.id,
    required this.status,
    this.introducedIn,
    this.retiredIn,
    this.replacedBy,
    this.reason,
  });

  final ReferenceList list;
  final String id;
  final ReferenceStatus status;
  final String? introducedIn;
  final String? retiredIn;
  final String? replacedBy;
  final String? reason;
}

Finding _err(
  String code,
  String message, {
  String? subject,
  String? field,
  List<String> related = const [],
}) => Finding(
  code: code,
  severity: Severity.error,
  message: message,
  subjectId: subject,
  field: field,
  related: related,
);

/// IC-801, IC-802 and IC-803 on a list of anatomy nodes.
///
/// IC-801: ids unique; parent exists; level equals parent level plus one; a
/// level 1 node has no parent; levels 1 to 4; no cycles. IC-802: sibling sort
/// values unique within a parent. IC-803: `fullBody` is the only
/// non-anatomical node, is a level 1 node and has no children (ADR-0010).
List<Finding> validateAnatomy(Iterable<AnatomyNode> nodes) {
  final list = nodes.toList();
  final out = <Finding>[];
  final byId = <AnatomyNodeId, AnatomyNode>{};
  for (final n in list) {
    if (byId.containsKey(n.id)) {
      out.add(
        _err(
          'IC-801',
          'Duplicate anatomy node id ${n.id}.',
          subject: n.id.value,
        ),
      );
    } else {
      byId[n.id] = n;
    }
  }
  for (final n in byId.values) {
    final id = n.id.value;
    if (n.level < 1 || n.level > 4) {
      out.add(
        _err(
          'IC-801',
          'Node $id has level ${n.level}; levels are 1 to 4.',
          subject: id,
          field: 'level',
        ),
      );
    }
    final parentId = n.parentId;
    if (parentId == null) {
      if (n.level != 1) {
        out.add(
          _err(
            'IC-801',
            'Node $id at level ${n.level} has no parent; only level 1 nodes '
                'are roots.',
            subject: id,
            field: 'parent',
          ),
        );
      }
    } else {
      final parent = byId[parentId];
      if (n.level == 1) {
        out.add(
          _err(
            'IC-801',
            'Level 1 node $id has a parent ($parentId).',
            subject: id,
            field: 'parent',
          ),
        );
      }
      if (parent == null) {
        out.add(
          _err(
            'IC-801',
            'Node $id names parent $parentId, which does not exist.',
            subject: id,
            field: 'parent',
          ),
        );
      } else if (n.level != parent.level + 1) {
        out.add(
          _err(
            'IC-801',
            'Node $id is at level ${n.level} but its parent $parentId is at '
                'level ${parent.level}; a child is one level deeper.',
            subject: id,
            field: 'level',
          ),
        );
      }
    }
  }
  out.addAll(
    _cycles<AnatomyNode, AnatomyNodeId>(
      byId,
      (n) => n.parentId,
      'IC-801',
      'anatomy',
    ),
  );
  // IC-802: unique sibling sort values.
  final bySiblings = <AnatomyNodeId?, Map<int, List<AnatomyNode>>>{};
  for (final n in byId.values) {
    bySiblings
        .putIfAbsent(n.parentId, () => {})
        .putIfAbsent(n.sort, () => [])
        .add(n);
  }
  for (final siblings in bySiblings.values) {
    for (final group in siblings.values) {
      if (group.length > 1) {
        final ids = group.map((n) => n.id.value).toList()..sort();
        out.add(
          _err(
            'IC-802',
            'Siblings ${ids.join(', ')} share sort value ${group.first.sort}.',
            subject: ids.first,
            field: 'sort',
            related: ids.skip(1).toList(),
          ),
        );
      }
    }
  }
  // IC-803: fullBody.
  for (final n in byId.values) {
    if (n.nonAnatomical && n.id != fullBodyNodeId) {
      out.add(
        _err(
          'IC-803',
          'Node ${n.id} is non-anatomical; fullBody is the only '
              'non-anatomical node.',
          subject: n.id.value,
          field: 'nonAnatomical',
        ),
      );
    }
  }
  final fullBody = byId[fullBodyNodeId];
  if (fullBody != null) {
    if (!fullBody.nonAnatomical) {
      out.add(
        _err(
          'IC-803',
          'fullBody must be flagged non-anatomical.',
          subject: 'fullBody',
          field: 'nonAnatomical',
        ),
      );
    }
    if (fullBody.level != 1 || fullBody.parentId != null) {
      out.add(
        _err(
          'IC-803',
          'fullBody must be a level 1 node.',
          subject: 'fullBody',
          field: 'level',
        ),
      );
    }
    final children = byId.values
        .where((n) => n.parentId == fullBodyNodeId)
        .toList();
    if (children.isNotEmpty) {
      out.add(
        _err(
          'IC-803',
          'fullBody must have no children.',
          subject: 'fullBody',
          related: [for (final c in children) c.id.value],
        ),
      );
    }
  }
  return out;
}

/// Cycle findings for any parent-linked reference list. One finding per
/// cycle, named by its smallest id.
List<Finding> _cycles<T, I extends Comparable<I>>(
  Map<I, T> byId,
  I? Function(T) parentOf,
  String code,
  String what,
) {
  final out = <Finding>[];
  final reported = <I>{};
  for (final start in byId.keys) {
    final path = <I>[];
    I? at = start;
    while (at != null && !path.contains(at)) {
      path.add(at);
      final node = byId[at];
      at = node == null ? null : parentOf(node);
    }
    if (at == null) continue;
    final cycle = path.sublist(path.indexOf(at));
    final smallest = cycle.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    if (reported.add(smallest)) {
      out.add(
        _err(
          code,
          'The $what parents form a cycle: ${cycle.join(' > ')}.',
          subject: smallest.toString(),
          field: 'parent',
          related: [for (final c in cycle) c.toString()],
        ),
      );
    }
  }
  return out;
}

/// IC-804: the 19 preserved ids are present at the planned levels and with
/// the planned parents.
List<Finding> validatePreservedAnatomy(AnatomyTree tree) {
  final out = <Finding>[];
  for (final p in preservedMuscleNodes) {
    final n = tree.node(p.id);
    if (n == null) {
      out.add(
        _err(
          'IC-804',
          'Preserved WP 8 id ${p.id} is missing.',
          subject: p.id.value,
        ),
      );
      continue;
    }
    if (n.level != p.level) {
      out.add(
        _err(
          'IC-804',
          'Preserved id ${p.id} is at level ${n.level}; the plan sets level '
              '${p.level}.',
          subject: p.id.value,
          field: 'level',
        ),
      );
    }
    if (n.parentId != p.parent) {
      out.add(
        _err(
          'IC-804',
          'Preserved id ${p.id} has parent ${n.parentId ?? 'none'}; the plan '
              'sets ${p.parent ?? 'none'}.',
          subject: p.id.value,
          field: 'parent',
        ),
      );
    }
    if (!n.isActive) {
      out.add(
        _err(
          'IC-804',
          'Preserved id ${p.id} is retired.',
          subject: p.id.value,
          field: 'status',
        ),
      );
    }
  }
  return out;
}

/// IC-805: families have no parent; patterns have a family parent; no cycles.
List<Finding> validatePatterns(Iterable<MovementPattern> patterns) {
  final out = <Finding>[];
  final byId = <MovementPatternId, MovementPattern>{};
  for (final p in patterns) {
    if (byId.containsKey(p.id)) {
      out.add(
        _err(
          'IC-805',
          'Duplicate movement pattern id ${p.id}.',
          subject: p.id.value,
        ),
      );
    } else {
      byId[p.id] = p;
    }
  }
  for (final p in byId.values) {
    final id = p.id.value;
    final parentId = p.parentId;
    if (parentId == null) {
      if (p.level != 1) {
        out.add(
          _err(
            'IC-805',
            'Pattern $id has no parent but is at level ${p.level}; only '
                'families are roots.',
            subject: id,
            field: 'parent',
          ),
        );
      }
      continue;
    }
    final parent = byId[parentId];
    if (p.level != 2) {
      out.add(
        _err(
          'IC-805',
          'Pattern $id has a parent but is at level ${p.level}; patterns are '
              'at level 2.',
          subject: id,
          field: 'level',
        ),
      );
    }
    if (parent == null) {
      out.add(
        _err(
          'IC-805',
          'Pattern $id names family $parentId, which does not exist.',
          subject: id,
          field: 'parent',
        ),
      );
    } else if (!parent.isFamily) {
      out.add(
        _err(
          'IC-805',
          'Pattern $id has parent $parentId, which is not a family.',
          subject: id,
          field: 'parent',
        ),
      );
    }
  }
  out.addAll(
    _cycles<MovementPattern, MovementPatternId>(
      byId,
      (p) => p.parentId,
      'IC-805',
      'pattern',
    ),
  );
  return out;
}

/// IC-806: the 21 existing equipment ids are present, unchanged in meaning
/// (flagged existing) and active; ids are unique.
List<Finding> validateEquipmentItems(Iterable<EquipmentItem> items) {
  final out = <Finding>[];
  final byId = <EquipmentItemId, EquipmentItem>{};
  for (final i in items) {
    if (byId.containsKey(i.id)) {
      out.add(
        _err('IC-806', 'Duplicate equipment id ${i.id}.', subject: i.id.value),
      );
    } else {
      byId[i.id] = i;
    }
  }
  for (final id in existingEquipmentIds) {
    final item = byId[id];
    if (item == null) {
      out.add(
        _err(
          'IC-806',
          'Existing equipment id $id is missing.',
          subject: id.value,
        ),
      );
    } else if (!item.existing) {
      out.add(
        _err(
          'IC-806',
          'Existing equipment id $id is not marked existing.',
          subject: id.value,
          field: 'status',
        ),
      );
    } else if (!item.isActive) {
      out.add(
        _err(
          'IC-806',
          'Existing equipment id $id is retired.',
          subject: id.value,
          field: 'status',
        ),
      );
    }
  }
  return out;
}

/// IC-807: definition, inclusion and exclusion text present for every anatomy
/// node and pattern.
List<Finding> validateReferenceTexts({
  Iterable<AnatomyNode> anatomy = const [],
  Iterable<MovementPattern> patterns = const [],
}) {
  final out = <Finding>[];
  void check(String id, String kind, String? def, String? inc, String? exc) {
    for (final (field, text) in [
      ('definition', def),
      ('includes', inc),
      ('excludes', exc),
    ]) {
      if (text == null || text.trim().isEmpty) {
        out.add(
          _err(
            'IC-807',
            'The $kind $id has no $field text.',
            subject: id,
            field: field,
          ),
        );
      }
    }
  }

  for (final n in anatomy) {
    check(n.id.value, 'anatomy node', n.definition, n.includes, n.excludes);
  }
  for (final p in patterns) {
    check(p.id.value, 'pattern', p.definition, p.includes, p.excludes);
  }
  return out;
}

/// IC-808: an id of the previous release is removed from a list (retire it
/// instead), or its parent or level changed.
List<Finding> validateReferenceAgainstPrevious({
  Iterable<AnatomyNode> previousAnatomy = const [],
  Iterable<AnatomyNode> anatomy = const [],
  Iterable<MovementPattern> previousPatterns = const [],
  Iterable<MovementPattern> patterns = const [],
  Iterable<EquipmentItem> previousEquipment = const [],
  Iterable<EquipmentItem> equipment = const [],
}) {
  final out = <Finding>[];
  final nowAnatomy = {for (final n in anatomy) n.id: n};
  for (final old in previousAnatomy) {
    final n = nowAnatomy[old.id];
    if (n == null) {
      out.add(
        _err(
          'IC-808',
          'Anatomy id ${old.id} was removed; retire it instead.',
          subject: old.id.value,
        ),
      );
    } else if (n.parentId != old.parentId || n.level != old.level) {
      out.add(
        _err(
          'IC-808',
          'Anatomy id ${old.id} changed parent or level.',
          subject: old.id.value,
        ),
      );
    }
  }
  final nowPatterns = {for (final p in patterns) p.id: p};
  for (final old in previousPatterns) {
    final p = nowPatterns[old.id];
    if (p == null) {
      out.add(
        _err(
          'IC-808',
          'Pattern id ${old.id} was removed; retire it instead.',
          subject: old.id.value,
        ),
      );
    } else if (p.parentId != old.parentId || p.level != old.level) {
      out.add(
        _err(
          'IC-808',
          'Pattern id ${old.id} changed parent or level.',
          subject: old.id.value,
        ),
      );
    }
  }
  final nowEquipment = {for (final i in equipment) i.id: i};
  for (final old in previousEquipment) {
    if (!nowEquipment.containsKey(old.id)) {
      out.add(
        _err(
          'IC-808',
          'Equipment id ${old.id} was removed; retire it instead.',
          subject: old.id.value,
        ),
      );
    }
  }
  return out;
}

/// IC-809: labels unique within a list and locale (warning).
List<Finding> validateReferenceLabels({
  Iterable<AnatomyNode> anatomy = const [],
  Iterable<MovementPattern> patterns = const [],
  Iterable<EquipmentItem> equipment = const [],
}) {
  final out = <Finding>[];
  void check(String list, Iterable<(String, Map<String, String>)> entries) {
    final seen = <String, String>{};
    for (final (id, labels) in entries) {
      for (final MapEntry(key: locale, value: label) in labels.entries) {
        final key = '$locale|${norm(label)}';
        final first = seen[key];
        if (first == null) {
          seen[key] = id;
        } else {
          out.add(
            Finding(
              code: 'IC-809',
              severity: Severity.warning,
              message:
                  'The $list label "$label" ($locale) is used by $first and '
                  '$id.',
              subjectId: id,
              related: [first],
            ),
          );
        }
      }
    }
  }

  check('anatomy', [for (final n in anatomy) (n.id.value, n.labels)]);
  check('pattern', [for (final p in patterns) (p.id.value, p.labels)]);
  check('equipment', [for (final i in equipment) (i.id.value, i.labels)]);
  return out;
}

/// IC-810: the reference ledger. Every reference id appears exactly once; the
/// ledger lifecycle equals the list lifecycle; a retired id has `retiredIn`
/// and a reason; an id never returns to active (against [previousLedger]).
List<Finding> validateLedger({
  required Iterable<LedgerEntry> ledger,
  Iterable<AnatomyNode> anatomy = const [],
  Iterable<MovementPattern> patterns = const [],
  Iterable<EquipmentItem> equipment = const [],
  Iterable<LedgerEntry> previousLedger = const [],
}) {
  final out = <Finding>[];
  final byKey = <String, LedgerEntry>{};
  for (final e in ledger) {
    final key = '${e.list.wire}:${e.id}';
    if (byKey.containsKey(key)) {
      out.add(
        _err(
          'IC-810',
          'Ledger lists ${e.list.wire} id ${e.id} more than once.',
          subject: e.id,
        ),
      );
    } else {
      byKey[key] = e;
    }
    if (e.status == ReferenceStatus.retired) {
      if ((e.retiredIn ?? '').isEmpty) {
        out.add(
          _err(
            'IC-810',
            'Retired ${e.list.wire} id ${e.id} has no retiredIn.',
            subject: e.id,
          ),
        );
      }
      if ((e.reason ?? '').isEmpty) {
        out.add(
          _err(
            'IC-810',
            'Retired ${e.list.wire} id ${e.id} has no reason.',
            subject: e.id,
          ),
        );
      }
    }
  }
  void check(ReferenceList list, Iterable<(String, ReferenceStatus)> refs) {
    final listed = <String>{};
    for (final (id, status) in refs) {
      listed.add(id);
      final entry = byKey['${list.wire}:$id'];
      if (entry == null) {
        out.add(
          _err(
            'IC-810',
            'The ${list.wire} id $id is not in the ledger.',
            subject: id,
          ),
        );
      } else if (entry.status != status) {
        out.add(
          _err(
            'IC-810',
            'The ${list.wire} id $id is ${status.name} in the list but '
                '${entry.status.name} in the ledger.',
            subject: id,
          ),
        );
      }
    }
    for (final e in byKey.values.where((e) => e.list == list)) {
      if (!listed.contains(e.id)) {
        out.add(
          _err(
            'IC-810',
            'Ledger entry ${e.list.wire} id ${e.id} has no node in the list.',
            subject: e.id,
          ),
        );
      }
    }
  }

  check(ReferenceList.anatomy, [
    for (final n in anatomy) (n.id.value, n.status),
  ]);
  check(ReferenceList.movementPattern, [
    for (final p in patterns) (p.id.value, p.status),
  ]);
  check(ReferenceList.equipment, [
    for (final i in equipment) (i.id.value, i.status),
  ]);
  for (final old in previousLedger) {
    if (old.status != ReferenceStatus.retired) continue;
    final now = byKey['${old.list.wire}:${old.id}'];
    if (now != null && now.status == ReferenceStatus.active) {
      out.add(
        _err(
          'IC-810',
          'The ${old.list.wire} id ${old.id} was retired and is active again; '
              'ids never return.',
          subject: old.id,
        ),
      );
    }
  }
  return out;
}
