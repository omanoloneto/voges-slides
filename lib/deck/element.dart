import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart' show immutable;

import 'text_body.dart';

enum ShapeKind {
  rectangle,
  roundedRectangle,
  ellipse,
  triangle,
  rightTriangle,
  diamond,
  pentagon,
  hexagon,
  star,
  rightArrow,
  leftArrow,
  upArrow,
  downArrow,
  line,
}

/// Where the text sits in the height of its shape.
enum TextAnchor { top, middle, bottom }

/// The role a shape plays in the layout of its slide.
enum PlaceholderKind { title, subtitle, body }

/// The bytes of a picture exactly as they came, shared by every element and
/// slide that shows it. Compared by identity.
class ImageData {
  ImageData(this.bytes, this.extension);

  final Uint8List bytes;

  /// Lowercase file extension without the dot: `png`, `jpeg`, `gif`, `bmp`,
  /// `webp`, `tiff`, `emf`, `wmf`, `svg`…
  final String extension;

  static const _decodable = {'png', 'jpeg', 'jpg', 'gif', 'bmp', 'webp'};

  /// False for formats the app cannot draw; those show a placeholder and
  /// are saved back untouched.
  bool get decodable => _decodable.contains(extension);
}

/// Space between the frame of a shape and its text, in points.
@immutable
class TextInsets {
  const TextInsets({
    this.left = 7.2,
    this.top = 3.6,
    this.right = 7.2,
    this.bottom = 3.6,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get horizontal => left + right;
  double get vertical => top + bottom;

  @override
  bool operator ==(Object other) =>
      other is TextInsets &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// Something placed on a slide. Geometry is in points from the top left
/// corner of the slide.
@immutable
sealed class SlideElement {
  const SlideElement({
    required this.id,
    required this.frame,
    this.rotation = 0,
    this.locked = false,
  });

  /// Unique in the presentation.
  final int id;

  /// The box before rotation.
  final Rect frame;

  /// Degrees clockwise around the center of [frame].
  final double rotation;

  /// Decoration that came from the master or layout of an imported slide:
  /// drawn, but not selectable until unlocked.
  final bool locked;

  SlideElement withGeometry({Rect? frame, double? rotation});

  SlideElement withId(int id);

  SlideElement withLocked(bool locked);
}

const _keep = Object();

class ShapeElement extends SlideElement {
  const ShapeElement({
    required super.id,
    required super.frame,
    super.rotation,
    super.locked,
    this.kind = ShapeKind.rectangle,
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
    this.flipH = false,
    this.flipV = false,
    this.startArrow = false,
    this.endArrow = false,
    required this.text,
    this.anchor = TextAnchor.top,
    this.insets = const TextInsets(),
    this.placeholder,
    this.autoFit = false,
  });

  final ShapeKind kind;

  /// ARGB; null draws no fill.
  final int? fill;

  /// ARGB; null draws no outline.
  final int? stroke;

  /// Outline width in points.
  final double strokeWidth;

  final bool flipH;
  final bool flipV;

  /// Arrow heads, only drawn on [ShapeKind.line].
  final bool startArrow;
  final bool endArrow;

  final TextBody text;
  final TextAnchor anchor;
  final TextInsets insets;
  final PlaceholderKind? placeholder;

  /// The height follows the text, as in a text box.
  final bool autoFit;

  bool get isLine => kind == ShapeKind.line;

  /// A line runs between two opposite corners of its frame; the flips say
  /// which ones. Lines are never rotated.
  Offset get lineStart => Offset(
    flipH ? frame.right : frame.left,
    flipV ? frame.bottom : frame.top,
  );

  Offset get lineEnd => Offset(
    flipH ? frame.left : frame.right,
    flipV ? frame.top : frame.bottom,
  );

  ShapeElement copyWith({
    Rect? frame,
    double? rotation,
    bool? locked,
    ShapeKind? kind,
    Object? fill = _keep,
    Object? stroke = _keep,
    double? strokeWidth,
    bool? flipH,
    bool? flipV,
    bool? startArrow,
    bool? endArrow,
    TextBody? text,
    TextAnchor? anchor,
    TextInsets? insets,
    Object? placeholder = _keep,
    bool? autoFit,
    int? id,
  }) => ShapeElement(
    id: id ?? this.id,
    frame: frame ?? this.frame,
    rotation: rotation ?? this.rotation,
    locked: locked ?? this.locked,
    kind: kind ?? this.kind,
    fill: identical(fill, _keep) ? this.fill : fill as int?,
    stroke: identical(stroke, _keep) ? this.stroke : stroke as int?,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    flipH: flipH ?? this.flipH,
    flipV: flipV ?? this.flipV,
    startArrow: startArrow ?? this.startArrow,
    endArrow: endArrow ?? this.endArrow,
    text: text ?? this.text,
    anchor: anchor ?? this.anchor,
    insets: insets ?? this.insets,
    placeholder: identical(placeholder, _keep)
        ? this.placeholder
        : placeholder as PlaceholderKind?,
    autoFit: autoFit ?? this.autoFit,
  );

  @override
  ShapeElement withGeometry({Rect? frame, double? rotation}) =>
      copyWith(frame: frame, rotation: rotation);

  @override
  ShapeElement withId(int id) => copyWith(id: id);

  @override
  ShapeElement withLocked(bool locked) => copyWith(locked: locked);
}

class ImageElement extends SlideElement {
  const ImageElement({
    required super.id,
    required super.frame,
    super.rotation,
    super.locked,
    required this.image,
    this.crop = Rect.zero,
  });

  final ImageData image;

  /// Fraction of the picture cut from each side (left, top, right, bottom),
  /// each from 0 to 1.
  final Rect crop;

  ImageElement copyWith({
    Rect? frame,
    double? rotation,
    bool? locked,
    ImageData? image,
    Rect? crop,
    int? id,
  }) => ImageElement(
    id: id ?? this.id,
    frame: frame ?? this.frame,
    rotation: rotation ?? this.rotation,
    locked: locked ?? this.locked,
    image: image ?? this.image,
    crop: crop ?? this.crop,
  );

  @override
  ImageElement withGeometry({Rect? frame, double? rotation}) =>
      copyWith(frame: frame, rotation: rotation);

  @override
  ImageElement withId(int id) => copyWith(id: id);

  @override
  ImageElement withLocked(bool locked) => copyWith(locked: locked);
}
