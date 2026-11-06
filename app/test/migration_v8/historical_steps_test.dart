import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/internal/versioned_schema.dart' show VersionedSchema;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/db/legacy_training_rows.dart';
import 'package:repforge/data/db/migration/historical_steps.dart';
import 'package:repforge/data/db/migration/legacy_training_rows_v6.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:repforge/data/db/migration/schema_versions.g.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

import '../data/generated_migrations/schema.dart';
import 'harness_v7_db.dart';
import 'migration_digest.dart';

/// WP 8 stage 3b-3: the historical steps v1 → v7 on frozen shapes
/// (`lib/data/db/migration/`) against today's production result.
///
/// (a) every frozen fixture migrates to exactly `expected_v7_digests.json`;
/// (b) the schema equals a fresh v7 schema and today's live production
///     result, also under a strict SQL normaliser;
/// (c) a failure inside any step rolls that step back, version included,
///     and a re-run completes to the same result;
/// (d) negative control: a v5 → v6 rebuild into a later shape fails;
/// (e) `user_version` is N after step N; foreign keys are off during the
///     chain and on afterwards;
/// (f) a database left in today's production crash window (work committed,
///     `user_version` not written) still completes;
/// plus the generated shapes against the frozen snapshots and the live
/// dependencies of the reused data logic.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final expected =
      (jsonDecode(File(expectedDigestsPath).readAsStringSync())
              as Map<String, Object?>)['fixtures']!
          as Map<String, Object?>;
  int versionOf(String key) => int.parse(key.substring(1).split('_').first);

  /// Compares a chain result with the stored production result of [key].
  void expectProductionResult(Map<String, Object?> got, String key) {
    final want = expected[key]! as Map<String, Object?>;
    expect(got['migrated'], isTrue, reason: '${got['error']}');
    expect(got['userVersion'], want['userVersion']);
    expect(got['integrityCheck'], want['integrityCheck']);
    expect(got['foreignKeyViolations'], want['foreignKeyViolations']);
    expect(
      jsonEncode(got['schema']),
      jsonEncode(want['schema']),
      reason: 'schema after migration',
    );
    final gotTables = got['tables']! as Map<String, Object?>;
    final wantTables = want['tables']! as Map<String, Object?>;
    expect(gotTables.keys.toList(), wantTables.keys.toList());
    expect(
      [
        for (final t in wantTables.keys)
          if (jsonEncode(gotTables[t]) != jsonEncode(wantTables[t])) t,
      ],
      isEmpty,
      reason: 'tables with different rows',
    );
  }

  group("(a) differential: the chain reproduces today's v7 result", () {
    final hashesBefore = {
      for (final (key, path) in allFixtures()) key: sha256OfFile(path),
    };

    for (final (key, path) in allFixtures()) {
      test('fixture_$key', () async {
        final got = await migrateWithChain(path);
        expectProductionResult(got, key);
        final want = expected[key]! as Map<String, Object?>;
        expect(
          got['foreignKeyViolationsBefore'],
          want['foreignKeyViolationsBefore'],
        );
        if (!key.endsWith('_orphans')) {
          expect(got['foreignKeyViolations'], isEmpty);
        }
      });
    }

    test('fixtures are untouched and no temporary file is left', () {
      for (final (key, path) in allFixtures()) {
        expect(sha256OfFile(path), hashesBefore[key]);
        expect(File('$path-journal').existsSync(), isFalse);
      }
      expect(
        Directory.systemTemp.listSync().where(
          (e) => e.path
              .split(Platform.pathSeparator)
              .last
              .startsWith(chainTempPrefix),
        ),
        isEmpty,
      );
    });
  });

  group('(b) schema equals a fresh v7 schema', () {
    late Map<String, Object?> snapshotV7;
    late Map<String, Object?> productionFresh;
    late List<String> strictSnapshotV7;
    late bool productionIsV7;

    setUpAll(() async {
      snapshotV7 = await freshSchemaDescription(7);
      productionFresh = await productionFreshSchemaDescription();
      strictSnapshotV7 = await _freshStrictSchema(
        (e) => GeneratedHelper().databaseForVersion(e, 7),
      );
      final app = AppDatabase(NativeDatabase.memory());
      productionIsV7 = app.schemaVersion == 7;
      await app.close();
    });

    for (final (key, path) in allFixtures()) {
      test('fixture_$key: table_info, indexes, foreign keys, CHECKs, '
          'triggers; strict SQL equals the frozen production v7', () async {
        final got = await migrateWithChain(path);
        expect(jsonEncode(got['schema']), jsonEncode(snapshotV7));
        expect(jsonEncode(got['schema']), jsonEncode(productionFresh));
        final strict = got['strictSchema']! as List<String>;
        expect(strict, hasLength(greaterThan(40)));
        expect(strict, strictSnapshotV7);
        // Frozen strict record of production v7 (review M1): every entity,
        // strict SQL and CHECK clauses with operator direction.
        final record = strictOnly(got['strictRecord']! as List<Object?>);
        expect(jsonEncode(record), jsonEncode(_frozenStrict(key)));
        expect(jsonEncode(record), jsonEncode(_frozenStrict('fresh')));
        // Live production as well, while production is still at v7.
        if (productionIsV7) {
          expect(strict, await productionStrictSchema(path));
        }
      });
    }

    test('the frozen strict record refines expected_v7_digests.json: '
        'normaliseSql of it gives every stored create_sql, check and '
        'index_sql', () {
      var compared = 0;
      for (final (key, _) in allFixtures()) {
        final schema =
            (expected[key]! as Map<String, Object?>)['schema']!
                as Map<String, Object?>;
        final tables = schema['tables']! as Map<String, Object?>;
        final indexSql = schema['index_sql']! as Map<String, Object?>;
        final record = _frozenStrict(key);
        final recordTables = {
          for (final e in record)
            if (e['type'] == 'table') e['name']! as String: e,
        };
        final recordIndexes = {
          for (final e in record)
            if (e['type'] == 'index' && e['strict'] != null)
              e['name']! as String: e,
        };
        expect(recordTables.keys.toSet(), tables.keys.toSet());
        expect(recordIndexes.keys.toSet(), indexSql.keys.toSet());
        expect(
          record.where((e) => e['type'] == 'trigger' || e['type'] == 'view'),
          isEmpty,
        );
        expect(schema['triggers_and_views'], isEmpty);
        for (final MapEntry(key: name, value: e) in recordTables.entries) {
          final stored = tables[name]! as Map<String, Object?>;
          expect(
            normaliseSql(e['strict']! as String),
            stored['create_sql'],
            reason: '$key $name',
          );
          expect(
            [for (final c in e['checks']! as List) normaliseSql(c as String)],
            stored['checks'],
            reason: '$key $name checks',
          );
          compared++;
        }
        for (final MapEntry(key: name, value: e) in recordIndexes.entries) {
          expect(normaliseSql(e['strict']! as String), indexSql[name]);
          compared++;
        }
      }
      expect(compared, greaterThan(13 * 40));
    });

    test('the strict normaliser keeps operators the 3b-1 one loses', () {
      // Recorded finding: normaliseSql replaces every operator with "$1".
      expect(normaliseSql('a > 0'), normaliseSql('a < 0'));
      expect(strictNormaliseSql('a > 0'), isNot(strictNormaliseSql('a < 0')));
      expect(
        strictNormaliseSql('"completed" IN (0, 1)'),
        strictNormaliseSql('completed IN(0,1)'),
      );
    });
  });

  group('(c) a failure inside a step rolls it back; a re-run completes', () {
    final cases = <(String, String, int, MigrationStage)>[
      // Every step of every clean fixture fails at the last moment.
      for (final (key, path) in allFixtures())
        if (!key.endsWith('_orphans') && versionOf(key) < 7)
          for (var k = versionOf(key); k < 7; k++)
            (key, path, k, MigrationStage.versionWritten),
      // The first step of each fixture also fails before and after its work.
      for (final (key, path) in allFixtures())
        if (versionOf(key) < 7)
          for (final stage in [
            MigrationStage.stepStarted,
            MigrationStage.workDone,
            if (key.endsWith('_orphans')) MigrationStage.versionWritten,
          ])
            (key, path, versionOf(key), stage),
    ];

    for (final (key, path, k, stage) in cases) {
      test('fixture_$key, step v$k→v${k + 1} fails at ${stage.name}', () async {
        final s = versionOf(key);
        final reference = await withFixtureCopy(path, (copy) async {
          if (k > s) {
            expect(await openWithChain(copy, targetVersion: k), isNull);
          }
          return describeFile(copy);
        });
        expect(reference['userVersion'], k);

        await withFixtureCopy(path, (copy) async {
          final error = await openWithChain(
            copy,
            probe: (c) async {
              if (c.from == k && c.stage == stage) {
                throw StateError('injected at $c');
              }
            },
          );
          expect(error, isA<StateError>());
          final failed = describeFile(copy);
          expect(failed['userVersion'], k);
          expect(failed['integrityCheck'], 'ok');
          expect(jsonEncode(failed['tables']), jsonEncode(reference['tables']));
          expect(failed['strictSchema'], reference['strictSchema']);
          expect(jsonEncode(failed['schema']), jsonEncode(reference['schema']));

          expect(await openWithChain(copy), isNull);
          expectProductionResult(describeFile(copy), key);
        });
      });
    }
  });

  group('(d) negative control: the v5 → v6 hazard', () {
    // The production step rebuilds into the CURRENT classes. Written against
    // a later shape, a rebuild selects columns the v5 table does not have.
    Future<int> rebuildIntoV7Shape(int from, GeneratedDatabase db) async {
      if (from != 5) {
        return await HistoricalSteps(clock: harnessClock).steps(from, db);
      }
      final later = Schema7(database: db);
      await Migrator(db, later).alterTable(
        TableMigration(
          later.sessionSets,
          newColumns: [
            later.sessionSets.energyKcal,
            later.sessionSets.energyProvenance,
          ],
        ),
      );
      return 6;
    }

    test('a rebuild of v5 session_sets into a later shape fails and '
        'changes nothing', () async {
      await withFixtureCopy(fixturePath(5), (copy) async {
        final before = describeFile(copy);
        final error = await openWithChain(copy, steps: rebuildIntoV7Shape);
        expect(error, isA<SqliteException>());
        expect('$error', matches(RegExp('no such column: "?set_kind')));
        final after = describeFile(copy);
        expect(after['userVersion'], 5);
        expect(jsonEncode(after['tables']), jsonEncode(before['tables']));
        expect(after['strictSchema'], before['strictSchema']);
      });
    });

    test('the frozen Schema6 rebuild of the same fixture reaches the v6 '
        'shape exactly', () async {
      final freshV6 = await _freshStrictSchema(
        (e) => GeneratedHelper().databaseForVersion(e, 6),
      );
      await withFixtureCopy(fixturePath(5), (copy) async {
        expect(await openWithChain(copy, targetVersion: 6), isNull);
        expect(describeFile(copy)['strictSchema'], freshV6);
      });
    });
  });

  group('(e) user_version and foreign keys', () {
    for (final (key, path) in allFixtures()) {
      if (versionOf(key) == 7) continue;
      test('fixture_$key: version N after step N; keys off inside, on '
          'after', () async {
        await withFixtureCopy(path, (copy) async {
          final seen = <String>[];
          late final HarnessV7Database db;
          Future<int> read(String pragma) async =>
              (await db.customSelect('PRAGMA $pragma').getSingle()).read<int>(
                pragma,
              );
          db = HarnessV7Database(
            NativeDatabase(copy),
            probe: (c) async {
              final uv = await read('user_version');
              final fk = await read('foreign_keys');
              seen.add('${c.from}>${c.reached} ${c.stage.name} uv=$uv fk=$fk');
            },
          );
          try {
            await db.customSelect('SELECT 1').get();
            expect(await read('foreign_keys'), 1);
            expect(await read('user_version'), 7);
          } finally {
            await db.close();
          }
          final s = versionOf(key);
          expect(seen, [
            for (var n = s; n < 7; n++) ...[
              '$n>null stepStarted uv=$n fk=0',
              '$n>${n + 1} workDone uv=$n fk=0',
              '$n>${n + 1} versionWritten uv=${n + 1} fk=0',
              '$n>${n + 1} committed uv=${n + 1} fk=0',
            ],
          ]);
        });
      });
    }

    for (final (key, path) in allFixtures()) {
      if (versionOf(key) == 7) continue;
      test('fixture_$key on a connection with foreign keys ON at setup: '
          'keys off inside, same result', () async {
        await withFixtureCopy(path, (copy) async {
          final fkSeen = <int>{};
          late final HarnessV7Database db;
          db = HarnessV7Database(
            NativeDatabase(
              copy,
              setup: (d) => d.execute('PRAGMA foreign_keys = ON'),
            ),
            probe: (c) async {
              fkSeen.add(
                (await db.customSelect('PRAGMA foreign_keys').getSingle())
                    .read<int>('foreign_keys'),
              );
            },
          );
          try {
            await db.customSelect('SELECT 1').get();
          } finally {
            await db.close();
          }
          expect(fkSeen, {0});
          expectProductionResult(describeFile(copy), key);
        });
      });
    }

    test('the setup callback really switches keys on', () async {
      await withFixtureCopy(fixturePath(7), (copy) async {
        final db = _BareDatabase(
          NativeDatabase(
            copy,
            setup: (d) => d.execute('PRAGMA foreign_keys = ON'),
          ),
          version: 7,
        );
        try {
          final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
          expect(row.read<int>('foreign_keys'), 1);
        } finally {
          await db.close();
        }
      });
    });

    test('after an injected failure the keys are on again and the original '
        'error propagates', () async {
      await withFixtureCopy(fixturePath(4), (copy) async {
        final db = _BareDatabase(NativeDatabase(copy), version: 4);
        Future<int> read(String pragma) async =>
            (await db.customSelect('PRAGMA $pragma').getSingle()).read<int>(
              pragma,
            );
        try {
          expect(await read('foreign_keys'), 0);
          final m = RepforgeMigration(
            database: db,
            clock: harnessClock,
            probe: (c) async {
              if (c.from == 5 && c.stage == MigrationStage.workDone) {
                throw StateError('injected');
              }
            },
          );
          await expectLater(
            m.upgrade(4, 7),
            throwsA(
              isA<StateError>().having((e) => e.message, 'm', 'injected'),
            ),
          );
          expect(await read('foreign_keys'), 1);
          expect(await read('user_version'), 5);
        } finally {
          await db.close();
        }
      });
    });

    test('a direct upgrade() leaves the keys on by itself (no '
        'beforeOpen)', () async {
      await withFixtureCopy(fixturePath(4), (copy) async {
        // No migration strategy of ours: the keys are on only if upgrade()
        // switched them on.
        final db = _BareDatabase(NativeDatabase(copy), version: 4);
        Future<int> read(String pragma) async =>
            (await db.customSelect('PRAGMA $pragma').getSingle()).read<int>(
              pragma,
            );
        try {
          expect(await read('foreign_keys'), 0);
          await RepforgeMigration(
            database: db,
            clock: harnessClock,
          ).upgrade(4, 7);
          expect(await read('foreign_keys'), 1);
          expect(await read('user_version'), 7);
        } finally {
          await db.close();
        }
        expectProductionResult(describeFile(copy), 'v4');
      });
    });

    test('a failing key restore never masks the original error', () async {
      await withFixtureCopy(fixturePath(4), (copy) async {
        final db = _BareDatabase(NativeDatabase(copy), version: 4);
        try {
          final m = RepforgeMigration(
            database: db,
            clock: harnessClock,
            probe: (c) async {
              if (c.stage == MigrationStage.committed) {
                // An open transaction makes the restore pragma a no-op, so
                // the restore check fails as well.
                await db.customStatement('BEGIN');
                throw StateError('original');
              }
            },
          );
          await expectLater(
            m.upgrade(4, 7),
            throwsA(
              isA<StateError>().having((e) => e.message, 'm', 'original'),
            ),
          );
          await db.customStatement('ROLLBACK');
        } finally {
          await db.close();
        }
      });
    });

    test('the v7 fixture runs no step and keeps its rows', () async {
      await withFixtureCopy(fixturePath(7), (copy) async {
        final before = describeFile(copy);
        final steps = <MigrationCheckpoint>[];
        expect(
          await openWithChain(copy, probe: (c) async => steps.add(c)),
          isNull,
        );
        expect(steps, isEmpty);
        final after = describeFile(copy);
        expect(jsonEncode(after['tables']), jsonEncode(before['tables']));
        expect(after['userVersion'], 7);
      });
    });

    test('a downgrade is refused', () async {
      final m = RepforgeMigration(
        database: HarnessV7Database(NativeDatabase.memory()),
        clock: harnessClock,
      );
      try {
        await expectLater(m.upgrade(7, 6), throwsStateError);
      } finally {
        await m.database.close();
      }
    });

    test('the chain refuses to run when foreign keys cannot be switched '
        'off', () async {
      final db = HarnessV7Database(NativeDatabase.memory());
      try {
        await db.customSelect('SELECT 1').get();
        // Inside a transaction the pragma is ignored: keys stay on.
        await expectLater(
          db.transaction(
            () => RepforgeMigration(
              database: db,
              clock: harnessClock,
            ).upgrade(7, 7),
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('did not switch off'),
            ),
          ),
        );
      } finally {
        await db.close();
      }
    });

    test('a step that does not advance the version fails its '
        'transaction', () async {
      await withFixtureCopy(fixturePath(6), (copy) async {
        final error = await openWithChain(copy, steps: (from, db) async => 6);
        expect(error, isA<StateError>());
        expect(describeFile(copy)['userVersion'], 6);
      });
    });
  });

  group("(f) a database in today's production crash window completes", () {
    // Production commits each step but drift writes user_version only after
    // the whole upgrade. Production work done, version still old: the guards
    // make the chain finish with the same result.
    for (final (key, path) in allFixtures()) {
      final s = versionOf(key);
      if (s == 7) continue;
      test(
        'fixture_$key: production work committed, user_version $s',
        () async {
          await withFixtureCopy(path, (copy) async {
            final app = AppDatabase(NativeDatabase(copy));
            try {
              await app.customSelect('SELECT 1').get();
            } finally {
              await app.close();
            }
            final raw = sqlite3.open(copy.path);
            try {
              raw.execute('PRAGMA user_version = $s');
            } finally {
              raw.close();
            }
            expect(await openWithChain(copy), isNull);
            expectProductionResult(describeFile(copy), key);
          });
        },
      );
    }

    // Partial production states (review L2): production committed its
    // steps up to v6 (with its v7 columns on session_sets, the hazard) but
    // not v6 → v7; user_version is the start version or later.
    for (final (key, path) in allFixtures()) {
      final s = versionOf(key);
      if (s < 2 || s > 5) continue;
      for (final uv in {s, if (s <= 4) 4, 5}) {
        test('fixture_$key: production work up to v6 committed, '
            'user_version $uv', () async {
          await withFixtureCopy(path, (copy) async {
            final app = AppDatabase(NativeDatabase(copy));
            try {
              await app.customSelect('SELECT 1').get();
            } finally {
              await app.close();
            }
            final raw = sqlite3.open(copy.path);
            try {
              raw
                ..execute('DROP TABLE session_exercises')
                ..execute('DROP TABLE scheduled_workouts')
                ..execute('DROP INDEX idx_session_sets_entry')
                ..execute('UPDATE session_sets SET session_exercise_id = NULL')
                ..execute('PRAGMA user_version = $uv');
            } finally {
              raw.close();
            }
            expect(await openWithChain(copy), isNull);
            expectProductionResult(describeFile(copy), key);
          });
        });
      }
    }

    for (final (key, path) in allFixtures()) {
      final s = versionOf(key);
      if (s == 7 || key.endsWith('_orphans')) continue;
      for (var k = s; k < 7; k++) {
        test('fixture_$key: chain step v$k→v${k + 1} committed, '
            'user_version $k', () async {
          await withFixtureCopy(path, (copy) async {
            expect(await openWithChain(copy, targetVersion: k + 1), isNull);
            final raw = sqlite3.open(copy.path);
            try {
              raw.execute('PRAGMA user_version = $k');
            } finally {
              raw.close();
            }
            expect(await openWithChain(copy), isNull);
            expectProductionResult(describeFile(copy), key);
          });
        });
      }
    }
  });

  group('generated shapes equal the frozen snapshots', () {
    test('the generated dispatcher has steps from v1 to v6 only', () async {
      final db = _BareDatabase(NativeDatabase.memory());
      try {
        final steps = HistoricalSteps(clock: harnessClock).steps;
        await expectLater(steps(0, db), throwsArgumentError);
        await expectLater(steps(7, db), throwsArgumentError);
      } finally {
        await db.close();
      }
    });

    for (var v = 2; v <= 7; v++) {
      test('Schema$v creates the schema_v$v snapshot schema', () async {
        final viaSteps = await _freshStrictSchema(
          _BareDatabase.new,
          create: (db) => Migrator(db, _schemaAt(v, db)).createAll(),
        );
        final snapshot = await _freshStrictSchema(
          (e) => GeneratedHelper().databaseForVersion(e, v),
        );
        expect(viaSteps, snapshot);
        expect(viaSteps, isNotEmpty);
      });
    }
  });

  group('frozen LegacyTrainingRowsV6 (review M3)', () {
    // Production names (enum values), for the equivalence checks.
    final liveLists = <String, (List<Enum>, List<String>)>{
      'type': (ExerciseType.values, LegacyTrainingRowsV6.exerciseTypes),
      'category': (
        ExerciseCategory.values,
        LegacyTrainingRowsV6.exerciseCategories,
      ),
      'muscle': (MuscleGroup.values, LegacyTrainingRowsV6.muscleGroups),
      'equipment': (Equipment.values, LegacyTrainingRowsV6.equipment),
    };

    test("the frozen identifier lists equal today's enums", () {
      for (final MapEntry(key: name, value: (live, frozen))
          in liveLists.entries) {
        expect(frozen, [for (final v in live) v.name], reason: name);
      }
    });

    // Every identifier, label and synonym, in several spellings, plus
    // no-equipment words, unmatched words and edge cases.
    String spaced(String camel) =>
        camel.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m.group(0)}');
    final rawTexts = <String>{
      for (final (_, frozen) in liveLists.values)
        for (final n in frozen) ...[n, n.toUpperCase(), spaced(n), '$n!'],
      for (final k in LegacyTrainingRowsV6.labelToIdentifier.keys) ...[
        k,
        k.toUpperCase(),
      ],
      for (final k in LegacyTrainingRowsV6.synonyms.keys) ...[
        k,
        ' ${k.toUpperCase()} ',
      ],
      ...LegacyTrainingRowsV6.noEquipment,
      'Cable Station',
      'Rowing Machine',
      'Cross-Trainer',
      'Bench Press',
      'delts',
      'shoulders',
      'rotator cuff',
      '',
      '   ',
      '???',
      'Écarté',
      'quàds',
      '腿',
    };

    test('matchName golden: labels and synonyms', () {
      const m = LegacyTrainingRowsV6.matchName;
      const eq = LegacyTrainingRowsV6.equipment;
      const mu = LegacyTrainingRowsV6.muscleGroups;
      const ca = LegacyTrainingRowsV6.exerciseCategories;
      LegacyTrainingRowsV6.labelToIdentifier.forEach((label, id) {
        expect(m(label, eq), id, reason: label);
      });
      LegacyTrainingRowsV6.synonyms.forEach((word, id) {
        final list = mu.contains(id) ? mu : (eq.contains(id) ? eq : ca);
        expect(m(word, list), id, reason: word);
      });
      expect(m('Cable Station', eq), 'cable');
      expect(m('Front Delts', mu), 'frontDelts');
      expect(m('front-delts', mu), 'frontDelts');
      expect(m('Stretching', ca), 'mobility');
      expect(m('Stretching', mu), isNull);
      expect(m('delts', mu), isNull);
      expect(m('shoulders', mu), isNull);
      expect(m('', mu), isNull);
      expect(m('quàds', mu), isNull);
      expect(m('Quads', eq), isNull);
    });

    test('matchName equals production on ${rawTexts.length} texts x 4 '
        'lists', () {
      for (final raw in rawTexts) {
        for (final MapEntry(key: name, value: (live, frozen))
            in liveLists.entries) {
          expect(
            LegacyTrainingRowsV6.matchName(raw, frozen),
            LegacyTrainingRows.matchName(raw, live),
            reason: '"$raw" as $name',
          );
        }
      }
    });

    // Boundaries of every range: just inside, on, and just outside.
    final setRows = <Map<String, Object?>>[
      {'id': 'clean', 'reps': 5},
      for (final (column, lo, hi) in [
        ('reps', 1, 100),
        ('load_kg', 0, 1000),
        ('assistance_kg', 0, 1000),
        ('average_heart_rate', 30, 250),
        ('exertion_value', 0, 10),
        ('rest_seconds', 0, 3600),
      ])
        for (final v in [lo - 1, lo - 0.5, lo, lo + 0.5, hi, hi + 0.5, hi + 1])
          {'id': '$column=$v', column: v},
      for (final column in ['duration_sec', 'metres'])
        for (final v in [-1, 0, 0.1, 1]) {'id': '$column=$v', column: v},
      {'id': 'text', 'reps': 'ten', 'load_kg': null},
      {'id': 'many', 'reps': 0, 'load_kg': -5, 'rest_seconds': 3601},
    ];
    final planRows = <Map<String, Object?>>[
      for (final sets in [0, 1, 20, 21, null])
        for (final order in [-1, 0, 3, 'x'])
          {'id': 'p$sets/$order', 'target_sets': sets, 'sort_order': order},
      for (final reps in [0, 1, 100, 101, null])
        {
          'id': 'r$reps',
          'target_sets': 3,
          'sort_order': 0,
          'target_reps': reps,
        },
      for (final (min, max) in [(1, 5), (5, 1), (0, 5), (null, 5), (3, 3)])
        {
          'id': 'v6 $min-$max',
          'target_sets': 3,
          'sort_order': 0,
          'reps_min': min,
          'reps_max': max,
        },
      for (final (column, bad) in [
        ('target_load_kg', 1000.5),
        ('target_load_kg', -0.1),
        ('target_duration_sec', 0),
        ('target_metres', -1),
        ('rest_seconds', 3601),
      ])
        {
          'id': '$column=$bad',
          'target_sets': 3,
          'sort_order': 0,
          'target_reps': 5,
          column: bad,
        },
    ];

    String sanitisedV6(SanitisedRowV6 r) =>
        jsonEncode([r.row, r.nulledColumns, r.reason, r.unchanged]);
    String sanitisedLive(SanitisedRow r) =>
        jsonEncode([r.row, r.nulledColumns, r.reason, r.unchanged]);

    test('range golden: sets and plan exercises', () {
      const set = LegacyTrainingRowsV6.sessionSet;
      expect(set({'reps': 1, 'load_kg': 1000}).unchanged, isTrue);
      expect(set({'reps': 101}).nulledColumns, ['reps']);
      expect(set({'reps': 0}).reason, 'Out-of-range value set to NULL: reps');
      expect(set({'duration_sec': 0}).nulledColumns, ['duration_sec']);
      expect(set({'exertion_value': 10.5}).nulledColumns, ['exertion_value']);
      expect(set({'average_heart_rate': 29}).nulledColumns, [
        'average_heart_rate',
      ]);
      const plan = LegacyTrainingRowsV6.planExercise;
      final gone = plan({'target_sets': 21, 'sort_order': 0});
      expect(gone.row, isNull);
      expect(
        gone.reason,
        'Out-of-range target_sets or sort_order; row moved here',
      );
      final mapped = plan({
        'target_sets': 3,
        'sort_order': 0,
        'target_reps': 8,
      });
      expect(mapped.row, {
        'target_sets': 3,
        'sort_order': 0,
        'reps_min': 8,
        'reps_max': 8,
      });
      expect(
        plan({'target_sets': 3, 'sort_order': 0, 'reps_min': 5, 'reps_max': 1})
            .nulledColumns,
        ['reps_min', 'reps_max'],
      );
    });

    test('ranges equal production on ${setRows.length} sets and '
        '${planRows.length} plan exercises', () {
      for (final row in setRows) {
        expect(
          sanitisedV6(LegacyTrainingRowsV6.sessionSet(row)),
          sanitisedLive(LegacyTrainingRows.sessionSet(row)),
          reason: '${row['id']}',
        );
      }
      for (final row in planRows) {
        expect(
          sanitisedV6(LegacyTrainingRowsV6.planExercise(row)),
          sanitisedLive(LegacyTrainingRows.planExercise(row)),
          reason: '${row['id']}',
        );
      }
    });

    // Unicode sample for the frozen search key (Dart's toLowerCase and the
    // diacritic table): accents, upper-case accents, ß, dotted İ, final
    // sigma, ø, CJK, emoji, combining marks.
    const unicodeNames = [
      'Développé Couché',
      'ÀÉÎÕÜ ÇÑ',
      'Straße',
      'İstanbul Squat',
      'ΣΊΣΥΦΟΣ',
      'Øvelse æ œ ł đ',
      '深蹲 🏋️ 💪🏽',
      'Café (combining)',
      '',
    ];

    test('search key golden', () {
      const key = LegacyTrainingRowsV6.searchKey;
      expect(
        key('Développé Couché', ['Bänkpress']),
        'developpe couche bankpress',
      );
      expect(key('ÀÉÎÕÜ ÇÑ', const []), 'aeiou cn');
      expect(key('Straße', const []), 'straße');
      expect(key('Øvelse æ œ ł đ', const []), 'øvelse æ œ ł đ');
      expect(key('深蹲 🏋️', const []), '深蹲 🏋️');
      expect(key('Café', const []), 'café');
      expect(key('', const ['A']), ' a');
    });

    test('search key and exercise mapping equal production', () {
      for (final name in unicodeNames) {
        for (final aliases in [
          const <String>[],
          const ['Ä', 'b C'],
          unicodeNames,
        ]) {
          expect(
            LegacyTrainingRowsV6.searchKey(name, aliases),
            exerciseSearchKey(name, aliases),
            reason: name,
          );
        }
      }
      final exerciseRows = <Map<String, Object?>>[
        for (final (i, raw) in rawTexts.indexed)
          {
            'id': 'e$i',
            'name': unicodeNames[i % unicodeNames.length],
            'type': raw,
            'category': raw,
            'primary_muscle': raw,
            'secondary_muscles_json': jsonEncode([raw, 'Quads', raw]),
            'equipment_json': jsonEncode([raw, 'none']),
            'is_custom': i.isEven ? 1 : 0,
          },
        {'id': 'bad-json', 'secondary_muscles_json': 'chest,', 'is_custom': 1},
        {'id': 'not-strings', 'equipment_json': '[1, 2]'},
        {'id': 'aliases', 'name': 'Row', 'aliases_json': '["Rudern", 7]'},
        {'id': 'bad-aliases', 'aliases_json': '{'},
        {'id': 'v6 row', 'supplied': 1, 'type': 'Weighted'},
      ];
      for (final row in exerciseRows) {
        final v6 = LegacyTrainingRowsV6.exercise(row);
        final live = LegacyTrainingRows.exercise(row);
        expect(
          jsonEncode(v6.row),
          jsonEncode(live.row),
          reason: '${row['id']}',
        );
        expect(v6.quarantineReason, live.quarantineReason);
      }
    });
  });
}

