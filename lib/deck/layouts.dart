import 'dart:ui' show Rect, Size;

import 'element.dart';
import 'presentation.dart';
import 'text_body.dart';

enum SlideLayout { titleSlide, titleContent, titleOnly, blank }

/// Font and color the placeholders of a new slide take.
class LayoutLook {
  const LayoutLook({
    this.titleFont = defaultFont,
    this.titleColor = 0xFF000000,
    this.bodyFont = defaultFont,
    this.bodyColor = 0xFF000000,
  });

  /// The look of the placeholders [slide] already has.
  factory LayoutLook.of(Slide slide) {
    RunStyle? styleOf(Set<PlaceholderKind> kinds) {
      for (final element in slide.elements) {
        if (element is ShapeElement && kinds.contains(element.placeholder)) {
          return element.text.paragraphs.first.runs.first.style;
        }
      }
      return null;
    }

    final title = styleOf(const {PlaceholderKind.title});
    final body =
        styleOf(const {PlaceholderKind.body}) ??
        styleOf(const {PlaceholderKind.subtitle});
    const standard = LayoutLook();
    return LayoutLook(
      titleFont: title?.font ?? body?.font ?? standard.titleFont,
      titleColor: title?.color ?? body?.color ?? standard.titleColor,
      bodyFont: body?.font ?? title?.font ?? standard.bodyFont,
      bodyColor: body?.color ?? title?.color ?? standard.bodyColor,
    );
  }

  final String titleFont;
  final int titleColor;
  final String bodyFont;
  final int bodyColor;
}

/// The placeholders of [layout] on a slide of [size]. Measures were drawn
/// for a 960 x 540 slide and follow the slide from there.
List<ShapeElement> layoutElements(
  SlideLayout layout,
  Size size,
  int Function() nextId, {
  LayoutLook look = const LayoutLook(),
}) {
  final sx = size.width / 960, sy = size.height / 540;

  ShapeElement placeholder(
    PlaceholderKind kind,
    Rect frame,
    double fontSize, {
    TextAnchor anchor = TextAnchor.top,
    ParagraphAlign align = ParagraphAlign.left,
    BulletKind bullet = BulletKind.none,
    double spaceBefore = 0,
  }) {
    final isTitle = kind == PlaceholderKind.title;
    return ShapeElement(
      id: nextId(),
      frame: Rect.fromLTWH(
        frame.left * sx,
        frame.top * sy,
        frame.width * sx,
        frame.height * sy,
      ),
      placeholder: kind,
      anchor: anchor,
      text: TextBody([
        Paragraph(
          runs: [
            TextRun(
              '',
              RunStyle(
                font: isTitle ? look.titleFont : look.bodyFont,
                size: (fontSize * sy).roundToDouble(),
                color: isTitle ? look.titleColor : look.bodyColor,
              ),
            ),
          ],
          align: align,
          bullet: bullet,
          spaceBefore: spaceBefore * sy,
        ),
      ]),
    );
  }

  ShapeElement heading() => placeholder(
    PlaceholderKind.title,
    const Rect.fromLTWH(66, 28.75, 828, 104.375),
    44,
    anchor: TextAnchor.middle,
  );

  return switch (layout) {
    SlideLayout.titleSlide => [
      placeholder(
        PlaceholderKind.title,
        const Rect.fromLTWH(120, 88.375, 720, 188),
        60,
        anchor: TextAnchor.bottom,
        align: ParagraphAlign.center,
      ),
      placeholder(
        PlaceholderKind.subtitle,
        const Rect.fromLTWH(120, 283.625, 720, 130.375),
        24,
        align: ParagraphAlign.center,
      ),
    ],
    SlideLayout.titleContent => [
      heading(),
      placeholder(
        PlaceholderKind.body,
        const Rect.fromLTWH(66, 143.75, 828, 342.625),
        28,
        bullet: BulletKind.bullet,
        spaceBefore: 10,
      ),
    ],
    SlideLayout.titleOnly => [heading()],
    SlideLayout.blank => const [],
  };
}
