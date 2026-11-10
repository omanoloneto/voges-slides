import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'presentation_files.dart';

/// Files the system asked to open: double-click, "Open With", or the
/// command line.
class SystemOpen {
  SystemOpen(this._files);

  static const _channel = MethodChannel('voges_slides/open');

  final PresentationFiles _files;

  Future<List<OpenedFile>> pending(List<String> launchArguments) async {
    final files = <OpenedFile>[];
    for (final argument in launchArguments) {
      if (argument.startsWith('-')) continue;
      final file = await _read(argument);
      if (file != null) files.add(file);
    }
    if (kIsWeb) return files;
    try {
      final received = await _channel.invokeListMethod<Object?>('pending');
      for (final item in received ?? const []) {
        final file = await _fromPlatform(item);
        if (file != null) files.add(file);
      }
    } on MissingPluginException {
      return files;
    }
    return files;
  }

  void listen(ValueChanged<OpenedFile> onOpen) {
    if (kIsWeb) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'open') return;
      for (final item in call.arguments as List<Object?>) {
        final file = await _fromPlatform(item);
        if (file != null) onOpen(file);
      }
    });
  }

  Future<OpenedFile?> _fromPlatform(Object? item) async {
    if (item is! Map) return null;
    final path = item['path'];
    return path is String ? _read(path) : null;
  }

  Future<OpenedFile?> _read(String path) async {
    try {
      return await _files.read(path);
    } catch (_) {
      return null;
    }
  }
}
