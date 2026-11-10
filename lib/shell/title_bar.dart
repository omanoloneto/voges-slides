// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/l10n.dart';
import 'app_logo.dart';
import 'platform.dart';
import 'ribbon_controls.dart';
import 'ribbon_style.dart';
import 'window_buttons.dart';

const titleBarHeight = 46.0;

/// Room for the native macOS buttons, which Swift centers in the ribbon.
const _macButtonsWidth = 80.0;
const _quickButtonWidth = 32.0;
const _pillMinWidth = 240.0;

class QuickActions {
  const QuickActions({
    required this.undo,
    required this.redo,
    required this.copy,
    required this.cut,
    required this.paste,
  });

  /// Null when there is nothing to undo; the same for the others.
  final VoidCallback? undo;
  final VoidCallback? redo;
  final VoidCallback copy;
  final VoidCallback? cut;
  final VoidCallback paste;
}

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({
    required this.name,
    required this.dirty,
    required this.actions,
    required this.onFile,
    required this.isMaximized,
    this.isFullScreen = false,
    this.windowButtons = WindowButtonsLayout.right,
    super.key,
  });

  final String name;
  final bool dirty;
  final QuickActions actions;
  final VoidCallback onFile;
  final bool isMaximized;
  final bool isFullScreen;
  final WindowButtonsLayout windowButtons;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width > 720;
    final macOS =
        isDesktopPlatform && defaultTargetPlatform == TargetPlatform.macOS;
    final drawn = isDesktopPlatform && !macOS;
    final leading = drawn ? windowButtons.leading : const <WindowButton>[];
    final trailing = drawn ? windowButtons.trailing : const <WindowButton>[];

    // Shortcuts always sit on the side opposite the window buttons.
    final quickOnRight = macOS || leading.isNotEmpty;
    final quickWidth = (wide ? 5 : 2) * _quickButtonWidth + (wide ? 16 : 8);
    final leadingWidth = macOS
        ? (isFullScreen ? 0.0 : _macButtonsWidth)
        : WindowButtons.widthOf(leading);
    final left = leadingWidth + (quickOnRight ? 0 : quickWidth);
    final right =
        WindowButtons.widthOf(trailing) + (quickOnRight ? quickWidth : 0);
    final room = math.max(0.0, width - left - right - _pillMinWidth);
    final balance = math.min((left - right).abs(), room);

    final quick = Padding(
      padding: EdgeInsets.only(
        left: quickOnRight ? 0 : 8,
        right: quickOnRight ? 8 : 0,
      ),
      child: _QuickButtons(actions: actions, wide: wide),
    );

    return SizedBox(
      height: titleBarHeight,
      child: Stack(
        children: [
          if (isDesktopPlatform)
            const Positioned.fill(
              child: DragToMoveArea(child: SizedBox.expand()),
            ),
          Row(
            children: [
              if (macOS)
                SizedBox(width: leadingWidth)
              else
                WindowButtons(
                  buttons: leading,
                  isMaximized: isMaximized,
                  height: titleBarHeight,
                ),
              if (!quickOnRight) quick,
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: left < right ? balance : 0,
                    right: right < left ? balance : 0,
                  ),
                  child: Center(
                    child: _FilePill(name: name, dirty: dirty, onTap: onFile),
                  ),
                ),
              ),
              if (quickOnRight) quick,
              WindowButtons(
                buttons: trailing,
                isMaximized: isMaximized,
                height: titleBarHeight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickButtons extends StatelessWidget {
  const _QuickButtons({required this.actions, required this.wide});

  final QuickActions actions;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RibbonIconButton(
          icon: Icons.undo,
          tooltip: '${l10n.undo} (${shortcutLabel('Z')})',
          onPressed: actions.undo,
        ),
        RibbonIconButton(
          icon: Icons.redo,
          tooltip: '${l10n.redo} (${shortcutLabel('Y')})',
          onPressed: actions.redo,
        ),
        if (wide) ...[
          const SizedBox(width: 8),
          RibbonIconButton(
            icon: Icons.content_copy,
            tooltip: '${l10n.copy} (${shortcutLabel('C')})',
            onPressed: actions.copy,
          ),
          RibbonIconButton(
            icon: Icons.content_cut,
            tooltip: '${l10n.cut} (${shortcutLabel('X')})',
            onPressed: actions.cut,
          ),
          RibbonIconButton(
            icon: Icons.content_paste,
            tooltip: '${l10n.paste} (${shortcutLabel('V')})',
            onPressed: actions.paste,
          ),
        ],
      ],
    );
  }
}

class _FilePill extends StatelessWidget {
  const _FilePill({
    required this.name,
    required this.dirty,
    required this.onTap,
  });

  final String name;
  final bool dirty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Material(
      color: RibbonColors.field,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: RibbonColors.hover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 18, outlined: true),
              const SizedBox(width: 8),
              Text(context.l10n.fileMenu, style: RibbonText.activeTab),
              Container(
                width: 1,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: RibbonColors.divider,
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width < 520 ? 120 : 280,
                  ),
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: RibbonText.control,
                  ),
                ),
              ),
              if (dirty) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: context.l10n.unsavedChanges,
                  child: const Icon(
                    Icons.circle,
                    size: 8,
                    color: RibbonColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
