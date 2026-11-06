import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/result.dart';

import '../../migration_v8/migration_digest.dart' as digest;
import 'backup_v8_support.dart';

/// WP 8 sub-stage 3b-7, regression suite of malformed backups (review M1;
/// owner decision 2026-11-06 on H1 and B-09): the first row of every table
/// of a format 1 (schema v5) and a format 2 (schema v7) golden, each column
/// in turn set to a value of another JSON type or an out-of-range value.
/// The preview never throws; a restore never throws, never fails inside the
/// write transaction (every refusal is a phase 1 `ValidationError`), and a
/// refused restore changes nothing.
void main() {
  test('malformed v7 backups: preview and restore always return a Result; '
      'every refusal is a ValidationError and changes nothing', () async {
    final values = <Object?>[
      'x',
      1.5,
      true,
      null,
      <Object?>[],
      <String, Object?>{},
    ];
    var cases = 0;
    var refused = 0;
    await inBackupTempDir((dir) async {
      final v8 = await V8File.create(dir);
      try {
        Future<String> state() async => jsonEncode([
          for (final t in [
            'measurements',
            'exercises',
            'exercise_targets',
            'legacy_quarantine',
            'session_sets',
            'migration_runs',
          ])
            await v8.count(t),
          await v8.foreignKeys(),
        ]);
        for (final path in [
          digest.goldenFormat1Path(5),
          digest.goldenFormat2Path(),
        ]) {
          final golden = readGolden(path);
          final tables =
              (jsonDecode(golden) as Map<String, Object?>)['tables']!
                  as Map<String, Object?>;
          for (final MapEntry(key: table, value: rows) in tables.entries) {
            if ((rows! as List).isEmpty) continue;
            final columns = ((rows as List).first as Map<String, Object?>).keys;
            for (final column in columns) {
              for (final value in values) {
                final env = jsonDecode(golden) as Map<String, Object?>;
                (((env['tables']! as Map<String, Object?>)[table]! as List)
                            .first
                        as Map<String, Object?>)[column] =
                    value;
                final json = jsonEncode(env);
                final where = '$path $table.$column = ${jsonEncode(value)}';
                cases++;
                final preview = v8.repo().previewJson(json);
                expect(preview, isA<Result<BackupPreview>>(), reason: where);
                final before = await state();
                final result = await v8
                    .repo(config: restoreConfig(newRunId: () => 'f$cases'))
                    .importJson(json);
                if (result case Err(:final error)) {
                  refused++;
                  expect(error, isA<ValidationError>(), reason: where);
                  expect(await state(), before, reason: where);
                  if (preview case Err(error: final p)) {
                    expect(p.message, error.message, reason: where);
                  }
                }
              }
            }
          }
        }
      } finally {
        await v8.close();
      }
    });
    expect(cases, greaterThan(1500));
    expect(refused, greaterThan(500));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
