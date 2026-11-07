import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';

/// The validated outer layer of a backup file: the single place that decides
/// whether a text is a RepForge backup this app can read (DAT-004(2)). Both
/// the side-effect-free preview and the restore go through
/// [parseBackupEnvelope], so they can never disagree about a file.
@immutable
final class BackupEnvelope {
  const BackupEnvelope({
    required this.formatVersion,
    required this.exportedAt,
    required this.tables,
  });

  final int formatVersion;

  /// When the backup was made (UTC), or null when the file has no readable
  /// `exportedAt` (older files).
  final DateTime? exportedAt;

  /// Table name to its raw rows (not yet interpreted).
  final Map<String, Object?> tables;
}

/// What a backup file holds, shown before the user confirms a restore
/// (DAT-004(1)). Produced without touching any data.
@immutable
final class BackupPreview {
  const BackupPreview({
    required this.formatVersion,
    required this.exportedAt,
    required this.rowCounts,
  });

  final int formatVersion;

  /// UTC instant the backup was made, or null when the file does not say.
  final DateTime? exportedAt;

  /// Rows that a restore would write, per table name (tables the app does not
  /// know are not listed; tables with no rows are listed with 0).
  final Map<String, int> rowCounts;

  /// All rows a restore would write.
  int get totalRows => rowCounts.values.fold(0, (a, b) => a + b);
}

/// Parses the envelope of [json] without any side effect.
///
/// Errors are [ValidationError]s with `field: 'file'`: not JSON, not a RepForge
/// backup, `formatVersion` missing, not an integer or newer than
/// [supportedFormatVersion], or no `tables` map.
Result<BackupEnvelope> parseBackupEnvelope(
  String json, {
  required int supportedFormatVersion,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const Err(invalidBackupJson);
  }
  return parseDecodedBackupEnvelope(
    decoded,
    supportedFormatVersion: supportedFormatVersion,
  );
}

/// The error of a backup text that is not JSON ([parseBackupEnvelope]).
const ValidationError invalidBackupJson = ValidationError(
  'Backup is not valid JSON.',
  field: 'file',
);

/// [parseBackupEnvelope] for a text the caller has already decoded with
/// `jsonDecode` (a caller that needs the decoded value decodes once; WP 8
/// 3b-10, Review C M-1). The same checks and errors.
Result<BackupEnvelope> parseDecodedBackupEnvelope(
  Object? decoded, {
  required int supportedFormatVersion,
}) {
  if (decoded is! Map<String, Object?> || decoded['app'] != 'repforge') {
    return const Err(
      ValidationError('This file is not a RepForge backup.', field: 'file'),
    );
  }
  final version = decoded['formatVersion'];
  if (version is! int || version > supportedFormatVersion) {
    return const Err(
      ValidationError(
        'This backup was made by a newer version of RepForge.',
        field: 'file',
      ),
    );
  }
  final tables = decoded['tables'];
  if (tables is! Map<String, Object?>) {
    return const Err(ValidationError('Backup has no tables.', field: 'file'));
  }
  final exported = decoded['exportedAt'];
  return Ok(
    BackupEnvelope(
      formatVersion: version,
      exportedAt: exported is String
          ? DateTime.tryParse(exported)?.toUtc()
          : null,
      tables: tables,
    ),
  );
}
