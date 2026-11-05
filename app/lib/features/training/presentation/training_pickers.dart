import 'package:flutter/material.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/tokens.dart';

/// Bottom sheet that picks one value (or none, via [anyLabel]). Each option's
/// key is `<keyPrefix>-<value.name>`; the clear option is `<keyPrefix>-any`.
/// Returns null when dismissed; a wrapped null when "any" is chosen.
Future<({T? value})?> showPickOneSheet<T extends Enum>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  required String keyPrefix,
  T? selected,
  String? anyLabel,
}) => showModalBottomSheet<({T? value})>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (ctx) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
          child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
        ),
        if (anyLabel != null)
          ListTile(
            key: Key('$keyPrefix-any'),
            title: Text(anyLabel),
            selected: selected == null,
            onTap: () => Navigator.of(ctx).pop((value: null)),
          ),
        for (final o in options)
          ListTile(
            key: Key('$keyPrefix-${o.name}'),
            title: Text(labelOf(o)),
            selected: o == selected,
            trailing: o == selected ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(ctx).pop((value: o)),
          ),
      ],
    ),
  ),
);

/// Bottom sheet that picks any number of values. Each option's key is
/// `<keyPrefix>-<value.name>`, the confirm button `<keyPrefix>-done`.
/// Returns null when dismissed.
Future<Set<T>?> showPickManySheet<T extends Enum>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  required String keyPrefix,
  required Set<T> selected,
  String? helper,
  String doneLabel = 'Done',
}) => showModalBottomSheet<Set<T>>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (ctx) {
    final chosen = {...selected};
    return StatefulBuilder(
      builder: (ctx, setState) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            if (helper != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: RfSpace.gutter,
                  vertical: RfSpace.s1,
                ),
                child: Text(helper, style: Theme.of(ctx).textTheme.bodySmall),
              ),
            for (final o in options)
              CheckboxListTile(
                key: Key('$keyPrefix-${o.name}'),
                title: Text(labelOf(o)),
                value: chosen.contains(o),
                onChanged: (v) => setState(() {
                  if (v ?? false) {
                    chosen.add(o);
                  } else {
                    chosen.remove(o);
                  }
                }),
              ),
            Padding(
              padding: const EdgeInsets.all(RfSpace.gutter),
              child: RfButton(
                key: Key('$keyPrefix-done'),
                label: doneLabel,
                onPressed: () => Navigator.of(ctx).pop({...chosen}),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
