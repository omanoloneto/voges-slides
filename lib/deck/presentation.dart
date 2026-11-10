import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show immutable;

import 'element.dart';

/// A widescreen (16:9) slide, in points.
const defaultSlideSize = Size(960, 540);

const _keep = Object();

@immutable
class Slide {
  const Slide({
    required this.id,
    this.background = 0xFFFFFFFF,
    this.backgroundImage,
    this.elements = const [],
  });

  /// Unique in the presentation, among slides and elements alike.
  final int id;

  /// ARGB.
  final int background;

  /// Stretched over the whole slide, above [background].
  final ImageData? backgroundImage;

  /// From back to front.
  final List<SlideElement> elements;

  SlideElement? element(int id) {
    for (final element in elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  Slide copyWith({
    int? id,
    int? background,
    Object? backgroundImage = _keep,
    List<SlideElement>? elements,
  }) => Slide(
    id: id ?? this.id,
    background: background ?? this.background,
    backgroundImage: identical(backgroundImage, _keep)
        ? this.backgroundImage
        : backgroundImage as ImageData?,
    elements: elements ?? this.elements,
  );
}

/// A deck of slides of one size. It always has at least one slide.
@immutable
class Presentation {
  const Presentation({this.size = defaultSlideSize, required this.slides})
    : assert(slides.length > 0);

  /// Width and height of every slide, in points.
  final Size size;

  final List<Slide> slides;

  Presentation copyWith({Size? size, List<Slide>? slides}) =>
      Presentation(size: size ?? this.size, slides: slides ?? this.slides);
}
