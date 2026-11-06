import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';

/// WP 8 stage 3b-3 gate: the new migration chain (`lib/data/db/migration/`)
/// is not connected to the app. Production stays at schema v7 and migrates
/// with `AppDatabase` until the owner authorises the switch (D04 §7,
/// 2026-11-06).
void main() {
  const migrationDir = 'lib/data/db/migration';
  final importPattern = RegExp(
    r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  List<File> dartFiles(String dir) =>
      Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

  String normalise(String path) => path.replaceAll(r'\', '/');

  /// True when [target], imported from [file], resolves into the migration
  /// directory (package or relative import).
  bool reachesMigration(File file, String target) {
    if (target.startsWith('package:repforge/data/db/migration/')) return true;
    if (target.startsWith('package:') || target.startsWith('dart:')) {
      return false;
    }
    final resolved = normalise(file.absolute.uri.resolve(target).toFilePath());
    final root = normalise(Directory(migrationDir).absolute.path);
    return resolved.startsWith('$root/');
  }

  /// [target] imported from [file] as a `package:` URI: relative imports
  /// inside `lib/` become `package:repforge/...`; others stay as written.
  String asPackageUri(File file, String target) {
    if (target.startsWith('package:') || target.startsWith('dart:')) {
      return target;
    }
    final resolved = normalise(file.absolute.uri.resolve(target).toFilePath());
    final lib = normalise(Directory('lib').absolute.path);
    return resolved.startsWith('$lib/')
        ? 'package:repforge/${resolved.substring(lib.length + 1)}'
        : resolved;
  }

  /// Imports of the chain's files that match [forbidden], package or
  /// relative.
  List<String> chainImportsMatching(RegExp forbidden) => [
    for (final f in dartFiles(migrationDir))
      for (final m in importPattern.allMatches(f.readAsStringSync()))
        if (forbidden.hasMatch(asPackageUri(f, m.group(1)!)))
          '${f.path}: ${m.group(1)}',
  ];

  List<String> offenders(Iterable<File> files) => [
    for (final f in files)
      for (final m in importPattern.allMatches(f.readAsStringSync()))
        if (reachesMigration(f, m.group(1)!)) '${f.path}: ${m.group(1)}',
  ];

  test('the migration directory exists and holds the chain', () {
    final names = dartFiles(migrationDir)
        .map((f) => normalise(f.path).split('/').last)
        .toSet();
    expect(
      names,
      containsAll([
        'schema_versions.g.dart',
        'historical_steps.dart',
        'repforge_migration.dart',
        'legacy_training_rows_v6.dart',
      ]),
    );
  });

  test('app, features and repositories do not import the chain', () {
    final files = [
      for (final dir in ['lib/app', 'lib/features', 'lib/data/repositories'])
        ...dartFiles(dir),
    ];
    expect(files.length, greaterThan(20));
    expect(offenders(files), isEmpty);
  });

  test('no other production file imports the chain', () {
    final files = [
      for (final f in dartFiles('lib'))
        if (!normalise(f.path).startsWith('$migrationDir/')) f,
    ];
    expect(offenders(files), isEmpty);
  });

  test('the chain imports no app, feature, UI or repository code', () {
    final forbidden = RegExp(
      '^package:repforge/(app|features|ui|data/repositories)/',
    );
    expect(chainImportsMatching(forbidden), isEmpty);
  });

  test('the chain uses only frozen data logic, not the live mapping or '
      'enums', () {
    final live = RegExp(
      r'^package:repforge/(data/db/legacy_training_rows\.dart|'
      r'data/db/app_database\.dart|data/db/tables\.dart|domain/training/|'
      r'domain/core/search_key\.dart)',
    );
    expect(chainImportsMatching(live), isEmpty);
  });

  test('relative imports resolve to package URIs for the gates', () {
    final probe = File('$migrationDir/historical_steps.dart');
    expect(
      asPackageUri(probe, '../legacy_training_rows.dart'),
      'package:repforge/data/db/legacy_training_rows.dart',
    );
    expect(
      asPackageUri(probe, '../../../domain/core/search_key.dart'),
      'package:repforge/domain/core/search_key.dart',
    );
    expect(asPackageUri(probe, 'dart:convert'), 'dart:convert');
  });

  test('the relative-import check sees a reaching import', () {
    final probe = File('lib/data/db/app_database.dart');
    expect(reachesMigration(probe, 'migration/historical_steps.dart'), isTrue);
    expect(reachesMigration(probe, 'tables.dart'), isFalse);
  });

  test('production AppDatabase stays at schema version 7', () async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      expect(db.schemaVersion, 7);
    } finally {
      await db.close();
    }
  });
}
