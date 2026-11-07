import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/finding.dart';

import '../../tool/catalogue_gate.dart';
import '../domain/library/release/support/release_support.dart';

const String _catalogue = 'assets/catalogue';
const String _gapsPath = '../docs/catalogue/accepted-gaps.json';

Map<String, List<int>> _assets() => {
  for (final f in Directory(_catalogue).listSync(recursive: true))
    if (f is File) f.path.substring(_catalogue.length + 1): f.readAsBytesSync(),
};

Map<String, List<int>> _docs() => {
  for (final f in Directory(referenceDir).listSync())
    if (f is File && f.path.endsWith('.json'))
      f.uri.pathSegments.last: f.readAsBytesSync(),
};

String _gaps() => File(_gapsPath).readAsStringSync();

GateResult _run({
  Map<String, List<int>>? assets,
  String? gaps,
  Map<String, List<int>>? docs,
  bool noGaps = false,
}) => runCatalogueGate(
  assets: assets ?? _assets(),
  acceptedGapsText: noGaps ? null : (gaps ?? _gaps()),
  docsReference: docs ?? _docs(),
);

List<String> _codes(GateResult r) => [for (final f in r.gateFindings) f.code];

Map<String, List<int>> _withRelease(
  String name,
  Map<String, Object?> release, [
  Map<String, List<int>>? base,
]) => {...(base ?? _assets()), 'releases/$name': bytesOf(release)};

