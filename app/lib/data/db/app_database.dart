import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'app_database.g.dart';

/// Body-weight entries (requirement BCM-001).
///
/// Every table carries `id`, `createdAt`, `updatedAt` and `deletedAt` so that a
/// sync layer can be added later without a schema rewrite (ADR-0004).
@DataClassName('WeightEntryRow')
class WeightEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get recordedAt => dateTime()();
  RealColumn get weightKg => real()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The application's SQLite database. Schema version history:
///
/// 1. `weight_entries` (WP 1).
@DriftDatabase(tables: [WeightEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Private in-memory database for tests.
  AppDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
