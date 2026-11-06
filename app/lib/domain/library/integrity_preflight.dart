import 'package:meta/meta.dart';

/// The integrity preflight before the v8 upgrade (D04 section 7, 2026-11-06,
/// "Damaged database at upgrade"): if `PRAGMA quick_check` fails before the
/// migration, the migration stops. No v8 migration runs, version 8 is not
/// written, and no record is changed or quarantined. The app reports the
/// integrity failure with the recovery and backup route, keeps the original
/// database intact for diagnosis, and never promises normal operation on a
/// damaged database.
///
/// Pure decision logic and messages; the data layer runs the pragma.

/// What running `PRAGMA quick_check` produced.
@immutable
sealed class QuickCheckResult {
  const QuickCheckResult();
}

/// The rows the pragma returned, verbatim and in order.
final class QuickCheckRows extends QuickCheckResult {
  QuickCheckRows(List<String> rows) : rows = List.unmodifiable(rows);

  final List<String> rows;
}

/// The pragma could not run (for example the file is not a database). The
/// text is the error message, verbatim.
final class QuickCheckError extends QuickCheckResult {
  const QuickCheckError(this.message);

  final String message;
}

/// Decision of the preflight.
enum PreflightDecision {
  /// `quick_check` returned exactly one row `ok`: the migration may start.
  proceed,

  /// The check failed or could not run: stop before any upgrade work.
  stopBeforeUpgrade,
}

/// Outcome of the preflight: the decision and what the app reports.
@immutable
final class PreflightOutcome {
  PreflightOutcome._({
    required this.decision,
    required this.schemaVersion,
    required List<String> diagnostics,
    required this.userMessage,
  }) : diagnostics = List.unmodifiable(diagnostics);

  final PreflightDecision decision;

  /// The schema version the database stays at (stop) or starts from
  /// (proceed).
  final int schemaVersion;

  /// The pragma output or error, verbatim and complete (never truncated);
  /// empty when the check passed.
  final List<String> diagnostics;

  /// Plain text for the user; null when the check passed.
  final String? userMessage;

  bool get mayMigrate => decision == PreflightDecision.proceed;

  /// No upgrade work may write: no migration step, no version write, no
  /// quarantine, no report row in the database.
  bool get writesAllowed => mayMigrate;

  /// Normal operation is never promised on a damaged database.
  bool get normalOperationPromised => mayMigrate;
}

/// The message shown when the preflight stops the upgrade. It reports the
/// failure, says nothing was changed, and shows the recovery and backup
/// route. It promises no normal operation.
String integrityFailureMessage(int schemaVersion) =>
    'RepForge found damage in its database during the integrity check, so it '
    'did not upgrade it. Nothing was changed: the database is still at '
    'version $schemaVersion and is kept as it is for diagnosis. RepForge may '
    'not work normally with this database. Export a backup if you can, then '
    'restore your most recent good backup (Settings › Data › Backup and '
    'restore). Keep the details below for diagnosis.';

/// Decides the preflight from the `quick_check` [result] of a database at
/// [schemaVersion].
///
/// Proceeds only when the pragma returned exactly one row equal to `ok`.
/// Everything else stops: error rows, several rows, no row at all, or an
/// error running the pragma. An unexpected result is never read as success.
PreflightOutcome evaluateIntegrityPreflight({
  required int schemaVersion,
  required QuickCheckResult result,
}) {
  if (schemaVersion < 1) {
    throw ArgumentError.value(schemaVersion, 'schemaVersion', 'must be >= 1');
  }
  final List<String> diagnostics;
  switch (result) {
    case QuickCheckRows(:final rows) when rows.length == 1 && rows[0] == 'ok':
      return PreflightOutcome._(
        decision: PreflightDecision.proceed,
        schemaVersion: schemaVersion,
        diagnostics: const [],
        userMessage: null,
      );
    case QuickCheckRows(:final rows):
      diagnostics = rows.isEmpty
          ? const ['quick_check returned no rows']
          : rows;
    case QuickCheckError(:final message):
      diagnostics = ['quick_check could not run: $message'];
  }
  return PreflightOutcome._(
    decision: PreflightDecision.stopBeforeUpgrade,
    schemaVersion: schemaVersion,
    diagnostics: diagnostics,
    userMessage: integrityFailureMessage(schemaVersion),
  );
}
