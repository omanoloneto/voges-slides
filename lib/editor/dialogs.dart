import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

enum UnsavedChoice { save, discard, cancel }

Future<UnsavedChoice> askToSave(BuildContext context, String name) async {
  final choice = await showDialog<UnsavedChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.saveChangesTitle),
      content: Text(context.l10n.saveChangesMessage(name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, UnsavedChoice.cancel),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, UnsavedChoice.discard),
          child: Text(context.l10n.dontSave),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, UnsavedChoice.save),
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
  return choice ?? UnsavedChoice.cancel;
}
