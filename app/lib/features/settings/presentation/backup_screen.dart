import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/features/settings/application/backup_use_cases.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/file_feedback.dart';
import 'package:repforge/ui/tokens.dart';

/// Backup and restore (DAT-004, BCM-009(2); owner decision D3).
///
/// Export hands the full JSON backup to the share sheet. Restore lets the user
/// choose a file, validates it without changing anything, shows the backup
/// date and the record counts, and replaces all data only after an explicit
/// confirmation. Results stay on screen (a restore result must not vanish
/// with a snackbar). The text never says an export was "saved": the share
/// sheet only reports that a destination was chosen (ADR-0011).
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

enum _Busy { none, exporting, choosing, restoring }

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final GlobalKey _exportKey = GlobalKey();
  _Busy _busy = _Busy.none;
  String? _status;
  bool _statusIsError = false;

  void _setStatus(String text, {bool error = false}) => setState(() {
    _status = text;
    _statusIsError = error;
  });

  Future<void> _export() async {
    if (_busy != _Busy.none) return;
    setState(() {
      _busy = _Busy.exporting;
      _status = null;
    });
    final result = await ref.read(exportBackupProvider)(
      anchor: shareAnchorOf(_exportKey.currentContext),
    );
    if (!mounted) return;
    setState(() => _busy = _Busy.none);
    switch (result) {
      case Ok(:final value):
        _setStatus(exportOutcomeText(value));
      case Err(:final error):
        _setStatus(exportErrorText(error), error: true);
    }
  }

  Future<void> _restore() async {
    if (_busy != _Busy.none) return;
    setState(() {
      _busy = _Busy.choosing;
      _status = null;
    });
    final chosen = await ref.read(previewBackupProvider)();
    if (!mounted) return;
    setState(() => _busy = _Busy.none);
    switch (chosen) {
      case Err(:final error):
        _setStatus(
          '${_fileErrorText(error)} Nothing was changed.',
          error: true,
        );
      case Ok(value: null):
        _setStatus('No file was chosen. Nothing was changed.');
      case Ok(:final value?):
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => _ConfirmRestoreDialog(backup: value),
        );
        if (!mounted) return;
        if (confirmed != true) {
          _setStatus('Restore cancelled. Nothing was changed.');
          return;
        }
        await _applyRestore(value);
    }
  }

  Future<void> _applyRestore(PreviewedBackup backup) async {
    setState(() => _busy = _Busy.restoring);
    final result = await ref.read(restoreBackupProvider)(backup);
    if (!mounted) return;
    setState(() => _busy = _Busy.none);
    switch (result) {
      case Ok(:final value):
        final total = value.rowCounts.values.fold(0, (a, b) => a + b);
        _setStatus(
          'Restored $total ${total == 1 ? 'record' : 'records'} from the '
          'backup. Everything that was on this device before has been '
          'replaced.',
        );
      case Err(:final error):
        _setStatus(
          '${_fileErrorText(error)} Nothing was changed.',
          error: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _busy != _Busy.none;
    // Leaving while a restore runs would hide its result; wait for it.
    return PopScope(
      canPop: _busy != _Busy.restoring,
      child: Scaffold(
        appBar: AppBar(title: const Text('Backup and restore')),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
          children: [
            const RfScreenTitle(
              title: 'Backup and restore',
              caption: 'A copy of everything on this device',
            ),
            RfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export a backup', style: theme.textTheme.titleMedium),
                  const SizedBox(height: RfSpace.s1),
                  Text(
                    'Creates one file with all your data and opens the share '
                    'sheet, where you choose where to keep it (Files, Drive, '
                    'email). Keep it somewhere safe: it is not encrypted.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: RfSpace.s3),
                  KeyedSubtree(
                    key: _exportKey,
                    child: RfButton(
                      key: const Key('export-backup'),
                      label: 'Export backup',
                      icon: Icons.ios_share,
                      loading: _busy == _Busy.exporting,
                      onPressed: busy ? null : _export,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RfSpace.s3),
            RfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Restore a backup', style: theme.textTheme.titleMedium),
                  const SizedBox(height: RfSpace.s1),
                  Text(
                    'Choose a RepForge backup file. You will see what it '
                    'contains before anything changes. Restoring replaces '
                    'everything currently on this device.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: RfSpace.s3),
                  RfButton(
                    key: const Key('restore-backup'),
                    label: _busy == _Busy.restoring
                        ? 'Restoring'
                        : 'Choose backup file',
                    variant: RfButtonVariant.secondary,
                    icon: Icons.restore,
                    loading:
                        _busy == _Busy.choosing || _busy == _Busy.restoring,
                    onPressed: busy ? null : _restore,
                  ),
                ],
              ),
            ),
            if (_status != null) ...[
              const SizedBox(height: RfSpace.s3),
              RfCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _statusIsError ? Icons.error_outline : Icons.info_outline,
                      color: _statusIsError ? context.rf.alert : null,
                      size: RfIcon.md,
                    ),
                    const SizedBox(width: RfSpace.s3),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _status!,
                          key: const Key('backup-status'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: RfSpace.s8),
          ],
        ),
      ),
    );
  }
}

