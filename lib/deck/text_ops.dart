import 'dart:math' as math;

import 'package:flutter/services.dart' show CharacterBoundary;

import 'text_body.dart';

/// Where a position of the text falls: the paragraph and the offset in it.
typedef TextLocation = ({int paragraph, int offset});

TextLocation locate(TextBody body, int position) {
  var remaining = math.max(0, position);
  final last = body.paragraphs.length - 1;
  for (var index = 0; index < last; index++) {
    final length = body.paragraphs[index].length;
    if (remaining <= length) return (paragraph: index, offset: remaining);
    remaining -= length + 1;
  }
  return (
    paragraph: last,
    offset: math.min(remaining, body.paragraphs[last].length),
  );
}

/// Position of the first character of the paragraph at [index].
int paragraphStart(TextBody body, int index) {
  var start = 0;
  for (var i = 0; i < index; i++) {
    start += body.paragraphs[i].length + 1;
  }
  return start;
}

List<TextRun> _slice(Paragraph paragraph, int from, int to) {
  final runs = <TextRun>[];
  var position = 0;
  for (final run in paragraph.runs) {
    final end = position + run.text.length;
    final a = math.max(from, position), b = math.min(to, end);
    if (b > a) {
      runs.add(
        a == position && b == end
            ? run
            : TextRun(
                run.text.substring(a - position, b - position),
                run.style,
              ),
      );
    }
    position = end;
  }
  return runs;
}

List<TextRun> _normalize(List<TextRun> runs, RunStyle whenEmpty) {
  final result = <TextRun>[];
  for (final run in runs) {
    if (run.text.isEmpty) continue;
    if (result.isNotEmpty && result.last.style == run.style) {
      result.last = TextRun(result.last.text + run.text, run.style);
    } else {
      result.add(run);
    }
  }
  return result.isEmpty ? [TextRun('', whenEmpty)] : result;
}

/// The style of the character before [position], or of the first one at the
/// start of a paragraph.
RunStyle styleAt(TextBody body, int position) {
  final at = locate(body, position);
  final runs = body.paragraphs[at.paragraph].runs;
  var end = 0;
  for (final run in runs) {
    end += run.text.length;
    if (at.offset <= end) return run.style;
  }
  return runs.last.style;
}

/// The style text typed over the range takes: the one before the caret, or
/// the one of the first character selected.
RunStyle insertionStyle(TextBody body, int start, int end) {
  if (start >= end) return styleAt(body, start);
  final at = locate(body, start);
  return at.offset < body.paragraphs[at.paragraph].length
      ? styleAt(body, start + 1)
      : styleAt(body, start);
}

/// Replaces the range with [text], where each `\n` starts a paragraph that
/// keeps the settings of the one being split.
TextBody replaceText(
  TextBody body,
  int start,
  int end,
  String text, {
  RunStyle? style,
}) {
  final from = locate(body, start), to = locate(body, math.max(start, end));
  final inserted = style ?? insertionStyle(body, start, end);
  final first = body.paragraphs[from.paragraph];
  final last = body.paragraphs[to.paragraph];
  final head = _slice(first, 0, from.offset);
  final tail = _slice(last, to.offset, last.length);
  final lines = text.split('\n');
  return TextBody([
    ...body.paragraphs.take(from.paragraph),
    for (var i = 0; i < lines.length; i++)
      first.copyWith(
        runs: _normalize([
          if (i == 0) ...head,
          TextRun(lines[i], inserted),
          if (i == lines.length - 1) ...tail,
        ], inserted),
      ),
    ...body.paragraphs.skip(to.paragraph + 1),
  ]);
}

/// Restyles the characters of the range. An empty paragraph inside it has
/// the style of what will be typed there changed.
TextBody mapRuns(
  TextBody body,
  int start,
  int end,
  RunStyle Function(RunStyle style) change,
) {
  final paragraphs = <Paragraph>[];
  var changed = false;
  var paragraphStart = 0;
  for (final paragraph in body.paragraphs) {
    final length = paragraph.length;
    final paragraphEnd = paragraphStart + length;
    var result = paragraph;
    if (start <= paragraphEnd && end >= paragraphStart) {
      final a = math.max(start, paragraphStart) - paragraphStart;
      final b = math.min(end, paragraphEnd) - paragraphStart;
      final runs = length == 0
          ? [TextRun('', change(paragraph.runs.first.style))]
          : b > a
          ? _normalize([
              ..._slice(paragraph, 0, a),
              for (final run in _slice(paragraph, a, b))
                TextRun(run.text, change(run.style)),
              ..._slice(paragraph, b, length),
            ], paragraph.runs.first.style)
          : paragraph.runs;
      if (!_sameRuns(runs, paragraph.runs)) {
        result = paragraph.copyWith(runs: runs);
      }
    }
    changed = changed || !identical(result, paragraph);
    paragraphs.add(result);
    paragraphStart = paragraphEnd + 1;
  }
  return changed ? TextBody(paragraphs) : body;
}

