import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../deck/element.dart';

final _paths = Expando<Path>();

/// The outline of a shape around the center of its frame, before rotation.
Path shapePathOf(ShapeElement shape) => _paths[shape] ??= _build(shape);

Path _build(ShapeElement shape) {
  final size = shape.frame.size;
  final sx = shape.flipH ? -1.0 : 1.0, sy = shape.flipV ? -1.0 : 1.0;
  return _outline(shape.kind, size.width, size.height).transform(
    Float64List.fromList([
      ...[sx, 0, 0, 0],
      ...[0, sy, 0, 0],
      ...[0, 0, 1, 0],
      ...[-sx * size.width / 2, -sy * size.height / 2, 0, 1],
    ]),
  );
}

Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

Path _outline(ShapeKind kind, double w, double h) {
  final short = math.min(w, h);
  switch (kind) {
    case ShapeKind.rectangle || ShapeKind.line:
      return Path()..addRect(Rect.fromLTWH(0, 0, w, h));
    case ShapeKind.roundedRectangle:
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h),
          Radius.circular(short / 6),
        ),
      );
    case ShapeKind.ellipse:
      return Path()..addOval(Rect.fromLTWH(0, 0, w, h));
    case ShapeKind.triangle:
      return _polygon([Offset(w / 2, 0), Offset(w, h), Offset(0, h)]);
    case ShapeKind.rightTriangle:
      return _polygon([Offset.zero, Offset(w, h), Offset(0, h)]);
    case ShapeKind.diamond:
      return _polygon([
        Offset(w / 2, 0),
        Offset(w, h / 2),
        Offset(w / 2, h),
        Offset(0, h / 2),
      ]);
    case ShapeKind.pentagon:
      return _polygon([
        Offset(w / 2, 0),
        Offset(w, h * 0.38197),
        Offset(w * 0.80902, h),
        Offset(w * 0.19098, h),
        Offset(0, h * 0.38197),
      ]);
    case ShapeKind.hexagon:
      final inset = math.min(short / 4, w / 2);
      return _polygon([
        Offset(0, h / 2),
        Offset(inset, 0),
        Offset(w - inset, 0),
        Offset(w, h / 2),
        Offset(w - inset, h),
        Offset(inset, h),
      ]);
    case ShapeKind.star:
      return _polygon([
        for (var point = 0; point < 10; point++) _starPoint(point, w, h),
      ]);
    case ShapeKind.rightArrow:
      return _polygon(_arrow(w, h));
    case ShapeKind.leftArrow:
      return _polygon([for (final p in _arrow(w, h)) Offset(w - p.dx, p.dy)]);
    case ShapeKind.downArrow:
      return _polygon([for (final p in _arrow(h, w)) Offset(p.dy, p.dx)]);
    case ShapeKind.upArrow:
      return _polygon([for (final p in _arrow(h, w)) Offset(p.dy, h - p.dx)]);
  }
}

Offset _starPoint(int point, double w, double h) {
  final radius = point.isEven ? 1.0 : 0.381966;
  final angle = -math.pi / 2 + point * math.pi / 5;
  return Offset(
    w / 2 + w / 2 * radius * math.cos(angle) / 0.951057,
    h * (radius * math.sin(angle) + 1) / 1.809017,
  );
}

/// An arrow pointing right in a box [length] long and [breadth] across.
List<Offset> _arrow(double length, double breadth) {
  final neck = length - math.min(length, breadth) / 2;
  return [
    Offset(0, breadth / 4),
    Offset(neck, breadth / 4),
    Offset(neck, 0),
    Offset(length, breadth / 2),
    Offset(neck, breadth),
    Offset(neck, breadth * 3 / 4),
    Offset(0, breadth * 3 / 4),
  ];
}

/// How far from its tip the head of an arrow on a line reaches.
double arrowHeadLength(double strokeWidth) => math.max(7, strokeWidth * 3.5);

/// The head of an arrow whose tip is at [tip], coming from [from].
Path arrowHead(Offset from, Offset tip, double strokeWidth) {
  final length = arrowHeadLength(strokeWidth);
  final travel = tip - from;
  final distance = travel.distance;
  final along = distance == 0 ? const Offset(1, 0) : travel / distance;
  final across = Offset(-along.dy, along.dx) * (length * 0.4);
  final base = tip - along * length;
  return _polygon([tip, base + across, base - across]);
}