void main() {
  group('the shipped catalogue', () {
    test('passes with zero errors', () {
      final r = _run();
      expect(r.passed, isTrue);
      expect(r.errors, 0);
      expect(r.gateFindings, isEmpty);
      expect(r.releases, hasLength(1));
      final release = r.releases.single;
      expect(release.file, 'releases/repforge-release-2.json');
      expect(release.provider, 'repforge');
      expect(release.release, 2);
      expect(release.report!.exerciseCount, 89);
      expect(release.report!.passed, isTrue);
      expect(release.contentHash, hasLength(64));
    });

    test('the accepted-gaps file clears exactly the dispositions it lists', () {
      final report = _run().releases.single.report!;
      final withDisposition = {
        for (final f in report.findings)
          if (f.disposition != null) f.disposition,
      };
      expect(withDisposition, {
        'accepted (AG-0001)',
        'accepted (AG-0002)',
        'accepted (AG-0003)',
        'accepted (AG-0004)',
        'distinct (AG-0005)',
        'distinct (AG-0006)',
      });
      // No stale entry and no error is silenced.
      expect(report.findingsFor('ED-901'), isEmpty);
      expect(report.errors, 0);
    });

    test('the accepted-gaps entries are documented dispositions only', () {
      final gaps = jsonDecode(_gaps())! as Map<String, Object?>;
      expect(gaps['schema'], 'repforge.acceptedGaps/1');
      final entries = (gaps['accepted']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(entries, hasLength(6));
      for (final e in entries) {
        expect(e['reason'], isA<String>());
        expect((e['reason']! as String).isNotEmpty, isTrue);
        expect(e['reference'], contains('quality-and-duplicates.md'));
        expect(e['kind'], isNot('coverageGap'), reason: 'owner only');
      }
    });

    test('reports are deterministic and carry no timestamp', () {
      final a = _run();
      final b = _run();
      expect(a.toJsonString(), b.toJsonString());
      expect(a.toMarkdown(), b.toMarkdown());
      expect(
        a.releases.single.report!.toJsonString(),
        b.releases.single.report!.toJsonString(),
      );
      final json = jsonDecode(a.toJsonString())! as Map<String, Object?>;
      expect(json['schema'], gateSchema);
      expect(json['passed'], isTrue);
      expect(a.toJsonString(), isNot(contains('2026-')), reason: 'no date');
      final release =
          (json['releases']! as List<Object?>).single! as Map<String, Object?>;
      expect(release['coverage'], {
        'slotRequired': 325,
        'slotFilled': 67,
        'setRequired': 70,
        'setFilled': 20,
        'openGaps': 341,
      });
      expect(release['integrityReport'], 'integrity-repforge-release-2.json');
    });

    test('the Markdown report states the result and the hash', () {
      final md = _run().toMarkdown();
      expect(md, contains('Result: **passed**'));
      expect(md, contains('releases/repforge-release-2.json'));
      expect(md, contains('Coverage: slots 67 of 325'));
    });
  });

  group('gate failures', () {
    test('a missing or broken accepted-gaps file (GATE-001)', () {
      var r = _run(noGaps: true);
      expect(_codes(r), ['GATE-001']);
      expect(r.passed, isFalse);

      r = _run(gaps: 'not json');
      expect(_codes(r), ['GATE-001']);
      expect(r.passed, isFalse);

      r = _run(gaps: '{"schema": "other", "accepted": []}');
      expect(_codes(r), ['GATE-001']);

      r = _run(
        gaps: jsonEncode({
          'schema': 'repforge.acceptedGaps/1',
          'accepted': [
            {
              'id': 'AG-9',
              'kind': 'coverageGap',
              'group': 'neck',
              'dimension': 'slot',
              'item': 'x',
              'reason': 'r',
              'acceptedBy': 'someone',
            },
          ],
        }),
      );
      expect(_codes(r), ['GATE-001'], reason: 'coverage gaps are owner only');
    });

    test('an asset copy that differs from the approved file (GATE-002)', () {
      final assets = _assets();
      final changed = [...assets['reference/equipment.json']!, 32];
      assets['reference/equipment.json'] = changed;
      final r = _run(assets: assets);
      expect(_codes(r), contains('GATE-002'));
      expect(r.passed, isFalse);
      // The release also fails: its declared hash no longer matches.
      expect(r.releases.single.findings.map((f) => f.code), contains('RF-008'));
    });

    test('a file missing from the assets or from the docs (GATE-002)', () {
      final assets = _assets()..remove('reference/ledger.json');
      expect(_codes(_run(assets: assets)), contains('GATE-002'));
      final docs = _docs()..remove('coverage.json');
      expect(_codes(_run(docs: docs)), ['GATE-002']);
    });

    test('no release file (GATE-004)', () {
      final assets = _assets()
        ..removeWhere((k, _) => k.startsWith('releases/'));
      final r = _run(assets: assets);
      expect(_codes(r), ['GATE-004']);
      expect(r.passed, isFalse);
    });

    test('a file name that does not match its content (GATE-003)', () {
      final assets = _assets();
      assets['releases/other-release-9.json'] = assets.remove(
        'releases/repforge-release-2.json',
      )!;
      final r = _run(assets: assets);
      expect(
        r.releases.single.findings.map((f) => f.code),
        contains('GATE-003'),
      );
      expect(r.passed, isFalse);
    });

    test('two files for the same release (GATE-005)', () {
      final assets = _assets();
      assets['releases/repforge-release-2.copy.json'] =
          assets['releases/repforge-release-2.json']!;
      final r = _run(assets: assets);
      expect(r.passed, isFalse);
      final codes = [
        for (final x in r.releases) ...x.findings.map((f) => f.code),
      ];
      expect(codes, containsAll(['GATE-003', 'GATE-005']));
    });

    test('an unparseable release fails the gate', () {
      final assets = _assets();
      assets['releases/repforge-release-3.json'] = utf8.encode('{');
      final r = _run(assets: assets);
      expect(r.passed, isFalse);
      expect(r.releases.first.provider, isNull);
      expect(r.releases.first.findings.single.code, 'RF-001');
      // The good release is still evaluated and reported.
      expect(r.releases.last.passed, isTrue);
    });

    test('an integrity error in a release fails the gate and is reported', () {
      final map = release2Map();
      (exercisesOf(map)[3]['targets']! as List<Object?>).add({
        'node': 'noSuchNode',
        'role': 'secondary',
      });
      final r = _run(assets: _withRelease('repforge-release-2.json', map));
      expect(r.passed, isFalse);
      expect(r.errors, greaterThan(0));
      final json = jsonDecode(r.toJsonString())! as Map<String, Object?>;
      final release =
          (json['releases']! as List<Object?>).single! as Map<String, Object?>;
      expect(release['passed'], isFalse);
      expect(
        (release['errorFindings']! as List<Object?>).length,
        greaterThan(0),
      );
      expect(r.toMarkdown(), contains('FAILED'));
    });

    test('an unlisted warning does not fail the gate; an error is never '
        'silenced by an entry', () {
      final r = _run(
        gaps: '{"schema": "repforge.acceptedGaps/1", "accepted": []}',
      );
      expect(r.passed, isTrue);
      expect(r.warnings, 116);
      expect(
        r.releases.single.report!.findings.where((f) => f.disposition != null),
        isEmpty,
      );
    });

    test('a stale accepted-gaps entry is information, not a failure', () {
      final gaps = jsonDecode(_gaps())! as Map<String, Object?>;
      (gaps['accepted']! as List<Object?>).add({
        'id': 'AG-0099',
        'kind': 'warning',
        'code': 'IC-311',
        'exerciseId': 'lib-back-squat',
        'reason': 'Matches nothing.',
        'acceptedBy': 'test',
      });
      final r = _run(gaps: jsonEncode(gaps));
      expect(r.passed, isTrue);
      final stale = r.releases.single.report!.findingsFor('ED-901');
      expect(stale, hasLength(1));
      expect(stale.single.severity, Severity.info);
    });
  });

  group('several releases of one provider', () {
    test('the next release is checked against the previous one', () {
      final next = release2Map()..['release'] = 3;
      var r = _run(assets: _withRelease('repforge-release-3.json', next));
      expect(r.passed, isTrue, reason: r.toMarkdown());
      expect(r.releases.map((x) => x.release), [2, 3]);

      // Release 3 drops an id without retiring it (IC-110).
      final omitting = release2Map()..['release'] = 3;
      final ex = exercisesOf(omitting)..removeLast();
      omitting['exercises'] = ex;
      r = _run(assets: _withRelease('repforge-release-3.json', omitting));
      expect(r.passed, isFalse);
      expect(r.releases.first.passed, isTrue);
      expect(r.releases.last.findings.map((f) => f.code), contains('IC-110'));

      // Retiring it makes the release valid.
      final retired = release2Map()..['release'] = 3;
      final last = exercisesOf(retired).removeLast();
      retired['retirements'] = [
        {'id': last['id'], 'reason': 'Merged.'},
      ];
      r = _run(assets: _withRelease('repforge-release-3.json', retired));
      expect(r.passed, isTrue, reason: r.toMarkdown());
    });

    test(
      'files are evaluated in release order whatever their names sort as',
      () {
        final next = release2Map()..['release'] = 10;
        final r = _run(assets: _withRelease('repforge-release-10.json', next));
        expect(r.releases.map((x) => x.release), [2, 10]);
      },
    );
  });

  test('the command writes the JSON and Markdown reports', () async {
    final out = Directory.systemTemp.createTempSync('catalogue_gate_');
    addTearDown(() => out.deleteSync(recursive: true));
    ProcessResult result;
    try {
      result = await Process.run('dart', [
        'run',
        'tool/catalogue_gate.dart',
        '--out',
        out.path,
      ]);
    } on ProcessException {
      markTestSkipped('dart is not on the PATH');
      return;
    }
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('passed'));
    final names = out.listSync().map((e) => e.uri.pathSegments.last).toSet();
    expect(
      names,
      containsAll([
        'catalogue-gate.json',
        'catalogue-gate.md',
        'integrity-repforge-release-2.json',
        'integrity-repforge-release-2.md',
      ]),
    );
    final json =
        jsonDecode(File('${out.path}/catalogue-gate.json').readAsStringSync())!
            as Map<String, Object?>;
    expect(json['passed'], isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the command fails on an unknown argument', () async {
    ProcessResult result;
    try {
      result = await Process.run('dart', [
        'run',
        'tool/catalogue_gate.dart',
        '--nope',
      ]);
    } on ProcessException {
      markTestSkipped('dart is not on the PATH');
      return;
    }
    expect(result.exitCode, 2);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
