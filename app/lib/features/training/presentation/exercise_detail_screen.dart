import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/exercise_library_providers.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/set_format.dart';
import 'package:repforge/features/training/presentation/source_badge.dart';
import 'package:repforge/features/training/presentation/training_labels.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Exercise detail (TRN-008..012, TRN-025): classification, provenance,
/// history and the edit / archive actions.
class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  bool _busy = false;

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _edit(Exercise e) async {
    if (!e.supplied) {
      await context.push<void>(RfRoutes.trainExerciseEdit(e.id));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit creates your own copy'),
        content: Text(
          '"${e.name}" is a supplied exercise and stays as it is. Your '
          'changes are saved to a new custom exercise.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('copy-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create copy'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final result = await ref.read(copySuppliedExerciseProvider)(sourceId: e.id);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok(:final value):
        context.pushReplacement(RfRoutes.trainExerciseEdit(value.id));
      case Err(:final error):
        _snack(userMessageFor(error));
    }
  }

  Future<void> _archive(Exercise e) async {
    setState(() => _busy = true);
    final result = await ref.read(archiveExerciseProvider)(
      e.id,
      archived: !e.archived,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Err(:final error)) _snack(userMessageFor(error));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(exerciseByIdProvider(widget.exerciseId));
    final e = async.value;
    if (e == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercise')),
        body: async.hasError
            ? const RfErrorState(message: 'Could not load the exercise.')
            : async.isLoading
            ? const RfLoading()
            : const Padding(
                padding: EdgeInsets.all(RfSpace.gutter),
                child: RfEmptyState(
                  key: Key('exercise-missing'),
                  message: 'That exercise no longer exists.',
                ),
              ),
      );
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const SizedBox(height: RfSpace.s3),
          Text(e.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: RfSpace.s2),
          Wrap(
            spacing: RfSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              KeyedSubtree(
                key: const Key('detail-badge'),
                child: ExerciseSourceBadge(e),
              ),
              if (e.archived)
                const Text('Archived', key: Key('detail-archived')),
            ],
          ),
          const SizedBox(height: RfSpace.s2),
          _ProvenanceNote(exercise: e),
          const SizedBox(height: RfSpace.s3),
          RfCard(
            child: Column(
              children: [
                _Field('Type', exerciseTypeLabel(e.type), 'type'),
                _Field(
                  'Category',
                  exerciseCategoryLabel(e.category),
                  'category',
                ),
                _Field(
                  'Primary muscle',
                  muscleGroupLabel(e.primaryMuscle),
                  'primary',
                ),
                _Field(
                  'Secondary muscles',
                  e.secondaryMuscles.isEmpty
                      ? 'None'
                      : e.secondaryMuscles.map(muscleGroupLabel).join(', '),
                  'secondary',
                ),
                _Field('Equipment', equipmentSummary(e.equipment), 'equipment'),
                _Field(
                  'Also known as',
                  e.aliases.isEmpty ? 'None' : e.aliases.join(', '),
                  'aliases',
                ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s3),
          RfButton(
            key: const Key('exercise-edit'),
            label: e.supplied ? 'Edit (creates your copy)' : 'Edit',
            icon: Icons.edit_outlined,
            onPressed: _busy ? null : () => _edit(e),
          ),
          if (!e.supplied) ...[
            const SizedBox(height: RfSpace.s2),
            RfButton(
              key: const Key('exercise-archive'),
              label: e.archived ? 'Unarchive' : 'Archive',
              icon: e.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              variant: RfButtonVariant.secondary,
              onPressed: _busy ? null : () => _archive(e),
            ),
            if (!e.archived)
              Padding(
                padding: const EdgeInsets.only(top: RfSpace.s1),
                child: Text(
                  'Archiving hides it from the library. Your history stays.',
                  style: context.rfText.caption,
                ),
              ),
          ],
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'History'),
          _History(exerciseId: e.id),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value, this.id);

  final String label;
  final String value;
  final String id;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: RfSpace.s1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(label, style: context.rfText.caption)),
        Expanded(
          child: Text(
            value,
            key: Key('field-$id'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

class _ProvenanceNote extends ConsumerWidget {
  const _ProvenanceNote({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = exercise;
    final String text;
    if (e.supplied) {
      text =
          'Supplied exercise. It cannot be changed; editing creates your '
          'own copy.';
    } else if (e.copiedFromId != null) {
      final original = ref.watch(exerciseByIdProvider(e.copiedFromId!)).value;
      text = original == null
          ? 'Your custom copy of a supplied exercise.'
          : 'Your custom copy of "${original.name}".';
    } else {
      text = 'Custom exercise you created.';
    }
    return Text(
      text,
      key: const Key('provenance-note'),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(exerciseHistoryProvider(exerciseId));
    final units =
        ref.watch(settingsProvider.select((s) => s.value?.units)) ??
        UnitSystem.metric;
    return history.when(
      loading: () => const RfLoading(),
      error: (e, _) =>
          const RfErrorState(message: 'Could not load the history.'),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const RfEmptyState(
            key: Key('history-empty'),
            icon: Icons.history,
            message: 'Not performed yet. Completed sets will appear here.',
          );
        }
        return Column(
          children: [
            for (final s in sessions) ...[
              _SessionCard(session: s, units: units),
              const SizedBox(height: RfSpace.s2),
            ],
          ],
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.units});

  final ExerciseSessionHistory session;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateFormat('d MMM yyyy').format(session.startedAt.toLocal());
    return RfCard(
      key: Key('history-session-${session.sessionId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(session.sessionName, style: theme.textTheme.titleSmall),
          Text(date, style: context.rfText.caption),
          const SizedBox(height: RfSpace.s2),
          for (var i = 0; i < session.sets.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text('Set ${i + 1}', style: context.rfText.caption),
                  ),
                  Expanded(
                    child: Text(
                      formatSetData(session.sets[i].data, units),
                      key: Key('history-set-${session.sets[i].id}'),
                    ),
                  ),
                  if (session.sets[i].exertion case final x?)
                    Text(formatExertion(x), style: context.rfText.caption),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
