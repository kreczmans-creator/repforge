import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';
import 'package:repforge/features/delivery/application/blocker_providers.dart';
import 'package:repforge/features/delivery/presentation/blocker_chips.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/tokens.dart';

enum _Scope { open, resolved, all }

/// Owner actions and delivery blockers: everything the delivery needs from
/// the owner, grouped by work package, with filters.
class OwnerBlockersScreen extends ConsumerStatefulWidget {
  const OwnerBlockersScreen({super.key});

  @override
  ConsumerState<OwnerBlockersScreen> createState() =>
      _OwnerBlockersScreenState();
}

class _OwnerBlockersScreenState extends ConsumerState<OwnerBlockersScreen> {
  BlockerWorkPackage? _wp;
  BlockerPriority? _priority;
  BlockerCategory? _category;
  BlockerStatus? _status;
  _Scope _scope = _Scope.open;

  bool _matches(BlockerView v) {
    if (_wp != null && v.blocker.workPackage != _wp) return false;
    if (_priority != null && v.blocker.priority != _priority) return false;
    if (_category != null && v.blocker.category != _category) return false;
    if (_status != null && v.status != _status) return false;
    return switch (_scope) {
      _Scope.open => v.isOpen,
      _Scope.resolved => !v.isOpen,
      _Scope.all => true,
    };
  }

  void _clearFilters() => setState(() {
    _wp = null;
    _priority = null;
    _category = null;
    _status = null;
    _scope = _Scope.open;
  });

  /// Keeps scope and status consistent so they never contradict.
  void _setStatus(BlockerStatus? v) => setState(() {
    _status = v;
    if (v == null) return;
    _scope = v.isOpen ? _Scope.open : _Scope.resolved;
  });

