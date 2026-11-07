import 'package:meta/meta.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/catalogue_records.dart';
import 'package:repforge/domain/library/exercise_relationship.dart';
import 'package:repforge/domain/library/integrity_report.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/value_equality.dart';

/// The only release format this code reads (`docs/catalogue/release-format-2.md`).
const int releaseFormatVersion2 = 2;

/// The five reference sections of a release, in file order.
enum ReleaseReferenceName {
  anatomy('anatomy'),
  movementPatterns('movementPatterns'),
  equipment('equipment'),
  ledger('ledger'),
  coverage('coverage');

  ReleaseReferenceName(this.wire);

  /// The key used in the release file.
  final String wire;
}

/// A reference file a release points at: bundle-relative path and the SHA-256
/// (lowercase hex) of its exact bytes.
@immutable
final class ReleaseReferenceFile extends ValueObject {
  const ReleaseReferenceFile({required this.path, required this.sha256});

  final String path;
  final String sha256;

  @override
  List<Object?> get props => [path, sha256];
}

/// A parsed release document (format 2), typed with the 3a catalogue records.
///
/// Every exercise is `system`, belongs to [provider] and has a revision; its
/// creation and update times are [releasedOn] (release-derived times, so the
/// result is identical on every device and run). The parser guarantees the
/// shape, not the catalogue rules: those are checked by the validator.
@immutable
final class ReleaseDocument extends ValueObject {
  ReleaseDocument({
    required this.provider,
    required this.release,
    required this.releasedOn,
    required Map<ReleaseReferenceName, ReleaseReferenceFile> reference,
    required List<CatalogueExercise> exercises,
    List<ExerciseRelationship> relationships = const [],
    List<ContentSection> content = const [],
    List<MediaReference> media = const [],
    List<Retirement> retirements = const [],
    Map<String, String> tranches = const {},
  }) : reference = Map.unmodifiable(reference),
       exercises = List.unmodifiable(exercises),
       relationships = List.unmodifiable(relationships),
       content = List.unmodifiable(content),
       media = List.unmodifiable(media),
       retirements = List.unmodifiable(retirements),
       tranches = Map.unmodifiable(tranches);

  final ContentProvider provider;
  final ReleaseId release;
  final DateTime releasedOn;
  final Map<ReleaseReferenceName, ReleaseReferenceFile> reference;
  final List<CatalogueExercise> exercises;
  final List<ExerciseRelationship> relationships;
  final List<ContentSection> content;
  final List<MediaReference> media;
  final List<Retirement> retirements;

  /// Tranche id to `planned`, `inProgress` or `complete`.
  final Map<String, String> tranches;

  /// The ids of the exercises in the release.
  Set<ExerciseId> get exerciseIds => {for (final e in exercises) e.id};

  /// The relationships that have [id] at either end.
  List<ExerciseRelationship> relationshipsInvolving(ExerciseId id) => [
    for (final r in relationships)
      if (r.from == id || r.to == id) r,
  ];

  @override
  List<Object?> get props => [
    provider,
    release,
    releasedOn,
    reference,
    exercises,
    relationships,
    content,
    media,
    [for (final r in retirements) (r.id, r.reason, r.replacedBy)],
    tranches,
  ];
}
