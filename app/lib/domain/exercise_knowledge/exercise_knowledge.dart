import 'package:meta/meta.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/catalogue_records.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/release/release_format.dart';
import 'package:repforge/domain/training/training.dart'
    show ExerciseCategory, ExerciseType;

export 'package:repforge/domain/library/catalogue_records.dart'
    show ContentProvenance, ContentStatus, MediaReference;
export 'package:repforge/domain/library/library_enums.dart'
    show Difficulty, Laterality, Mechanics;
export 'package:repforge/domain/library/library_ids.dart' show ExerciseId;

/// The exercise knowledge system (WP 8; owner brief of 2026-11-07): a
/// read-only view of one catalogue release (format 2, specification revision
/// 2) that tells the user what an exercise is and how to perform it.
///
/// Nothing here is a second catalogue. Every record is built from a
/// [ReleaseDocument] parsed by the stage 3c release parser; identity is the
/// stable exercise id. The view is pure Dart and works offline.

/// Media kinds the knowledge system knows (owner brief: image, illustration,
/// animation, video). The release format stores the kind as text.
abstract final class KnowledgeMediaKinds {
  static const String image = 'image';
  static const String illustration = 'illustration';
  static const String animation = 'animation';
  static const String video = 'video';
  static const Set<String> all = {image, illustration, animation, video};
}

/// Display purposes of a media item.
abstract final class KnowledgeMediaPurposes {
  static const String start = 'start';
  static const String execution = 'execution';
  static const String finish = 'finish';
  static const String overview = 'overview';
  static const Set<String> all = {start, execution, finish, overview};
}

/// Where a media item comes from: RepForge-authored or properly licensed.
abstract final class KnowledgeMediaSources {
  static const String original = 'original';
  static const String licensed = 'licensed';
  static const Set<String> all = {original, licensed};
}

/// Whether a media item can be shown, or is a recorded gap.
abstract final class KnowledgeMediaAvailability {
  static const String available = 'available';
  static const String unavailable = 'unavailable';
  static const Set<String> all = {available, unavailable};
}

/// Locator scheme of an original RepForge illustration drawn by the app from
/// built-in vector data: no file, no network (`repforge-illustration:<key>`).
const String builtInIllustrationScheme = 'repforge-illustration:';

/// Locator scheme of a file bundled with the app (`asset:<path>`).
const String bundledAssetScheme = 'asset:';

/// One media item of an exercise, in display order.
@immutable
final class KnowledgeMedia {
  const KnowledgeMedia(this.reference);

  final MediaReference reference;

  String get id => reference.id;
  String get kind => reference.kind;
  String get purpose => reference.purpose ?? KnowledgeMediaPurposes.overview;
  String get locator => reference.locator;
  int get ordinal => reference.ordinal;
  String get caption => reference.caption ?? '';
  String get attribution => reference.attribution;
  String get licence => reference.licence;
  String get source => reference.source ?? '';

  /// True only when the item is recorded as available. An item with an
  /// unknown availability is treated as unavailable (degrades to the
  /// placeholder).
  bool get isAvailable =>
      reference.availability == KnowledgeMediaAvailability.available;

  /// The key of a built-in RepForge illustration, or null.
  String? get builtInIllustrationKey =>
      locator.startsWith(builtInIllustrationScheme)
      ? locator.substring(builtInIllustrationScheme.length)
      : null;

  @override
  bool operator ==(Object other) =>
      other is KnowledgeMedia && other.reference == reference;

  @override
  int get hashCode => reference.hashCode;
}

/// A common mistake: the fault, why it is undesirable and the correction.
///
/// The release stores the fault and the fix in one `commonMistakes` item in
/// the editorial pattern "Fault. Fix." (`editorial-guide.md` section 8) and
/// the reason in the `mistakeEffects` item of the same position.
@immutable
final class CommonMistake {
  const CommonMistake({required this.fault, required this.fix, this.why});

  /// Splits a "Fault. Fix." item at the end of its first sentence.
  factory CommonMistake.fromItem(String item, {String? why}) {
    final text = item.trim();
    final m = RegExp(r'^(.+?[.!?])\s+(.+)$', dotAll: true).firstMatch(text);
    if (m == null) return CommonMistake(fault: text, fix: '', why: why);
    return CommonMistake(fault: m.group(1)!, fix: m.group(2)!, why: why);
  }

  final String fault;
  final String fix;
  final String? why;

  bool get isComplete =>
      fault.isNotEmpty && fix.isNotEmpty && (why?.isNotEmpty ?? false);

  @override
  bool operator ==(Object other) =>
      other is CommonMistake &&
      other.fault == fault &&
      other.fix == fix &&
      other.why == why;

  @override
  int get hashCode => Object.hash(fault, fix, why);
}

/// How a linked exercise relates to the one shown.
enum ExerciseLinkKind {
  /// A regression: the linked exercise is the easier step (derived from a
  /// stored `progressionOf` from this exercise).
  easier,

  /// A progression: the linked exercise is the harder step.
  harder,

  /// Same movement family, different equipment (load items differ).
  equipmentAlternative,

