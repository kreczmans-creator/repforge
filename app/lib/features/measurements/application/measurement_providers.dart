import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/unreadable_measurement.dart';

/// Live history of one site, newest first (BCM-004(3)); offline, re-emits on
/// every insert, edit and delete so charts and summaries update at once.
// ignore: specify_nonobvious_property_types
final measurementsForSiteProvider =
    StreamProvider.family<List<Measurement>, MeasurementSite>(
      (ref, site) => ref.watch(measurementRepositoryProvider).watchSite(site),
    );

/// Live list of every site's readings, newest first.
final allMeasurementsProvider = StreamProvider<List<Measurement>>(
  (ref) => ref.watch(measurementRepositoryProvider).watchAll(),
);

/// Stored readings that cannot be shown (unknown site, or value out of range or
/// off the 0.1 step;
/// only possible via a raw backup restore). Preserved untouched, excluded from
/// history, charts and CSV, and reported here so a screen can say "N stored
/// readings cannot be shown" with details and offer deletion by id.
final unreadableMeasurementsProvider =
    StreamProvider<List<UnreadableMeasurement>>(
      (ref) => ref.watch(measurementRepositoryProvider).watchUnreadable(),
    );

/// Number of unreadable stored readings (0 while loading).
final unreadableMeasurementCountProvider = Provider<int>(
  (ref) => ref.watch(unreadableMeasurementsProvider).value?.length ?? 0,
);
