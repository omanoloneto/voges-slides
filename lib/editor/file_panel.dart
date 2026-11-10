import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../l10n/l10n.dart';
import '../shell/app_logo.dart';
import '../shell/platform.dart';
import '../shell/ribbon_style.dart';

class FilePanelActions {
  const FilePanelActions({
    required this.newFile,
    required this.open,
    required this.save,
    required this.saveAs,
  });

  final VoidCallback newFile;
  final VoidCallback open;
  final VoidCallback save;
  final VoidCallback saveAs;
}

/// The "File" panel: file actions and the language.
Future<void> showFilePanel(
  BuildContext context, {
  required String name,
  required AppLanguage language,
  required FilePanelActions actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.close,
    barrierColor: const Color(0x22000000),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (context, _, _) => SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _FilePanel(name: name, language: language, actions: actions),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, -0.02),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
  );
}

class _FilePanel extends StatelessWidget {
  const _FilePanel({
    required this.name,
    required this.language,
    required this.actions,
  });

  final String name;
  final AppLanguage language;
  final FilePanelActions actions;

  void _run(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final width = math.min(520.0, MediaQuery.sizeOf(context).width - 24);
    return Material(
      color: RibbonColors.menu,
      elevation: 16,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  const AppLogo(size: 22, outlined: true),
                  const SizedBox(width: 10),
                  Text(l10n.fileMenu, style: RibbonText.activeTab),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: RibbonColors.field,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: RibbonText.control,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Wrap(
                children: [
                  _PanelAction(
                    Icons.note_add_outlined,
                    l10n.newFile,
                    shortcutLabel('N'),
                    () => _run(context, actions.newFile),
                  ),
                  _PanelAction(
                    Icons.folder_open_outlined,
                    l10n.openFile,
                    shortcutLabel('O'),
                    () => _run(context, actions.open),
                  ),
                  _PanelAction(
                    Icons.save_outlined,
                    l10n.save,
                    shortcutLabel('S'),
                    () => _run(context, actions.save),
                  ),
                  _PanelAction(
                    Icons.save_as_outlined,
                    l10n.saveAs,
                    shortcutLabel('S', shift: true),
                    () => _run(context, actions.saveAs),
                  ),
                ],
              ),
            ),
            const Divider(color: RibbonColors.divider, height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.translate,
                    size: 18,
                    color: RibbonColors.text,
                  ),
                  const SizedBox(width: 10),
                  Text(l10n.language, style: RibbonText.control),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: language,
                    builder: (context, _) => DropdownButton<Locale?>(
                      value: language.locale,
                      dropdownColor: RibbonColors.menu,
                      style: RibbonText.control,
                      iconEnabledColor: RibbonColors.text,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(child: Text(l10n.systemLanguage)),
                        for (final locale in appLanguages)
                          DropdownMenuItem(
                            value: locale,
                            child: Text(languageName(locale)),
                          ),
                      ],
                      onChanged: language.select,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  const _PanelAction(this.icon, this.label, this.shortcut, this.onTap);

  final IconData icon;
  final String label;
  final String shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: shortcut,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: RibbonColors.text,
          overlayColor: RibbonColors.hover,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: RibbonText.control),
      ),
    );
  }
}
