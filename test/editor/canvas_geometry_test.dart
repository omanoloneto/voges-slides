import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/deck/element.dart';
import 'package:voges_slides/deck/presentation.dart';
import 'package:voges_slides/deck/text_body.dart';
import 'package:voges_slides/editor/canvas_geometry.dart';

ShapeElement box(
  int id,
  Rect frame, {
  double rotation = 0,
  bool locked = false,
}) => ShapeElement(
  id: id,
  frame: frame,
  rotation: rotation,
  locked: locked,
  text: TextBody.empty(),
);

ShapeElement line(Offset start, Offset end) => lineBetween(
  ShapeElement(
    id: 9,
    frame: Rect.zero,
    kind: ShapeKind.line,
    stroke: 0xFF000000,
    strokeWidth: 2,
    text: TextBody.empty(),
  ),
  start,
  end,
);

Matcher near(Offset expected) => within<Offset>(
  distance: 1e-6,
  from: expected,
  distanceFunction: (a, b) => (a - b).distance,
);

void main() {
  const frame = Rect.fromLTWH(100, 100, 200, 100);

  group('rotation', () {
    test('turns clockwise as the slide shows it', () {
      expect(rotated(const Offset(10, 0), 90), near(const Offset(0, 10)));
      expect(rotated(const Offset(0, -10), 90), near(const Offset(10, 0)));
    });

    test('toLocal and toSlide undo each other', () {
      final shape = box(1, frame, rotation: 30);
      const point = Offset(260, 120);
      expect(toSlide(shape, toLocal(shape, point)), near(point));
    });

    test('the upright bounds of a quarter turn swap width and height', () {
      final bounds = boundsOf(box(1, frame, rotation: 90));
      expect(bounds.center, near(frame.center));
      expect(bounds.width, closeTo(100, 1e-6));
      expect(bounds.height, closeTo(200, 1e-6));
    });

    test('rotationToward points the top at the pointer', () {
      final shape = box(1, frame);
      final center = frame.center;
      expect(
        rotationToward(shape, center + const Offset(0, -50), snap: false),
        closeTo(0, 1e-6),
      );
      expect(
        rotationToward(shape, center + const Offset(50, 0), snap: false),
        closeTo(90, 1e-6),
      );
      expect(
        rotationToward(shape, center + const Offset(-50, 0), snap: false),
        closeTo(270, 1e-6),
      );
    });

    test('rotationToward snaps to steps of 15 degrees', () {
      final shape = box(1, frame);
      final toward = frame.center + rotated(const Offset(0, -80), 50);
      expect(rotationToward(shape, toward, snap: true), 45);
    });
  });

  group('hit test', () {
    test('a rotated shape is hit where it is drawn', () {
      final shape = box(1, frame, rotation: 90);
      // the frame is 200 wide, but turned it reaches 100 above the center
      expect(hits(shape, frame.center + const Offset(0, -90), 0), isTrue);
      expect(hits(shape, frame.center + const Offset(90, 0), 0), isFalse);
    });

    test('a line is hit near its segment only', () {
      final diagonal = line(const Offset(0, 0), const Offset(100, 100));
      expect(hits(diagonal, const Offset(50, 52), 4), isTrue);
      expect(hits(diagonal, const Offset(90, 10), 4), isFalse);
      expect(hits(diagonal, const Offset(120, 120), 4), isFalse);
    });

    test('elementAt picks the front element and skips locked ones', () {
      final slide = Slide(
        id: 100,
        elements: [
          box(1, frame),
          box(2, frame.shift(const Offset(50, 0))),
          box(3, frame, locked: true),
        ],
      );
      expect(elementAt(slide, const Offset(200, 150), 0)?.id, 2);
      expect(elementAt(slide, const Offset(110, 150), 0)?.id, 1);
      expect(elementAt(slide, const Offset(10, 10), 0), isNull);
    });
  });

  group('handles', () {
    test('a shape has a rotation handle and eight resize handles', () {
      final placed = handlesOf(box(1, frame), 20);
      expect(placed, hasLength(9));
      expect(placed.first.handle.kind, HandleKind.rotate);
      expect(placed.first.at, near(const Offset(200, 80)));
    });

    test('a line only has its two ends', () {
      final placed = handlesOf(
        line(const Offset(10, 90), const Offset(70, 20)),
        20,
      );
      expect(
        [for (final entry in placed) entry.handle.kind],
        [HandleKind.lineStart, HandleKind.lineEnd],
      );
      expect(placed.first.at, const Offset(10, 90));
      expect(placed.last.at, const Offset(70, 20));
    });

    test('handleAt returns the closest handle within reach', () {
      final shape = box(1, frame);
      final corner = handleAt(shape, const Offset(302, 201), 6, 20);
      expect(corner?.hx, 1);
      expect(corner?.hy, 1);
      expect(handleAt(shape, const Offset(250, 150), 6, 20), isNull);
    });
  });

  group('resize', () {
    test('dragging a corner keeps the opposite corner in place', () {
      final changed = resized(
        box(1, frame),
        const Handle.resize(1, 1),
        const Offset(400, 250),
        keepAspect: false,
      );
      expect(changed.frame, const Rect.fromLTRB(100, 100, 400, 250));
    });

    test('dragging a side changes one dimension only', () {
      final changed = resized(
        box(1, frame),
        const Handle.resize(-1, 0),
        const Offset(50, 400),
        keepAspect: false,
      );
      expect(changed.frame, const Rect.fromLTRB(50, 100, 300, 200));
    });

    test('keeping the aspect scales both dimensions by the larger pull', () {
      final changed = resized(
        box(1, frame),
        const Handle.resize(1, 1),
        const Offset(500, 210),
        keepAspect: true,
      );
      expect(changed.frame, const Rect.fromLTRB(100, 100, 500, 300));
    });

    test('a shape never gets smaller than the minimum', () {
      final changed = resized(
        box(1, frame),
        const Handle.resize(1, 1),
        const Offset(0, 0),
        keepAspect: false,
      );
      expect(changed.frame.width, minElementSize);
      expect(changed.frame.height, minElementSize);
      expect(changed.frame.topLeft, frame.topLeft);
    });

    test('a rotated shape keeps its opposite corner where it is drawn', () {
      final shape = box(1, frame, rotation: 90);
      const handle = Handle.resize(1, 1);
      final anchor = toSlide(shape, const Offset(-100, -50));
      final changed = resized(
        shape,
        handle,
        toSlide(shape, const Offset(200, 100)),
        keepAspect: false,
      );
      expect(changed.frame.width, closeTo(300, 1e-6));
      expect(changed.frame.height, closeTo(150, 1e-6));
      expect(toSlide(changed, const Offset(-150, -75)), near(anchor));
    });
  });

  group('lines', () {
    test('lineBetween keeps the direction in the flips', () {
      final up = line(const Offset(100, 80), const Offset(20, 10));
      expect(up.frame, const Rect.fromLTRB(20, 10, 100, 80));
      expect(up.flipH, isTrue);
      expect(up.flipV, isTrue);
      expect(up.lineStart, const Offset(100, 80));
      expect(up.lineEnd, const Offset(20, 10));
    });

    test('snappedLineEnd rounds the angle to 45 degrees', () {
      expect(
        snappedLineEnd(const Offset(0, 0), const Offset(100, 8)),
        near(Offset(const Offset(100, 8).distance, 0)),
      );
      final diagonal = snappedLineEnd(const Offset(0, 0), const Offset(60, 50));
      expect(diagonal.dx, closeTo(diagonal.dy, 1e-6));
    });
  });
}
