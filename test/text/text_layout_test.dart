import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/deck/element.dart';
import 'package:voges_slides/deck/text_body.dart';
import 'package:voges_slides/text/text_layout.dart';

// the font of the tests draws every character as a square of the font size
const style = RunStyle(size: 10);

TextBody lines(List<String> texts) =>
    TextBody([for (final text in texts) Paragraph.plain(text, style)]);

String? labelOf(BodyLayout layout, int index) =>
    layout.paragraphs[index].label?.text?.toPlainText();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('layout', () {
    test('text wraps at the width', () {
      final layout = BodyLayout(lines(['aaaa bbbb']), 50);
      expect(layout.height, 20);
      expect(BodyLayout(lines(['aaaa bbbb']), 200).height, 10);
    });

    test('a soft break starts a line in the same paragraph', () {
      final layout = BodyLayout(lines(['ab${softBreak}cd']), 200);
      expect(layout.paragraphs, hasLength(1));
      expect(layout.height, 20);
    });

    test('paragraphs stack with the space between them', () {
      final layout = BodyLayout(
        TextBody([
          Paragraph.plain('one', style).copyWith(spaceBefore: 7, spaceAfter: 3),
          Paragraph.plain('two', style).copyWith(spaceBefore: 5, spaceAfter: 9),
        ]),
        200,
      );
      // the space before the first and after the last paragraph is ignored
      expect(layout.tops, [0, 18]);
      expect(layout.starts, [0, 4]);
      expect(layout.height, 28);
    });

    test('line spacing stretches the lines', () {
      final single = BodyLayout(lines(['a']), 200);
      final double = BodyLayout(
        TextBody([Paragraph.plain('a', style).copyWith(lineSpacing: 2)]),
        200,
      );
      expect(double.height, greaterThan(single.height * 1.9));
    });

    test('the same text at the same width is laid out once', () {
      final body = lines(['one', 'two']);
      expect(identical(BodyLayout(body, 120), BodyLayout(body, 120)), isTrue);
      expect(identical(BodyLayout(body, 120), BodyLayout(body, 90)), isFalse);
    });
  });

  group('bullets and numbers', () {
    test('the text hangs after the level and the bullet', () {
      final layout = BodyLayout(
        TextBody([
          Paragraph.plain('plain', style),
          Paragraph.plain('dot', style, bullet: BulletKind.bullet),
          Paragraph.plain('deep', style, bullet: BulletKind.bullet, level: 2),
        ]),
        300,
      );
      expect(layout.paragraphs[0].indent, 0);
      expect(layout.paragraphs[0].label, isNull);
      expect(layout.paragraphs[1].indent, 9);
      expect(layout.paragraphs[2].labelLeft, 2 * levelIndent);
      expect(layout.paragraphs[2].indent, 2 * levelIndent + 9);
      expect(labelOf(layout, 1), '•');
    });

    test('numbers count per level and start over after a break', () {
      Paragraph numbered(String text, [int level = 0]) =>
          Paragraph.plain(text, style, bullet: BulletKind.number, level: level);
      final layout = BodyLayout(
        TextBody([
          numbered('a'),
          numbered('b'),
          numbered('inner', 1),
          numbered('inner', 1),
          numbered('c'),
          Paragraph.plain('break', style),
          numbered('again'),
        ]),
        300,
      );
      expect(
        [for (var index = 0; index < 7; index++) labelOf(layout, index)],
        ['1.', '2.', '1.', '2.', '3.', null, '1.'],
      );
    });

    test('a bullet narrows the width the text wraps at', () {
      final plain = BodyLayout(lines(['aaaa bbbb']), 95);
      final bulleted = BodyLayout(
        TextBody([
          Paragraph.plain('aaaa bbbb', style, bullet: BulletKind.bullet),
        ]),
        95,
      );
      expect(plain.height, 10);
      expect(bulleted.height, 20);
    });
  });

  group('positions', () {
    test('a point finds the position in its paragraph', () {
      final layout = BodyLayout(lines(['abcd', 'efgh']), 200);
      expect(layout.positionAt(const Offset(21, 5)), 2);
      expect(layout.positionAt(const Offset(21, 15)), 7);
      expect(layout.positionAt(const Offset(500, 15)), 9);
      expect(layout.positionAt(const Offset(-5, -5)), 0);
    });

    test('the caret sits after the characters before it', () {
      final layout = BodyLayout(lines(['abcd', 'efgh']), 200);
      final caret = layout.caretRect(7);
      expect(caret.left, 20);
      expect(caret.top, 10);
      expect(caret.height, 10);
    });

    test('the caret of an empty bulleted paragraph hangs with its text', () {
      final layout = BodyLayout(
        TextBody([Paragraph.plain('', style, bullet: BulletKind.bullet)]),
        200,
      );
      final caret = layout.caretRect(0);
      expect(caret.left, 9);
      expect(caret.height, 10);
    });

    test('a selection over a paragraph break shows a sliver for it', () {
      final layout = BodyLayout(lines(['abcd', 'efgh']), 200);
      final rects = layout.selectionRects(2, 6);
      expect(rects, hasLength(3));
      expect(rects[0], const Rect.fromLTRB(20, 0, 40, 10));
      expect(rects[1].left, 40);
      expect(rects[1].width, 3);
      expect(rects[2], const Rect.fromLTRB(0, 10, 10, 20));
      expect(layout.selectionRects(1, 3), hasLength(1));
    });
  });

  group('lines', () {
    // wraps as "aaaa " and "bbbb"
    final wrapped = lines(['aaaa bbbb', 'cc']);

    test('line start and end follow the wrapping', () {
      final layout = BodyLayout(wrapped, 50);
      expect(layout.lineStart(2), 0);
      expect(layout.lineEnd(2), 4);
      expect(layout.lineStart(7), 5);
      expect(layout.lineEnd(7), 9);
      expect(layout.lineStart(11), 10);
      expect(layout.lineEnd(11), 12);
    });

    test('moving down and up keeps the column', () {
      final layout = BodyLayout(wrapped, 50);
      expect(layout.verticalMove(1, 1), 6);
      expect(layout.verticalMove(6, 1), 11);
      expect(layout.verticalMove(11, -1), 6);
      expect(layout.verticalMove(6, -1), 1);
    });

    test('the first line goes to the start and the last to the end', () {
      final layout = BodyLayout(wrapped, 50);
      expect(layout.verticalMove(3, -1), 0);
      expect(layout.verticalMove(10, 1), 12);
    });

    test('a remembered column survives a short line', () {
      final layout = BodyLayout(lines(['abcdef', 'x', 'abcdef']), 200);
      expect(layout.verticalMove(5, 1), 8);
      expect(layout.verticalMove(8, 1, x: 50), 14);
    });
  });

  group('shapes', () {
    ShapeElement shape(TextAnchor anchor) => ShapeElement(
      id: 1,
      frame: const Rect.fromLTWH(0, 0, 120, 100),
      anchor: anchor,
      insets: const TextInsets(left: 10, top: 4, right: 10, bottom: 6),
      text: lines(['abcd']),
    );

    test('the text wraps inside the insets', () {
      expect(textWidthOf(shape(TextAnchor.top)), 100);
    });

    test('the anchor places the text in the height of the shape', () {
      Offset origin(TextAnchor anchor) {
        final element = shape(anchor);
        return textOriginOf(element, layoutOf(element));
      }

      expect(origin(TextAnchor.top), const Offset(10, 4));
      expect(origin(TextAnchor.middle), const Offset(10, 44));
      expect(origin(TextAnchor.bottom), const Offset(10, 84));
    });

    test('the fitted height is the text plus the insets', () {
      expect(fittedHeightOf(shape(TextAnchor.top)), 20);
    });
  });
}
