import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/catalogue_records.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/exercise_relationship.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/integrity_report.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_parsers.dart';
import 'package:repforge/domain/library/release/release_format.dart';
import 'package:repforge/domain/library/release/release_hash.dart';
import 'package:repforge/domain/training/training.dart'
    show ExerciseCategory, ExerciseType;

/// The result of parsing a release: either a typed [document] or the full list
/// of [findings]. Nothing is thrown across this boundary.
@immutable
final class ReleaseParseResult {
  const ReleaseParseResult({
    required this.findings,
    this.document,
    this.contentHash,
  });

  /// Set exactly when [findings] holds no error.
  final ReleaseDocument? document;
  final List<Finding> findings;

  /// SHA-256 (lowercase hex) of the exact bytes; set when parsing bytes.
  final String? contentHash;

  bool get ok => document != null;
}

Finding _rf(String code, String message, {String? field, String? subjectId}) =>
    Finding(
      code: code,
      severity: Severity.error,
      message: message,
      field: field,
      subjectId: subjectId,
    );

/// Parses the exact bytes of a release file. The content hash is computed over
/// these bytes (R-10), never over a re-serialised form.
ReleaseParseResult parseReleaseBytes(List<int> bytes) {
  final hash = releaseContentHash(bytes);
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException catch (e) {
    return ReleaseParseResult(
      findings: [
        _rf('RF-001', 'The release is not valid UTF-8: ${e.message}.'),
      ],
      contentHash: hash,
    );
  }
  final parsed = parseReleaseText(text);
  return ReleaseParseResult(
    findings: parsed.findings,
    document: parsed.document,
    contentHash: hash,
  );
}

/// Parses release JSON text.
ReleaseParseResult parseReleaseText(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    return ReleaseParseResult(
      findings: [_rf('RF-001', 'The release is not valid JSON: ${e.message}.')],
    );
  }
  return parseReleaseJson(json);
}

/// Parses decoded release JSON. Every malformed input becomes a finding.
ReleaseParseResult parseReleaseJson(Object? json) {
  final p = _ReleaseParser();
  final document = p.parse(json);
  final findings = sortedFindings(p.findings());
  final hasError = findings.any((f) => f.severity == Severity.error);
  return ReleaseParseResult(
    findings: findings,
    document: hasError ? null : document,
  );
}

final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');
final RegExp _plainPath = RegExp(
  r'^(?!\.{1,2}(/|$))[A-Za-z0-9_-][A-Za-z0-9._-]*(/(?!\.{1,2}(/|$))[A-Za-z0-9_-][A-Za-z0-9._-]*)*$',
);
final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
const Set<String> _trancheStatuses = {'planned', 'inProgress', 'complete'};

class _ReleaseParser {
  final JsonReader r = JsonReader();
  final List<Finding> _extra = [];
  final List<String?> _exerciseIds = [];
  final Set<(RelationshipKind, ExerciseId, ExerciseId)> _relKeys = {};

  List<Finding> findings() => [
    for (final e in r.errors.entries)
      _rf(
        _codeFor(e.key, e.value),
        '${e.key}: ${e.value}',
        field: e.key,
        subjectId: _subject(e.key),
      ),
    ..._extra,
  ];

  /// An unknown enum value in a release file is the raw-file form of IC-202,
  /// IC-203 and IC-308 (the 3a carry-over); everything else is a shape
  /// problem.
  String _codeFor(String path, String message) {
    if (path == 'formatVersion') return 'RF-003';
    if (!message.startsWith('Expected one of')) return 'RF-002';
    if (path.endsWith('.loggingType')) return 'IC-202';
    if (path.endsWith('.category')) return 'IC-203';
    if (RegExp(r'\.(mechanics|laterality|difficulty|role|kind)$')
        .hasMatch(path)) {
      return 'IC-308';
    }
    return 'RF-002';
  }

  String? _subject(String path) {
    final m = RegExp(r'^exercises\[(\d+)\]').firstMatch(path);
    if (m == null) return null;
    final i = int.parse(m.group(1)!);
    return i < _exerciseIds.length ? _exerciseIds[i] : null;
  }

