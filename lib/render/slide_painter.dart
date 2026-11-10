import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../deck/element.dart';
import '../deck/presentation.dart';
import '../deck/text_body.dart';
import '../text/text_layout.dart';
import 'shape_paths.dart';
import 'slide_images.dart';

/// The text an empty placeholder shows in the editor.
class SlidePrompts {
  const SlidePrompts({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final String title;
  final String subtitle;
  final String body;

  String of(PlaceholderKind kind) => switch (kind) {
    PlaceholderKind.title => title,
    PlaceholderKind.subtitle => subtitle,
    PlaceholderKind.body => body,
  };
}

const _promptColor = 0xFF8A8A8A;

final _promptBodies = Expando<TextBody>();

TextBody _promptBody(Paragraph first, String prompt) {
  final cached = _promptBodies[first];
  if (cached != null && cached.paragraphs.first.runs.first.text == prompt) {
    return cached;
  }
  return _promptBodies[first] = TextBody([
    first.copyWith(
      runs: [
        TextRun(prompt, first.runs.first.style.copyWith(color: _promptColor)),
      ],
    ),
  ]);
}

/// Draws a slide in its own points, with the top left corner at the origin.
///
/// [prompts] are shown in empty placeholders, except in the one being typed
/// in ([editingId]). [clip] hides what hangs out of the slide.
void paintSlide(
  Canvas canvas,
  Slide slide,
  Size size,
  SlideImages images, {
  int? editingId,
  SlidePrompts? prompts,
  bool clip = true,
}) {
  final area = Offset.zero & size;
  canvas.save();
  if (clip) canvas.clipRect(area);
  canvas.drawRect(area, Paint()..color = Color(slide.background));
  final backdrop = slide.backgroundImage;
  final picture = backdrop == null ? null : images.of(backdrop);
  if (picture != null) _drawImage(canvas, picture, Rect.zero, area);
  for (final element in slide.elements) {
    switch (element) {
      case ShapeElement():
        if (element.isLine) {
          _paintLine(canvas, element);
        } else {
          _paintShape(
            canvas,
            element,
            element.id == editingId ? null : prompts,
          );
        }
      case ImageElement():
        _paintImage(canvas, element, images);
    }
  }
  canvas.restore();
}

void _centered(Canvas canvas, SlideElement element, VoidCallback paint) {
  final center = element.frame.center;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  if (element.rotation != 0) canvas.rotate(element.rotation * math.pi / 180);
  paint();
  canvas.restore();
}

Paint _strokeOf(ShapeElement shape, int color) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = shape.strokeWidth
  ..strokeJoin = StrokeJoin.round
  ..color = Color(color);

void _paintShape(Canvas canvas, ShapeElement shape, SlidePrompts? prompts) {
  _centered(canvas, shape, () {
    final fill = shape.fill, stroke = shape.stroke;
    if (fill != null || (stroke != null && shape.strokeWidth > 0)) {
      final path = shapePathOf(shape);
      if (fill != null) canvas.drawPath(path, Paint()..color = Color(fill));
      if (stroke != null && shape.strokeWidth > 0) {
        canvas.drawPath(path, _strokeOf(shape, stroke));
      }
    }
    final corner = -shape.frame.size.center(Offset.zero);
    if (!shape.text.isEmpty) {
      final layout = layoutOf(shape);
      layout.paint(canvas, corner + textOriginOf(shape, layout));
      return;
    }
    final kind = shape.placeholder;
    if (prompts == null || kind == null) return;
    final layout = BodyLayout(
      _promptBody(shape.text.paragraphs.first, prompts.of(kind)),
      textWidthOf(shape),
    );
    layout.paint(canvas, corner + textOriginOf(shape, layout));
  });
}

void _paintLine(Canvas canvas, ShapeElement line) {
  final color = line.stroke;
  if (color == null || line.strokeWidth <= 0) return;
  var start = line.lineStart, end = line.lineEnd;
  final travel = end - start;
  final length = travel.distance;
  if (length == 0) return;
  final along = travel / length;
  final head = math.min(arrowHeadLength(line.strokeWidth), length / 2);
  final solid = Paint()..color = Color(color);
  // the line stops short of the tip so it does not blunt the arrow head
  if (line.endArrow) {
    canvas.drawPath(arrowHead(start, end, line.strokeWidth), solid);
    end -= along * (head * 0.8);
  }
  if (line.startArrow) {
    canvas.drawPath(arrowHead(end, start, line.strokeWidth), solid);
    start += along * (head * 0.8);
  }
  canvas.drawLine(start, end, _strokeOf(line, color));
}

void _paintImage(Canvas canvas, ImageElement element, SlideImages images) {
  final picture = images.of(element.image);
  final box = Rect.fromCenter(
    center: Offset.zero,
    width: element.frame.width,
    height: element.frame.height,
  );
  _centered(canvas, element, () {
    if (picture != null) {
      _drawImage(canvas, picture, element.crop, box);
      return;
    }
    canvas.drawRect(box, Paint()..color = const Color(0xFFE3E3E3));
    canvas.drawRect(
      box.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFB5B5B5),
    );
  });
}

void _drawImage(Canvas canvas, ui.Image picture, Rect crop, Rect box) {
  final width = picture.width.toDouble(), height = picture.height.toDouble();
  canvas.drawImageRect(
    picture,
    Rect.fromLTRB(
      crop.left * width,
      crop.top * height,
      width - crop.right * width,
      height - crop.bottom * height,
    ),
    box,
    Paint()..filterQuality = FilterQuality.medium,
  );
}
