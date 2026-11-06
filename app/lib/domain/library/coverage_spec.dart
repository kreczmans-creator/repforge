import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/reference_parsers.dart';

/// A term of a slot: what an exercise must also satisfy to fill the slot
/// (`coverage.json`, `countingRules.discriminatorKinds`).
sealed class SlotDiscriminator {
  const SlotDiscriminator();
}

/// A recorded attribute equals one of [values]; an unrecorded attribute never
/// matches.
final class AttributeDiscriminator extends SlotDiscriminator {
  const AttributeDiscriminator(this.attribute, this.values);

  final ExerciseAttribute attribute;
  final List<String> values;
}

/// The derived equipment class is one of [classes].
final class EquipmentClassDiscriminator extends SlotDiscriminator {
  const EquipmentClassDiscriminator(this.classes);

  final List<EquipmentClass> classes;
}

/// The laterality is one of [values].
final class LateralityDiscriminator extends SlotDiscriminator {
  const LateralityDiscriminator(this.values);

  final List<Laterality> values;
}

/// The mechanics is one of [values]; unset never matches.
final class MechanicsDiscriminator extends SlotDiscriminator {
  const MechanicsDiscriminator(this.values);

  final List<Mechanics> values;
}

/// The exercise has [node] (or a descendant) as a target; [primaryOnly]
/// restricts it to the primary role.
final class SubTargetDiscriminator extends SlotDiscriminator {
  const SubTargetDiscriminator(this.node, {required this.primaryOnly});

  final AnatomyNodeId node;
  final bool primaryOnly;
}

/// An intended entry of a slot or set (not a required name).
@immutable
final class CoverageEntry {
  const CoverageEntry({
    required this.name,
    required this.counted,
    this.equipmentClass,
    this.laterality,
    this.mechanics,
    this.group,
  });

  final String name;
  final bool counted;
  final EquipmentClass? equipmentClass;
  final Laterality? laterality;
  final Mechanics? mechanics;

  /// For the static stretch set: the coverage group the entry serves.
  final String? group;
}

/// One slot of a group: a function with patterns, discriminators and a
/// minimum that equals its counted entries.
@immutable
final class CoverageSlot {
  const CoverageSlot({
    required this.id,
    required this.label,
    required this.patterns,
    required this.discriminators,
    required this.min,
    required this.entries,
  });

  final String id;
  final String label;
  final List<MovementPatternId> patterns;
  final List<SlotDiscriminator> discriminators;
  final int min;
  final List<CoverageEntry> entries;
}

/// The minimums derived from the counted entries of a group.
@immutable
final class GroupDerived {
  const GroupDerived({
    required this.compound,
    required this.isolation,
    required this.bilateral,
    required this.unilateralOrAlternating,
    required this.equipmentClasses,
    required this.variationFamilies,
    required this.classCap,
  });

  final int compound;
  final int isolation;
  final int bilateral;
  final int unilateralOrAlternating;
  final Map<EquipmentClass, int> equipmentClasses;
  final int variationFamilies;
  final double classCap;
}

/// A coverage group: an L2 group (or the three lower-leg groups) with slots.
@immutable
final class CoverageGroup {
  const CoverageGroup({
    required this.id,
    required this.label,
    required this.tranche,
    required this.nodes,
    required this.bodyweightExempt,
    required this.slots,
    required this.slotTotal,
    required this.derived,
  });

  final String id;
  final String label;
  final String tranche;
  final List<AnatomyNodeId> nodes;
  final bool bodyweightExempt;
  final List<CoverageSlot> slots;
  final int slotTotal;
  final GroupDerived derived;

  Set<MovementPatternId> get patterns => {for (final s in slots) ...s.patterns};
}

/// A conditioning, power or mobility set, measured by pattern.
@immutable
final class CoverageSet {
  const CoverageSet({
    required this.id,
    required this.label,
    required this.patterns,
    required this.min,
    required this.requiresEquipment,
    required this.categories,
    required this.eachGroup,
    required this.entries,
    this.note,
  });

  final String id;
  final String label;
  final List<MovementPatternId> patterns;
  final int min;
  final List<EquipmentItemId> requiresEquipment;

  /// When non-empty, only exercises of these categories count.
  final List<String> categories;

