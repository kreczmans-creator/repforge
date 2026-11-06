import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/reference_validation.dart';

/// Pure parsers for the approved reference file formats
/// (`docs/catalogue/reference/*.json`, format version 1). Each takes the
/// decoded JSON (`Map<String, Object?>`), reads no file and returns a
/// [Result]: all problems are collected in the `fieldErrors` of one
/// [ValidationError], keyed by a path such as `nodes[3].level`.
///
/// The parsers check shape and types only. The structural rules (parents,
/// levels, cycles, fullBody) are the validators in `reference_validation.dart`.
const int referenceFormatVersion = 1;

/// Collects problems while reading a decoded JSON document.
final class JsonReader {
  JsonReader();

  final Map<String, String> errors = {};

  void fail(String path, String message) =>
      errors.putIfAbsent(path, () => message);

  Map<String, Object?>? map(Object? value, String path) {
    if (value is Map<String, Object?>) return value;
    fail(path, 'Expected an object.');
    return null;
  }

  List<Object?>? list(Object? value, String path) {
    if (value is List<Object?>) return value;
    fail(path, 'Expected a list.');
    return null;
  }

  String? string(Map<String, Object?> m, String key, String path) {
    final v = m[key];
    if (v is String && v.isNotEmpty) return v;
    fail('$path.$key', 'Expected a non-empty string.');
    return null;
  }

  String? optionalString(Map<String, Object?> m, String key, String path) {
    final v = m[key];
    if (v == null) return null;
    if (v is String) return v;
    fail('$path.$key', 'Expected a string or null.');
    return null;
  }

  int? integer(Map<String, Object?> m, String key, String path) {
    final v = m[key];
    if (v is int) return v;
    fail('$path.$key', 'Expected an integer.');
    return null;
  }

  bool boolean(
    Map<String, Object?> m,
    String key,
    String path, {
    bool fallback = false,
  }) {
    final v = m[key];
    if (v == null) return fallback;
    if (v is bool) return v;
    fail('$path.$key', 'Expected true or false.');
    return fallback;
  }

  List<String> stringList(Map<String, Object?> m, String key, String path) {
    final v = m[key];
    if (v == null) return const [];
    if (v is List<Object?> && v.every((e) => e is String)) {
      return v.cast<String>();
    }
    fail('$path.$key', 'Expected a list of strings.');
    return const [];
  }

  T? enumValue<T extends Enum>(
    List<T> values,
    Map<String, Object?> m,
    String key,
    String path,
  ) {
    final v = enumByName(values, m[key]);
    if (v == null) {
      fail(
        '$path.$key',
        'Expected one of ${values.map((e) => e.name).join(', ')}.',
      );
    }
    return v;
  }

  /// Checks `formatVersion` and reads `provider` and `locale`.
  ({ProviderId provider, String locale})? header(Map<String, Object?> root) {
    final version = root['formatVersion'];
    if (version != referenceFormatVersion) {
      fail('formatVersion', 'Expected format version $referenceFormatVersion.');
    }
    final provider = string(root, 'provider', '');
    final locale = string(root, 'locale', '');
    if (provider == null || locale == null) return null;
    return (provider: ProviderId(provider), locale: locale);
  }

  ReferenceStatus? lifecycle(Map<String, Object?> m, String path) =>
      enumValue(ReferenceStatus.values, m, 'lifecycle', path);

  Result<T> finish<T>(String what, T? value) {
    if (errors.isNotEmpty || value == null) {
      final first = errors.entries.first;
      return Result.err(
        ValidationError(
          'Invalid $what: ${errors.length} problem(s); '
          'first at ${first.key}: ${first.value}',
          field: first.key,
          fieldErrors: Map.unmodifiable(errors),
        ),
      );
    }
    return Result.ok(value);
  }
}

/// The parsed `anatomy.json`.
@immutable
final class AnatomyReference {
  const AnatomyReference({
    required this.provider,
    required this.locale,
    required this.nodes,
    required this.preservedIds,
  });

  final ProviderId provider;
  final String locale;
  final List<AnatomyNode> nodes;

  /// `preservedWp8Ids`: the 19 WP 8 muscle ids.
  final List<AnatomyNodeId> preservedIds;
}

/// The parsed `movement-patterns.json`.
@immutable
final class PatternReference {
  const PatternReference({
    required this.provider,
    required this.locale,
    required this.nodes,
  });

  final ProviderId provider;
  final String locale;
  final List<MovementPattern> nodes;
}

