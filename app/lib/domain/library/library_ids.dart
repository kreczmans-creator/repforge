import 'package:meta/meta.dart';

/// Typed identifiers of the exercise library (ADR-0008 decision 1).
///
/// Reference and exercise ids are plain strings in storage; in code they are
/// always held in these wrappers so an anatomy node id cannot be passed where
/// an exercise id is expected. Equality is by value and by type.
@immutable
final class ExerciseId implements Comparable<ExerciseId> {
  const ExerciseId(this.value);

  final String value;

  @override
  int compareTo(ExerciseId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is ExerciseId && other.value == value;

  @override
  int get hashCode => Object.hash(ExerciseId, value);

  @override
  String toString() => value;
}

/// Identifier of an anatomy node (`chest`, `regionShoulder`, `fullBody`).
@immutable
final class AnatomyNodeId implements Comparable<AnatomyNodeId> {
  const AnatomyNodeId(this.value);

  final String value;

  @override
  int compareTo(AnatomyNodeId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is AnatomyNodeId && other.value == value;

  @override
  int get hashCode => Object.hash(AnatomyNodeId, value);

  @override
  String toString() => value;
}

/// Identifier of a movement pattern or pattern family (`squat`, `upperPush`).
@immutable
final class MovementPatternId implements Comparable<MovementPatternId> {
  const MovementPatternId(this.value);

  final String value;

  @override
  int compareTo(MovementPatternId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is MovementPatternId && other.value == value;

  @override
  int get hashCode => Object.hash(MovementPatternId, value);

  @override
  String toString() => value;
}

/// Identifier of an equipment item (`barbell`, `skiErg`).
@immutable
final class EquipmentItemId implements Comparable<EquipmentItemId> {
  const EquipmentItemId(this.value);

  final String value;

  @override
  int compareTo(EquipmentItemId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is EquipmentItemId && other.value == value;

  @override
  int get hashCode => Object.hash(EquipmentItemId, value);

  @override
  String toString() => value;
}

/// Identifier of a content provider (`repforge`).
@immutable
final class ProviderId implements Comparable<ProviderId> {
  const ProviderId(this.value);

  /// The provider of RepForge's own content.
  static const ProviderId repforge = ProviderId('repforge');

  final String value;

  @override
  int compareTo(ProviderId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is ProviderId && other.value == value;

  @override
  int get hashCode => Object.hash(ProviderId, value);

  @override
  String toString() => value;
}

/// Identifier of a catalogue release: the provider and its release number.
@immutable
final class ReleaseId implements Comparable<ReleaseId> {
  const ReleaseId(this.provider, this.number);

  final ProviderId provider;
  final int number;

  @override
  int compareTo(ReleaseId other) {
    final byProvider = provider.compareTo(other.provider);
    return byProvider != 0 ? byProvider : number.compareTo(other.number);
  }

  @override
  bool operator ==(Object other) =>
      other is ReleaseId &&
      other.provider == provider &&
      other.number == number;

  @override
  int get hashCode => Object.hash(ReleaseId, provider, number);

  @override
  String toString() => '$provider#$number';
}
