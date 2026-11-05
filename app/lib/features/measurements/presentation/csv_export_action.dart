import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/measurements/application/export_measurements_csv.dart';
import 'package:repforge/ui/file_feedback.dart';

/// Snackbar text for a finished CSV export (BCM-009(1), review F6). Never says
/// "saved". Mentions readings that were left out because they cannot be read.
String csvExportMessage(CsvExportResult result) {
  final n = result.unreadableCount;
  final left = n == 0
      ? ''
      : n == 1
      ? ' 1 unreadable reading was not included.'
      : ' $n unreadable readings were not included.';
  final main = result.outcome == null
      ? 'Nothing to export.'
      : exportOutcomeText(result.outcome!);
  return '$main$left';
}

/// Runs the export and reports the result in a snackbar. [anchorContext] is
/// the button's context (iPad share popover anchor); [site] limits the export
/// to one type. Returns when the share sheet has been closed.
Future<void> runMeasurementsCsvExport(
  BuildContext context,
  WidgetRef ref, {
  BuildContext? anchorContext,
  MeasurementSite? site,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final export = ref.read(exportMeasurementsCsvProvider);
  final result = await export(site: site, anchor: shareAnchorOf(anchorContext));
  final text = switch (result) {
    Ok(:final value) => csvExportMessage(value),
    Err(:final error) => exportErrorText(error),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const Key('export-feedback'),
        duration: const Duration(seconds: 6),
        content: Text(text),
      ),
    );
}
