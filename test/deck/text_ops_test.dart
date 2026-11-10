import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/deck/text_body.dart';
import 'package:voges_slides/deck/text_ops.dart';

const _plain = RunStyle();
const _bold = RunStyle(bold: true);

TextBody _body(String text) => TextBody.plain(text, _plain);

void main() {
  group('locate', () {
    test('finds the paragraph and the offset in it', () {
      final body = _body('ab\ncd');
      expect(locate(body, 0), (paragraph: 0, offset: 0));
      expect(locate(body, 2), (paragraph: 0, offset: 2));
      expect(locate(body, 3), (paragraph: 1, offset: 0));
      expect(locate(body, 5), (paragraph: 1, offset: 2));
    });

    test('a position past the end is the end', () {
      expect(locate(_body('ab\ncd'), 99), (paragraph: 1, offset: 2));
    });
  });

  group('replaceText', () {
    test('typing in the middle keeps the rest', () {
      expect(replaceText(_body('hello'), 2, 2, 'XY').text, 'heXYllo');
    });

    test('a line break splits the paragraph and keeps its settings', () {
      final body = TextBody([
        Paragraph.plain('first', _plain, bullet: BulletKind.bullet, level: 2),
      ]);
      final split = replaceText(body, 2, 2, '\n');
      expect(split.text, 'fi\nrst');
      expect(split.paragraphs, hasLength(2));
      expect(split.paragraphs[1].bullet, BulletKind.bullet);
      expect(split.paragraphs[1].level, 2);
    });

    test('deleting across paragraphs joins them', () {
      final joined = replaceText(_body('one\ntwo\nthree'), 2, 9, '');
      expect(joined.text, 'onhree');
      expect(joined.paragraphs, hasLength(1));
    });

    test('emptying the text leaves one empty run with the style', () {
      final body = TextBody([Paragraph.plain('bold', _bold)]);
      final emptied = replaceText(body, 0, 4, '');
      expect(emptied.isEmpty, isTrue);
      expect(emptied.paragraphs.single.runs.single.style, _bold);
    });

    test('typed text takes the style before the caret', () {
      final body = TextBody([
        Paragraph(
          runs: [const TextRun('ab', _bold), const TextRun('cd', _plain)],
        ),
      ]);
      final typed = replaceText(body, 2, 2, 'X');
      expect(typed.paragraphs.single.runs.first.text, 'abX');
      expect(typed.paragraphs.single.runs.first.style, _bold);
    });

    test('text replacing a selection takes the style of its start', () {
      final body = TextBody([
        Paragraph(
          runs: [const TextRun('ab', _plain), const TextRun('cd', _bold)],
        ),
      ]);
      final typed = replaceText(body, 2, 4, 'X');
      expect(typed.text, 'abX');
      expect(typed.paragraphs.single.runs.last.style, _bold);
    });

    test('pasted lines become paragraphs', () {
      final pasted = replaceText(_body('ad'), 1, 1, 'b\nc');
      expect(pasted.text, 'ab\ncd');
      expect(pasted.paragraphs, hasLength(2));
    });
  });

  group('mapRuns', () {
    test('restyles only the range, splitting the run', () {
      final styled = mapRuns(
        _body('hello'),
        1,
        3,
        (style) => style.copyWith(bold: true),
      );
      final runs = styled.paragraphs.single.runs;
      expect([for (final run in runs) run.text], ['h', 'el', 'lo']);
      expect([for (final run in runs) run.style.bold], [false, true, false]);
    });

    test('an unchanged style returns the same text', () {
      final body = _body('hello');
      expect(identical(mapRuns(body, 0, 5, (style) => style), body), isTrue);
    });

    test('joins neighbours that end with the same style', () {
      final body = TextBody([
        Paragraph(
          runs: [const TextRun('ab', _bold), const TextRun('cd', _plain)],
        ),
      ]);
      final styled = mapRuns(body, 0, 4, (style) => style.copyWith(bold: true));
      expect(styled.paragraphs.single.runs, hasLength(1));
    });
  });

  group('everyRun', () {
    final body = TextBody([
      Paragraph(
        runs: [const TextRun('ab', _bold), const TextRun('cd', _plain)],
      ),
    ]);

    test('is true only when the whole range passes', () {
      expect(everyRun(body, 0, 2, (style) => style.bold), isTrue);
      expect(everyRun(body, 1, 3, (style) => style.bold), isFalse);
    });

    test('with a caret looks at the style typed next', () {
      expect(everyRun(body, 2, 2, (style) => style.bold), isTrue);
      expect(everyRun(body, 4, 4, (style) => style.bold), isFalse);
    });
  });

  test('mapParagraphs changes the paragraphs the range touches', () {
    final changed = mapParagraphs(
      _body('one\ntwo\nthree'),
      5,
      9,
      (paragraph) => paragraph.copyWith(align: ParagraphAlign.center),
    );
    expect(
      [for (final paragraph in changed.paragraphs) paragraph.align],
      [ParagraphAlign.left, ParagraphAlign.center, ParagraphAlign.center],
    );
  });

  test('plainText turns a line break inside a paragraph into a new line', () {
    final body = _body('a${softBreak}b\nc');
    expect(plainText(body, 0, body.length), 'a\nb\nc');
  });

  group('caret movement', () {
    test('a character is a whole grapheme', () {
      const text = 'a👨‍👩‍👧b';
      expect(nextCharacter(text, 1), text.length - 1);
      expect(previousCharacter(text, text.length - 1), 1);
    });

    test('previousWord and nextWord skip spaces first', () {
      const text = 'one  two, three';
      expect(nextWord(text, 0), 3);
      expect(nextWord(text, 3), 8);
      expect(nextWord(text, 8), 9);
      expect(previousWord(text, 15), 10);
      expect(previousWord(text, 10), 8);
      expect(previousWord(text, 5), 0);
    });

    test('wordAround selects the word, the spaces or the punctuation', () {
      const text = 'one  two!';
      expect(wordAround(text, 1), (start: 0, end: 3));
      expect(wordAround(text, 3), (start: 3, end: 5));
      expect(wordAround(text, 8), (start: 8, end: 9));
      expect(wordAround(text, 99), (start: 8, end: 9));
      expect(wordAround('', 0), (start: 0, end: 0));
    });

    test('wordAround does not cross paragraphs', () {
      expect(wordAround('ab\ncd', 4), (start: 3, end: 5));
      expect(wordAround('ab\ncd', 2), (start: 2, end: 2));
    });
  });
}
