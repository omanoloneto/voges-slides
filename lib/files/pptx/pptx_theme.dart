import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../../deck/text_body.dart';
import 'pptx_xml.dart';

/// What the reader needs from `ppt/theme/themeN.xml`.
class PptxTheme {
  const PptxTheme({
    this.colors = _officeColors,
    this.majorFont = defaultFont,
    this.minorFont = defaultFont,
    this.lineWidths = const [],
  });

  /// A missing or broken theme part falls back to the Office defaults.
  factory PptxTheme.parse(XmlElement? root) {
    final elements = child(root, 'themeElements');
    if (elements == null) return const PptxTheme();
    final colors = {..._officeColors};
    final scheme = child(elements, 'clrScheme');
    if (scheme != null) {
      for (final slot in scheme.childElements) {
        final color = slot.firstElementChild;
        final hex = color?.getAttribute(
          color.name.local == 'sysClr' ? 'lastClr' : 'val',
        );
        final rgb = hex == null ? null : int.tryParse(hex, radix: 16);
        if (rgb != null) colors[slot.name.local] = rgb & 0xFFFFFF;
      }
    }
    final fonts = child(elements, 'fontScheme');
    String latin(String name) =>
        descend(fonts, [name, 'latin'])?.getAttribute('typeface') ?? '';
    final major = latin('majorFont');
    final minor = latin('minorFont');
    final lines = descend(elements, ['fmtScheme', 'lnStyleLst']);
    return PptxTheme(
      colors: colors,
      majorFont: major.isEmpty ? defaultFont : major,
      minorFont: minor.isEmpty ? defaultFont : minor,
      lineWidths: [
        if (lines != null)
          for (final line in children(lines, 'ln'))
            pointsAttribute(line, 'w') ?? defaultLineWidth,
      ],
    );
  }

  /// RGB by scheme slot: `dk1`, `lt1`, `dk2`, `lt2`, `accent1`…`accent6`,
  /// `hlink`, `folHlink`.
  final Map<String, int> colors;
  final String majorFont;
  final String minorFont;

  /// Widths in points of the outlines `a:lnRef idx` picks, first is idx 1.
  final List<double> lineWidths;

  static const defaultLineWidth = 0.75;

  static const _officeColors = {
    'dk1': 0x000000,
    'lt1': 0xFFFFFF,
    'dk2': 0x44546A,
    'lt2': 0xE7E6E6,
    'accent1': 0x4472C4,
    'accent2': 0xED7D31,
    'accent3': 0xA5A5A5,
    'accent4': 0xFFC000,
    'accent5': 0x5B9BD5,
    'accent6': 0x70AD47,
    'hlink': 0x0563C1,
    'folHlink': 0x954F72,
  };

  /// The font a `typeface` names: `+mj-lt` and `+mn-lt` are the heading and
  /// body fonts of the theme, and text that names none uses the body font.
  String font(String? typeface) {
    if (typeface == null || typeface.isEmpty) return minorFont;
    if (typeface.startsWith('+mj')) return majorFont;
    if (typeface.startsWith('+mn')) return minorFont;
    return typeface;
  }

  double lineWidth(int index) => index >= 1 && index <= lineWidths.length
      ? lineWidths[index - 1]
      : defaultLineWidth;
}

/// A fill read from a shape: [color] null draws nothing. [approximate] says
/// the file had something richer than one flat color.
class FillChoice {
  const FillChoice(this.color, {this.approximate = false});

  final int? color;
  final bool approximate;
}

/// Turns DrawingML colors into ARGB, through the theme and the color map of
/// the slide being read.
class PptxColors {
  const PptxColors(this.theme, [this.map = const {}]);

  final PptxTheme theme;

  /// `p:clrMap`: which theme slot `bg1`, `tx1`, `bg2`, `tx2`… stand for.
  final Map<String, String> map;

  static const _defaultMap = {
    'bg1': 'lt1',
    'tx1': 'dk1',
    'bg2': 'lt2',
    'tx2': 'dk2',
  };

  static const _colorElements = {
    'srgbClr',
    'schemeClr',
    'sysClr',
    'prstClr',
    'scrgbClr',
    'hslClr',
  };