  void _closed(Map<String, Object?> m, Set<String> keys, String path) {
    for (final k in m.keys) {
      if (!keys.contains(k)) {
        _extra.add(
          _rf(
            'RF-006',
            '$path.$k: Unknown key.',
            field: '$path.$k',
            subjectId: _subject(path),
          ),
        );
      }
    }
  }

  ReleaseDocument? parse(Object? json) {
    final root = r.map(json, r'$');
    if (root == null) return null;
    _closed(root, {
      'formatVersion',
      'provider',
      'release',
      'releasedOn',
      'reference',
      'tranches',
      'exercises',
      'retirements',
    }, r'$');
    final version = root['formatVersion'];
    if (version is! int || version != releaseFormatVersion2) {
      r.fail(
        'formatVersion',
        'Expected format version $releaseFormatVersion2.',
      );
    }
    final provider = _provider(root['provider']);
    final rawNumber = root['release'];
    final number = rawNumber is int && rawNumber >= 1 ? rawNumber : null;
    if (number == null) {
      r.fail('release', 'Expected an integer release number of at least 1.');
    }
    final releasedOn = _releasedOn(root['releasedOn']);
    final reference = _reference(root['reference']);
    final tranches = _tranches(root['tranches']);
    final stamp = releasedOn ?? DateTime.utc(1970);
    final exercises = <CatalogueExercise>[];
    final relationships = <ExerciseRelationship>[];
    final content = <ContentSection>[];
    final media = <MediaReference>[];
    final contentProvenance = <ExerciseId, ContentProvenance>{};
    final rawExercises = r.list(root['exercises'], 'exercises');
    if (rawExercises != null) {
      for (var i = 0; i < rawExercises.length; i++) {
        final raw = rawExercises[i];
        _exerciseIds.add(
          raw is Map<String, Object?> && raw['id'] is String
              ? raw['id']! as String
              : null,
        );
        _exercise(
          raw,
          'exercises[$i]',
          provider?.id ?? const ProviderId('?'),
          stamp,
          exercises,
          relationships,
          content,
          media,
          contentProvenance,
        );
      }
    }
    final retirements = _retirements(root['retirements']);
    if (rawExercises != null &&
        rawExercises.isEmpty &&
        (retirements?.isEmpty ?? false)) {
      r.fail('exercises', 'A release lists an exercise or a retirement.');
    }
    if (provider == null ||
        number == null ||
        releasedOn == null ||
        reference == null ||
        tranches == null ||
        rawExercises == null ||
        retirements == null) {
      return null;
    }
    return ReleaseDocument(
      provider: provider,
      release: ReleaseId(provider.id, number),
      releasedOn: releasedOn,
      reference: reference,
      exercises: exercises,
      relationships: relationships,
      content: content,
      media: media,
      contentProvenance: contentProvenance,
      retirements: retirements,
      tranches: tranches,
    );
  }

  ContentProvider? _provider(Object? value) {
    final m = r.map(value, 'provider');
    if (m == null) return null;
    _closed(m, {'id', 'name', 'licence', 'attribution', 'url'}, 'provider');
    final id = r.string(m, 'id', 'provider');
    final name = r.string(m, 'name', 'provider');
    final licence = r.string(m, 'licence', 'provider');
    final rawAttribution = m['attribution'];
    final attribution = rawAttribution is String ? rawAttribution : null;
    if (attribution == null) {
      r.fail('provider.attribution', 'Expected a string (empty when none).');
    }
    final url = r.optionalString(m, 'url', 'provider');
    if (id == null || name == null || licence == null || attribution == null) {
      return null;
    }
    return ContentProvider(
      id: ProviderId(id),
      name: name,
      licence: licence,
      attribution: attribution,
      url: url,
    );
  }

  DateTime? _releasedOn(Object? value) => _date(value, 'releasedOn');

