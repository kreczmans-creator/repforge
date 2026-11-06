import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';

/// WP 8 stage 3b-2 gate: the schema v8 definition (`lib/data/db/v8/`) is not
/// connected to the app. Production stays at schema v7 (`AppDatabase`) until
/// the owner accepts stage 3b and authorises the switch (D04 §7,
/// 2026-11-06).
///
/// Sub-stage 3b-8 adds the v8 repositories (`lib/data/repositories/v8/`) to
/// the isolated zone: they may use v8, and nothing outside the zone may
/// import either directory. The production repositories, providers, use
/// cases and screens stay on v7.
void main() {
  const v8Dir = 'lib/data/db/v8';
  const v8RepositoriesDir = 'lib/data/repositories/v8';
  const isolatedZone = [v8Dir, v8RepositoriesDir];
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

  /// [target] imported from [file] as a `package:` URI (relative imports
  /// inside `lib/` resolved); other URIs as written.
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

  List<String> importsOf(Iterable<File> files, RegExp target) => [
    for (final f in files)
      for (final m in importPattern.allMatches(f.readAsStringSync()))
        if (target.hasMatch(asPackageUri(f, m.group(1)!)))
          '${f.path}: ${m.group(1)}',
  ];

  final reachesV8 = RegExp('^package:repforge/data/db/v8/');
  final reachesV8Repositories = RegExp(
    '^package:repforge/data/repositories/v8/',
  );
  bool inZone(File f) =>
      isolatedZone.any((dir) => normalise(f.path).startsWith('$dir/'));

  test('the v8 directory holds the definition', () {
    final names = dartFiles(v8Dir)
        .map((f) => normalise(f.path).split('/').last)
        .toSet();
    expect(
      names,
      containsAll([
        'tables_v8.dart',
        'app_database_v8.dart',
        'app_database_v8.g.dart',
        'exertion_rule_sql.dart',
      ]),
    );
  });

  test('app, features, UI and production repositories do not import v8 or '
      'the v8 repositories', () {
    final files = [
      for (final dir in [
        'lib/app',
        'lib/features',
        'lib/ui',
        'lib/data/repositories',
      ])
        if (Directory(dir).existsSync())
          for (final f in dartFiles(dir))
            if (!inZone(f)) f,
    ];
    expect(files.length, greaterThan(20));
    expect(importsOf(files, reachesV8), isEmpty);
    expect(importsOf(files, reachesV8Repositories), isEmpty);
  });

  test('no production file outside the isolated zone imports v8 or the v8 '
      'repositories', () {
    final files = [
      for (final f in dartFiles('lib'))
        if (!inZone(f)) f,
    ];
    expect(files.length, greaterThan(100));
    expect(importsOf(files, reachesV8), isEmpty);
    expect(importsOf(files, reachesV8Repositories), isEmpty);
  });

  test('the v8 definition does not import the v8 repositories', () {
    expect(importsOf(dartFiles(v8Dir), reachesV8Repositories), isEmpty);
  });

  test('the v8 repositories import no production database, mapper, '
      'repository, app, feature or UI code', () {
    final files = dartFiles(v8RepositoriesDir);
    expect(
      files.map((f) => normalise(f.path).split('/').last),
      containsAll([
        'drift_library_repository_v8.dart',
        'drift_migration_report_repository_v8.dart',
      ]),
    );
    final forbidden = RegExp(
      '^package:repforge/(app/|features/|ui/|data/mappers/|'
      r'data/db/app_database\.dart|data/repositories/(?!v8/))',
    );
    expect(importsOf(files, forbidden), isEmpty);
  });

  test('v8 imports no production database, app, feature, UI or repository '
      'code', () {
    final forbidden = RegExp(
      '^package:repforge/(app/|features/|ui/|data/repositories/|'
      r'data/db/app_database\.dart)',
    );
    expect(importsOf(dartFiles(v8Dir), forbidden), isEmpty);
  });

  test('the import check resolves relative imports', () {
    final probe = File('lib/data/db/app_database.dart');
    expect(reachesV8.hasMatch(asPackageUri(probe, 'v8/tables_v8.dart')), true);
    expect(reachesV8.hasMatch(asPackageUri(probe, 'tables.dart')), false);
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
