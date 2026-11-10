import 'package:flutter/material.dart';

import '../shell/ribbon_controls.dart';
import '../shell/ribbon_style.dart';

const paletteColors = [
  0xFF000000, 0xFF434343, 0xFF666666, 0xFF999999, 0xFFCCCCCC, 0xFFFFFFFF, //
  0xFFC00000, 0xFFFF0000, 0xFFFFC000, 0xFFFFFF00, 0xFF92D050, 0xFF00B050, //
  0xFF00B0F0, 0xFF0070C0, 0xFF002060, 0xFF7030A0, 0xFFBF4222, 0xFF4472C4, //
  0xFFF4CCCC, 0xFFFCE5CD, 0xFFFFF2CC, 0xFFD9EAD3, 0xFFCFE2F3, 0xFFD9D2E9, //
];

/// A ribbon button that opens a palette. [extra] is a command listed above
/// the colors, such as "No fill".
class ColorMenuButton extends StatelessWidget {
  const ColorMenuButton({
    required this.icon,
    required this.tooltip,
    required this.current,
    required this.onPicked,
    this.enabled = true,
    this.extra,
    super.key,
  });

  final IconData icon;
  final String tooltip;

  /// ARGB shown under the icon; null shows none.
  final int? current;

  final ValueChanged<int> onPicked;
  final bool enabled;
  final RibbonMenuItem? extra;

  @override
  Widget build(BuildContext context) {
    final extra = this.extra;
    return MenuAnchor(
      style: ribbonMenuStyle(),
      menuChildren: [
        if (extra != null)
          MenuItemButton(
            style: ribbonMenuItemStyle(),
            leadingIcon: Icon(extra.icon, size: 18),
            onPressed: extra.onPressed,
            child: Text(extra.label),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 6 * 28 - 4,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final color in paletteColors)
                  _Swatch(
                    color: color,
                    selected: color == current,
                    onTap: () => onPicked(color),
                  ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, menu, _) => RibbonIconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: enabled
            ? () => menu.isOpen ? menu.close() : menu.open()
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17),
            Container(
              width: 18,
              height: 4,
              color: current == null ? Colors.transparent : Color(current!),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final int color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {
      onTap();
      MenuController.maybeOf(context)?.close();
    },
    child: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Color(color),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected ? RibbonColors.text : const Color(0x55FFFFFF),
          width: selected ? 2 : 1,
        ),
      ),
    ),
  );
}