  /// Same movement family, another variation (grip, angle, stance, range).
  variation,

  /// The single-limb or bilateral counterpart.
  counterpart,

  /// A different movement that trains the same target (`alternativeTo`).
  comparable,
}

/// A link to another real catalogue exercise.
@immutable
final class ExerciseLink {
  const ExerciseLink({
    required this.exerciseId,
    required this.name,
    required this.kind,
  });

  final ExerciseId exerciseId;
  final String name;
  final ExerciseLinkKind kind;

  @override
  bool operator ==(Object other) =>
      other is ExerciseLink &&
      other.exerciseId == exerciseId &&
      other.name == name &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(exerciseId, name, kind);

  @override
  String toString() => '${kind.name}:$exerciseId';
}

/// Display labels of the approved reference data (`en-GB`), taken from the
/// approved reference files the release points at. Ids without a label are
/// shown as their id.
@immutable
final class ReferenceLabels {
  const ReferenceLabels({
    this.anatomy = const {},
    this.patterns = const {},
    this.equipment = const {},
    this.supportEquipment = const {},
  });

  static const ReferenceLabels none = ReferenceLabels();

  final Map<String, String> anatomy;
  final Map<String, String> patterns;
  final Map<String, String> equipment;

  /// Equipment ids whose default role is `support` (`equipment.json`): they
  /// hold the body or another item and do not decide an equipment
  /// alternative.
  final Set<String> supportEquipment;

  bool get isEmpty => anatomy.isEmpty && patterns.isEmpty && equipment.isEmpty;

  String anatomyLabel(AnatomyNodeId id) => anatomy[id.value] ?? id.value;
  String patternLabel(MovementPatternId id) => patterns[id.value] ?? id.value;
  String equipmentLabel(EquipmentItemId id) => equipment[id.value] ?? id.value;
}

/// Everything the app knows about how to perform one exercise.
@immutable
final class ExerciseKnowledge {
  const ExerciseKnowledge({
    required this.exercise,
    required this.content,
    required this.media,
    required this.links,
    required this.labels,
    this.contentProvenance,
  });

  /// The catalogue record (classification, targets, equipment, provenance).
  final CatalogueExercise exercise;

  /// Instruction items by section kind (`en-GB`), in order.
  final Map<String, List<String>> content;

  /// Media in display order.
  final List<KnowledgeMedia> media;
  final List<ExerciseLink> links;
  final ReferenceLabels labels;
  final ContentProvenance? contentProvenance;

  ExerciseId get id => exercise.id;
  String get name => exercise.name;
  List<String> get aliases => exercise.aliases;
  ExerciseType get loggingType => exercise.type;
  ExerciseCategory get category => exercise.category;
  Difficulty? get difficulty => exercise.difficulty;
  Mechanics? get mechanics => exercise.mechanics;
  Laterality? get laterality => exercise.laterality;
  int? get revision => exercise.revision;

  List<String> section(String kind) => content[kind] ?? const [];
  List<String> get description => section(ContentSectionKinds.description);
  List<String> get startingPosition => section(ContentSectionKinds.setup);
  List<String> get execution => section(ContentSectionKinds.execution);
  List<String> get breathing => section(ContentSectionKinds.breathing);
  List<String> get tempo => section(ContentSectionKinds.tempo);
  List<String> get cues => section(ContentSectionKinds.cues);
  List<String> get safety => section(ContentSectionKinds.safety);

  /// Common mistakes with their reasons, paired by position.
  List<CommonMistake> get mistakes {
    final items = section(ContentSectionKinds.commonMistakes);
    final effects = section(ContentSectionKinds.mistakeEffects);
    return [
      for (var i = 0; i < items.length; i++)
        CommonMistake.fromItem(
          items[i],
          why: i < effects.length ? effects[i] : null,
        ),
    ];
  }

  List<String> get primaryTargetLabels => [
    for (final t in exercise.primaryTargets) labels.anatomyLabel(t.node),
  ];
  List<String> get secondaryTargetLabels => [
    for (final t in exercise.secondaryTargets) labels.anatomyLabel(t.node),
  ];
  List<String> get patternLabels => [
    for (final p in exercise.patterns) labels.patternLabel(p),
  ];
  List<String> get equipmentLabels => [
    for (final e in exercise.equipment) labels.equipmentLabel(e.item),
  ];

  /// True when any instruction section has text.
  bool get hasInstructions => content.values.any((v) => v.isNotEmpty);

  /// Media that can be shown now, in display order.
  List<KnowledgeMedia> get availableMedia => [
    for (final m in media)
      if (m.isAvailable) m,
  ];

  List<ExerciseLink> linksOf(ExerciseLinkKind kind) => [
    for (final l in links)
      if (l.kind == kind) l,
  ];
}

/// The knowledge view of one release: every exercise of the release, keyed
/// by its stable id.
final class KnowledgeCatalogue {
  KnowledgeCatalogue._(this.document, this.byId, this.contentHash);

