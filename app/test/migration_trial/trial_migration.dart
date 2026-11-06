import 'package:drift/drift.dart';

import 'trial_db.dart';
import 'trial_fixture.dart' show muscleIds;

/// How `exercises` is changed to the v8 shape.
enum ExercisesOption { none, rebuild, alterColumns }

/// How the TRN-020 rule reaches `session_sets`.
enum Trn020Option { none, rebuild, triggers, alterConstraint }

/// Where a simulated crash happens.
enum CrashPoint {
  none,

  /// Inside the transaction, after the exercises step, before the
  /// foreign-key check and commit.
  afterRebuild,

  /// After the transaction committed, before drift writes `user_version`.
  beforeUserVersion,

  /// Inside the TRN-020 step, after values are cleared, before the
  /// constraint exists.
  insideTrn020,

  /// Inside the transaction, after `PRAGMA user_version = 8` was written.
  afterVersionInTransaction,
}

/// One migration run's configuration and observations.
final class TrialPlan {
  TrialPlan({
    this.exercises = ExercisesOption.none,
    this.trn020 = Trn020Option.none,
    this.crash = CrashPoint.none,
    this.midTransaction,
    this.writeVersionInTransaction = false,
    this.injectFkViolation = false,
    this.fkScope,
  });

  final ExercisesOption exercises;
  final Trn020Option trn020;
  final CrashPoint crash;

  /// Writes `PRAGMA user_version = 8` as the last statement of the
  /// transaction (recommended; drift writes it again after `beforeOpen`).
  final bool writeVersionInTransaction;

  /// Inserts an orphan `exercise_targets` row (keys are off) before the
  /// foreign-key check, to prove that the check aborts and rolls back.
  final bool injectFkViolation;

  /// Tables whose foreign keys are checked; null checks the whole database.
  final List<String>? fkScope;

  /// Called inside the transaction after the exercises step (used to copy
  /// the database files while a transaction is open).
  final Future<void> Function()? midTransaction;

  /// Milliseconds per step, filled by the run.
  final Map<String, int> laps = {};

  /// Foreign-key state seen at the start of `onUpgrade` and after open.
  bool? keysAtStart;
  bool? keysAfterOpen;

  /// Rows the migration report would list.
  final Map<String, int> report = {};
}

final class SimulatedCrash implements Exception {
  const SimulatedCrash(this.where);
  final String where;
  @override
  String toString() => 'SimulatedCrash($where)';
}

const _systemCase = "CASE WHEN supplied = 1 THEN 'system' ELSE 'user' END";

/// Database used only by the trial. Its `onUpgrade` follows the plan's
/// section 6 and safeguard A. It never touches production code.
class TrialDb extends GeneratedDatabase {
  TrialDb(super.executor, this.plan);

  final TrialPlan plan;

  late final TrialExercisesV8 exercises = TrialExercisesV8(this);
  late final TrialSessionSetsV8 sessionSets = TrialSessionSetsV8(this);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => [exercises, sessionSets];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [exercises, sessionSets];

