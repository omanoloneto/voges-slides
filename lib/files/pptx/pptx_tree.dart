import 'dart:ui' show Rect;

import 'package:xml/xml.dart';

import '../../deck/element.dart';
import '../../deck/text_body.dart';
import 'opc_package.dart';
import 'pptx_import.dart';
import 'pptx_parts.dart';
import 'pptx_shapes.dart';
import 'pptx_text.dart';
import 'pptx_theme.dart';
import 'pptx_xml.dart';

/// What is shared by everything read from one file.
class ImportSession {
  ImportSession(this.package);

  final OpcPackage package;
  final losses = <ImportLoss>{};

  var _lastId = 0;
  final _images = <String, ImageData?>{};
  final _relationships = <String, Map<String, Relationship>>{};

  int nextId() => ++_lastId;

  /// The relationships of a part by id. Broken ones count as none, so the
  /// part is still read without what it pointed to.
  Map<String, Relationship> relationships(String partPath) =>
      _relationships[partPath] ??= _readRelationships(partPath);

  Map<String, Relationship> _readRelationships(String partPath) {
    try {
      return {
        for (final relationship in package.relationships(partPath))
          relationship.id: relationship,
      };
    } on FormatException {
      return const {};
    }
  }

  /// The part of the first relationship of [partPath] with a type ending
  /// in [typeSuffix].
  String? related(String partPath, String typeSuffix) {
    for (final relationship in relationships(partPath).values) {
      if (!relationship.hasType(typeSuffix)) continue;
      final target = package.targetOf(partPath, relationship);
      if (target != null) return target;
    }
    return null;
  }

  /// One [ImageData] per media part, however many times it is shown. Null
  /// for linked pictures and for parts that are missing or damaged.
  ImageData? image(String partPath, String? relationshipId) {
    final relationship = relationships(partPath)[relationshipId];
    if (relationship == null) return null;
    final path = package.targetOf(partPath, relationship);
    if (path == null) return null;
    if (_images.containsKey(path)) return _images[path];
    final bytes = package.bytes(path);
    final name = path.substring(path.lastIndexOf('/') + 1);
    final dot = name.lastIndexOf('.');
    return _images[path] = bytes == null || bytes.isEmpty
        ? null
        : ImageData(
            bytes,
            dot < 0 ? '' : name.substring(dot + 1).toLowerCase(),
          );
  }
}

/// Reads the shape tree of one part (a slide, or a layout or master whose
/// decoration is copied onto slides) into elements.
class TreeReader {
  TreeReader(
    this.session, {
    required this.partPath,
    required this.colors,
    required this.text,
    required this.defaults,
    this.master,
    this.layout,
    this.decoration = false,
  });

  final ImportSession session;
  final String partPath;
  final PptxColors colors;
  final TextReader text;

  /// Text styles of a part that has no master to give them.
  final TextChain defaults;
  final MasterPart? master;
  final LayoutPart? layout;

  /// Placeholders are templates there, not content: only the rest is read,
  /// with id 0, for the slides to copy.
  final bool decoration;

  static const _mediaMarkers = {
    'videoFile',
    'audioFile',
    'audioCd',
    'wavAudioFile',
    'quickTimeFile',
  };

  static const _autofits = {'normAutofit', 'spAutoFit', 'noAutofit'};

  List<SlideElement> read(XmlElement root) {
    final elements = <SlideElement>[];
    final tree = descend(root, ['cSld', 'spTree']);
    if (tree != null) _tree(tree, null, elements);
    return elements;
  }

  void _tree(XmlElement container, GroupFrame? group, List<SlideElement> out) {
    for (final element in contentElements(container)) {
      final name = element.name.local;
      if (name == 'nvGrpSpPr' || name == 'grpSpPr' || name == 'extLst') {
        continue;
      }
      if (_hidden(element)) continue;
      switch (name) {
        case 'sp':
          _shape(element, group, out, connector: false);
        case 'cxnSp':
          _shape(element, group, out, connector: true);
        case 'pic':
          _picture(element, group, out);
        case 'grpSp':
          _group(element, group, out);
        default:
          session.losses.add(ImportLoss.content);
      }
    }
  }

  static bool _hidden(XmlElement element) =>
      boolAttribute(child(element.firstElementChild, 'cNvPr'), 'hidden') ??
      false;

  int _newId() => decoration ? 0 : session.nextId();

  void _group(XmlElement group, GroupFrame? parent, List<SlideElement> out) {
    if ((parent?.depth ?? 0) >= GroupFrame.maxDepth) {
      session.losses.add(ImportLoss.content);
      return;
    }
    final properties = child(group, 'grpSpPr');
    final frame = GroupFrame.parse(
      child(properties, 'xfrm'),
      parent,
      fill: colors.fillIn(properties, groupFill: parent?.fill)?.color,
    );
    if (frame != null && (frame.rotation != 0 || frame.flipH || frame.flipV)) {
      session.losses.add(ImportLoss.shapes);
    }
    _tree(group, frame ?? parent, out);
  }

