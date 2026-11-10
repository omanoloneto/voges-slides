import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../deck/element.dart';
import '../deck/text_body.dart';
import '../deck/text_ops.dart';

/// Points each indent level moves a paragraph to the right.
const levelIndent = 36.0;

const _lookAlikes = {
  'calibri': ['Carlito'],
  'cambria': ['Caladea'],
  'arial': ['Liberation Sans', 'Arimo', 'Helvetica'],
  'times new roman': ['Liberation Serif', 'Tinos', 'Times'],
  'courier new': ['Liberation Mono', 'Cousine', 'Courier'],
};

const _anyFont = ['Helvetica Neue', 'Arial', 'Liberation Sans', 'DejaVu Sans'];

final _fallbacks = <String, List<String>>{};

List<String> _fallbackOf(String font) =>
    _fallbacks[font] ??= [...?_lookAlikes[font.toLowerCase()], ..._anyFont];

/// Width of the column where the bullet or the number of a paragraph hangs.
double hangingIndent(Paragraph paragraph) {
  final size = paragraph.runs.first.style.size;
  return switch (paragraph.bullet) {
    BulletKind.none => 0,
    BulletKind.bullet => size * 0.9,
    BulletKind.number => size * 1.6,
  };
}

TextStyle textStyleOf(RunStyle style, {double lineSpacing = 1}) => TextStyle(
  fontFamily: style.font,
  fontFamilyFallback: _fallbackOf(style.font),
  fontSize: style.size,
  fontWeight: style.bold ? FontWeight.bold : FontWeight.normal,
  fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
  color: Color(style.color),
  decoration: TextDecoration.combine([
    if (style.underline) TextDecoration.underline,
    if (style.strike) TextDecoration.lineThrough,
  ]),
  height: lineSpacing == 1 ? null : 1.2 * lineSpacing,
);

/// One paragraph laid out at a width, in slide points.
class ParagraphLayout {
  ParagraphLayout._(this.painter, this.indent, this.label, this.labelLeft);

