import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';
import 'package:repforge/features/delivery/application/blocker_providers.dart';
import 'package:repforge/features/delivery/application/update_blocker_status.dart';
import 'package:repforge/features/delivery/presentation/blocker_chips.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// One owner action or blocker: the full record and the status control.
class OwnerBlockerDetailScreen extends ConsumerStatefulWidget {
  const OwnerBlockerDetailScreen({required this.blockerId, super.key});

  final String blockerId;

  @override
  ConsumerState<OwnerBlockerDetailScreen> createState() =>
      _OwnerBlockerDetailScreenState();
}

class _OwnerBlockerDetailScreenState
    extends ConsumerState<OwnerBlockerDetailScreen> {
  final _note = TextEditingController();
  BlockerStatus? _status;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Whether the editor differs from the stored (or register) state.
  bool _isDirty(BlockerView view) {
    if (_status != view.status) return true;
    final current = view.state?.note ?? '';
    return _note.text.trim() != current.trim();
  }

  Future<void> _save() async {
    final status = _status;
    if (status == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref.read(updateBlockerStatusProvider)(
      blockerId: widget.blockerId,
      status: status,
      note: _note.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = result.fold((_) => null, userMessageFor);
    });
    if (result.isOk) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Status saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = ref.watch(ownerBlockerRegisterProvider);
    final blocker = register.where((b) => b.id == widget.blockerId).firstOrNull;
    if (blocker == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.blockerId)),
        body: const Padding(
          padding: EdgeInsets.all(RfSpace.gutter),
          child: RfEmptyState(
            key: Key('blocker-missing'),
            message: 'This blocker is not in the register.',
            icon: Icons.search_off_outlined,
          ),
        ),
      );
    }
    final views = ref.watch(blockerViewsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(blocker.id)),
      body: views.when(
        loading: () => const RfLoading(),
        error: (_, _) => const Padding(
          padding: EdgeInsets.all(RfSpace.gutter),
          child: RfErrorState(message: 'Could not load this blocker.'),
        ),
        data: (all) {
          final view = all.firstWhere((v) => v.blocker.id == blocker.id);
          // Seed the editor once from the stored state; later stream updates
          // (our own save) must not overwrite what the owner is typing.
          if (_status == null) {
            _status = view.status;
            _note.text = view.state?.note ?? '';
          }
          return _body(blocker, view);
        },
      ),
    );
  }

  Widget _section(String title, Widget body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: RfSpace.s3),
      child: RfCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: RfSpace.s2),
            body,
          ],
        ),
      ),
    );
  }

  Widget _text(String text) =>
      Text(text, style: Theme.of(context).textTheme.bodyMedium);

  Widget _body(OwnerBlocker b, BlockerView view) {
    final theme = Theme.of(context);
    final updated = view.state?.updatedAt;
    return ListView(
      padding: const EdgeInsets.all(RfSpace.gutter),
      children: [
        RfScreenTitle(
          title: b.title,
          caption: '${b.workPackage.label} · ${b.stage} · ${b.reference}',
        ),
        Wrap(
          spacing: RfSpace.s2,
          runSpacing: RfSpace.s2,
          children: [
            BlockerPill(
              label: b.category.label,
              color: context.rf.textSecondary,
            ),
            PriorityPill(b.priority),
            StatusPill(view.status),
            AssigneePill(b.assignee),
          ],
        ),
        const SizedBox(height: RfSpace.s4),
        _section('Description', _text(b.description)),
        _section('Why it is blocked', _text(b.whyBlocked)),
        _section('Action required', _text(b.actionRequired)),
        _section('Recommended response', _text(b.recommendation)),
        _section('Consequences of alternatives', _text(b.consequences)),
        _section(
          'Dependencies',
          b.dependencies.isEmpty
              ? _text('None')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final d in b.dependencies) _text(d)],
                ),
        ),
        _section(
          'Supporting evidence',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, e) in b.evidence.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: RfSpace.s1),
                  child: SelectableText(
                    e.reference == null
                        ? e.label
                        : '${e.label}: ${e.reference}',
                    key: Key('blocker-evidence-$i'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
        _section(
          'Related delivery record',
          SelectableText(b.deliveryRecord, style: context.rfText.meta),
        ),
        _section(
          'Status',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioGroup<BlockerStatus>(
                key: const Key('blocker-status-choice'),
                groupValue: _status,
                onChanged: (s) => setState(() {
                  _status = s;
                  _error = null;
                }),
                child: Column(
                  children: [
                    for (final s in BlockerStatus.values)
                      RadioListTile<BlockerStatus>(
                        value: s,
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.label),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: RfSpace.s2),
              Text(
                'Selected: ${_status?.label ?? ''}',
                key: const Key('blocker-status-selected'),
                style: theme.textTheme.bodySmall,
              ),
              if (_status == BlockerStatus.resolved &&
                  UpdateBlockerStatus.needsResolutionNote(b)) ...[
                const SizedBox(height: RfSpace.s1),
                Text(
                  'Record the decision in the note; agents never resolve '
                  'owner items.',
                  key: const Key('blocker-resolution-hint'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: RfSpace.s3),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _note,
                builder: (_, value, _) => RfTextField(
                  key: const Key('blocker-note-field'),
                  label: 'Note (optional)',
                  controller: _note,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  // Counts UTF-16 code units, the unit the use case checks,
                  // so the counter and the limit always agree.
                  inputFormatters: const [
                    TextInputFormatter.withFunction(_limitNote),
                  ],
                  helper:
                      '${value.text.length}/'
                      '${UpdateBlockerStatus.maxNoteLength}',
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              const SizedBox(height: RfSpace.s2),
              Text(
                updated == null
                    ? 'Register status, not yet changed in the app'
                    : 'Changed ${_formatUtc(updated)}',
                key: const Key('blocker-state-updated'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: RfSpace.s2),
              Text(
                'An owner decision counts as decided only when the owner '
                'records it here or in the delivery record. Agents never '
                'resolve owner decisions.',
                style: theme.textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: RfSpace.s2),
                Text(
                  _error!,
                  key: const Key('blocker-status-error'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.rf.alertText,
                  ),
                ),
              ],
              const SizedBox(height: RfSpace.s3),
              RfButton(
                key: const Key('blocker-save-status'),
                label: 'Save status',
                loading: _saving,
                onPressed: _isDirty(view) ? _save : null,
              ),
            ],
          ),
        ),
        _section('History', _history(view.state)),
        const SizedBox(height: RfSpace.s8),
      ],
    );
  }

  Widget _history(BlockerState? state) {
    final theme = Theme.of(context);
    if (state == null) {
      return Text(
        'No changes recorded in the app yet.',
        key: const Key('blocker-history-empty'),
        style: theme.textTheme.bodyMedium,
      );
    }
    final changes = state.allChanges.reversed.toList();
    return Column(
      key: const Key('blocker-history'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, c) in changes.indexed)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == changes.length - 1 ? 0 : RfSpace.s3,
            ),
            child: Column(
              key: Key('blocker-history-$i'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.status.label, style: theme.textTheme.titleSmall),
                Text(_formatUtc(c.at), style: theme.textTheme.bodySmall),
                if (c.note != null) ...[
                  const SizedBox(height: RfSpace.s1),
                  Text(c.note!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "7 Nov 2026, 06:30 UTC".
  static String _formatUtc(DateTime at) {
    final t = at.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.day} ${_months[t.month - 1]} ${t.year}, '
        '${two(t.hour)}:${two(t.minute)} UTC';
  }
}

/// Truncates the note to [UpdateBlockerStatus.maxNoteLength] UTF-16 code
/// units without splitting a surrogate pair, so the counter, the limit and
/// the use case all agree on the unit.
TextEditingValue _limitNote(
  TextEditingValue oldValue,
  TextEditingValue newValue,
) {
  const max = UpdateBlockerStatus.maxNoteLength;
  final text = newValue.text;
  if (text.length <= max) return newValue;
  var cut = max;
  final last = text.codeUnitAt(cut - 1);
  if (last >= 0xD800 && last <= 0xDBFF) cut--;
  return TextEditingValue(
    text: text.substring(0, cut),
    selection: TextSelection.collapsed(offset: cut),
  );
}
