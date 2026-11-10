import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../deck/presentation.dart';
import 'pptx/pptx_import.dart';
import 'pptx/pptx_reader.dart';
import 'pptx/pptx_writer.dart';
import 'presentation_file_exception.dart';
import 'presentation_files.dart';

export 'pptx/pptx_import.dart' show ImportLoss, PptxImport;
export 'presentation_file_exception.dart'
    show PresentationFileException, PresentationProblem;

/// Reads an opened file away from the interface, which keeps answering
/// while a large presentation loads.
Future<PptxImport> decodePresentation(OpenedFile file) {
  final bytes = file.bytes;
  return Isolate.run(() => readPptx(bytes));
}

Future<Uint8List> encodePresentation(Presentation presentation) =>
    Isolate.run(() => writePptx(presentation));

/// Problems that mean "another kind of file", not a broken one.
bool isUnsupported(PresentationFileException error) => switch (error.problem) {
  PresentationProblem.legacyPowerPoint ||
  PresentationProblem.openDocument ||
  PresentationProblem.unsupportedFormat ||
  PresentationProblem.encrypted => true,
  _ => false,
};