bool _sameRuns(List<TextRun> a, List<TextRun> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// Changes every paragraph the range touches.
TextBody mapParagraphs(
  TextBody body,
  int start,
  int end,
  Paragraph Function(Paragraph paragraph) change,
) {
  final paragraphs = <Paragraph>[];
  var paragraphStart = 0;
  for (final paragraph in body.paragraphs) {
    final paragraphEnd = paragraphStart + paragraph.length;
    paragraphs.add(
      start <= paragraphEnd && end >= paragraphStart
          ? change(paragraph)
          : paragraph,
    );
    paragraphStart = paragraphEnd + 1;
  }
  return TextBody(paragraphs);
}

/// Whether every character of the range passes [test]; at a caret, whether
/// the style typed there does.
bool everyRun(
  TextBody body,
  int start,
  int end,
  bool Function(RunStyle style) test,
) {
  var tested = false;
  var paragraphStart = 0;
  for (final paragraph in body.paragraphs) {
    final length = paragraph.length;
    final paragraphEnd = paragraphStart + length;
    if (start < end && start <= paragraphEnd && end >= paragraphStart) {
      if (length == 0) {
        if (!test(paragraph.runs.first.style)) return false;
        tested = true;
      } else {
        final a = math.max(start, paragraphStart) - paragraphStart;
        final b = math.min(end, paragraphEnd) - paragraphStart;
        for (final run in _slice(paragraph, a, b)) {
          if (!test(run.style)) return false;
          tested = true;
        }
      }
    }
    paragraphStart = paragraphEnd + 1;
  }
  return tested || test(styleAt(body, start));
}

/// The first paragraph the range touches.
Paragraph paragraphAt(TextBody body, int position) =>
    body.paragraphs[locate(body, position).paragraph];

/// The text of the range as plain text, with one line per line shown.
String plainText(TextBody body, int start, int end) =>
    body.text.substring(start, end).replaceAll(softBreak, '\n');

int nextCharacter(String text, int position) => position >= text.length
    ? text.length
    : CharacterBoundary(text).getTrailingTextBoundaryAt(position) ??
          text.length;

int previousCharacter(String text, int position) => position <= 0
    ? 0
    : CharacterBoundary(text).getLeadingTextBoundaryAt(position - 1) ?? 0;

enum _CharacterClass { space, punctuation, word }

const _punctuation = r'''!"#$%&'()*+,-./:;<=>?@[\]^`{|}~¡¿«»“”‘’…–—''';

_CharacterClass _classAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  if (unit == 0x20 ||
      unit == 0x0A ||
      unit == 0x09 ||
      unit == 0xA0 ||
      unit == 0x2028) {
    return _CharacterClass.space;
  }
  return _punctuation.contains(text[index])
      ? _CharacterClass.punctuation
      : _CharacterClass.word;
}

/// Where Ctrl/Option+Left lands: the start of the word before [position].
int previousWord(String text, int position) {
  var index = math.min(position, text.length);
  while (index > 0 && _classAt(text, index - 1) == _CharacterClass.space) {
    index--;
  }
  if (index == 0) return 0;
  final kind = _classAt(text, index - 1);
  while (index > 0 && _classAt(text, index - 1) == kind) {
    index--;
  }
  return index;
}

/// Where Ctrl/Option+Right lands: the end of the word after [position].
int nextWord(String text, int position) {
  var index = math.max(0, position);
  while (index < text.length &&
      _classAt(text, index) == _CharacterClass.space) {
    index++;
  }
  if (index >= text.length) return text.length;
  final kind = _classAt(text, index);
  while (index < text.length && _classAt(text, index) == kind) {
    index++;
  }
  return index;
}

/// The word, the spaces or the punctuation around [position], as a double
/// click selects.
({int start, int end}) wordAround(String text, int position) {
  if (text.isEmpty) return (start: 0, end: 0);
  final index = position.clamp(0, text.length - 1);
  if (text.codeUnitAt(index) == 0x0A) return (start: index, end: index);
  final kind = _classAt(text, index);
  bool same(int i) => text.codeUnitAt(i) != 0x0A && _classAt(text, i) == kind;
  var start = index, end = index + 1;
  while (start > 0 && same(start - 1)) {
    start--;
  }
  while (end < text.length && same(end)) {
    end++;
  }
  return (start: start, end: end);
}
