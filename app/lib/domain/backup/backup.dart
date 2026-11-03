import 'package:repforge/domain/core/result.dart';

/// Backup and restore (DAT-003..). The payload is JSON with a format version;
/// restore replaces all local data (default per OQ-17) inside a transaction.
abstract interface class BackupRepository {
  /// Serialises every table to a JSON string.
  Future<String> exportJson();

  /// Replaces all local data with the backup. Fails without changing anything
  /// if the payload is malformed or from a newer format version.
  Future<Result<BackupSummary>> importJson(String json);
}

final class BackupSummary {
  const BackupSummary({required this.formatVersion, required this.rowCounts});
  final int formatVersion;
  final Map<String, int> rowCounts;
}
