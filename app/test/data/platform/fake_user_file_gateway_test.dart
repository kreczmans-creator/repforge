import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/platform/fake_user_file_gateway.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';
import 'package:repforge/ui/error_text.dart';

void main() {
  test('records exports and answers the scripted outcome', () async {
    final fake = FakeUserFileGateway();
    final r = await fake.exportFile(
      fileName: 'a.csv',
      mimeType: 'text/csv',
      bytes: 'x,y'.codeUnits,
      subject: 'S',
    );
    expect((r as Ok<ExportOutcome>).value, ExportOutcome.shared);
    expect(fake.exports.single.fileName, 'a.csv');
    expect(fake.exports.single.text, 'x,y');
    expect(fake.exports.single.subject, 'S');

    fake.exportResult = const Result.ok(ExportOutcome.dismissed);
    expect(
      ((await fake.exportFile(
        fileName: 'b',
        mimeType: 't',
        bytes: [],
      )) as Ok<ExportOutcome>).value,
      ExportOutcome.dismissed,
    );
    fake.exportResult = const Result.err(UnexpectedError('x'));
    expect(
      await fake.exportFile(fileName: 'c', mimeType: 't', bytes: []),
      isA<Err<ExportOutcome>>(),
    );
    expect(fake.exports, hasLength(3));
  });

  test('recorded text decodes UTF-8', () async {
    final fake = FakeUserFileGateway();
    await fake.exportFile(
      fileName: 'a.csv',
      mimeType: 'text/csv',
      bytes: utf8.encode('Größe,日本'),
    );
    expect(fake.exports.single.text, 'Größe,日本');
  });

  test('picks: cancelled by default, then scripted results in order', () async {
    final fake = FakeUserFileGateway();
    expect(
      (await fake.pickFile(
        extensions: ['json'],
        mimeTypes: ['a/b'],
      ) as Ok<PickedFile?>).value,
      isNull,
    );
    fake
      ..queuePick('one.json', [1])
      ..pickResults.add(const Result.err(UnavailableError('no')));
    final first = await fake.pickFile(extensions: [], mimeTypes: []);
    expect((first as Ok<PickedFile?>).value!.name, 'one.json');
    expect(
      await fake.pickFile(extensions: [], mimeTypes: []),
      isA<Err<PickedFile?>>(),
    );
    expect(fake.picks, hasLength(3));
    expect(fake.picks.first.extensions, ['json']);
    expect(fake.picks.first.maxBytes, maxPickedFileBytes);
  });

  test('a scripted file over maxBytes yields FileTooLargeError', () async {
    final fake = FakeUserFileGateway()..queuePick('big.json', [1, 2, 3]);
    final r = await fake.pickFile(extensions: [], mimeTypes: [], maxBytes: 2);
    expect((r as Err<PickedFile?>).error, isA<FileTooLargeError>());
  });

  test('the default provider reports the capability as unavailable', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gateway = container.read(userFileGatewayProvider);
    final e = await gateway.exportFile(fileName: 'a', mimeType: 't', bytes: []);
    expect((e as Err<ExportOutcome>).error, isA<UnavailableError>());
    final p = await gateway.pickFile(extensions: [], mimeTypes: []);
    expect((p as Err<PickedFile?>).error, isA<UnavailableError>());
  });

  test('new errors have user text', () {
    expect(userMessageFor(const UnavailableError('x')), isNotEmpty);
    expect(
      userMessageFor(const FileTooLargeError('x', maxBytes: 1)),
      contains('too large'),
    );
  });
}
