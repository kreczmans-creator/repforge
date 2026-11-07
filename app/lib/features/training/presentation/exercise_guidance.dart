import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge_source.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/exercise_knowledge_providers.dart';
import 'package:repforge/features/training/presentation/exercise_illustration.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Exercise guidance on the detail screen (WP 8 exercise knowledge system):
/// sections A to I — visual, overview, starting position, execution,
/// breathing and tempo, coaching cues, common mistakes, safety, variations
/// and alternatives. Read-only and offline.
///
/// [overviewDetails] is the existing classification card; it is shown inside
/// section B so the user's own exercise record stays the source of the
/// muscles and equipment shown.
class ExerciseGuidance extends ConsumerWidget {
  const ExerciseGuidance({
    required this.exercise,
    required this.overviewDetails,
    super.key,
  });

  final Exercise exercise;
  final Widget overviewDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookup = ref.watch(exerciseKnowledgeProvider(exercise.id));
    return lookup.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [overviewDetails, const RfLoading()],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          overviewDetails,
          const SizedBox(height: RfSpace.s3),
          const RfErrorState(
            key: Key('guidance-error'),
            message: 'Could not load the exercise guidance.',
          ),
        ],
      ),
      data: (result) => switch (result) {
        KnowledgeFound(:final knowledge) => _Sections(
          knowledge: knowledge,
          overviewDetails: overviewDetails,
        ),
        KnowledgeNotAuthored() => _NoGuidance(
          exercise: exercise,
          overviewDetails: overviewDetails,
        ),
        KnowledgeUnavailable() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            overviewDetails,
            const SizedBox(height: RfSpace.s3),
            const RfEmptyState(
              key: Key('guidance-unavailable'),
              icon: Icons.menu_book_outlined,
              message:
                  'Exercise guidance is not included in this version of the '
                  'app yet. The details and history below still work.',
            ),
          ],
        ),
      },
    );
  }
}

class _NoGuidance extends ConsumerWidget {
  const _NoGuidance({required this.exercise, required this.overviewDetails});

  final Exercise exercise;
  final Widget overviewDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final original = exercise.copiedFromId;
    final originalLookup = original == null
        ? null
        : ref.watch(exerciseKnowledgeProvider(original)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        overviewDetails,
        const SizedBox(height: RfSpace.s3),
        RfEmptyState(
          key: const Key('guidance-none'),
          icon: Icons.menu_book_outlined,
          message: exercise.supplied
              ? 'No instructions yet for this exercise.'
              : 'No instructions yet. RepForge writes guidance for catalogue '
                    'exercises; your own exercises show their details and '
                    'history.',
        ),
        if (originalLookup case KnowledgeFound(:final knowledge))
          Padding(
            padding: const EdgeInsets.only(top: RfSpace.s2),
            child: OutlinedButton.icon(
              key: const Key('guidance-original'),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text('See guidance for "${knowledge.name}"'),
              onPressed: () =>
                  context.push(RfRoutes.trainExercise(knowledge.id.value)),
            ),
          ),
      ],
    );
  }
}

class _Sections extends StatelessWidget {
  const _Sections({required this.knowledge, required this.overviewDetails});

  final ExerciseKnowledge knowledge;
  final Widget overviewDetails;

  @override
  Widget build(BuildContext context) {
    final k = knowledge;
    final draft =
        k.contentProvenance?.status == ContentStatus.draftAwaitingEditor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (draft)
          const Padding(
            padding: EdgeInsets.only(bottom: RfSpace.s3),
            child: _DraftNote(key: Key('guidance-draft-note')),
          ),
        _Section(
          id: 'visual',
          title: 'How it looks',
          child: _Visual(knowledge: k),
        ),
        _Section(
          id: 'overview',
          title: 'Overview',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in k.description)
                Padding(
                  padding: const EdgeInsets.only(bottom: RfSpace.s2),
                  child: Text(p, style: Theme.of(context).textTheme.bodyMedium),
                ),
              if (k.description.isEmpty) const _NotWritten(),
              _Classification(knowledge: k),
              const SizedBox(height: RfSpace.s3),
              overviewDetails,
            ],
          ),
        ),
        _Section(
          id: 'starting-position',
          title: 'Starting position',
          child: _Bullets(items: k.startingPosition),
        ),
        _Section(
          id: 'execution',
          title: 'How to do it',
          child: _Steps(items: k.execution),
        ),
        _Section(
          id: 'breathing',
          title: k.tempo.isEmpty ? 'Breathing' : 'Breathing and tempo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Bullets(items: k.breathing),
              if (k.tempo.isNotEmpty) ...[
                const SizedBox(height: RfSpace.s2),
                _Labelled(label: 'Tempo', items: k.tempo, id: 'tempo'),
              ],
            ],
          ),
        ),
        _Section(
          id: 'cues',
          title: 'Coaching cues',
          child: _Bullets(items: k.cues, icon: Icons.campaign_outlined),
        ),
        _Section(
          id: 'mistakes',
          title: 'Common mistakes',
          child: _Mistakes(mistakes: k.mistakes),
        ),
        _Section(
          id: 'safety',
          title: 'Safety',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Bullets(items: k.safety, icon: Icons.shield_outlined),
              const SizedBox(height: RfSpace.s2),
              Text(
                'General exercise guidance, not medical advice.',
                key: const Key('safety-disclaimer'),
                style: context.rfText.caption,
              ),
            ],
          ),
        ),
        _Section(
          id: 'related',
          title: 'Variations and alternatives',
          child: _Related(links: k.links),
        ),
      ],
    );
  }
}

