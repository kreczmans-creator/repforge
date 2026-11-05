import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ADR-0006 standing constraint, extended by ADR-0007: platform plugins are
/// imported only by the adapters in `lib/data/platform/`. Feature, domain and
/// app code reach them through Flutter-free interfaces.
void main() {
  List<String> importers(RegExp pattern) {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty, reason: 'the guard must scan real files');
    return [
      for (final f in files)
        if (pattern.hasMatch(f.readAsStringSync()))
          f.path.replaceAll(r'\', '/'),
    ];
  }

  test('only lib/data/platform imports flutter_local_notifications or '
      'timezone', () {
    final found = importers(
      RegExp(
        r'''import\s+['"]package:(flutter_local_notifications[a-z_]*|timezone)/''',
      ),
    );
    expect(found, isNotEmpty, reason: 'the adapter must be found');
    expect(found.where((p) => !p.startsWith('lib/data/platform/')), isEmpty);
  });

  test('only lib/data/platform imports the other platform plugins', () {
    final found = importers(
      RegExp(
        r'''import\s+['"]package:(mobile_scanner|permission_handler|share_plus[a-z_]*|file_selector[a-z_]*)/''',
      ),
    );
    expect(found, isNotEmpty);
    expect(found.where((p) => !p.startsWith('lib/data/platform/')), isEmpty);
  });

  test('only the user file adapter imports share_plus and file_selector', () {
    final found = importers(
      RegExp(
        r'''import\s+['"]package:(share_plus[a-z_]*|file_selector[a-z_]*)/''',
      ),
    );
    expect(found, [
      'lib/data/platform/share_and_selector_user_file_gateway.dart',
    ]);
  });

  test('the user file port is Flutter-free', () {
    final text = File('lib/domain/files/user_file_gateway.dart')
        .readAsStringSync();
    expect(text, isNot(contains('package:flutter')));
    expect(text, isNot(contains('dart:ui')));
    expect(text, isNot(contains("import 'package:share_plus")));
    expect(text, isNot(contains("import 'package:file_selector")));
  });

  test('the rest alert port is Flutter-free', () {
    final text = File('lib/domain/training/rest_alert_scheduler.dart')
        .readAsStringSync();
    expect(text, isNot(contains('package:flutter')));
  });
}
