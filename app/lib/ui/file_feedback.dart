import 'package:flutter/material.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';
import 'package:repforge/ui/error_text.dart';

/// User text for what happened to an exported file (ADR-0011, review F6).
///
/// The share sheet reports only that a destination was chosen: Android says
/// "success" as soon as a target is selected, and iOS/Android do not promise
/// the order of dismissal and completion reports. The text therefore never
/// says the file was "saved"; `dismissed` and `resultUnknown` are neutral.
String exportOutcomeText(ExportOutcome outcome) => switch (outcome) {
  ExportOutcome.shared => 'Export shared with the app you chose.',
  ExportOutcome.dismissed => 'Share sheet closed.',
  ExportOutcome.resultUnknown =>
    'Export sent to the share sheet. RepForge cannot tell where it went.',
};

/// User text for a failed export.
String exportErrorText(AppError error) => switch (error) {
  UnavailableError() => 'Exporting files is not available on this device.',
  StorageError() => 'Could not prepare the file. Please try again.',
  UnexpectedError() => 'Could not open the share sheet. Please try again.',
  _ => userMessageFor(error),
};

/// The on-screen rectangle of [context]'s widget, so the iPad share popover
/// can point at the button that opened it. Null when it has no size yet.
ShareAnchor? shareAnchorOf(BuildContext? context) {
  final box = context?.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final topLeft = box.localToGlobal(Offset.zero);
  final size = box.size;
  if (size.isEmpty) return null;
  return ShareAnchor(
    left: topLeft.dx,
    top: topLeft.dy,
    width: size.width,
    height: size.height,
  );
}
