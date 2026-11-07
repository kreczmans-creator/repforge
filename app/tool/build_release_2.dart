// Builds the release-2 file of provider `repforge` from
// `docs/catalogue/mapping-existing.json` (the approved release-2
// classifications of the 89 seed exercises) and the approved reference files.
// Pure and deterministic: no clock, no network, no randomness. The output is
// the exact bytes bundled as `assets/catalogue/releases/repforge-release-2.json`
// (specification: `docs/catalogue/release-format-2.md`).
//
// Usage (from app/):
//   dart run tool/build_release_2.dart           write the asset
//   dart run tool/build_release_2.dart --check   fail when the asset differs
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:repforge/domain/library/release/release_hash.dart';

/// Release date written into the file (release-derived time, R-21). A constant,
/// not the clock.
const String release2Date = '2026-11-07';

/// Where the inputs and the output live, relative to `app/`.
const String mappingPath = '../docs/catalogue/mapping-existing.json';
const String releaseAssetPath =
    'assets/catalogue/releases/repforge-release-2.json';

/// Reference files named by the release: section key, path inside the bundled
/// `assets/catalogue/` folder and the source file name under
/// `docs/catalogue/reference/`.
const List<({String key, String file})> referenceSections = [
  (key: 'anatomy', file: 'anatomy.json'),
  (key: 'movementPatterns', file: 'movement-patterns.json'),
  (key: 'equipment', file: 'equipment.json'),
  (key: 'ledger', file: 'ledger.json'),
  (key: 'coverage', file: 'coverage.json'),
];

/// Builds the release text from the decoded [mapping] and the SHA-256 of each
/// reference file's bytes ([referenceHashes], keyed by file name).
String buildRelease2(
  Map<String, Object?> mapping,
  Map<String, String> referenceHashes,
) {
  final provenance = mapping['seedProvenance']! as Map<String, Object?>;
  final exercises = [
    for (final raw
        in (mapping['exercises']! as List<Object?>)
            .cast<Map<String, Object?>>())
      _exercise(raw, provenance),
  ];
  final release = <String, Object?>{
    'formatVersion': 2,
    'provider': {
      'id': provenance['providerId'],
      'name': 'RepForge',
      'licence': 'proprietary (RepForge)',
      'attribution': '',
      'url': null,
    },
    'release': 2,
    'releasedOn': release2Date,
    'reference': {
      for (final s in referenceSections)
        s.key: {
          'path': 'reference/${s.file}',
          'sha256': referenceHashes[s.file],
        },
    },
    'exercises': exercises,
    'retirements': <Object?>[],
  };
  return '${const JsonEncoder.withIndent('  ').convert(release)}\n';
}

Map<String, Object?> _exercise(
  Map<String, Object?> e,
  Map<String, Object?> provenance,
) {
  List<String> strings(String key) =>
      ((e[key] as List<Object?>?) ?? const []).cast<String>();
  final removed = strings('aliasesRemove');
  final aliases = [
    for (final a in strings('seedAliases'))
      if (!removed.contains(a)) a,
    ...strings('aliasesAdd'),
  ];
  final roles = (e['equipmentRoles'] as Map<String, Object?>?) ?? const {};
  final flags = ((e['flags'] as List<Object?>?) ?? const [])
      .cast<Map<String, Object?>>();
  final roleNote = flags.isEmpty
      ? 'Role differs from the default.'
      : flags.first['text']! as String;
  final attributes = (e['attributes'] as Map<String, Object?>?) ?? const {};
  return {
    'id': e['id'],
    'revision': 1,
    'names': {
      'en-GB': {'name': e['name'], 'aliases': aliases},
    },
    'loggingType': e['loggingType'],
    'category': e['category'],
    'targets': [
      for (final n in strings('proposedPrimary'))
        {'node': n, 'role': 'primary'},
      for (final n in strings('proposedSecondary'))
        {'node': n, 'role': 'secondary'},
    ],
    'patterns': strings('proposedPatterns'),
    'equipment': [
      for (final item in strings('proposedEquipment'))
        {
          'item': item,
          if (roles[item] != null) 'role': roles[item],
          if (roles[item] != null) 'roleNote': roleNote,
        },
    ],
    'mechanics': e['mechanics'],
    'laterality': e['laterality'],
    'difficulty': e['difficulty'],
    if (attributes.isNotEmpty) 'attributes': attributes,
    'provenance': {
      'authoredBy': provenance['authoredBy'],
      'reviewedBy': provenance['reviewedBy'],
      'sourceRef': null,
    },
  };
}

/// Reads the mapping and the reference files under [docsRoot] and builds the
/// release text.
String buildRelease2FromFiles({String docsRoot = '../docs/catalogue'}) {
  final mapping =
      jsonDecode(File('$docsRoot/mapping-existing.json').readAsStringSync())!
          as Map<String, Object?>;
  final hashes = {
    for (final s in referenceSections)
      s.file: releaseContentHash(
        File('$docsRoot/reference/${s.file}').readAsBytesSync(),
      ),
  };
  return buildRelease2(mapping, hashes);
}

void main(List<String> args) {
  final text = buildRelease2FromFiles();
  final file = File(releaseAssetPath);
  if (args.contains('--check')) {
    final current = file.existsSync() ? file.readAsStringSync() : null;
    if (current != text) {
      print(
        'build_release_2: $releaseAssetPath is not derived from '
        '$mappingPath; run `dart run tool/build_release_2.dart`.',
      );
      exitCode = 1;
    } else {
      print('build_release_2: $releaseAssetPath matches the mapping.');
    }
    return;
  }
  file
    ..createSync(recursive: true)
    ..writeAsStringSync(text);
  print('build_release_2: wrote $releaseAssetPath');
}
