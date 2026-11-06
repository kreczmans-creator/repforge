/// Runs several repository operations as one atomic unit: all of them are
/// kept, or none are. If `action` throws, everything it wrote is undone and
/// the error is rethrown. Calls may nest (the inner call joins the outer
/// unit, or is rolled back with it).
abstract interface class Transactor {
  Future<T> run<T>(Future<T> Function() action);
}
