import 'dart:convert';
import 'dart:typed_data';

import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';

/// One export recorded by [FakeUserFileGateway].
final class RecordedExport {
  const RecordedExport({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    this.subject,
  });
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final String? subject;

  /// The bytes decoded as UTF-8 (CSV and JSON exports).
  String get text => utf8.decode(bytes);
}

/// One pick request recorded by [FakeUserFileGateway].
final class RecordedPick {
  const RecordedPick({
    required this.extensions,
    required this.mimeTypes,
    required this.uniformTypeIdentifiers,
    required this.maxBytes,
  });
  final List<String> extensions;
  final List<String> mimeTypes;
  final List<String> uniformTypeIdentifiers;
  final int maxBytes;
}

/// Test double for [UserFileGateway]: records exports and pick requests and
/// answers from scripted results. Fakes over mocks.
final class FakeUserFileGateway implements UserFileGateway {
  FakeUserFileGateway({
    this.exportResult = const Result.ok(ExportOutcome.shared),
    this.delay = Duration.zero,
  });

  /// Answer of every [exportFile] call (set an `Err` to script a failure).
  Result<ExportOutcome> exportResult;

  /// Answers of successive [pickFile] calls, consumed in order. When empty,
  /// [pickFile] answers `Ok(null)` (the user cancelled).
  final List<Result<PickedFile?>> pickResults = [];

  /// Pause before answering, to test busy states.
  Duration delay;

  final List<RecordedExport> exports = [];
  final List<RecordedPick> picks = [];

  /// Scripts the next pick to return a file.
  void queuePick(String name, List<int> bytes) => pickResults.add(
    Result.ok(PickedFile(name: name, bytes: Uint8List.fromList(bytes))),
  );

  @override
  Future<Result<ExportOutcome>> exportFile({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    String? subject,
    ShareAnchor? anchor,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    exports.add(
      RecordedExport(
        fileName: fileName,
        mimeType: mimeType,
        bytes: Uint8List.fromList(bytes),
        subject: subject,
      ),
    );
    return exportResult;
  }

  @override
  Future<Result<PickedFile?>> pickFile({
    required List<String> extensions,
    required List<String> mimeTypes,
    List<String> uniformTypeIdentifiers = const [],
    int maxBytes = maxPickedFileBytes,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    picks.add(
      RecordedPick(
        extensions: extensions,
        mimeTypes: mimeTypes,
        uniformTypeIdentifiers: uniformTypeIdentifiers,
        maxBytes: maxBytes,
      ),
    );
    if (pickResults.isEmpty) return const Result.ok(null);
    final next = pickResults.removeAt(0);
    if (next case Ok<PickedFile?>(:final value?)
        when value.bytes.length > maxBytes) {
      return Result.err(
        FileTooLargeError('File exceeds $maxBytes bytes.', maxBytes: maxBytes),
      );
    }
    return next;
  }
}
