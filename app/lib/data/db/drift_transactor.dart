import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/transactor.dart';

/// [Transactor] over a drift transaction. drift nests `transaction` calls as
/// savepoints, so repositories that open their own transaction (such as
/// PrepBatchRepository.consume) work inside [run].
final class DriftTransactor implements Transactor {
  const DriftTransactor(this._db);

  final AppDatabase _db;

  @override
  Future<T> run<T>(Future<T> Function() action) => _db.transaction(action);
}
