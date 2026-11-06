import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/volume.dart';
import 'package:repforge/features/training/application/session_view.dart';
import 'package:repforge/features/training/presentation/session_starter.dart';
import 'package:repforge/features/training/presentation/volume_format.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

/// Workout history (TRN-024, TRN-025): finished and in-progress sessions,
/// newest first, 20 at first and 20 more each time the end is reached.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _limit = sessionHistoryPage;
  List<WorkoutSession>? _last;

  void _more(List<WorkoutSession> shown) {
    // Only when the current page is full: otherwise there is nothing more.
    if (shown.length < _limit) return;
    setState(() => _limit += sessionHistoryPage);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionHistoryProvider(_limit));
    // Keep showing the previous page while the next one loads, so the list
    // does not jump back to the top.
    final sessions = async.value ?? _last;
    if (async.value != null) _last = async.value;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: sessions == null
          ? (async.hasError
                ? const RfErrorState(message: 'Could not load your history.')
                : const RfLoading())
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 300) _more(sessions);
                return false;
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
                children: [
                  const RfScreenTitle(
                    title: 'History',
                    caption: 'Your workouts, newest first',
                  ),
                  if (sessions.isEmpty)
                    const RfEmptyState(
                      key: Key('history-list-empty'),
                      icon: Icons.history,
                      message: 'No workouts yet. Start one from the Train tab.',
                    ),
                  for (final s in sessions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: RfSpace.s2),
                      child: _SessionRow(session: s),
                    ),
                  if (sessions.length >= _limit)
                    RfButton(
                      key: const Key('history-load-more'),
                      label: 'Show more',
                      variant: RfButtonVariant.secondary,
                      onPressed: () => _more(sessions),
                    ),
                  const SizedBox(height: RfSpace.s8),
                ],
              ),
            ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = session;
    final date = DateFormat('EEE d MMM y, HH:mm').format(s.startedAt.toLocal());
    final minutes = s.endedAt?.difference(s.startedAt).inMinutes;
    final meta = [
      date,
      if (minutes == null) 'In progress' else '$minutes min',
      if (s.exercises.length == 1)
        '1 exercise'
      else
        '${s.exercises.length} exercises',
    ].join(' · ');
    return RfCard(
      key: Key('history-session-${s.id}'),
      onTap: () => context.push(
        s.endedAt == null
            ? RfRoutes.trainSession(s.id)
            : RfRoutes.trainHistoryDetail(s.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.name,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(meta, style: context.rfText.caption),
          Text(
            'Volume: ${formatVolume(VolumeRules.ofSession(s))}',
            key: Key('history-volume-${s.id}'),
            style: context.rfText.caption,
          ),
          if (s.notes.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: RfSpace.s1),
              child: Text(
                s.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                key: Key('history-note-${s.id}'),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: RfButton(
              key: Key('history-repeat-${s.id}'),
              label: 'Repeat workout',
              icon: Icons.replay,
              variant: RfButtonVariant.tertiary,
              expand: false,
              onPressed: () => ref.startFromPast(context, s.id),
            ),
          ),
        ],
      ),
    );
  }
}