/// An equipment item that was considered and not proposed.
@immutable
final class NotProposedEquipment {
  const NotProposedEquipment(this.id, this.label, this.reason);

  final String id;
  final String label;
  final String reason;
}

/// The parsed `equipment.json`.
@immutable
final class EquipmentReference {
  const EquipmentReference({
    required this.provider,
    required this.locale,
    required this.classes,
    required this.items,
    required this.notProposed,
  });

  final ProviderId provider;
  final String locale;
  final List<EquipmentClass> classes;
  final List<EquipmentItem> items;
  final List<NotProposedEquipment> notProposed;
}

/// Parses `anatomy.json`.
Result<AnatomyReference> parseAnatomyReference(Object? json) {
  final r = JsonReader();
  final root = r.map(json, r'$');
  if (root == null) return r.finish('anatomy reference data', null);
  final header = r.header(root);
  final rawNodes = r.list(root['nodes'], 'nodes');
  final nodes = <AnatomyNode>[];
  if (header != null && rawNodes != null) {
    for (var i = 0; i < rawNodes.length; i++) {
      final path = 'nodes[$i]';
      final m = r.map(rawNodes[i], path);
      if (m == null) continue;
      final id = r.string(m, 'id', path);
      final level = r.integer(m, 'level', path);
      final sort = r.integer(m, 'sort', path);
      final label = r.string(m, 'label', path);
      final status = r.lifecycle(m, path);
      final parent = r.optionalString(m, 'parent', path);
      final nonAnatomical = r.boolean(m, 'nonAnatomical', path);
      if (id == null ||
          level == null ||
          sort == null ||
          label == null ||
          status == null) {
        continue;
      }
      nodes.add(
        AnatomyNode(
          id: AnatomyNodeId(id),
          parentId: parent == null ? null : AnatomyNodeId(parent),
          level: level,
          nonAnatomical: nonAnatomical,
          sort: sort,
          labels: {header.locale: label},
          status: status,
          providerId: header.provider,
          definition: r.optionalString(m, 'definition', path),
          includes: r.optionalString(m, 'includes', path),
          excludes: r.optionalString(m, 'excludes', path),
          note: r.optionalString(m, 'note', path),
        ),
      );
    }
  }
  final preserved = r.stringList(root, 'preservedWp8Ids', r'$');
  return r.finish(
    'anatomy reference data',
    header == null
        ? null
        : AnatomyReference(
            provider: header.provider,
            locale: header.locale,
            nodes: List.unmodifiable(nodes),
            preservedIds: List.unmodifiable([
              for (final p in preserved) AnatomyNodeId(p),
            ]),
          ),
  );
}

/// Parses `movement-patterns.json`.
Result<PatternReference> parsePatternReference(Object? json) {
  final r = JsonReader();
  final root = r.map(json, r'$');
  if (root == null) return r.finish('movement pattern reference data', null);
  final header = r.header(root);
  final rawNodes = r.list(root['nodes'], 'nodes');
  final nodes = <MovementPattern>[];
  if (header != null && rawNodes != null) {
    for (var i = 0; i < rawNodes.length; i++) {
      final path = 'nodes[$i]';
      final m = r.map(rawNodes[i], path);
      if (m == null) continue;
      final id = r.string(m, 'id', path);
      final level = r.integer(m, 'level', path);
      final sort = r.integer(m, 'sort', path);
      final label = r.string(m, 'label', path);
      final status = r.lifecycle(m, path);
      final parent = r.optionalString(m, 'parent', path);
      if (id == null ||
          level == null ||
          sort == null ||
          label == null ||
          status == null) {
        continue;
      }
      nodes.add(
        MovementPattern(
          id: MovementPatternId(id),
          parentId: parent == null ? null : MovementPatternId(parent),
          level: level,
          sort: sort,
          labels: {header.locale: label},
          status: status,
          providerId: header.provider,
          relatedCategories: r.stringList(m, 'relatedCategories', path),
          definition: r.optionalString(m, 'definition', path),
          includes: r.optionalString(m, 'includes', path),
          excludes: r.optionalString(m, 'excludes', path),
          note: r.optionalString(m, 'note', path),
        ),
      );
    }
  }
  return r.finish(
    'movement pattern reference data',
    header == null
        ? null
        : PatternReference(
            provider: header.provider,
            locale: header.locale,
            nodes: List.unmodifiable(nodes),
          ),
  );
}