  /// Rule `eachGroup`: one exercise per coverage group counts.
  final bool eachGroup;
  final List<CoverageEntry> entries;
  final String? note;

  /// Tranche of the set: all sets belong to 5.7.
  String get tranche => '5.7';
}

/// A band `[low, high]` of shares.
@immutable
final class ShareBand {
  const ShareBand(this.low, this.high);

  final double low;
  final double high;

  bool contains(double share) => share >= low - 1e-9 && share <= high + 1e-9;
}

/// Difficulty bands per scope (`coverage-matrix.md` section 8).
@immutable
final class DifficultyBands {
  const DifficultyBands(this.beginner, this.intermediate, this.advanced);

  final ShareBand beginner;
  final ShareBand intermediate;
  final ShareBand advanced;
}

/// Thresholds of the approved metrics (`coverage.json`, `metrics`).
@immutable
final class CoverageMetrics {
  const CoverageMetrics({
    required this.primariesMeanMaximum,
    required this.primariesTwoOrMoreShareMaximum,
    required this.regionalBands,
    required this.conditioningBands,
    required this.mobilityBands,
    required this.largeGroupBeginnerShare,
    required this.largeGroupIntermediateShare,
    required this.largeGroupAdvancedShare,
    required this.largeGroupAdvancedMinimum,
    required this.smallGroupBeginnerMinimum,
    required this.smallGroupIntermediateMinimum,
  });

  final double primariesMeanMaximum;
  final double primariesTwoOrMoreShareMaximum;
  final DifficultyBands regionalBands;
  final DifficultyBands conditioningBands;
  final DifficultyBands mobilityBands;
  final double largeGroupBeginnerShare;
  final double largeGroupIntermediateShare;
  final double largeGroupAdvancedShare;
  final int largeGroupAdvancedMinimum;
  final int smallGroupBeginnerMinimum;
  final int smallGroupIntermediateMinimum;
}

/// The class cap: at most `max(55 percent of the group total, 4)` exercises in
/// one equipment class (`coverage.json`, `countingRules.caps`).
const double classCapShare = 0.55;
const int classCapFloor = 4;

/// The parsed `coverage.json`.
@immutable
final class CoverageSpec {
  const CoverageSpec({
    required this.groups,
    required this.sets,
    required this.attributeValues,
    required this.metrics,
  });

  final List<CoverageGroup> groups;
  final List<CoverageSet> sets;

  /// The attribute vocabulary recorded in the file, for comparison with the
  /// domain vocabulary (IC-811).
  final Map<String, List<String>> attributeValues;
  final CoverageMetrics metrics;

  int get slotMinimumTotal => groups.fold(0, (n, g) => n + g.slotTotal);
  int get setMinimumTotal => sets.fold(0, (n, s) => n + s.min);
}

