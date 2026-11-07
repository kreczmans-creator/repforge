import 'package:flutter_test/flutter_test.dart';

import 'v8_library_support.dart';

/// WP 8 3b-10, Review C L-6: the history of one exercise selects its
/// sessions without a list of ids, so it works however many sessions there
/// are (more than SQLite's 32,766 host parameters here), in session order
/// (start, then id), with each session's own entries and sets.
void main() {
  late V8LibraryHarness h;

  setUp(() async => h = await V8LibraryHarness.open());
  tearDown(() => h.close());
  tearDownAll(V8LibraryFixture.dispose);

  test('history over 33,000 sessions: every session once, in order, with '
      'its own entries and sets', () async {
    const sessions = 33000;
    final before = [
      for (final s in await h.library.history('ex-rotator')) s.session.id,
    ];
    await h.db.transaction(() async {
      // Start times run backwards against the ids, so the order is the
      // start's, not the insertion's.
      await h.db.customStatement(
        'WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n '
        'WHERE i + 1 < $sessions) '
        'INSERT INTO workout_sessions (id, created_at, updated_at, '
        'deleted_at, name, plan_id, started_at, ended_at, notes) '
        "SELECT printf('s-%05d', i), '2026-01-01T00:00:00.000Z', "
        "'2026-01-01T00:00:00.000Z', NULL, 'Scale', NULL, "
        "printf('2025-%02d-%02dT%02d:%02d:00.000Z', 1 + ($sessions - i) "
        '/ 2880 % 12, 1 + ($sessions - i) / 96 % 28, ($sessions - i) / 4 % '
        "24, ($sessions - i) % 4 * 15), NULL, '' FROM n",
      );
      // Two entries in every session; a set only in every third.
      await h.db.customStatement(
        'INSERT INTO session_exercises (id, session_id, position, '
        "exercise_id, note) SELECT 'se-' || id || '-' || p.k, id, p.k, "
        "'ex-rotator', NULL FROM workout_sessions, (SELECT 1 AS k UNION ALL "
        "SELECT 0) p WHERE workout_sessions.id LIKE 's-%'",
      );
      await h.db.customStatement(
        'INSERT INTO session_sets (id, session_id, exercise_id, '
        'exercise_order, set_order, type, load_kg, reps, completed, '
        'exertion_scale, exertion_value, set_kind, session_exercise_id) '
        "SELECT 'set-' || id, id, 'ex-rotator', 0, 0, 'weighted', 20.0, 8, "
        "1, NULL, NULL, 'working', 'se-' || id || '-0' FROM "
        "workout_sessions WHERE id LIKE 's-%' AND "
        'CAST(substr(id, 3) AS INTEGER) % 3 = 0',
      );
    });
    final expected = [
      for (final r
          in await h.db
              .customSelect(
                'SELECT id FROM workout_sessions WHERE id IN (SELECT '
                'session_id FROM session_exercises WHERE exercise_id = '
                "'ex-rotator' UNION SELECT session_id FROM session_sets WHERE "
                "exercise_id = 'ex-rotator') ORDER BY started_at, id",
              )
              .get())
        r.read<String>('id'),
    ];
    final history = await h.library.history('ex-rotator');
    expect(history.length, sessions + before.length);
    expect([for (final s in history) s.session.id], expected);
    for (final s in history) {
      if (!s.session.id.startsWith('s-')) continue;
      expect([for (final e in s.entries) e.position], [0, 1]);
      expect(s.entries.every((e) => e.sessionId == s.session.id), isTrue);
      final n = int.parse(s.session.id.substring(2));
      expect(
        [for (final x in s.sets) x.id],
        [if (n % 3 == 0) 'set-${s.session.id}'],
      );
    }
  });
}