/// A database with no tables, so a [Migrator] with a frozen schema can
/// create that schema on an empty file.
class _BareDatabase extends GeneratedDatabase {
  _BareDatabase(super.executor, {this.version = 1});

  /// Equal to the file's `user_version`, so opening runs no migration.
  final int version;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => version;
}

Map<String, Object?>? _frozenStrictFile;

/// The strict parts of the frozen production v7 record of [key] (a fixture
/// key or `fresh`).
List<Map<String, Object?>> _frozenStrict(String key) {
  final file = _frozenStrictFile ??= jsonDecode(
    File(strictSchemaPath).readAsStringSync(),
  ) as Map<String, Object?>;
  final entry = key == 'fresh'
      ? file['fresh']
      : (file['fixtures']! as Map<String, Object?>)[key];
  return strictOnly(entry! as List<Object?>);
}

VersionedSchema _schemaAt(int v, GeneratedDatabase db) => switch (v) {
  2 => Schema2(database: db),
  3 => Schema3(database: db),
  4 => Schema4(database: db),
  5 => Schema5(database: db),
  6 => Schema6(database: db),
  7 => Schema7(database: db),
  _ => throw ArgumentError.value(v),
};

/// [strictSchema] of a new file opened (and so created) by [open], after
/// [create] if given.
Future<List<String>> _freshStrictSchema(
  GeneratedDatabase Function(QueryExecutor e) open, {
  Future<void> Function(GeneratedDatabase db)? create,
}) async {
  final dir = Directory.systemTemp.createTempSync(chainTempPrefix);
  try {
    final file = File('${dir.path}/fresh.sqlite');
    final db = open(NativeDatabase(file));
    try {
      await db.customSelect('SELECT 1').get();
      if (create != null) await create(db);
    } finally {
      await db.close();
    }
    final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      return strictSchema(raw);
    } finally {
      raw.close();
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}