  /// Builds the view from a parsed release. [labels] come from the approved
  /// reference files; [contentHash] is the SHA-256 of the release bytes.
  factory KnowledgeCatalogue.fromRelease(
    ReleaseDocument document, {
    ReferenceLabels labels = ReferenceLabels.none,
    String? contentHash,
  }) {
    final exercises = {for (final e in document.exercises) e.id: e};
    final contentById = <ExerciseId, Map<String, List<ContentSection>>>{};
    for (final c in document.content) {
      if (c.locale != canonicalLocale) continue;
      contentById
          .putIfAbsent(c.exerciseId, () => {})
          .putIfAbsent(c.kind, () => [])
          .add(c);
    }
    final mediaById = <ExerciseId, List<KnowledgeMedia>>{};
    for (final m in document.media) {
      mediaById.putIfAbsent(m.exerciseId, () => []).add(KnowledgeMedia(m));
    }
    final byId = <ExerciseId, ExerciseKnowledge>{};
    for (final e in document.exercises) {
      final sections = contentById[e.id] ?? const {};
      final media = [...?mediaById[e.id]]
        ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
      byId[e.id] = ExerciseKnowledge(
        exercise: e,
        content: {
          for (final MapEntry(:key, :value) in sections.entries)
            key: [
              for (final c in value..sort((a, b) => a.ordinal - b.ordinal))
                c.body.trim(),
            ],
        },
        media: List.unmodifiable(media),
        links: List.unmodifiable(_links(e.id, document, exercises, labels)),
        labels: labels,
        contentProvenance: document.contentProvenance[e.id],
      );
    }
    return KnowledgeCatalogue._(document, Map.unmodifiable(byId), contentHash);
  }

  final ReleaseDocument document;
  final Map<ExerciseId, ExerciseKnowledge> byId;
  final String? contentHash;

  ExerciseKnowledge? operator [](String exerciseId) =>
      byId[ExerciseId(exerciseId)];

  Iterable<ExerciseKnowledge> get all => byId.values;
}

/// Links of [id] to other exercises of the release, each exercise once, in
/// the order easier, harder, equipment alternatives, variations,
/// counterparts, comparable exercises; names in alphabetical order within a
/// kind. Only active exercises of the release are linked.
List<ExerciseLink> _links(
  ExerciseId id,
  ReleaseDocument document,
  Map<ExerciseId, CatalogueExercise> exercises,
  ReferenceLabels labels,
) {
  final self = exercises[id]!;
  final rels = document.relationships;
  final found = <ExerciseId, ExerciseLinkKind>{};
  void put(ExerciseId other, ExerciseLinkKind kind) {
    if (other == id) return;
    final target = exercises[other];
    if (target == null || !target.isActive) return;
    final existing = found[other];
    if (existing == null || kind.index < existing.index) found[other] = kind;
  }

  ExerciseId? root;
  for (final r in rels) {
    if (r.kind == RelationshipKind.variationOf && r.from == id) root = r.to;
  }
  final familyRoot = root ?? id;
  final family = <ExerciseId>{
    familyRoot,
    for (final r in rels)
      if (r.kind == RelationshipKind.variationOf && r.to == familyRoot) r.from,
  };
  if (family.length > 1) {
    final ownLoad = _loadItems(self, labels.supportEquipment);
    for (final member in family) {
      final other = exercises[member];
      if (other == null) continue;
      put(
        member,
        _sameSet(_loadItems(other, labels.supportEquipment), ownLoad)
            ? ExerciseLinkKind.variation
            : ExerciseLinkKind.equipmentAlternative,
      );
    }
  }
  for (final r in rels) {
    switch (r.kind) {
      case RelationshipKind.progressionOf:
        // `from` is the harder step, `to` the easier one.
        if (r.from == id) put(r.to, ExerciseLinkKind.easier);
        if (r.to == id) put(r.from, ExerciseLinkKind.harder);
      case RelationshipKind.alternativeTo:
        if (r.from == id) put(r.to, ExerciseLinkKind.comparable);
        if (r.to == id) put(r.from, ExerciseLinkKind.comparable);
      case RelationshipKind.unilateralCounterpartOf:
        if (r.from == id) put(r.to, ExerciseLinkKind.counterpart);
        if (r.to == id) put(r.from, ExerciseLinkKind.counterpart);
      case RelationshipKind.variationOf:
      case RelationshipKind.regressionOf:
        break;
    }
  }
  final out =
      [
        for (final MapEntry(:key, :value) in found.entries)
          ExerciseLink(
            exerciseId: key,
            name: exercises[key]!.name,
            kind: value,
          ),
      ]..sort((a, b) {
        final k = a.kind.index.compareTo(b.kind.index);
        return k != 0 ? k : a.name.compareTo(b.name);
      });
  return out;
}

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// Equipment ids that carry load (ignoring support items such as a bench or a
/// rack), used to tell an equipment alternative from another variation. A
/// per-exercise role override wins over the default role.
Set<String> _loadItems(CatalogueExercise e, Set<String> support) => {
  for (final u in e.equipment)
    if (u.roleOverride == EquipmentRole.load ||
        (u.roleOverride == null && !support.contains(u.item.value)))
      u.item.value,
};
