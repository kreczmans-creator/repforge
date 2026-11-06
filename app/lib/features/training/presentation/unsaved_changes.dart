import 'package:flutter/material.dart';

/// Asks whether to throw away unsaved edits. True when the user chooses to
/// discard; false when they keep editing or dismiss the dialog.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text('You have unsaved changes. They will be lost.'),
      actions: [
        TextButton(
          key: const Key('keep-editing'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep editing'),
        ),
        TextButton(
          key: const Key('discard-changes'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return discard ?? false;
}

/// Blocks leaving [child] while [dirty] and asks first (back button, system
/// back and swipe all go through it). A direct `Navigator.pop` after a
/// successful save is not intercepted.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    required this.dirty,
    required this.child,
    super.key,
  });

  final bool dirty;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      final navigator = Navigator.of(context);
      if (await confirmDiscardChanges(context)) navigator.pop();
    },
    child: child,
  );
}
