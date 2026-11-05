import 'package:flutter/material.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/tokens.dart';

/// Edits a note (TRN-023). Returns the new text (possibly empty, which clears
/// the note) or null when cancelled. The length limit is the use case's.
Future<String?> showNoteDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required String keyPrefix,
}) => showDialog<String>(
  context: context,
  builder: (ctx) =>
      _NoteDialog(title: title, initial: initial, keyPrefix: keyPrefix),
);

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.initial,
    required this.keyPrefix,
  });

  final String title;
  final String initial;
  final String keyPrefix;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: RfTextField(
        key: Key('${widget.keyPrefix}-field'),
        controller: _controller,
        label: 'Note',
        maxLines: 6,
      ),
    ),
    actions: [
      TextButton(
        key: Key('${widget.keyPrefix}-cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        key: Key('${widget.keyPrefix}-save'),
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

/// Asks for a yes. [confirmKey] is the key of the confirming button.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String confirmKey,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          key: const Key('confirm-cancel'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: Key(confirmKey),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// New session details from [showEditSessionDialog].
typedef SessionDetailsInput = ({
  String name,
  DateTime startedAt,
  DateTime? endedAt,
});

/// Edits a session's name, start and length (TRN-024). The length is whole
/// minutes after the start; empty means still in progress. Returns null when
/// cancelled. Validation (name, end after start) is the use case's.
Future<SessionDetailsInput?> showEditSessionDialog(
  BuildContext context,
  WorkoutSession session,
) => showDialog<SessionDetailsInput>(
  context: context,
  builder: (ctx) => _EditSessionDialog(session: session),
);

class _EditSessionDialog extends StatefulWidget {
  const _EditSessionDialog({required this.session});

  final WorkoutSession session;

  @override
  State<_EditSessionDialog> createState() => _EditSessionDialogState();
}

String _minutesOf(WorkoutSession s) =>
    s.endedAt == null ? '' : '${s.endedAt!.difference(s.startedAt).inMinutes}';

class _EditSessionDialogState extends State<_EditSessionDialog> {
  late final _name = TextEditingController(text: widget.session.name);
  late final _minutes = TextEditingController(text: _minutesOf(widget.session));
  late DateTime _start = widget.session.startedAt.toLocal();

  @override
  void dispose() {
    _name.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(_start.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _start.hour,
        _start.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(
        _start.year,
        _start.month,
        _start.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit workout details'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RfTextField(
            key: const Key('details-name'),
            controller: _name,
            label: 'Name',
          ),
          const SizedBox(height: RfSpace.s3),
          Wrap(
            spacing: RfSpace.s2,
            children: [
              OutlinedButton(
                key: const Key('details-date'),
                onPressed: _pickDate,
                child: Text(
                  '${_start.year}-${_two(_start.month)}-${_two(_start.day)}',
                ),
              ),
              OutlinedButton(
                key: const Key('details-time'),
                onPressed: _pickTime,
                child: Text('${_two(_start.hour)}:${_two(_start.minute)}'),
              ),
            ],
          ),
          const SizedBox(height: RfSpace.s3),
          RfTextField.integer(
            key: const Key('details-minutes'),
            controller: _minutes,
            label: 'Length',
            unit: 'min',
            helper: 'Leave empty while the workout is in progress.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const Key('details-cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        key: const Key('details-save'),
        onPressed: () {
          final m = int.tryParse(_minutes.text.trim());
          Navigator.of(context).pop((
            name: _name.text,
            startedAt: _start.toUtc(),
            endedAt: m == null
                ? null
                : _start.add(Duration(minutes: m)).toUtc(),
          ));
        },
        child: const Text('Save'),
      ),
    ],
  );
}
