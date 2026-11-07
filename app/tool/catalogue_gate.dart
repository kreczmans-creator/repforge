// Catalogue integrity gate (WP 8 stage 3c, CI): parses and validates every
// release file under assets/catalogue/releases/ against the bundled approved
// reference data, runs the integrity checks and the coverage evaluation
// (`runIntegrityChecks` inside the release validator), applies
// docs/catalogue/accepted-gaps.json and fails on any error. Writes JSON and
// Markdown reports. Deterministic: no network, no randomness, no clock.
//
// Usage (from app/):
//   dart run tool/catalogue_gate.dart --out build/catalogue_gate
//     [--catalogue assets/catalogue]
//     [--docs ../docs/catalogue/reference]
//     [--accepted-gaps ../docs/catalogue/accepted-gaps.json]
//
// Exit code: 0 passed, 1 failed, 2 usage or I/O problem.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/accepted_gaps.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/integrity_report.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/release/release_format.dart';
import 'package:repforge/domain/library/release/release_one_baseline.dart';
import 'package:repforge/domain/library/release/release_parser.dart';
import 'package:repforge/domain/library/release/release_validator.dart';

const String gateSchema = 'repforge.catalogueGate/1';

Finding _gate(String code, String message, {String? subjectId}) => Finding(
  code: code,
  severity: Severity.error,
  message: message,
  subjectId: subjectId,
);

/// The outcome for one release file.
class GateRelease {
  GateRelease({
    required this.file,
    required this.parseFindings,
    this.provider,
    this.release,
    this.contentHash,
    this.validation,
  });

  /// Path relative to the catalogue root, for example
  /// `releases/repforge-release-2.json`.
  final String file;
  final String? provider;
  final int? release;
  final String? contentHash;

  /// Findings from reading the file (parse and name checks).
  final List<Finding> parseFindings;
  final ReleaseValidation? validation;

  List<Finding> get findings => validation?.findings ?? parseFindings;
  IntegrityReport? get report => validation?.report;

  int count(Severity s) => findings.where((f) => f.severity == s).length;
  bool get passed =>
      parseFindings.every((f) => f.severity != Severity.error) &&
      (validation?.isValid ?? false);

  /// File name of the per-release integrity report (without extension).
  String get reportName =>
      'integrity-${provider ?? 'unknown'}-release-${release ?? 0}';
}

/// The outcome of the gate.
class GateResult {
  GateResult({required this.gateFindings, required this.releases});

  /// Findings of the gate itself (`GATE-xxx`).
  final List<Finding> gateFindings;
  final List<GateRelease> releases;

  int _total(Severity s) =>
      gateFindings.where((f) => f.severity == s).length +
      releases.fold(0, (n, r) => n + r.count(s));

  int get errors => _total(Severity.error);
  int get warnings => _total(Severity.warning);
  int get infos => _total(Severity.info);

  bool get passed =>
      errors == 0 && releases.isNotEmpty && releases.every((r) => r.passed);

  Map<String, Object?> toJson() => {
    'schema': gateSchema,
    'passed': passed,
    'summary': {'errors': errors, 'warnings': warnings, 'infos': infos},
    'gateFindings': [for (final f in gateFindings) _findingJson(f)],
    'releases': [
      for (final r in releases)
        {
          'file': r.file,
          'provider': r.provider,
          'release': r.release,
          'contentHash': r.contentHash,
          'passed': r.passed,
          'errors': r.count(Severity.error),
          'warnings': r.count(Severity.warning),
          'infos': r.count(Severity.info),
          'exercises': r.report?.exerciseCount,
          'integrityReport': r.report == null ? null : '${r.reportName}.json',
          'coverage': _coverageJson(r.report),
          'errorFindings': [
            for (final f in r.findings)
              if (f.severity == Severity.error) _findingJson(f),
          ],
        },
    ],
  };

