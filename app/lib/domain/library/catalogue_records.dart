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
/// is stored in the database (ADR-0008 decision 6).
///
/// Release format 2, specification revision 2 adds the knowledge-system media
/// fields: display [purpose], sequence [ordinal] (position in the exercise's
/// media list), [caption], [source] (`original` or `licensed`) and
/// [availability] (`available` or `unavailable`). They are optional so that a
/// revision 1 reference stays representable; the exercise-knowledge checks
/// require them for knowledge content.
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
    this.ordinal = 0,
    this.purpose,
    this.caption,
    this.source,
    this.availability,
  });

  final String id;
  final ExerciseId exerciseId;

  /// Kind as text (`image`, `illustration`, `animation`, `video`); the list is
  /// open, like content kinds.
  final String kind;
  final String locator;
  final String licence;
  final String attribution;
  final ProviderId providerId;
  final int revision;

  /// Position in the exercise's media list, from 0 (display sequence).
  final int ordinal;

  /// What the media shows (`start`, `execution`, `finish`, `overview`).
  final String? purpose;
  final String? caption;

  /// `original` (RepForge-authored) or `licensed`.
  final String? source;

  /// `available` or `unavailable` (a recorded gap).
  final String? availability;

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
    ordinal,
    purpose,
    caption,
    source,
    availability,
  ];
}

/// Provenance of an exercise's instruction content (release format 2,
/// specification revision 2; `provenance-and-licensing.md` section 3 item 7
/// and section 8). A named human [editor] is the accountable author; AI
/// drafting assistance is recorded in [draftingAssistance]. Until an editor
/// approves it, content stays [ContentStatus.draftAwaitingEditor].
@immutable
final class ContentProvenance extends ValueObject {
  const ContentProvenance({
    required this.authoredBy,
    required this.status,
    required this.draftedOn,
    this.editor,
    this.draftingAssistance,
    this.approvedOn,
  });

  final String authoredBy;
  final ContentStatus status;
  final DateTime draftedOn;

  /// The named human editor; null until one is assigned.
  final String? editor;
  final String? draftingAssistance;
  final DateTime? approvedOn;

  @override
  List<Object?> get props => [
    authoredBy,
    status,
    draftedOn,
    editor,
    draftingAssistance,
    approvedOn,
  ];
}

/// Editorial status of instruction content. Nothing is complete or published
/// until a named human editor approves it (owner rule, D04 section 7).
enum ContentStatus { draftAwaitingEditor, editorApproved }

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
