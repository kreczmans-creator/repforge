import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../harness_v7_db.dart';
import '../migration_digest.dart';

/// Expectations against the frozen v7 evidence, shared by the WS5 recovery
/// tests (kill, failure injection, repeated migration). They read
/// `expected_v7_digests.json` (3b-1) and `v7_strict_schema_3b3.json` (3b-3)
/// and never write them.

Map<String, Object?>? _expected;
Map<String, Object?>? _strict;

/// The stored production v1..v7 → v7 result of fixture [key] (3b-1).
Map<String, Object?> expectedV7Result(String key) {
  final all = _expected ??=
      (jsonDecode(File(expectedDigestsPath).readAsStringSync())
              as Map<String, Object?>)['fixtures']!
          as Map<String, Object?>;
  return all[key]! as Map<String, Object?>;
}

/// The strict parts of the frozen production v7 schema record of [key] (a
/// fixture key or `fresh`; 3b-3).
List<Map<String, Object?>> frozenStrictRecord(String key) {
  final file = _strict ??= jsonDecode(
    File(strictSchemaPath).readAsStringSync(),
  ) as Map<String, Object?>;
  final entry = key == 'fresh'
      ? file['fresh']
      : (file['fixtures']! as Map<String, Object?>)[key];
  return strictOnly(entry! as List<Object?>);
}

/// Version of a fixture key (`v5_orphans` → 5).
int fixtureVersionOf(String key) =>
    int.parse(key.substring(1).split('_').first);

/// What "the same database state" means for a `describeFile` result:
/// version, schema (3b-1 and strict) and every table's row digest.
String stateKeyOf(Map<String, Object?> described) => jsonEncode({
  'userVersion': described['userVersion'],
  'schema': described['schema'],
  'strictSchema': described['strictSchema'],
  'tables': described['tables'],
});

/// Same comparison as the 3b-3 differential test (a): [got] (a
/// `describeFile` result) equals the stored production result of [key],
/// and its strict schema equals the frozen strict record.
void expectV7ProductionResult(Map<String, Object?> got, String key) {
  final want = expectedV7Result(key);
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
  expect(
    jsonEncode(strictOnly(got['strictRecord']! as List<Object?>)),
    jsonEncode(frozenStrictRecord(key)),
    reason: 'strict schema record',
  );
}

/// The reference state of a copy of fixture [path] after the chain ran up
/// to each version from the fixture's own up to [target]: version to
/// [stateKeyOf].
Future<Map<int, String>> referenceStates(
  String path, {
  required int from,
  int target = 7,
}) async {
  final out = <int, String>{};
  for (var v = from; v <= target; v++) {
    out[v] = await withFixtureCopy(path, (copy) async {
      if (v > from) {
        final error = await openWithChain(copy, targetVersion: v);
        if (error != null) throw StateError('reference v$v: $error');
      }
      return stateKeyOf(describeFile(copy));
    });
  }
  return out;
}

/// Directory for WS5 reports (`REPFORGE_WS5_REPORT_DIR`, else
/// `build/migration_v8_ws5` under `app/`, which git ignores).
Directory ws5ReportDir() {
  final env = Platform.environment['REPFORGE_WS5_REPORT_DIR'];
  final dir = Directory(
    env != null && env.isNotEmpty ? env : 'build/migration_v8_ws5',
  );
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

/// Writes [report] as `<name>.json` into [ws5ReportDir] and returns the file.
File writeWs5Report(String name, Object? report) {
  final f = File('${ws5ReportDir().path}/$name.json')
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  return f;
}