  String toJsonString() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# Catalogue integrity gate')
      ..writeln()
      ..writeln('Result: **${passed ? 'passed' : 'FAILED'}**.')
      ..writeln()
      ..writeln('| Errors | Warnings | Infos |')
      ..writeln('|---|---|---|')
      ..writeln('| $errors | $warnings | $infos |')
      ..writeln()
      ..writeln('## Gate findings');
    if (gateFindings.isEmpty) {
      b.writeln('None.');
    } else {
      for (final f in gateFindings) {
        b.writeln('- `${f.code}` ${f.subjectId ?? ''} ${f.message}');
      }
    }
    b
      ..writeln()
      ..writeln('## Releases');
    if (releases.isEmpty) b.writeln('None found.');
    for (final r in releases) {
      final report = r.report;
      b
        ..writeln()
        ..writeln('### ${r.file}')
        ..writeln()
        ..writeln(
          '- Provider ${r.provider ?? '-'}, release ${r.release ?? '-'}, '
          '${report?.exerciseCount ?? '-'} exercises.',
        )
        ..writeln(
          '- Content hash (sha256, lowercase hex): ${r.contentHash ?? '-'}.',
        )
        ..writeln(
          '- Result: ${r.passed ? 'passed' : 'FAILED'}; '
          '${r.count(Severity.error)} errors, '
          '${r.count(Severity.warning)} warnings, '
          '${r.count(Severity.info)} infos.',
        );
      final coverage = report?.coverage;
      if (coverage != null) {
        b.writeln(
          '- Coverage: slots ${coverage.slotFilled} of '
          '${coverage.slotRequired}; set entries ${coverage.setFilled} of '
          '${coverage.setRequired}; ${coverage.openGaps.length} open gap rows '
          '(information outside complete tranches).',
        );
      }
      if (report != null) {
        final byCode = report.countsByCode.entries
            .map((e) => '${e.key} ${e.value}')
            .join(', ');
        b
          ..writeln('- Findings by code: $byCode.')
          ..writeln(
            '- Full report: `${r.reportName}.md` and `${r.reportName}.json`.',
          );
      }
      final errorFindings = [
        for (final f in r.findings)
          if (f.severity == Severity.error) f,
      ];
      if (errorFindings.isNotEmpty) {
        b
          ..writeln()
          ..writeln('Errors:');
        for (final f in errorFindings) {
          b.writeln('- `${f.code}` `${f.subjectId ?? '-'}` ${f.message}');
        }
      }
    }
    return b.toString();
  }
}

Map<String, Object?> _findingJson(Finding f) => {
  'code': f.code,
  'severity': f.severity.name,
  'subjectId': f.subjectId,
  'field': f.field,
  'message': f.message,
  'disposition': f.disposition,
};

Map<String, Object?>? _coverageJson(IntegrityReport? report) {
  final c = report?.coverage;
  if (c == null) return null;
  return {
    'slotRequired': c.slotRequired,
    'slotFilled': c.slotFilled,
    'setRequired': c.setRequired,
    'setFilled': c.setFilled,
    'openGaps': c.openGaps.length,
  };
}

final RegExp _releaseName = RegExp(r'^releases/([^/]+)-release-(\d+)\.json$');