  DateTime? _date(Object? value, String path) {
    final m = value is String ? _datePattern.firstMatch(value) : null;
    if (m != null) {
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      final date = DateTime.utc(y, mo, d);
      if (date.year == y && date.month == mo && date.day == d) return date;
    }
    r.fail(path, 'Expected a calendar date as YYYY-MM-DD.');
    return null;
  }

  Map<ReleaseReferenceName, ReleaseReferenceFile>? _reference(Object? value) {
    final m = r.map(value, 'reference');
    if (m == null) return null;
    _closed(m, {
      for (final n in ReleaseReferenceName.values) n.wire,
    }, 'reference');
    final out = <ReleaseReferenceName, ReleaseReferenceFile>{};
    for (final name in ReleaseReferenceName.values) {
      final path = 'reference.${name.wire}';
      final section = r.map(m[name.wire], path);
      if (section == null) continue;
      _closed(section, {'path', 'sha256'}, path);
      final file = r.string(section, 'path', path);
      final hash = r.string(section, 'sha256', path);
      if (file != null && !_plainPath.hasMatch(file)) {
        r.fail('$path.path', 'Expected a plain relative path.');
        continue;
      }
      if (hash != null && !_hex64.hasMatch(hash)) {
        r.fail('$path.sha256', 'Expected 64 lowercase hexadecimal characters.');
        continue;
      }
      if (file != null && hash != null) {
        out[name] = ReleaseReferenceFile(path: file, sha256: hash);
      }
    }
    return out.length == ReleaseReferenceName.values.length ? out : null;
  }

  Map<String, String>? _tranches(Object? value) {
    if (value == null) return const {};
    final m = r.map(value, 'tranches');
    if (m == null) return null;
    final out = <String, String>{};
    for (final e in m.entries) {
      final v = e.value;
      if (v is String && _trancheStatuses.contains(v)) {
        out[e.key] = v;
      } else {
        r.fail(
          'tranches.${e.key}',
          'Expected one of ${_trancheStatuses.join(', ')}.',
        );
      }
    }
    return out;
  }

  List<Retirement>? _retirements(Object? value) {
    final raw = r.list(value, 'retirements');
    if (raw == null) return null;
    final out = <Retirement>[];
    final seenRetired = <String>{};
    for (var i = 0; i < raw.length; i++) {
      final path = 'retirements[$i]';
      final m = r.map(raw[i], path);
      if (m == null) continue;
      _closed(m, {'id', 'reason', 'replacedBy'}, path);
      final id = r.string(m, 'id', path);
      final reason = r.string(m, 'reason', path);
      final by = r.optionalString(m, 'replacedBy', path);
      if (id == null || reason == null) continue;
      if (!seenRetired.add(id)) {
        _extra.add(
          _rf(
            'RF-007',
            '$path: $id is retired more than once.',
            field: path,
            subjectId: id,
          ),
        );
        continue;
      }
      out.add(
        Retirement(
          ExerciseId(id),
          reason,
          replacedBy: by == null ? null : ExerciseId(by),
        ),
      );
    }
    return out;
  }

