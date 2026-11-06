// Coverage gate: fails when line coverage of hand-written code is below the
// threshold. Generated code is excluded (owner decision at WP 3 acceptance,
// 2026-11-04; engineering standards §7). The threshold is not lowered without
// an ADR and owner approval.
//
// Usage: dart run tool/coverage_gate.dart [lcov path] [--min 80]
// ignore_for_file: avoid_print
import 'dart:io';

/// Source paths excluded from the hand-written coverage figure.
const generatedPatterns = [
  r'\.g\.dart$',
  r'\.freezed\.dart$',
  'generated_migrations/',
];

/// Line coverage summary for an lcov report.
class CoverageSummary {
  const CoverageSummary({required this.linesFound, required this.linesHit});

  final int linesFound;
  final int linesHit;

  double get percent => linesFound == 0 ? 0 : 100 * linesHit / linesFound;
}

/// Parses [lcov] and sums LF/LH over records whose source path matches none
/// of [excludePatterns].
CoverageSummary summarise(
  String lcov, {
  List<String> excludePatterns = generatedPatterns,
}) {
  final excludes = excludePatterns.map(RegExp.new).toList();
  var found = 0;
  var hit = 0;
  for (final record in lcov.split('end_of_record')) {
    final source = RegExp(r'^SF:(.*)$', multiLine: true).firstMatch(record);
    if (source == null) continue;
    final path = source.group(1)!.trim();
    if (excludes.any((e) => e.hasMatch(path))) continue;
    found += _intAfter(record, 'LF');
    hit += _intAfter(record, 'LH');
  }
  return CoverageSummary(linesFound: found, linesHit: hit);
}

int _intAfter(String record, String key) {
  final match = RegExp('^$key:(\\d+)\$', multiLine: true).firstMatch(record);
  return match == null ? 0 : int.parse(match.group(1)!);
}

void main(List<String> args) {
  var path = 'coverage/lcov.info';
  var minimum = 80.0;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--min' && i + 1 < args.length) {
      minimum = double.parse(args[++i]);
    } else {
      path = args[i];
    }
  }
  final file = File(path);
  if (!file.existsSync()) {
    print('coverage gate: $path not found');
    exitCode = 2;
    return;
  }
  final summary = summarise(file.readAsStringSync());
  final pct = summary.percent.toStringAsFixed(1);
  print(
    'coverage gate: hand-written lines ${summary.linesHit}/'
    '${summary.linesFound} = $pct % (minimum $minimum %)',
  );
  if (summary.percent < minimum) {
    print('coverage gate: FAILED');
    exitCode = 1;
  }
}
