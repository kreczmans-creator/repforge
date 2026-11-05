import 'dart:convert';

import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';

/// Use case: hand the full JSON backup to the share sheet (DAT-004, BCM-009(2),
/// D3). Uses the existing [BackupRepository.exportJson]; there is no second
/// export format. The outcome only says a destination was chosen, never that
/// the file was saved (ADR-0011).
final class ExportBackup {
  const ExportBackup({
    required this._repository,
    required this._gateway,
    required this._clock,
  });

  final BackupRepository _repository;
  final UserFileGateway _gateway;
  final Clock _clock;

  static const mimeType = 'application/json';

  /// `repforge-backup-2026-11-05.json` (device-local date).
  static String fileNameFor(DateTime now) =>
      'repforge-backup-${CalendarDate.fromInstant(now).iso}.json';

  Future<Result<ExportOutcome>> call({ShareAnchor? anchor}) async {
    final String json;
    try {
      json = await _repository.exportJson();
    } on Object catch (e) {
      return Err(StorageError('Could not read the data to back up.', cause: e));
    }
    return await _gateway.exportFile(
      fileName: fileNameFor(_clock.now()),
      mimeType: mimeType,
      bytes: utf8.encode(json),
      subject: 'RepForge backup',
      anchor: anchor,
    );
  }
}

/// A backup file that passed validation and is waiting for confirmation.
final class PreviewedBackup {
  const PreviewedBackup({
    required this.fileName,
    required this.json,
    required this.preview,
  });

  /// Name reported by the platform (may be empty).
  final String fileName;

  /// The validated text, handed back to [RestoreBackup] after confirmation.
  final String json;
  final BackupPreview preview;
}

/// Use case: let the user choose a backup file and validate it **without
/// changing any data** (DAT-004(1)(2)). Returns `Ok(null)` when the picker is
/// cancelled. A file that cannot be read, is too large, is not JSON, is not a
/// RepForge backup or comes from a newer format is an error and nothing is
/// stored. A file with no restorable record is rejected too. Validation
/// is [BackupRepository.previewJson], the same envelope
/// check the restore runs.
final class PreviewBackup {
  const PreviewBackup({required this._repository, required this._gateway});

  final BackupRepository _repository;
  final UserFileGateway _gateway;

  Future<Result<PreviewedBackup?>> call() async {
    final picked = await _gateway.pickFile(
      // No extension or MIME filter: Android providers (Drive, Downloads,
      // mail) often report a .json file as text/plain or octet-stream and a
      // filter would hide it. [parseBackupEnvelope] is the guard. iOS filters
      // by type identifier.
      extensions: const [],
      mimeTypes: const [],
      uniformTypeIdentifiers: const ['public.json'],
    );
    switch (picked) {
      case Err(:final error):
        return Err(error);
      case Ok(value: null):
        return const Ok(null);
      case Ok(:final value?):
        final String text;
        try {
          text = utf8.decode(value.bytes);
        } on FormatException {
          return const Err(
            ValidationError(
              'That file is not a RepForge backup (it is not text).',
              field: 'file',
            ),
          );
        }
        return switch (_repository.previewJson(text)) {
          // Owner rule D3 (applied by the coordinator, owner may override): a
          // file that would restore nothing is rejected, not offered as a way
          // to empty the device.
          Ok(value: BackupPreview(totalRows: 0)) => const Err(
            ValidationError('This backup contains no records.', field: 'file'),
          ),
          Ok(value: final preview) => Ok(
            PreviewedBackup(fileName: value.name, json: text, preview: preview),
          ),
          Err(:final error) => Err(error),
        };
    }
  }
}

/// Use case: replace all local data with a previewed backup (DAT-004, OQ-17
/// default: replace). The caller must have shown the preview and obtained an
/// explicit confirmation. The repository validates again and restores in one
/// transaction; on any failure nothing is changed.
final class RestoreBackup {
  const RestoreBackup({required this._repository});

  final BackupRepository _repository;

  Future<Result<BackupSummary>> call(PreviewedBackup backup) async {
    try {
      return await _repository.importJson(backup.json);
    } on Object catch (e) {
      return Err(
        StorageError('Restore failed; nothing was changed.', cause: e),
      );
    }
  }
}
