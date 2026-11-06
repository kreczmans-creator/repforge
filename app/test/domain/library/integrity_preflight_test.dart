import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/integrity_preflight.dart';

/// WS4 (3B-ACC-01): the integrity preflight decision (D04 section 7,
/// 2026-11-06, "Damaged database at upgrade").
void main() {
  PreflightOutcome check(QuickCheckResult r, {int version = 7}) =>
      evaluateIntegrityPreflight(schemaVersion: version, result: r);

  test('exactly one row "ok" proceeds, with no message', () {
    final o = check(QuickCheckRows(const ['ok']));
    expect(o.decision, PreflightDecision.proceed);
    expect(o.mayMigrate, isTrue);
    expect(o.writesAllowed, isTrue);
    expect(o.normalOperationPromised, isTrue);
    expect(o.userMessage, isNull);
    expect(o.diagnostics, isEmpty);
    expect(o.schemaVersion, 7);
  });

  test('a failed quick_check stops before the upgrade: no writes, no '
      'promise, verbatim diagnostics', () {
    const rows = [
      '*** in database main ***',
      'Page 12: btreeInitPage() returns error code 11',
      'row 3 missing from index idx_session_sets_session',
    ];
    final o = check(QuickCheckRows(rows));
    expect(o.decision, PreflightDecision.stopBeforeUpgrade);
    expect(o.mayMigrate, isFalse);
    expect(o.writesAllowed, isFalse);
    expect(o.normalOperationPromised, isFalse);
    expect(o.schemaVersion, 7, reason: 'stays at version 7');
    expect(o.diagnostics, rows, reason: 'complete and in order');
    expect(o.userMessage, integrityFailureMessage(7));
  });

  test('anything but a single "ok" row stops', () {
    for (final rows in [
      <String>[],
      ['OK'],
      ['ok '],
      ['ok', 'ok'],
      ['ok', 'row 1 missing from index'],
      [''],
    ]) {
      final o = check(QuickCheckRows(rows));
      expect(o.decision, PreflightDecision.stopBeforeUpgrade, reason: '$rows');
      expect(o.diagnostics, isNotEmpty, reason: '$rows');
    }
    expect(check(QuickCheckRows(const [])).diagnostics, [
      'quick_check returned no rows',
    ]);
  });

  test('a pragma that cannot run stops and keeps the error text', () {
    final o = check(const QuickCheckError('file is not a database'));
    expect(o.decision, PreflightDecision.stopBeforeUpgrade);
    expect(o.diagnostics, [
      'quick_check could not run: file is not a database',
    ]);
  });

  test('the message reports the failure, says nothing changed, gives the '
      'recovery and backup route, and promises no normal operation', () {
    final m = integrityFailureMessage(7);
    expect(m, contains('integrity check'));
    expect(m, contains('did not upgrade'));
    expect(m, contains('Nothing was changed'));
    expect(m, contains('version 7'));
    expect(m, contains('kept as it is for diagnosis'));
    expect(m, contains('may not work normally'));
    expect(m, contains('backup'));
    expect(m, contains('Backup and restore'));
    expect(m, isNot(contains('will work')));
  });

  test('an earlier schema version stays where it is', () {
    final o = check(QuickCheckRows(const ['corrupt']), version: 4);
    expect(o.schemaVersion, 4);
    expect(o.userMessage, contains('version 4'));
  });

  test('a schema version below 1 is refused', () {
    expect(
      () => check(QuickCheckRows(const ['ok']), version: 0),
      throwsArgumentError,
    );
  });
}
