import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WP 11 stage A: the analytics domain (`lib/domain/analytics`) is pure Dart.
/// It imports no Flutter, no drift, no platform plugin and nothing from
/// `lib/data`, `lib/ui`, `lib/features` or `lib/app` (engineering standards
/// section 3; D03 section 2).
void main() {
  final files = Directory('lib/domain/analytics')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final importPattern = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  test('the analytics domain exists and is scanned', () {
    expect(files.length, greaterThan(8));
  });

  test('imports are limited to dart core libraries, meta and the domain', () {
    final allowedPackages = RegExp('^package:(meta/|repforge/domain/)');
    final violations = <String>[];
    for (final f in files) {
      for (final m in importPattern.allMatches(f.readAsStringSync())) {
        final target = m.group(1)!;
        final ok = target.startsWith('dart:')
            ? const {'dart:math', 'dart:collection'}.contains(target)
            : allowedPackages.hasMatch(target);
        if (!ok) violations.add('${f.path}: $target');
      }
    }
    expect(violations, isEmpty);
  });

  test('transitive imports stay Flutter, drift and plugin free', () {
    final forbidden = RegExp(
      '^(package:(flutter|flutter_test|drift|drift_flutter|sqlite3|'
      'flutter_riverpod|riverpod|go_router|dio|path_provider|share_plus|'
      'file_selector|mobile_scanner|permission_handler|'
      'flutter_local_notifications|timezone)/|dart:(ui|io|html))',
    );
    final seen = <String>{};
    final queue = <String>[for (final f in files) f.path.replaceAll(r'\', '/')];
    final offenders = <String>[];
    while (queue.isNotEmpty) {
      final path = queue.removeLast();
      if (!seen.add(path)) continue;
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      for (final m in importPattern.allMatches(file.readAsStringSync())) {
        final target = m.group(1)!;
        if (forbidden.hasMatch(target)) {
          offenders.add('$path: $target');
        } else if (target.startsWith('package:repforge/')) {
          final rest = target.substring('package:repforge/'.length);
          if (RegExp('^(data|ui|features|app)/').hasMatch(rest)) {
            offenders.add('$path: $target');
          } else {
            queue.add('lib/$rest');
          }
        }
      }
    }
    expect(offenders, isEmpty);
    expect(seen.length, greaterThan(files.length));
  });

  test('no analytics text instructs the user (GOL-011)', () {
    final advice = RegExp(
      r'\b(should|must|try to|we recommend|recommend\w*|you need to|'
      r'consider|aim for|eat|reduce|increase your|cut back)\b',
      caseSensitive: false,
    );
    final literal = RegExp(
      "'''[\\s\\S]*?'''|\"\"\"[\\s\\S]*?\"\"\"|"
      r"'(?:[^'\\\n]|\\.)*'|"
      r'"(?:[^"\\\n]|\\.)*"',
    );
    final sources = [
      for (final dir in ['lib/domain/analytics', 'lib/features/analytics'])
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
    ];
    expect(sources, isNotEmpty);
    final offenders = <String>[];
    for (final f in sources) {
      // Strings only: comments are removed first.
      final code = f.readAsStringSync().replaceAll(RegExp('//.*'), '');
      for (final m in literal.allMatches(code)) {
        if (advice.hasMatch(m.group(0)!)) {
          offenders.add('${f.path}: ${m.group(0)}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the data-quality check has no provider and no screen (OQ-15)', () {
    // The Owner Actions register cites the check's class names in the
    // evidence text of OB-WP11-02; it is a data record and reads nothing.
    const register = 'lib/domain/delivery/owner_blocker_register.dart';
    final users = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.replaceAll(r'\', '/').startsWith('lib/domain/analytics/') &&
            f.path.replaceAll(r'\', '/') != register &&
            RegExp('DataQuality').hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(users, isEmpty);
  });

  test('analytics application and screens never import lib/data', () {
    final offenders = [
      for (final f in Directory(
        'lib/features/analytics',
      ).listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            importPattern
                .allMatches(f.readAsStringSync())
                .any((m) => m.group(1)!.startsWith('package:repforge/data/')))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