/// Parses `coverage.json`.
Result<CoverageSpec> parseCoverageSpec(Object? json) {
  final r = JsonReader();
  final root = r.map(json, r'$');
  if (root == null) return r.finish('coverage specification', null);
  if (root['formatVersion'] != referenceFormatVersion) {
    r.fail('formatVersion', 'Expected format version $referenceFormatVersion.');
  }

  List<CoverageEntry> entries(Object? raw, String path) {
    final list = r.list(raw, path);
    final out = <CoverageEntry>[];
    if (list == null) return out;
    for (var i = 0; i < list.length; i++) {
      final p = '$path[$i]';
      final m = r.map(list[i], p);
      if (m == null) continue;
      final name = r.string(m, 'name', p);
      final cls = m['equipmentClass'] == null
          ? null
          : r.enumValue(EquipmentClass.values, m, 'equipmentClass', p);
      final lat = m['laterality'] == null
          ? null
          : r.enumValue(Laterality.values, m, 'laterality', p);
      final mech = m['mechanics'] == null
          ? null
          : r.enumValue(Mechanics.values, m, 'mechanics', p);
      if (name == null) continue;
      out.add(
        CoverageEntry(
          name: name,
          counted: r.boolean(m, 'counted', p, fallback: true),
          equipmentClass: cls,
          laterality: lat,
          mechanics: mech,
          group: r.optionalString(m, 'group', p),
        ),
      );
    }
    return out;
  }

  SlotDiscriminator? discriminator(Object? raw, String path) {
    final m = r.map(raw, path);
    if (m == null) return null;
    final kind = r.string(m, 'kind', path);
    switch (kind) {
      case 'attribute':
        final name = r.string(m, 'attribute', path);
        final attribute = enumByName(ExerciseAttribute.values, name);
        if (attribute == null) {
          r.fail('$path.attribute', 'Unknown attribute.');
          return null;
        }
        return AttributeDiscriminator(
          attribute,
          r.stringList(m, 'values', path),
        );
      case 'equipmentClass':
        final values = <EquipmentClass>[];
        for (final v in r.stringList(m, 'values', path)) {
          final c = enumByName(EquipmentClass.values, v);
          if (c == null) {
            r.fail('$path.values', 'Unknown equipment class $v.');
          } else {
            values.add(c);
          }
        }
        return EquipmentClassDiscriminator(values);
      case 'laterality':
        final values = <Laterality>[];
        for (final v in r.stringList(m, 'values', path)) {
          final c = enumByName(Laterality.values, v);
          if (c == null) {
            r.fail('$path.values', 'Unknown laterality $v.');
          } else {
            values.add(c);
          }
        }
        return LateralityDiscriminator(values);
      case 'mechanics':
        final values = <Mechanics>[];
        for (final v in r.stringList(m, 'values', path)) {
          final c = enumByName(Mechanics.values, v);
          if (c == null) {
            r.fail('$path.values', 'Unknown mechanics $v.');
          } else {
            values.add(c);
          }
        }
        return MechanicsDiscriminator(values);
      case 'subTarget':
        final node = r.string(m, 'node', path);
        final role = r.string(m, 'role', path);
        if (role != null && role != 'primary' && role != 'any') {
          r.fail('$path.role', 'Expected primary or any.');
        }
        if (node == null) return null;
        return SubTargetDiscriminator(
          AnatomyNodeId(node),
          primaryOnly: role == 'primary',
        );
      default:
        r.fail('$path.kind', 'Unknown discriminator kind.');
        return null;
    }
  }

  final groups = <CoverageGroup>[];
  final rawGroups = r.list(root['groups'], 'groups');
  if (rawGroups != null) {
    for (var gi = 0; gi < rawGroups.length; gi++) {
      final gp = 'groups[$gi]';
      final g = r.map(rawGroups[gi], gp);
      if (g == null) continue;
      final id = r.string(g, 'id', gp);
      final label = r.string(g, 'label', gp);
      final tranche = r.string(g, 'tranche', gp);
      final total = r.integer(g, 'slotTotal', gp);
      final slots = <CoverageSlot>[];
      final rawSlots = r.list(g['slots'], '$gp.slots');
      if (rawSlots != null) {
        for (var si = 0; si < rawSlots.length; si++) {
          final sp = '$gp.slots[$si]';
          final s = r.map(rawSlots[si], sp);
          if (s == null) continue;
          final sid = r.string(s, 'id', sp);
          final slabel = r.string(s, 'label', sp);
          final min = r.integer(s, 'min', sp);
          final discs = <SlotDiscriminator>[];
          final rawDiscs = r.list(s['discriminator'], '$sp.discriminator');
          if (rawDiscs != null) {
            for (var di = 0; di < rawDiscs.length; di++) {
              final d = discriminator(rawDiscs[di], '$sp.discriminator[$di]');
              if (d != null) discs.add(d);
            }
          }
          if (sid == null || slabel == null || min == null) continue;
          slots.add(
            CoverageSlot(
              id: sid,
              label: slabel,
              patterns: [
                for (final p in r.stringList(s, 'patterns', sp))
                  MovementPatternId(p),
              ],
              discriminators: List.unmodifiable(discs),
              min: min,
              entries: List.unmodifiable(entries(s['entries'], '$sp.entries')),
            ),
          );
        }
      }
      final dm = r.map(g['derived'], '$gp.derived');
      GroupDerived? derived;
      if (dm != null) {
        final mech = r.map(dm['mechanics'], '$gp.derived.mechanics');
        final lat = r.map(dm['laterality'], '$gp.derived.laterality');
        final cls = r.map(
          dm['equipmentClasses'],
          '$gp.derived.equipmentClasses',
        );
        final families = r.integer(dm, 'variationFamilies', '$gp.derived');
        final cap = dm['classCap'];
        if (cap is! num) r.fail('$gp.derived.classCap', 'Expected a number.');
        if (mech != null &&
            lat != null &&
            cls != null &&
            families != null &&
            cap is num) {
          final classes = <EquipmentClass, int>{};
          for (final e in cls.entries) {
            final c = enumByName(EquipmentClass.values, e.key);
            final n = e.value;
            if (c == null || n is! int) {
              r.fail('$gp.derived.equipmentClasses.${e.key}', 'Invalid entry.');
            } else {
              classes[c] = n;
            }
          }
          derived = GroupDerived(
            compound: _count(r, mech, 'compound', '$gp.derived.mechanics'),
            isolation: _count(r, mech, 'isolation', '$gp.derived.mechanics'),
            bilateral: _count(r, lat, 'bilateral', '$gp.derived.laterality'),
            unilateralOrAlternating: _count(
              r,
              lat,
              'unilateralOrAlternating',
              '$gp.derived.laterality',
            ),
            equipmentClasses: Map.unmodifiable(classes),
            variationFamilies: families,
            classCap: cap.toDouble(),
          );
        }
      }
      if (id == null ||
          label == null ||
          tranche == null ||
          total == null ||
          derived == null) {
        continue;
      }
      groups.add(
        CoverageGroup(
          id: id,
          label: label,
          tranche: tranche,
          nodes: [
            for (final n in r.stringList(g, 'nodes', gp)) AnatomyNodeId(n),
          ],
          bodyweightExempt: r.boolean(g, 'bodyweightExempt', gp),
          slots: List.unmodifiable(slots),
          slotTotal: total,
          derived: derived,
        ),
      );
    }
  }

  final sets = <CoverageSet>[];
  final rawSets = r.list(root['sets'], 'sets');
  if (rawSets != null) {
    for (var i = 0; i < rawSets.length; i++) {
      final p = 'sets[$i]';
      final s = r.map(rawSets[i], p);
      if (s == null) continue;
      final id = r.string(s, 'id', p);
      final label = r.string(s, 'label', p);
      final min = r.integer(s, 'min', p);
      final rule = r.optionalString(s, 'rule', p);
      if (rule != null && rule != 'eachGroup') {
        r.fail('$p.rule', 'Expected eachGroup.');
      }
      if (id == null || label == null || min == null) continue;
      sets.add(
        CoverageSet(
          id: id,
          label: label,
          patterns: [
            for (final x in r.stringList(s, 'patterns', p))
              MovementPatternId(x),
          ],
          min: min,
          requiresEquipment: [
            for (final x in r.stringList(s, 'requiresEquipment', p))
              EquipmentItemId(x),
          ],
          categories: r.stringList(s, 'categories', p),
          eachGroup: rule == 'eachGroup',
          entries: List.unmodifiable(entries(s['entries'], '$p.entries')),
          note: r.optionalString(s, 'note', p),
        ),
      );
    }
  }

  // Attribute vocabulary.
  final attributes = <String, List<String>>{};
  final proposed = r.map(
    root['exerciseAttributesProposed'],
    'exerciseAttributesProposed',
  );
  final attrMap = proposed == null
      ? null
      : r.map(proposed['attributes'], 'exerciseAttributesProposed.attributes');
  if (attrMap != null) {
    for (final e in attrMap.entries) {
      final def = r.map(
        e.value,
        'exerciseAttributesProposed.attributes.${e.key}',
      );
      final values = def == null
          ? null
          : r.map(
              def['values'],
              'exerciseAttributesProposed.attributes.${e.key}.values',
            );
      if (values != null) attributes[e.key] = values.keys.toList();
    }
  }

  final metrics = _metrics(r, root['metrics']);
  if (groups.isEmpty && r.errors.isEmpty) r.fail('groups', 'No groups.');
  return r.finish(
    'coverage specification',
    metrics == null
        ? null
        : CoverageSpec(
            groups: List.unmodifiable(groups),
            sets: List.unmodifiable(sets),
            attributeValues: Map.unmodifiable(attributes),
            metrics: metrics,
          ),
  );
}

