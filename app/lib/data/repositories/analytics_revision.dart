import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';

/// Emits once for every write to a table the analytics read: logged sets and
/// sessions, food entries, measurements, goals and settings. The analytics
/// providers watch it so any edit, including one to an old row or a single
/// set, recomputes the figures (TRN-024(1)). Read-only: it only listens to
/// drift's table updates.
Stream<void> analyticsTableUpdates(AppDatabase db) => db.tableUpdates(
  TableUpdateQuery.onAllTables([
    db.sessionSets,
    db.workoutSessions,
    db.foodLogEntries,
    db.measurements,
    db.goals,
    db.settings,
  ]),
);
