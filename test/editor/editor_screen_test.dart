import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/app.dart';
import 'package:voges_slides/deck/deck_controller.dart';
import 'package:voges_slides/deck/element.dart';
import 'package:voges_slides/deck/text_body.dart';
import 'package:voges_slides/editor/slide_canvas.dart';
import 'package:voges_slides/files/presentation_files.dart';
import 'package:voges_slides/files/system_open.dart';
import 'package:voges_slides/l10n/app_language.dart';

/// The time of the last pointer event, so clicks can be told from double
/// clicks.
var clock = Duration.zero;

Future<DeckController> pumpEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = DeckController();
  final files = PresentationFiles();
  await tester.pumpWidget(
    VogesSlidesApp(
      controller: controller,
      files: files,
      systemOpen: SystemOpen(files),
      language: AppLanguage(const Locale('pt')),
      launchArguments: const [],
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Where a point of the slide, in slide units, is on the screen.
Offset onSlide(WidgetTester tester, Offset point) {
  final canvas = tester.getRect(find.byType(SlideCanvas));
  final scale = math.min((canvas.width - 48) / 960, (canvas.height - 48) / 540);
  final origin = Offset(
    (canvas.width - 960 * scale) / 2,
    (canvas.height - 540 * scale) / 2,
  );
  return canvas.topLeft + origin + point * scale;
}

Future<void> _press(WidgetTester tester, Offset at) async {
  final gesture = await tester.createGesture();
  await gesture.down(at, timeStamp: clock);
  await gesture.up(timeStamp: clock);
  await tester.pump();
}

Future<void> click(WidgetTester tester, Offset at) {
  clock += const Duration(seconds: 1);
  return _press(tester, at);
}

Future<void> doubleClick(WidgetTester tester, Offset at) async {
  await click(tester, at);
  clock += const Duration(milliseconds: 100);
  await _press(tester, at);
}

Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
  clock += const Duration(seconds: 1);
  final gesture = await tester.createGesture();
  await gesture.down(from, timeStamp: clock);
  await gesture.moveTo(Offset.lerp(from, to, 0.5)!, timeStamp: clock);
  await gesture.moveTo(to, timeStamp: clock);
  await gesture.up(timeStamp: clock);
  await tester.pump();
}

/// Replaces the text being typed, as the system keyboard does.
Future<void> type(WidgetTester tester, String text) async {
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump();
}

Future<void> press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool shift = false,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

ShapeElement shapeOf(DeckController c, int id) =>
    c.slide.element(id)! as ShapeElement;

void main() {
  testWidgets('starts with one title slide', (tester) async {
    final c = await pumpEditor(tester);
    expect(c.slides, hasLength(1));
    expect(c.dirty, isFalse);
    expect(find.text('Slide 1 de 1'), findsOneWidget);
  });

  testWidgets('a double click on a placeholder starts typing in it', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    final title = c.slide.elements.first;
    await doubleClick(tester, onSlide(tester, title.frame.center));
    expect(c.editingId, title.id);
    await type(tester, 'Olá');
    expect(shapeOf(c, title.id).text.text, 'Olá');
    expect(c.dirty, isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    expect(c.editing, isNull);
    expect(c.selection, {title.id});
  });

  testWidgets('a second click on the selected shape puts the caret in it', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    final title = c.slide.elements.first;
    final center = onSlide(tester, title.frame.center);
    await click(tester, center);
    expect(c.selection, {title.id});
    expect(c.editing, isNull);
    await click(tester, center);
    expect(c.editingId, title.id);
  });

  testWidgets('Shift+Enter breaks the line inside the paragraph', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    final title = c.slide.elements.first;
    await doubleClick(tester, onSlide(tester, title.frame.center));
    await type(tester, 'ab');
    await press(tester, LogicalKeyboardKey.enter, shift: true);
    final text = shapeOf(c, title.id).text;
    expect(text.text, 'ab$softBreak');
    expect(text.paragraphs, hasLength(1));
  });

  testWidgets('Tab changes the level of a bulleted paragraph', (tester) async {
    final c = await pumpEditor(tester);
    c.addSlide();
    await tester.pump();
    final body = c.slide.elements.last;
    await doubleClick(tester, onSlide(tester, body.frame.center));
    expect(c.editingId, body.id);
    await type(tester, 'item');
    await press(tester, LogicalKeyboardKey.tab);
    expect(shapeOf(c, body.id).text.paragraphs.single.level, 1);
    expect(shapeOf(c, body.id).text.text, 'item');
    await press(tester, LogicalKeyboardKey.tab, shift: true);
    expect(shapeOf(c, body.id).text.paragraphs.single.level, 0);
  });

  testWidgets('typing over a selected shape goes on from the end of its text', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    final title = c.slide.elements.first;
    await click(tester, onSlide(tester, title.frame.center));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await tester.pump();
    expect(c.editingId, title.id);
    expect(shapeOf(c, title.id).text.text, 'a');
    expect(c.textSelection, const TextSelection.collapsed(offset: 1));
  });

  testWidgets('the shortcuts format the selected text', (tester) async {
    final c = await pumpEditor(tester);
    final title = c.slide.elements.first;
    await doubleClick(tester, onSlide(tester, title.frame.center));
    await type(tester, 'abc');
    await press(tester, LogicalKeyboardKey.keyA, control: true);
    expect(c.textSelection.start, 0);
    expect(c.textSelection.end, 3);
    await press(tester, LogicalKeyboardKey.keyB, control: true);
    expect(c.everyStyle((style) => style.bold), isTrue);
    await tester.tap(find.byTooltip('Itálico (Ctrl+I)'));
    await tester.pump();
    expect(c.everyStyle((style) => style.italic), isTrue);
    await press(tester, LogicalKeyboardKey.keyB, control: true);
    expect(c.everyStyle((style) => style.bold), isFalse);
  });

  testWidgets('the ribbon adds a slide with the chosen layout', (tester) async {
    final c = await pumpEditor(tester);
    await tester.tap(find.text('Novo slide'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Somente título'));
    await tester.pumpAndSettle();
    expect(c.slides, hasLength(2));
    expect(c.slideIndex, 1);
    expect(c.slide.elements, hasLength(1));
    expect(find.text('Slide 2 de 2'), findsOneWidget);
  });

  testWidgets('the ribbon adds a shape, selected', (tester) async {
    final c = await pumpEditor(tester);
    await tester.tap(find.text('Formas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elipse'));
    await tester.pumpAndSettle();
    final shape = c.single! as ShapeElement;
    expect(shape.kind, ShapeKind.ellipse);
    expect(c.slide.elements, hasLength(3));
  });

  testWidgets('Delete removes the selected shape and undo brings it back', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    c.addShape(ShapeKind.ellipse);
    await tester.pump();
    final id = c.single!.id;
    await press(tester, LogicalKeyboardKey.delete);
    expect(c.slide.element(id), isNull);
    await press(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(c.slide.element(id), isNotNull);
  });

  testWidgets('dragging a shape moves it in a single undo step', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    c.addShape(ShapeKind.ellipse);
    await tester.pump();
    final before = c.single!.frame;
    final from = onSlide(tester, before.center);
    final to = onSlide(tester, before.center + const Offset(100, -50));
    await drag(tester, from, to);
    final after = c.single!.frame;
    expect(after.left, moreOrLessEquals(before.left + 100, epsilon: 0.01));
    expect(after.top, moreOrLessEquals(before.top - 50, epsilon: 0.01));
    expect(after.width, moreOrLessEquals(before.width, epsilon: 0.01));
    expect(after.height, moreOrLessEquals(before.height, epsilon: 0.01));
    expect(c.editing, isNull);
    c.undo();
    expect(c.single!.frame, before);
  });

  testWidgets('the arrows nudge the selected shape', (tester) async {
    final c = await pumpEditor(tester);
    c.addShape(ShapeKind.rectangle);
    await tester.pump();
    final before = c.single!.frame;
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowDown, shift: true);
    expect(c.single!.frame, before.shift(const Offset(1, 10)));
  });

  testWidgets('Ctrl+D duplicates the selected shape', (tester) async {
    final c = await pumpEditor(tester);
    c.addShape(ShapeKind.rectangle);
    await tester.pump();
    final original = c.single!;
    await press(tester, LogicalKeyboardKey.keyD, control: true);
    expect(c.slide.elements, hasLength(4));
    expect(c.single!.id, isNot(original.id));
    expect(c.single!.frame.size, original.frame.size);
  });

  testWidgets('a click on the empty slide clears the selection', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    final title = c.slide.elements.first;
    await click(tester, onSlide(tester, title.frame.center));
    expect(c.selection, isNotEmpty);
    await click(tester, onSlide(tester, const Offset(20, 20)));
    expect(c.selection, isEmpty);
  });

  testWidgets('the right click menu deletes the shape under it', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    final title = c.slide.elements.first;
    await tester.tapAt(
      onSlide(tester, title.frame.center),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(c.selection, {title.id});
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(c.slide.element(title.id), isNull);
  });

  testWidgets('the slideshow runs to the closing screen and comes back', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    c
      ..addSlide()
      ..selectSlide(0);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('Fim da apresentação. Clique para sair.'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(c.slideIndex, 1);
    expect(find.text('Slide 2 de 2'), findsOneWidget);
  });
}
