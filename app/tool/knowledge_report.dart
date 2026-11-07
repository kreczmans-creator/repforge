// Exercise knowledge completeness report (WP 8 exercise knowledge system):
// reads the latest catalogue release and the approved reference files,
// applies the knowledge checks, computes the completeness matrix and writes
// the Markdown report. Deterministic: no network, no randomness, no clock
// (the snapshot date is an argument).
//
// Usage (from app/):
//   dart run tool/knowledge_report.dart --date 2026-11-07
//     [--release assets/catalogue/releases/repforge-release-3.json]
//     [--out ../docs/catalogue/content-completeness-<date>.md]
//
// Exit code: 0 written, 1 knowledge errors, 2 usage or I/O problem.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge_source.dart';
import 'package:repforge/domain/exercise_knowledge/knowledge_completeness.dart';

const String defaultRelease =
    'assets/catalogue/releases/repforge-release-3.json';

const Map<ReleaseReferenceName, String> referenceFiles = {
  ReleaseReferenceName.anatomy: 'assets/catalogue/reference/anatomy.json',
  ReleaseReferenceName.movementPatterns:
      'assets/catalogue/reference/movement-patterns.json',
  ReleaseReferenceName.equipment: 'assets/catalogue/reference/equipment.json',
};

/// Editor notes carried into the report (section 5).
const List<String> editorNotes = [
  'IC-708: 85 instruction items are near-identical across related exercises '
      '(for example curl and row cues). Keep, vary or merge them; the pairs are '
      'listed in the catalogue gate report for release 3.',
  'Illustrations are two-dimensional side views with fixed segment lengths. '
      'Arms that move sideways in reality (push-up bottom, pull-up top, bar '
      'grip in the back squat) look shorter and more folded than in life; '
      'confirm each figure against the steps and captions.',
  'Tempo lines are qualitative (no counts). Check that each of the 60 is '
      'meaningful for its exercise and remove any that are not.',
  'Common mistakes are stored as "Fault. Fix." and shown split at the first '
      'sentence; keep the fault to one sentence.',
  'Assisted machines differ: the exit steps for the assisted dip and pull-up '
      'describe a counterweight machine. Check them against the machines in '
      'use.',
  'lib-run-400m and lib-outdoor-run are not linked (owner decision KS-D7).',
  'Muscles on the detail screen come from the stored v7 record; the release '
      '2 targets in this report can differ until stage 3d (KS-D8).',
];

/// Builds the report text, or the failure message.
Result<String> buildKnowledgeReport({
  required List<int> releaseBytes,
  required Map<ReleaseReferenceName, List<int>> reference,
  required String date,
  required String releaseFile,
}) {
  final loaded = loadKnowledgeCatalogue(
    KnowledgeBundle(release: releaseBytes, reference: reference),
  );
  return switch (loaded) {
    Ok(:final value) => Ok(
      renderCompletenessReport(
        KnowledgeMatrix(value.all),
        snapshotDate: date,
        releaseFile: releaseFile,
        contentHash: value.contentHash ?? '',
        editorNotes: editorNotes,
      ),
    ),
    Err(:final error) => Err(error),
  };
}

Future<void> main(List<String> args) async {
  String? date;
  var release = defaultRelease;
  String? out;
  for (var i = 0; i < args.length; i++) {
    final hasValue = i + 1 < args.length;
    switch (args[i]) {
      case '--date' when hasValue:
        date = args[++i];
      case '--release' when hasValue:
        release = args[++i];
      case '--out' when hasValue:
        out = args[++i];
      default:
        stderr.writeln('Unknown or incomplete argument: ${args[i]}');
        exitCode = 2;
        return;
    }
  }
  if (date == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    stderr.writeln('--date YYYY-MM-DD is required.');
    exitCode = 2;
    return;
  }
  out ??= '../docs/catalogue/content-completeness-$date.md';
  final List<int> bytes;
  final reference = <ReleaseReferenceName, List<int>>{};
  try {
    bytes = File(release).readAsBytesSync();
    for (final MapEntry(:key, :value) in referenceFiles.entries) {
      reference[key] = File(value).readAsBytesSync();
    }
  } on FileSystemException catch (e) {
    stderr.writeln('Cannot read ${e.path}: ${e.message}');
    exitCode = 2;
    return;
  }
  final report = buildKnowledgeReport(
    releaseBytes: bytes,
    reference: reference,
    date: date,
    releaseFile: 'app/$release',
  );
  switch (report) {
    case Ok(:final value):
      File(out).writeAsStringSync(value);
      print('knowledge report written to $out');
    case Err(:final error):
      stderr.writeln(error.message);
      exitCode = 1;
  }
}
