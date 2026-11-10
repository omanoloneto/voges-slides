import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/deck/element.dart';
import 'package:voges_slides/deck/presentation.dart';
import 'package:voges_slides/deck/text_body.dart';
import 'package:voges_slides/files/pptx/pptx_import.dart';
import 'package:voges_slides/files/pptx/pptx_reader.dart';
import 'package:voges_slides/files/pptx/pptx_writer.dart';

import 'fixtures.dart';

const _plain = RunStyle();
const _heading = RunStyle(font: 'Georgia', size: 44, bold: true);
const _accent = RunStyle(
  font: 'Courier New',
  size: 13.5,
  italic: true,
  underline: true,
  strike: true,
  color: 0x80336699,
);

ShapeElement _text(
  String text, {
  required Rect frame,
  RunStyle style = _plain,
  PlaceholderKind? placeholder,
  TextAnchor anchor = TextAnchor.top,
}) => ShapeElement(
  id: 0,
  frame: frame,
  text: TextBody.plain(text, style),
  placeholder: placeholder,
  anchor: anchor,
);

Presentation _deck() {
  final shared = ImageData(pictureBytes, 'png');
  final other = ImageData(Uint8List.fromList([0xFF, 0xD8, 0xFF, 7]), 'jpeg');
  final vector = ImageData(Uint8List.fromList([1, 0, 0, 0, 9]), 'emf');
  return Presentation(
    size: const Size(720, 540),
    slides: [
      Slide(
        id: 0,
        background: 0xFF102030,
        elements: [
          _text(
            'Deck title',
            frame: const Rect.fromLTWH(90, 88.5, 540, 188),
            style: _heading,
            placeholder: PlaceholderKind.title,
            anchor: TextAnchor.bottom,
          ),
          _text(
            'By someone',
            frame: const Rect.fromLTWH(90, 283.5, 540, 130),
            style: const RunStyle(size: 24, color: 0xFF445566),
            placeholder: PlaceholderKind.subtitle,
          ),
        ],
      ),
      Slide(
        id: 0,
        elements: [
          _text(
            'Agenda',
            frame: const Rect.fromLTWH(50, 28.75, 620, 104),
            style: _heading,
            placeholder: PlaceholderKind.title,
            anchor: TextAnchor.middle,
          ),
          ShapeElement(
            id: 0,
            frame: const Rect.fromLTWH(50, 143.75, 620, 342.5),
            placeholder: PlaceholderKind.body,
            text: TextBody([
              Paragraph.plain(
                'First point',
                const RunStyle(size: 28),
                bullet: BulletKind.bullet,
              ),
              Paragraph.plain(
                'Detail',
                const RunStyle(size: 24),
                bullet: BulletKind.bullet,
                level: 1,
              ),
              Paragraph.plain(
                'Step',
                const RunStyle(size: 20),
                bullet: BulletKind.number,
                level: 2,
              ),
            ]),
          ),
        ],
      ),
      Slide(
        id: 0,
        background: 0xFFF0F0F0,
        elements: [
          _text(
            'Only a title',
            frame: const Rect.fromLTWH(50, 28.75, 620, 104),
            placeholder: PlaceholderKind.title,
          ),
          ShapeElement(
            id: 0,
            frame: const Rect.fromLTWH(40, 150, 300, 200),
            autoFit: true,
            anchor: TextAnchor.middle,
            insets: const TextInsets(left: 10, top: 5, right: 12, bottom: 0),
            text: TextBody([
              Paragraph(
                runs: const [
                  TextRun('Mixed ', _plain),
                  TextRun('styles & <tags> "quoted"', _accent),
                  TextRun(' line one${softBreak}line two', _heading),
                ],
                align: ParagraphAlign.center,
                lineSpacing: 1.15,
                spaceBefore: 6,
                spaceAfter: 12.5,
              ),
              Paragraph.plain('', _accent, align: ParagraphAlign.right),
              Paragraph(
                runs: const [TextRun('Justified', _plain)],
                align: ParagraphAlign.justify,
                bullet: BulletKind.number,
                level: 8,
                lineSpacing: 2,
              ),
            ]),
          ),
          ShapeElement(
            id: 0,
            frame: const Rect.fromLTWH(-20, 500.5, 80, 60),
            text: TextBody.empty(_accent),
            fill: 0xFFFFCC00,
          ),
        ],
      ),
      Slide(
        id: 0,
        elements: [
          for (final (index, kind) in ShapeKind.values.indexed)
            if (kind != ShapeKind.line)
              ShapeElement(
                id: 0,
                frame: Rect.fromLTWH(10.0 + index * 50, 20, 45, 30.5),
                rotation: index * 27.5,
                kind: kind,
                fill: index.isEven ? 0xFF4472C4 : null,
                stroke: index % 3 == 0 ? null : 0xCC112233,
                strokeWidth: 0.5 + index,
                flipH: index % 2 == 1,
                flipV: index % 4 == 2,
                anchor: TextAnchor.values[index % 3],
                text: TextBody.plain('Shape $index', _plain),
              ),
          ShapeElement(
            id: 0,
            frame: const Rect.fromLTWH(100, 300, 200, 80),
            kind: ShapeKind.line,
            stroke: 0xFFFF0000,
            strokeWidth: 2.25,
            flipV: true,
            startArrow: true,
            text: TextBody.empty(),
          ),
          ShapeElement(
            id: 0,
            frame: const Rect.fromLTWH(400, 300, 0, 120),
            kind: ShapeKind.line,
            stroke: 0xFF000000,
            flipH: true,
            endArrow: true,
            text: TextBody.empty(),
          ),
        ],
      ),
      Slide(
        id: 0,
        backgroundImage: other,
        elements: [
          ImageElement(
            id: 0,
            frame: const Rect.fromLTWH(10, 10, 320, 240),
            image: shared,
          ),
          ImageElement(
            id: 0,
            frame: const Rect.fromLTWH(350, 10, 160, 120),
            rotation: 315,
            image: shared,
            crop: const Rect.fromLTRB(0.1, 0.2, 0.3, 0.05),
          ),
          ImageElement(
            id: 0,
            frame: const Rect.fromLTWH(350, 200, 100, 100),
            image: vector,
          ),
        ],
      ),
      Slide(
        id: 0,
        backgroundImage: shared,
        elements: [
          ImageElement(
            id: 0,
            frame: const Rect.fromLTWH(0, 0, 50, 50),
            image: other,
          ),
        ],
      ),
    ],
  );
}

