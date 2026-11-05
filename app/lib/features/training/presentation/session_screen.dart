import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/volume.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/rest_timer_controller.dart';
import 'package:repforge/features/training/application/session_use_cases.dart';
import 'package:repforge/features/training/application/session_view.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/exercise_picker.dart';
import 'package:repforge/features/training/presentation/rest_timer_panel.dart';
import 'package:repforge/features/training/presentation/session_dialogs.dart';
import 'package:repforge/features/training/presentation/session_set_widgets.dart';
import 'package:repforge/features/training/presentation/session_starter.dart';
import 'package:repforge/features/training/presentation/set_defaults.dart';
import 'package:repforge/features/training/presentation/volume_format.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// The workout session screen (TRN-016..021, TRN-023, TRN-024, TRN-026,
/// TRN-027): ordered exercise entries with notes, the logged sets with PR
/// badges, a pre-filled row for the next set, the rest timer, volume, and
/// finish. A finished session opens here too, to correct its sets.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  String get _id => widget.sessionId;

  void _refresh() => ref.invalidate(sessionViewProvider(_id));

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// Runs a write, refreshes the view and reports an error. True on success.
  Future<bool> _do<T>(Future<Result<T>> Function() op) async {
    final result = await op();
    if (!mounted) return false;
    _refresh();
    if (result case Err(:final error)) {
      _snack(userMessageFor(error));
      return false;
    }
    return true;
  }

  Future<void> _finish() async {
    final ok = await _do(() => ref.read(finishSessionProvider)(_id));
    if (!ok || !mounted) return;
    ref.read(restTimerProvider.notifier).skip();
    ref.read(startWarningsProvider.notifier).dismiss(_id);
    context.pushReplacement(RfRoutes.trainHistoryDetail(_id));
  }

  Future<void> _editDetails(WorkoutSession s) async {
    final input = await showEditSessionDialog(context, s);
    if (input == null || !mounted) return;
    await _do(
      () => ref.read(editSessionDetailsProvider)(
        sessionId: _id,
        name: input.name,
        startedAt: input.startedAt,
        endedAt: input.endedAt,
      ),
    );
  }

  Future<void> _sessionNote(WorkoutSession s) async {
    final text = await showNoteDialog(
      context,
      title: 'Workout note',
      initial: s.notes,
      keyPrefix: 'session-note',
    );
    if (text == null || !mounted) return;
    await _do(
      () => ref.read(setSessionNoteProvider)(sessionId: _id, note: text),
    );
  }

  Future<void> _entryNote(SessionExercise e) async {
    final text = await showNoteDialog(
      context,
      title: 'Exercise note',
      initial: e.note ?? '',
      keyPrefix: 'entry-note',
    );
    if (text == null || !mounted) return;
    await _do(
      () => ref.read(setSessionExerciseNoteProvider)(
        sessionId: _id,
        sessionExerciseId: e.id,
        note: text,
      ),
    );
  }

  Future<void> _add() async {
    final picked = await pickExercise(context);
    if (picked == null || !mounted) return;
    await _do(
      () => ref.read(addSessionExerciseProvider)(
        sessionId: _id,
        exerciseId: picked.id,
      ),
    );
  }

  Future<void> _replace(SessionExercise e) async {
    final picked = await pickExercise(context);
    if (picked == null || !mounted) return;
    await _do(
      () => ref.read(replaceSessionExerciseProvider)(
        sessionId: _id,
        sessionExerciseId: e.id,
        newExerciseId: picked.id,
      ),
    );
  }

  Future<void> _remove(SessionExercise e, int setCount, String name) async {
    if (setCount > 0) {
      final ok = await confirmAction(
        context,
        title: 'Remove $name?',
        message:
            'Its $setCount logged ${setCount == 1 ? 'set' : 'sets'} will be '
            'deleted too.',
        confirmLabel: 'Remove',
        confirmKey: 'remove-confirm',
      );
      if (!ok || !mounted) return;
    }
    await _do(
      () => ref.read(removeSessionExerciseProvider)(
        sessionId: _id,
        sessionExerciseId: e.id,
      ),
    );
  }

  Future<void> _move(int from, int to) => _do(
    () => ref.read(reorderSessionExercisesProvider)(
      sessionId: _id,
      from: from,
      to: to,
    ),
  );

  Future<void> _editSet(SessionSet s, int number, String name) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditSetSheet(
        sessionId: _id,
        set: s,
        number: number,
        exerciseName: name,
      ),
    );
    if (saved ?? false) {
      if (mounted) _refresh();
    }
  }

  Future<void> _deleteSet(SessionSet s, int number) async {
    final ok = await confirmAction(
      context,
      title: 'Delete set $number?',
      message: 'This removes the set. Records and volume update.',
      confirmLabel: 'Delete',
      confirmKey: 'delete-set-confirm',
    );
    if (!ok || !mounted) return;
    await _do(() => ref.read(deleteSetProvider)(sessionId: _id, setId: s.id));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionViewProvider(_id));
    final view = async.value;
    if (view == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: async.hasError
            ? RfErrorState(
                message: 'Could not load the workout.',
                onRetry: _refresh,
              )
            : async.isLoading
            ? const RfLoading()
            : const Padding(
                padding: EdgeInsets.all(RfSpace.gutter),
                child: RfEmptyState(
                  key: Key('session-missing'),
                  message: 'That workout no longer exists.',
                ),
              ),
      );
    }
    final session = view.session;
    final entries = session.exercises;
    final warnings = ref.watch(startWarningsProvider)[_id] ?? const [];
    final start = DateFormat('EEE d MMM, HH:mm')
        .format(session.startedAt.toLocal());
    return Scaffold(
      appBar: AppBar(
        title: Text(session.name, key: const Key('session-title')),
        actions: [
          IconButton(
            key: const Key('session-edit-details'),
            tooltip: 'Edit workout details',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editDetails(session),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
              children: [
                const SizedBox(height: RfSpace.s3),
                Text(
                  session.endedAt == null ? 'Started $start' : 'Done · $start',
                  key: const Key('session-started'),
                  style: context.rfText.caption,
                ),
                Text(
                  'Volume: ${formatVolume(VolumeRules.ofSession(session))}',
                  key: const Key('session-volume'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (session.notes.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: RfSpace.s1),
                    child: Text(
                      session.notes,
                      key: const Key('session-note-text'),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RfButton(
                    key: const Key('session-note-edit'),
                    label: session.notes.trim().isEmpty
                        ? 'Add workout note'
                        : 'Edit workout note',
                    icon: Icons.notes,
                    variant: RfButtonVariant.tertiary,
                    expand: false,
                    onPressed: () => _sessionNote(session),
                  ),
                ),
                if (warnings.isNotEmpty)
                  _WarningBanner(
                    warnings: warnings,
                    onDismiss: () =>
                        ref.read(startWarningsProvider.notifier).dismiss(_id),
                  ),
                if (entries.isEmpty)
                  const RfEmptyState(
                    key: Key('session-no-exercises'),
                    icon: Icons.fitness_center_outlined,
                    message: 'No exercises yet. Add one to start logging.',
                  ),
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RfSpace.s3),
                    child: _EntryCard(
                      view: view,
                      entry: entries[i],
                      index: i,
                      count: entries.length,
                      onMove: _move,
                      onNote: _entryNote,
                      onReplace: _replace,
                      onRemove: _remove,
                      onEditSet: _editSet,
                      onDeleteSet: _deleteSet,
                    ),
                  ),
                RfButton(
                  key: const Key('add-exercise'),
                  label: 'Add exercise',
                  icon: Icons.add,
                  variant: RfButtonVariant.secondary,
                  onPressed: _add,
                ),
                const SizedBox(height: RfSpace.s3),
                if (session.endedAt == null)
                  RfButton(
                    key: const Key('finish-session'),
                    label: 'Finish workout',
                    icon: Icons.flag_outlined,
                    onPressed: _finish,
                  )
                else
                  RfButton(
                    key: const Key('session-open-detail'),
                    label: 'Back to workout summary',
                    variant: RfButtonVariant.tertiary,
                    onPressed: () => context.pushReplacement(
                      RfRoutes.trainHistoryDetail(_id),
                    ),
                  ),
                const SizedBox(height: RfSpace.s8),
              ],
            ),
          ),
          const RestTimerPanel(),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.warnings, required this.onDismiss});

  final List<StartWarning> warnings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RfSpace.s3),
    child: RfCard(
      key: const Key('start-warnings'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in warnings)
            Text(
              startWarningText(w),
              key: Key('start-warning-${w.exerciseId}'),
            ),
          RfButton(
            key: const Key('start-warnings-dismiss'),
            label: 'Dismiss',
            variant: RfButtonVariant.tertiary,
            expand: false,
            onPressed: onDismiss,
          ),
        ],
      ),
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.view,
    required this.entry,
    required this.index,
    required this.count,
    required this.onMove,
    required this.onNote,
    required this.onReplace,
    required this.onRemove,
    required this.onEditSet,
    required this.onDeleteSet,
  });

  final SessionView view;
  final SessionExercise entry;
  final int index;
  final int count;
  final Future<void> Function(int from, int to) onMove;
  final Future<void> Function(SessionExercise e) onNote;
  final Future<void> Function(SessionExercise e) onReplace;
  final Future<void> Function(SessionExercise e, int sets, String name)
  onRemove;
  final Future<void> Function(SessionSet s, int number, String name) onEditSet;
  final Future<void> Function(SessionSet s, int number) onDeleteSet;

  @override
  Widget build(BuildContext context) {
    final id = entry.id;
    final exercise = view.exercises[entry.exerciseId];
    final name = exercise?.name ?? 'Removed exercise';
    final sets = view.setsOf(id);
    final prefill = view.prefill[id];
    final theme = Theme.of(context);
    final type = exercise?.type;
    final hint = type == null
        ? null
        : previousHint(
            type,
            sets.where((s) => s.kind != SetKind.warmUp).length,
            prefill,
            UnitSystem.metric,
          );
    final plan = planHint(prefill);
    return RfCard(
      key: Key('entry-$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    name,
                    key: Key('entry-name-$id'),
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                key: Key('entry-up-$id'),
                tooltip: 'Move $name up',
                icon: const Icon(Icons.arrow_upward),
                onPressed: index == 0
                    ? null
                    : () => unawaited(onMove(index, index - 1)),
              ),
              IconButton(
                key: Key('entry-down-$id'),
                tooltip: 'Move $name down',
                icon: const Icon(Icons.arrow_downward),
                onPressed: index == count - 1
                    ? null
                    : () => unawaited(onMove(index, index + 1)),
              ),
              PopupMenuButton<String>(
                key: Key('entry-menu-$id'),
                tooltip: 'More for $name',
                onSelected: (v) {
                  switch (v) {
                    case 'note':
                      unawaited(onNote(entry));
                    case 'replace':
                      unawaited(onReplace(entry));
                    case 'remove':
                      unawaited(onRemove(entry, sets.length, name));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    key: Key('entry-menu-note-$id'),
                    value: 'note',
                    child: const Text('Exercise note'),
                  ),
                  PopupMenuItem(
                    key: Key('entry-menu-replace-$id'),
                    value: 'replace',
                    child: const Text('Replace exercise'),
                  ),
                  PopupMenuItem(
                    key: Key('entry-menu-remove-$id'),
                    value: 'remove',
                    child: const Text('Remove exercise'),
                  ),
                ],
              ),
            ],
          ),
          Text(
            'Volume: ${formatVolume(VolumeRules.total(sets))}',
            key: Key('entry-volume-$id'),
            style: context.rfText.caption,
          ),
          if ((entry.note ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: RfSpace.s1),
              child: Text(entry.note!, key: Key('entry-note-text-$id')),
            ),
          if (plan != null)
            Text(
              plan,
              key: Key('plan-hint-$id'),
              style: context.rfText.caption,
            ),
          if (hint != null)
            Text(
              hint,
              key: Key('prev-hint-$id'),
              style: context.rfText.caption,
            ),
          const SizedBox(height: RfSpace.s2),
          for (var i = 0; i < sets.length; i++)
            LoggedSetRow(
              set: sets[i],
              number: i + 1,
              isRecord: view.recordSetIds.contains(sets[i].id),
              onEdit: () => onEditSet(sets[i], i + 1, name),
              onDelete: () => onDeleteSet(sets[i], i + 1),
            ),
          const SizedBox(height: RfSpace.s2),
          if (exercise == null)
            Text(
              'This exercise was deleted. Its sets stay in your history.',
              key: Key('entry-removed-$id'),
              style: context.rfText.caption,
            )
          else if (exercise.archived)
            Text(
              'This exercise is archived. Restore it to log more sets.',
              key: Key('entry-archived-$id'),
              style: context.rfText.caption,
            )
          else
            NewSetRow(
              // A new row (and fresh pre-fill) after every logged or deleted
              // set of the entry.
              key: ValueKey('newset-row-$id-${sets.length}'),
              sessionId: view.session.id,
              entry: entry,
              exercise: exercise,
              entrySets: sets,
              prefill: prefill,
            ),
        ],
      ),
    );
  }
}
