import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';
import 'package:share_plus/share_plus.dart';

/// Shows the share sheet (default: `SharePlus.instance.share`).
typedef ShareFunction = Future<ShareResult> Function(ShareParams params);

/// Shows the file chooser (default: file_selector's `openFile`).
typedef OpenFileFunction = Future<XFile?> Function({
  List<XTypeGroup> acceptedTypeGroups,
});

/// Directory for temporary export files (default: the app cache).
typedef TempDirectoryProvider = Future<Directory> Function();

/// Directories in which a picked file is a temporary copy made by the plugin
/// (default: application cache and temporary directory).
typedef PickedFileRootsProvider = Future<List<Directory>> Function();

/// File name safe on every file system and in a content URI: letters, digits,
/// dot, dash, underscore and space survive; everything else (path separators,
/// control characters, quotes, `..`) becomes `_`. Leading dots are removed so
/// the file is never hidden, and the name is capped at 100 characters while
/// keeping the extension. Returns `null` when nothing usable is left.
@visibleForTesting
String? safeFileName(String name) {
  var cleaned = name
      .replaceAll(RegExp('[^A-Za-z0-9._ -]'), '_')
      .replaceAll(RegExp(r'^[.\s]+'), '')
      .trim();
  if (cleaned.isEmpty || cleaned.replaceAll('_', '').isEmpty) return null;
  if (cleaned.length > 100) {
    final dot = cleaned.lastIndexOf('.');
    final ext = dot > 0 && cleaned.length - dot <= 10
        ? cleaned.substring(dot)
        : '';
    cleaned = cleaned.substring(0, 100 - ext.length) + ext;
  }
  return cleaned;
}

