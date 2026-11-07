import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/release/release_format.dart';
import 'package:repforge/domain/library/release/release_parser.dart';

import 'support/release_support.dart';

List<String> _codes(ReleaseParseResult r) => [
  for (final f in r.findings) f.code,
];

ReleaseParseResult _parse(Map<String, Object?> map) =>
    parseReleaseBytes(bytesOf(map));

Map<String, Object?> _one() => subsetRelease(['lib-back-squat']);

Map<String, Object?> _ex(Map<String, Object?> release) =>
    exercisesOf(release).single;

void main() {
  group('a valid release', () {
    test('release 2 parses to 89 system exercises with release times', () {
      final r = parseReleaseBytes(release2Bytes());
      expect(r.findings, isEmpty);
      final doc = r.document!;
      expect(doc.exercises, hasLength(89));
      expect(doc.provider.id, ProviderId.repforge);
      expect(doc.release, const ReleaseId(ProviderId.repforge, 2));
      expect(doc.releasedOn, DateTime.utc(2026, 11, 7));
      expect(doc.retirements, isEmpty);
      expect(doc.content, isEmpty);
      expect(doc.reference.keys, ReleaseReferenceName.values);
      for (final e in doc.exercises) {
        expect(e.source, ExerciseSource.system);
        expect(e.providerId, ProviderId.repforge);
        expect(e.revision, 2);
        expect(e.createdAt, doc.releasedOn);
        expect(e.updatedAt, doc.releasedOn);
      }
    });

    test('target ordinals follow the array position; roles are kept', () {
      final doc = parseReleaseBytes(release2Bytes()).document!;
      final squat = doc.exercises.firstWhere(
        (e) => e.id.value == 'lib-back-squat',
      );
      expect([for (final t in squat.targets) t.ordinal], [0, 1, 2, 3]);
      expect(squat.primaryTargets.single.node.value, 'quadriceps');
      expect(squat.patterns.single.value, 'squat');
      expect(squat.names.name, 'Barbell back squat');
      expect(squat.aliases, ['Back squat', 'Squat']);
    });

    test('the equipment role override and its note survive', () {
      final doc = parseReleaseBytes(release2Bytes()).document!;
      final row = doc.exercises.firstWhere(
        (e) => e.id.value == 'lib-inverted-row',
      );
      final barbell = row.equipment.firstWhere(
        (e) => e.item.value == 'barbell',
      );
      expect(barbell.roleOverride, EquipmentRole.support);
      expect(barbell.overrideNote, isNotEmpty);
    });

    test('parsing text and decoded JSON gives the same document', () {
      final bytes = release2Bytes();
      final a = parseReleaseBytes(bytes).document!;
      final b = parseReleaseText(utf8.decode(bytes)).document!;
      final c = parseReleaseJson(jsonDecode(utf8.decode(bytes))).document!;
      expect(b, a);
      expect(c, a);
    });

    test('relationships, content, media, retirements and tranches parse', () {
      final map = subsetRelease(['lib-back-squat', 'lib-front-squat']);
      final ex = exercisesOf(map);
      ex[0]['relationships'] = [
        {'kind': 'progressionOf', 'to': 'lib-front-squat'},
        {'kind': 'alternativeTo', 'to': 'lib-front-squat'},
      ];
      ex[1]['relationships'] = [
        {'kind': 'unilateralCounterpartOf', 'to': 'lib-back-squat'},
      ];
      ex[0]['content'] = {
        'en-GB': {
          'setup': ['Set the bar on the rack.', 'Brace.'],
          'execution': ['Sit down between the hips.'],
        },
      };
      ex[0]['media'] = [
        {
          'id': 'm1',
          'kind': 'image',
          'locator': 'media/squat.png',
          'licence': 'proprietary (RepForge)',
          'attribution': 'RepForge',
        },
      ];
      map['retirements'] = [
        {'id': 'lib-gone', 'reason': 'Merged.', 'replacedBy': 'lib-back-squat'},
        {'id': 'lib-gone-too', 'reason': 'Dropped.'},
      ];
      map['tranches'] = {'5.1': 'inProgress'};
      final r = _parse(map);
      expect(r.findings, isEmpty);
      final doc = r.document!;
      expect(doc.relationships, hasLength(3));
      expect(
        doc.relationships.every((x) => x.source == ExerciseSource.system),
        isTrue,
      );
      // The symmetric pair is stored with the smaller id first.
      final symmetric = doc.relationships.firstWhere(
        (x) => x.kind == RelationshipKind.alternativeTo,
      );
      expect(symmetric.from.value, 'lib-back-squat');
      expect(doc.content, hasLength(3));
      expect(doc.content.first.ordinal, 0);
      expect(doc.content.first.revision, 2);
      expect(doc.content.first.providerId, ProviderId.repforge);
      expect(doc.media.single.exerciseId.value, 'lib-back-squat');
      expect(doc.retirements.map((x) => x.id.value), [
        'lib-gone',
        'lib-gone-too',
      ]);
      expect(doc.retirements.first.replacedBy?.value, 'lib-back-squat');
      expect(doc.tranches, {'5.1': 'inProgress'});
      expect(
        doc.relationshipsInvolving(const ExerciseId('lib-front-squat')),
        hasLength(3),
      );
    });
  });

  group('every malformed input is a finding, never an exception', () {
    test('bytes that are not UTF-8 (RF-001)', () {
      final r = parseReleaseBytes([0xff, 0xfe, 0x7b, 0x7d]);
      expect(_codes(r), ['RF-001']);
      expect(r.document, isNull);
      expect(r.contentHash, hasLength(64));
    });

    test('text that is not JSON (RF-001)', () {
      expect(_codes(parseReleaseBytes(utf8.encode('{"formatVersion": '))), [
        'RF-001',
      ]);
      expect(_codes(parseReleaseBytes(const [])), ['RF-001']);
    });

    test('roots that are not objects', () {
      for (final json in <Object?>[null, 5, 'x', <Object?>[], true]) {
        final r = parseReleaseJson(json);
        expect(r.document, isNull, reason: '$json');
        expect(_codes(r), ['RF-002'], reason: '$json');
      }
    });

    test('an empty object reports every missing part together', () {
      final r = parseReleaseJson(<String, Object?>{});
      expect(r.document, isNull);
      final fields = {for (final f in r.findings) f.field};
      expect(
        fields,
        containsAll([
          'formatVersion',
          'provider',
          'release',
          'releasedOn',
          'reference',
          'exercises',
          'retirements',
        ]),
      );
    });

    test('a wrong or missing format version (RF-003)', () {
      for (final v in <Object?>[1, 3, '2', null]) {
        final map = _one()..['formatVersion'] = v;
        expect(_codes(_parse(map)), contains('RF-003'), reason: '$v');
      }
      final map = _one()..remove('formatVersion');
      expect(_codes(_parse(map)), contains('RF-003'));
    });

    test('unknown keys at every level (RF-006)', () {
      final map = _one();
      map['extra'] = 1;
      (map['provider']! as Map<String, Object?>)['extra'] = 1;
      (map['reference']! as Map<String, Object?>)['extra'] = 1;
      _ex(map)['source'] = 'user'; // source is not a key: R-26
      _ex(map)['extra'] = 1;
      final r = _parse(map);
      expect(r.document, isNull);
      final unknown = r.findings.where((f) => f.code == 'RF-006').toList();
      expect(unknown, hasLength(5));
      expect(
        unknown.where((f) => f.subjectId == 'lib-back-squat'),
        hasLength(2),
      );
    });

    test('provider problems', () {
      final map = _one();
      map['provider'] = {'id': '', 'name': 'x', 'licence': 5};
      final r = _parse(map);
      final fields = {for (final f in r.findings) f.field};
      expect(
        fields,
        containsAll([
          'provider.id',
          'provider.licence',
          'provider.attribution',
        ]),
      );
    });

    test('release number and date', () {
      for (final n in <Object?>[0, -1, '2', 1.5, null]) {
        final r = _parse(_one()..['release'] = n);
        expect(r.document, isNull, reason: '$n');
      }
      for (final d in <Object?>[
        '2026-02-30',
        '2026-13-01',
        '07/11/2026',
        '2026-11-7',
        20261107,
        null,
      ]) {
        final r = _parse(_one()..['releasedOn'] = d);
        expect(r.document, isNull, reason: '$d');
        expect(r.findings.map((f) => f.field), contains('releasedOn'));
      }
    });

    test('reference sections: missing, wrong hash shape, wrong type', () {
      var map = _one();
      (map['reference']! as Map<String, Object?>).remove('ledger');
      expect(
        _parse(map).findings.map((f) => f.field),
        contains('reference.ledger'),
      );
      map = _one();
      ((map['reference']! as Map<String, Object?>)['anatomy']!
              as Map<String, Object?>)['sha256'] =
          'ABC';
      expect(
        _parse(map).findings.map((f) => f.field),
        contains('reference.anatomy.sha256'),
      );
      map = _one()..['reference'] = [];
      expect(_parse(map).document, isNull);
    });

    test('exercise fields: type, enum, names, targets, equipment', () {
      final cases = <String, void Function(Map<String, Object?>)>{
        'exercises[0].id': (e) => e.remove('id'),
        'exercises[0].revision': (e) => e['revision'] = '1',
        'exercises[0].loggingType': (e) => e['loggingType'] = 'weights',
        'exercises[0].category': (e) => e['category'] = null,
        'exercises[0].names.en-GB': (e) => e['names'] = {
          'fr-FR': {'name': 'Squat'},
        },
        'exercises[0].names.en-GB.name': (e) => e['names'] = {
          'en-GB': {'aliases': <Object?>[]},
        },
        'exercises[0].names.en-GB.aliases[0]': (e) => e['names'] = {
          'en-GB': {
            'name': 'Squat',
            'aliases': [3],
          },
        },
        'exercises[0].targets[0].role': (e) => e['targets'] = [
          {'node': 'quadriceps', 'role': 'main'},
        ],
        'exercises[0].targets[0].node': (e) => e['targets'] = [
          {'role': 'primary'},
        ],
        'exercises[0].patterns[0]': (e) => e['patterns'] = [''],
        'exercises[0].equipment[0].role': (e) => e['equipment'] = [
          {'item': 'barbell', 'role': 'cardio'},
        ],
        'exercises[0].equipment[0].item': (e) => e['equipment'] = [
          {'role': 'load'},
        ],
        'exercises[0].mechanics': (e) => e['mechanics'] = 'both',
        'exercises[0].laterality': (e) => e['laterality'] = 'left',
        'exercises[0].difficulty': (e) => e['difficulty'] = 3,
        'exercises[0].attributes.stance': (e) =>
            e['attributes'] = {'stance': ''},
        'exercises[0].attributes.pace': (e) =>
            e['attributes'] = {'pace': 'slow'},
        'exercises[0].provenance': (e) => e['provenance'] = 'RepForge',
        'exercises[0].targets': (e) => e['targets'] = 'quadriceps',
      };
      for (final entry in cases.entries) {
        final map = _one();
        entry.value(_ex(map));
        final r = _parse(map);
        expect(r.document, isNull, reason: entry.key);
        expect(
          r.findings.map((f) => f.field),
          contains(entry.key),
          reason: entry.key,
        );
        expect(r.findings.every((f) => f.severity == Severity.error), isTrue);
      }
    });

    test('optional classification keys may be null (the checks decide)', () {
      final map = _one();
      _ex(map)
        ..['mechanics'] = null
        ..['laterality'] = null
        ..['difficulty'] = null;
      final r = _parse(map);
      expect(r.findings, isEmpty);
      expect(r.document!.exercises.single.laterality, isNull);
    });

    test('relationship problems', () {
      var map = subsetRelease(['lib-back-squat', 'lib-front-squat']);
      exercisesOf(map)[0]['relationships'] = [
        {'kind': 'regressionOf', 'to': 'lib-front-squat'},
      ];
      var r = _parse(map);
      expect(
        r.findings.map((f) => f.field),
        contains('exercises[0].relationships[0].kind'),
      );

      map = subsetRelease(['lib-back-squat']);
      _ex(map)['relationships'] = [
        {'kind': 'variationOf', 'to': 'lib-back-squat'},
      ];
      r = _parse(map);
      expect(
        r.findings.map((f) => f.field),
        contains('exercises[0].relationships[0].to'),
      );

      map = subsetRelease(['lib-back-squat', 'lib-front-squat']);
      exercisesOf(map)[0]['relationships'] = [
        {'kind': 'alternativeTo', 'to': 'lib-front-squat'},
      ];
      exercisesOf(map)[1]['relationships'] = [
        {'kind': 'alternativeTo', 'to': 'lib-back-squat'},
      ];
      r = _parse(map);
      expect(_codes(r), ['RF-007']);
      expect(r.findings.single.subjectId, 'lib-front-squat');

      map = subsetRelease(['lib-back-squat'])
        ..['exercises'] = [
          (_ex(subsetRelease(['lib-back-squat'])))..['relationships'] = 5,
        ];
      expect(_parse(map).document, isNull);
    });

    test('content, media, retirements and tranche problems', () {
      var map = _one();
      _ex(map)['content'] = {
        'en-GB': {
          'setup': [1],
          'execution': 'text',
        },
        'fr-FR': 3,
      };
      var r = _parse(map);
      expect(
        r.findings.map((f) => f.field),
        containsAll([
          'exercises[0].content.en-GB.setup[0]',
          'exercises[0].content.en-GB.execution',
          'exercises[0].content.fr-FR',
        ]),
      );

      map = _one();
      _ex(map)['media'] = [
        {'id': 'm1', 'kind': 'image'},
      ];
      r = _parse(map);
      expect(
        r.findings.map((f) => f.field),
        containsAll([
          'exercises[0].media[0].locator',
          'exercises[0].media[0].licence',
          'exercises[0].media[0].attribution',
        ]),
      );

      map = _one()
        ..['retirements'] = [
          {'id': 'lib-x'},
          5,
        ];
      r = _parse(map);
      expect(
        r.findings.map((f) => f.field),
        containsAll(['retirements[0].reason', 'retirements[1]']),
      );

      map = _one()..['tranches'] = {'5.1': 'done'};
      expect(_parse(map).findings.map((f) => f.field), ['tranches.5.1']);
      map = _one()..remove('retirements');
      expect(_parse(map).findings.map((f) => f.field), ['retirements']);
    });

    test('findings are sorted and a parse is deterministic', () {
      final map = _one();
      _ex(map)
        ..['category'] = 'x'
        ..['mechanics'] = 'y'
        ..['extra'] = 1;
      final a = _parse(map).findings.map((f) => f.toString()).toList();
      final b = _parse(map).findings.map((f) => f.toString()).toList();
      expect(a, b);
      expect(a, [...a]..sort());
    });

    test(
      'replacing any top-level or exercise value with junk never throws',
      () {
        final junk = <Object?>[
          null,
          7,
          'x',
          true,
          <Object?>[],
          <String, Object?>{},
        ];
        final base = _one();
        void probe(Map<String, Object?> map) {
          final r = parseReleaseJson(map);
          expect(
            r.document == null,
            r.findings.any((f) => f.severity == Severity.error),
          );
        }

        for (final key in base.keys) {
          for (final j in junk) {
            probe({
              ...jsonDecode(jsonEncode(base)) as Map<String, Object?>,
              key: j,
            });
          }
        }
        final exerciseKeys = _ex(base).keys.toList();
        for (final key in exerciseKeys) {
          for (final j in junk) {
            final copy = jsonDecode(jsonEncode(base)) as Map<String, Object?>;
            _ex(copy)[key] = j;
            probe(copy);
          }
        }
      },
    );

    test('enum values outside the vocabulary carry the 3a codes (IC-202, '
        'IC-203, IC-308) and all problems are reported together', () {
      final map = _one();
      _ex(map)
        ..['loggingType'] = 'weights'
        ..['category'] = 'arms'
        ..['mechanics'] = 'both'
        ..['laterality'] = 'left'
        ..['difficulty'] = 'expert'
        ..['targets'] = [
          {'node': 'quadriceps', 'role': 'main'},
        ];
      final r = _parse(map);
      expect(r.document, isNull);
      expect(_codes(r), [
        'IC-202',
        'IC-203',
        'IC-308',
        'IC-308',
        'IC-308',
        'IC-308',
      ]);
      expect(r.findings.every((f) => f.subjectId == 'lib-back-squat'), isTrue);
    });

    test('formatVersion must be the integer 2', () {
      expect(
        _codes(
          parseReleaseText(
            jsonEncode(_one())
                .replaceFirst('"formatVersion":2', '"formatVersion":2.0'),
          ),
        ),
        ['RF-003'],
      );
    });

    test('an empty release, duplicate retirements, a role note without a '
        'role, unknown reference paths', () {
      var map = _one()..['exercises'] = <Object?>[];
      expect(_parse(map).findings.map((f) => f.field), ['exercises']);

      map = _one()
        ..['retirements'] = [
          {'id': 'lib-x', 'reason': 'a'},
          {'id': 'lib-x', 'reason': 'b'},
        ];
      expect(_codes(_parse(map)), ['RF-007']);

      map = _one();
      _ex(map)['equipment'] = [
        {'item': 'barbell', 'roleNote': 'note'},
      ];
      expect(_parse(map).findings.map((f) => f.field), [
        'exercises[0].equipment[0].roleNote',
      ]);

      for (final bad in ['../x.json', '/etc/x', 'a//b', r'a\b', '.', '']) {
        map = _one();
        ((map['reference']! as Map<String, Object?>)['ledger']!
                as Map<String, Object?>)['path'] =
            bad;
        expect(_parse(map).document, isNull, reason: bad);
      }
    });

    test('exercise problems are reported even when the provider is '
        'malformed', () {
      final map = _one()..['provider'] = 5;
      _ex(map)['category'] = 'x';
      final r = _parse(map);
      expect(_codes(r), containsAll(['RF-002', 'IC-203']));
    });
  });
}
