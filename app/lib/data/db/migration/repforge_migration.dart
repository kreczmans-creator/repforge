import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:repforge/data/db/migration/historical_steps.dart';
import 'package:repforge/domain/core/clock.dart';

/// Where in the chain a [MigrationCheckpoint] is reported.
enum MigrationStage {
  /// Inside the step's transaction, before any work.
  stepStarted,

  /// Inside the transaction, after the step's work, before the version write.
  workDone,

  /// Inside the transaction, after `PRAGMA user_version`, before commit.
  versionWritten,

  /// After the step's transaction committed.
  committed,
}

/// A point in the migration chain, reported to a [MigrationProbe].
final class MigrationCheckpoint {
  const MigrationCheckpoint({
    required this.from,
    required this.stage,
    this.reached,
  });

  /// Version the step starts from.
  final int from;

  /// Version the step reached; null before the step has run.
  final int? reached;

  final MigrationStage stage;

  @override
  String toString() => 'v$from→${reached ?? '?'} ${stage.name}';
}

/// Observes the chain at each [MigrationCheckpoint]. A probe that throws
/// inside the transaction rolls the step back. For tests and later kill
/// tests only; production passes none.
typedef MigrationProbe = Future<void> Function(MigrationCheckpoint checkpoint);

/// Builds the migration strategy of a RepForge database from versioned steps
/// (WP 8 stage 3b-3). Used by the test harness now and by schema v8 later;
/// `AppDatabase` does not use it yet.
///
/// The chain:
/// - switches foreign keys off before any transaction and verifies they are
///   off (the pragma is ignored inside a transaction);
/// - runs each step in its own transaction, with `PRAGMA user_version = N`
///   as the last statement inside it, so a step and its version commit or
///   roll back together;
/// - switches foreign keys back on afterwards and verifies they are on;
///   after a failure it restores them too and rethrows the original error.
///
/// `clock` stamps quarantine rows. [steps] defaults to
/// [HistoricalSteps.steps]; v8 will pass the historical steps plus its own,
/// so it is API, not a test seam. [onCreate] is API for the same reason.
/// [probe] is a test seam only (failure and kill tests).
final class RepforgeMigration {
  RepforgeMigration({
    required this.database,
    required Clock clock,
    this.probe,
    MigrationStep? steps,
    this.onCreate,
  }) : steps = steps ?? HistoricalSteps(clock: clock).steps;

  final GeneratedDatabase database;

  /// Test seam (null in the app): sees every [MigrationCheckpoint].
  @visibleForTesting
  final MigrationProbe? probe;

  /// The steps of the chain, dispatched by the version they start from.
  final MigrationStep steps;

  /// Creates a new database; null means `createAll`.
  final Future<void> Function(Migrator m)? onCreate;

  /// The strategy to return from `GeneratedDatabase.migration`. `onCreate`
  /// defaults to `createAll`; `beforeOpen` switches foreign keys on.
  MigrationStrategy get strategy => MigrationStrategy(
    onCreate: onCreate ?? (m) => m.createAll(),
    onUpgrade: (m, from, to) => upgrade(from, to),
    beforeOpen: (_) => _setForeignKeys(on: true),
  );

  /// Runs every step from [from] up to [to].
  Future<void> upgrade(int from, int to) async {
    if (from > to) {
      throw StateError('Cannot migrate down from v$from to v$to.');
    }
    await database.exclusively(() async {
      await _setForeignKeys(on: false);
      try {
        for (var version = from; version < to;) {
          final reached = await _runStep(version, to);
          await _report(version, reached, MigrationStage.committed);
          version = reached;
        }
      } on Object catch (error, stack) {
        // Restore the keys, but never let a restore failure hide the
        // original error: that one says why the migration stopped.
        try {
          await _setForeignKeys(on: true);
        } on Object catch (_) {
          // Ignored on purpose; the original error is rethrown below.
        }
        Error.throwWithStackTrace(error, stack);
      }
      await _setForeignKeys(on: true);
    });
  }

  Future<int> _runStep(int from, int to) => database.transaction(() async {
    await _report(from, null, MigrationStage.stepStarted);
    final reached = await steps(from, database);
    if (reached <= from || reached > to) {
      throw StateError('Step from v$from reached v$reached (target v$to).');
    }
    await _report(from, reached, MigrationStage.workDone);
    await database.customStatement('PRAGMA user_version = $reached');
    await _report(from, reached, MigrationStage.versionWritten);
    return reached;
  });

  Future<void> _report(int from, int? reached, MigrationStage stage) async {
    final p = probe;
    if (p == null) return;
    await p(MigrationCheckpoint(from: from, reached: reached, stage: stage));
  }

  Future<void> _setForeignKeys({required bool on}) async {
    await database.customStatement(
      'PRAGMA foreign_keys = ${on ? 'ON' : 'OFF'}',
    );
    final row = await database.customSelect('PRAGMA foreign_keys').getSingle();
    if (row.read<bool>('foreign_keys') != on) {
      throw StateError(
        'PRAGMA foreign_keys did not switch ${on ? 'on' : 'off'} '
        '(inside a transaction?).',
      );
    }
  }
}