class _DraftNote extends StatelessWidget {
  const _DraftNote({super.key});

  @override
  Widget build(BuildContext context) {
    final rf = context.rf;
    return Container(
      padding: const EdgeInsets.all(RfSpace.s3),
      decoration: BoxDecoration(
        color: rf.accentSubtle,
        borderRadius: BorderRadius.circular(RfRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note, size: RfIcon.md, color: rf.accentText),
          const SizedBox(width: RfSpace.s2),
          Expanded(
            child: Text(
              'Draft guidance, written with AI assistance. It has not yet '
              'been reviewed by a RepForge editor.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.id, required this.title, required this.child});

  final String id;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    key: Key('guidance-$id'),
    padding: const EdgeInsets.only(bottom: RfSpace.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: RfSectionHeader(title: title)),
        child,
      ],
    ),
  );
}

class _NotWritten extends StatelessWidget {
  const _NotWritten();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RfSpace.s2),
    child: Text(
      'Not written yet.',
      key: const Key('guidance-not-written'),
      style: context.rfText.caption,
    ),
  );
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items, this.icon});

  final List<String> items;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _NotWritten();
    final rf = context.rf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: RfSpace.s2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      icon ?? Icons.circle,
                      size: icon == null ? 8 : RfIcon.sm,
                      color: rf.accentText,
                    ),
                  ),
                ),
                const SizedBox(width: RfSpace.s2),
                Expanded(
                  child: Text(t, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.items, required this.id});

  final String label;
  final List<String> items;
  final String id;

  @override
  Widget build(BuildContext context) => Column(
    key: Key('guidance-$id-items'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: context.rfText.kicker),
      const SizedBox(height: RfSpace.s1),
      for (final t in items)
        Text(t, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _Steps extends StatelessWidget {
  const _Steps({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _NotWritten();
    final rf = context.rf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: RfSpace.s2),
            child: Semantics(
              key: Key('step-${i + 1}'),
              container: true,
              label: 'Step ${i + 1} of ${items.length}: ${items[i]}',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rf.accentSubtle,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: context.rfText.dataS.copyWith(
                        color: rf.accentText,
                      ),
                    ),
                  ),
                  const SizedBox(width: RfSpace.s3),
                  Expanded(
                    child: Text(
                      items[i],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Mistakes extends StatelessWidget {
  const _Mistakes({required this.mistakes});

  final List<CommonMistake> mistakes;

  @override
  Widget build(BuildContext context) {
    if (mistakes.isEmpty) return const _NotWritten();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < mistakes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: RfSpace.s2),
            child: RfCard(
              key: Key('mistake-${i + 1}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mistakes[i].fault, style: theme.textTheme.titleSmall),
                  if (mistakes[i].why case final why? when why.isNotEmpty) ...[
                    const SizedBox(height: RfSpace.s2),
                    Text('Why it matters', style: context.rfText.kicker),
                    Text(why, style: theme.textTheme.bodyMedium),
                  ],
                  if (mistakes[i].fix.isNotEmpty) ...[
                    const SizedBox(height: RfSpace.s2),
                    Text('How to fix it', style: context.rfText.kicker),
                    Text(mistakes[i].fix, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _difficultyLabel(Difficulty d) => switch (d) {
  Difficulty.beginner => 'Beginner',
  Difficulty.intermediate => 'Intermediate',
  Difficulty.advanced => 'Advanced',
};

String _mechanicsLabel(Mechanics m) => switch (m) {
  Mechanics.compound => 'Compound (several joints)',
  Mechanics.isolation => 'Isolation (one joint)',
};

String _lateralityLabel(Laterality l) => switch (l) {
  Laterality.bilateral => 'Both sides together',
  Laterality.unilateral => 'One side at a time',
  Laterality.alternating => 'Alternating sides',
};

class _Classification extends StatelessWidget {
  const _Classification({required this.knowledge});

  final ExerciseKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final k = knowledge;
    final rows = <(String, String, String)>[
      if (k.difficulty case final d?)
        ('Difficulty', _difficultyLabel(d), 'difficulty'),
      if (k.mechanics case final m?)
        ('Mechanics', _mechanicsLabel(m), 'mechanics'),
      if (k.laterality case final l?)
        ('Laterality', _lateralityLabel(l), 'laterality'),
      if (k.patternLabels.isNotEmpty)
        ('Movement', k.patternLabels.join(', '), 'pattern'),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return RfCard(
      key: const Key('guidance-classification'),
      child: Column(
        children: [
          for (final (label, value, id) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RfSpace.s1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(label, style: context.rfText.caption),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      key: Key('knowledge-$id'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _purposeLabel(String purpose) => switch (purpose) {
  KnowledgeMediaPurposes.start => 'Start',
  KnowledgeMediaPurposes.execution => 'During',
  KnowledgeMediaPurposes.finish => 'Finish',
  _ => 'Position',
};

class _Visual extends StatelessWidget {
  const _Visual({required this.knowledge});

  final ExerciseKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final media = knowledge.availableMedia;
    if (media.isEmpty) return const VisualPlaceholder();
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoUp = media.length > 1 && constraints.maxWidth >= 320;
        final width = twoUp
            ? (constraints.maxWidth - RfSpace.s2) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: RfSpace.s2,
          runSpacing: RfSpace.s2,
          children: [
            for (final m in media)
              SizedBox(
                width: width,
                child: _MediaTile(media: m, exerciseName: knowledge.name),
              ),
          ],
        );
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.media, required this.exerciseName});

  final KnowledgeMedia media;
  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    final pose = exerciseIllustrations[media.builtInIllustrationKey];
    final label =
        '$exerciseName, ${_purposeLabel(media.purpose)}. '
        '${media.caption}';
    final Widget picture;
    if (media.kind == KnowledgeMediaKinds.illustration && pose != null) {
      picture = ExerciseIllustration(pose: pose, semanticLabel: label);
    } else if (media.kind == KnowledgeMediaKinds.image &&
        media.locator.startsWith(bundledAssetScheme)) {
      picture = Image.asset(
        media.locator.substring(bundledAssetScheme.length),
        semanticLabel: label,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _MissingPicture(),
      );
    } else {
      picture = const _MissingPicture();
    }
    return RfCard(
      key: Key('media-${media.id}'),
      padding: const EdgeInsets.all(RfSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 4 / 3, child: picture),
          const SizedBox(height: RfSpace.s1),
          Text(_purposeLabel(media.purpose), style: context.rfText.kicker),
          Text(media.caption, style: context.rfText.caption),
        ],
      ),
    );
  }
}

class _MissingPicture extends StatelessWidget {
  const _MissingPicture();

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      Icons.image_not_supported_outlined,
      color: context.rf.textMuted,
      semanticLabel: 'Picture not available offline',
    ),
  );
}

/// The designed placeholder shown where no RepForge visual exists yet. It is
/// always labelled, so it is never mistaken for a demonstration.
class VisualPlaceholder extends StatelessWidget {
  const VisualPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final rf = context.rf;
    return Semantics(
      key: const Key('visual-placeholder'),
      label: 'Illustration not yet available',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(RfSpace.s4),
        decoration: BoxDecoration(
          color: rf.surface2,
          borderRadius: BorderRadius.circular(RfRadius.md),
          border: Border.all(color: rf.border),
        ),
        child: Row(
          children: [
            Icon(Icons.draw_outlined, color: rf.textMuted, size: RfIcon.lg),
            const SizedBox(width: RfSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Illustration not yet available',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: RfSpace.s1),
                  Text(
                    'A RepForge illustration of this exercise has not been '
                    'made yet. Follow the written steps below.',
                    style: context.rfText.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _linkHeading(ExerciseLinkKind kind) => switch (kind) {
  ExerciseLinkKind.easier => 'Easier',
  ExerciseLinkKind.harder => 'Harder',
  ExerciseLinkKind.equipmentAlternative => 'With other equipment',
  ExerciseLinkKind.variation => 'Variations',
  ExerciseLinkKind.counterpart => 'Single-side or two-side version',
  ExerciseLinkKind.comparable => 'Comparable exercises',
};

class _Related extends StatelessWidget {
  const _Related({required this.links});

  final List<ExerciseLink> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return Text(
        'No related exercises in the catalogue yet.',
        key: const Key('related-none'),
        style: context.rfText.caption,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in ExerciseLinkKind.values)
          if (links.any((l) => l.kind == kind)) ...[
            Padding(
              padding: const EdgeInsets.only(top: RfSpace.s1),
              child: Text(_linkHeading(kind), style: context.rfText.kicker),
            ),
            for (final l in links.where((l) => l.kind == kind))
              ListTile(
                key: Key('link-${l.exerciseId.value}'),
                contentPadding: EdgeInsets.zero,
                minTileHeight: rfMinTouchTarget,
                title: Text(l.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push(RfRoutes.trainExercise(l.exerciseId.value)),
              ),
          ],
      ],
    );
  }
}
