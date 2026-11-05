import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/training_labels.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/tokens.dart';

/// Opens the exercise picker and returns the chosen exercise, or null when
/// the user goes back. Archived exercises are not offered (TRN-012(2)).
Future<Exercise?> pickExercise(BuildContext context) => Navigator.of(context)
    .push<Exercise>(MaterialPageRoute(builder: (_) => const ExercisePicker()));

/// Searchable list of the active exercise library. Pops the tapped exercise.
class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({super.key});

  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  final _search = TextEditingController();
  ExerciseCategory? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(
      exerciseLibraryProvider(
        ExerciseQuery(text: _search.text, category: _category),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Choose an exercise')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RfSpace.gutter,
              RfSpace.s3,
              RfSpace.gutter,
              RfSpace.s2,
            ),
            child: RfTextField(
              key: const Key('picker-search'),
              controller: _search,
              label: 'Search exercises',
              hint: 'Name or alias',
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: RfSpace.s2,
                runSpacing: RfSpace.s1,
                children: [
                  for (final c in ExerciseCategory.values)
                    FilterChip(
                      key: Key('picker-category-${c.name}'),
                      label: Text(exerciseCategoryLabel(c)),
                      selected: _category == c,
                      onSelected: (v) =>
                          setState(() => _category = v ? c : null),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: library.when(
              loading: () => const RfLoading(),
              error: (e, _) => const RfErrorState(
                message: 'Could not load the exercise library.',
              ),
              data: (exercises) => exercises.isEmpty
                  ? const RfEmptyState(
                      key: Key('picker-empty'),
                      icon: Icons.fitness_center_outlined,
                      message: 'No exercises match.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: RfSpace.gutter,
                      ),
                      itemCount: exercises.length,
                      itemBuilder: (context, i) {
                        final e = exercises[i];
                        return ListTile(
                          key: Key('picker-exercise-${e.id}'),
                          contentPadding: EdgeInsets.zero,
                          minVerticalPadding: RfSpace.s2,
                          title: Text(e.name),
                          subtitle: Text(
                            '${exerciseTypeLabel(e.type)} · '
                            '${muscleGroupLabel(e.primaryMuscle)}',
                          ),
                          onTap: () => Navigator.of(context).pop(e),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