  void _exercise(
    Object? raw,
    String path,
    ProviderId provider,
    DateTime stamp,
    List<CatalogueExercise> exercises,
    List<ExerciseRelationship> relationships,
    List<ContentSection> content,
    List<MediaReference> media,
    Map<ExerciseId, ContentProvenance> contentProvenance,
  ) {
    final m = r.map(raw, path);
    if (m == null) return;
    _closed(m, {
      'id',
      'revision',
      'names',
      'loggingType',
      'category',
      'targets',
      'patterns',
      'equipment',
      'mechanics',
      'laterality',
      'difficulty',
      'attributes',
      'provenance',
      'relationships',
      'content',
      'contentProvenance',
      'media',
    }, path);
    final id = r.string(m, 'id', path);
    final revision = r.integer(m, 'revision', path);
    final names = _names(m['names'], '$path.names');
    final type = r.enumValue(ExerciseType.values, m, 'loggingType', path);
    final category = r.enumValue(ExerciseCategory.values, m, 'category', path);
    final targets = _targets(m['targets'], '$path.targets');
    final patterns = _strings(m['patterns'], '$path.patterns');
    final equipment = _equipment(m['equipment'], '$path.equipment');
    final mechanics = _optionalEnum(Mechanics.values, m, 'mechanics', path);
    final laterality = _optionalEnum(Laterality.values, m, 'laterality', path);
    final difficulty = _optionalEnum(Difficulty.values, m, 'difficulty', path);
    final attributes = _attributes(m['attributes'], '$path.attributes');
    final provenance = _provenance(m['provenance'], '$path.provenance');
    if (id == null ||
        revision == null ||
        names == null ||
        type == null ||
        category == null ||
        targets == null ||
        patterns == null ||
        equipment == null ||
        attributes == null ||
        provenance == null) {
      // Still read the optional parts so their problems are reported too.
      _relationships(
        m['relationships'],
        '$path.relationships',
        null,
        relationships,
      );
      _content(m['content'], '$path.content', null, 0, content);
      _contentProvenance(m['contentProvenance'], '$path.contentProvenance');
      _media(m['media'], '$path.media', null, 0, provider, media);
      return;
    }
    final exerciseId = ExerciseId(id);
    exercises.add(
      CatalogueExercise(
        id: exerciseId,
        names: names,
        type: type,
        category: category,
        source: ExerciseSource.system,
        providerId: provider,
        revision: revision,
        targets: targets,
        patterns: [for (final s in patterns) MovementPatternId(s)],
        equipment: equipment,
        mechanics: mechanics,
        laterality: laterality,
        difficulty: difficulty,
        attributes: attributes,
        provenance: provenance,
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
    _relationships(
      m['relationships'],
      '$path.relationships',
      exerciseId,
      relationships,
    );
    _content(
      m['content'],
      '$path.content',
      exerciseId,
      revision,
      content,
      provider,
    );
    final cp = _contentProvenance(
      m['contentProvenance'],
      '$path.contentProvenance',
    );
    if (cp != null) contentProvenance[exerciseId] = cp;
    _media(m['media'], '$path.media', exerciseId, revision, provider, media);
  }

  /// Specification revision 2: provenance of the instruction content.
  ContentProvenance? _contentProvenance(Object? value, String path) {
    if (value == null) return null;
    final m = r.map(value, path);
    if (m == null) return null;
    _closed(m, {
      'authoredBy',
      'editor',
      'status',
      'draftingAssistance',
      'draftedOn',
      'approvedOn',
    }, path);
    final authoredBy = r.string(m, 'authoredBy', path);
    final status = r.enumValue(ContentStatus.values, m, 'status', path);
    final editor = r.optionalString(m, 'editor', path);
    final assistance = r.optionalString(m, 'draftingAssistance', path);
    final draftedOn = _date(m['draftedOn'], '$path.draftedOn');
    final approvedOn = m['approvedOn'] == null
        ? null
        : _date(m['approvedOn'], '$path.approvedOn');
    if (authoredBy == null || status == null || draftedOn == null) return null;
    if (m['approvedOn'] != null && approvedOn == null) return null;
    return ContentProvenance(
      authoredBy: authoredBy,
      status: status,
      draftedOn: draftedOn,
      editor: editor,
      draftingAssistance: assistance,
      approvedOn: approvedOn,
    );
  }

  T? _optionalEnum<T extends Enum>(
    List<T> values,
    Map<String, Object?> m,
    String key,
    String path,
  ) => m[key] == null ? null : r.enumValue(values, m, key, path);

  List<String>? _strings(Object? value, String path) {
    final raw = r.list(value, path);
    if (raw == null) return null;
    final out = <String>[];
    var ok = true;
    for (var i = 0; i < raw.length; i++) {
      final v = raw[i];
      if (v is String && v.isNotEmpty) {
        out.add(v);
      } else {
        r.fail('$path[$i]', 'Expected a non-empty string.');
        ok = false;
      }
    }
    return ok ? out : null;
  }

  ExerciseNames? _names(Object? value, String path) {
    final m = r.map(value, path);
    if (m == null) return null;
    final out = <String, LocalizedName>{};
    var ok = true;
    for (final e in m.entries) {
      final lp = '$path.${e.key}';
      final lm = r.map(e.value, lp);
      if (lm == null) {
        ok = false;
        continue;
      }
      _closed(lm, {'name', 'aliases'}, lp);
      final name = r.string(lm, 'name', lp);
      final aliases = lm['aliases'] == null
          ? const <String>[]
          : _strings(lm['aliases'], '$lp.aliases');
      if (name == null || aliases == null) {
        ok = false;
        continue;
      }
      out[e.key] = LocalizedName(name, aliases: aliases);
    }
    if (!m.containsKey(canonicalLocale)) {
      r.fail('$path.$canonicalLocale', 'The canonical locale is required.');
      ok = false;
    }
    return ok ? ExerciseNames(out) : null;
  }

  List<ExerciseTarget>? _targets(Object? value, String path) {
    final raw = r.list(value, path);
    if (raw == null) return null;
    final out = <ExerciseTarget>[];
    var ok = true;
    for (var i = 0; i < raw.length; i++) {
      final tp = '$path[$i]';
      final m = r.map(raw[i], tp);
      if (m == null) {
        ok = false;
        continue;
      }
      _closed(m, {'node', 'role'}, tp);
      final node = r.string(m, 'node', tp);
      final role = r.enumValue(TargetRole.values, m, 'role', tp);
      if (node == null || role == null) {
        ok = false;
        continue;
      }
      out.add(
        ExerciseTarget(node: AnatomyNodeId(node), role: role, ordinal: i),
      );
    }
    return ok ? out : null;
  }

  List<ExerciseEquipment>? _equipment(Object? value, String path) {
    final raw = r.list(value, path);
    if (raw == null) return null;
    final out = <ExerciseEquipment>[];
    var ok = true;
    for (var i = 0; i < raw.length; i++) {
      final ep = '$path[$i]';
      final m = r.map(raw[i], ep);
      if (m == null) {
        ok = false;
        continue;
      }
      _closed(m, {'item', 'role', 'roleNote'}, ep);
      final item = r.string(m, 'item', ep);
      final role = _optionalEnum(EquipmentRole.values, m, 'role', ep);
      final note = r.optionalString(m, 'roleNote', ep);
      if (m['role'] != null && role == null) ok = false;
      if (m['role'] == null && m['roleNote'] != null) {
        r.fail('$ep.roleNote', 'A role note needs a role.');
        ok = false;
      }
      if (item == null) {
        ok = false;
        continue;
      }
      out.add(
        ExerciseEquipment(
          EquipmentItemId(item),
          roleOverride: role,
          overrideNote: note,
        ),
      );
    }
    return ok ? out : null;
  }

  Map<ExerciseAttribute, String>? _attributes(Object? value, String path) {
    if (value == null) return const {};
    final m = r.map(value, path);
    if (m == null) return null;
    final out = <ExerciseAttribute, String>{};
    var ok = true;
    for (final e in m.entries) {
      final attribute = enumByName(ExerciseAttribute.values, e.key);
      final v = e.value;
      if (attribute == null) {
        r.fail('$path.${e.key}', 'Unknown attribute.');
        ok = false;
      } else if (v is! String || v.isEmpty) {
        r.fail('$path.${e.key}', 'Expected a non-empty string.');
        ok = false;
      } else {
        out[attribute] = v;
      }
    }
    return ok ? out : null;
  }

  ExerciseProvenance? _provenance(Object? value, String path) {
    if (value == null) return const ExerciseProvenance();
    final m = r.map(value, path);
    if (m == null) return null;
    _closed(m, {'authoredBy', 'reviewedBy', 'sourceRef'}, path);
    return ExerciseProvenance(
      authoredBy: r.optionalString(m, 'authoredBy', path),
      reviewedBy: r.optionalString(m, 'reviewedBy', path),
      sourceRef: r.optionalString(m, 'sourceRef', path),
    );
  }

  (RelationshipKind, ExerciseId, ExerciseId) _relKey(ExerciseRelationship x) =>
      (x.kind, x.from, x.to);

  void _relationships(
    Object? value,
    String path,
    ExerciseId? owner,
    List<ExerciseRelationship> out,
  ) {
    if (value == null) return;
    final raw = r.list(value, path);
    if (raw == null) return;
    for (var i = 0; i < raw.length; i++) {
      final rp = '$path[$i]';
      final m = r.map(raw[i], rp);
      if (m == null) continue;
      _closed(m, {'kind', 'to'}, rp);
      final kind = r.enumValue(RelationshipKind.values, m, 'kind', rp);
      final to = r.string(m, 'to', rp);
      if (kind == null || to == null || owner == null) continue;
      if (!kind.isStored) {
        r.fail(
          '$rp.kind',
          '${kind.name} is derived and is not written; declare progressionOf '
              'on the other exercise.',
        );
        continue;
      }
      final result = ExerciseRelationship.normalised(
        from: owner,
        to: ExerciseId(to),
        kind: kind,
        source: ExerciseSource.system,
      );
      switch (result) {
        case Ok(:final value):
          if (_relKeys.add(_relKey(value))) {
            out.add(value);
          } else {
            _extra.add(
              _rf(
                'RF-007',
                '$rp: The relationship ${value.from} ${value.kind.name} '
                    '${value.to} is declared more than once.',
                field: rp,
                subjectId: owner.value,
              ),
            );
          }
        case Err(:final error):
          r.fail('$rp.to', error.message);
      }
    }
  }

  void _content(
    Object? value,
    String path,
    ExerciseId? owner,
    int revision,
    List<ContentSection> out, [
    ProviderId? provider,
  ]) {
    if (value == null) return;
    final byLocale = r.map(value, path);
    if (byLocale == null) return;
    for (final locale in byLocale.entries) {
      final lp = '$path.${locale.key}';
      final byKind = r.map(locale.value, lp);
      if (byKind == null) continue;
      for (final kind in byKind.entries) {
        final items = _strings(kind.value, '$lp.${kind.key}');
        if (items == null || owner == null || provider == null) continue;
        for (var i = 0; i < items.length; i++) {
          out.add(
            ContentSection(
              exerciseId: owner,
              locale: locale.key,
              kind: kind.key,
              ordinal: i,
              body: items[i],
              providerId: provider,
              revision: revision,
            ),
          );
        }
      }
    }
  }

  void _media(
    Object? value,
    String path,
    ExerciseId? owner,
    int revision,
    ProviderId provider,
    List<MediaReference> out,
  ) {
    if (value == null) return;
    final raw = r.list(value, path);
    if (raw == null) return;
    for (var i = 0; i < raw.length; i++) {
      final mp = '$path[$i]';
      final m = r.map(raw[i], mp);
      if (m == null) continue;
      _closed(m, {
        'id',
        'kind',
        'locator',
        'licence',
        'attribution',
        'purpose',
        'caption',
        'source',
        'availability',
      }, mp);
      final id = r.string(m, 'id', mp);
      final kind = r.string(m, 'kind', mp);
      final locator = r.string(m, 'locator', mp);
      final licence = r.string(m, 'licence', mp);
      final attribution = r.string(m, 'attribution', mp);
      final purpose = r.optionalString(m, 'purpose', mp);
      final caption = r.optionalString(m, 'caption', mp);
      final source = r.optionalString(m, 'source', mp);
      final availability = r.optionalString(m, 'availability', mp);
      if (owner == null ||
          id == null ||
          kind == null ||
          locator == null ||
          licence == null ||
          attribution == null) {
        continue;
      }
      out.add(
        MediaReference(
          id: id,
          exerciseId: owner,
          kind: kind,
          locator: locator,
          licence: licence,
          attribution: attribution,
          providerId: provider,
          revision: revision,
          ordinal: i,
          purpose: purpose,
          caption: caption,
          source: source,
          availability: availability,
        ),
      );
    }
  }
}
