import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/plan_providers.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/session_dialogs.dart';
import 'package:repforge/features/training/presentation/session_starter.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Workout plans and training splits (TRN-013, TRN-014): list, create, edit,
/// archive and restore. Reached from the Train tab.
class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  bool _showArchived = false;

  Future<void> _setArchived(WorkoutPlan plan, {required bool archived}) async {
    final result = await ref.read(archivePlanProvider)(
      plan.id,
      archived: archived,
    );
    if (!mounted) return;
    if (result case Err(:final error)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  Future<void> _duplicate(WorkoutPlan plan) async {
    final result = await ref.read(duplicatePlanProvider)(plan.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (result) {
          Ok(:final value) => 'Created "${value.name}"',
          Err(:final error) => userMessageFor(error),
        }),
      ),
    );
  }

  Future<void> _delete(WorkoutPlan plan) async {
    final ok = await confirmAction(
      context,
      title: 'Delete "${plan.name}"?',
      message:
          'The workout is removed. Past workouts and scheduled sessions '
          'are not changed.',
      confirmLabel: 'Delete',
      confirmKey: 'plan-delete-confirm',
    );
    if (!ok || !mounted) return;
    final result = await ref.read(deletePlanProvider)(plan.id);
    if (!mounted) return;
    if (result case Err(:final error)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(allWorkoutPlansProvider);
    final splits = ref.watch(trainingSplitsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: plans.when(
        loading: () => const RfLoading(),
        error: (e, _) =>
            const RfErrorState(message: 'Could not load your workouts.'),
        data: (all) {
          final shown = [
            for (final p in all)
              if (_showArchived || !p.archived) p,
          ];
          final hasArchived = all.any((p) => p.archived);
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
            children: [
              const RfScreenTitle(
                title: 'Workouts',
                caption: 'Plans, splits and your schedule',
              ),
              RfButton(
                key: const Key('new-plan'),
                label: 'New workout',
                icon: Icons.add,
                onPressed: () => context.push(RfRoutes.trainPlanNew),
              ),
              const SizedBox(height: RfSpace.s2),
              RfButton(
                key: const Key('plans-open-schedule'),
                label: 'Schedule',
                icon: Icons.calendar_month_outlined,
                variant: RfButtonVariant.secondary,
                onPressed: () => context.push(RfRoutes.trainSchedule),
              ),
              const SizedBox(height: RfSpace.s4),
              if (hasArchived)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    key: const Key('plans-show-archived'),
                    label: const Text('Show archived'),
                    selected: _showArchived,
                    onSelected: (v) => setState(() => _showArchived = v),
                  ),
                ),
              if (shown.isEmpty)
                const RfEmptyState(
                  key: Key('plans-empty'),
                  icon: Icons.list_alt_outlined,
                  message: 'No workouts yet. Create one to schedule it.',
                ),
              for (final p in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: RfSpace.s2),
                  child: RfCard(
                    key: Key('plan-${p.id}'),
                    onTap: () => context.push(RfRoutes.trainPlan(p.id)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                [
                                  _exerciseCount(p),
                                  if (p.archived) 'Archived',
                                ].join(' · '),
                                style: context.rfText.caption,
                              ),
                            ],
                          ),
                        ),
                        if (!p.archived)
                          IconButton(
                            key: Key('plan-start-${p.id}'),
                            tooltip: 'Start ${p.name}',
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () => ref.startFromPlan(context, p.id),
                          ),
                        IconButton(
                          key: Key('plan-duplicate-${p.id}'),
                          tooltip: 'Duplicate ${p.name}',
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: () => _duplicate(p),
                        ),
                        IconButton(
                          key: Key('plan-delete-${p.id}'),
                          tooltip: 'Delete ${p.name}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(p),
                        ),
                        if (p.archived)
                          IconButton(
                            key: Key('plan-unarchive-${p.id}'),
                            tooltip: 'Restore ${p.name}',
                            icon: const Icon(Icons.unarchive_outlined),
                            onPressed: () => _setArchived(p, archived: false),
                          )
                        else
                          IconButton(
                            key: Key('plan-archive-${p.id}'),
                            tooltip: 'Archive ${p.name}',
                            icon: const Icon(Icons.archive_outlined),
                            onPressed: () => _setArchived(p, archived: true),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: RfSpace.s4),
              const RfSectionHeader(title: 'Splits'),
              RfButton(
                key: const Key('new-split'),
                label: 'New split',
                icon: Icons.add,
                variant: RfButtonVariant.secondary,
                onPressed: () => context.push(RfRoutes.trainSplitNew),
              ),
              const SizedBox(height: RfSpace.s2),
              ...switch (splits) {
                AsyncData(:final value) when value.isEmpty => [
                  const RfEmptyState(
                    key: Key('splits-empty'),
                    icon: Icons.view_week_outlined,
                    message:
                        'No splits yet. A split repeats your workouts over '
                        '1 to 14 days.',
                  ),
                ],
                AsyncData(:final value) => [
                  for (final s in value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: RfSpace.s2),
                      child: RfCard(
                        key: Key('split-${s.id}'),
                        onTap: () => context.push(RfRoutes.trainSplit(s.id)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _splitSummary(s),
                              style: context.rfText.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                AsyncError() => [
                  const RfErrorState(message: 'Could not load your splits.'),
                ],
                _ => [const RfLoading()],
              },
              const SizedBox(height: RfSpace.s8),
            ],
          );
        },
      ),
    );
  }
}

String _splitSummary(TrainingSplit s) {
  final rest = s.days.where((d) => d.isRest).length;
  return '${s.cycleDays}-day cycle · ${s.cycleDays - rest} workouts · '
      '$rest rest';
}

String _exerciseCount(WorkoutPlan p) {
  final n = p.exercises.length;
  return n == 1 ? '1 exercise' : '$n exercises';
}
