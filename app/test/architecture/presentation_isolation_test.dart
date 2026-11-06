import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Layering guard (engineering standards): presentation code never imports
/// `lib/data/` (it goes through providers and use cases), and the domain
/// layer stays Flutter-free.
void main() {
  List<File> dartFiles(bool Function(String path) where) {
    final files = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            where(f.path.replaceAll(r'\', '/')))
          f,
    ];
    expect(files, isNotEmpty, reason: 'the guard must scan real files');
    return files;
  }

  List<String> importing(List<File> files, RegExp pattern) => [
    for (final f in files)
      if (pattern.hasMatch(f.readAsStringSync())) f.path.replaceAll(r'\', '/'),
  ];

  test('presentation and ui code does not import package:repforge/data/', () {
    final files = dartFiles(
      (p) =>
          p.startsWith('lib/ui/') ||
          RegExp('^lib/features/[^/]+/presentation/').hasMatch(p),
    );
    final found = importing(
      files,
      RegExp('(import|export)\\s+[\'"]package:repforge/data/'),
    );
    expect(found, isEmpty);
  });

  test('the domain layer does not import package:flutter/', () {
    final files = dartFiles((p) => p.startsWith('lib/domain/'));
    final found = importing(
      files,
      RegExp(r'''(import|export)\s+['"]package:flutter/'''),
    );
    expect(found, isEmpty);
  });
}
