import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:xml/xml.dart';

import '../../deck/element.dart';
import 'pptx_xml.dart';

/// Preset geometries the app draws as they are.
const _exactKinds = {
  'rect': ShapeKind.rectangle,
  'flowChartProcess': ShapeKind.rectangle,
  'roundRect': ShapeKind.roundedRectangle,
  'round1Rect': ShapeKind.roundedRectangle,
  'round2SameRect': ShapeKind.roundedRectangle,
  'snipRoundRect': ShapeKind.roundedRectangle,
  'flowChartAlternateProcess': ShapeKind.roundedRectangle,
  'ellipse': ShapeKind.ellipse,
  'flowChartConnector': ShapeKind.ellipse,
  'triangle': ShapeKind.triangle,
  'flowChartExtract': ShapeKind.triangle,
  'rtTriangle': ShapeKind.rightTriangle,
  'diamond': ShapeKind.diamond,
  'flowChartDecision': ShapeKind.diamond,
  'pentagon': ShapeKind.pentagon,
  'hexagon': ShapeKind.hexagon,
  'star5': ShapeKind.star,
  'rightArrow': ShapeKind.rightArrow,
  'leftArrow': ShapeKind.leftArrow,
  'upArrow': ShapeKind.upArrow,
  'downArrow': ShapeKind.downArrow,
  'line': ShapeKind.line,
  'straightConnector1': ShapeKind.line,
};

final _otherStar = RegExp(r'^star\d+$');
final _routedConnector = RegExp(r'^(bent|curved)Connector\d$');

/// The closest [ShapeKind] to the geometry in [spPr]; `exact` is false when
/// the file drew something the model has no kind for.
({ShapeKind kind, bool exact}) shapeKind(XmlElement? spPr) {
  final preset = child(spPr, 'prstGeom')?.getAttribute('prst');
  if (preset == null) {
    return (kind: ShapeKind.rectangle, exact: child(spPr, 'custGeom') == null);
  }
  final kind = _exactKinds[preset];
  if (kind != null) return (kind: kind, exact: true);
  if (_otherStar.hasMatch(preset)) return (kind: ShapeKind.star, exact: false);
  if (_routedConnector.hasMatch(preset)) {
    return (kind: ShapeKind.line, exact: false);
  }
  return (kind: ShapeKind.rectangle, exact: false);
}

/// Where an `a:xfrm` puts something, in points.
class Placement {
  Placement(this.frame, this.rotation, this.flipH, this.flipV);

  /// Null when [xfrm] has no usable offset and size.
  static Placement? parse(XmlElement? xfrm) {
    final frame = _rect(child(xfrm, 'off'), child(xfrm, 'ext'));
    if (frame == null) return null;
    return Placement(
      frame,
      angleToDegrees(intAttribute(xfrm, 'rot') ?? 0) % 360,
      boolAttribute(xfrm, 'flipH') ?? false,
      boolAttribute(xfrm, 'flipV') ?? false,
    );
  }

  Rect frame;
  double rotation;
  bool flipH;
  bool flipV;

  /// Sizes that came out of broken numbers cannot be drawn.
  bool get isValid =>
      frame.isFinite &&
      rotation.isFinite &&
      frame.left.abs() < _limit &&
      frame.top.abs() < _limit &&
      frame.width < _limit &&
      frame.height < _limit;

  static const _limit = 1e7;

  /// Lines are never rotated in the model: the rotation moves the two ends
  /// instead, and the flips say which corners of the new frame they are.
  void bakeLineRotation() {
    if (rotation == 0) return;
    final center = frame.center;
    final start = _snap(
      _rotate(
        Offset(
          flipH ? frame.right : frame.left,
          flipV ? frame.bottom : frame.top,
        ),
        center,
        rotation,
      ),
    );
    final end = _snap(
      _rotate(
        Offset(
          flipH ? frame.left : frame.right,
          flipV ? frame.top : frame.bottom,
        ),
        center,
        rotation,
      ),
    );
    frame = Rect.fromPoints(start, end);
    flipH = start.dx > end.dx;
    flipV = start.dy > end.dy;
    rotation = 0;
  }

