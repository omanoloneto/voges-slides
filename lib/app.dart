import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:voges_updater/voges_updater.dart'
    show UpdateCheck, UpdaterLocalizations;

import 'deck/deck_controller.dart';
import 'editor/editor_screen.dart';
import 'files/presentation_files.dart';
import 'files/system_open.dart';
import 'l10n/app_language.dart';
import 'l10n/l10n.dart';
import 'shell/window_buttons.dart';

const brandColor = Color(0xFFBF4222);

class VogesSlidesApp extends StatelessWidget {
  const VogesSlidesApp({
    required this.controller,
    required this.files,
    required this.systemOpen,
    required this.language,
    required this.launchArguments,
    this.windowButtons = WindowButtonsLayout.right,
    this.updates,
    super.key,
  });

  final DeckController controller;
  final PresentationFiles files;
  final SystemOpen systemOpen;
  final AppLanguage language;
  final List<String> launchArguments;
  final WindowButtonsLayout windowButtons;
  final UpdateCheck? updates;

  ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: brightness,
    ),
    visualDensity: VisualDensity.standard,
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: language,
      builder: (context, _) => MaterialApp(
        title: 'Voges Slides',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        locale: language.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          UpdaterLocalizations.delegate,
        ],
        home: EditorScreen(
          controller: controller,
          files: files,
          systemOpen: systemOpen,
          language: language,
          launchArguments: launchArguments,
          windowButtons: windowButtons,
          updates: updates,
        ),
      ),
    );
  }
}