int _count(JsonReader r, Map<String, Object?> m, String key, String path) =>
    r.integer(m, key, path) ?? 0;

CoverageMetrics? _metrics(JsonReader r, Object? raw) {
  final m = r.map(raw, 'metrics');
  if (m == null) return null;
  final primaries = r.map(
    m['primariesPerExercise'],
    'metrics.primariesPerExercise',
  );
  final difficulty = r.map(m['difficulty'], 'metrics.difficulty');
  if (primaries == null || difficulty == null) return null;

  ShareBand? band(Map<String, Object?> parent, String key, String path) {
    final v = parent[key];
    if (v is List<Object?> && v.length == 2 && v[0] is num && v[1] is num) {
      return ShareBand((v[0]! as num).toDouble(), (v[1]! as num).toDouble());
    }
    r.fail('$path.$key', 'Expected [low, high].');
    return null;
  }

  DifficultyBands? bands(String key) {
    final p = 'metrics.difficulty.$key';
    final b = r.map(difficulty[key], p);
    if (b == null) return null;
    final x = band(b, 'beginner', p);
    final y = band(b, 'intermediate', p);
    final z = band(b, 'advanced', p);
    return x == null || y == null || z == null
        ? null
        : DifficultyBands(x, y, z);
  }

  double number(Map<String, Object?> parent, String key, String path) {
    final v = parent[key];
    if (v is num) return v.toDouble();
    r.fail('$path.$key', 'Expected a number.');
    return 0;
  }

  final large = r.map(
    difficulty['groupWithTotalAtLeast20'],
    'metrics.difficulty.groupWithTotalAtLeast20',
  );
  final small = r.map(
    difficulty['groupWithTotalBelow20'],
    'metrics.difficulty.groupWithTotalBelow20',
  );
  final regional = bands('regionalTranche');
  final conditioning = bands('conditioning');
  final mobility = bands('mobility');
  if (large == null ||
      small == null ||
      regional == null ||
      conditioning == null ||
      mobility == null) {
    return null;
  }
  return CoverageMetrics(
    primariesMeanMaximum: number(
      primaries,
      'meanMaximum',
      'metrics.primariesPerExercise',
    ),
    primariesTwoOrMoreShareMaximum: number(
      primaries,
      'shareWithTwoOrMorePrimariesMaximum',
      'metrics.primariesPerExercise',
    ),
    regionalBands: regional,
    conditioningBands: conditioning,
    mobilityBands: mobility,
    largeGroupBeginnerShare: number(
      large,
      'beginner',
      'metrics.difficulty.groupWithTotalAtLeast20',
    ),
    largeGroupIntermediateShare: number(
      large,
      'intermediate',
      'metrics.difficulty.groupWithTotalAtLeast20',
    ),
    largeGroupAdvancedShare: number(
      large,
      'advancedShare',
      'metrics.difficulty.groupWithTotalAtLeast20',
    ),
    largeGroupAdvancedMinimum: number(
      large,
      'advancedMinimumExercises',
      'metrics.difficulty.groupWithTotalAtLeast20',
    ).round(),
    smallGroupBeginnerMinimum: number(
      small,
      'beginner',
      'metrics.difficulty.groupWithTotalBelow20',
    ).round(),
    smallGroupIntermediateMinimum: number(
      small,
      'intermediate',
      'metrics.difficulty.groupWithTotalBelow20',
    ).round(),
  );
}

