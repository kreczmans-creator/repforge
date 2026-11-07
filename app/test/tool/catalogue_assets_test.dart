import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-3c-3 recommendation: the approved reference JSON under
/// `docs/catalogue/reference/` is bundled byte for byte under
/// `app/assets/catalogue/reference/`. A drift between the two fails CI.
const String docsDir = '../docs/catalogue/reference';
const String assetDir = 'assets/catalogue/reference';

List<String> _jsonNames(String dir) => [
  for (final f in Directory(dir).listSync())
    if (f is File && f.path.endsWith('.json')) f.uri.pathSegments.last,
]..sort();

void main() {
  final names = _jsonNames(docsDir);

  test('the approved reference files are the five expected ones', () {
    expect(names, [
      'anatomy.json',
      'coverage.json',
      'equipment.json',
      'ledger.json',
      'movement-patterns.json',
    ]);
  });

  test('the asset folder holds exactly the same file names', () {
    expect(_jsonNames(assetDir), names);
    expect(
      [
        for (final f in Directory(assetDir).listSync())
          if (f is File) f.uri.pathSegments.last,
      ]..sort(),
      names,
      reason: 'no other file belongs in the bundled reference folder',
    );
  });

  for (final name in names) {
    test('$name: the asset copy is byte-identical to the approved file', () {
      final approved = File('$docsDir/$name').readAsBytesSync();
      final bundled = File('$assetDir/$name').readAsBytesSync();
      expect(bundled.length, approved.length);
      expect(bundled, approved);
    });
  }

  test('pubspec.yaml registers the catalogue asset folders', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/catalogue/reference/'));
    expect(pubspec, contains('- assets/catalogue/releases/'));
  });
}