  @override
  int get schemaVersion => 8;

  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from != 7) throw StateError('trial migrates v7 only');
      await _upgrade(m);
    },
    beforeOpen: (details) async {
      if (plan.crash == CrashPoint.beforeUserVersion && details.hadUpgrade) {
        throw const SimulatedCrash('before user_version');
      }
      await customStatement('PRAGMA foreign_keys = ON');
      plan.keysAfterOpen = await _foreignKeysOn();
    },
  );

  Future<bool> _foreignKeysOn() async => (await customSelect(
    'PRAGMA foreign_keys',
  ).getSingle()).read<bool>('foreign_keys');

  Future<bool> _columnExists(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info("$table")').get();
    return rows.any((r) => r.read<String>('name') == column);
  }

  void _lap(String name, Stopwatch sw) {
    plan.laps[name] = (plan.laps[name] ?? 0) + sw.elapsedMilliseconds;
    sw.reset();
  }

  /// Creates the v8 tables in an empty file (used to compare shapes).
  Future<void> createFresh() => createMigrator().createAll();

  /// Safeguard A: disable enforcement outside the transaction, run the whole
  /// migration in one transaction, check foreign keys before commit, commit,
  /// restore enforcement and verify it.
  Future<void> _upgrade(Migrator m) => exclusively(() async {
    final total = Stopwatch()..start();
    final sw = Stopwatch()..start();
    final keysOn = await _foreignKeysOn();
    plan.keysAtStart = keysOn;
    if (keysOn) await customStatement('PRAGMA foreign_keys = OFF');
    if (await _foreignKeysOn()) {
      throw StateError('foreign keys still on before the transaction');
    }
    try {
      await transaction(() async {
        if (plan.exercises != ExercisesOption.none &&
            await _columnExists('exercises', 'primary_muscle')) {
          await _backfillTargets();
          _lap('backfill', sw);
          if (plan.exercises == ExercisesOption.rebuild) {
            await _rebuildExercises(m);
          } else {
            await _alterExercises();
          }
          _lap('exercises', sw);
          await plan.midTransaction?.call();
          if (plan.crash == CrashPoint.afterRebuild) {
            throw const SimulatedCrash('after rebuild, before commit');
          }
        }
        if (plan.trn020 != Trn020Option.none) {
          await _trn020(m);
          _lap('trn020', sw);
        }
        if (plan.injectFkViolation) {
          await customStatement(
            'INSERT INTO exercise_targets VALUES '
            "('orphan-exercise', 'chest', 'primary', 0)",
          );
        }
        final scope = plan.fkScope;
        final bad = [
          if (scope == null)
            ...await customSelect('PRAGMA foreign_key_check').get()
          else
            for (final t in scope)
              ...await customSelect('PRAGMA foreign_key_check("$t")').get(),
        ];
        _lap('fkcheck', sw);
        if (bad.isNotEmpty) {
          throw StateError('foreign_key_check found ${bad.length} rows');
        }
        if (plan.writeVersionInTransaction) {
          await customStatement('PRAGMA user_version = 8');
          if (plan.crash == CrashPoint.afterVersionInTransaction) {
            throw const SimulatedCrash('after user_version, before commit');
          }
        }
      });
      _lap('commit', sw);
    } finally {
      if (keysOn) await customStatement('PRAGMA foreign_keys = ON');
    }
    if (keysOn && !await _foreignKeysOn()) {
      throw StateError('foreign keys not restored');
    }
    plan.laps['total'] = total.elapsedMilliseconds;
  });

  /// Steps 2 and 3 of plan section 6 for the muscle columns: reference rows,
  /// `exercise_targets`, and the migration report. The same in both options.
  Future<void> _backfillTargets() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS anatomy_nodes (id TEXT NOT NULL PRIMARY KEY)',
    );
    for (final n in muscleIds) {
      await customStatement(
        'INSERT OR IGNORE INTO anatomy_nodes (id) VALUES (?)',
        [n],
      );
    }
    await customStatement('''
CREATE TABLE IF NOT EXISTS exercise_targets (
  exercise_id TEXT NOT NULL REFERENCES exercises (id) ON DELETE CASCADE,
  node_id TEXT NOT NULL REFERENCES anatomy_nodes (id),
  role TEXT NOT NULL CHECK (role IN ('primary', 'secondary')),
  ordinal INTEGER NOT NULL,
  PRIMARY KEY (exercise_id, node_id)
)''');
    await customStatement('''
INSERT INTO exercise_targets (exercise_id, node_id, role, ordinal)
SELECT id, primary_muscle, 'primary', 0 FROM exercises
WHERE primary_muscle IN (SELECT id FROM anatomy_nodes)''');
    await customStatement('''
INSERT INTO exercise_targets (exercise_id, node_id, role, ordinal)
SELECT e.id, j.value, 'secondary', MIN(j.key) + 1
FROM exercises e, json_each(e.secondary_muscles_json) j
WHERE j.value IN (SELECT id FROM anatomy_nodes)
  AND j.value <> e.primary_muscle
GROUP BY e.id, j.value''');
    // Unmapped values keep their exercise row; the original goes to
    // legacy_quarantine (plan section 6, step 5).
    await customStatement('''
INSERT INTO legacy_quarantine
  (source_table, row_id, reason, original_json, quarantined_at)
SELECT 'exercises', id, 'unmapped primary muscle',
       json_object('primary_muscle', primary_muscle),
       '2026-11-06T00:00:00.000Z'
FROM exercises WHERE primary_muscle NOT IN (SELECT id FROM anatomy_nodes)''');
    await customStatement('''
INSERT INTO legacy_quarantine
  (source_table, row_id, reason, original_json, quarantined_at)
SELECT 'exercises', e.id, 'unmapped secondary muscle',
       json_object('secondary_muscle', j.value),
       '2026-11-06T00:00:00.000Z'
FROM exercises e, json_each(e.secondary_muscles_json) j
WHERE j.value NOT IN (SELECT id FROM anatomy_nodes)''');
    Future<int> one(String sql) async =>
        (await customSelect(sql).getSingle()).read<int>('c');
    plan.report['secondaryEqualToPrimary'] = await one(
      'SELECT count(*) AS c FROM exercises e, '
      'json_each(e.secondary_muscles_json) j WHERE j.value = e.primary_muscle',
    );
    plan.report['duplicateWithinList'] = await one(
      'SELECT count(*) AS c FROM (SELECT 1 FROM exercises e, '
      'json_each(e.secondary_muscles_json) j GROUP BY e.id, j.value '
      'HAVING count(*) > 1)',
    );
    plan.report['fullBodySecondary'] = await one(
      'SELECT count(*) AS c FROM exercises e, '
      "json_each(e.secondary_muscles_json) j WHERE j.value = 'fullBody'",
    );
  }

  /// Option A: drift `TableMigration`. Copies into the v8 shape; the muscle
  /// and `supplied` columns are not in the new table.
  Future<void> _rebuildExercises(Migrator m) => m.alterTable(
    TableMigration(
      exercises,
      columnTransformer: {
        exercises.source: const CustomExpression<String>(_systemCase),
        exercises.providerId: const CustomExpression<String>(
          "CASE WHEN supplied = 1 THEN 'repforge' END",
        ),
        exercises.revision: const CustomExpression<int>(
          'CASE WHEN supplied = 1 THEN 1 END',
        ),
      },
      newColumns: [
        exercises.mechanics,
        exercises.laterality,
        exercises.difficulty,
        exercises.retiredAt,
      ],
    ),
  );

  /// Option B3: ALTER TABLE ADD COLUMN, UPDATE, then DROP COLUMN.
  Future<void> _alterExercises() async {
    const adds = {
      'source':
          "TEXT NOT NULL DEFAULT 'user' "
          "CHECK (source IN ('system', 'user', 'imported'))",
      'provider_id': 'TEXT NULL',
      'revision': 'INTEGER NULL CHECK (revision IS NULL OR revision >= 1)',
      'mechanics': "TEXT NULL CHECK (mechanics IN ('compound', 'isolation'))",
      'laterality':
          'TEXT NULL CHECK (laterality IN '
          "('bilateral', 'unilateral', 'alternating'))",
      'difficulty':
          'TEXT NULL CHECK (difficulty IN '
          "('beginner', 'intermediate', 'advanced'))",
      'retired_at': 'TEXT NULL',
    };
    for (final e in adds.entries) {
      if (!await _columnExists('exercises', e.key)) {
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN ${e.key} ${e.value}',
        );
      }
    }
    await customStatement('''
UPDATE exercises SET
  source = $_systemCase,
  provider_id = CASE WHEN supplied = 1 THEN 'repforge' END,
  revision = CASE WHEN supplied = 1 THEN 1 END''');
    for (final c in ['primary_muscle', 'secondary_muscles_json', 'supplied']) {
      if (await _columnExists('exercises', c)) {
        await customStatement('ALTER TABLE exercises DROP COLUMN $c');
      }
    }
  }

  /// TRN-020 on `session_sets`: quarantine and clear values the rule rejects,
  /// then enforce the rule by rebuild (CHECK) or by triggers.
  Future<void> _trn020(Migrator m) async {
    final bad = '(${exertionRuleSql()}) = 0';
    await customStatement('''
INSERT INTO legacy_quarantine
  (source_table, row_id, reason, original_json, quarantined_at)
SELECT 'session_sets', id, 'TRN-020 exertion outside the rule',
       json_object('exertion_scale', exertion_scale,
                   'exertion_value', exertion_value),
       '2026-11-06T00:00:00.000Z'
FROM session_sets WHERE $bad''');
    plan.report['exertionCleared'] = (await customSelect(
      'SELECT count(*) AS c FROM session_sets WHERE $bad',
    ).getSingle()).read<int>('c');
    await customStatement(
      'UPDATE session_sets SET exertion_scale = NULL, exertion_value = NULL '
      'WHERE $bad',
    );
    if (plan.crash == CrashPoint.insideTrn020) {
      throw const SimulatedCrash('inside the TRN-020 step');
    }
    if (plan.trn020 == Trn020Option.rebuild) {
      final sql = (await customSelect(
        "SELECT sql FROM sqlite_master WHERE name = 'session_sets'",
      ).getSingle()).read<String>('sql');
      if (!sql.contains("exertion_scale = 'rir'")) {
        await m.alterTable(TableMigration(sessionSets));
      }
    } else if (plan.trn020 == Trn020Option.alterConstraint) {
      final sql = (await customSelect(
        "SELECT sql FROM sqlite_master WHERE name = 'session_sets'",
      ).getSingle()).read<String>('sql');
      if (!sql.contains('CONSTRAINT trn020')) {
        await customStatement(
          'ALTER TABLE session_sets ADD CONSTRAINT trn020 '
          'CHECK (${exertionRuleSql().replaceAll('\n', ' ')})',
        );
      }
    } else {
      final newRule = exertionRuleSql(
        scale: 'NEW.exertion_scale',
        value: 'NEW.exertion_value',
      );
      for (final (name, event) in [
        ('trg_session_sets_exertion_ins', 'INSERT'),
        (
          'trg_session_sets_exertion_upd',
          'UPDATE OF exertion_scale, exertion_value',
        ),
      ]) {
        await customStatement('''
CREATE TRIGGER IF NOT EXISTS $name BEFORE $event ON session_sets
WHEN NOT ($newRule)
BEGIN SELECT RAISE(ABORT, 'TRN-020: exertion outside the rule'); END''');
      }
    }
  }
}
