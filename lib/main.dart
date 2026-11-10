import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'deck/deck_controller.dart';
import 'files/presentation_files.dart';
import 'files/system_open.dart';
import 'l10n/app_language.dart';
import 'shell/platform.dart';
import 'shell/title_bar.dart';
import 'shell/window_buttons.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'Voges Slides',
        size: Size(1280, 860),
        minimumSize: Size(640, 480),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: true,
      ),
      () async {
        await placeNativeWindowButtons(titleBarHeight);
        await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  final language = AppLanguage();
  await language.load();
  final files = PresentationFiles();

  runApp(
    VogesSlidesApp(
      controller: DeckController(),
      files: files,
      systemOpen: SystemOpen(files),
      language: language,
      launchArguments: arguments,
      windowButtons: await WindowButtonsLayout.forPlatform(),
    ),
  );
}
