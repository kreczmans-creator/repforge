import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge_source.dart';

/// The single switch that shows AI-drafted exercise guidance that no named
/// editor has approved yet. **Off by default** (owner decision KS-D9 is
/// pending), so bundling the catalogue cannot publish drafts. It is a build
/// flag: `--dart-define=REPFORGE_SHOW_DRAFT_GUIDANCE=true`.
const bool showDraftExerciseGuidance = bool.fromEnvironment(
  'REPFORGE_SHOW_DRAFT_GUIDANCE',
);

/// Provider form of [showDraftExerciseGuidance] (tests override it).
final showDraftExerciseGuidanceProvider = Provider<bool>(
  (_) => showDraftExerciseGuidance,
);

/// The knowledge (instructions, media, related exercises) of one exercise by
/// its stable id, after the publication rule. Read-only and offline; see
/// [ExerciseKnowledgeSource] and [applyPublicationPolicy].
// ignore: specify_nonobvious_property_types, the family type is not exported
final exerciseKnowledgeProvider = FutureProvider.autoDispose
    .family<KnowledgeLookup, String>(
      (ref, id) async => applyPublicationPolicy(
        await ref.watch(exerciseKnowledgeSourceProvider).lookup(id),
        showDrafts: ref.watch(showDraftExerciseGuidanceProvider),
      ),
    );
