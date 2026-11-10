import 'dart:ui';

import 'package:flutter/services.dart' show TextSelection;
import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/deck/deck_controller.dart';
import 'package:voges_slides/deck/element.dart';
import 'package:voges_slides/deck/layouts.dart';
import 'package:voges_slides/deck/presentation.dart';
import 'package:voges_slides/deck/text_body.dart';

ShapeElement _titleOf(DeckController deck) => deck.slide.elements
    .whereType<ShapeElement>()
    .firstWhere((shape) => shape.placeholder == PlaceholderKind.title);

Set<int> _idsOf(Presentation presentation) => {
  for (final slide in presentation.slides) ...[
    slide.id,
    for (final element in slide.elements) element.id,
  ],
};

int _idCount(Presentation presentation) => presentation.slides.fold(
  0,
  (count, slide) => count + 1 + slide.elements.length,
);

void _type(DeckController deck, String text) {
  for (final character in text.split('')) {
    deck.insertText(character);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeckController deck;
  setUp(() => deck = DeckController());

  test('starts with a title slide and nothing to save', () {
    expect(deck.slides, hasLength(1));
    expect(_titleOf(deck).text.isEmpty, isTrue);
    expect(deck.dirty, isFalse);
    expect(deck.canUndo, isFalse);
  });

  group('slides', () {
    test('a new slide goes after the current one and is undone', () {
      deck.addSlide();
      expect(deck.slides, hasLength(2));
      expect(deck.slideIndex, 1);
      expect(deck.dirty, isTrue);

      deck.undo();
      expect(deck.slides, hasLength(1));
      expect(deck.slideIndex, 0);
      expect(deck.dirty, isFalse);

      deck.redo();
      expect(deck.slides, hasLength(2));
      expect(deck.slideIndex, 1);
    });

    test('a new slide takes the background of the current one', () {
      deck.setBackground(0xFF102030);
      deck.addSlide(SlideLayout.blank);
      expect(deck.slide.background, 0xFF102030);
      expect(deck.slide.elements, isEmpty);
    });

    test('a duplicate shares no id with the original', () {
      deck.duplicateSlide();
      expect(deck.slides, hasLength(2));
      expect(_idsOf(deck.presentation), hasLength(_idCount(deck.presentation)));
    });

    test('the last slide is never deleted', () {
      expect(deck.canDeleteSlide, isFalse);
      deck.deleteSlide();
      expect(deck.slides, hasLength(1));

      deck.addSlide();
      deck.deleteSlide();
      expect(deck.slides, hasLength(1));
      expect(deck.slideIndex, 0);
    });

    test('moving a slide keeps it selected', () {
      deck.addSlide();
      deck.addSlide();
      final moved = deck.slide.id;
      deck.moveSlide(2, 0);
      expect(deck.slideIndex, 0);
      expect(deck.slide.id, moved);
    });

    test('a pasted slide is a copy with its own ids', () {
      deck.copySlide();
      deck.pasteSlide();
      expect(deck.slides, hasLength(2));
      expect(_idsOf(deck.presentation), hasLength(_idCount(deck.presentation)));
    });

    test('ids of a loaded presentation are not reused', () {
      deck.load(Presentation(slides: const [Slide(id: 40)]));
      deck.addShape(ShapeKind.ellipse);
      expect(deck.slide.elements.single.id, greaterThan(40));
    });
  });

  group('elements', () {
    test('a new shape is selected, deleted and brought back', () {
      deck.addShape(ShapeKind.ellipse);
      final shape = deck.single!;
      expect(deck.slide.elements.last, same(shape));

      deck.deleteSelection();
      expect(deck.slide.element(shape.id), isNull);
      expect(deck.selection, isEmpty);

      deck.undo();
      expect(deck.slide.element(shape.id), isNotNull);
    });

    test('nudges in a row are one step back', () {
      deck.addShape(ShapeKind.rectangle);
      final start = deck.single!.frame;
      deck.nudge(const Offset(1, 0));
      deck.nudge(const Offset(1, 0));
      deck.nudge(const Offset(0, 5));
      expect(deck.single!.frame, start.shift(const Offset(2, 5)));

      deck.undo();
      expect(deck.single!.frame, start);
    });

    test('a drag is one step back', () {
      deck.addShape(ShapeKind.rectangle);
      final shape = deck.single!;
      deck.beginGesture();
      deck.replaceElements([
        shape.withGeometry(frame: shape.frame.shift(const Offset(10, 0))),
      ]);
      deck.replaceElements([
        shape.withGeometry(frame: shape.frame.shift(const Offset(30, 0))),
      ]);
      deck.endGesture();
      expect(deck.single!.frame, shape.frame.shift(const Offset(30, 0)));

      deck.undo();
      expect(deck.single!.frame, shape.frame);
    });

    test('a drag that moved nothing leaves no step', () {
      deck.addShape(ShapeKind.rectangle);
      deck.undo();
      deck.beginGesture();
      deck.endGesture();
      expect(deck.canUndo, isFalse);
    });

    test('each paste lands a little further', () {
      deck.addShape(ShapeKind.rectangle);
      final shape = deck.single!;
      deck.copyElements();
      deck.pasteElements();
      final first = deck.single!;
      deck.pasteElements();
      final second = deck.single!;

      expect({shape.id, first.id, second.id}, hasLength(3));
      expect(first.frame, shape.frame.shift(const Offset(12, 12)));
      expect(second.frame, shape.frame.shift(const Offset(24, 24)));
    });

    test('copying returns the text of the shapes', () {
      deck.startEditing(_titleOf(deck).id);
      _type(deck, 'Hello');
      deck.select({_titleOf(deck).id});
      expect(deck.copyElements(), 'Hello');
    });

    test('sending back stops above the locked elements', () {
      deck.load(
        Presentation(
          slides: [
            Slide(
              id: 1,
              elements: [
                ShapeElement(
                  id: 2,
                  frame: const Rect.fromLTWH(0, 0, 10, 10),
                  locked: true,
                  text: TextBody.empty(),
                ),
                ShapeElement(
                  id: 3,
                  frame: const Rect.fromLTWH(0, 0, 10, 10),
                  text: TextBody.empty(),
                ),
                ShapeElement(
                  id: 4,
                  frame: const Rect.fromLTWH(0, 0, 10, 10),
                  text: TextBody.empty(),
                ),
              ],
            ),
          ],
        ),
      );
      deck.select({4});
      deck.arrange(Arrange.back);
      expect(
        [for (final element in deck.slide.elements) element.id],
        [2, 4, 3],
      );

      deck.arrange(Arrange.backward);
      expect(
        [for (final element in deck.slide.elements) element.id],
        [2, 4, 3],
      );
    });

    test('locked elements are not selected until unlocked', () {
      deck.load(
        Presentation(
          slides: [
            Slide(
              id: 1,
              elements: [
                ShapeElement(
                  id: 2,
                  frame: const Rect.fromLTWH(0, 0, 10, 10),
                  locked: true,
                  text: TextBody.empty(),
                ),
              ],
            ),
          ],
        ),
      );
      deck.selectAll();
      expect(deck.selection, isEmpty);

      deck.unlockBackground();
      deck.selectAll();
      expect(deck.selection, {2});
    });

    test('a line takes no fill', () {
      deck.addShape(ShapeKind.line, arrow: true);
      deck.setFill(0xFFFF0000);
      final line = deck.single! as ShapeElement;
      expect(line.fill, isNull);
      expect(line.endArrow, isTrue);
    });
  });

  group('text', () {
    test('typing is undone a word at a time', () {
      final id = _titleOf(deck).id;
      deck.startEditing(id);
      _type(deck, 'hi yo');
      expect(_titleOf(deck).text.text, 'hi yo');

      deck.undo();
      expect(_titleOf(deck).text.text, 'hi ');
      deck.undo();
      expect(_titleOf(deck).text.text, '');
      expect(deck.canUndo, isFalse);
    });

    test('the caret follows what is typed', () {
      deck.startEditing(_titleOf(deck).id);
      _type(deck, 'abc');
      expect(deck.textSelection, const TextSelection.collapsed(offset: 3));

      deck.setTextSelection(
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
      expect(deck.selectedText, 'ab');
      deck.insertText('X');
      expect(_titleOf(deck).text.text, 'Xc');
      expect(deck.textSelection, const TextSelection.collapsed(offset: 1));
    });

    test('a format with only a caret applies to what is typed next', () {
      deck.startEditing(_titleOf(deck).id);
      deck.insertText('a');
      deck.formatText((style) => style.copyWith(bold: true));
      expect(deck.currentStyle!.bold, isTrue);
      expect(deck.everyStyle((style) => style.bold), isTrue);

      deck.insertText('b');
      final runs = _titleOf(deck).text.paragraphs.single.runs;
      expect([for (final run in runs) run.text], ['a', 'b']);
      expect([for (final run in runs) run.style.bold], [false, true]);
    });

    test('a format outside editing changes all the text of the shape', () {
      final id = _titleOf(deck).id;
      deck.startEditing(id);
      _type(deck, 'Title');
      deck.select({id});
      deck.formatText((style) => style.copyWith(italic: true));
      expect(deck.everyStyle((style) => style.italic), isTrue);
    });

    test('a format that changes nothing leaves no step', () {
      final id = _titleOf(deck).id;
      deck.startEditing(id);
      _type(deck, 'Title');
      deck.select({id});
      deck.undo();
      expect(deck.canUndo, isFalse);
      deck.redo();

      final before = deck.presentation;
      deck.formatText((style) => style.copyWith(bold: false));
      expect(deck.presentation, same(before));
    });

    test('Enter on an empty list item leaves the list a level at a time', () {
      deck.startEditing(_titleOf(deck).id);
      deck.formatParagraphs(
        (paragraph) => paragraph.copyWith(bullet: BulletKind.bullet, level: 1),
      );

      deck.insertText('\n');
      expect(_titleOf(deck).text.paragraphs.single.level, 0);
      expect(_titleOf(deck).text.paragraphs.single.bullet, BulletKind.bullet);

      deck.insertText('\n');
      expect(_titleOf(deck).text.paragraphs.single.bullet, BulletKind.none);

      deck.insertText('\n');
      expect(_titleOf(deck).text.paragraphs, hasLength(2));
    });

    test('Enter on a list item with text adds another item', () {
      deck.startEditing(_titleOf(deck).id);
      deck.formatParagraphs(
        (paragraph) => paragraph.copyWith(bullet: BulletKind.bullet),
      );
      _type(deck, 'one');
      deck.insertText('\n');
      final paragraphs = _titleOf(deck).text.paragraphs;
      expect(paragraphs, hasLength(2));
      expect(paragraphs.last.bullet, BulletKind.bullet);
    });

    test('a text box left empty goes away', () {
      final before = deck.slide.elements.length;
      deck.addTextBox();
      expect(deck.editing, isNotNull);
      expect(deck.slide.elements, hasLength(before + 1));

      deck.stopEditing();
      expect(deck.slide.elements, hasLength(before));
      expect(deck.selection, isEmpty);
    });

    test('a text box grows with its text', () {
      deck.addTextBox();
      final empty = deck.editing!.frame.height;
      _type(deck, 'one');
      deck.insertText('\n');
      _type(deck, 'two');
      expect(deck.editing!.frame.height, greaterThan(empty));

      deck.stopEditing();
      expect(deck.single, isNotNull);
    });

    test('an empty placeholder stays when it is left', () {
      final before = deck.slide.elements.length;
      deck.startEditing(_titleOf(deck).id);
      deck.stopEditing();
      expect(deck.slide.elements, hasLength(before));
    });

    test('lines and locked elements take no text', () {
      deck.addShape(ShapeKind.line);
      deck.startEditing(deck.single!.id);
      expect(deck.editing, isNull);
    });
  });

  group('saving', () {
    test('marks the written presentation as saved', () {
      deck.addSlide();
      deck.markSaved(
        deck.presentation,
        name: 'deck.pptx',
        path: '/a/deck.pptx',
      );
      expect(deck.dirty, isFalse);
      expect(deck.name, 'deck.pptx');
      expect(deck.path, '/a/deck.pptx');
    });

    test('what changed during the save is still unsaved', () {
      final written = deck.presentation;
      deck.addSlide();
      deck.markSaved(written, name: 'deck.pptx', path: '/a/deck.pptx');
      expect(deck.dirty, isTrue);
    });

    test('undoing back to the saved state is not dirty', () {
      deck.addSlide();
      deck.markSaved(
        deck.presentation,
        name: 'deck.pptx',
        path: '/a/deck.pptx',
      );
      deck.addSlide();
      expect(deck.dirty, isTrue);
      deck.undo();
      expect(deck.dirty, isFalse);
    });
  });
}
