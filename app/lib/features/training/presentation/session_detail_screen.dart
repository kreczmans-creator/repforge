import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/volume.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/session_view.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/session_dialogs.dart';
import 'package:repforge/features/training/presentation/session_set_widgets.dart';
import 'package:repforge/features/training/presentation/session_starter.dart';
import 'package:repforge/features/training/presentation/set_form.dart';
import 'package:repforge/features/training/presentation/set_format.dart';
import 'package:repforge/features/training/presentation/volume_format.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// How long the Undo snackbar for a deleted workout stays (TRN-024(2) asks
/// for at least 10 s).
const sessionUndoWindow = Duration(seconds: 12);

/// One workout in the history (TRN-023..027): notes, sets with kind, exertion
/// and PR badges, volume per exercise and for the workout, with edit, repeat
/// and delete (with confirmation and Undo).
class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  String get _id => widget.sessionId;

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _editDetails(WorkoutSession s) async {
    final input = await showEditSessionDialog(context, s);
    if (input == null || !mounted) return;
    final result = await ref.read(editSessionDetailsProvider)(
      sessionId: _id,
      name: input.name,
      startedAt: input.startedAt,
      endedAt: input.endedAt,
    );
    if (!mounted) return;
    ref.invalidate(sessionViewProvider(_id));
    if (result case Err(:final error)) _snack(userMessageFor(error));
  }

  Future<void> _delete(WorkoutSession s) async {
    final ok = await confirmAction(
      context,
      title: 'Delete "${s.name}"?',
      message: 'You can undo this for a few seconds afterwards.',
      confirmLabel: 'Delete',
      confirmKey: 'delete-session-confirm',
    );
    if (!ok || !mounted) return;
    // Everything the Undo needs is taken now: this screen is gone by then.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final restore = ref.read(restoreSessionProvider);
    final result = await ref.read(deleteSessionProvider)(_id);
    if (!mounted) return;
    if (result case Err(:final error)) {
      _snack(userMessageFor(error));
      return;
    }
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(RfRoutes.trainHistory);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('session-deleted-snackbar'),
          duration: sessionUndoWindow,
          // A snackbar with an action stays until dismissed unless told not to.
          persist: false,
          content: Text('Deleted "${s.name}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final r = await restore(s.id);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      r is Err<WorkoutSession>
                          ? userMessageFor(r.error)
                          : 'Restored "${s.name}"',
                    ),
                  ),
                );
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionViewProvider(_id));
    final view = async.value;
    if (view == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: async.hasError
            ? const RfErrorState(message: 'Could not load the workout.')
            : async.isLoading
            ? const RfLoading()
            : const Padding(
                padding: EdgeInsets.all(RfSpace.gutter),
                child: RfEmptyState(
                  key: Key('detail-missing'),
                  message: 'That workout no longer exists.',
                ),
              ),
      );
    }
    final s = view.session;
    final date = DateFormat('EEE d MMM y, HH:mm').format(s.startedAt.toLocal());
    final minutes = s.endedAt?.difference(s.startedAt).inMinutes;
    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const SizedBox(height: RfSpace.s3),
          Semantics(
            header: true,
            child: Text(
              s.name,
              key: const Key('detail-title'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Text(
            [
              date,
              if (minutes == null) 'In progress' else '$minutes min',
            ].join(' · '),
            key: const Key('detail-meta'),
            style: context.rfText.caption,
          ),
          const SizedBox(height: RfSpace.s1),
          Text(
            'Volume: ${formatVolume(VolumeRules.ofSession(s))}',
            key: const Key('detail-volume'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (s.notes.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: RfSpace.s2),
              child: Text(s.notes, key: const Key('detail-note')),
            ),
          const SizedBox(height: RfSpace.s3),
          Wrap(
            spacing: RfSpace.s2,
            runSpacing: RfSpace.s2,
            children: [
              RfButton(
                key: const Key('detail-edit-details'),
                label: 'Edit details',
                icon: Icons.edit_outlined,
                variant: RfButtonVariant.secondary,
                expand: false,
                onPressed: () => _editDetails(s),
              ),
              RfButton(
                key: const Key('detail-edit-sets'),
                label: 'Edit sets',
                icon: Icons.tune,
                variant: RfButtonVariant.secondary,
                expand: false,
                onPressed: () => context.push(RfRoutes.trainSession(s.id)),
              ),
              RfButton(
                key: const Key('detail-repeat'),
                label: 'Repeat workout',
                icon: Icons.replay,
                variant: RfButtonVariant.secondary,
                expand: false,
                onPressed: () => ref.startFromPast(context, s.id),
              ),
              RfButton(
                key: const Key('detail-delete'),
                label: 'Delete',
                icon: Icons.delete_outline,
                variant: RfButtonVariant.danger,
                expand: false,
                onPressed: () => _delete(s),
              ),
            ],
          ),
          const SizedBox(height: RfSpace.s4),
          if (s.exercises.isEmpty)
            const RfEmptyState(
              key: Key('detail-no-exercises'),
              icon: Icons.fitness_center_outlined,
              message: 'No exercises in this workout.',
            ),
          for (final e in s.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: RfSpace.s3),
              child: _DetailEntry(view: view, entry: e),
            ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}

class _DetailEntry extends StatelessWidget {
  const _DetailEntry({required this.view, required this.entry});

  final SessionView view;
  final SessionExercise entry;

  @override
  Widget build(BuildContext context) {
    final id = entry.id;
    final name = view.exercises[entry.exerciseId]?.name ?? 'Removed exercise';
    final sets = view.setsOf(id);
    return RfCard(
      key: Key('detail-entry-$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(name, style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(
            'Volume: ${formatVolume(VolumeRules.total(sets))}',
            key: Key('detail-entry-volume-$id'),
            style: context.rfText.caption,
          ),
          if ((entry.note ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: RfSpace.s1),
              child: Text(entry.note!, key: Key('detail-entry-note-$id')),
            ),
          const SizedBox(height: RfSpace.s2),
          if (sets.isEmpty)
            Text('No sets logged.', style: context.rfText.caption),
          for (var i = 0; i < sets.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text('Set ${i + 1}', style: context.rfText.caption),
                  ),
                  Expanded(
                    child: Text(
                      [
                        formatSetData(sets[i].data, UnitSystem.metric),
                        if (sets[i].kind != SetKind.working)
                          setKindLabel(sets[i].kind),
                        if (sets[i].exertion != null)
                          formatExertion(sets[i].exertion!),
                      ].join(' · '),
                      key: Key('detail-set-${sets[i].id}'),
                    ),
                  ),
                  if (view.recordSetIds.contains(sets[i].id))
                    PrBadge(setId: sets[i].id),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
