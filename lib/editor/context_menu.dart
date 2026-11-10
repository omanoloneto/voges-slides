import 'package:flutter/material.dart';

/// A command of a right-click menu. Without [onSelected] it is disabled.
class ContextMenuEntry {
  const ContextMenuEntry(this.icon, this.label, this.onSelected);

  final IconData icon;
  final String label;
  final VoidCallback? onSelected;
}

/// Opens a menu at [position], in global coordinates, and runs the command
/// chosen.
Future<void> showContextMenu(
  BuildContext context,
  Offset position,
  List<ContextMenuEntry> entries,
) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final action = await showMenu<VoidCallback>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final entry in entries)
        PopupMenuItem<VoidCallback>(
          value: entry.onSelected,
          enabled: entry.onSelected != null,
          height: 36,
          child: Row(
            children: [
              Icon(entry.icon, size: 18),
              const SizedBox(width: 12),
              Flexible(
                child: Text(entry.label, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
    ],
  );
  action?.call();
}