  Placement? _place(XmlElement? properties, GroupFrame? group) {
    final placement = Placement.parse(child(properties, 'xfrm'));
    if (placement != null) group?.apply(placement);
    return placement;
  }

  void _shape(
    XmlElement shape,
    GroupFrame? group,
    List<SlideElement> out, {
    required bool connector,
  }) {
    final ph = Placeholder.of(shape);
    if (ph != null && decoration) return;
    final type = ph == null ? null : ph.getAttribute('type') ?? 'obj';
    final layoutPh = type == null
        ? null
        : layout?.placeholder(type, intAttribute(ph, 'idx'));
    final masterPh = type == null
        ? null
        : layoutPh?.inherited ?? master?.placeholder(type);

    final properties = child(shape, 'spPr');
    final placement =
        _place(properties, group) ?? layoutPh?.placement ?? masterPh?.placement;
    if (placement == null || !placement.isValid) return;
    final txBody = child(shape, 'txBody');
    if (type != null && Placeholder.isFurniture(type) && !_hasText(txBody)) {
      return;
    }

    final geometry = shapeKind(properties);
    if (!geometry.exact) session.losses.add(ImportLoss.shapes);
    final isLine = connector || geometry.kind == ShapeKind.line;
    final style = child(shape, 'style');
    final inherited = [layoutPh?.properties, masterPh?.properties];
    final outline = _outline(properties, style, inherited);

    if (isLine) {
      placement.bakeLineRotation();
      final ends = child(properties, 'ln');
      out.add(
        ShapeElement(
          id: _newId(),
          frame: placement.frame,
          locked: decoration,
          kind: ShapeKind.line,
          stroke: outline.color,
          strokeWidth: outline.width,
          flipH: placement.flipH,
          flipV: placement.flipV,
          startArrow: _hasArrow(child(ends, 'headEnd')),
          endArrow: _hasArrow(child(ends, 'tailEnd')),
          text: TextBody.empty(),
        ),
      );
      return;
    }

    var chain =
        layoutPh?.chain ??
        masterPh?.chain ??
        (type == null ? master?.otherChain : master?.chainFor(type)) ??
        defaults;
    final fontRef = child(style, 'fontRef');
    if (fontRef != null) {
      chain = chain.extend(ListStyle.uniform(_fontReference(fontRef)));
    }
    final body = _BodyProperties([
      child(txBody, 'bodyPr'),
      layoutPh?.bodyProperties,
      masterPh?.bodyProperties,
    ]);
    if (body.isVertical) session.losses.add(ImportLoss.shapes);

    out.add(
      ShapeElement(
        id: _newId(),
        frame: placement.frame,
        rotation: placement.rotation,
        locked: decoration,
        kind: geometry.kind,
        fill: _fill(properties, style, inherited, group),
        stroke: outline.color,
        strokeWidth: outline.width,
        flipH: placement.flipH,
        flipV: placement.flipV,
        text: txBody == null
            ? text.empty(chain)
            : text.read(txBody, chain, shrink: body.shrink),
        anchor: body.anchor,
        insets: body.insets,
        placeholder: type == null ? null : Placeholder.kindOf(type),
        autoFit: body.autoFit,
      ),
    );
  }

  static bool _hasText(XmlElement? txBody) =>
      txBody != null &&
      txBody.descendantElements.any(
        (element) =>
            element.name.local == 't' && element.innerText.trim().isNotEmpty,
      );

  static bool _hasArrow(XmlElement? end) {
    final type = end?.getAttribute('type');
    return type != null && type != 'none';
  }

  static RunProps _fontReference(XmlElement fontRef) {
    final props = RunProps()
      ..font = switch (fontRef.getAttribute('idx')) {
        'major' => '+mj-lt',
        'minor' => '+mn-lt',
        _ => null,
      };
    if (fontRef.firstElementChild != null) props.fill = fontRef;
    return props;
  }

  int? _fill(
    XmlElement? properties,
    XmlElement? style,
    List<XmlElement?> inherited,
    GroupFrame? group,
  ) {
    var fill = colors.fillIn(properties, groupFill: group?.fill);
    final reference = child(style, 'fillRef');
    if (fill == null && reference != null) {
      fill = (intAttribute(reference, 'idx') ?? 0) == 0
          ? const FillChoice(null)
          : FillChoice(colors.colorIn(reference));
    }
    for (final other in inherited) {
      fill ??= colors.fillIn(other);
    }
    if (fill != null && fill.approximate) {
      session.losses.add(ImportLoss.shapes);
    }
    return fill?.color;
  }

