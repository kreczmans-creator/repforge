import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WP 8 stage 3a: the exercise library domain (`lib/domain/library`) is pure
/// Dart. It imports no Flutter, no drift, no platform plugin and nothing from
/// `lib/data`, `lib/ui`, `lib/features` or `lib/app` (engineering standards
/// section 3; ADR-0006).
void main() {
  final dir = Directory('lib/domain/library');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final importPattern = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  test('the library domain exists and is scanned', () {
    expect(files.length, greaterThan(15));
  });

  test(
    'imports are limited to dart:core-level libraries, meta and the domain',
    () {
      final allowedPackages = RegExp('^package:(meta|repforge/domain/)');
      final allowedDart = {'dart:convert'};
      final violations = <String>[];
      for (final f in files) {
        final text = f.readAsStringSync();
        for (final m in importPattern.allMatches(text)) {
          final target = m.group(1)!;
          final ok = target.startsWith('dart:')
              ? allowedDart.contains(target)
              : allowedPackages.hasMatch(target);
          if (!ok) violations.add('${f.path}: $target');
        }
      }
      expect(violations, isEmpty);
    },
  );

  test('no Flutter, drift, platform plugin or higher-layer import', () {
    final forbidden = RegExp(
      '(package:flutter/|package:flutter_test/|dart:ui|dart:io|dart:html|package:drift|package:sqlite3|package:riverpod|package:flutter_riverpod|package:go_router|package:dio|package:path_provider|package:share_plus|package:file_selector|package:mobile_scanner|package:permission_handler|package:flutter_local_notifications|package:timezone|package:repforge/(data|ui|features|app)/)',
    );
    final offenders = [
      for (final f in files)
        if (forbidden.hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(offenders, isEmpty);
  });

  test(
    'the only domain files it reaches are core results and the existing enums',
    () {
      final reached = <String>{};
      for (final f in files) {
        for (final m in importPattern.allMatches(f.readAsStringSync())) {
          final t = m.group(1)!;
          if (t.startsWith('package:repforge/domain/') &&
              !t.startsWith('package:repforge/domain/library/')) {
            reached.add(t);
          }
        }
      }
      expect(reached, {
        'package:repforge/domain/core/result.dart',
        'package:repforge/domain/training/training.dart',
      });
    },
  );

  test('transitive imports stay Flutter, drift and plugin free', () {
    final forbiddenTransitive = RegExp(
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
        if (forbiddenTransitive.hasMatch(target)) {
          offenders.add('$path: $target');
        } else if (target.startsWith('package:repforge/')) {
          queue.add('lib/${target.substring('package:repforge/'.length)}');
        }
      }
    }
    expect(offenders, isEmpty);
    expect(seen.length, greaterThan(files.length)); // it did follow imports
  });

  test('no existing code imports lib/domain/library (3a changes nothing '
      'else); only the unconnected v7 → v8 step (3b-4) and the unconnected '
      'v8 repositories (3b-8) use it', () {
    // The v8 repositories are kept out of the app by
    // `schema_v8_isolation_test.dart`.
    final importers = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.replaceAll(r'\', '/').startsWith('lib/domain/library/') &&
            f.readAsStringSync().contains('domain/library/'))
          f.path.replaceAll(r'\', '/'),
    ];
    expect(importers..sort(), [
      'lib/data/db/migration/v7_to_v8.dart',
      'lib/data/repositories/v8/drift_library_repository_v8.dart',
      'lib/data/repositories/v8/drift_migration_report_repository_v8.dart',
      'lib/data/repositories/v8/v8_exercise_read_port.dart',
    ]);
  });

  test('the existing exercise model and enums are still in place', () {
    final training = File('lib/domain/training/training.dart')
        .readAsStringSync();
    expect(training, contains('enum MuscleGroup'));
    expect(training, contains('enum Equipment'));
    expect(training, contains('primaryMuscle'));
  });
}
