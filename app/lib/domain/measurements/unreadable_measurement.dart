import 'package:meta/meta.dart';

/// A stored, not-deleted measurement row that cannot be shown as a
/// [Measurement]: an unknown site name, or a value that is outside the accepted
/// range or not on the 0.1 step (possible only through a raw backup restore
/// or legacy data).
///
/// Such rows are preserved untouched in the database — never corrected,
/// dropped silently or exported — and reported so the user can see them and
/// delete them (owner rule on legacy invalid values, 2026-11-05).
@immutable
final class UnreadableMeasurement {
  const UnreadableMeasurement({
    required this.id,
    required this.site,
    required this.rawValue,
    required this.recordedAt,
  });

  final String id;

  /// The stored site text, exactly as found.
  final String site;

  /// The stored value, exactly as found.
  final double rawValue;

  /// UTC instant of the reading.
  final DateTime recordedAt;

  @override
  bool operator ==(Object other) =>
      other is UnreadableMeasurement &&
      other.id == id &&
      other.site == site &&
      other.rawValue == rawValue &&
      other.recordedAt.isAtSameMomentAs(recordedAt);

  @override
  int get hashCode =>
      Object.hash(id, site, rawValue, recordedAt.millisecondsSinceEpoch);

  @override
  String toString() => 'UnreadableMeasurement($id, $site, $rawValue)';
}
