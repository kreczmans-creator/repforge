import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/catalogue/bundled_exercise_knowledge_source.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge_source.dart';

import '../../domain/exercise_knowledge/support/knowledge_support.dart';

void main() {
  test('retrieves exercise knowledge offline from bundled files', () async {
    await HttpOverrides.runZoned(() async {
      final source = repositorySource();
      final found = await source.lookup('lib-back-squat');
      expect(found, isA<KnowledgeFound>());
      final k = (found as KnowledgeFound).knowledge;
      expect(k.name, 'Barbell back squat');
      expect(k.execution, isNotEmpty);
      expect(k.media, hasLength(2));
      expect(k.primaryTargetLabels, ['Quadriceps']);
    }, createHttpClient: (_) => throw StateError('network access attempted'));
  });

  test(
    'reads each bundled file once and answers later lookups from memory',
    () async {
      final reads = <String>[];
      final source = BundledExerciseKnowledgeSource(
        readBytes: (key) async {
          reads.add(key);
          return await readFromRepository(key);
        },
      );
      await source.lookup('lib-deadlift');
      await source.lookup('lib-pull-up');
      await source.lookup('custom-1');
      expect(reads, [
        BundledExerciseKnowledgeSource.releaseAsset,
        ...BundledExerciseKnowledgeSource.referenceAssets.values,
      ]);
    },
  );

  test('a custom exercise id has no instructions yet', () async {
    expect(
      await repositorySource().lookup('0f7d2c8e-custom'),
      isA<KnowledgeNotAuthored>(),
    );
  });

  test('when the catalogue is not bundled every lookup is unavailable, '
      'without throwing', () async {
    final source = BundledExerciseKnowledgeSource(
      readBytes: (key) async => throw StateError('Unable to load asset'),
    );
    final r = await source.lookup('lib-deadlift');
    expect(r, isA<KnowledgeUnavailable>());
    expect((r as KnowledgeUnavailable).reason, contains('not bundled'));
  });

  test('missing reference files only cost the labels', () async {
    final source = BundledExerciseKnowledgeSource(
      readBytes: (key) async {
        if (key.contains('/reference/')) throw const FileSystemException('x');
        return await readFromRepository(key);
      },
    );
    final r = await source.lookup('lib-deadlift') as KnowledgeFound;
    expect(r.knowledge.primaryTargetLabels, ['glutes']);
    expect(r.knowledge.execution, isNotEmpty);
  });

  test('a corrupt release is unavailable, not a crash', () async {
    final source = BundledExerciseKnowledgeSource(
      readBytes: (key) async => [0xff, 0xfe],
    );
    expect(await source.lookup('lib-deadlift'), isA<KnowledgeUnavailable>());
  });

  test('the asset keys point at the canonical catalogue folder', () {
    expect(
      BundledExerciseKnowledgeSource.releaseAsset,
      'assets/catalogue/releases/repforge-release-3.json',
    );
    expect(
      File(BundledExerciseKnowledgeSource.releaseAsset).existsSync(),
      isTrue,
    );
    for (final path in BundledExerciseKnowledgeSource.referenceAssets.values) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('pubspec does not bundle the catalogue yet (owner decision D-3c-3)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('assets/catalogue')));
  });

  test('a failing catalogue build (for example in the background isolate) '
      'is unavailable, not a crash', () async {
    final source = BundledExerciseKnowledgeSource(
      readBytes: readFromRepository,
      build: (_) async => throw StateError('isolate failed'),
    );
    expect(await source.lookup('lib-deadlift'), isA<KnowledgeUnavailable>());
  });
}
