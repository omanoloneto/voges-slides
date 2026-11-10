import '../../deck/presentation.dart';

/// What an opened file had that the app cannot keep.
enum ImportLoss {
  /// Tables, charts, diagrams, videos, sounds and embedded objects, left out.
  content,

  /// Shapes drawn as a plain rectangle and effects that were dropped.
  shapes,

  /// Pictures in a format the app cannot draw.
  images,

  /// Speaker notes, left out.
  notes,

  /// Animations and slide transitions, left out.
  animations,
}

class PptxImport {
  const PptxImport(this.presentation, this.losses);

  final Presentation presentation;

  /// Empty when everything in the file was understood.
  final Set<ImportLoss> losses;
}
