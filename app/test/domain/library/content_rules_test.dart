import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/catalogue_records.dart';
import 'package:repforge/domain/library/content_rules.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';

import 'support/catalogue_fixtures.dart';

ContentSection row(
  String ex,
  String kind,
  int ordinal,
  String body, {
  String locale = 'en-GB',
}) => ContentSection(
  exerciseId: ExerciseId(ex),
  locale: locale,
  kind: kind,
  ordinal: ordinal,
  body: body,
);

List<ContentSection> good(String ex) => [
  row(ex, 'setup', 0, 'Set the bench to a flat position.'),
  row(ex, 'setup', 1, 'Lie back and plant both feet.'),
  row(ex, 'execution', 0, 'Lower the bar to your chest slowly.'),
  row(ex, 'execution', 1, 'Press the bar back up in a straight line.'),
  row(ex, 'execution', 2, 'Pause briefly at the top of each rep.'),
  row(ex, 'breathing', 0, 'Breathe in as you lower. Breathe out as you press.'),
  row(
    ex,
    'commonMistakes',
    0,
    'Bouncing the bar off the chest. Lower it under control.',
  ),
  row(ex, 'commonMistakes', 1, 'Lifting the hips. Keep them on the bench.'),
];

void main() {
  final e1 = exercise('lib-a');

  List<Finding> run(List<ContentSection> rows, {bool strict = false}) =>
      validateContent(
        [e1, exercise('lib-b')],
        rows,
        missingContentIsError: strict,
      );

  test('complete, well-formed content has no finding for its exercise', () {
    final f = run(good('lib-a')).where((x) => x.subjectId == 'lib-a');
    expect(f.where((x) => x.code != 'IC-210'), isEmpty);
    expect(f.withCode('IC-210'), isEmpty);
  });

  group('IC-210 the four sections', () {
    test(
      'missing sections are a warning, an error when the tranche is complete',
      () {
        final f = run(const []);
        expect(f.withCode('IC-210'), hasLength(2));
        expect(f.withCode('IC-210').first.severity, Severity.warning);
        expect(
          run(const [], strict: true).withCode('IC-210').first.severity,
          Severity.error,
        );
      },
    );

    test('a section with only blank text counts as missing', () {
      final rows = [...good('lib-a')]
        ..removeWhere((r) => r.kind == 'breathing')
        ..add(row('lib-a', 'breathing', 0, '          '));
      final f = run(rows)
          .where((x) => x.subjectId == 'lib-a' && x.code == 'IC-210');
      expect(f.single.message, contains('breathing'));
    });

    test('retired and user exercises are not required to have content', () {
      final f = validateContent([
        exercise('lib-r', retiredAt: fixtureTime),
        exercise('u1', source: ExerciseSource.user),
      ], const []);
      expect(f, isEmpty);
    });
  });

  group('item rules', () {
    List<Finding> one(String kind, String body, {int count = 1}) {
      final rows = [...good('lib-a')]
        ..removeWhere((r) => r.kind == kind)
        ..addAll([for (var i = 0; i < count; i++) row('lib-a', kind, i, body)]);
      return run(rows).where((f) => f.subjectId == 'lib-a').toList();
    }

    test('IC-701 length 10 to 200', () {
      expect(one('breathing', 'Too short').codes, contains('IC-701'));
      expect(one('breathing', '${'Word. ' * 40}end').codes, contains('IC-701'));
      expect(one('breathing', 'Exactly ten').codes, isNot(contains('IC-701')));
    });

    test('IC-702 item counts per section', () {
      expect(
        one('setup', 'Set the bench to a flat position.').codes,
        contains('IC-702'),
      );
      expect(
        one('setup', 'Set the bench to a flat position.', count: 6).codes,
        contains('IC-702'),
      );
      expect(
        one('setup', 'Set the bench to a flat position.', count: 2).codes,
        isNot(contains('IC-702')),
      );
      expect(
        one('breathing', 'Breathe in at the bottom.', count: 3).codes,
        contains('IC-702'),
      );
    });

    test('IC-703 sentence over 20 words', () {
      final long = 'Lower the bar ${List.filled(20, 'slowly').join(' ')} down.';
      expect(
        one('breathing', long).withCode('IC-703').single.severity,
        Severity.warning,
      );
    });

    test('IC-704 medical and outcome claims are errors', () {
      for (final claim in [
        'This will cure back pain for good.',
        'Helps to heal the shoulder joint.',
        'Use it to rehabilitate a knee injury.',
        'It will burn fat fast, guaranteed.',
        'This can prevent injury in the gym.',
        'A way to reduce pain in the knee.',
      ]) {
        expect(
          one('breathing', claim).withCode('IC-704').single.severity,
          Severity.error,
          reason: claim,
        );
      }
      expect(
        one('breathing', 'Breathe in at the bottom. Breathe out up.').codes,
        isNot(contains('IC-704')),
      );
    });

    test('IC-705 prescriptions', () {
      for (final p in [
        'Do 10 reps with a light weight.',
        'Use 3 sets of a moderate load.',
        'Load 20 kg on the bar plates.',
        'Lift at 80% of your best.',
        'Do 3x10 with a steady pace.',
      ]) {
        expect(one('breathing', p).codes, contains('IC-705'), reason: p);
      }
      expect(
        one('breathing', 'Breathe in at the bottom.').codes,
        isNot(contains('IC-705')),
      );
    });

    test('IC-706 US spelling and non-metric units', () {
      expect(
        one('breathing', 'Keep the color of the bar tape.').codes,
        contains('IC-706'),
      );
      expect(
        one('breathing', 'Hold it for one meter of travel.').codes,
        contains('IC-706'),
      );
      expect(
        one('breathing', 'Move the bar six inches away.').codes,
        contains('IC-706'),
      );
      expect(
        one('breathing', 'Keep the feet hip width apart.').codes,
        isNot(contains('IC-706')),
      );
    });

    test('IC-707 possible passive voice', () {
      expect(
        one('breathing', 'The bar is placed across the upper back.').codes,
        contains('IC-707'),
      );
      expect(
        one('breathing', 'Hold the bar across the upper back.').codes,
        isNot(contains('IC-707')),
      );
    });

    test('IC-710 a mistake without a fix', () {
      expect(
        one(
          'commonMistakes',
          'Bouncing the bar off the chest',
          count: 2,
        ).withCode('IC-710'),
        isNotEmpty,
      );
      expect(
        one(
          'commonMistakes',
          'Bouncing the bar. Lower it under control.',
          count: 2,
        ).codes,
        isNot(contains('IC-710')),
      );
    });

    test('an unknown section kind is not in the controlled list (IC-308)', () {
      // `cues` joined the controlled list with release format 2
      // specification revision 2; an uncontrolled kind is still refused.
      final rows = [
        ...good('lib-a'),
        row('lib-a', 'warmUpDrills', 0, 'Keep the chest tall and proud.'),
      ];
      expect(run(rows).codes, contains('IC-308'));
    });
  });

  group('cross-exercise and locale rules', () {
    test('IC-708 identical or near-identical text across exercises', () {
      final rows = [...good('lib-a'), ...good('lib-b')];
      final f = run(rows).withCode('IC-708');
      expect(f, isNotEmpty);
      expect(f.first.severity, Severity.warning);
      final distinct = [...good('lib-a')];
      expect(run(distinct).codes, isNot(contains('IC-708')));
      final nearly = [
        ...good('lib-a'),
        row('lib-b', 'execution', 0, 'Lower the bar to your chest slowly!'),
      ];
      expect(run(nearly).withCode('IC-708'), isNotEmpty);
    });

    test('IC-709 a locale without an en-GB counterpart', () {
      final rows = [
        ...good('lib-a'),
        row('lib-a', 'setup', 0, 'Stelle die Bank flach ein.', locale: 'de-DE'),
      ];
      expect(run(rows).codes, isNot(contains('IC-709')));
      final onlyGerman = [
        row(
          'lib-b',
          'commonMistakes',
          0,
          'Den Rücken runden. Rücken gerade halten.',
          locale: 'de-DE',
        ),
        row(
          'lib-b',
          'commonMistakes',
          1,
          'Zu schnell senken. Langsam senken bitte.',
          locale: 'de-DE',
        ),
      ];
      expect(run(onlyGerman).where((f) => f.code == 'IC-709'), isNotEmpty);
    });

    test('ED-701 content for an unknown exercise', () {
      final f = run([
        row('lib-ghost', 'setup', 0, 'Set the bench to a flat position.'),
      ]);
      expect(f.withCode('ED-701').single.severity, Severity.error);
    });
  });
}
