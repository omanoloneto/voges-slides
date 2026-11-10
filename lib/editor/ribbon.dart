import 'package:flutter/material.dart';

import '../deck/deck_controller.dart';
import '../deck/element.dart';
import '../deck/layouts.dart';
import '../deck/text_body.dart';
import '../l10n/l10n.dart';
import '../shell/platform.dart';
import '../shell/ribbon_controls.dart';
import '../shell/ribbon_style.dart';
import 'color_menu_button.dart';

const fontSizes = <double>[
  8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 44, 48, 54, 60, 66, //
  72, 80, 88, 96,
];

const _outlineWidths = [0.5, 1.0, 1.5, 2.25, 3.0, 4.5, 6.0];

/// A size in points without needless decimals: 18, 2.25.
String sizeLabel(double size) =>
    size.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// The next size of the list above (+1) or below (-1) [size].
double steppedSize(double size, int direction) => direction > 0
    ? fontSizes.firstWhere((other) => other > size, orElse: () => size)
    : fontSizes.lastWhere((other) => other < size, orElse: () => size);

/// What the ribbon asks of the screen, which owns the clipboard, the file
/// dialogs and the slideshow.
class RibbonActions {
  const RibbonActions({
    required this.cut,
    required this.copy,
    required this.paste,
    required this.insertImage,
    required this.slideshowFromStart,
    required this.slideshowFromCurrent,
  });

  final VoidCallback cut;
  final VoidCallback copy;
  final VoidCallback paste;
  final VoidCallback insertImage;
  final VoidCallback slideshowFromStart;
  final VoidCallback slideshowFromCurrent;
}

class Ribbon extends StatelessWidget {
  const Ribbon({
    required this.controller,
    required this.fonts,
    required this.actions,
    super.key,
  });

  final DeckController controller;

  /// Installed font families, in the order they are listed.
  final List<String> fonts;

