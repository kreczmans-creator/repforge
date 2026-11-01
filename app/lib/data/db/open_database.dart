import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Opens the on-device database file `repforge.sqlite`.
///
/// The file lives in the application-support directory (Android: app-private
/// files; iOS: `Library/Application Support`, excluded from user-visible file
/// sharing). drift_flutter's default is the Documents directory, which on iOS
/// is user-visible when file sharing is enabled, so it is overridden here.
QueryExecutor openAppDatabase() => driftDatabase(
  name: 'repforge',
  native: const DriftNativeOptions(
    databaseDirectory: getApplicationSupportDirectory,
  ),
);