  /// Rounds to whole EMU, hiding the noise of the trigonometry.
  static Offset _snap(Offset point) => Offset(
    (point.dx * emuPerPoint).roundToDouble() / emuPerPoint,
    (point.dy * emuPerPoint).roundToDouble() / emuPerPoint,
  );
}

Rect? _rect(XmlElement? offset, XmlElement? extent) {
  final x = pointsAttribute(offset, 'x');
  final y = pointsAttribute(offset, 'y');
  final width = pointsAttribute(extent, 'cx');
  final height = pointsAttribute(extent, 'cy');
  if (x == null || y == null || width == null || height == null) return null;
  if (width < 0 || height < 0) return null;
  return Rect.fromLTWH(x, y, width, height);
}

Offset _rotate(Offset point, Offset center, double degrees) {
  final radians = degrees * math.pi / 180;
  final cos = math.cos(radians);
  final sin = math.sin(radians);
  final dx = point.dx - center.dx;
  final dy = point.dy - center.dy;
  return Offset(
    center.dx + dx * cos - dy * sin,
    center.dy + dx * sin + dy * cos,
  );
}

/// A `p:grpSp` being flattened: maps what its children say onto the slide.
class GroupFrame {
  GroupFrame._({
    required this.parent,
    required this.frame,
    required this.childFrame,
    required this.rotation,
    required this.flipH,
    required this.flipV,
    required this.fill,
    required this.depth,
  });

  /// Null when the group has no usable transform.
  static GroupFrame? parse(XmlElement? xfrm, GroupFrame? parent, {int? fill}) {
    final own = Placement.parse(xfrm);
    if (own == null) return null;
    final childFrame =
        _rect(child(xfrm, 'chOff'), child(xfrm, 'chExt')) ?? own.frame;
    return GroupFrame._(
      parent: parent,
      frame: own.frame,
      childFrame: childFrame,
      rotation: own.rotation,
      flipH: own.flipH,
      flipV: own.flipV,
      fill: fill,
      depth: (parent?.depth ?? 0) + 1,
    );
  }

  static const maxDepth = 16;

  final GroupFrame? parent;
  final Rect frame;
  final Rect childFrame;
  final double rotation;
  final bool flipH;
  final bool flipV;

  /// What `a:grpFill` means for the shapes inside.
  final int? fill;
  final int depth;

  /// True when this group or one around it turns or mirrors its children,
  /// which is only approximated.
  bool get isApproximate =>
      rotation != 0 || flipH || flipV || (parent?.isApproximate ?? false);

  /// Moves [placement] from the coordinates of the children to the slide,
  /// through every enclosing group.
  void apply(Placement placement) {
    final scaleX = childFrame.width > 0 ? frame.width / childFrame.width : 1.0;
    final scaleY = childFrame.height > 0
        ? frame.height / childFrame.height
        : 1.0;
    final inner = placement.frame;
    var mapped = Rect.fromLTWH(
      frame.left + (inner.left - childFrame.left) * scaleX,
      frame.top + (inner.top - childFrame.top) * scaleY,
      inner.width * scaleX,
      inner.height * scaleY,
    );
    if (flipH || flipV) {
      final center = mapped.center;
      mapped = Rect.fromCenter(
        center: Offset(
          flipH ? 2 * frame.center.dx - center.dx : center.dx,
          flipV ? 2 * frame.center.dy - center.dy : center.dy,
        ),
        width: mapped.width,
        height: mapped.height,
      );
      if (flipH) placement.flipH = !placement.flipH;
      if (flipV) placement.flipV = !placement.flipV;
      if (flipH != flipV) placement.rotation = -placement.rotation % 360;
    }
    if (rotation != 0) {
      mapped = Rect.fromCenter(
        center: _rotate(mapped.center, frame.center, rotation),
        width: mapped.width,
        height: mapped.height,
      );
      placement.rotation = (placement.rotation + rotation) % 360;
    }
    placement.frame = mapped;
    parent?.apply(placement);
  }
}