  /// The attributes of a `p:clrMap` or `a:overrideClrMapping`.
  static Map<String, String> readMap(XmlElement? element) => {
    if (element != null)
      for (final attribute in element.attributes)
        if (attribute.name.prefix == null)
          attribute.name.local: attribute.value,
  };

  /// The color [holder] carries as a child (`a:solidFill`, `a:fontRef`,
  /// `a:gs`…), or null when it has none. [placeholder] is what `phClr`
  /// stands for.
  int? colorIn(XmlElement? holder, {int? placeholder}) {
    if (holder == null) return null;
    for (final element in holder.childElements) {
      if (_colorElements.contains(element.name.local)) {
        return _color(element, placeholder);
      }
    }
    return null;
  }

  /// The fill among the children of [properties] (`p:spPr`, `a:ln`,
  /// `p:bgPr`, `a:rPr`…), or null when it names none.
  FillChoice? fillIn(XmlElement? properties, {int? groupFill}) {
    if (properties == null) return null;
    for (final element in properties.childElements) {
      switch (element.name.local) {
        case 'noFill':
          return const FillChoice(null);
        case 'solidFill':
          return FillChoice(colorIn(element));
        case 'gradFill':
          final stop = descend(element, ['gsLst', 'gs']);
          return FillChoice(colorIn(stop), approximate: true);
        case 'pattFill':
          return FillChoice(
            colorIn(child(element, 'fgClr')),
            approximate: true,
          );
        case 'blipFill':
          return const FillChoice(null, approximate: true);
        case 'grpFill':
          return FillChoice(groupFill);
      }
    }
    return null;
  }

  int? _color(XmlElement element, int? placeholder) {
    final int? base;
    switch (element.name.local) {
      case 'srgbClr':
        base = _hex(element.getAttribute('val'));
      case 'sysClr':
        base =
            _hex(element.getAttribute('lastClr')) ??
            (element.getAttribute('val') == 'window' ? 0xFFFFFF : 0x000000);
      case 'schemeClr':
        final name = element.getAttribute('val') ?? '';
        if (name == 'phClr') {
          base = placeholder;
        } else {
          final slot = map[name] ?? _defaultMap[name] ?? name;
          base = theme.colors[slot];
        }
      case 'prstClr':
        base = _presetColors[element.getAttribute('val')];
      case 'scrgbClr':
        base = _rgb(
          _linearToSrgb(fractionAttribute(element, 'r') ?? 0),
          _linearToSrgb(fractionAttribute(element, 'g') ?? 0),
          _linearToSrgb(fractionAttribute(element, 'b') ?? 0),
        );
      case 'hslClr':
        base = _hslToRgb(
          (intAttribute(element, 'hue') ?? 0) / 60000 / 360,
          fractionAttribute(element, 'sat') ?? 0,
          fractionAttribute(element, 'lum') ?? 0,
        );
      default:
        base = null;
    }
    if (base == null) return null;
    return _transform(base, element);
  }

  static int? _hex(String? value) {
    if (value == null) return null;
    final rgb = int.tryParse(value.trim(), radix: 16);
    return rgb == null ? null : rgb & 0xFFFFFF;
  }

  /// Applies the transforms listed under a color, in the order they come.
  static int _transform(int color, XmlElement element) {
    if (element.firstElementChild == null) {
      return 0xFF000000 | (color & 0xFFFFFF);
    }
    var alpha = 1.0;
    var r = ((color >> 16) & 0xFF) / 255;
    var g = ((color >> 8) & 0xFF) / 255;
    var b = (color & 0xFF) / 255;
    void viaHsl(List<double> Function(List<double> hsl) change) {
      final rgb = _hslToUnitRgb(change(_rgbToHsl(r, g, b)));
      r = rgb[0];
      g = rgb[1];
      b = rgb[2];
    }

    for (final transform in element.childElements) {
      final value = fractionAttribute(transform, 'val');
      if (value == null) continue;
      switch (transform.name.local) {
        case 'lumMod':
          viaHsl((hsl) => [hsl[0], hsl[1], hsl[2] * value]);
        case 'lumOff':
          viaHsl((hsl) => [hsl[0], hsl[1], hsl[2] + value]);
        case 'satMod':
          viaHsl((hsl) => [hsl[0], hsl[1] * value, hsl[2]]);
        case 'satOff':
          viaHsl((hsl) => [hsl[0], hsl[1] + value, hsl[2]]);
        case 'tint':
          r = 1 - (1 - r) * value;
          g = 1 - (1 - g) * value;
          b = 1 - (1 - b) * value;
        case 'shade':
          r *= value;
          g *= value;
          b *= value;
        case 'alpha':
          alpha = value;
        case 'alphaMod':
          alpha *= value;
        case 'alphaOff':
          alpha += value;
      }
    }
    return (_byte(alpha) << 24) | _rgb(r, g, b);
  }

