import 'package:meta/meta.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/value_equality.dart';

/// One item of instruction text (ADR-0008 decision 6): keyed by exercise,
/// locale, section kind and position, with its provider and revision. The kind
/// is a controlled-list text (`ContentSectionKinds`).
@immutable
final class ContentSection extends ValueObject {
  const ContentSection({
    required this.exerciseId,
    required this.locale,
    required this.kind,
    required this.ordinal,
    required this.body,
    this.providerId = ProviderId.repforge,
    this.revision = 1,
  });

  final ExerciseId exerciseId;
  final String locale;
  final String kind;

  /// Position of the item within its section, from 0.
  final int ordinal;
  final String body;
  final ProviderId providerId;
  final int revision;

  @override
  List<Object?> get props => [
    exerciseId,
    locale,
    kind,
    ordinal,
    body,
    providerId,
    revision,
  ];
}

/// A reference to media (kind, locator, licence, attribution). No binary data
/// is stored and nothing is displayed in WP 8 stage 3.
@immutable
final class MediaReference extends ValueObject {
  const MediaReference({
    required this.id,
    required this.exerciseId,
    required this.kind,
    required this.locator,
    required this.licence,
    required this.attribution,
    this.providerId = ProviderId.repforge,
    this.revision = 1,
  });

  final String id;
  final ExerciseId exerciseId;

  /// Kind as text (`image`, `video`); the list is open, like content kinds.
  final String kind;
  final String locator;
  final String licence;
  final String attribution;
  final ProviderId providerId;
  final int revision;

  @override
  List<Object?> get props => [
    id,
    exerciseId,
    kind,
    locator,
    licence,
    attribution,
    providerId,
    revision,
  ];
}

/// A content provider (ADR-0009 decision 2): licence and attribution are
/// always recorded.
@immutable
final class ContentProvider extends ValueObject {
  const ContentProvider({
    required this.id,
    required this.name,
    required this.licence,
    required this.attribution,
    this.url,
  });

  final ProviderId id;
  final String name;
  final String licence;
  final String attribution;
  final String? url;

  @override
  List<Object?> get props => [id, name, licence, attribution, url];
}

/// The immutable record of an applied catalogue release (ADR-0009 decision 4).
@immutable
final class CatalogueRelease extends ValueObject {
  const CatalogueRelease({
    required this.id,
    required this.contentHash,
    required this.inserted,
    required this.updated,
    required this.retired,
    this.appliedAt,
    this.appVersion,
  });

  final ReleaseId id;

  /// Hash of the release content, for example `sha256:...`.
  final String contentHash;
  final int inserted;
  final int updated;
  final int retired;
  final DateTime? appliedAt;
  final String? appVersion;

  @override
  List<Object?> get props => [
    id,
    contentHash,
    inserted,
    updated,
    retired,
    appliedAt,
    appVersion,
  ];
}

/// User state of an exercise (ADR-0008 decision 8): kept apart from catalogue
/// fields and never written by the reconciler.
@immutable
final class UserExerciseState extends ValueObject {
  const UserExerciseState({
    required this.exerciseId,
    this.favourite = false,
    this.hidden = false,
    this.lastUsedAt,
  });

  final ExerciseId exerciseId;
  final bool favourite;
  final bool hidden;
  final DateTime? lastUsedAt;

  @override
  List<Object?> get props => [exerciseId, favourite, hidden, lastUsedAt];
}
