import 'package:xml/xml.dart';

import '../../deck/element.dart';
import 'pptx_shapes.dart';
import 'pptx_text.dart';
import 'pptx_theme.dart';
import 'pptx_xml.dart';

/// A `p:ph` of a master or layout: the template slide shapes inherit their
/// place, text styles and looks from.
class Placeholder {
  Placeholder(this.shape, XmlElement ph, this.chain, {this.inherited})
    : type = ph.getAttribute('type') ?? 'obj',
      index = intAttribute(ph, 'idx');

  /// The `p:ph` of [shape], or null when it is not a placeholder.
  static XmlElement? of(XmlElement shape) =>
      descend(shape.firstElementChild, ['nvPr', 'ph']);

  final XmlElement shape;
  final String type;
  final int? index;

  /// Text styles down to this placeholder's own `a:lstStyle`.
  final TextChain chain;

  /// The master placeholder behind a layout placeholder.
  final Placeholder? inherited;

  late final XmlElement? properties = child(shape, 'spPr');
  late final XmlElement? bodyProperties = descend(shape, ['txBody', 'bodyPr']);
  late final Placement? _placement = Placement.parse(child(properties, 'xfrm'));

  /// A fresh copy each time: the caller is free to change it.
  Placement? get placement {
    final own = _placement;
    if (own == null) return inherited?.placement;
    return Placement(own.frame, own.rotation, own.flipH, own.flipV);
  }

  static PlaceholderKind? kindOf(String type) => switch (type) {
    'title' || 'ctrTitle' => PlaceholderKind.title,
    'subTitle' => PlaceholderKind.subtitle,
    'body' || 'obj' => PlaceholderKind.body,
    _ => null,
  };

  /// The master placeholder type a slide or layout type inherits from.
  static String masterType(String type) => switch (type) {
    'title' || 'ctrTitle' => 'title',
    'body' ||
    'subTitle' ||
    'obj' ||
    'pic' ||
    'chart' ||
    'tbl' ||
    'dgm' ||
    'media' ||
    'clipArt' => 'body',
    _ => type,
  };

  /// Footers, dates and slide numbers: left out of a slide when empty.
  static bool isFurniture(String type) =>
      type == 'dt' || type == 'ftr' || type == 'sldNum' || type == 'hdr';
}

/// Finds the placeholders of the shape tree under [root].
List<Placeholder> readPlaceholders(
  XmlElement? root,
  Placeholder Function(XmlElement shape, XmlElement ph) build,
) {
  final tree = descend(root, ['cSld', 'spTree']);
  if (tree == null) return const [];
  final found = <Placeholder>[];
  for (final shape in contentElements(tree)) {
    final name = shape.name.local;
    if (name != 'sp' && name != 'pic') continue;
    final ph = Placeholder.of(shape);
    if (ph != null) found.add(build(shape, ph));
  }
  return found;
}

/// A slide background once resolved.
class Background {
  const Background(this.color, this.image);

  final int? color;
  final ImageData? image;
}

class MasterPart {
  MasterPart({
    required this.path,
    required this.root,
    required this.theme,
    required TextChain defaults,
  }) : colorMap = PptxColors.readMap(child(root, 'clrMap')) {
    final styles = child(root, 'txStyles');
    ListStyle? style(String name) => ListStyle.parse(child(styles, name));
    titleChain = defaults.extend(style('titleStyle'));
    bodyChain = defaults.extend(style('bodyStyle'));
    otherChain = defaults.extend(style('otherStyle'));
    placeholders = readPlaceholders(
      root,
      (shape, ph) => Placeholder(
        shape,
        ph,
        chainFor(
          ph.getAttribute('type') ?? 'obj',
        ).extend(ListStyle.parse(descend(shape, ['txBody', 'lstStyle']))),
      ),
    );
  }

  final String path;
  final XmlElement root;
  final PptxTheme theme;
  final Map<String, String> colorMap;
  late final TextChain titleChain;
  late final TextChain bodyChain;
  late final TextChain otherChain;
  late final List<Placeholder> placeholders;

  /// The `p:txStyles` entry text in a placeholder of [type] starts from.
  TextChain chainFor(String type) => switch (type) {
    'title' || 'ctrTitle' => titleChain,
    'body' || 'subTitle' || 'obj' => bodyChain,
    _ => otherChain,
  };

  Placeholder? placeholder(String type) {
    final wanted = Placeholder.masterType(type);
    for (final placeholder in placeholders) {
      if (placeholder.type == wanted) return placeholder;
    }
    return null;
  }
}

class LayoutPart {
  LayoutPart({required this.path, required this.root, required this.master})
    : showMasterShapes = boolAttribute(root, 'showMasterSp') ?? true,
      colorMapOverride = readColorMapOverride(root) {
    final master = this.master;
    placeholders = readPlaceholders(root, (shape, ph) {
      final type = ph.getAttribute('type') ?? 'obj';
      final inherited = master?.placeholder(type);
      final base = inherited?.chain ?? master?.chainFor(type);
      final style = ListStyle.parse(descend(shape, ['txBody', 'lstStyle']));
      return Placeholder(
        shape,
        ph,
        base?.extend(style) ?? TextChain(null, style),
        inherited: inherited,
      );
    });
  }

  final String path;
  final XmlElement root;
  final MasterPart? master;
  final bool showMasterShapes;
  final Map<String, String>? colorMapOverride;
  late final List<Placeholder> placeholders;

  /// The background slides get from here or from the master, shared like
  /// [decorations].
  bool backgroundRead = false;
  Background? background;

  /// Master and layout decoration with id 0, shared by the slides that
  /// have no color map of their own.
  List<SlideElement>? decorations;

  /// By `idx` when the layout has it, else by type, else by the family the
  /// type belongs to.
  Placeholder? placeholder(String type, int? index) {
    if (index != null) {
      for (final placeholder in placeholders) {
        if (placeholder.index == index) return placeholder;
      }
    }
    for (final placeholder in placeholders) {
      if (placeholder.type == type) return placeholder;
    }
    final family = Placeholder.masterType(type);
    for (final placeholder in placeholders) {
      if (Placeholder.masterType(placeholder.type) == family) {
        return placeholder;
      }
    }
    return null;
  }
}

/// The mapping of a `p:clrMapOvr`, or null when it keeps the master's.
Map<String, String>? readColorMapOverride(XmlElement root) {
  final override = descend(root, ['clrMapOvr', 'overrideClrMapping']);
  return override == null ? null : PptxColors.readMap(override);
}