/// [UserFileGateway] on top of `share_plus` (export) and `file_selector`
/// (pick) (ADR-0011).
///
/// This file is the only place that imports those two plugins (adapter
/// boundary, ADR-0006). Nothing here throws: every platform failure becomes
/// an [AppError].
///
/// Export: the bytes go to a temporary file in the app cache (one fresh
/// sub-directory per export, outside the folder share_plus manages), the file
/// is handed to the share sheet, and the directory is deleted afterwards
/// (best effort). Leftovers of earlier exports older than [staleAfter] are
/// removed at the start of each export. An export whose share sheet stays open
/// for more than [staleAfter] can therefore be swept by a concurrent export's
/// cleanup (its file then disappears under the sheet); this is accepted as
/// extremely rare.
///
/// share_plus on Android copies the file to its own `cache/share_plus` folder
/// and keeps that copy until the next share: the receiving app reads it
/// asynchronously, so it must not be deleted early. It is app-private and
/// excluded from backup.
///
/// Pick: the plugin has already copied the chosen file (Android: into the
/// cache; iOS: into tmp) before Dart sees it, so after the attempt (read,
/// oversize or failure) the copy is deleted when its symlink-resolved location
/// lies under the cache or a temporary directory (application cache,
/// `getTemporaryDirectory`, and `Directory.systemTemp`, i.e.
/// NSTemporaryDirectory on iOS; `/var` vs `/private/var` is handled by the
/// resolution). The exact iOS location of the picker's copy is not verified
/// here, so this is best effort and a copy elsewhere is left to the OS. The
/// size limit is checked by length before reading the bytes into Dart, but on
/// Android the plugin has already read the file; the limit only rejects it.
final class ShareAndSelectorUserFileGateway implements UserFileGateway {
  /// Creates the adapter; every collaborator is injectable for tests.
  ShareAndSelectorUserFileGateway({
    ShareFunction? share,
    OpenFileFunction? openFile,
    TempDirectoryProvider? tempDirectory,
    PickedFileRootsProvider? pickedFileRoots,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _pickedFileRoots = pickedFileRoots ?? _defaultPickedFileRoots,
       _share = share ?? SharePlus.instance.share,
       _openFile = openFile ?? _defaultOpenFile,
       _tempDirectory = tempDirectory ?? getApplicationCacheDirectory;

  /// Sub-directory of the cache that holds exports in flight.
  static const exportFolder = 'repforge_exports';

  /// Export folders older than this are leftovers (crash or kill mid-share).
  static const staleAfter = Duration(hours: 1);

  final DateTime Function() _now;
  final PickedFileRootsProvider _pickedFileRoots;
  final ShareFunction _share;
  final OpenFileFunction _openFile;
  final TempDirectoryProvider _tempDirectory;

  static Future<List<Directory>> _defaultPickedFileRoots() async => [
    await getApplicationCacheDirectory(),
    await getTemporaryDirectory(),
    // NSTemporaryDirectory on iOS (the document picker's copy lands in its
    // tmp, not in Library/Caches); /var vs /private/var is handled by the
    // symlink resolution.
    Directory.systemTemp,
  ];

  static Future<XFile?> _defaultOpenFile({
    List<XTypeGroup> acceptedTypeGroups = const [],
  }) => openFile(acceptedTypeGroups: acceptedTypeGroups);

  static const _unavailable = UnavailableError(
    'File export and import are not available on this platform.',
  );

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<Result<ExportOutcome>> exportFile({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    String? subject,
    ShareAnchor? anchor,
  }) async {
    if (!_supported) return const Result.err(_unavailable);
    final safeName = safeFileName(fileName);
    if (safeName == null) {
      return const Result.err(
        ValidationError('The export file needs a name.', field: 'fileName'),
      );
    }

    final cleanSubject = subject?.trim();
    final shareSubject = (cleanSubject == null || cleanSubject.isEmpty)
        ? null
        : cleanSubject;

    Directory? folder;
    try {
      final root = await _tempDirectory();
      final parent = await Directory(
        '${root.path}${Platform.pathSeparator}$exportFolder',
      ).create(recursive: true);
      await _removeStale(parent);
      folder = await parent.createTemp('export_');
      final file = File('${folder.path}${Platform.pathSeparator}$safeName');
      await file.writeAsBytes(bytes, flush: true);

      final ShareResult result;
      try {
        result = await _share(
          ShareParams(
            files: [XFile(file.path, mimeType: mimeType, name: safeName)],
            fileNameOverrides: [safeName],
            subject: shareSubject,
            title: shareSubject,
            sharePositionOrigin: anchor == null
                ? null
                : Rect.fromLTWH(
                    anchor.left,
                    anchor.top,
                    anchor.width,
                    anchor.height,
                  ),
          ),
        );
      } on Object catch (e) {
        debugPrint('Share failed: $e');
        return Result.err(UnexpectedError('The share sheet failed.', cause: e));
      }
      return Result.ok(switch (result.status) {
        ShareResultStatus.success => ExportOutcome.shared,
        ShareResultStatus.dismissed => ExportOutcome.dismissed,
        ShareResultStatus.unavailable => ExportOutcome.resultUnknown,
      });
    } on FileSystemException catch (e) {
      debugPrint('Export file write failed: $e');
      return Result.err(
        StorageError('The export file could not be written.', cause: e),
      );
    } on Object catch (e) {
      debugPrint('Export failed: $e');
      return Result.err(UnexpectedError('The export failed.', cause: e));
    } finally {
      await _cleanUp(folder);
    }
  }

  Future<void> _removeStale(Directory parent) async {
    try {
      final limit = _now().subtract(staleAfter);
      await for (final entry in parent.list()) {
        final name = entry.uri.pathSegments.lastWhere(
          (segment) => segment.isNotEmpty,
          orElse: () => '',
        );
        if (entry is! Directory || !name.startsWith('export_')) continue;
        if (entry.statSync().modified.isBefore(limit)) {
          await entry.delete(recursive: true);
        }
      }
    } on Object catch (e) {
      debugPrint('Stale export clean-up failed: $e');
    }
  }

  Future<void> _cleanUp(Directory? folder) async {
    if (folder == null) return;
    try {
      if (folder.existsSync()) await folder.delete(recursive: true);
    } on Object catch (e) {
      debugPrint('Export clean-up failed: $e');
    }
  }

  /// Deletes the plugin's temporary copy of a picked file, only when its
  /// symlink-resolved location lies under a symlink-resolved cache or
  /// temporary directory (never the user's original, never through a link
  /// that leaves the cache). Any resolution failure skips the deletion.
  Future<void> _deletePickedCopy(String path) async {
    try {
      if (path.isEmpty || path.split(RegExp(r'[\\/]')).contains('..')) return;
      final resolved = File(path).resolveSymbolicLinksSync();
      for (final root in await _pickedFileRoots()) {
        final String resolvedRoot;
        try {
          resolvedRoot = root.resolveSymbolicLinksSync();
        } on FileSystemException {
          continue;
        }
        if (resolved.startsWith('$resolvedRoot${Platform.pathSeparator}')) {
          await File(path).delete();
          return;
        }
      }
    } on Object catch (e) {
      debugPrint('Picked file clean-up failed: $e');
    }
  }

  @override
  Future<Result<PickedFile?>> pickFile({
    required List<String> extensions,
    required List<String> mimeTypes,
    List<String> uniformTypeIdentifiers = const [],
    int maxBytes = maxPickedFileBytes,
  }) async {
    if (!_supported) return const Result.err(_unavailable);
    XFile? chosen;
    try {
      final group = defaultTargetPlatform == TargetPlatform.iOS
          ? XTypeGroup(
              label: 'Files',
              uniformTypeIdentifiers: uniformTypeIdentifiers.isEmpty
                  ? null
                  : uniformTypeIdentifiers,
            )
          : XTypeGroup(
              label: 'Files',
              extensions: extensions.isEmpty ? null : extensions,
              mimeTypes: mimeTypes.isEmpty ? null : mimeTypes,
            );
      chosen = await _openFile(acceptedTypeGroups: [group]);
      if (chosen == null) return const Result.ok(null);

      final length = await chosen.length();
      if (length > maxBytes) {
        return Result.err(
          FileTooLargeError(
            'The chosen file is $length bytes; the limit is $maxBytes.',
            maxBytes: maxBytes,
          ),
        );
      }
      final bytes = await chosen.readAsBytes();
      if (bytes.length > maxBytes) {
        return Result.err(
          FileTooLargeError(
            'The chosen file is ${bytes.length} bytes; the limit is $maxBytes.',
            maxBytes: maxBytes,
          ),
        );
      }
      return Result.ok(
        PickedFile(name: chosen.name, bytes: Uint8List.fromList(bytes)),
      );
    } on Object catch (e) {
      debugPrint('Pick file failed: $e');
      return Result.err(
        UnexpectedError('The file could not be read.', cause: e),
      );
    } finally {
      // Every outcome after a file was chosen (read, oversize, failure).
      if (chosen != null) await _deletePickedCopy(chosen.path);
    }
  }
}
