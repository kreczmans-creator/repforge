import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/name_rules.dart';
import 'package:repforge/domain/library/text_normalisation.dart';

import 'support/catalogue_fixtures.dart';

void main() {
  group('norm and squash (IC-500)', () {
    test('lower-case, separators to space, apostrophes deleted', () {
      expect(norm('Push-up'), 'push up');
      expect(norm("Farmer's carry"), 'farmers carry');
      expect(norm('Farmer’s carry'), 'farmers carry');
      expect(norm('Cat–cow / Thread_the_needle'), 'cat cow thread the needle');
      expect(norm('  Wide   grip  '), 'wide grip');
      expect(norm('Dumbbell (seated)!'), 'dumbbell seated');
    });

    test('diacritics are folded and combining marks removed', () {
      expect(norm('Crème brûlée'), 'creme brulee');
      expect(norm('Ångström'), 'angstrom');
      expect(norm('é'), 'e');
      expect(norm('Straße'), 'strasse');
    });

    test('squash removes all spaces', () {
      expect(squash('Push-up'), 'pushup');
      expect(squash('Pull up'), squash('Pullup'));
      expect(squash("Farmer's walk"), squash('Farmers walk'));
    });

    test('name tokens drop stop words and a trailing s', () {
      expect(nameTokens('Barbell back squat'), {'barbell', 'back', 'squat'});
      expect(nameTokens('Squat with the bar and a box'), {
        'squat',
        'bar',
        'box',
      });
      expect(nameTokens('Dips'), {'dip'});
      expect(nameTokens('Abs'), {'abs'}); // three letters or fewer keep the s
      expect(nameTokens('Glutes of Steel'), {'glute', 'steel'});
    });

    test('jaccard and bounded Levenshtein', () {
      expect(jaccard<String>({}, {}), 1);
      expect(jaccard({'a', 'b'}, {'b', 'c'}), closeTo(1 / 3, 1e-9));
      expect(boundedLevenshtein('push up', 'pull up', 2), 2);
      expect(boundedLevenshtein('abduction', 'adduction', 2), 1);
      expect(boundedLevenshtein('abc', 'abc', 2), 0);
      expect(boundedLevenshtein('abc', 'xyzxyz', 2), 3); // limit + 1
      expect(boundedLevenshtein('squat', 'deadlift', 2), 3);
    });
  });

  List<Finding> names(List<dynamic> list) => validateNames(list.cast());

  group('uniqueness (IC-501 to IC-504)', () {
    test('IC-501 the same normalised name', () {
      final f = names([
        exercise('lib-a', name: 'Push-up'),
        exercise('lib-b', name: 'push up'),
      ]);
      expect(f.withCode('IC-501').single.severity, Severity.error);
    });

    test('IC-502 names equal once spaces are removed', () {
      final f = names([
        exercise('lib-a', name: 'Pull-up'),
        exercise('lib-b', name: 'Pullup'),
      ]);
      expect(f.codes, contains('IC-502'));
    });

    test('IC-502 an alias equals the own name once spaces are removed', () {
      final f = names([
        exercise('lib-a', name: 'Pull-up', aliases: const ['Pullup']),
      ]);
      expect(f.withCode('IC-502').single.severity, Severity.error);
    });

    test('IC-504 an alias equals the own name', () {
      final f = names([
        exercise('lib-a', name: 'Pull-up', aliases: const ['pull up']),
      ]);
      expect(f.withCode('IC-504'), hasLength(1));
      expect(f.codes, isNot(contains('IC-502')));
    });

    test('IC-503 an alias equals another exercise name or alias', () {
      final byName = names([
        exercise('lib-a', name: 'Farmer’s walk'),
        exercise('lib-b', name: 'Carry', aliases: const ['Farmers walk']),
      ]);
      expect(byName.withCode('IC-503'), hasLength(1));
      final byAlias = names([
        exercise('lib-a', name: 'Alpha', aliases: const ['Common name']),
        exercise('lib-b', name: 'Beta', aliases: const ['common-name']),
      ]);
      expect(byAlias.withCode('IC-503'), hasLength(1));
      final sameExercise = names([
        exercise('lib-a', name: 'Alpha', aliases: const ['Dup one', 'dup-one']),
      ]);
      expect(sameExercise.codes, contains('IC-503'));
    });

    test('L3: two identical aliases on one exercise are IC-503', () {
      final f = names([
        exercise(
          'lib-a',
          name: 'Alpha',
          aliases: const ['Same one', 'Same one'],
        ),
      ]);
      expect(f.withCode('IC-503'), hasLength(1));
    });

    test('distinct names and aliases pass', () {
      expect(
        names([
          exercise(
            'lib-a',
            name: 'Barbell back squat',
            aliases: const ['Back squat'],
          ),
          exercise(
            'lib-b',
            name: 'Barbell front squat',
            aliases: const ['Front squat'],
          ),
        ]).where((f) => f.severity == Severity.error),
        isEmpty,
      );
    });

    test('collisions that involve user content only warn', () {
      final f = names([
        exercise('lib-a', name: 'Push-up'),
        exercise('user-1', name: 'Push up', source: ExerciseSource.user),
      ]);
      expect(f.withCode('IC-501').single.severity, Severity.warning);
    });

    test('retired exercises do not take part', () {
      final f = names([
        exercise('lib-a', name: 'Push-up'),
        exercise('lib-b', name: 'Push up', retiredAt: fixtureTime),
      ]);
      expect(f.codes, isNot(contains('IC-501')));
    });
  });

  group('IC-505 to IC-509', () {
    test('IC-505 more than six aliases or an alias over 60 characters', () {
      expect(
        names([
          exercise(
            'lib-a',
            name: 'Alpha',
            aliases: [for (var i = 0; i < 7; i++) 'Alias number $i'],
          ),
        ]).codes,
        contains('IC-505'),
      );
      expect(
        names([
          exercise(
            'lib-a',
            name: 'Alpha',
            aliases: [List.filled(61, 'x').join()],
          ),
        ]).codes,
        contains('IC-505'),
      );
      expect(
        names([
          exercise(
            'lib-a',
            name: 'Alpha',
            aliases: [for (var i = 0; i < 6; i++) 'Alias number $i'],
          ),
        ]).codes,
        isNot(contains('IC-505')),
      );
    });

    test('IC-506 blocked words', () {
      expect(
        names([exercise('lib-a', name: 'Ultimate chest blaster')]).codes,
        contains('IC-506'),
      );
      expect(
        names([
          exercise('lib-a', name: 'Chest press', aliases: const ['Nike press']),
        ]).codes,
        contains('IC-506'),
      );
      expect(
        names([exercise('lib-a', name: 'Chest press')]).codes,
        isNot(contains('IC-506')),
      );
    });

    test('IC-507 US spelling and sentence case', () {
      expect(
        names([exercise('lib-a', name: 'Center row')]).codes,
        contains('IC-507'),
      );
      expect(
        names([exercise('lib-a', name: 'Lat Pulldown')]).codes,
        contains('IC-507'),
      );
      expect(
        names([exercise('lib-a', name: 'lat pulldown')]).codes,
        contains('IC-507'),
      );
      for (final ok in [
        'Lat pulldown',
        'Romanian deadlift',
        'EZ bar curl',
        '400 m run',
        'Push-up',
        "World's greatest stretch",
        'Bulgarian split squat',
      ]) {
        expect(
          names([exercise('lib-a', name: ok)]).codes,
          isNot(contains('IC-507')),
          reason: ok,
        );
      }
      expect(
        names([exercise('lib-a', name: 'Single-Arm row')]).codes,
        contains('IC-507'),
      );
    });

    test('IC-508 names within edit distance 2', () {
      final f = names([
        exercise('lib-a', name: 'Machine hip abduction'),
        exercise('lib-b', name: 'Machine hip adduction'),
        exercise('lib-c', name: 'Barbell back squat'),
      ]);
      expect(f.withCode('IC-508'), hasLength(1));
      expect(f.withCode('IC-508').single.related, ['lib-b']);
    });

    test('IC-509 known synonym pairs', () {
      final f = names([
        exercise('lib-a', name: 'Press-up'),
        exercise('lib-b', name: 'Push-up'),
      ]);
      expect(f.codes, contains('IC-509'));
      final g = names([
        exercise('lib-a', name: 'Wide press-up'),
        exercise('lib-b', name: 'Wide push-up'),
      ]);
      expect(g.codes, contains('IC-509'));
      expect(
        names([
          exercise('lib-a', name: 'Jump rope'),
          exercise('lib-b', name: 'Skipping'),
        ]).codes,
        contains('IC-509'),
      );
      expect(
        names([
          exercise('lib-a', name: 'Push-up'),
          exercise('lib-b', name: 'Dips'),
        ]).codes,
        isNot(contains('IC-509')),
      );
    });
  });

  test('other locales are checked separately and en-GB is not affected', () {
    final base = exercise('lib-a', name: 'Alpha');
    final a = base.copyWith(
      names: ExerciseNames(const {
        'en-GB': LocalizedName('Alpha'),
        'de-DE': LocalizedName('Liegestütz'),
      }),
    );
    final b = exercise('lib-b', name: 'Beta').copyWith(
      names: ExerciseNames(const {
        'en-GB': LocalizedName('Beta'),
        'de-DE': LocalizedName('Liegestutz'),
      }),
    );
    final f = validateNames([a, b]);
    expect(f.withCode('IC-501').single.message, contains('de-DE'));
  });
}
