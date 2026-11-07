import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge_source.dart';

/// The knowledge (instructions, media, related exercises) of one exercise by
/// its stable id. Read-only and offline; see [ExerciseKnowledgeSource].
// ignore: specify_nonobvious_property_types, the family type is not exported
final exerciseKnowledgeProvider = FutureProvider.autoDispose
    .family<KnowledgeLookup, String>(
      (ref, id) => ref.watch(exerciseKnowledgeSourceProvider).lookup(id),
    );