  final RibbonActions actions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = context.l10n;
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          color: RibbonColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RibbonColors.panelBorder),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RibbonGroup(label: l10n.clipboardGroup, child: _clipboard(l10n)),
              const RibbonGroupDivider(),
              RibbonGroup(label: l10n.slidesGroup, child: _slides(l10n)),
              const RibbonGroupDivider(),
              RibbonGroup(label: l10n.insertGroup, child: _insert(l10n)),
              const RibbonGroupDivider(),
              RibbonGroup(label: l10n.fontGroup, child: _font(l10n)),
              const RibbonGroupDivider(),
              RibbonGroup(label: l10n.paragraphGroup, child: _paragraph(l10n)),
              const RibbonGroupDivider(),
              RibbonGroup(label: l10n.shapeGroup, child: _shape(l10n)),
              const RibbonGroupDivider(),
              RibbonGroup(label: l10n.slideshowGroup, child: _slideshow(l10n)),
            ],
          ),
        ),
      );
    },
  );

  Widget _clipboard(AppLocalizations l10n) {
    final any = controller.selection.isNotEmpty;
    return Row(
      children: [
        RibbonBigButton(
          icon: Icons.content_paste,
          label: l10n.paste,
          tooltip: '${l10n.paste} (${shortcutLabel('V')})',
          onPressed: actions.paste,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RibbonIconButton(
              icon: Icons.content_cut,
              tooltip: '${l10n.cut} (${shortcutLabel('X')})',
              onPressed: any ? actions.cut : null,
            ),
            RibbonIconButton(
              icon: Icons.content_copy,
              tooltip: '${l10n.copy} (${shortcutLabel('C')})',
              onPressed: any ? actions.copy : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _slides(AppLocalizations l10n) {
    final layouts = [
      (SlideLayout.titleSlide, Icons.title, l10n.layoutTitleSlide),
      (
        SlideLayout.titleContent,
        Icons.article_outlined,
        l10n.layoutTitleContent,
      ),
      (SlideLayout.titleOnly, Icons.short_text, l10n.layoutTitleOnly),
      (SlideLayout.blank, Icons.crop_landscape, l10n.layoutBlank),
    ];
    return Row(
      children: [
        _BigMenuButton(
          icon: Icons.add_to_photos_outlined,
          label: l10n.newSlide,
          tooltip: '${l10n.newSlide} (${shortcutLabel('N', shift: true)})',
          items: [
            for (final (layout, icon, label) in layouts)
              RibbonMenuItem(icon, label, () => controller.addSlide(layout)),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RibbonIconButton(
                  icon: Icons.control_point_duplicate,
                  tooltip: l10n.duplicateSlide,
                  onPressed: controller.duplicateSlide,
                ),
                RibbonIconButton(
                  icon: Icons.delete_outline,
                  tooltip: l10n.deleteSlide,
                  onPressed: controller.canDeleteSlide
                      ? controller.deleteSlide
                      : null,
                ),
              ],
            ),
            ColorMenuButton(
              icon: Icons.format_paint_outlined,
              tooltip: l10n.slideBackground,
              current: controller.slide.background,
              onPicked: controller.setBackground,
              extra: RibbonMenuItem(
                Icons.library_add_check_outlined,
                l10n.backgroundAllSlides,
                () => controller.setBackground(
                  controller.slide.background,
                  allSlides: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _insert(AppLocalizations l10n) {
    final shapes = [
      (ShapeKind.rectangle, Icons.crop_square, l10n.shapeRectangle),
      (
        ShapeKind.roundedRectangle,
        Icons.rounded_corner,
        l10n.shapeRoundedRectangle,
      ),
      (ShapeKind.ellipse, Icons.circle_outlined, l10n.shapeEllipse),
      (ShapeKind.triangle, Icons.change_history, l10n.shapeTriangle),
      (
        ShapeKind.rightTriangle,
        Icons.signal_cellular_0_bar,
        l10n.shapeRightTriangle,
      ),
      (ShapeKind.diamond, Icons.diamond_outlined, l10n.shapeDiamond),
      (ShapeKind.pentagon, Icons.pentagon_outlined, l10n.shapePentagon),
      (ShapeKind.hexagon, Icons.hexagon_outlined, l10n.shapeHexagon),
      (ShapeKind.star, Icons.star_border, l10n.shapeStar),
      (ShapeKind.rightArrow, Icons.arrow_forward, l10n.shapeRightArrow),
      (ShapeKind.leftArrow, Icons.arrow_back, l10n.shapeLeftArrow),
      (ShapeKind.upArrow, Icons.arrow_upward, l10n.shapeUpArrow),
      (ShapeKind.downArrow, Icons.arrow_downward, l10n.shapeDownArrow),
    ];
    return Row(
      children: [
        RibbonBigButton(
          icon: Icons.text_fields,
          label: l10n.textBox,
          onPressed: controller.addTextBox,
        ),
        RibbonBigButton(
          icon: Icons.image_outlined,
          label: l10n.image,
          onPressed: actions.insertImage,
        ),
        _BigMenuButton(
          icon: Icons.category_outlined,
          label: l10n.shapes,
          items: [
            for (final (kind, icon, label) in shapes)
              RibbonMenuItem(icon, label, () => controller.addShape(kind)),
            RibbonMenuItem(
              Icons.horizontal_rule,
              l10n.shapeLine,
              () => controller.addShape(ShapeKind.line),
            ),
            RibbonMenuItem(
              Icons.trending_flat,
              l10n.shapeArrowLine,
              () => controller.addShape(ShapeKind.line, arrow: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _font(AppLocalizations l10n) {
    final style = controller.currentStyle;
    final enabled = style != null;

    Widget toggle(
      IconData icon,
      String tooltip,
      bool Function(RunStyle style) isOn,
      RunStyle Function(RunStyle style, bool on) set,
    ) {
      final on = enabled && controller.everyStyle(isOn);
      return RibbonIconButton(
        icon: icon,
        tooltip: tooltip,
        selected: on,
        onPressed: enabled
            ? () => controller.formatText((style) => set(style, !on))
            : null,
      );
    }

    void step(int direction) => controller.formatText(
      (style) => style.copyWith(size: steppedSize(style.size, direction)),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RibbonDropdown<String>(
              tooltip: l10n.fontFamily,
              label: style?.font ?? '',
              width: 150,
              options: [for (final font in fonts) RibbonOption(font, font)],
              selected: style?.font,
              onSelected: (font) =>
                  controller.formatText((style) => style.copyWith(font: font)),
            ),
            const SizedBox(width: 4),
            RibbonDropdown<double>(
              tooltip: l10n.fontSize,
              label: style == null ? '' : sizeLabel(style.size),
              width: 62,
              options: [
                for (final size in fontSizes)
                  RibbonOption(size, sizeLabel(size)),
              ],
              selected: style?.size,
              onSelected: (size) =>
                  controller.formatText((style) => style.copyWith(size: size)),
            ),
            RibbonIconButton(
              icon: Icons.text_increase,
              tooltip: l10n.growFont,
              onPressed: enabled ? () => step(1) : null,
            ),
            RibbonIconButton(
              icon: Icons.text_decrease,
              tooltip: l10n.shrinkFont,
              onPressed: enabled ? () => step(-1) : null,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            toggle(
              Icons.format_bold,
              '${l10n.bold} (${shortcutLabel('B')})',
              (style) => style.bold,
              (style, on) => style.copyWith(bold: on),
            ),
            toggle(
              Icons.format_italic,
              '${l10n.italic} (${shortcutLabel('I')})',
              (style) => style.italic,
              (style, on) => style.copyWith(italic: on),
            ),
            toggle(
              Icons.format_underlined,
              '${l10n.underline} (${shortcutLabel('U')})',
              (style) => style.underline,
              (style, on) => style.copyWith(underline: on),
            ),
            toggle(
              Icons.format_strikethrough,
              l10n.strikethrough,
              (style) => style.strike,
              (style, on) => style.copyWith(strike: on),
            ),
            ColorMenuButton(
              icon: Icons.format_color_text,
              tooltip: l10n.textColor,
              current: style?.color,
              enabled: enabled,
              onPicked: (color) => controller.formatText(
                (style) => style.copyWith(color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _paragraph(AppLocalizations l10n) {
    final enabled = controller.currentParagraph != null;

    Widget align(IconData icon, String tooltip, ParagraphAlign value) =>
        RibbonIconButton(
          icon: icon,
          tooltip: tooltip,
          selected:
              enabled &&
              controller.everyParagraph(
                (paragraph) => paragraph.align == value,
              ),
          onPressed: enabled
              ? () => controller.formatParagraphs(
                  (paragraph) => paragraph.copyWith(align: value),
                )
              : null,
        );

    Widget list(IconData icon, String tooltip, BulletKind value) {
      final on =
          enabled &&
          controller.everyParagraph((paragraph) => paragraph.bullet == value);
      return RibbonIconButton(
        icon: icon,
        tooltip: tooltip,
        selected: on,
        onPressed: enabled
            ? () => controller.formatParagraphs(
                (paragraph) =>
                    paragraph.copyWith(bullet: on ? BulletKind.none : value),
              )
            : null,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            align(Icons.format_align_left, l10n.alignLeft, ParagraphAlign.left),
            align(
              Icons.format_align_center,
              l10n.alignCenter,
              ParagraphAlign.center,
            ),
            align(
              Icons.format_align_right,
              l10n.alignRight,
              ParagraphAlign.right,
            ),
            align(
              Icons.format_align_justify,
              l10n.justify,
              ParagraphAlign.justify,
            ),
            RibbonMenuIconButton(
              icon: Icons.vertical_align_center,
              tooltip: l10n.textPosition,
              items: [
                RibbonMenuItem(
                  Icons.vertical_align_top,
                  l10n.alignTop,
                  () => controller.setAnchor(TextAnchor.top),
                ),
                RibbonMenuItem(
                  Icons.vertical_align_center,
                  l10n.alignMiddle,
                  () => controller.setAnchor(TextAnchor.middle),
                ),
                RibbonMenuItem(
                  Icons.vertical_align_bottom,
                  l10n.alignBottom,
                  () => controller.setAnchor(TextAnchor.bottom),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            list(Icons.format_list_bulleted, l10n.bullets, BulletKind.bullet),
            list(Icons.format_list_numbered, l10n.numbering, BulletKind.number),
            RibbonIconButton(
              icon: Icons.format_indent_decrease,
              tooltip: l10n.decreaseIndent,
              onPressed: enabled ? () => controller.changeLevel(-1) : null,
            ),
            RibbonIconButton(
              icon: Icons.format_indent_increase,
              tooltip: l10n.increaseIndent,
              onPressed: enabled ? () => controller.changeLevel(1) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _shape(AppLocalizations l10n) {
    final shape = controller.firstShape;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ColorMenuButton(
              icon: Icons.format_color_fill,
              tooltip: l10n.fillColor,
              current: shape?.fill,
              enabled: shape != null && !shape.isLine,
              onPicked: controller.setFill,
              extra: RibbonMenuItem(
                Icons.format_color_reset_outlined,
                l10n.noFill,
                () => controller.setFill(null),
              ),
            ),
            ColorMenuButton(
              icon: Icons.border_color_outlined,
              tooltip: l10n.outlineColor,
              current: shape?.stroke,
              enabled: shape != null,
              onPicked: controller.setStroke,
              extra: RibbonMenuItem(
                Icons.border_clear,
                l10n.noOutline,
                () => controller.setStroke(null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            RibbonMenuIconButton(
              icon: Icons.line_weight,
              tooltip: l10n.outlineWidth,
              items: [
                for (final width in _outlineWidths)
                  RibbonMenuItem(
                    Icons.horizontal_rule,
                    l10n.points(sizeLabel(width)),
                    () => controller.setStrokeWidth(width),
                  ),
              ],
            ),
            RibbonMenuIconButton(
              icon: Icons.layers_outlined,
              tooltip: l10n.arrange,
              items: [
                RibbonMenuItem(
                  Icons.flip_to_front,
                  l10n.bringToFront,
                  () => controller.arrange(Arrange.front),
                ),
                RibbonMenuItem(
                  Icons.flip_to_back,
                  l10n.sendToBack,
                  () => controller.arrange(Arrange.back),
                ),
                RibbonMenuItem(
                  Icons.arrow_upward,
                  l10n.bringForward,
                  () => controller.arrange(Arrange.forward),
                ),
                RibbonMenuItem(
                  Icons.arrow_downward,
                  l10n.sendBackward,
                  () => controller.arrange(Arrange.backward),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _slideshow(AppLocalizations l10n) => Row(
    children: [
      RibbonBigButton(
        icon: Icons.slideshow,
        label: l10n.slideshowFromStart,
        tooltip: '${l10n.slideshowFromStart} (F5)',
        onPressed: actions.slideshowFromStart,
      ),
      RibbonIconButton(
        icon: Icons.play_circle_outline,
        tooltip:
            '${l10n.slideshowFromCurrent} (${isApplePlatform ? '⇧F5' : 'Shift+F5'})',
        onPressed: actions.slideshowFromCurrent,
      ),
    ],
  );
}

class _BigMenuButton extends StatelessWidget {
  const _BigMenuButton({
    required this.icon,
    required this.label,
    required this.items,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final List<RibbonMenuItem> items;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: ribbonMenuStyle(),
    menuChildren: [
      for (final item in items)
        MenuItemButton(
          style: ribbonMenuItemStyle(),
          leadingIcon: Icon(item.icon, size: 18),
          onPressed: item.onPressed,
          child: Text(item.label),
        ),
    ],
    builder: (context, menu, _) => RibbonBigButton(
      icon: icon,
      label: label,
      tooltip: tooltip,
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
    ),
  );
}
