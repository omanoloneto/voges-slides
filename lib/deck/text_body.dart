import 'package:flutter/foundation.dart';

/// A line break inside a paragraph (Shift+Enter), as `<a:br/>` in a `.pptx`.
const softBreak = '\u2028';

/// The font of text that names none, present on every desktop or replaced
/// there by a look-alike.
const defaultFont = 'Arial';

enum ParagraphAlign { left, center, right, justify }

enum BulletKind { none, bullet, number }

/// How a stretch of text looks. Sizes are in points and colors are ARGB.
@immutable
class RunStyle {
  const RunStyle({
    this.font = defaultFont,
    this.size = 18,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.color = 0xFF000000,
  });

  final String font;
  final double size;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final int color;

  RunStyle copyWith({
    String? font,
    double? size,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    int? color,
  }) => RunStyle(
    font: font ?? this.font,
    size: size ?? this.size,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    strike: strike ?? this.strike,
    color: color ?? this.color,
  );

  @override
  bool operator ==(Object other) =>
      other is RunStyle &&
      other.font == font &&
      other.size == size &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike &&
      other.color == color;

  @override
  int get hashCode =>
      Object.hash(font, size, bold, italic, underline, strike, color);

  @override
  String toString() =>
      'RunStyle($font $size'
      '${bold ? ' bold' : ''}${italic ? ' italic' : ''}'
      '${underline ? ' underline' : ''}${strike ? ' strike' : ''}'
      ' #${color.toRadixString(16)})';
}

/// Text with one style. Never holds a paragraph break; [softBreak] is the
/// only line break it may carry.
@immutable
class TextRun {
  const TextRun(this.text, this.style);

  final String text;
  final RunStyle style;

  @override
  bool operator ==(Object other) =>
      other is TextRun && other.text == text && other.style == style;

  @override
  int get hashCode => Object.hash(text, style);

  @override
  String toString() => 'TextRun("$text", $style)';
}

/// One paragraph. It always has at least one run; an empty paragraph keeps
/// an empty run so the style of what is typed next is known.
@immutable
class Paragraph {
  const Paragraph({
    required this.runs,
    this.align = ParagraphAlign.left,
    this.bullet = BulletKind.none,
    this.level = 0,
    this.lineSpacing = 1,
    this.spaceBefore = 0,
    this.spaceAfter = 0,
  }) : assert(runs.length > 0);

  Paragraph.plain(
    String text,
    RunStyle style, {
    ParagraphAlign align = ParagraphAlign.left,
    BulletKind bullet = BulletKind.none,
    int level = 0,
  }) : this(
         runs: [TextRun(text, style)],
         align: align,
         bullet: bullet,
         level: level,
       );

  static const maxLevel = 8;

  final List<TextRun> runs;
  final ParagraphAlign align;
  final BulletKind bullet;

  /// Indent level, from 0 to [maxLevel].
  final int level;

  /// Multiple of the font's own line height.
  final double lineSpacing;

  /// Points above the paragraph; the first paragraph of a text ignores it.
  final double spaceBefore;

  /// Points below the paragraph.
  final double spaceAfter;

  String get text => runs.length == 1
      ? runs.first.text
      : [for (final run in runs) run.text].join();

  int get length {
    var length = 0;
    for (final run in runs) {
      length += run.text.length;
    }
    return length;
  }

  Paragraph copyWith({
    List<TextRun>? runs,
    ParagraphAlign? align,
    BulletKind? bullet,
    int? level,
    double? lineSpacing,
    double? spaceBefore,
    double? spaceAfter,
  }) => Paragraph(
    runs: runs ?? this.runs,
    align: align ?? this.align,
    bullet: bullet ?? this.bullet,
    level: level ?? this.level,
    lineSpacing: lineSpacing ?? this.lineSpacing,
    spaceBefore: spaceBefore ?? this.spaceBefore,
    spaceAfter: spaceAfter ?? this.spaceAfter,
  );

  @override
  String toString() => 'Paragraph("$text")';
}

/// The text of a shape. It always has at least one paragraph.
///
/// Positions in the text count UTF-16 units over [text], where paragraphs
/// are joined by `\n`.
@immutable
class TextBody {
  const TextBody(this.paragraphs) : assert(paragraphs.length > 0);

  TextBody.empty([RunStyle style = const RunStyle()])
    : this([Paragraph.plain('', style)]);

  /// One paragraph per line of [text].
  TextBody.plain(
    String text,
    RunStyle style, {
    ParagraphAlign align = ParagraphAlign.left,
  }) : this([
         for (final line in text.split('\n'))
           Paragraph.plain(line, style, align: align),
       ]);

  final List<Paragraph> paragraphs;

  String get text => paragraphs.length == 1
      ? paragraphs.first.text
      : [for (final paragraph in paragraphs) paragraph.text].join('\n');

  int get length {
    var length = paragraphs.length - 1;
    for (final paragraph in paragraphs) {
      length += paragraph.length;
    }
    return length;
  }

  bool get isEmpty => paragraphs.length == 1 && paragraphs.first.length == 0;

  @override
  String toString() => 'TextBody("$text")';
}
