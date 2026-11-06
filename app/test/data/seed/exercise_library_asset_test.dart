import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Allowed values copied from docs/training-taxonomy.md.
const _categories = {
  'push',
  'pull',
  'legs',
  'core',
  'fullBody',
  'cardio',
  'mobility',
};

const _muscles = {
  'chest',
  'frontDelts',
  'sideDelts',
  'rearDelts',
  'triceps',
  'biceps',
  'forearms',
  'upperBack',
  'lats',
  'lowerBack',
  'abs',
  'obliques',
  'glutes',
  'quadriceps',
  'hamstrings',
  'adductors',
  'abductors',
  'calves',
  'fullBody',
};

const _equipment = {
  'barbell',
  'ezBar',
  'trapBar',
  'dumbbell',
  'kettlebell',
  'cable',
  'machine',
  'smithMachine',
  'bench',
  'squatRack',
  'pullUpBar',
  'dipBars',
  'resistanceBand',
  'plate',
  'medicineBall',
  'rings',
  'treadmill',
  'bike',
  'rower',
  'elliptical',
  'skippingRope',
};

const _types = {
  'weighted',
  'bodyweight',
  'assisted',
  'timed',
  'distance',
  'cardio',
};

void main() {
  final root = jsonDecode(
    File('assets/seed/exercise_library.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final exercises = (root['exercises'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  List<String> strings(Object? v) => List<String>.from(v! as List<dynamic>);

  test('header and size', () {
    expect(root['formatVersion'], 1);
    expect(exercises.length, inInclusiveRange(70, 90));
  });

  test('ids and names are unique and well formed', () {
    final ids = exercises.map((e) => e['id'] as String).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(id, matches(RegExp(r'^lib-[a-z0-9]+(-[a-z0-9]+)*$')));
    }
    final names = exercises.map((e) => (e['name'] as String).toLowerCase());
    expect(names.toSet().length, exercises.length);
  });

  test('classification values are in the taxonomy', () {
    for (final e in exercises) {
      final id = e['id'];
      expect(_types, contains(e['type']), reason: '$id type');
      expect(_categories, contains(e['category']), reason: '$id category');
      expect(_muscles, contains(e['primaryMuscle']), reason: '$id primary');
      for (final m in strings(e['secondaryMuscles'])) {
        expect(_muscles, contains(m), reason: '$id secondary');
      }
      for (final q in strings(e['equipment'])) {
        expect(_equipment, contains(q), reason: '$id equipment');
      }
    }
  });

  test('all categories and types are present', () {
    expect(exercises.map((e) => e['category']).toSet(), _categories);
    expect(exercises.map((e) => e['type']).toSet(), _types);
  });

  test('primary is not repeated in secondary', () {
    for (final e in exercises) {
      expect(
        strings(e['secondaryMuscles']),
        isNot(contains(e['primaryMuscle'])),
        reason: '${e['id']}',
      );
    }
  });

  test('aliases never equal a name and most exercises have one', () {
    final names = exercises.map((e) => (e['name'] as String).toLowerCase());
    final nameSet = names.toSet();
    var withAlias = 0;
    for (final e in exercises) {
      final aliases = strings(e['aliases']);
      if (aliases.isNotEmpty) withAlias++;
      for (final a in aliases) {
        expect(nameSet, isNot(contains(a.toLowerCase())), reason: '${e['id']}');
      }
    }
    expect(withAlias / exercises.length, greaterThanOrEqualTo(0.6));
  });

  test('gear-free bodyweight exercises have empty equipment', () {
    const gearFree = [
      'lib-push-up',
      'lib-bodyweight-squat',
      'lib-bodyweight-lunge',
      'lib-glute-bridge',
      'lib-plank',
      'lib-side-plank',
      'lib-wall-sit',
      'lib-burpee',
      'lib-crunch',
      'lib-hip-flexor-stretch',
    ];
    final byId = {for (final e in exercises) e['id'] as String: e};
    for (final id in gearFree) {
      expect(byId, contains(id));
      expect(byId[id]!['equipment'], isEmpty, reason: id);
    }
    expect(strings(byId['lib-pull-up']!['equipment']), contains('pullUpBar'));
  });

  test('assisted exercises mention assisted or band', () {
    final assisted = exercises.where((e) => e['type'] == 'assisted').toList();
    expect(assisted, isNotEmpty);
    for (final e in assisted) {
      final text = [
        e['name'] as String,
        ...strings(e['aliases']),
      ].join(' ').toLowerCase();
      expect(
        text.contains('assisted') || text.contains('band'),
        isTrue,
        reason: '${e['id']}',
      );
    }
  });
}