/// User text for a file that could not be chosen, read or understood.
String _fileErrorText(AppError error) => switch (error) {
  UnavailableError() => 'Choosing a file is not available on this device.',
  FileTooLargeError(:final maxBytes) =>
    'That file is too large to be a backup (the limit is '
        '${maxBytes ~/ (1024 * 1024)} MB).',
  StorageError() => 'The backup could not be restored.',
  UnexpectedError() => 'The file could not be opened.',
  _ => userMessageFor(error),
};

/// Readable table names for the restore preview.
const Map<String, String> _tableLabels = {
  'measurements': 'Measurements',
  'foods': 'Foods',
  'food_servings': 'Food servings',
  'food_log_entries': 'Food log entries',
  'saved_meals': 'Saved meals',
  'saved_meal_items': 'Saved meal items',
  'recipes': 'Recipes',
  'recipe_ingredients': 'Recipe ingredients',
  'recipe_substitutes': 'Recipe substitutes',
  'meal_plan_items': 'Meal plan items',
  'prep_batches': 'Prep batches',
  'exercises': 'Exercises',
  'workout_plans': 'Workout plans',
  'plan_exercises': 'Plan exercises',
  'workout_sessions': 'Workouts',
  'session_exercises': 'Workout exercises',
  'session_sets': 'Logged sets',
  'scheduled_workouts': 'Scheduled workouts',
  'training_splits': 'Training splits',
  'split_days': 'Split days',
  'legacy_quarantine': 'Legacy rows kept aside',
  'goals': 'Goals',
  'settings': 'Settings',
};

String _tableLabel(String name) =>
    _tableLabels[name] ?? name.replaceAll('_', ' ');

/// Shows what the chosen file contains and asks for confirmation. Nothing has
/// been changed when this is shown.
class _ConfirmRestoreDialog extends StatelessWidget {
  const _ConfirmRestoreDialog({required this.backup});

  final PreviewedBackup backup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = backup.preview;
    final made = preview.exportedAt;
    final counts = [
      for (final e in preview.rowCounts.entries)
        if (e.value > 0) e,
    ];
    final total = preview.totalRows;
    return AlertDialog(
      key: const Key('restore-dialog'),
      title: const Text('Replace all data?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (backup.fileName.isNotEmpty)
              Text(
                'File: ${backup.fileName}',
                style: theme.textTheme.bodySmall,
              ),
            Text(
              made == null
                  ? 'Backup date: not recorded in the file'
                  : 'Backup made: '
                        '${DateFormat.yMMMd().add_Hm().format(made.toLocal())}',
              key: const Key('restore-date'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: RfSpace.s2),
            Text(
              'Records in this backup ($total):',
              key: const Key('restore-total'),
              style: theme.textTheme.bodyMedium,
            ),
            for (final e in counts)
              Padding(
                padding: const EdgeInsets.only(top: RfSpace.s1),
                child: Row(
                  key: Key('restore-count-${e.key}'),
                  children: [
                    Expanded(
                      child: Text(
                        _tableLabel(e.key),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text('${e.value}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            const SizedBox(height: RfSpace.s3),
            Text(
              'Restoring replaces everything currently on this device '
              'with the contents of this file. This cannot be undone.',
              key: const Key('restore-warning'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('restore-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('restore-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Replace all data'),
        ),
      ],
    );
  }
}
