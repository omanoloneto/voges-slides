import 'dart:math' as math;
import 'dart:ui';

import '../deck/element.dart';
import '../deck/presentation.dart';
import '../text/text_layout.dart';

const minElementSize = 4.0;

enum HandleKind { resize, rotate, lineStart, lineEnd }

/// A grip of the selection frame. For a resize grip, [hx] and [hy] say which
/// side or corner it sits on: -1, 0 or 1.
class Handle {
  const Handle.resize(this.hx, this.hy) : kind = HandleKind.resize;
  const Handle.rotate() : kind = HandleKind.rotate, hx = 0, hy = -1;
  const Handle.lineStart() : kind = HandleKind.lineStart, hx = 0, hy = 0;
  const Handle.lineEnd() : kind = HandleKind.lineEnd, hx = 0, hy = 0;

  final HandleKind kind;
  final int hx;
  final int hy;

  bool get isCorner => hx != 0 && hy != 0;
}

typedef PlacedHandle = ({Handle handle, Offset at});

const _resizeHandles = [
  Handle.resize(-1, -1),
  Handle.resize(0, -1),
  Handle.resize(1, -1),
  Handle.resize(1, 0),
  Handle.resize(1, 1),
  Handle.resize(0, 1),
  Handle.resize(-1, 1),
  Handle.resize(-1, 0),
];

/// [vector] turned clockwise, as the slide shows a rotated element.
Offset rotated(Offset vector, double degrees) {
  if (degrees == 0) return vector;
  final radians = degrees * math.pi / 180;
  final cos = math.cos(radians), sin = math.sin(radians);
  return Offset(
    vector.dx * cos - vector.dy * sin,
    vector.dx * sin + vector.dy * cos,
  );
}

/// A point of the slide seen from the center of [element], as if the
/// element was not rotated.
Offset toLocal(SlideElement element, Offset point) =>
    rotated(point - element.frame.center, -element.rotation);

Offset toSlide(SlideElement element, Offset local) =>
    element.frame.center + rotated(local, element.rotation);

/// Where the handles of [element] sit on the slide. The rotation handle
/// floats [rotateGap] above the frame.
List<PlacedHandle> handlesOf(SlideElement element, double rotateGap) {
  if (element is ShapeElement && element.isLine) {
    return [
      (handle: const Handle.lineStart(), at: element.lineStart),
      (handle: const Handle.lineEnd(), at: element.lineEnd),
    ];
  }
  final half = element.frame.size / 2;
  return [
    (
      handle: const Handle.rotate(),
      at: toSlide(element, Offset(0, -half.height - rotateGap)),
    ),
    for (final handle in _resizeHandles)
      (
        handle: handle,
        at: toSlide(
          element,
          Offset(handle.hx * half.width, handle.hy * half.height),
        ),
      ),
  ];
}

/// The handle of [element] closest to [point], no farther than [radius].
Handle? handleAt(
  SlideElement element,
  Offset point,
  double radius,
  double rotateGap,
) {
  Handle? closest;
  var best = radius;
  for (final placed in handlesOf(element, rotateGap)) {
    final distance = (placed.at - point).distance;
    if (distance <= best) {
      best = distance;
      closest = placed.handle;
    }
  }
  return closest;
}

double _distanceToSegment(Offset point, Offset a, Offset b) {
  final travel = b - a;
  final length = travel.distanceSquared;
  if (length == 0) return (point - a).distance;
  final along =
      ((point.dx - a.dx) * travel.dx + (point.dy - a.dy) * travel.dy) / length;
  return (point - (a + travel * along.clamp(0.0, 1.0))).distance;
}

/// Whether [point] touches [element]; [slop] is the reach around a line.
bool hits(SlideElement element, Offset point, double slop) {
  if (element is ShapeElement && element.isLine) {
    return _distanceToSegment(point, element.lineStart, element.lineEnd) <=
        slop + element.strokeWidth / 2;
  }
  final local = toLocal(element, point);
  final half = element.frame.size / 2;
  return local.dx.abs() <= half.width + 1 && local.dy.abs() <= half.height + 1;
}

/// The front element under [point] that can be selected.
SlideElement? elementAt(Slide slide, Offset point, double slop) {
  for (final element in slide.elements.reversed) {
    if (!element.locked && hits(element, point, slop)) return element;
  }
  return null;
}

/// The upright box around [element] as it is drawn.
Rect boundsOf(SlideElement element) {
  if (element.rotation == 0) return element.frame;
  final half = element.frame.size / 2;
  final a = rotated(Offset(half.width, half.height), element.rotation);
  final b = rotated(Offset(half.width, -half.height), element.rotation);
  final reach = Offset(
    math.max(a.dx.abs(), b.dx.abs()),
    math.max(a.dy.abs(), b.dy.abs()),
  );
  return Rect.fromCenter(
    center: element.frame.center,
    width: reach.dx * 2,
    height: reach.dy * 2,
  );
}

/// Top left corner of the text of [shape], from the center of its frame.
Offset textCornerOf(ShapeElement shape) =>
    textOriginOf(shape, layoutOf(shape)) - shape.frame.size.center(Offset.zero);

/// The position in the text of [shape] closest to a point of the slide.
int textPositionAt(ShapeElement shape, Offset point) =>
    layoutOf(shape).positionAt(toLocal(shape, point) - textCornerOf(shape));

/// [original] with a resize handle dragged to [point]; the opposite side or
/// corner stays where it is.
SlideElement resized(
  SlideElement original,
  Handle handle,
  Offset point, {
  required bool keepAspect,
}) {
  final hx = handle.hx, hy = handle.hy;
  final width = original.frame.width, height = original.frame.height;
  final anchor = toSlide(original, Offset(-hx * width / 2, -hy * height / 2));
  final reach = rotated(point - anchor, -original.rotation);
  var newWidth = hx != 0 ? math.max(minElementSize, hx * reach.dx) : width;
  var newHeight = hy != 0 ? math.max(minElementSize, hy * reach.dy) : height;
  if (keepAspect && handle.isCorner && width > 0 && height > 0) {
    final scale = math.max(newWidth / width, newHeight / height);
    newWidth = width * scale;
    newHeight = height * scale;
  }
  final center =
      anchor +
      rotated(Offset(hx * newWidth / 2, hy * newHeight / 2), original.rotation);
  return original.withGeometry(
    frame: Rect.fromCenter(center: center, width: newWidth, height: newHeight),
  );
}

/// The rotation that points the top of [element] at [point]; [snap] rounds
/// it to steps of 15 degrees.
double rotationToward(
  SlideElement element,
  Offset point, {
  required bool snap,
}) {
  final toward = point - element.frame.center;
  var degrees = math.atan2(toward.dx, -toward.dy) * 180 / math.pi;
  if (snap) degrees = (degrees / 15).round() * 15.0;
  return degrees % 360;
}

ShapeElement lineBetween(ShapeElement line, Offset start, Offset end) =>
    line.copyWith(
      frame: Rect.fromPoints(start, end),
      flipH: start.dx > end.dx,
      flipV: start.dy > end.dy,
    );

/// [point] moved so the line from [anchor] runs at a multiple of 45 degrees.
Offset snappedLineEnd(Offset anchor, Offset point) {
  final travel = point - anchor;
  const step = math.pi / 4;
  final angle = (travel.direction / step).round() * step;
  return anchor + Offset.fromDirection(angle, travel.distance);
}
