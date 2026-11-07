import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/data/repositories/v8/backup_restore_plan_v8.dart';
import 'package:repforge/data/repositories/v8/drift_backup_repository_v8.dart';
import 'package:repforge/domain/core/result.dart';

import '../../migration_v8/migration_digest.dart' as digest;
import 'backup_v8_support.dart';

/// WP 8 3b-10, Review C: compact format 3 export (M-1), bounded values in
/// error messages (L-1) and the foreign-key switch of a restore inside one
/// exclusive use of the connection, failures included (L-2).
void main() {
  AppError errorOf(Result<Object?> r) => switch (r) {
    Ok() => throw StateError('expected an error, got Ok'),
    Err(:final error) => error,
  };

  test('M-1: a format 3 export is compact JSON (no indentation) and restores '
      'onto a fresh device', () async {
    await inBackupTempDir((dir) async {
      final a = await richV8(await V8File.create(dir, 'a.sqlite'));
      final b = await V8File.create(dir, 'b.sqlite');
      try {
        final json = await a.repo().exportJson();
        expect(json, isNot(contains('\n')));
        expect(json, startsWith('{"app":"repforge","formatVersion":3,'));
        final restored = await b.repo().importJson(json);
        expect(restored, isA<Ok<Object?>>(), reason: '$restored');
      } finally {
        await a.close();
        await b.close();
      }
    });
  });

  group('L-1: values in messages are clipped', () {
    test('clipForMessage keeps short text, clips long text with its length '
        'and never splits a surrogate pair', () {
      expect(clipForMessage('abc', 3), 'abc');
      expect(clipForMessage('abcd', 3), 'abc… (4 characters)');
      // U+1F600 is two UTF-16 units; the cut falls between them.
      expect(clipForMessage('ab\u{1F600}c', 3), 'ab… (5 characters)');
      expect(describeBackupValue('x' * 1000).length, lessThan(120));
    });

    test('a huge value of the wrong type (format 3 row) is reported '
        'clipped', () async {
      await inBackupTempDir((dir) async {
        final v8 = await richV8(await V8File.create(dir));
        try {
          final env =
              jsonDecode(await v8.repo().exportJson()) as Map<String, Object?>;
          final settings =
              (env['tables']! as Map<String, Object?>)['settings']! as List;
          (settings.first as Map<String, Object?>)['updated_at'] = List.filled(
            50000,
            1,
          );
          final error = errorOf(v8.repo().previewJson(jsonEncode(env)));
          expect(error.message, contains('updated_at must be text, not [1,1'));
          expect(error.message, contains('(100001 characters)'));
          expect(error.message.length, lessThan(1000));
        } finally {
          await v8.close();
        }
      });
    });

    test('a huge value of the wrong type (v7 exercise) and a huge unknown '
        'column are reported clipped', () async {
      await inBackupTempDir((dir) async {
        final v8 = await V8File.create(dir);
        try {
          final env = jsonDecode(
            readGolden(digest.goldenFormat2Path()),
          ) as Map<String, Object?>;
          final exercises =
              (env['tables']! as Map<String, Object?>)['exercises']! as List;
          final first = exercises.first as Map<String, Object?>;
          first['supplied'] = 'y' * 100000;
          var error = errorOf(v8.repo().previewJson(jsonEncode(env)));
          expect(error.message, contains('supplied must be integer, not "yy'));
          expect(error.message, contains('(100002 characters)'));
          expect(error.message.length, lessThan(1000));
          first
            ..['supplied'] = 1
            ..['z' * 100000] = 1;
          error = errorOf(v8.repo().previewJson(jsonEncode(env)));
          expect(error.message, contains('unknown column "zzz'));
          expect(error.message.length, lessThan(1000));
        } finally {
          await v8.close();
        }
      });
    });

    test('a detail is clipped even when the record id is huge', () {
      final e = RestoreRejected('Bad:', ['${'i' * 5000}: broken']);
      expect(e.describe().length, lessThan(maxDetailChars + 80));
      expect(e.describe(), contains('(5008 characters)'));
    });
  });

  group('L-2: the foreign-key switch', () {
    test('no statement from outside the restore runs while the keys are '
        'off', () async {
      await inBackupTempDir((dir) async {
        final a = await richV8(await V8File.create(dir, 'a.sqlite'));
        final b = await V8File.create(dir, 'b.sqlite');
        try {
          final json = await a.repo().exportJson();
          Future<int>? outside;
          final result = await b
              .repo(
                phaseProbe: (p) async {
                  if (p == RestorePhase.keysOff) {
                    // Issued outside the restore's zone: it must wait for
                    // the restore to finish, so it sees the keys on.
                    outside = Zone.root.run(b.foreignKeys);
                  }
                },
              )
              .importJson(json);
          expect(result, isA<Ok<Object?>>(), reason: '$result');
          expect(await outside, 1);
        } finally {
          await a.close();
          await b.close();
        }
      });
    });

    for (final restoreSucceeds in [true, false]) {
      test('a failure switching the keys back is a Result, not a throw '
          '(restore ${restoreSucceeds ? 'succeeded' : 'failed'})', () async {
        await inBackupTempDir((dir) async {
          final a = await richV8(await V8File.create(dir, 'a.sqlite'));
          final interceptor = _FailKeysOn();
          final db = AppDatabaseV8(
            NativeDatabase(File('${dir.path}/b.sqlite'))
                .interceptWith(interceptor),
          );
          try {
            await db.customSelect('SELECT 1').get();
            final json = await a.repo().exportJson();
            interceptor.armed = true;
            final result = await DriftBackupRepositoryV8(
              db,
              config: restoreConfig(),
              phaseProbe: (p) async {
                if (!restoreSucceeds && p == RestorePhase.userDataInserted) {
                  throw StateError('injected at $p');
                }
              },
            ).importJson(json);
            final error = errorOf(result);
            expect(error, isA<StorageError>());
            if (restoreSucceeds) {
              expect(
                error.message,
                'The backup was restored, but foreign keys could not be '
                'switched back on. Restart the app.',
              );
              expect('${(error as StorageError).cause}', contains('refused'));
            } else {
              // The restore's own error, which says why it stopped.
              expect(error.message, 'Restore failed; nothing was changed.');
              expect('${(error as StorageError).cause}', contains('injected'));
            }
          } finally {
            interceptor.armed = false;
            await db.close();
            await a.close();
          }
        });
      });
    }
  });
}

/// Fails `PRAGMA foreign_keys = ON` while [armed].
final class _FailKeysOn extends QueryInterceptor {
  bool armed = false;

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (armed && statement == 'PRAGMA foreign_keys = ON') {
      throw StateError('switching the keys on refused (test)');
    }
    return executor.runCustom(statement, args);
  }
}
