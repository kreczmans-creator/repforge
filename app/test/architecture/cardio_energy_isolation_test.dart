import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source files under `lib/` whose path does not start with one of
/// [allowed] and whose text matches [pattern].
List<String> _offenders(RegExp pattern, List<String> allowed) {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  expect(files, isNotEmpty, reason: 'the guard must scan real files');
  return [
    for (final f in files)
      if (!allowed.any((dir) => f.path.startsWith(dir)) &&
          pattern.hasMatch(f.readAsStringSync()))
        f.path,
  ];
}

void main() {
  /// TRN-007(2): cardio energy expended is a training record only and never
  /// feeds the nutrition balance, the dashboard or planning. Only training
  /// code and the data layer may mention the set fields.
  test('cardio energy stays in training code (TRN-007(2))', () {
    expect(
      _offenders(RegExp('energyKcal|energyProvenance'), [
        'lib/domain/training/',
        'lib/features/training/',
        'lib/data/',
      ]),
      isEmpty,
    );
  });

  /// TRN-002(2): typed loads go through the strict `LoadKg.of`. The lenient
  /// stored-value readers, which snap instead of rejecting, are for the data
  /// layer only.
  test('lenient LoadKg readers are used only by the data layer', () {
    expect(
      _offenders(RegExp(r'LoadKg\.(tryFromStored|fromStored)'), [
        'lib/data/',
        'lib/domain/units/units.dart',
      ]),
      isEmpty,
    );
  });

  /// BCM-001(1), BCM-002(1): typed body weight and lengths go through the
  /// strict `Kilograms.of` / `Centimetres.of` (reject, never round). The
  /// stored-value readers (same strict rule, no snapping) are for the data
  /// layer only.
  test('stored body-value readers are used only by the data layer', () {
    expect(
      _offenders(
        RegExp(r'(Kilograms|Centimetres)\.(tryFromStored|fromStored)'),
        [
          'lib/data/',
          'lib/domain/units/units.dart',
          'lib/domain/units/kilograms.dart',
        ],
      ),
      isEmpty,
    );
  });
}