/// IC-811: the references of the coverage specification resolve, every slot
/// minimum equals its counted entries, every group total and derived minimum
/// equals the counted entries, and no slot depends on a retired id.
List<Finding> validateCoverageSpec(CoverageSpec spec, ReferenceData reference) {
  final out = <Finding>[];
  void err(String subject, String message) => out.add(
    Finding(
      code: 'IC-811',
      severity: Severity.error,
      message: message,
      subjectId: subject,
    ),
  );

  void pattern(String subject, MovementPatternId id) {
    final p = reference.patterns.pattern(id);
    if (p == null) {
      err(subject, 'The pattern $id does not exist.');
    } else if (p.isFamily) {
      err(subject, 'The pattern $id is a family; slots use leaf patterns.');
    } else if (!p.isActive) {
      err(subject, 'The slot depends on the retired pattern $id.');
    }
  }

  for (final g in spec.groups) {
    for (final n in g.nodes) {
      final node = reference.anatomy.node(n);
      if (node == null) {
        err(g.id, 'The group node $n does not exist.');
      } else if (!node.isActive) {
        err(g.id, 'The group depends on the retired node $n.');
      }
    }
    var sum = 0;
    var compound = 0;
    var isolation = 0;
    var bilateral = 0;
    var unilateral = 0;
    final classes = <EquipmentClass, int>{};
    for (final s in g.slots) {
      sum += s.min;
      final counted = s.entries.where((e) => e.counted).toList();
      if (counted.length != s.min) {
        err(
          s.id,
          'The minimum ${s.min} differs from ${counted.length} counted '
          'entries.',
        );
      }
      for (final e in counted) {
        if (e.mechanics == Mechanics.compound) compound++;
        if (e.mechanics == Mechanics.isolation) isolation++;
        if (e.laterality == Laterality.bilateral) bilateral++;
        if (e.laterality != null && e.laterality != Laterality.bilateral) {
          unilateral++;
        }
        final c = e.equipmentClass;
        if (c != null) classes.update(c, (n) => n + 1, ifAbsent: () => 1);
      }
      for (final p in s.patterns) {
        pattern(s.id, p);
      }
      for (final d in s.discriminators) {
        switch (d) {
          case AttributeDiscriminator():
            for (final v in d.values) {
              if (!AttributeVocabulary.isValid(d.attribute, v)) {
                err(
                  s.id,
                  'The value $v is not in the ${d.attribute.name} vocabulary.',
                );
              }
            }
          case SubTargetDiscriminator():
            final node = reference.anatomy.node(d.node);
            if (node == null) {
              err(s.id, 'The sub-target ${d.node} does not exist.');
            } else if (node.level != 2 && node.level != 3) {
              err(
                s.id,
                'The sub-target ${d.node} is at level ${node.level}; only '
                'level 2 or 3 is allowed.',
              );
            }
          case EquipmentClassDiscriminator() ||
              LateralityDiscriminator() ||
              MechanicsDiscriminator():
            break;
        }
      }
    }
    if (sum != g.slotTotal) {
      err(
        g.id,
        'The slot total ${g.slotTotal} differs from the sum $sum of '
        'the slot minimums.',
      );
    }
    final d = g.derived;
    if (d.compound != compound || d.isolation != isolation) {
      err(
        g.id,
        'The derived mechanics minimums differ from the counted entries.',
      );
    }
    if (d.bilateral != bilateral || d.unilateralOrAlternating != unilateral) {
      err(
        g.id,
        'The derived laterality minimums differ from the counted entries.',
      );
    }
    for (final c in EquipmentClass.values) {
      if ((d.equipmentClasses[c] ?? 0) != (classes[c] ?? 0)) {
        err(
          g.id,
          'The derived ${c.name} minimum differs from the counted entries.',
        );
      }
    }
  }
  for (final s in spec.sets) {
    for (final p in s.patterns) {
      pattern(s.id, p);
    }
    for (final item in s.requiresEquipment) {
      if (!reference.equipment.contains(item)) {
        err(s.id, 'The set needs the equipment $item, which does not exist.');
      }
    }
    final counted = s.entries.where((e) => e.counted).length;
    if (counted != s.min) {
      err(s.id, 'The minimum ${s.min} differs from $counted counted entries.');
    }
    if (s.eachGroup) {
      final ids = {for (final g in spec.groups) g.id};
      for (final e in s.entries.where((e) => e.counted)) {
        if (!ids.contains(e.group)) {
          err(s.id, 'The entry ${e.name} names the unknown group ${e.group}.');
        }
      }
      if (s.min != spec.groups.length) {
        err(
          s.id,
          'The each-group set needs one entry per group '
          '(${spec.groups.length}).',
        );
      }
    }
  }
  for (final MapEntry(key: name, value: values)
      in spec.attributeValues.entries) {
    final attribute = enumByName(ExerciseAttribute.values, name);
    if (attribute == null) {
      err(name, 'The attribute $name is not in the domain vocabulary.');
    } else if (!_sameSet(values, AttributeVocabulary.valuesOf(attribute))) {
      err(name, 'The values of $name differ from the domain vocabulary.');
    }
  }
  return out;
}

bool _sameSet(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);
