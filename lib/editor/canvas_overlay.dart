import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../deck/deck_controller.dart';
import '../deck/element.dart';
import '../text/text_layout.dart';
import 'canvas_geometry.dart';

/// Distance, in screen pixels, from the frame to its rotation handle.
const rotateHandleGap = 24.0;

/// What the editor draws over the slide: selection frames, handles, the
/// caret and the selected text. Sizes are in screen pixels at any zoom.
class CanvasOverlay extends CustomPainter {
  CanvasOverlay({
    required this.controller,
    required this.focusNode,
    required this.marquee,
    required this.caretOn,
    required this.origin,
    required this.scale,
    required this.accent,
  }) : super(
         repaint: Listenable.merge([controller, focusNode, marquee, caretOn]),
       );

  final DeckController controller;
  final FocusNode focusNode;

  /// The box being dragged over the slide, in points.
  final ValueListenable<Rect?> marquee;
  final ValueListenable<bool> caretOn;

  /// Where the top left corner of the slide is drawn.
  final Offset origin;
  final double scale;
  final Color accent;

  Offset _screen(Offset point) => origin + point * scale;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent;
    final editing = controller.editing;
    if (editing != null) _paintText(canvas, editing);
    for (final element in controller.selected) {
      if (element is ShapeElement && element.isLine) continue;
      final half = element.frame.size / 2;
      canvas.drawPath(
        Path()..addPolygon([
          for (final (x, y) in const [(-1, -1), (1, -1), (1, 1), (-1, 1)])
            _screen(toSlide(element, Offset(x * half.width, y * half.height))),
        ], true),
        line,
      );
    }
    final single = controller.single;
    if (single != null) _paintHandles(canvas, single, line);
    final box = marquee.value;
    if (box != null) {
      final area = Rect.fromPoints(
        _screen(box.topLeft),
        _screen(box.bottomRight),
      );
      canvas.drawRect(area, Paint()..color = accent.withValues(alpha: 0.12));
      canvas.drawRect(area, line);
    }
  }

  void _paintHandles(Canvas canvas, SlideElement element, Paint line) {
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    final handles = handlesOf(element, rotateHandleGap / scale);
    for (final placed in handles) {
      final at = _screen(placed.at);
      switch (placed.handle.kind) {
        case HandleKind.rotate:
          final half = element.frame.height / 2;
          canvas.drawLine(
            _screen(toSlide(element, Offset(0, -half))),
            at,
            line,
          );
          canvas.drawCircle(at, 5, fill);
          canvas.drawCircle(at, 5, line);
        case HandleKind.lineStart || HandleKind.lineEnd:
          canvas.drawCircle(at, 4.5, fill);
          canvas.drawCircle(at, 4.5, line);
        case HandleKind.resize:
          final grip = Rect.fromCenter(center: at, width: 8, height: 8);
          canvas.drawRect(grip, fill);
          canvas.drawRect(grip, line);
      }
    }
  }

  void _paintText(Canvas canvas, ShapeElement shape) {
    final selection = controller.textSelection;
    final layout = layoutOf(shape);
    final center = _screen(shape.frame.center);
    final corner = textCornerOf(shape);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (shape.rotation != 0) canvas.rotate(shape.rotation * math.pi / 180);
    canvas.scale(scale);
    canvas.translate(corner.dx, corner.dy);
    if (!selection.isCollapsed) {
      final highlight = Paint()..color = accent.withValues(alpha: 0.3);
      for (final rect in layout.selectionRects(
        selection.start,
        selection.end,
      )) {
        canvas.drawRect(rect, highlight);
      }
    } else if (caretOn.value && focusNode.hasFocus) {
      final caret = layout.caretRect(selection.extentOffset);
      final width = 1.5 / scale;
      canvas.drawRect(
        Rect.fromLTWH(caret.left - width / 2, caret.top, width, caret.height),
        Paint()..color = Color(controller.currentStyle?.color ?? 0xFF000000),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CanvasOverlay old) =>
      old.origin != origin || old.scale != scale || old.accent != accent;
}