  void _setScope(_Scope v) => setState(() {
    _scope = v;
    final status = _status;
    if (status == null || v == _Scope.all) return;
    if (status.isOpen != (v == _Scope.open)) _status = null;
  });

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(blockerViewsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Owner actions')),
      body: ListView(
        padding: const EdgeInsets.all(RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Owner Actions & Delivery Blockers',
            caption: 'What the delivery needs from you, in one place',
          ),
          ...views.when(
            loading: () => const [RfLoading()],
            error: (_, _) => [
              RfErrorState(
                message: 'Could not load the blockers.',
                onRetry: () => ref.invalidate(blockerStatesProvider),
              ),
            ],
            data: _content,
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }

  List<Widget> _content(List<BlockerView> all) {
    if (all.isEmpty) {
      return const [
        RfEmptyState(
          key: Key('blockers-empty'),
          message: 'No owner actions or blockers are recorded.',
        ),
      ];
    }
    final theme = Theme.of(context);
    final open = all.where((v) => v.isOpen).length;
    final awaiting = all.where((v) => v.isOpen && v.isOwnerAction).length;
    final resolved = all.length - open;
    final shown = all.where(_matches).toList();
    return [
      Text(
        'Status changes are stored with your other settings and travel with '
        'backups; restoring an older backup also restores the older '
        'statuses.',
        key: const Key('blockers-restore-note'),
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: RfSpace.s3),
      Text(
        '$open open · $awaiting awaiting you · $resolved resolved',
        key: const Key('blockers-summary'),
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: RfSpace.s3),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<_Scope>(
          key: const Key('blockers-scope'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _Scope.open, label: Text('Open')),
            ButtonSegment(value: _Scope.resolved, label: Text('Resolved')),
            ButtonSegment(value: _Scope.all, label: Text('All')),
          ],
          selected: {_scope},
          onSelectionChanged: (s) => _setScope(s.first),
        ),
      ),
      const SizedBox(height: RfSpace.s3),
      Wrap(
        spacing: RfSpace.s3,
        runSpacing: RfSpace.s3,
        children: [
          _FilterMenu<BlockerWorkPackage>(
            fieldKey: const Key('blockers-filter-wp'),
            label: 'Work package',
            value: _wp,
            options: BlockerWorkPackage.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _wp = v),
          ),
          _FilterMenu<BlockerPriority>(
            fieldKey: const Key('blockers-filter-priority'),
            label: 'Priority',
            value: _priority,
            options: BlockerPriority.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _priority = v),
          ),
          _FilterMenu<BlockerCategory>(
            fieldKey: const Key('blockers-filter-category'),
            label: 'Category',
            value: _category,
            options: BlockerCategory.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _category = v),
          ),
          _FilterMenu<BlockerStatus>(
            fieldKey: const Key('blockers-filter-status'),
            label: 'Status',
            value: _status,
            options: BlockerStatus.values,
            labelOf: (v) => v.label,
            onChanged: _setStatus,
          ),
        ],
      ),
      const SizedBox(height: RfSpace.s4),
      if (shown.isEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RfEmptyState(
              key: Key('blockers-empty-filtered'),
              message: 'Nothing matches these filters.',
              icon: Icons.filter_alt_off_outlined,
            ),
            const SizedBox(height: RfSpace.s2),
            RfButton(
              key: const Key('blockers-clear-filters'),
              label: 'Clear filters',
              variant: RfButtonVariant.tertiary,
              expand: false,
              onPressed: _clearFilters,
            ),
          ],
        )
      else
        for (final wp in BlockerWorkPackage.values)
          ..._group(wp, shown.where((v) => v.blocker.workPackage == wp)),
    ];
  }

  List<Widget> _group(BlockerWorkPackage wp, Iterable<BlockerView> rows) {
    if (rows.isEmpty) return const [];
    final theme = Theme.of(context);
    return [
      Padding(
        padding: const EdgeInsets.only(top: RfSpace.s2, bottom: RfSpace.s2),
        child: Row(
          key: Key('blockers-group-${wp.name}'),
          children: [
            Expanded(
              child: Text(
                '${wp.label} · ${wp.title}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: RfSpace.s2),
            Text(
              '${rows.length}',
              style: context.rfText.caption.copyWith(
                color: context.rf.textMuted,
              ),
            ),
          ],
        ),
      ),
      for (final v in rows) ...[
        _BlockerRow(view: v),
        const SizedBox(height: RfSpace.s3),
      ],
    ];
  }
}

class _BlockerRow extends StatelessWidget {
  const _BlockerRow({required this.view});

  final BlockerView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = view.blocker;
    return RfCard(
      key: Key('blocker-row-${b.id}'),
      onTap: () => context.push<void>(RfRoutes.settingsOwnerAction(b.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(b.id, style: context.rfText.meta),
          const SizedBox(height: RfSpace.s1),
          Text(b.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: RfSpace.s1),
          Text(
            '${b.category.label} · ${b.stage} · ${b.reference}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: RfSpace.s2),
          Wrap(
            spacing: RfSpace.s2,
            runSpacing: RfSpace.s2,
            children: [
              PriorityPill(b.priority),
              StatusPill(view.status),
              AssigneePill(b.assignee, key: Key('blocker-assignee-${b.id}')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact filter: a popup menu with an "All" entry, shown as a labelled
/// field.
class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final T? value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  PopupMenuItem<_Choice<T>> _item(
    BuildContext context,
    T? option,
    String text,
  ) {
    final selected = option == value;
    return PopupMenuItem(
      value: _Choice<T>(option),
      child: Row(
        children: [
          SizedBox(
            width: RfIcon.md,
            child: selected ? const Icon(Icons.check, size: RfIcon.sm) : null,
          ),
          const SizedBox(width: RfSpace.s2),
          Flexible(
            child: Text(
              text,
              style: selected
                  ? Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
      child: PopupMenuButton<_Choice<T>>(
        key: fieldKey,
        tooltip: label,
        onSelected: (c) => onChanged(c.value),
        itemBuilder: (_) => [
          _item(context, null, 'All'),
          for (final o in options) _item(context, o, labelOf(o)),
        ],
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value == null ? 'All' : labelOf(value as T),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps the "All" option so a null selection is still delivered.
final class _Choice<T> {
  const _Choice(this.value);
  final T? value;
}
