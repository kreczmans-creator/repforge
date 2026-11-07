import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/catalogue/bundled_exercise_knowledge_source.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge_source.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/exercise_knowledge_providers.dart';
import 'package:repforge/features/training/application/import_exercise_library.dart';
import 'package:repforge/features/training/presentation/exercise_guidance.dart';
import 'package:repforge/features/training/presentation/exercise_illustration.dart';
import 'package:repforge/ui/theme.dart';

import '../../../domain/exercise_knowledge/support/knowledge_support.dart';
import '../../../helpers/pump.dart';

final _now = DateTime(2026, 11, 7, 9);

const _sections = [
  'visual',
  'overview',
  'starting-position',
  'execution',
  'breathing',
  'cues',
  'mistakes',
  'safety',
  'related',
];

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  var gen = 0;

  setUp(() async {
    db = AppDatabase.inMemory();
    final clock = FixedClock(_now);
    exercises = DriftExerciseRepository(db, clock: clock);
    await ImportExerciseLibrary(
      exercises: exercises,
      settings: DriftSettingsRepository(db, clock: clock),
      clock: clock,
      loadJson: () async =>
          File('assets/seed/exercise_library.json').readAsStringSync(),
    )();
  });
  tearDown(() => db.close());

  Future<void> open(
    WidgetTester tester,
    String id, {
    ExerciseKnowledgeSource? source,
    bool showDrafts = true,
    Size size = const Size(390, 16000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(_now)),
          idGeneratorProvider.overrideWithValue(() => 'gen-${gen++}'),
          exerciseKnowledgeSourceProvider.overrideWithValue(
            source ?? repositorySource(),
          ),
          showDraftExerciseGuidanceProvider.overrideWithValue(showDrafts),
        ],
        child: RepForgeApp(
          router: createRouter(initialLocation: RfRoutes.trainExercise(id)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows sections A to I for a catalogue exercise, in order', (
    tester,
  ) async {
    await open(tester, 'lib-deadlift');
    final tops = <double>[];
    for (final s in _sections) {
      final f = find.byKey(Key('guidance-$s'));
      expect(f, findsOneWidget, reason: s);
      tops.add(tester.getTopLeft(f).dy);
    }
    expect(tops, [...tops]..sort(), reason: 'A to I appear in order');
    expect(find.byKey(const Key('guidance-draft-note')), findsOneWidget);
    // B: description, movement classification and the existing details.
    expect(
      find.textContaining('A barbell lift from the floor'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('knowledge-difficulty')), findsOneWidget);
    expect(find.text('Intermediate'), findsOneWidget);
    expect(find.text('Hinge'), findsOneWidget);
    expect(find.byKey(const Key('field-primary')), findsOneWidget);
    // D: numbered steps with an accessible label.
    expect(find.byKey(const Key('step-1')), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('step-1'))).label,
      startsWith('Step 1 of 4: '),
    );
    // G: fault, why and fix.
    expect(find.text('Rounding the back off the floor.'), findsOneWidget);
    expect(find.text('Why it matters'), findsWidgets);
    expect(find.text('How to fix it'), findsWidgets);
    // H: safety with the general disclaimer.
    expect(find.byKey(const Key('safety-disclaimer')), findsOneWidget);
    // History stays below the guidance.
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('by default (switch off) drafts are not shown: the screen '
      'says the guidance awaits editorial review (KS-D9)', (tester) async {
    expect(showDraftExerciseGuidance, isFalse, reason: 'off by default');
    await open(tester, 'lib-deadlift', showDrafts: false);
    expect(find.byKey(const Key('guidance-awaiting-review')), findsOneWidget);
    for (final s in _sections) {
      expect(find.byKey(Key('guidance-$s')), findsNothing, reason: s);
    }
    expect(find.textContaining('A barbell lift from the floor'), findsNothing);
    expect(find.byKey(const Key('field-primary')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('editor-approved guidance is shown with the switch off, '
      'without the draft note', (tester) async {
    await open(
      tester,
      'lib-deadlift',
      showDrafts: false,
      source: _ApprovedSource(repositorySource()),
    );
    expect(find.byKey(const Key('guidance-execution')), findsOneWidget);
    expect(find.byKey(const Key('guidance-draft-note')), findsNothing);
    await unmount(tester);
  });

  testWidgets('shows several original illustrations in sequence', (
    tester,
  ) async {
    await open(tester, 'lib-deadlift');
    final start = find.byKey(const Key('media-ill-deadlift-start'));
    final finish = find.byKey(const Key('media-ill-deadlift-finish'));
    expect(start, findsOneWidget);
    expect(finish, findsOneWidget);
    expect(
      tester.getTopLeft(start).dx,
      lessThan(tester.getTopLeft(finish).dx),
      reason: 'start before finish, side by side',
    );
    expect(find.byType(ExerciseIllustration), findsNWidgets(2));
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
    expect(find.byKey(const Key('visual-placeholder')), findsNothing);
    await unmount(tester);
  });

  testWidgets('shows the labelled placeholder where no visual exists', (
    tester,
  ) async {
    await open(tester, 'lib-bench-press');
    expect(find.byKey(const Key('visual-placeholder')), findsOneWidget);
    expect(find.text('Illustration not yet available'), findsOneWidget);
    expect(find.byType(ExerciseIllustration), findsNothing);
    await unmount(tester);
  });

  testWidgets('tempo appears only where the content gives one', (tester) async {
    await open(tester, 'lib-back-squat');
    expect(find.text('Breathing and tempo'), findsOneWidget);
    expect(find.byKey(const Key('guidance-tempo-items')), findsOneWidget);
    await unmount(tester);
    await open(tester, 'lib-walking-lunge');
    expect(find.text('Breathing'), findsOneWidget);
    expect(find.byKey(const Key('guidance-tempo-items')), findsNothing);
    await unmount(tester);
  });

  testWidgets('a variation link opens that real exercise', (tester) async {
    await open(tester, 'lib-deadlift');
    final link = find.byKey(const Key('link-lib-sumo-deadlift'));
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Sumo deadlift'), findsWidgets);
    expect(
      find.textContaining('wide stance and the hands inside'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('links are grouped as easier, harder and comparable', (
    tester,
  ) async {
    await open(tester, 'lib-goblet-squat');
    expect(find.text('Easier'), findsOneWidget);
    expect(find.text('Harder'), findsOneWidget);
    expect(find.byKey(const Key('link-lib-bodyweight-squat')), findsOneWidget);
    expect(find.byKey(const Key('link-lib-back-squat')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an exercise without related catalogue exercises says so', (
    tester,
  ) async {
    await open(tester, 'lib-lateral-raise');
    expect(find.byKey(const Key('related-none')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a custom exercise shows the no-instructions state', (
    tester,
  ) async {
    await exercises.upsert(
      Exercise(
        id: 'mine',
        name: 'My cable thing',
        type: ExerciseType.weighted,
        category: ExerciseCategory.pull,
        primaryMuscle: MuscleGroup.lats,
        createdAt: _now.toUtc(),
        updatedAt: _now.toUtc(),
      ),
    );
    await open(tester, 'mine');
    expect(find.byKey(const Key('guidance-none')), findsOneWidget);
    expect(find.textContaining('No instructions yet'), findsOneWidget);
    expect(find.byKey(const Key('guidance-original')), findsNothing);
    expect(find.byKey(const Key('field-primary')), findsOneWidget);
    for (final s in _sections) {
      expect(find.byKey(Key('guidance-$s')), findsNothing);
    }
    await unmount(tester);
  });

  testWidgets('a custom copy points to the guidance of its original', (
    tester,
  ) async {
    await exercises.upsert(
      Exercise(
        id: 'copy',
        name: 'My deadlift',
        type: ExerciseType.weighted,
        category: ExerciseCategory.legs,
        primaryMuscle: MuscleGroup.glutes,
        copiedFromId: 'lib-deadlift',
        createdAt: _now.toUtc(),
        updatedAt: _now.toUtc(),
      ),
    );
    await open(tester, 'copy');
    final button = find.byKey(const Key('guidance-original'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guidance-execution')), findsOneWidget);
    expect(find.text('Conventional deadlift'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('without a bundled catalogue the screen degrades to its '
      'details and history', (tester) async {
    await open(
      tester,
      'lib-deadlift',
      source: BundledExerciseKnowledgeSource(
        readBytes: (_) async => throw StateError('Unable to load asset'),
      ),
    );
    expect(find.byKey(const Key('guidance-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('field-primary')), findsOneWidget);
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a failing source shows an error state, not a crash', (
    tester,
  ) async {
    await open(tester, 'lib-deadlift', source: _ThrowingSource());
    expect(find.byKey(const Key('guidance-error')), findsOneWidget);
    expect(find.byKey(const Key('field-primary')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('fits a small screen without overflow', (tester) async {
    await open(tester, 'lib-back-squat', size: const Size(320, 16000));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('guidance-related')), findsOneWidget);
    await unmount(tester);
  });

  group('every illustration renders in both themes at phone width', () {
    final catalogue = shippedCatalogue();
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} theme', (tester) async {
        tester.view.physicalSize = const Size(320, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final illustrated = [
          for (final k in catalogue.all)
            if (k.media.isNotEmpty) k,
        ];
        for (final k in illustrated) {
          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey('${brightness.name}-${k.id}'),
              overrides: [
                exerciseKnowledgeProvider(k.id.value)
                    .overrideWith((ref) async => KnowledgeFound(k)),
              ],
              child: MaterialApp(
                theme: rfTheme(brightness),
                home: Scaffold(
                  body: ListView(
                    children: [
                      ExerciseGuidance(
                        exercise: Exercise(
                          id: k.id.value,
                          name: k.name,
                          type: ExerciseType.weighted,
                          category: ExerciseCategory.legs,
                          primaryMuscle: MuscleGroup.glutes,
                          supplied: true,
                          createdAt: _now,
                          updatedAt: _now,
                        ),
                        overviewDetails: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${k.id}');
          expect(
            find.byType(ExerciseIllustration),
            findsNWidgets(k.availableMedia.length),
            reason: '${k.id}',
          );
          final label = tester
              .getSemantics(find.byType(ExerciseIllustration).first)
              .label;
          expect(label, contains(k.name));
        }
      });
    }
  });

  test('illustrated poses keep their feet on the floor', () {
    for (final MapEntry(:key, :value) in exerciseIllustrations.entries) {
      if (!value.floor) continue;
      final j = value.joints;
      final lowest = [
        j['nearAnkle'].dy,
        j['nearToe'].dy,
      ].reduce((a, b) => a < b ? a : b);
      expect(lowest, inInclusiveRange(-0.5, 3.5), reason: key);
    }
  });

  group('illustration pose invariants (review L-4)', () {
    Offset at(String key, String joint) =>
        exerciseIllustrations[key]!.joints[joint];

    double angleAt(Offset vertex, Offset a, Offset b) {
      final u = a - vertex;
      final v = b - vertex;
      final cos = (u.dx * v.dx + u.dy * v.dy) / (u.distance * v.distance);
      return math.acos(cos.clamp(-1.0, 1.0)) * 180 / math.pi;
    }

    double elbowAngle(String key) => angleAt(
      at(key, 'nearElbow'),
      at(key, 'shoulder'),
      at(key, 'nearWrist'),
    );

    /// 0 for a straight knee.
    double kneeFlexion(String key) =>
        180 -
        angleAt(at(key, 'nearKnee'), at(key, 'hip'), at(key, 'nearAnkle'));

    test('push-up: the hands stay where they were placed', () {
      final top = at('push-up/start', 'nearWrist');
      final bottom = at('push-up/finish', 'nearWrist');
      expect((top.dx - bottom.dx).abs(), lessThan(1.5));
      expect(top.dy, closeTo(bottom.dy, 0.5));
      expect(bottom.dy, lessThan(2.5), reason: 'hands on the floor');
      expect(
        (at('push-up/finish', 'shoulder').dx - bottom.dx).abs(),
        lessThan(5),
        reason: 'hands under the chest, not behind it',
      );
    });

    test('Romanian deadlift: soft knees, hips back, bar below the knee', () {
      const key = 'romanian-deadlift/finish';
      expect(kneeFlexion(key), inInclusiveRange(10, 25));
      final ankle = at(key, 'nearAnkle');
      expect(at(key, 'hip').dx, lessThan(ankle.dx - 8), reason: 'hips back');
      expect(at(key, 'nearWrist').dy, lessThan(at(key, 'nearKnee').dy));
      expect((at(key, 'nearWrist').dx - ankle.dx).abs(), lessThan(6));
      expect(exerciseIllustrations[key]!.torso, lessThan(25));
    });

    test('pull-up top: elbows deeply bent, chin above the bar', () {
      const key = 'pull-up/finish';
      expect(elbowAngle(key), inInclusiveRange(30, 50));
      final bar = exerciseIllustrations[key]!.props.single.a.dy;
      final chin = at(key, 'head').dy - FigureProportions.headRadius;
      expect(chin, greaterThan(bar));
      expect(at(key, 'nearWrist').dy, closeTo(bar, 0.5));
    });

    test('no bent arm folds closer than 15 degrees', () {
      for (final key in exerciseIllustrations.keys) {
        expect(elbowAngle(key), greaterThan(15), reason: key);
      }
    });

    test('back squat: the hands hold the bar', () {
      for (final key in ['back-squat/start', 'back-squat/finish']) {
        final bar = exerciseIllustrations[key]!.props.firstWhere(
          (p) => p.kind == IllustrationPropKind.bar,
        );
        final wrist = at(key, 'nearWrist');
        expect(wrist.dy, closeTo(bar.a.dy, 0.5), reason: key);
        expect(
          wrist.dx,
          inInclusiveRange(bar.a.dx - 0.5, bar.b.dx + 0.5),
          reason: key,
        );
      }
    });
  });
}

/// Presents every record as approved by a named editor.
class _ApprovedSource implements ExerciseKnowledgeSource {
  _ApprovedSource(this.inner);
  final ExerciseKnowledgeSource inner;

  @override
  Future<KnowledgeLookup> lookup(String exerciseId) async {
    final r = await inner.lookup(exerciseId);
    if (r is! KnowledgeFound) return r;
    final k = r.knowledge;
    return KnowledgeFound(
      ExerciseKnowledge(
        exercise: k.exercise,
        content: k.content,
        media: k.media,
        links: k.links,
        labels: k.labels,
        contentProvenance: ContentProvenance(
          authoredBy: k.contentProvenance!.authoredBy,
          status: ContentStatus.editorApproved,
          draftedOn: k.contentProvenance!.draftedOn,
          editor: 'Test Editor',
          approvedOn: DateTime.utc(2026, 11, 8),
        ),
      ),
    );
  }
}

class _ThrowingSource implements ExerciseKnowledgeSource {
  @override
  Future<KnowledgeLookup> lookup(String exerciseId) async =>
      throw StateError('boom');
}
