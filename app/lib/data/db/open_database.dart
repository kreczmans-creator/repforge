import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens the on-device database file `repforge.sqlite` in the platform's
/// application-support directory (Android and iOS).
QueryExecutor openAppDatabase() => driftDatabase(name: 'repforge');
