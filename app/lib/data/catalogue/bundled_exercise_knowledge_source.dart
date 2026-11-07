import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge_source.dart';

/// Reads the bytes of a bundled file by its asset key; throws when the file
/// is not bundled.
typedef ReadBundledBytes = Future<List<int>> Function(String key);

/// Parses, checks and hashes a bundle. Production runs it off the UI thread
/// (Flutter `compute`); the default runs it in place.
typedef BuildKnowledgeCatalogue = Future<Result<KnowledgeCatalogue>> Function(
  KnowledgeBundle bundle,
);

Future<Result<KnowledgeCatalogue>> _buildInPlace(
  KnowledgeBundle bundle,
) async => loadKnowledgeCatalogue(bundle);

/// Data adapter for [ExerciseKnowledgeSource]: reads the canonical catalogue
/// release (format 2) and the approved reference files from the app bundle,
/// once, and answers lookups from memory. Read-only and offline: it never
/// touches the network or the database.
///
/// Bundling the release and reference files into the app binary is owner
/// decision D-3c-3 (`docs/wp8-stage-3c-3d-5-6-preparation.md`). Until the
/// assets are registered in `pubspec.yaml`, [readBytes] throws and every
/// lookup returns [KnowledgeUnavailable]; the screen degrades gracefully.
final class BundledExerciseKnowledgeSource implements ExerciseKnowledgeSource {
  BundledExerciseKnowledgeSource({
    required this.readBytes,
    this.build = _buildInPlace,
  });

  /// The release the app reads (the latest `repforge` release).
  static const String releaseAsset =
      'assets/catalogue/releases/repforge-release-3.json';

  /// The approved reference files, for display labels and equipment roles.
  static const Map<ReleaseReferenceName, String> referenceAssets = {
    ReleaseReferenceName.anatomy: 'assets/catalogue/reference/anatomy.json',
    ReleaseReferenceName.movementPatterns:
        'assets/catalogue/reference/movement-patterns.json',
    ReleaseReferenceName.equipment: 'assets/catalogue/reference/equipment.json',
  };

  final ReadBundledBytes readBytes;
  final BuildKnowledgeCatalogue build;
  Future<Result<KnowledgeCatalogue>>? _catalogue;

  /// The loaded catalogue (loaded once; a failure is kept, not retried, so a
  /// missing asset costs one read per app run).
  Future<Result<KnowledgeCatalogue>> catalogue() => _catalogue ??= _load();

  Future<Result<KnowledgeCatalogue>> _load() async {
    final List<int> release;
    try {
      release = await readBytes(releaseAsset);
    } on Object {
      return const Err(
        UnavailableError(
          'The exercise catalogue is not bundled in this build.',
        ),
      );
    }
    final reference = <ReleaseReferenceName, List<int>>{};
    for (final MapEntry(:key, :value) in referenceAssets.entries) {
      try {
        reference[key] = await readBytes(value);
      } on Object {
        // Labels fall back to ids; the instructions still work.
      }
    }
    try {
      return await build(
        KnowledgeBundle(release: release, reference: reference),
      );
    } on Object {
      return const Err(
        UnavailableError('The exercise catalogue could not be prepared.'),
      );
    }
  }

  @override
  Future<KnowledgeLookup> lookup(String exerciseId) async {
    final result = await catalogue();
    return switch (result) {
      Ok(:final value) =>
        value[exerciseId] == null
            ? const KnowledgeNotAuthored()
            : KnowledgeFound(value[exerciseId]!),
      Err(:final error) => KnowledgeUnavailable(error.message),
    };
  }
}
