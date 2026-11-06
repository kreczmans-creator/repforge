import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';

/// Largest file [UserFileGateway.pickFile] reads into memory (50 MB). A full
/// JSON backup is far smaller; the cap only protects against a wrong file.
const int maxPickedFileBytes = 50 * 1024 * 1024;

/// What happened to an exported file after the share sheet was shown.
enum ExportOutcome {
  /// The user picked a destination (save to Files or Drive, email, an app).
  /// This only means a target was chosen: the UI must not claim the file was
  /// "saved" (Android reports success as soon as a target is selected).
  shared,

  /// The user closed the share sheet without choosing anything. Treat it
  /// neutrally (no error, no success): the platforms do not guarantee that
  /// dismissal and completion are reported in a reliable order.
  dismissed,

  /// The sheet was shown but the platform does not report the choice
  /// (share_plus `unavailable`). The UI must not claim the file was saved.
  resultUnknown,
}

/// A file chosen by the user, fully read.
@immutable
final class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  /// File name as reported by the platform (may be empty on some providers).
  final String name;
  final Uint8List bytes;
}

/// Where the share sheet should anchor on iPad (global screen coordinates).
/// Optional: without it the sheet appears at the screen centre.
@immutable
final class ShareAnchor {
  const ShareAnchor({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
  final double left;
  final double top;
  final double width;
  final double height;
}

/// Hands files to the user and reads files the user chooses (ADR-0011).
///
/// Flutter-free port (ADR-0006). Implementations never throw: every failure is
/// an [AppError] in the returned [Result].
abstract interface class UserFileGateway {
  /// Offers [bytes] as a file named [fileName] through the system share sheet
  /// (save to Files or Drive, email, another app).
  ///
  /// Errors: [ValidationError] (empty or unusable [fileName]),
  /// [UnavailableError] (no sharing on this platform), [StorageError] (the
  /// temporary file could not be written), [UnexpectedError] (platform
  /// failure).
  Future<Result<ExportOutcome>> exportFile({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    String? subject,
    ShareAnchor? anchor,
  });

  /// Lets the user choose one file and returns it, or `Ok(null)` when they
  /// cancel. [extensions] (without the dot) and [mimeTypes] filter on Android
  /// and desktop; [uniformTypeIdentifiers] filters on iOS (an empty list
  /// allows any file there).
  ///
  /// Errors: [UnavailableError], [FileTooLargeError] (over [maxBytes]),
  /// [UnexpectedError].
  Future<Result<PickedFile?>> pickFile({
    required List<String> extensions,
    required List<String> mimeTypes,
    List<String> uniformTypeIdentifiers = const [],
    int maxBytes = maxPickedFileBytes,
  });
}

/// Gateway used where no platform adapter is bound (desktop, web, tests that
/// do not care): every call reports [UnavailableError].
final class UnavailableUserFileGateway implements UserFileGateway {
  const UnavailableUserFileGateway();

  static const _error = UnavailableError(
    'File export and import are not available on this platform.',
  );

  @override
  Future<Result<ExportOutcome>> exportFile({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    String? subject,
    ShareAnchor? anchor,
  }) async => const Result.err(_error);

  @override
  Future<Result<PickedFile?>> pickFile({
    required List<String> extensions,
    required List<String> mimeTypes,
    List<String> uniformTypeIdentifiers = const [],
    int maxBytes = maxPickedFileBytes,
  }) async => const Result.err(_error);
}