  /// The first source that names a color (or none) decides the color, and
  /// the first that names a width decides the width.
  ({int? color, double width}) _outline(
    XmlElement? properties,
    XmlElement? style,
    List<XmlElement?> inherited,
  ) {
    FillChoice? choice;
    double? width;
    void take(XmlElement? line) {
      if (line == null) return;
      choice ??= colors.fillIn(line);
      width ??= pointsAttribute(line, 'w');
    }

    take(child(properties, 'ln'));
    final reference = child(style, 'lnRef');
    if (reference != null) {
      final index = intAttribute(reference, 'idx') ?? 0;
      choice ??= index == 0
          ? const FillChoice(null)
          : FillChoice(colors.colorIn(reference));
      if (index > 0) width ??= colors.theme.lineWidth(index);
    }
    for (final other in inherited) {
      take(child(other, 'ln'));
    }
    if (choice != null && choice!.approximate) {
      session.losses.add(ImportLoss.shapes);
    }
    return (
      color: choice?.color,
      width: (width ?? PptxTheme.defaultLineWidth).clamp(0.0, 1000.0),
    );
  }

  void _picture(XmlElement picture, GroupFrame? group, List<SlideElement> out) {
    final ph = Placeholder.of(picture);
    if (ph != null && decoration) return;
    final nonVisual = child(picture.firstElementChild, 'nvPr');
    if (nonVisual != null &&
        nonVisual.childElements.any(
          (element) => _mediaMarkers.contains(element.name.local),
        )) {
      session.losses.add(ImportLoss.content);
    }
    var placement = _place(child(picture, 'spPr'), group);
    if (placement == null && ph != null) {
      final type = ph.getAttribute('type') ?? 'obj';
      final layoutPh = layout?.placeholder(type, intAttribute(ph, 'idx'));
      placement = layoutPh?.placement ?? master?.placeholder(type)?.placement;
    }
    if (placement == null || !placement.isValid) return;

    final fill = child(picture, 'blipFill');
    final blip = child(fill, 'blip');
    final image = blip == null
        ? null
        : session.image(partPath, relationshipAttribute(blip, 'embed'));
    if (image == null) {
      session.losses.add(ImportLoss.images);
      return;
    }
    if (!image.decodable) session.losses.add(ImportLoss.images);

    final source = child(fill, 'srcRect');
    double side(String name) =>
        (fractionAttribute(source, name) ?? 0).clamp(0.0, 1.0);
    out.add(
      ImageElement(
        id: _newId(),
        frame: placement.frame,
        rotation: placement.rotation,
        locked: decoration,
        image: image,
        crop: Rect.fromLTRB(side('l'), side('t'), side('r'), side('b')),
      ),
    );
  }
}

/// `a:bodyPr` of a shape over those of the placeholders it inherits from.
class _BodyProperties {
  _BodyProperties(List<XmlElement?> sources)
    : _sources = [for (final source in sources) ?source];

  final List<XmlElement> _sources;

  String? _attribute(String name) {
    for (final source in _sources) {
      final value = source.getAttribute(name);
      if (value != null) return value;
    }
    return null;
  }

  double _inset(String name, double fallback) {
    for (final source in _sources) {
      final value = pointsAttribute(source, name);
      if (value != null) return value.clamp(0.0, 10000.0);
    }
    return fallback;
  }

  late final XmlElement? _autofit = () {
    for (final source in _sources) {
      for (final element in source.childElements) {
        if (TreeReader._autofits.contains(element.name.local)) return element;
      }
    }
    return null;
  }();

  TextAnchor get anchor => switch (_attribute('anchor')) {
    'ctr' => TextAnchor.middle,
    'b' => TextAnchor.bottom,
    _ => TextAnchor.top,
  };

  TextInsets get insets => TextInsets(
    left: _inset('lIns', 7.2),
    top: _inset('tIns', 3.6),
    right: _inset('rIns', 7.2),
    bottom: _inset('bIns', 3.6),
  );

  bool get isVertical {
    final vertical = _attribute('vert');
    return vertical != null && vertical != 'horz';
  }

  bool get autoFit => _autofit?.name.local == 'spAutoFit';

  TextShrink get shrink {
    final autofit = _autofit;
    if (autofit == null || autofit.name.local != 'normAutofit') {
      return TextShrink.none;
    }
    return TextShrink(
      fontScale: (fractionAttribute(autofit, 'fontScale') ?? 1).clamp(0.01, 1),
      spacingReduction: (fractionAttribute(autofit, 'lnSpcReduction') ?? 0)
          .clamp(0, 1),
    );
  }
}
