import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

const openableExtensions = ['pptx', 'ppsx', 'potx'];
const imageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'];

class OpenedFile {
  const OpenedFile({required this.name, required this.bytes, this.path});

  final String name;
  final Uint8List bytes;

  /// Where Save can write back; null when the file came as a copy.
  final String? path;

  /// Lowercase, without the dot; empty when the name has none.
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// Titles of the system file dialogs, in the user's language.
class FileDialogTitles {
  const FileDialogTitles({
    this.open = 'Open',
    this.save = 'Save',
    this.image = 'Insert picture',
  });

  final String open;
  final String save;
  final String image;
}

/// Opens and saves files with the system dialogs.
class PresentationFiles {
  FileDialogTitles titles = const FileDialogTitles();

  Future<OpenedFile?> pick() => _pick(titles.open, openableExtensions);

  Future<OpenedFile?> pickImage() => _pick(titles.image, imageExtensions);

  Future<OpenedFile?> _pick(String title, List<String> extensions) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: title,
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    final path = result?.files.single.path;
    return path == null ? null : read(path);
  }

  Future<OpenedFile> read(String path) async => OpenedFile(
    name: path.split(Platform.pathSeparator).last,
    bytes: await File(path).readAsBytes(),
    path: path,
  );

  /// The path the user chose, ending in `.pptx`; null if canceled.
  Future<String?> chooseSaveLocation(String name) async {
    final path = await FilePicker.saveFile(
      dialogTitle: titles.save,
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const ['pptx'],
    );
    if (path == null) return null;
    return path.toLowerCase().endsWith('.pptx') ? path : '$path.pptx';
  }

  Future<void> write(String path, Uint8List bytes) =>
      File(path).writeAsBytes(bytes, flush: true);
}