/// Parses `equipment.json`.
Result<EquipmentReference> parseEquipmentReference(Object? json) {
  final r = JsonReader();
  final root = r.map(json, r'$');
  if (root == null) return r.finish('equipment reference data', null);
  final header = r.header(root);
  final classes = <EquipmentClass>[];
  final rawClasses = r.list(root['classes'], 'classes');
  if (rawClasses != null) {
    for (var i = 0; i < rawClasses.length; i++) {
      final c = enumByName(EquipmentClass.values, rawClasses[i]);
      if (c == null) {
        r.fail('classes[$i]', 'Unknown equipment class.');
      } else {
        classes.add(c);
      }
    }
  }
  final rawNodes = r.list(root['nodes'], 'nodes');
  final items = <EquipmentItem>[];
  if (header != null && rawNodes != null) {
    for (var i = 0; i < rawNodes.length; i++) {
      final path = 'nodes[$i]';
      final m = r.map(rawNodes[i], path);
      if (m == null) continue;
      final id = r.string(m, 'id', path);
      final sort = r.integer(m, 'sort', path);
      final label = r.string(m, 'label', path);
      final status = r.lifecycle(m, path);
      final cls = r.enumValue(EquipmentClass.values, m, 'equipmentClass', path);
      final role = r.enumValue(EquipmentDefaultRole.values, m, 'role', path);
      final origin = r.string(m, 'status', path);
      if (origin != null && origin != 'existing' && origin != 'approved') {
        r.fail('$path.status', 'Expected existing or approved.');
      }
      if (id == null ||
          sort == null ||
          label == null ||
          status == null ||
          cls == null ||
          role == null) {
        continue;
      }
      items.add(
        EquipmentItem(
          id: EquipmentItemId(id),
          sort: sort,
          labels: {header.locale: label},
          equipmentClass: cls,
          defaultRole: role,
          existing: origin == 'existing',
          status: status,
          providerId: header.provider,
          note: r.optionalString(m, 'note', path),
        ),
      );
    }
  }
  final notProposed = <NotProposedEquipment>[];
  final rawNot = root['notProposed'];
  if (rawNot != null) {
    final list = r.list(rawNot, 'notProposed');
    if (list != null) {
      for (var i = 0; i < list.length; i++) {
        final path = 'notProposed[$i]';
        final m = r.map(list[i], path);
        if (m == null) continue;
        final id = r.string(m, 'id', path);
        final label = r.string(m, 'label', path);
        final reason = r.string(m, 'reason', path);
        if (id != null && label != null && reason != null) {
          notProposed.add(NotProposedEquipment(id, label, reason));
        }
      }
    }
  }
  return r.finish(
    'equipment reference data',
    header == null
        ? null
        : EquipmentReference(
            provider: header.provider,
            locale: header.locale,
            classes: List.unmodifiable(classes),
            items: List.unmodifiable(items),
            notProposed: List.unmodifiable(notProposed),
          ),
  );
}

/// Parses `ledger.json` into its entries.
Result<List<LedgerEntry>> parseLedger(Object? json) {
  final r = JsonReader();
  final root = r.map(json, r'$');
  if (root == null) return r.finish('reference ledger', null);
  if (root['formatVersion'] != referenceFormatVersion) {
    r.fail('formatVersion', 'Expected format version $referenceFormatVersion.');
  }
  final raw = r.list(root['entries'], 'entries');
  final entries = <LedgerEntry>[];
  if (raw != null) {
    for (var i = 0; i < raw.length; i++) {
      final path = 'entries[$i]';
      final m = r.map(raw[i], path);
      if (m == null) continue;
      final listName = r.string(m, 'list', path);
      ReferenceList? list;
      for (final l in ReferenceList.values) {
        if (l.wire == listName) list = l;
      }
      if (listName != null && list == null) {
        r.fail('$path.list', 'Expected anatomy, movementPattern or equipment.');
      }
      final id = r.string(m, 'id', path);
      final status = r.lifecycle(m, path);
      if (list == null || id == null || status == null) continue;
      entries.add(
        LedgerEntry(
          list: list,
          id: id,
          status: status,
          introducedIn: r.optionalString(m, 'introducedIn', path),
          retiredIn: r.optionalString(m, 'retiredIn', path),
          replacedBy: r.optionalString(m, 'replacedBy', path),
          reason: r.optionalString(m, 'reason', path),
        ),
      );
    }
  }
  return r.finish('reference ledger', List<LedgerEntry>.unmodifiable(entries));
}
