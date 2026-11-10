import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

bool get isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

bool get isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Command on Apple platforms, Ctrl elsewhere.
SingleActivator shortcut(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(
      key,
      control: !isApplePlatform,
      meta: isApplePlatform,
      shift: shift,
    );

/// How a shortcut is written in tooltips: "⌘Z" or "Ctrl+Z".
String shortcutLabel(String key, {bool shift = false}) => isApplePlatform
    ? '${shift ? '⇧' : ''}⌘$key'
    : 'Ctrl+${shift ? 'Shift+' : ''}$key';