  factory ParagraphLayout._build(
    Paragraph paragraph,
    double width,
    int ordinal,
  ) {
    final spacing = paragraph.lineSpacing;
    final first = paragraph.runs.first.style;
    final labelLeft = paragraph.level * levelIndent;
    final indent = labelLeft + hangingIndent(paragraph);
    final available = math.max(1.0, width - indent);
    final painter = TextPainter(
      text: TextSpan(
        style: textStyleOf(first, lineSpacing: spacing),
        children: [
          for (final run in paragraph.runs)
            TextSpan(
              text: run.text.replaceAll(softBreak, '\n'),
              style: textStyleOf(run.style, lineSpacing: spacing),
            ),
        ],
      ),
      textAlign: switch (paragraph.align) {
        ParagraphAlign.left => TextAlign.left,
        ParagraphAlign.center => TextAlign.center,
        ParagraphAlign.right => TextAlign.right,
        ParagraphAlign.justify => TextAlign.justify,
      },
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(minWidth: available, maxWidth: available);
    TextPainter? label;
    if (paragraph.bullet != BulletKind.none) {
      final isBullet = paragraph.bullet == BulletKind.bullet;
      label = TextPainter(
        text: TextSpan(
          text: isBullet ? '•' : '$ordinal.',
          style: textStyleOf(
            RunStyle(
              font: isBullet ? defaultFont : first.font,
              size: first.size,
              color: first.color,
            ),
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
    }
    return ParagraphLayout._(painter, indent, label, labelLeft);
  }

  final TextPainter painter;

  /// Where the text starts, from the left of the text area.
  final double indent;

  final TextPainter? label;
  final double labelLeft;

  double get height => painter.height;

  void paint(Canvas canvas, Offset origin) {
    painter.paint(canvas, origin + Offset(indent, 0));
    final label = this.label;
    if (label == null) return;
    final drop =
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic) -
        label.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    label.paint(canvas, origin + Offset(labelLeft, drop));
  }
}

class _Cached {
  _Cached(this.width, this.ordinal, this.layout);

  final double width;
  final int ordinal;
  final ParagraphLayout layout;
}

final _paragraphs = Expando<List<_Cached>>();
final _bodies = Expando<BodyLayout>();

ParagraphLayout _layoutOf(Paragraph paragraph, double width, int ordinal) {
  final cached = _paragraphs[paragraph] ??= [];
  for (final entry in cached) {
    if (entry.width == width && entry.ordinal == ordinal) return entry.layout;
  }
  final layout = ParagraphLayout._build(paragraph, width, ordinal);
  if (cached.length == 3) cached.removeAt(0);
  cached.add(_Cached(width, ordinal, layout));
  return layout;
}

/// A whole text laid out at a width. Everything is in slide points, from
/// the top left corner of the text.
class BodyLayout {
  BodyLayout._(this.body, this.width) {
    final counters = List.filled(Paragraph.maxLevel + 2, 0);
    var y = 0.0, position = 0;
    for (var index = 0; index < body.paragraphs.length; index++) {
      final paragraph = body.paragraphs[index];
      final level = paragraph.level.clamp(0, Paragraph.maxLevel);
      counters.fillRange(level + 1, counters.length, 0);
      counters[level] = paragraph.bullet == BulletKind.number
          ? counters[level] + 1
          : 0;
      final layout = _layoutOf(paragraph, width, counters[level]);
      if (index > 0) y += paragraph.spaceBefore;
      paragraphs.add(layout);
      tops.add(y);
      starts.add(position);
      y += layout.height;
      if (index < body.paragraphs.length - 1) y += paragraph.spaceAfter;
      position += paragraph.length + 1;
    }
    height = y;
  }

  /// The layout of [body] at [width], kept while the text does not change.
  factory BodyLayout(TextBody body, double width) {
    final cached = _bodies[body];
    if (cached != null && cached.width == width) return cached;
    return _bodies[body] = BodyLayout._(body, width);
  }

  final TextBody body;
  final double width;
  final paragraphs = <ParagraphLayout>[];
  final tops = <double>[];
  final starts = <int>[];
  late final double height;

  void paint(Canvas canvas, Offset origin) {
    for (var index = 0; index < paragraphs.length; index++) {
      paragraphs[index].paint(canvas, origin + Offset(0, tops[index]));
    }
  }

  int _paragraphAtY(double y) {
    var index = 0;
    while (index < tops.length - 1 && tops[index + 1] <= y) {
      index++;
    }
    return index;
  }

  Offset _originOf(int index) => Offset(paragraphs[index].indent, tops[index]);

  /// The text position closest to a point.
  int positionAt(Offset point) {
    final index = _paragraphAtY(point.dy);
    final offset = paragraphs[index].painter
        .getPositionForOffset(point - _originOf(index))
        .offset;
    return starts[index] + math.min(offset, body.paragraphs[index].length);
  }

  Rect caretRect(int position) {
    final at = locate(body, position);
    final painter = paragraphs[at.paragraph].painter;
    final caret = TextPosition(offset: at.offset);
    final offset = painter.getOffsetForCaret(caret, Rect.zero);
    final height = painter.getFullHeightForCaret(caret, Rect.zero);
    return (offset + _originOf(at.paragraph)) &
        Size(0, height > 0 ? height : painter.preferredLineHeight);
  }

  /// Boxes covering the range, with a sliver for each paragraph break in it.
  List<Rect> selectionRects(int start, int end) {
    final rects = <Rect>[];
    for (var index = 0; index < paragraphs.length; index++) {
      final length = body.paragraphs[index].length;
      final from = starts[index], to = from + length;
      if (end < from || start > to) continue;
      final origin = _originOf(index);
      final a = math.max(start, from) - from, b = math.min(end, to) - from;
      final painter = paragraphs[index].painter;
      if (b > a) {
        for (final box in painter.getBoxesForSelection(
          TextSelection(baseOffset: a, extentOffset: b),
          boxHeightStyle: ui.BoxHeightStyle.max,
        )) {
          rects.add(box.toRect().shift(origin));
        }
      }
      if (end > to) {
        final caret = caretRect(to);
        rects.add(
          Rect.fromLTWH(
            caret.left,
            caret.top,
            body.paragraphs[index].runs.last.style.size * 0.3,
            caret.height,
          ),
        );
      }
    }
    return rects;
  }

  TextRange _lineOf(TextLocation at) => paragraphs[at.paragraph].painter
      .getLineBoundary(TextPosition(offset: at.offset));

  int lineStart(int position) {
    final at = locate(body, position);
    return starts[at.paragraph] + math.max(0, _lineOf(at).start);
  }

  /// The end of the line, before the space or break that wraps it.
  int lineEnd(int position) {
    final at = locate(body, position);
    final text = body.paragraphs[at.paragraph].text;
    var end = _lineOf(at).end.clamp(at.offset, text.length);
    if (end < text.length && end > at.offset) {
      final last = text.codeUnitAt(end - 1);
      if (last == 0x20 || last == 0x2028) end--;
    }
    return starts[at.paragraph] + end;
  }

  /// The position one line above (-1) or below (+1), keeping [x] when the
  /// caret is travelling a column.
  int verticalMove(int position, int direction, {double? x}) {
    final at = locate(body, position);
    final caret = caretRect(position);
    final line = _lineOf(at);
    final column = x ?? caret.left;
    if (direction < 0) {
      if (line.start > 0) return positionAt(Offset(column, caret.top - 1));
      if (at.paragraph == 0) return 0;
      final above = at.paragraph - 1;
      return positionAt(
        Offset(column, tops[above] + paragraphs[above].height - 1),
      );
    }
    if (line.end < body.paragraphs[at.paragraph].length) {
      return positionAt(Offset(column, caret.bottom + 1));
    }
    if (at.paragraph == paragraphs.length - 1) return body.length;
    return positionAt(Offset(column, tops[at.paragraph + 1] + 1));
  }
}

/// Width the text of [shape] wraps at.
double textWidthOf(ShapeElement shape) =>
    math.max(1.0, shape.frame.width - shape.insets.horizontal);

BodyLayout layoutOf(ShapeElement shape) =>
    BodyLayout(shape.text, textWidthOf(shape));

/// Top left corner of the text, from the top left corner of the frame.
Offset textOriginOf(ShapeElement shape, BodyLayout layout) {
  final free = shape.frame.height - shape.insets.vertical - layout.height;
  return Offset(
    shape.insets.left,
    shape.insets.top +
        switch (shape.anchor) {
          TextAnchor.top => 0,
          TextAnchor.middle => free / 2,
          TextAnchor.bottom => free,
        },
  );
}

/// The height a shape needs to show all of its text.
double fittedHeightOf(ShapeElement shape) =>
    layoutOf(shape).height + shape.insets.vertical;