Future<Uint8List> _writeInBackground(Presentation deck) =>
    Isolate.run(() => writePptx(deck));

Future<PptxImport> _readInBackground(Uint8List bytes) =>
    Isolate.run(() => readPptx(bytes));

void main() {
  test('a deck comes back as it was saved', () {
    final deck = _deck();

    final result = readPptx(writePptx(deck));

    expectSamePresentation(result.presentation, deck);
  });

  test('only the picture the app cannot draw is reported as a loss', () {
    final deck = _deck();
    final drawable = Presentation(
      size: deck.size,
      slides: deck.slides.sublist(0, 4),
    );

    expect(readPptx(writePptx(drawable)).losses, isEmpty);
    expect(readPptx(writePptx(deck)).losses, {ImportLoss.images});
  });

  test('ids are unique among the slides and elements read back', () {
    final presentation = readPptx(writePptx(_deck())).presentation;

    final ids = [
      for (final slide in presentation.slides) ...[
        slide.id,
        for (final element in slide.elements) element.id,
      ],
    ];
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, everyElement(greaterThan(0)));
  });

  test('saving what was read gives the same file again', () {
    final first = writePptx(_deck());

    final second = writePptx(readPptx(first).presentation);

    expect(second, first);
  });

  test('reading and writing work in a background isolate', () async {
    final deck = _deck();

    final bytes = await _writeInBackground(deck);
    final result = await _readInBackground(bytes);

    expect(bytes, writePptx(deck));
    expectSamePresentation(result.presentation, deck);
    expect(result.losses, {ImportLoss.images});
  });

  test('a deck with one empty slide survives', () {
    final deck = Presentation(slides: const [Slide(id: 1)]);

    final result = readPptx(writePptx(deck));

    expectSamePresentation(result.presentation, deck);
    expect(result.losses, isEmpty);
  });
}
