import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/exercise_library_providers.dart';
import 'package:repforge/features/training/application/session_view.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/session_starter.dart';
import 'package:repforge/features/training/presentation/source_badge.dart';
import 'package:repforge/features/training/presentation/training_labels.dart';
import 'package:repforge/features/training/presentation/training_pickers.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Train tab: the exercise library (TRN-008..012). Works from the local
/// database only. Search matches names and aliases, filters narrow by
/// category, muscle group and the equipment the user has.
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final _search = TextEditingController();
  ExerciseCategory? _category;
  MuscleGroup? _muscle;
  bool _showArchived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _new() async {
    final saved = await context.push<Exercise>(RfRoutes.trainExerciseNew);
    if (!mounted || saved == null) return;
    await context.push<void>(RfRoutes.trainExercise(saved.id));
  }

  Future<void> _pickMuscle() async {
    final picked = await showPickOneSheet<MuscleGroup>(
      context,
      title: 'Muscle group',
      options: MuscleGroup.values,
      labelOf: muscleGroupLabel,
      keyPrefix: 'muscle',
      selected: _muscle,
      anyLabel: 'Any muscle group',
    );
    if (picked == null || !mounted) return;
    setState(() => _muscle = picked.value);
  }

  Future<void> _pickEquipment(Set<Equipment> current) async {
    final picked = await showPickManySheet<Equipment>(
      context,
      title: 'Equipment I have',
      helper:
          'Only exercises you can do with this equipment are listed. '
          'Bodyweight exercises always are. Select nothing to show '
          'everything.',
      options: Equipment.values,
      labelOf: equipmentLabel,
      keyPrefix: 'avail',
      selected: current,
      doneLabel: 'Apply',
    );
    if (picked == null || !mounted) return;
    final result = await ref.read(setAvailableEquipmentProvider)(picked);
    if (!mounted) return;
    _showError(result);
  }

  void _showError(Result<void> result) {
    if (result case Err(:final error)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final available =
        ref.watch(availableEquipmentProvider).value ?? const <Equipment>{};
    final bodyweightOnly = ref.watch(bodyweightOnlyProvider).value ?? false;
    final query = ExerciseQuery(
      text: _search.text,
      category: _category,
      muscle: _muscle,
      // An empty set is "bodyweight only"; null is "no filter".
      availableEquipment: bodyweightOnly
          ? const <Equipment>{}
          : (available.isEmpty ? null : available),
      includeArchived: _showArchived,
    );
    final library = ref.watch(exerciseLibraryProvider(query));
    final filtered =
        _search.text.trim().isNotEmpty ||
        _category != null ||
        _muscle != null ||
        available.isNotEmpty ||
        bodyweightOnly;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RfScreenTitle(
          title: 'Train',
          caption: 'Exercise library, available offline',
        ),
        const _ContinueSessionCard(),
        RfButton(
          key: const Key('start-empty-session'),
          label: 'Start empty workout',
          icon: Icons.play_arrow,
          onPressed: () => ref.startEmpty(context),
        ),
        const SizedBox(height: RfSpace.s2),
        RfButton(
          key: const Key('new-exercise'),
          label: 'New exercise',
          icon: Icons.add,
          onPressed: _new,
        ),
        const SizedBox(height: RfSpace.s2),
        Wrap(
          spacing: RfSpace.s2,
          runSpacing: RfSpace.s2,
          children: [
            RfButton(
              key: const Key('open-plans'),
              label: 'Workouts',
              icon: Icons.list_alt_outlined,
              variant: RfButtonVariant.secondary,
              expand: false,
              onPressed: () => context.push(RfRoutes.trainPlans),
            ),
            RfButton(
              key: const Key('open-history'),
              label: 'History',
              icon: Icons.history,
              variant: RfButtonVariant.secondary,
              expand: false,
              onPressed: () => context.push(RfRoutes.trainHistory),
            ),
            RfButton(
              key: const Key('open-schedule'),
              label: 'Schedule',
              icon: Icons.calendar_month_outlined,
              variant: RfButtonVariant.secondary,
              expand: false,
              onPressed: () => context.push(RfRoutes.trainSchedule),
            ),
          ],
        ),
        const SizedBox(height: RfSpace.s3),
        RfTextField(
          key: const Key('exercise-search'),
          controller: _search,
          label: 'Search exercises',
          hint: 'Name or alias',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: RfSpace.s2),
        Wrap(
          spacing: RfSpace.s2,
          runSpacing: RfSpace.s1,
          children: [
            for (final c in ExerciseCategory.values)
              FilterChip(
                key: Key('filter-category-${c.name}'),
                label: Text(exerciseCategoryLabel(c)),
                selected: _category == c,
                onSelected: (v) => setState(() => _category = v ? c : null),
              ),
          ],
        ),
        const SizedBox(height: RfSpace.s1),
        Wrap(
          spacing: RfSpace.s2,
          runSpacing: RfSpace.s1,
          children: [
            FilterChip(
              key: const Key('filter-muscle'),
              label: Text(
                _muscle == null
                    ? 'Muscle group'
                    : 'Muscle: ${muscleGroupLabel(_muscle!)}',
              ),
              selected: _muscle != null,
              onSelected: (_) => _pickMuscle(),
            ),
            FilterChip(
              key: const Key('filter-equipment'),
              label: Text(
                available.isEmpty
                    ? 'My equipment'
                    : 'Equipment: ${available.length} selected',
              ),
              selected: available.isNotEmpty,
              onSelected: (_) => _pickEquipment(available),
            ),
            FilterChip(
              key: const Key('equipment-bodyweight-only'),
              label: const Text('Bodyweight only'),
              selected: bodyweightOnly,
              onSelected: (v) async {
                final result = await ref
                    .read(setAvailableEquipmentProvider)
                    .setBodyweightOnly(value: v);
                if (!mounted) return;
                _showError(result);
              },
            ),
            FilterChip(
              key: const Key('show-archived'),
              label: const Text('Show archived'),
              selected: _showArchived,
              onSelected: (v) => setState(() => _showArchived = v),
            ),
          ],
        ),
        const SizedBox(height: RfSpace.s3),
      ],
    );
    return library.when(
      loading: () => const RfLoading(),
      error: (e, _) =>
          const RfErrorState(message: 'Could not load the exercise library.'),
      data: (exercises) => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        itemCount: 2 + (exercises.isEmpty ? 1 : exercises.length),
        itemBuilder: (context, i) {
          if (i == 0) return header;
          if (i == 1 + (exercises.isEmpty ? 1 : exercises.length)) {
            return const SizedBox(height: RfSpace.s8);
          }
          if (exercises.isEmpty) {
            return RfEmptyState(
              key: const Key('exercises-empty'),
              icon: Icons.fitness_center_outlined,
              message: filtered
                  ? 'No exercises match. Try clearing a filter or search.'
                  : 'No exercises yet. The library loads on first start; '
                        'or create your own.',
            );
          }
          final e = exercises[i - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: RfSpace.s2),
            child: _ExerciseRow(
              exercise: e,
              secondaryMatch:
                  _muscle != null &&
                  e.primaryMuscle != _muscle &&
                  e.secondaryMuscles.contains(_muscle),
              onOpen: () => context.push(RfRoutes.trainExercise(e.id)),
            ),
          );
        },
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.secondaryMatch,
    required this.onOpen,
  });

  final Exercise exercise;
  final bool secondaryMatch;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final meta = [
      exerciseTypeLabel(e.type),
      exerciseCategoryLabel(e.category),
      muscleGroupLabel(e.primaryMuscle),
      equipmentSummary(e.equipment),
    ].join(' · ');
    return RfCard(
      key: Key('exercise-${e.id}'),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.name,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: RfSpace.s1),
          Text(meta, style: context.rfText.caption),
          const SizedBox(height: RfSpace.s2),
          Wrap(
            spacing: RfSpace.s2,
            runSpacing: RfSpace.s1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              KeyedSubtree(
                key: Key('badge-${e.id}'),
                child: ExerciseSourceBadge(e),
              ),
              if (e.archived)
                Text(
                  'Archived',
                  key: Key('archived-${e.id}'),
                  style: context.rfText.caption,
                ),
              if (secondaryMatch)
                Text(
                  'Secondary muscle',
                  key: Key('secondary-hint-${e.id}'),
                  style: context.rfText.caption,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Continue workout" for a session that was started and not finished.
class _ContinueSessionCard extends ConsumerWidget {
  const _ContinueSessionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionProvider).value;
    if (active == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: RfSpace.s2),
      child: RfCard(
        key: const Key('continue-session'),
        accentEdge: true,
        onTap: () => context.push(RfRoutes.trainSession(active.id)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Workout in progress', style: context.rfText.caption),
                  Text(
                    active.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
