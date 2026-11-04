import 'package:flutter_test/flutter_test.dart';

import '../../tool/coverage_gate.dart';

const _lcov = '''
SF:lib/domain/units/units.dart
LF:10
LH:8
end_of_record
SF:lib/data/db/app_database.g.dart
LF:1000
LH:10
end_of_record
SF:lib/domain/foo.freezed.dart
LF:100
LH:0
end_of_record
SF:test/data/generated_migrations/schema_v1.dart
LF:50
LH:0
end_of_record
SF:lib/data/repositories/repo.dart
LF:10
LH:9
end_of_record
''';

void main() {
  test('excludes generated files from the hand-written figure', () {
    final s = summarise(_lcov);
    expect(s.linesFound, 20);
    expect(s.linesHit, 17);
    expect(s.percent, 85.0);
  });

  test('includes everything when no pattern is excluded', () {
    final s = summarise(_lcov, excludePatterns: const []);
    expect(s.linesFound, 1170);
    expect(s.linesHit, 27);
  });

  test('empty report is 0 %', () {
    expect(summarise('').percent, 0);
  });
}
