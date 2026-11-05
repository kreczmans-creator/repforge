import 'dart:convert';

import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/measurements_csv.dart';

/// What [ExportMeasurementsCsv] did.
final class CsvExportResult {
  const CsvExportResult({
    required this.rows,
    required this.unreadableCount,
    required this.outcome,
    this.fileName,
  });

  /// Readings written to the CSV (0 when nothing was exported).
  final int rows;

  /// Stored readings that cannot be read and are therefore not in the file
  /// (same scope as the export: all types, or the chosen type).
  final int unreadableCount;

  /// What happened to the file after the share sheet, or null when there was
  /// nothing to export and the sheet was not opened.
  final ExportOutcome? outcome;

  final String? fileName;

  bool get nothingToExport => outcome == null;
}

/// Use case: export readings as a CSV file (BCM-009(1), D5) through the
/// `UserFileGateway` port (ADR-0011).
///
/// One row per readable reading of every type, or of one type only. Unreadable
/// stored readings (owner rule on legacy values) are not written; their number
/// is returned so the screen can say so. With no readable reading nothing is
/// shared and the result says so. The file is UTF-8 **without** a byte order
/// mark: the content is ASCII (labels, digits, `+ - : .`), which every
/// spreadsheet reads identically with or without a mark, while a mark would
/// corrupt the first header cell for strict CSV readers.
final class ExportMeasurementsCsv {
  const ExportMeasurementsCsv({
    required this._repository,
    required this._gateway,
    required this._clock,
  });

  final MeasurementRepository _repository;
  final UserFileGateway _gateway;
  final Clock _clock;

  static const mimeType = 'text/csv';

  /// `repforge-measurements-2026-11-05.csv` (device-local date); a single type
  /// adds its name: `repforge-measurements-waist-2026-11-05.csv`.
  static String fileNameFor(DateTime now, [MeasurementSite? site]) {
    final day = CalendarDate.fromInstant(now).iso;
    return site == null
        ? 'repforge-measurements-$day.csv'
        : 'repforge-measurements-${site.name}-$day.csv';
  }

  Future<Result<CsvExportResult>> call({
    MeasurementSite? site,
    ShareAnchor? anchor,
  }) async {
    final List<Measurement> readings;
    final int unreadable;
    try {
      readings = site == null
          ? await _repository.watchAll().first
          : await _repository.watchSite(site).first;
      final stored = await _repository.watchUnreadable().first;
      unreadable = site == null
          ? stored.length
          : stored.where((u) => u.site == site.name).length;
    } on Object catch (e) {
      return Err(StorageError('Could not read the measurements.', cause: e));
    }
    if (readings.isEmpty) {
      return Ok(
        CsvExportResult(rows: 0, unreadableCount: unreadable, outcome: null),
      );
    }
    final fileName = fileNameFor(_clock.now(), site);
    final result = await _gateway.exportFile(
      fileName: fileName,
      mimeType: mimeType,
      bytes: utf8.encode(buildMeasurementsCsv(readings)),
      subject: 'RepForge measurements',
      anchor: anchor,
    );
    return switch (result) {
      Ok(:final value) => Ok(
        CsvExportResult(
          rows: readings.length,
          unreadableCount: unreadable,
          outcome: value,
          fileName: fileName,
        ),
      ),
      Err(:final error) => Err(error),
    };
  }
}
