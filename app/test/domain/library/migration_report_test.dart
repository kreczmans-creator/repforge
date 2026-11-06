import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/legacy_v8_mapping.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/library/sha256_hex.dart';

import '../../migration_v8/migration_digest.dart' as frozen_digest;

/// WS4 (3B-ACC-01): the migration report contract (R-03 to R-08).
void main() {
  ReportRun run([String id = 'run-1']) => ReportRun(
    runId: id,
    trigger: ReportTrigger.migration,
    generatedAt: DateTime.utc(2026, 11, 6, 12),
    appVersion: '0.8.0+test',
    fromSchemaVersion: 7,
    toSchemaVersion: 8,
  );

  ReportEvent ev({
    String table = 'exercises',
    String recordId = 'ex-1',
    String field = 'equipment_json',
    int? position,
    ReportAction action = ReportAction.skipped,
    String rule = 'IC-307',
    ReportCategory category = ReportCategory.migrated,
    BlockReason? blockReason,
    Object? original = '["barbell","barbell"]',
  }) => ReportEvent(
    table: table,
    recordId: recordId,
    field: field,
    position: position,
    originalValue: encodeStoredValue(original),
    action: action,
    rule: rule,
    category: category,
    reason: 'A test event.',
    blockReason: blockReason,
  );

  group('categories (R-05)', () {
    test('the five stored codes are exactly the approved strings', () {
      expect(
        [for (final c in ReportCategory.values) c.code],
        [
          'migrated',
          'preserved',
          'quarantinedOrUnresolved',
          'rejectedOrBlocked',
          'warningForReview',
        ],
      );
      expect(
        [for (final c in ReportCategory.values) c.ownerWording],
        [
          'migrated successfully',
          'preserved unchanged',
          'quarantined or unresolved',
          'rejected or blocked',
          'warnings requiring review',
        ],
      );
    });

    test('four outcomes; warnings are not an outcome (R-04)', () {
      expect(ReportCategory.outcomes, [
        ReportCategory.migrated,
        ReportCategory.preserved,
        ReportCategory.quarantinedOrUnresolved,
        ReportCategory.rejectedOrBlocked,
      ]);
      expect(ReportCategory.warningForReview.isOutcome, isFalse);
      expect(
        ReportCategory.values.where((c) => c.isOutcome),
        ReportCategory.outcomes,
      );
    });

    test('codes round-trip; unknown codes are refused', () {
      for (final c in ReportCategory.values) {
        expect(ReportCategory.fromCode(c.code), c);
      }
      expect(ReportCategory.fromCode('Migrated'), isNull);
      expect(ReportCategory.fromCode('warnings'), isNull);
    });

    test('actions are the section 4.2 list plus blocked (R-03) and '
        'corrected (C-1)', () {
      expect(
        [for (final a in ReportAction.values) a.name],
        [
          'quarantined',
          'cleared',
          'retained',
          'mapped',
          'markerAdded',
          'skipped',
          'rejected',
          'blocked',
          'none',
          'corrected',
        ],
      );
      expect(ReportAction.fromName('blocked'), ReportAction.blocked);
      expect(ReportAction.fromName('corrected'), ReportAction.corrected);
      expect(ReportAction.fromName('Blocked'), isNull);
    });

    test('block reasons (R-02; unreadable data, 2026-11-06)', () {
      expect(
        [for (final r in BlockReason.values) r.name],
        [
          'noPrimaryTarget',
          'unknownEquipment',
          'invalidEquipment',
          'invalidSecondaryTarget',
          'invalidClassification',
          'invalidAliases',
        ],
      );
    });

    test('block-row rule codes: approved IC-204, ADR-0008-Q12, R-02 and the '
        'three decision-reference codes', () {
      expect(
        {
          for (final r in BlockReason.values)
            r: MigrationRuleCodes.blockRule(r),
        },
        {
          BlockReason.noPrimaryTarget: 'IC-204',
          BlockReason.unknownEquipment: 'ADR-0008-Q12',
          BlockReason.invalidEquipment: 'R-02',
          BlockReason.invalidSecondaryTarget: 'D04-UNREADABLE-SECONDARY',
          BlockReason.invalidClassification: 'D04-UNREADABLE-CLASSIFICATION',
          BlockReason.invalidAliases: 'D04-UNREADABLE-ALIASES',
        },
      );
    });

    test('triggers: section 4.2 plus userCorrection (C-1)', () {
      expect(
        [for (final t in ReportTrigger.values) t.name],
        [
          'migration',
          'restore',
          'integrityCheck',
          'catalogueUpdate',
          'userCorrection',
        ],
      );
    });
  });

  group('stored value encoding (R-06)', () {
    test('SQL NULL, JSON null text, strings and numbers stay distinct', () {
      // A list, not a map: 7 == 7.0 in Dart, so they cannot both be keys.
      final cases = <(Object?, String)>[
        (null, 'null'),
        ('null', '"null"'),
        ('', '""'),
        ('[null]', '"[null]"'),
        ('7', '"7"'),
        (7, '7'),
        (7.0, '7.0'),
        (-0.0, '-0.0'),
        (9.75, '9.75'),
        (1e21, '1e+21'),
        (-3, '-3'),
        ('é "quoted" \n', jsonEncode('é "quoted" \n')),
        (double.infinity, '{"real":"Infinity"}'),
        (double.negativeInfinity, '{"real":"-Infinity"}'),
        (double.nan, '{"real":"NaN"}'),
      ];
      for (final (key, value) in cases) {
        expect(encodeStoredValue(key), value, reason: '$key');
        expect(encodeStoredValue(key), isNot(isEmpty));
      }
      expect(
        {for (final (_, v) in cases) v}.length,
        cases.length,
        reason: 'distinct',
      );
    });

    test('round trip keeps type and value', () {
      final values = <Object?>[
        null,
        'null',
        '',
        ' ',
        'rpe',
        '{"blob":"AA=="}',
        '{"real":"NaN"}',
        0,
        7,
        -(1 << 62) - 1,
        7.0,
        0.5,
        -0.0,
        1e-300,
        1e300,
        double.infinity,
        double.negativeInfinity,
        <int>[],
        [0, 1, 254, 255],
      ];
      final r = Random(7);
      for (var i = 0; i < 500; i++) {
        values
          ..add(r.nextDouble() * 1000)
          ..add(r.nextInt(1 << 32) - (1 << 31))
          ..add(
            String.fromCharCodes([
              for (var k = 0; k < r.nextInt(8); k++) r.nextInt(0x2FFF),
            ]),
          );
      }
      for (final v in values) {
        final encoded = encodeStoredValue(v);
        final back = decodeStoredValue(encoded);
        if (v is List<int>) {
          expect(back, isA<List<int>>());
          expect(back, v);
          expect(encoded, startsWith('{"blob":'));
        } else {
          expect(back.runtimeType, v.runtimeType, reason: encoded);
          expect(back, v, reason: encoded);
          if (v is double) expect((back! as double).isNegative, v.isNegative);
        }
      }
      expect(decodeStoredValue(encodeStoredValue(double.nan)), isNaN);
    });

    test('INTEGER 7 and REAL 7.0 stay distinct after a round trip', () {
      expect(decodeStoredValue('7'), isA<int>());
      expect(decodeStoredValue('7.0'), isA<double>());
      expect(decodeStoredValue('1e+21'), isA<double>());
    });

    test('non-storage values are refused', () {
      for (final bad in <Object>[
        true,
        {'a': 1},
        [256],
        [-1],
        #sym,
      ]) {
        expect(
          () => encodeStoredValue(bad),
          throwsArgumentError,
          reason: '$bad',
        );
      }
    });

    test('only canonical encodings decode (encode(decode(x)) == x)', () {
      for (final bad in [
        '-0',
        '1E3',
        '1e3',
        '7.50',
        ' 7 ',
        '7 ',
        '07',
        '9223372036854775808',
        '1e400',
        '7.',
        r'"\u0041"',
        '{"blob":"AP8"}',
        '{"blob":"AP8=" }',
        '{ "real":"NaN"}',
      ]) {
        expect(
          () => decodeStoredValue(bad),
          throwsFormatException,
          reason: bad,
        );
      }
      for (final good in [
        'null',
        '0',
        '-0.0',
        '7',
        '7.0',
        '1e+21',
        '1e-7',
        '5e-324',
        '9223372036854775807',
        '-9223372036854775808',
        r'"\ud800"',
        '{"blob":"AP8="}',
        '{"blob":""}',
        '{"real":"NaN"}',
      ]) {
        expect(encodeStoredValue(decodeStoredValue(good)), good, reason: good);
      }
      expect(decodeStoredValue('{"real":"NaN"}'), isNaN);
    });

    test('text outside the contract does not decode', () {
      for (final bad in [
        '',
        'nul',
        '[1]',
        '{}',
        '{"real":"Inf"}',
        '{"blob":1}',
        '{"blob":"!!"}',
        '{"blob":"AA==","x":1}',
        'true',
      ]) {
        expect(
          () => decodeStoredValue(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('a stored row encodes column by column, in order', () {
      expect(
        encodeStoredRow({'exertion_scale': 'borg', 'exertion_value': 5.0}),
        '{"exertion_scale":"borg","exertion_value":5.0}',
      );
      expect(
        encodeStoredRow({'b': null, 'a': 'null', 'c': 3}),
        '{"b":null,"a":"null","c":3}',
      );
      expect(
        jsonDecode(
          encodeStoredRow({
            'x': 1.5,
            'y': [1, 2],
          }),
        ),
        {
          'x': 1.5,
          'y': {'blob': 'AQI='},
        },
      );
    });
  });

  group('SHA-256', () {
    test('FIPS 180-4 examples', () {
      expect(
        sha256Hex(utf8.encode('')),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        sha256Hex(
          utf8.encode(
            'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
          ),
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
      expect(
        sha256Hex(List<int>.filled(1000000, 0x61)),
        'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
      );
    });

    test('equals the frozen test helper on varied lengths', () {
      final r = Random(3);
      for (var n = 0; n < 200; n++) {
        final data = [for (var i = 0; i < n * 3; i++) r.nextInt(256)];
        expect(sha256Hex(data), frozen_digest.sha256Hex(data));
      }
    });

    test('refuses non-bytes', () {
      expect(() => sha256Hex([256]), throwsArgumentError);
    });
  });

  group('event ids (R-07)', () {
    String id({
      String runId = 'run-1',
      String table = 'exercises',
      String recordId = 'ex-1',
      String field = 'equipment_json',
      int? position = 2,
      String rule = 'IC-307',
    }) => migrationEventId(
      runId: runId,
      table: table,
      recordId: recordId,
      field: field,
      position: position,
      rule: rule,
    );

    test('derivation is SHA-256 of the canonical JSON tuple', () {
      expect(
        id(),
        sha256Hex(
          utf8.encode(
            '["repforge.migrationEvent/1","run-1","exercises","ex-1",'
            '"equipment_json",2,"IC-307"]',
          ),
        ),
      );
      expect(
        id(position: null),
        sha256Hex(
          utf8.encode(
            '["repforge.migrationEvent/1","run-1","exercises","ex-1",'
            '"equipment_json",null,"IC-307"]',
          ),
        ),
      );
      expect(id(), matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('pinned value (a change breaks history merges)', () {
      expect(
        id(),
        sha256Hex(
          utf8.encode(
            jsonEncode([
              migrationEventIdScheme,
              'run-1',
              'exercises',
              'ex-1',
              'equipment_json',
              2,
              'IC-307',
            ]),
          ),
        ),
      );
      expect(migrationEventIdScheme, 'repforge.migrationEvent/1');
    });

    test('deterministic: the same tuple gives the same id every time', () {
      expect(id(), id());
      final a = [for (var i = 0; i < 50; i++) id(recordId: 'ex-$i')];
      final b = [for (var i = 0; i < 50; i++) id(recordId: 'ex-$i')];
      expect(a, b);
    });

    test('each component changes the id', () {
      final ids = {
        id(),
        id(runId: 'run-2'),
        id(table: 'session_sets'),
        id(recordId: 'ex-2'),
        id(field: 'primary_muscle'),
        id(position: 3),
        id(position: null),
        id(position: 0),
        id(rule: 'WP8-D3'),
      };
      expect(ids, hasLength(9));
    });

    test('no separator ambiguity between components', () {
      expect(
        id(table: 'a', recordId: 'b|c'),
        isNot(id(table: 'a|b', recordId: 'c')),
      );
      expect(
        id(table: 'a","b', recordId: 'c'),
        isNot(id(table: 'a', recordId: 'b","c')),
      );
      expect(id(position: 1, rule: '2'), isNot(id(position: 12, rule: '')));
    });

    test('a resumed run (same run id) reproduces every event id; a new '
        'attempt (new run id) gets new ones', () {
      final rows = [
        const LegacyExerciseRow(
          id: 'ex-a',
          type: 'weighted',
          category: 'push',
          aliasesJson: '[]',
          primaryMuscle: 'Neck',
          secondaryMusclesJson: '["chest","chest","fullBody"]',
          equipmentJson: '["barbell","barbell","hoverboard",1]',
          supplied: 0,
        ),
        const LegacyExerciseRow(
          id: 'ex-b',
          type: 'Aerobic',
          category: 'push',
          aliasesJson: 'oops',
          primaryMuscle: 'chest',
          secondaryMusclesJson: 'oops',
          equipmentJson: 'oops',
          supplied: 1,
        ),
      ];
      List<String> idsOf(String runId) {
        final b = MigrationReportBuilder(run(runId));
        for (final row in rows) {
          final m = mapLegacyExercise(row);
          b.examine(
            table: 'exercises',
            recordId: row.id,
            cleanOutcome: ReportCategory.migrated,
            events: m.events,
          );
        }
        final s = classifyLegacyExertion(
          setId: 'set-1',
          scale: 'borg',
          value: 5.0,
        );
        b.examine(
          table: 'session_sets',
          recordId: 'set-1',
          cleanOutcome: ReportCategory.preserved,
          events: s.events,
        );
        return [for (final e in b.build().entries) e.eventId];
      }

      final first = idsOf('run-1');
      expect(first.toSet(), hasLength(first.length), reason: 'unique');
      expect(idsOf('run-1'), first);
      expect(idsOf('run-2').toSet().intersection(first.toSet()), isEmpty);
      expect(
        () => migrationEventId(
          runId: '',
          table: 't',
          recordId: 'r',
          field: 'f',
          position: null,
          rule: 'x',
        ),
        throwsArgumentError,
      );
    });
  });

  group('events and entries', () {
    test('an event validates its contract', () {
      expect(() => ev(table: ''), throwsArgumentError);
      expect(() => ev(rule: ''), throwsArgumentError);
      expect(() => ev(position: -1), throwsArgumentError);
      expect(
        () => ReportEvent(
          table: 't',
          recordId: 'r',
          field: 'f',
          originalValue: 'not encoded',
          action: ReportAction.skipped,
          rule: 'x',
          category: ReportCategory.migrated,
          reason: 'r',
        ),
        throwsFormatException,
      );
      expect(
        () => ReportEvent(
          table: 't',
          recordId: 'r',
          field: 'f',
          originalValue: 'null',
          action: ReportAction.skipped,
          rule: 'x',
          category: ReportCategory.migrated,
          reason: '  ',
        ),
        throwsArgumentError,
      );
      // blocked <=> blockReason, and blocked is rejectedOrBlocked.
      expect(
        () => ev(
          action: ReportAction.blocked,
          category: ReportCategory.rejectedOrBlocked,
        ),
        throwsArgumentError,
      );
      expect(
        () => ev(blockReason: BlockReason.unknownEquipment),
        throwsArgumentError,
      );
      expect(
        () => ev(
          action: ReportAction.blocked,
          blockReason: BlockReason.unknownEquipment,
        ),
        throwsArgumentError,
      );
      expect(
        ev(
          action: ReportAction.blocked,
          category: ReportCategory.rejectedOrBlocked,
          blockReason: BlockReason.unknownEquipment,
        ).blockReason,
        BlockReason.unknownEquipment,
      );
    });

    test('equality and entry id', () {
      expect(ev(), ev());
      expect(ev().hashCode, ev().hashCode);
      expect(ev(), isNot(ev(position: 1)));
      final e = ReportEntry('run-1', ev(position: 2));
      expect(
        e.eventId,
        migrationEventId(
          runId: 'run-1',
          table: 'exercises',
          recordId: 'ex-1',
          field: 'equipment_json',
          position: 2,
          rule: 'IC-307',
        ),
      );
      expect(e, ReportEntry('run-1', ev(position: 2)));
    });

    test('a migration run names both schema versions', () {
      expect(
        () => ReportRun(
          runId: 'r',
          trigger: ReportTrigger.migration,
          generatedAt: DateTime.utc(2026),
          appVersion: 'x',
        ),
        throwsArgumentError,
      );
      expect(
        ReportRun(
          runId: 'r',
          trigger: ReportTrigger.restore,
          generatedAt: DateTime.utc(2026),
          appVersion: 'x',
        ).fromSchemaVersion,
        isNull,
      );
      expect(
        () => ReportRun(
          runId: '',
          trigger: ReportTrigger.restore,
          generatedAt: DateTime.utc(2026),
          appVersion: 'x',
        ),
        throwsArgumentError,
      );
    });
  });

  group('record outcome (R-04)', () {
    test('precedence: rejectedOrBlocked, then quarantined, else clean', () {
      final skip = ev();
      final warn = ev(
        position: 1,
        action: ReportAction.retained,
        rule: 'ADR-0010',
        category: ReportCategory.warningForReview,
      );
      final quarantine = ev(
        position: 3,
        action: ReportAction.quarantined,
        category: ReportCategory.quarantinedOrUnresolved,
      );
      final block = ev(
        action: ReportAction.blocked,
        category: ReportCategory.rejectedOrBlocked,
        blockReason: BlockReason.unknownEquipment,
      );
      ReportCategory o(
        List<ReportEvent> e, [
        ReportCategory clean = ReportCategory.migrated,
      ]) => recordOutcome(e, cleanOutcome: clean);
      expect(o([]), ReportCategory.migrated);
      expect(o([], ReportCategory.preserved), ReportCategory.preserved);
      expect(o([skip, warn]), ReportCategory.migrated);
      expect(o([warn], ReportCategory.preserved), ReportCategory.preserved);
      expect(o([skip, quarantine]), ReportCategory.quarantinedOrUnresolved);
      expect(o([quarantine, block, warn]), ReportCategory.rejectedOrBlocked);
      expect(o([block, quarantine]), ReportCategory.rejectedOrBlocked);
      expect(() => o([], ReportCategory.warningForReview), throwsArgumentError);
      expect(
        () => o([], ReportCategory.rejectedOrBlocked),
        throwsArgumentError,
      );
    });
  });

  group('builder and reconciliation', () {
    MigrationReport sample() {
      final b = MigrationReportBuilder(run())
        // clean
        ..examine(
          table: 'exercises',
          recordId: 'ex-clean',
          cleanOutcome: ReportCategory.migrated,
        )
        // skipped only: migrated with an entry
        ..examine(
          table: 'exercises',
          recordId: 'ex-skip',
          cleanOutcome: ReportCategory.migrated,
          events: [ev(recordId: 'ex-skip', position: 1)],
        )
        // warning only
        ..examine(
          table: 'exercises',
          recordId: 'ex-warn',
          cleanOutcome: ReportCategory.migrated,
          events: [
            ev(
              recordId: 'ex-warn',
              field: 'secondary_muscles_json',
              position: 0,
              action: ReportAction.retained,
              rule: 'ADR-0010',
              category: ReportCategory.warningForReview,
            ),
          ],
        )
        // quarantined (since the unreadable-data decision an unmapped
        // secondary also blocks, so the quarantine-only record is built by
        // hand here)
        ..examine(
          table: 'exercises',
          recordId: 'ex-q',
          cleanOutcome: ReportCategory.migrated,
          events: [
            ev(
              recordId: 'ex-q',
              field: 'secondary_muscles_json',
              position: 0,
              action: ReportAction.quarantined,
              rule: 'IC-301',
              category: ReportCategory.quarantinedOrUnresolved,
              original: '["traps","fullBody"]',
            ),
            ev(
              recordId: 'ex-q',
              field: 'secondary_muscles_json',
              position: 1,
              action: ReportAction.retained,
              rule: 'ADR-0010',
              category: ReportCategory.warningForReview,
              original: '["traps","fullBody"]',
            ),
          ],
        )
        // blocked twice over, with a warning
        ..examine(
          table: 'exercises',
          recordId: 'ex-b',
          cleanOutcome: ReportCategory.migrated,
          events: mapLegacyExercise(
            const LegacyExerciseRow(
              id: 'ex-b',
              type: 'weighted',
              category: 'push',
              aliasesJson: '[]',
              primaryMuscle: '',
              secondaryMusclesJson: '["fullBody"]',
              equipmentJson: '["hoverboard"]',
              supplied: 1,
            ),
          ).events,
        )
        // rejected
        ..examine(
          table: 'exercises',
          recordId: 'ex-r',
          cleanOutcome: ReportCategory.migrated,
          events: [
            ev(
              recordId: 'ex-r',
              field: 'name',
              action: ReportAction.rejected,
              rule: 'IC-201',
              category: ReportCategory.rejectedOrBlocked,
              original: '',
            ),
          ],
        );
      for (var i = 0; i < 5; i++) {
        final c = classifyLegacyExertion(
          setId: 'set-$i',
          scale: i.isEven ? 'rpe' : 'borg',
          value: 8.0,
        );
        b.examine(
          table: 'session_sets',
          recordId: 'set-$i',
          cleanOutcome: ReportCategory.preserved,
          events: c.events,
        );
      }
      return b.build();
    }

    test('counts per table and outcome reconcile to the records examined', () {
      final r = sample();
      final ex = r.counts['exercises']!;
      expect(ex.examined, 6);
      expect(
        (ex.migrated, ex.preserved, ex.quarantinedOrUnresolved),
        (3, 0, 1),
      );
      expect((ex.rejectedOrBlocked, ex.blocked, ex.rejected), (2, 1, 1));
      expect(ex.warningEntries, 3, reason: 'ex-warn, ex-q and ex-b');
      expect(ex.recordsWithWarnings, 3);
      expect(ex.outcomeTotal, ex.examined);
      final sets = r.counts['session_sets']!;
      expect(sets.examined, 5);
      expect((sets.preserved, sets.quarantinedOrUnresolved), (3, 2));
      expect(sets.migrated, 0);
      expect(r.examined, 11);
      expect(r.counts.keys, ['exercises', 'session_sets']);
      final result = reconcileReport(
        r,
        examinedByTable: {'exercises': 6, 'session_sets': 5},
      );
      expect(result.problems, isEmpty);
      expect(result.reconciles, isTrue);
      expect('$result', 'reconciles');
    });

    test('disposition breakdown per table: blocked, quarantined and '
        'rejected stated separately (Review A M1)', () {
      final r = sample();
      final ex = r.counts['exercises']!;
      // ex-skip 1 skipped; ex-warn 1 retained; ex-q: traps quarantined,
      // fullBody retained; ex-b: primary quarantined + blocked, fullBody
      // retained, hoverboard quarantined + blocked; ex-r rejected.
      expect(ex.entriesByAction, {
        ReportAction.quarantined: 3,
        ReportAction.retained: 3,
        ReportAction.skipped: 1,
        ReportAction.rejected: 1,
        ReportAction.blocked: 2,
      });
      expect(ex.entriesByAction.keys.toList(), [
        ReportAction.quarantined,
        ReportAction.retained,
        ReportAction.skipped,
        ReportAction.rejected,
        ReportAction.blocked,
      ], reason: 'ReportAction order');
      expect(ex.entries(ReportAction.cleared), 0);
      final sets = r.counts['session_sets']!;
      expect(sets.entriesByAction, {ReportAction.cleared: 4});
      // Record counts stay separate from entry counts.
      expect((ex.blocked, ex.rejected, ex.quarantinedOrUnresolved), (1, 1, 1));
      expect('$ex', contains('blocked 2'));
    });

    test('a disposition or rejected count that disagrees with the entries '
        'does not reconcile', () {
      final r = sample();
      final ex = r.counts['exercises']!;
      TableCounts with_({
        Map<ReportAction, int>? actions,
        int? blocked,
        int? rejected,
      }) => TableCounts(
        table: ex.table,
        examined: ex.examined,
        migrated: ex.migrated,
        preserved: ex.preserved,
        quarantinedOrUnresolved: ex.quarantinedOrUnresolved,
        rejectedOrBlocked: ex.rejectedOrBlocked,
        blocked: blocked ?? ex.blocked,
        rejected: rejected ?? ex.rejected,
        warningEntries: ex.warningEntries,
        recordsWithWarnings: ex.recordsWithWarnings,
        entriesByAction: actions ?? ex.entriesByAction,
      );
      MigrationReport withCounts(TableCounts c) => MigrationReport.restored(
        run: r.run,
        entries: r.entries,
        counts: {...r.counts, 'exercises': c},
        exceptionalOutcomes: r.exceptionalOutcomes,
        cleanOutcomes: r.cleanOutcomes,
      );
      expect(reconcileReport(withCounts(with_())).reconciles, isTrue);
      final moreBlocked = {...ex.entriesByAction, ReportAction.blocked: 3};
      expect(
        reconcileReport(withCounts(with_(actions: moreBlocked))).problems,
        ['exercises: blocked count 3 but 2 entries'],
      );
      final swapped = reconcileReport(
        withCounts(with_(blocked: 2, rejected: 0)),
      ).problems;
      expect(swapped, [
        contains('rejected 0 but 1 records'),
        contains('blocked 2 but 1 records'),
      ]);
    });

    test('totals by category, action and rule head the report', () {
      final r = sample();
      expect(r.entriesByCategory[ReportCategory.warningForReview], 3);
      expect(r.entriesByAction[ReportAction.cleared], 4);
      expect(r.entriesByAction[ReportAction.blocked], 2);
      expect(r.entriesByRule['TRN-020'], 4);
      expect(
        r.entriesByCategory.values.fold(0, (a, b) => a + b),
        r.entries.length,
      );
    });

    test('entries are in deterministic order with unique ids', () {
      final r = sample();
      final sorted = r.entries.toList()
        ..sort((a, b) => ReportEvent.compare(a.event, b.event));
      expect(r.entries, sorted);
      expect(
        r.entries.map((e) => e.eventId).toSet(),
        hasLength(r.entries.length),
      );
      expect(
        [for (final e in sample().entries) e.eventId],
        [for (final e in r.entries) e.eventId],
      );
    });

    test('clean records appear only in the counts', () {
      final r = sample();
      expect(r.entries.where((e) => e.event.recordId == 'ex-clean'), isEmpty);
      expect(
        r.exceptionalOutcomes['exercises']!.containsKey('ex-clean'),
        isFalse,
      );
      expect(r.exceptionalOutcomes['session_sets']!.keys, ['set-1', 'set-3']);
    });

    test('an independent input count that differs does not reconcile', () {
      final r = sample();
      expect(
        reconcileReport(
          r,
          examinedByTable: {'exercises': 7, 'session_sets': 5},
        ).reconciles,
        isFalse,
      );
      expect(
        reconcileReport(r, examinedByTable: {'exercises': 6}).problems.single,
        contains('session_sets'),
      );
      expect(
        reconcileReport(
          r,
          examinedByTable: {'exercises': 6, 'session_sets': 5, 'plans': 0},
        ).problems.single,
        contains('plans'),
      );
    });

    test('a refused examine leaves the builder unchanged (review WS4 L7)', () {
      final b = MigrationReportBuilder(run());
      // Duplicate event ids: refused before anything is recorded.
      expect(
        () => b.examine(
          table: 'exercises',
          recordId: 'ex-1',
          cleanOutcome: ReportCategory.migrated,
          events: [ev(), ev()],
        ),
        throwsStateError,
      );
      // A foreign event: refused, and the table's clean outcome is not fixed.
      expect(
        () => b.examine(
          table: 'session_sets',
          recordId: 'set-1',
          cleanOutcome: ReportCategory.migrated,
          events: [ev(recordId: 'other')],
        ),
        throwsArgumentError,
      );
      // The same record and a different clean outcome are accepted now.
      b
        ..examine(
          table: 'exercises',
          recordId: 'ex-1',
          cleanOutcome: ReportCategory.migrated,
          events: [ev()],
        )
        ..examine(
          table: 'session_sets',
          recordId: 'set-1',
          cleanOutcome: ReportCategory.preserved,
        );
      final r = b.build();
      expect(r.entries, hasLength(1));
      expect(r.counts['exercises']!.examined, 1);
      expect(r.counts['session_sets']!.preserved, 1);
      expect(reconcileReport(r).problems, isEmpty);
    });

    test('the builder refuses double counting and foreign events', () {
      final b = MigrationReportBuilder(run())
        ..examine(
          table: 'exercises',
          recordId: 'ex-1',
          cleanOutcome: ReportCategory.migrated,
        );
      expect(
        () => b.examine(
          table: 'exercises',
          recordId: 'ex-1',
          cleanOutcome: ReportCategory.migrated,
        ),
        throwsStateError,
      );
      expect(
        () => b.examine(
          table: 'exercises',
          recordId: 'ex-2',
          cleanOutcome: ReportCategory.preserved,
        ),
        throwsStateError,
        reason: 'one clean outcome per table',
      );
      expect(
        () => b.examine(
          table: 'exercises',
          recordId: 'ex-3',
          cleanOutcome: ReportCategory.migrated,
          events: [ev(recordId: 'ex-4')],
        ),
        throwsArgumentError,
      );
      expect(
        () => b.examine(
          table: 'exercises',
          recordId: 'ex-5',
          cleanOutcome: ReportCategory.migrated,
          events: [
            ev(recordId: 'ex-5'),
            ev(recordId: 'ex-5'),
          ],
        ),
        throwsStateError,
        reason: 'duplicate event id',
      );
    });

    test('large run: 100 000 sets reconcile against an independent count', () {
      final r = Random(20261106);
      const legacy = <(Object?, Object?)>[
        ('rpe', 0.0),
        ('rpe', 0.5),
        ('rpe', 7.3),
        ('rpe', 9.75),
        ('rir', 6.0),
        ('rir', 7.5),
        ('rir', 2.5),
        ('rir', 0.5),
        ('borg', 5.0),
        (null, 6.0),
        ('rir', null),
        ('rpe', null),
      ];
      final b = MigrationReportBuilder(run());
      var invalid = 0;
      var clearedColumns = 0;
      for (var n = 0; n < 100000; n++) {
        final x = r.nextInt(1000);
        Object? scale;
        Object? value;
        if (x < 450) {
          // not recorded
        } else if (x < 780) {
          scale = 'rpe';
          value = 1 + r.nextInt(19) * 0.5;
        } else if (x < 980) {
          scale = 'rir';
          value = r.nextInt(6).toDouble();
        } else {
          (scale, value) = legacy[x % legacy.length];
          invalid++;
          clearedColumns += (scale == null ? 0 : 1) + (value == null ? 0 : 1);
        }
        final c = classifyLegacyExertion(
          setId: 'set-$n',
          scale: scale,
          value: value,
        );
        b.examine(
          table: 'session_sets',
          recordId: 'set-$n',
          cleanOutcome: ReportCategory.preserved,
          events: c.events,
        );
      }
      final report = b.build();
      final c = report.counts['session_sets']!;
      expect(c.quarantinedOrUnresolved, invalid);
      expect(c.preserved, 100000 - invalid);
      expect(report.entries, hasLength(clearedColumns));
      expect(
        reconcileReport(
          report,
          examinedByTable: {'session_sets': 100000},
        ).problems,
        isEmpty,
      );
    });
  });

  group('action and category (review WS4 M3)', () {
    test('only the documented pairs are accepted', () {
      const allowed = <ReportAction, Set<ReportCategory>>{
        ReportAction.quarantined: {ReportCategory.quarantinedOrUnresolved},
        ReportAction.cleared: {ReportCategory.quarantinedOrUnresolved},
        ReportAction.rejected: {ReportCategory.rejectedOrBlocked},
        ReportAction.blocked: {ReportCategory.rejectedOrBlocked},
        ReportAction.skipped: {
          ReportCategory.migrated,
          ReportCategory.preserved,
        },
        ReportAction.mapped: {
          ReportCategory.migrated,
          ReportCategory.preserved,
        },
        ReportAction.retained: {
          ReportCategory.warningForReview,
          ReportCategory.migrated,
          ReportCategory.preserved,
        },
        ReportAction.markerAdded: {
          ReportCategory.warningForReview,
          ReportCategory.migrated,
          ReportCategory.preserved,
        },
        ReportAction.none: {
          ReportCategory.warningForReview,
          ReportCategory.quarantinedOrUnresolved,
        },
        // C-1: a user correction converts the field; never a warning, a
        // quarantine or a block.
        ReportAction.corrected: {
          ReportCategory.migrated,
          ReportCategory.preserved,
        },
      };
      expect(allowed.keys.toSet(), ReportAction.values.toSet());
      for (final action in ReportAction.values) {
        expect(ReportEvent.allowedCategories(action), allowed[action]);
        for (final category in ReportCategory.values) {
          ReportEvent make() => ev(
            action: action,
            category: category,
            blockReason: action == ReportAction.blocked
                ? BlockReason.noPrimaryTarget
                : null,
          );
          if (allowed[action]!.contains(category)) {
            expect(make, returnsNormally, reason: '$action $category');
          } else {
            expect(make, throwsArgumentError, reason: '$action $category');
          }
        }
      }
    });
  });

  group('reconciliation structure (review WS4 M1, L1, L2)', () {
    MigrationReport sample() {
      final b = MigrationReportBuilder(run())
        ..examine(
          table: 'exercises',
          recordId: 'e1',
          cleanOutcome: ReportCategory.migrated,
          events: [
            ev(
              recordId: 'e1',
              field: 'secondary_muscles_json',
              position: 0,
              action: ReportAction.quarantined,
              rule: 'IC-301',
              category: ReportCategory.quarantinedOrUnresolved,
              original: '["traps"]',
            ),
          ],
        )
        ..examine(
          table: 'exercises',
          recordId: 'e2',
          cleanOutcome: ReportCategory.migrated,
        );
      return b.build();
    }

    TableCounts counts(String table) => TableCounts(
      table: table,
      examined: 2,
      migrated: 1,
      preserved: 0,
      quarantinedOrUnresolved: 1,
      rejectedOrBlocked: 0,
      blocked: 0,
      rejected: 0,
      warningEntries: 0,
      recordsWithWarnings: 0,
      entriesByAction: const {ReportAction.quarantined: 1},
    );

    test('a counts key that is not its table fails', () {
      final r = sample();
      expect(reconcileReport(r).reconciles, isTrue);
      final forged = MigrationReport.restored(
        run: r.run,
        entries: r.entries,
        counts: {'exercises': counts('other')},
        exceptionalOutcomes: r.exceptionalOutcomes,
        cleanOutcomes: r.cleanOutcomes,
      );
      expect(
        reconcileReport(forged, examinedByTable: {'exercises': 2}).problems,
        ['counts key exercises holds the counts of table other'],
      );
    });

    test('a missing clean outcome is a problem, not a type error', () {
      final r = sample();
      final forged = MigrationReport.restored(
        run: r.run,
        entries: r.entries,
        counts: r.counts,
        exceptionalOutcomes: r.exceptionalOutcomes,
        cleanOutcomes: const {},
      );
      expect(
        reconcileReport(forged).problems,
        contains('exercises: no clean outcome recorded'),
      );
      final wrongKind = MigrationReport.restored(
        run: r.run,
        entries: r.entries,
        counts: r.counts,
        exceptionalOutcomes: r.exceptionalOutcomes,
        cleanOutcomes: const {'exercises': ReportCategory.warningForReview},
      );
      expect(
        reconcileReport(wrongKind).problems.join(),
        contains('is not migrated or preserved'),
      );
    });

    test('clean or exceptional outcomes of an uncounted table fail', () {
      final r = sample();
      final ghost = MigrationReport.restored(
        run: r.run,
        entries: r.entries,
        counts: r.counts,
        exceptionalOutcomes: {
          ...r.exceptionalOutcomes,
          'ghost': const {'g1': ReportCategory.rejectedOrBlocked},
        },
        cleanOutcomes: {
          ...r.cleanOutcomes,
          'phantom': ReportCategory.preserved,
        },
      );
      expect(reconcileReport(ghost).problems, [
        'clean outcome for table phantom, which has no counts',
        'exceptional outcomes for table ghost, which has no counts',
      ]);
    });

    test('affected records found independently must equal the report '
        '(review WS4 M2; section 4.4)', () {
      final r = sample();
      final affected = {
        'exercises': {
          ReportCategory.quarantinedOrUnresolved: {'e1'},
          ReportCategory.rejectedOrBlocked: <String>{},
          ReportCategory.warningForReview: <String>{},
        },
      };
      expect(reconcileReport(r, affectedByTable: affected).problems, isEmpty);
      // Entries dropped and the record recounted as migrated: the counts
      // still add up, but the independent input catches it.
      final dropped = MigrationReport.restored(
        run: r.run,
        entries: const [],
        counts: {
          'exercises': TableCounts(
            table: 'exercises',
            examined: 2,
            migrated: 2,
            preserved: 0,
            quarantinedOrUnresolved: 0,
            rejectedOrBlocked: 0,
            blocked: 0,
            rejected: 0,
            warningEntries: 0,
            recordsWithWarnings: 0,
          ),
        },
        exceptionalOutcomes: const {},
        cleanOutcomes: const {'exercises': ReportCategory.migrated},
      );
      expect(
        reconcileReport(dropped, examinedByTable: {'exercises': 2}).reconciles,
        isTrue,
        reason: 'counts alone cannot see dropped rows',
      );
      expect(
        reconcileReport(
          dropped,
          examinedByTable: {'exercises': 2},
          affectedByTable: affected,
        ).problems.single,
        'exercises: quarantinedOrUnresolved records differ from the '
        'independent input (missing e1; unexpected )',
      );
      expect(
        reconcileReport(
          r,
          affectedByTable: {
            'sets': {ReportCategory.quarantinedOrUnresolved: <String>{}},
          },
        ).problems,
        ['affected records given for table sets, which has no counts'],
      );
    });
  });

  group('reconciliation detects tampering', () {
    test('a stored event id that does not match its fields fails (L3)', () {
      final b = MigrationReportBuilder(run())
        ..examine(
          table: 'exercises',
          recordId: 'ex-1',
          cleanOutcome: ReportCategory.migrated,
          events: [ev()],
        );
      final good = b.build();
      final entry = good.entries.single;
      expect(entry.eventIdMatches, isTrue);
      final stored = ReportEntry.stored(
        runId: entry.runId,
        eventId: entry.eventId,
        event: entry.event,
      );
      expect(stored, entry);
      expect(
        reconcileReport(_Forged(good, entries: [stored]).report).reconciles,
        isTrue,
      );
      final tampered = ReportEntry.stored(
        runId: entry.runId,
        eventId: '0' * 64,
        event: entry.event,
      );
      expect(tampered.eventIdMatches, isFalse);
      expect(
        reconcileReport(_Forged(good, entries: [tampered]).report).problems,
        ['event id ${'0' * 64} does not match its fields'],
      );
    });

    // Rebuilds a report through the builder with one inconsistency, using
    // the public surface only: entries are re-wrapped from another run, or
    // counts disagree with the input.
    test('an entry from another run, a forged id or a duplicate id fails', () {
      final b = MigrationReportBuilder(run())
        ..examine(
          table: 'exercises',
          recordId: 'ex-1',
          cleanOutcome: ReportCategory.migrated,
          events: [ev()],
        );
      final good = b.build();
      expect(reconcileReport(good).reconciles, isTrue);

      final forged = _Forged(good, entries: [ReportEntry('run-other', ev())]);
      expect(
        reconcileReport(forged.report).problems.join(),
        contains('belongs to run run-other'),
      );

      final dup = _Forged(
        good,
        entries: [good.entries.single, good.entries.single],
      );
      expect(
        reconcileReport(dup.report).problems.join(),
        contains('appears twice'),
      );

      final orphan = _Forged(
        good,
        entries: [
          ...good.entries,
          ReportEntry('run-1', ev(recordId: 'ex-unknown')),
        ],
      );
      expect(
        reconcileReport(orphan.report).problems.join(),
        contains('ex-unknown has entries but no counted outcome'),
      );

      final missing = _Forged(good, entries: const []);
      expect(
        reconcileReport(missing.report).problems.join(),
        contains('has an exceptional outcome but no entry'),
      );
    });

    test('an outcome that disagrees with its entries fails', () {
      final b = MigrationReportBuilder(run())
        ..examine(
          table: 'exercises',
          recordId: 'ex-1',
          cleanOutcome: ReportCategory.migrated,
          events: [ev()],
        );
      final good = b.build();
      final blockedEntry = ReportEntry(
        'run-1',
        ev(
          action: ReportAction.blocked,
          category: ReportCategory.rejectedOrBlocked,
          blockReason: BlockReason.unknownEquipment,
        ),
      );
      final wrong = _Forged(good, entries: [blockedEntry]);
      final problems = reconcileReport(wrong.report).problems.join('\n');
      expect(problems, contains('entries say rejectedOrBlocked'));
      expect(problems, contains('blocked count 0 but 1 entries'));
    });
  });

  group('report history merge (D04 restore conflicts; R-08)', () {
    final provenance = ReportProvenance(
      origin: ReportOrigin.backup,
      appVersion: '0.8.0',
      mergedAt: DateTime.utc(2026, 11, 7),
    );

    test(
      'repeated merges never duplicate; conflicts keep the existing row',
      () {
        final a = ReportEntry('run-1', ev(position: 1));
        final b = ReportEntry('run-1', ev(position: 2));
        final first = planReportMerge(
          existing: const {},
          incoming: [a, b, a],
          provenance: provenance,
        );
        expect(first.toInsert, [a, b]);
        expect(first.alreadyPresent, [a]);
        expect(first.conflicting, isEmpty);
        expect(first.provenance, provenance);

        final existing = {for (final e in first.toInsert) e.eventId: e};
        final again = planReportMerge(
          existing: existing,
          incoming: [a, b],
          provenance: provenance,
        );
        expect(again.toInsert, isEmpty);
        expect(again.alreadyPresent, [a, b]);

        // Same tuple (same id), different content.
        final changed = ReportEntry(
          'run-1',
          ReportEvent(
            table: 'exercises',
            recordId: 'ex-1',
            field: 'equipment_json',
            position: 1,
            originalValue: '"other"',
            action: ReportAction.skipped,
            rule: 'IC-307',
            category: ReportCategory.migrated,
            reason: 'Different.',
          ),
        );
        expect(changed.eventId, a.eventId);
        final conflict = planReportMerge(
          existing: existing,
          incoming: [changed],
          provenance: provenance,
        );
        expect(conflict.conflicting, [changed]);
        expect(conflict.toInsert, isEmpty);
      },
    );

    test('provenance is structured and comparable', () {
      expect(
        provenance,
        ReportProvenance(
          origin: ReportOrigin.backup,
          appVersion: '0.8.0',
          mergedAt: DateTime.utc(2026, 11, 7),
        ),
      );
      expect(
        [for (final o in ReportOrigin.values) o.name],
        ['device', 'backup'],
      );
    });
  });
}

/// A report with replaced entries and the base report's counts: what a
/// tampered or inconsistent stored report looks like.
final class _Forged {
  _Forged(MigrationReport base, {required List<ReportEntry> entries})
    : report = MigrationReport.restored(
        run: base.run,
        entries: entries,
        counts: base.counts,
        exceptionalOutcomes: base.exceptionalOutcomes,
        cleanOutcomes: base.cleanOutcomes,
      );

  final MigrationReport report;
}
