import 'package:flutter/material.dart';

import 'ribbon_style.dart';

class RibbonIconButton extends StatelessWidget {
  const RibbonIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.child,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  /// Replaces the icon (e.g. an icon with a small color bar).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: Material(
          color: selected ? RibbonColors.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(6),
            hoverColor: RibbonColors.hover,
            child: SizedBox(
              width: 32,
              height: 30,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    color: enabled
                        ? RibbonColors.text
                        : RibbonColors.text.withValues(alpha: 0.35),
                    size: 19,
                  ),
                  child: child ?? Icon(icon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big button: icon on top, label below.
class RibbonBigButton extends StatelessWidget {
  const RibbonBigButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: selected ? RibbonColors.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        hoverColor: RibbonColors.hover,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: RibbonColors.text, size: 24),
                const SizedBox(height: 4),
                Text(label, style: RibbonText.control.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: tooltip == null
          ? button
          : Tooltip(message: tooltip!, child: button),
    );
  }
}

/// Ribbon group: content on top and label below.
class RibbonGroup extends StatelessWidget {
  const RibbonGroup({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 68, child: Center(child: child)),
          const SizedBox(height: 2),
          Text(label, style: RibbonText.label),
        ],
      ),
    );
  }
}

class RibbonGroupDivider extends StatelessWidget {
  const RibbonGroupDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 70, color: RibbonColors.divider);
}

class RibbonOption<T> {
  const RibbonOption(this.value, this.label, {this.style});

  final T value;
  final String label;
  final TextStyle? style;
}

/// Field with a drop-down list (font, size, spacing…).
class RibbonDropdown<T> extends StatelessWidget {
  const RibbonDropdown({
    required this.tooltip,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.width = 140,
    super.key,
  });

  final String tooltip;
  final String label;
  final List<RibbonOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: ribbonMenuStyle(),
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            style: ribbonMenuItemStyle(),
            onPressed: () => onSelected(option.value),
            leadingIcon: Icon(
              Icons.check,
              size: 16,
              color: option.value == selected
                  ? RibbonColors.text
                  : Colors.transparent,
            ),
            child: Text(
              option.label,
              style: RibbonText.control.merge(option.style),
            ),
          ),
      ],
      builder: (context, menu, _) => Tooltip(
        message: tooltip,
        child: RibbonField(
          width: width,
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: RibbonText.control,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: RibbonColors.text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RibbonField extends StatelessWidget {
  const RibbonField({required this.child, this.width, this.onTap, super.key});

  final Widget child;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RibbonColors.field,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: RibbonColors.hover,
        child: SizedBox(
          width: width,
          height: 30,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: child,
          ),
        ),
      ),
    );
  }
}

class RibbonMenuItem {
  const RibbonMenuItem(this.icon, this.label, this.onPressed);

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// A small ribbon button that opens a list of commands.
class RibbonMenuIconButton extends StatelessWidget {
  const RibbonMenuIconButton({
    required this.icon,
    required this.tooltip,
    required this.items,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final List<RibbonMenuItem> items;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: ribbonMenuStyle(),
    menuChildren: [
      for (final item in items)
        MenuItemButton(
          style: ribbonMenuItemStyle(),
          leadingIcon: Icon(item.icon, size: 18),
          onPressed: item.onPressed,
          child: Text(item.label),
        ),
    ],
    builder: (context, menu, _) => RibbonIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
    ),
  );
}
