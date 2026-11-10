/// Why a file could not be opened, so the interface can say it plainly.
enum PresentationProblem {
  /// Not a presentation, or damaged beyond reading.
  notPresentation,

  /// A password-protected presentation.
  encrypted,

  /// The old binary PowerPoint format (`.ppt`, PowerPoint 97–2003).
  legacyPowerPoint,

  /// An OpenDocument presentation (`.odp`).
  openDocument,

  /// Any other kind of file.
  unsupportedFormat,

  /// Expands to more data than is safe to hold in memory.
  tooLarge,
}

class PresentationFileException extends FormatException {
  PresentationFileException(this.problem, [String? detail])
    : super(detail ?? problem.name);

  final PresentationProblem problem;

  @override
  String toString() => 'PresentationFileException(${problem.name}): $message';
}