/// Runs the gate over [assets] (bytes keyed by path relative to the catalogue
/// root, for example `reference/anatomy.json` and
/// `releases/repforge-release-2.json`).
///
/// [docsReference] (bytes keyed by file name, optional) is the approved
/// `docs/catalogue/reference/` folder: when given, every asset copy must be
/// byte-identical to it. [acceptedGapsText] is the text of the accepted-gaps
/// file, or null when it does not exist (an error). [legacySeedText] is the
/// seed file (release 1) that release 2 is compared with.
GateResult runCatalogueGate({
  required Map<String, List<int>> assets,
  required String? acceptedGapsText,
  Map<String, List<int>>? docsReference,
  String? legacySeedText,
}) {
  final gateFindings = <Finding>[];

  var acceptedGaps = AcceptedGaps.none;
  if (acceptedGapsText == null) {
    gateFindings.add(
      _gate('GATE-001', 'docs/catalogue/accepted-gaps.json does not exist.'),
    );
  } else {
    try {
      final parsed = parseAcceptedGaps(jsonDecode(acceptedGapsText));
      switch (parsed) {
        case Ok(:final value):
          acceptedGaps = value;
        case Err(:final error):
          gateFindings.add(
            _gate(
              'GATE-001',
              'accepted-gaps.json is invalid: ${error.message}',
            ),
          );
      }
    } on FormatException catch (e) {
      gateFindings.add(
        _gate('GATE-001', 'accepted-gaps.json is not JSON: ${e.message}.'),
      );
    }
  }

  if (docsReference != null) {
    final names = {
      ...docsReference.keys,
      for (final k in assets.keys)
        if (k.startsWith('reference/')) k.substring('reference/'.length),
    }.toList()..sort();
    for (final name in names) {
      final doc = docsReference[name];
      final asset = assets['reference/$name'];
      if (doc == null || asset == null || !_sameBytes(doc, asset)) {
        gateFindings.add(
          _gate(
            'GATE-002',
            'reference/$name differs between docs/catalogue/reference and the '
                'bundled assets (${doc == null
                    ? 'missing in docs'
                    : asset == null
                    ? 'missing in assets'
                    : 'bytes differ'}).',
            subjectId: name,
          ),
        );
      }
    }
  }

  final releaseFiles = [
    for (final k in assets.keys)
      if (k.startsWith('releases/') && k.endsWith('.json')) k,
  ]..sort();
  if (releaseFiles.isEmpty) {
    gateFindings.add(_gate('GATE-004', 'No release file found.'));
  }

  // Parse every file first, then validate in (provider, release) order so the
  // previous release of a provider is available to the cross-release checks.
  final parsed =
      <({String file, ReleaseParseResult result})>[
        for (final f in releaseFiles)
          (file: f, result: parseReleaseBytes(assets[f]!)),
      ]..sort((a, b) {
        final da = a.result.document;
        final db = b.result.document;
        if (da == null || db == null) {
          return da == null && db == null
              ? a.file.compareTo(b.file)
              : (da == null ? -1 : 1);
        }
        final c = da.release.compareTo(db.release);
        return c != 0 ? c : a.file.compareTo(b.file);
      });

  final releases = <GateRelease>[];
  final seen = <ReleaseId>{};
  final lastByProvider = <ProviderId, ValidatedRelease>{};
  final retiredByProvider = <ProviderId, Set<ExerciseId>>{};
  for (final p in parsed) {
    final doc = p.result.document;
    if (doc == null) {
      releases.add(
        GateRelease(
          file: p.file,
          parseFindings: p.result.findings,
          contentHash: p.result.contentHash,
        ),
      );
      continue;
    }
    final fileFindings = <Finding>[];
    final match = _releaseName.firstMatch(p.file);
    if (match == null ||
        match.group(1) != doc.provider.id.value ||
        int.parse(match.group(2)!) != doc.release.number) {
      fileFindings.add(
        _gate(
          'GATE-003',
          '${p.file} does not match its content: the name must be '
              '<provider>-release-<n>.json for ${doc.provider.id} release '
              '${doc.release.number}.',
          subjectId: p.file,
        ),
      );
    }
    if (!seen.add(doc.release)) {
      fileFindings.add(
        _gate(
          'GATE-005',
          '${doc.release} appears in more than one file.',
          subjectId: p.file,
        ),
      );
    }
    final referenceBytes = <ReleaseReferenceName, List<int>>{};
    for (final name in ReleaseReferenceName.values) {
      final bytes = assets[doc.reference[name]!.path];
      if (bytes != null) referenceBytes[name] = bytes;
    }
    final loaded = loadApprovedReferenceSet(referenceBytes);
    final set = loaded.set;
    if (set == null) {
      releases.add(
        GateRelease(
          file: p.file,
          provider: doc.provider.id.value,
          release: doc.release.number,
          contentHash: p.result.contentHash,
          parseFindings: [...fileFindings, ...loaded.findings],
        ),
      );
      continue;
    }
    final earlier = lastByProvider[doc.provider.id];
    var previous = earlier == null ? null : previousCatalogueOf(earlier);
    // Release 1 of `repforge` is the seed as a migrated device holds it.
    if (previous == null &&
        doc.provider.id == ProviderId.repforge &&
        doc.release.number > 1) {
      final seed = legacySeedText;
      if (seed == null) {
        fileFindings.add(
          _gate(
            'GATE-006',
            'The seed file (release 1) is needed to check ${p.file} against '
                'the migrated catalogue (IC-104, IC-105, IC-110).',
            subjectId: p.file,
          ),
        );
      } else {
        final baseline = releaseOneBaseline(seed);
        previous = baseline.previous;
        fileFindings.addAll(baseline.findings);
      }
    }
    final validation = validateReleaseBytes(
      bytes: assets[p.file]!,
      reference: set,
      previous: previous,
      retiredExerciseLedger: retiredByProvider[doc.provider.id] ?? const {},
      acceptedGaps: acceptedGaps,
      options: const IntegrityOptions(includeCoverageFindings: true),
    );
    final validated = validation.release;
    if (validated != null) {
      lastByProvider[doc.provider.id] = validated;
    }
    retiredByProvider.putIfAbsent(doc.provider.id, () => {}).addAll([
      for (final r in doc.retirements) r.id,
    ]);
    releases.add(
      GateRelease(
        file: p.file,
        provider: doc.provider.id.value,
        release: doc.release.number,
        contentHash: p.result.contentHash,
        parseFindings: fileFindings,
        validation: ReleaseValidation(
          findings: sortedFindings([...fileFindings, ...validation.findings]),
          release: fileFindings.isEmpty ? validation.release : null,
          report: validation.report,
          contentHash: validation.contentHash,
        ),
      ),
    );
  }
  return GateResult(
    gateFindings: sortedFindings(gateFindings),
    releases: releases,
  );
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Map<String, List<int>> _readTree(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return {};
  return {
    for (final f in dir.listSync(recursive: true))
      if (f is File)
        f.path.substring(dir.path.length + 1).replaceAll(r'\', '/'): f
            .readAsBytesSync(),
  };
}

const String _noGaps = '{"schema": "repforge.acceptedGaps/1", "accepted": []}';

void main(List<String> args) {
  try {
    _run(args);
  } on FileSystemException catch (e) {
    print('catalogue gate: I/O problem: ${e.message} ${e.path ?? ''}');
    exitCode = 2;
  }
}

void _run(List<String> args) {
  var out = 'build/catalogue_gate';
  var catalogue = 'assets/catalogue';
  var docs = '../docs/catalogue/reference';
  var acceptedGapsPath = '../docs/catalogue/accepted-gaps.json';
  var seedPath = 'assets/seed/exercise_library.json';
  var skipDocs = false;
  for (var i = 0; i < args.length; i++) {
    final hasValue = i + 1 < args.length;
    switch (args[i]) {
      case '--out' when hasValue:
        out = args[++i];
      case '--catalogue' when hasValue:
        catalogue = args[++i];
      case '--docs' when hasValue:
        docs = args[++i];
      case '--accepted-gaps' when hasValue:
        acceptedGapsPath = args[++i];
      case '--seed' when hasValue:
        seedPath = args[++i];
      case '--skip-docs':
        skipDocs = true;
      default:
        print('catalogue gate: unknown or incomplete argument ${args[i]}');
        exitCode = 2;
        return;
    }
  }
  if (!Directory(catalogue).existsSync()) {
    print('catalogue gate: $catalogue not found');
    exitCode = 2;
    return;
  }
  final gapsFile = File(acceptedGapsPath);
  if (!skipDocs && (!Directory(docs).existsSync() || !gapsFile.existsSync())) {
    print(
      'catalogue gate: $docs or $acceptedGapsPath not found; pass --skip-docs '
      'to run without the docs equality check and the accepted-gaps file',
    );
    exitCode = 2;
    return;
  }
  final docsFiles = skipDocs
      ? null
      : {
          for (final e in _readTree(docs).entries)
            if (e.key.endsWith('.json')) e.key: e.value,
        };
  final seedFile = File(seedPath);
  final result = runCatalogueGate(
    assets: _readTree(catalogue),
    acceptedGapsText: gapsFile.existsSync()
        ? gapsFile.readAsStringSync()
        : (skipDocs ? _noGaps : null),
    docsReference: docsFiles,
    legacySeedText: seedFile.existsSync() ? seedFile.readAsStringSync() : null,
  );

  final dir = Directory(out)..createSync(recursive: true);
  File('${dir.path}/catalogue-gate.json')
      .writeAsStringSync(result.toJsonString());
  File('${dir.path}/catalogue-gate.md').writeAsStringSync(result.toMarkdown());
  for (final r in result.releases) {
    final report = r.report;
    if (report == null) continue;
    File('${dir.path}/${r.reportName}.json')
        .writeAsStringSync('${report.toJsonString()}\n');
    File('${dir.path}/${r.reportName}.md')
        .writeAsStringSync(report.toMarkdown());
  }
  print(
    'catalogue gate: ${result.releases.length} release(s), '
    '${result.errors} errors, ${result.warnings} warnings, '
    '${result.infos} infos -> ${result.passed ? 'passed' : 'FAILED'} '
    '(reports in ${dir.path})',
  );
  if (!result.passed) exitCode = 1;
}
