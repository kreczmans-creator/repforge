import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/platform/share_and_selector_user_file_gateway.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';
import 'package:share_plus/share_plus.dart';

/// The adapter with the plugin entry points replaced by scripted functions
/// (no device): temp file contents and name, clean-up, result mapping,
/// picking and every failure turned into an [AppError].
void main() {
  late Directory cache;
  late ShareParams? seen;
  late String? seenContent;
  late bool seenExists;
  late Future<ShareResult> Function(ShareParams) onShare;
  late Future<XFile?> Function(List<XTypeGroup>) onOpen;
  late List<XTypeGroup> seenGroups;
  late DateTime clock;

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('repforge_user_file_test_');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    seen = null;
    seenContent = null;
    seenExists = false;
    seenGroups = [];
    clock = DateTime.now();
    onShare = (p) async {
      seen = p;
      final path = p.files!.single.path;
      seenExists = File(path).existsSync();
      seenContent = seenExists ? File(path).readAsStringSync() : null;
      return const ShareResult('x', ShareResultStatus.success);
    };
    onOpen = (groups) async {
      seenGroups = groups;
      return null;
    };
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    if (cache.existsSync()) await cache.delete(recursive: true);
  });

  ShareAndSelectorUserFileGateway gateway() => ShareAndSelectorUserFileGateway(
    share: (p) => onShare(p),
    openFile: ({acceptedTypeGroups = const []}) => onOpen(acceptedTypeGroups),
    tempDirectory: () async => cache,
    pickedFileRoots: () async => [cache],
    now: () => clock,
  );

  Directory exportRoot() => Directory(
    '${cache.path}${Platform.pathSeparator}'
    '${ShareAndSelectorUserFileGateway.exportFolder}',
  );

  group('safeFileName', () {
    test('keeps plain names and replaces unsafe characters', () {
      expect(
        safeFileName('repforge-measurements.csv'),
        'repforge-measurements.csv',
      );
      expect(safeFileName(r'a/b\c:d*e?.csv'), 'a_b_c_d_e_.csv');
      expect(safeFileName('../../etc/passwd'), '_.._etc_passwd');
      expect(safeFileName('.hidden.csv'), 'hidden.csv');
      expect(safeFileName('Größe.csv'), 'Gr__e.csv');
    });

    test('rejects names with nothing usable', () {
      expect(safeFileName(''), isNull);
      expect(safeFileName('...'), isNull);
      expect(safeFileName('///'), isNull);
    });

    test('caps the length and keeps the extension', () {
      final name = safeFileName('${'a' * 300}.json')!;
      expect(name.length, 100);
      expect(name, endsWith('.json'));
    });
  });

  group('exportFile', () {
    test('writes the bytes under the safe name and shares the file', () async {
      final result = await gateway().exportFile(
        fileName: 'my data/2026.csv',
        mimeType: 'text/csv',
        bytes: 'a,b\r\n1,2\r\n'.codeUnits,
        subject: 'Measurements',
      );

      expect(result, isA<Ok<ExportOutcome>>());
      expect((result as Ok<ExportOutcome>).value, ExportOutcome.shared);
      expect(seenExists, isTrue);
      expect(seenContent, 'a,b\r\n1,2\r\n');
      final params = seen!;
      expect(params.files!.single.name, 'my data_2026.csv');
      expect(params.files!.single.mimeType, 'text/csv');
      expect(params.fileNameOverrides, ['my data_2026.csv']);
      expect(params.subject, 'Measurements');
      expect(
        params.files!.single.path,
        startsWith(exportRoot().path),
        reason: 'inside the app cache, outside the share_plus folder',
      );
    });

    test('deletes the temporary file after sharing', () async {
      await gateway().exportFile(
        fileName: 'a.csv',
        mimeType: 'text/csv',
        bytes: const [1, 2, 3],
      );
      expect(exportRoot().listSync(), isEmpty);
    });

    test('deletes the temporary file when sharing fails', () async {
      onShare = (_) async => throw StateError('boom');
      final result = await gateway().exportFile(
        fileName: 'a.csv',
        mimeType: 'text/csv',
        bytes: const [1],
      );
      expect(result, isA<Err<ExportOutcome>>());
      expect(exportRoot().listSync(), isEmpty);
    });

    test('maps the share result status', () async {
      for (final (status, expected) in [
        (ShareResultStatus.success, ExportOutcome.shared),
        (ShareResultStatus.dismissed, ExportOutcome.dismissed),
        (ShareResultStatus.unavailable, ExportOutcome.resultUnknown),
      ]) {
        onShare = (_) async => ShareResult('', status);
        final result = await gateway().exportFile(
          fileName: 'a.csv',
          mimeType: 'text/csv',
          bytes: const [1],
        );
        expect(
          (result as Ok<ExportOutcome>).value,
          expected,
          reason: '$status',
        );
      }
    });

    test('passes the iPad anchor as the share position', () async {
      await gateway().exportFile(
        fileName: 'a.csv',
        mimeType: 'text/csv',
        bytes: const [1],
        anchor: const ShareAnchor(left: 1, top: 2, width: 3, height: 4),
      );
      expect(seen!.sharePositionOrigin, const Rect.fromLTWH(1, 2, 3, 4));
    });

    test('a platform failure becomes UnexpectedError, never a throw', () async {
      onShare = (_) async => throw PlatformException(code: 'x');
      final result = await gateway().exportFile(
        fileName: 'a.csv',
        mimeType: 'text/csv',
        bytes: const [1],
      );
      expect((result as Err<ExportOutcome>).error, isA<UnexpectedError>());
    });

    test('a temp directory failure becomes StorageError', () async {
      final blocker = File('${cache.path}${Platform.pathSeparator}file')
        ..writeAsStringSync('x');
      final g = ShareAndSelectorUserFileGateway(
        share: (p) => onShare(p),
        tempDirectory: () async => Directory(blocker.path),
      );
      final result = await g.exportFile(
        fileName: 'a.csv',
        mimeType: 'text/csv',
        bytes: const [1],
      );
      expect((result as Err<ExportOutcome>).error, isA<StorageError>());
      expect(seen, isNull);
    });

    test(
      'an unusable file name is a validation error and shares nothing',
      () async {
        final result = await gateway().exportFile(
          fileName: '...',
          mimeType: 'text/csv',
          bytes: const [1],
        );
        expect((result as Err<ExportOutcome>).error, isA<ValidationError>());
        expect(seen, isNull);
      },
    );

    test('works on iOS and reports unavailable on desktop', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ios = await gateway().exportFile(
        fileName: 'a.csv',
        mimeType: 'text/csv',
        bytes: const [1],
      );
      expect(ios, isA<Ok<ExportOutcome>>());

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      seen = null;
      final desktop = await gateway().exportFile(
        fileName: 'a.csv',
        mimeType: 'text/csv',
        bytes: const [1],
      );
      expect((desktop as Err<ExportOutcome>).error, isA<UnavailableError>());
      expect(seen, isNull);
    });
  });

  group('pickFile', () {
    test('cancel returns Ok(null)', () async {
      final result = await gateway().pickFile(
        extensions: ['json'],
        mimeTypes: ['application/json'],
      );
      expect(result, isA<Ok<PickedFile?>>());
      expect((result as Ok<PickedFile?>).value, isNull);
    });

    test(
      'returns the name and bytes and filters by extension and MIME',
      () async {
        final picked = File('${cache.path}${Platform.pathSeparator}backup.json')
          ..writeAsBytesSync([123, 125]);
        onOpen = (groups) async {
          seenGroups = groups;
          return XFile(picked.path);
        };
        final result = await gateway().pickFile(
          extensions: ['json'],
          mimeTypes: ['application/json'],
          uniformTypeIdentifiers: ['public.json'],
        );
        final file = (result as Ok<PickedFile?>).value!;
        expect(file.name, 'backup.json');
        expect(file.bytes, [123, 125]);
        expect(seenGroups.single.extensions, ['json']);
        expect(seenGroups.single.mimeTypes, ['application/json']);
        expect(seenGroups.single.uniformTypeIdentifiers, isNull);
      },
    );

    test('on iOS the filter is the uniform type identifiers', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await gateway().pickFile(
        extensions: ['json'],
        mimeTypes: ['application/json'],
        uniformTypeIdentifiers: ['public.json'],
      );
      expect(seenGroups.single.uniformTypeIdentifiers, ['public.json']);
      expect(seenGroups.single.extensions, isNull);

      await gateway().pickFile(extensions: ['json'], mimeTypes: const []);
      expect(seenGroups.single.allowsAny, isTrue);
    });

    test('a file over the limit is rejected with FileTooLargeError', () async {
      onOpen = (_) async => XFile.fromData(Uint8List(11), name: 'big.json');
      final result = await gateway().pickFile(
        extensions: ['json'],
        mimeTypes: ['application/json'],
        maxBytes: 10,
      );
      final error = (result as Err<PickedFile?>).error;
      expect(error, isA<FileTooLargeError>());
      expect((error as FileTooLargeError).maxBytes, 10);
    });

    test('a file exactly at the limit is accepted', () async {
      onOpen = (_) async => XFile.fromData(Uint8List(10), name: 'ok.json');
      final result = await gateway().pickFile(
        extensions: ['json'],
        mimeTypes: ['application/json'],
        maxBytes: 10,
      );
      expect((result as Ok<PickedFile?>).value!.bytes.length, 10);
    });

    test('the default limit is 50 MB', () {
      expect(maxPickedFileBytes, 50 * 1024 * 1024);
    });

    test('a platform exception becomes UnexpectedError', () async {
      onOpen = (_) async => throw PlatformException(code: 'denied');
      final result = await gateway().pickFile(
        extensions: ['json'],
        mimeTypes: ['application/json'],
      );
      expect((result as Err<PickedFile?>).error, isA<UnexpectedError>());
    });

    test('a read failure becomes UnexpectedError', () async {
      onOpen = (_) async => XFile('${cache.path}/does-not-exist.json');
      final result = await gateway().pickFile(
        extensions: ['json'],
        mimeTypes: ['application/json'],
      );
      expect((result as Err<PickedFile?>).error, isA<UnexpectedError>());
    });

    test('desktop reports unavailable', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final result = await gateway().pickFile(extensions: [], mimeTypes: []);
      expect((result as Err<PickedFile?>).error, isA<UnavailableError>());
    });
  });

  group('hygiene', () {
    test('blank subjects are not passed as title or subject', () async {
      for (final subject in <String?>[null, '', '   ']) {
        await gateway().exportFile(
          fileName: 'a.csv',
          mimeType: 'text/csv',
          bytes: const [1],
          subject: subject,
        );
        expect(seen!.subject, isNull, reason: '"$subject"');
        expect(seen!.title, isNull, reason: '"$subject"');
      }
      await gateway().exportFile(
        fileName: 'a.csv',
        mimeType: 'text/csv',
        bytes: const [1],
        subject: ' Weights ',
      );
      expect(seen!.subject, 'Weights');
      expect(seen!.title, 'Weights');
    });

    test('stale export folders are removed, fresh ones kept', () async {
      final parent = exportRoot()..createSync(recursive: true);
      final stale = Directory(
        '${parent.path}${Platform.pathSeparator}export_old',
      )..createSync();
      File('${stale.path}${Platform.pathSeparator}x.csv')
          .writeAsStringSync('x');
      final other = Directory('${parent.path}${Platform.pathSeparator}keep_me')
        ..createSync();

      // Real clock: the leftover is brand new and must survive.
      await gateway().exportFile(
        fileName: 'a.csv',
        mimeType: 'text/csv',
        bytes: const [1],
      );
      expect(stale.existsSync(), isTrue);

      clock = DateTime.now().add(const Duration(hours: 2));
      await gateway().exportFile(
        fileName: 'a.csv',
        mimeType: 'text/csv',
        bytes: const [1],
      );
      expect(stale.existsSync(), isFalse);
      expect(other.existsSync(), isTrue, reason: 'only export_* folders');
    });

    test('the plugin copy of a picked file is deleted after reading', () async {
      final copy = File('${cache.path}${Platform.pathSeparator}pick.json')
        ..writeAsBytesSync([1, 2]);
      onOpen = (_) async => XFile(copy.path);
      final result = await gateway().pickFile(
        extensions: ['json'],
        mimeTypes: ['application/json'],
      );
      expect((result as Ok<PickedFile?>).value!.bytes, [1, 2]);
      expect(copy.existsSync(), isFalse);
    });

    test('a picked file outside the cache is never deleted', () async {
      final elsewhere = await Directory.systemTemp.createTemp('repforge_user_');
      addTearDown(() => elsewhere.delete(recursive: true));
      final original = File('${elsewhere.path}${Platform.pathSeparator}o.json')
        ..writeAsBytesSync([9]);
      onOpen = (_) async => XFile(original.path);
      final result = await gateway().pickFile(
        extensions: ['json'],
        mimeTypes: ['application/json'],
      );
      expect((result as Ok<PickedFile?>).value!.bytes, [9]);
      expect(original.existsSync(), isTrue);
    });

    test('an oversized plugin copy is also deleted when rejected', () async {
      final copy = File('${cache.path}${Platform.pathSeparator}big.json')
        ..writeAsBytesSync(List.filled(11, 0));
      onOpen = (_) async => XFile(copy.path);
      final result = await gateway().pickFile(
        extensions: [],
        mimeTypes: [],
        maxBytes: 10,
      );
      expect((result as Err<PickedFile?>).error, isA<FileTooLargeError>());
      expect(copy.existsSync(), isFalse);
    });

    test('the copy is also deleted when the length check rejects it', () async {
      final copy = File('${cache.path}${Platform.pathSeparator}len.json')
        ..writeAsBytesSync(List.filled(11, 0));
      onOpen = (_) async => XFile(copy.path);
      await gateway().pickFile(extensions: [], mimeTypes: [], maxBytes: 5);
      expect(copy.existsSync(), isFalse);
    });

    group('deletion safety', () {
      late Directory outside;
      setUp(() async {
        outside = await Directory.systemTemp.createTemp('repforge_outside_');
      });
      tearDown(() async {
        if (outside.existsSync()) await outside.delete(recursive: true);
      });

      Future<void> pick(String path) async {
        onOpen = (_) async => XFile(path);
        await gateway().pickFile(extensions: [], mimeTypes: []);
      }

      test('a symlinked directory inside the cache is not followed', () async {
        final original = File(
          '${outside.path}${Platform.pathSeparator}orig.json',
        )..writeAsBytesSync([1]);
        Link('${cache.path}${Platform.pathSeparator}lnk')
            .createSync(outside.path);
        const sep = '/';
        await pick('${cache.path}${sep}lnk${sep}orig.json');
        expect(original.existsSync(), isTrue);
      });

      test('a symlinked file pointing outside is not followed', () async {
        final original = File('${outside.path}${Platform.pathSeparator}o2.json')
          ..writeAsBytesSync([1]);
        final link = Link('${cache.path}${Platform.pathSeparator}o2.json')
          ..createSync(original.path);
        await pick(link.path);
        expect(original.existsSync(), isTrue);
      });

      test('a prefix-sibling directory is not under the root', () async {
        final sibling = Directory('${cache.path}_sibling')..createSync();
        addTearDown(() => sibling.deleteSync(recursive: true));
        final f = File('${sibling.path}${Platform.pathSeparator}s.json')
          ..writeAsBytesSync([1]);
        await pick(f.path);
        expect(f.existsSync(), isTrue);
      });

      test('a .. segment is never deleted', () async {
        final original = File('${cache.path}${Platform.pathSeparator}keep.json')
          ..writeAsBytesSync([1]);
        final sub = Directory('${cache.path}${Platform.pathSeparator}sub')
          ..createSync();
        const sep = '/';
        await pick('${sub.path}$sep..${sep}keep.json');
        expect(original.existsSync(), isTrue);
      });

      test('the root itself or a directory is never deleted', () async {
        await pick(cache.path);
        await pick('${cache.path}${Platform.pathSeparator}');
        expect(cache.existsSync(), isTrue);
      });

      test('a root reached through a symlink alias still matches', () async {
        final alias = Link('${outside.path}${Platform.pathSeparator}alias')
          ..createSync(cache.path);
        final copy = File('${cache.path}${Platform.pathSeparator}a.json')
          ..writeAsBytesSync([1]);
        final viaAlias = '${alias.path}${Platform.pathSeparator}a.json';
        onOpen = (_) async => XFile(viaAlias);
        await gateway().pickFile(extensions: [], mimeTypes: []);
        expect(copy.existsSync(), isFalse);
      });
    });
  });

  group('default wiring through the share_plus method channel', () {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    late Completer<String?> reply;
    late Map<Object?, Object?> args;
    late bool existedWhilePending;
    late String? contentWhilePending;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      reply = Completer<String?>();
      args = {};
      existedWhilePending = false;
      contentWhilePending = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'share');
            args = call.arguments as Map<Object?, Object?>;
            final path = (args['paths']! as List).single as String;
            existedWhilePending = File(path).existsSync();
            contentWhilePending = existedWhilePending
                ? File(path).readAsStringSync()
                : null;
            final value = await reply.future;
            return value;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    ShareAndSelectorUserFileGateway real() =>
        ShareAndSelectorUserFileGateway(tempDirectory: () async => cache);

    Future<Result<ExportOutcome>> run() => real().exportFile(
      fileName: 'weights.csv',
      mimeType: 'text/csv',
      bytes: 'd,v\r\n'.codeUnits,
      subject: 'Weights',
    );

    test(
      'passes the temp path unchanged and cleans up after the reply',
      () async {
        final future = run();
        while (args.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        final path = (args['paths']! as List).single as String;
        expect(path, startsWith(exportRoot().path));
        expect(path, endsWith('weights.csv'));
        expect(existedWhilePending, isTrue);
        expect(contentWhilePending, 'd,v\r\n');
        expect(args['mimeTypes'], ['text/csv']);
        expect(args['subject'], 'Weights');
        expect(args['title'], 'Weights');
        expect(File(path).existsSync(), isTrue, reason: 'still pending');

        reply.complete('com.example.target');
        final result = await future;
        expect((result as Ok<ExportOutcome>).value, ExportOutcome.shared);
        expect(File(path).existsSync(), isFalse);
        expect(exportRoot().listSync(), isEmpty);
      },
    );

    test('maps the result string to the outcome', () async {
      for (final (raw, expected) in [
        ('', ExportOutcome.dismissed),
        (
          'dev.fluttercommunity.plus/share/unavailable',
          ExportOutcome.resultUnknown,
        ),
        ('com.example.target', ExportOutcome.shared),
      ]) {
        reply = Completer<String?>()..complete(raw);
        final result = await run();
        expect((result as Ok<ExportOutcome>).value, expected, reason: raw);
      }
    });
  });
}