  static int _byte(double unit) => (unit.clamp(0.0, 1.0) * 255).round();

  static int _rgb(double r, double g, double b) =>
      (_byte(r) << 16) | (_byte(g) << 8) | _byte(b);

  static double _linearToSrgb(double linear) {
    final value = linear.clamp(0.0, 1.0);
    return value <= 0.0031308
        ? value * 12.92
        : 1.055 * math.pow(value, 1 / 2.4) - 0.055;
  }

  static List<double> _rgbToHsl(double r, double g, double b) {
    final high = math.max(r, math.max(g, b));
    final low = math.min(r, math.min(g, b));
    final light = (high + low) / 2;
    final delta = high - low;
    if (delta == 0) return [0, 0, light];
    final saturation = delta / (1 - (2 * light - 1).abs());
    double hue;
    if (high == r) {
      hue = ((g - b) / delta) % 6;
    } else if (high == g) {
      hue = (b - r) / delta + 2;
    } else {
      hue = (r - g) / delta + 4;
    }
    return [hue / 6, saturation, light];
  }

  static List<double> _hslToUnitRgb(List<double> hsl) {
    final hue = hsl[0] % 1.0;
    final saturation = hsl[1].clamp(0.0, 1.0);
    final light = hsl[2].clamp(0.0, 1.0);
    final chroma = (1 - (2 * light - 1).abs()) * saturation;
    final sector = hue * 6;
    final x = chroma * (1 - (sector % 2 - 1).abs());
    final m = light - chroma / 2;
    final List<double> rgb = switch (sector.floor()) {
      0 => [chroma, x, 0],
      1 => [x, chroma, 0],
      2 => [0, chroma, x],
      3 => [0, x, chroma],
      4 => [x, 0, chroma],
      _ => [chroma, 0, x],
    };
    return [rgb[0] + m, rgb[1] + m, rgb[2] + m];
  }

  static int _hslToRgb(double hue, double saturation, double light) {
    final rgb = _hslToUnitRgb([hue, saturation, light]);
    return _rgb(rgb[0], rgb[1], rgb[2]);
  }

  static const _presetColors = {
    'black': 0x000000,
    'white': 0xFFFFFF,
    'red': 0xFF0000,
    'green': 0x008000,
    'lime': 0x00FF00,
    'blue': 0x0000FF,
    'yellow': 0xFFFF00,
    'cyan': 0x00FFFF,
    'aqua': 0x00FFFF,
    'magenta': 0xFF00FF,
    'fuchsia': 0xFF00FF,
    'gray': 0x808080,
    'grey': 0x808080,
    'silver': 0xC0C0C0,
    'ltGray': 0xD3D3D3,
    'ltGrey': 0xD3D3D3,
    'dkGray': 0xA9A9A9,
    'dkGrey': 0xA9A9A9,
    'orange': 0xFFA500,
    'purple': 0x800080,
    'pink': 0xFFC0CB,
    'brown': 0xA52A2A,
    'navy': 0x000080,
    'teal': 0x008080,
    'maroon': 0x800000,
    'olive': 0x808000,
    'gold': 0xFFD700,
    'dkBlue': 0x00008B,
    'dkGreen': 0x006400,
    'dkRed': 0x8B0000,
    'ltBlue': 0xADD8E6,
    'ltGreen': 0x90EE90,
    'ltYellow': 0xFFFFE0,
  };
}
