import 'package:repforge/domain/measurements/measurements.dart';

abstract interface class MeasurementRepository {
  /// Newest first for one site.
  Stream<List<Measurement>> watchSite(MeasurementSite site);

  /// Every site, newest first, optionally limited.
  Stream<List<Measurement>> watchAll({int? limit});
  Future<Measurement?> latest(MeasurementSite site);
  Future<void> insert(Measurement m);
  Future<void> update(Measurement m);
  Future<void> delete(String id);
}
