import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import '../../deck/element.dart';
import '../../deck/presentation.dart';
import '../../deck/text_body.dart';
import 'opc_package.dart';
import 'pptx_template.dart';
import 'pptx_xml.dart';

/// Saves [presentation] as a `.pptx` file. Everything a shape shows is
/// written on the shape itself, so nothing depends on what a reader makes
/// of the master and layouts. The same deck always gives the same bytes.
///
/// Uses no Flutter binding, so it can run in an isolate.
Uint8List writePptx(Presentation presentation) {
  final size = presentation.size;
  final media = _Media();
  final slides = [
    for (final slide in presentation.slides) _SlideWriter(slide, media).write(),
  ];

  final parts = <String, List<int>>{};
  void add(String path, String xml) => parts[path] = utf8.encode(xml);
  void addWithRelationships(String path, String xml, String relationships) {
    add(path, xml);
    add(OpcPackage.relationshipsPath(path), relationships);
  }

  add(
    OpcPackage.contentTypesPath,
    contentTypesXml(
      slideCount: slides.length,
      mediaExtensions: media.extensions,
    ),
  );
  add('_rels/.rels', packageRelationshipsXml);
  add('docProps/app.xml', appPropertiesXml(slides.length));
  add('docProps/core.xml', corePropertiesXml);
  addWithRelationships(
    'ppt/presentation.xml',
    presentationXml(size, slides.length),
    presentationRelationshipsXml(slides.length),
  );
  add(themePath, themeXml);
  addWithRelationships(masterPath, masterXml(size), masterRelationshipsXml);
  for (final layout in TemplateLayout.values) {
    addWithRelationships(
      layout.path,
      layoutXml(layout, size),
      layoutRelationshipsXml,
    );
  }
  for (var i = 0; i < slides.length; i++) {
    addWithRelationships(
      slidePath(i + 1),
      slides[i].xml,
      slides[i].relationships,
    );
  }
  media.paths.forEach((image, path) => parts[path] = image.bytes);
  return OpcPackage.encode(parts);
}

/// The pictures of the deck, each stored once however often it is shown.
class _Media {
  final paths = Map<ImageData, String>.identity();
  final extensions = <String>{};

  static final _plainExtension = RegExp(r'^[a-z0-9]{1,8}$');

  String pathOf(ImageData image) => paths[image] ??= _newPath(image);

  String _newPath(ImageData image) {
    var extension = image.extension.toLowerCase();
    if (!_plainExtension.hasMatch(extension) ||
        extension == 'xml' ||
        extension == 'rels') {
      extension = 'bin';
    }
    extensions.add(extension);
    return 'ppt/media/image${paths.length + 1}.$extension';
  }
}

const _presets = {
  ShapeKind.rectangle: 'rect',
  ShapeKind.roundedRectangle: 'roundRect',
  ShapeKind.ellipse: 'ellipse',
  ShapeKind.triangle: 'triangle',
  ShapeKind.rightTriangle: 'rtTriangle',
  ShapeKind.diamond: 'diamond',
  ShapeKind.pentagon: 'pentagon',
  ShapeKind.hexagon: 'hexagon',
  ShapeKind.star: 'star5',
  ShapeKind.rightArrow: 'rightArrow',
  ShapeKind.leftArrow: 'leftArrow',
  ShapeKind.upArrow: 'upArrow',
  ShapeKind.downArrow: 'downArrow',
  ShapeKind.line: 'line',
};

const _shapeNames = {
  ShapeKind.rectangle: 'Rectangle',
  ShapeKind.roundedRectangle: 'Rounded Rectangle',
  ShapeKind.ellipse: 'Oval',
  ShapeKind.triangle: 'Isosceles Triangle',
  ShapeKind.rightTriangle: 'Right Triangle',
  ShapeKind.diamond: 'Diamond',
  ShapeKind.pentagon: 'Pentagon',
  ShapeKind.hexagon: 'Hexagon',
  ShapeKind.star: 'Star',
  ShapeKind.rightArrow: 'Right Arrow',
  ShapeKind.leftArrow: 'Left Arrow',
  ShapeKind.upArrow: 'Up Arrow',
  ShapeKind.downArrow: 'Down Arrow',
  ShapeKind.line: 'Straight Connector',
};

const _alignments = {
  ParagraphAlign.left: 'l',
  ParagraphAlign.center: 'ctr',
  ParagraphAlign.right: 'r',
  ParagraphAlign.justify: 'just',
};

const _anchors = {
  TextAnchor.top: 't',
  TextAnchor.middle: 'ctr',
  TextAnchor.bottom: 'b',
};

const _placeholderNames = {
  PlaceholderKind.title: 'Title',
  PlaceholderKind.subtitle: 'Subtitle',
  PlaceholderKind.body: 'Content Placeholder',
};

/// Broken numbers must not break the whole file.
int _emu(double points) => points.isFinite ? pointsToEmu(points) : 0;

int _size(double points) => _emu(points).clamp(0, 51206400);

String _solidFill(int argb) {
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  final alpha = (argb >> 24) & 0xFF;
  final color = alpha == 0xFF
      ? '<a:srgbClr val="$rgb"/>'
      : '<a:srgbClr val="$rgb">'
            '<a:alpha val="${(alpha / 255 * 100000).round()}"/></a:srgbClr>';
  return '<a:solidFill>$color</a:solidFill>';
}

String _fill(int? argb) => argb == null ? '<a:noFill/>' : _solidFill(argb);

class _SlideWriter {
  _SlideWriter(this.slide, this.media);

  final Slide slide;
  final _Media media;

  final _xml = StringBuffer();
  final _imageIds = Map<ImageData, String>.identity();
  final _relationships = <({String type, String target})>[];

  RunStyle? _lastStyle;
  String _lastProperties = '';

  ({String xml, String relationships}) write() {
    final (layout, placeholders) = _chooseLayout();
    _relationships.add((
      type: 'slideLayout',
      target: '../slideLayouts/slideLayout${layout.number}.xml',
    ));

    final background = slide.backgroundImage;
    _xml
      ..write(xmlDeclaration)
      ..write('<p:sld $drawingNamespaces><p:cSld><p:bg><p:bgPr>')
      ..write(
        background == null
            ? _solidFill(slide.background)
            : '<a:blipFill dpi="0" rotWithShape="1">'
                  '<a:blip r:embed="${_imageId(background)}"/><a:srcRect/>'
                  '<a:stretch><a:fillRect/></a:stretch></a:blipFill>',
      )
      ..write('<a:effectLst/></p:bgPr></p:bg>')
      ..write(shapeTreeStart);
    var id = 2;
    for (final element in slide.elements) {
      switch (element) {
        case ImageElement():
          _picture(element, id);
        case ShapeElement(isLine: true):
          _line(element, id);
        case ShapeElement():
          _shape(element, id, placeholders[element]);
      }
      id++;
    }
    _xml.write(
      '</p:spTree></p:cSld>'
      '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>',
    );
    return (
      xml: _xml.toString(),
      relationships: relationshipsXml(_relationships),
    );
  }

  /// The layout that has a placeholder for the most of what the slide
  /// holds, and the `p:ph` attributes of the elements that fill them.
  (TemplateLayout, Map<SlideElement, String>) _chooseLayout() {
    ShapeElement? first(PlaceholderKind kind) {
      for (final element in slide.elements) {
        if (element is ShapeElement &&
            !element.isLine &&
            element.placeholder == kind) {
          return element;
        }
      }
      return null;
    }

    final title = first(PlaceholderKind.title);
    if (title == null) return (TemplateLayout.blank, const {});
    final subtitle = first(PlaceholderKind.subtitle);
    if (subtitle != null) {
      return (
        TemplateLayout.titleSlide,
        Map.identity()
          ..[title] = 'type="ctrTitle"'
          ..[subtitle] = 'type="subTitle" idx="1"',
      );
    }
    final body = first(PlaceholderKind.body);
    if (body != null) {
      return (
        TemplateLayout.titleContent,
        Map.identity()
          ..[title] = 'type="title"'
          ..[body] = 'idx="1"',
      );
    }
    return (TemplateLayout.titleOnly, Map.identity()..[title] = 'type="title"');
  }

  String _imageId(ImageData image) => _imageIds[image] ??= _relate(image);

  String _relate(ImageData image) {
    final path = media.pathOf(image);
    _relationships.add((
      type: 'image',
      target: '../media/${path.substring(path.lastIndexOf('/') + 1)}',
    ));
    return 'rId${_relationships.length}';
  }

  void _transform(
    SlideElement element, {
    bool flipH = false,
    bool flipV = false,
  }) {
    final frame = element.frame;
    final rotation = element.rotation.isFinite
        ? degreesToAngle(element.rotation % 360) % 21600000
        : 0;
    _xml
      ..write('<a:xfrm')
      ..write(rotation == 0 ? '' : ' rot="$rotation"')
      ..write(flipH ? ' flipH="1"' : '')
      ..write(flipV ? ' flipV="1"' : '')
      ..write('><a:off x="${_emu(frame.left)}" y="${_emu(frame.top)}"/>')
      ..write('<a:ext cx="${_size(frame.width)}" cy="${_size(frame.height)}"/>')
      ..write('</a:xfrm>');
  }

  void _outline(ShapeElement shape, {String ends = ''}) {
    final width = _emu(shape.strokeWidth).clamp(0, 20116800);
    _xml.write('<a:ln w="$width">${_fill(shape.stroke)}$ends</a:ln>');
  }

  void _shape(ShapeElement shape, int id, String? ph) {
    final isTextBox =
        ph == null &&
        shape.kind == ShapeKind.rectangle &&
        shape.fill == null &&
        shape.stroke == null;
    final name = ph != null
        ? _placeholderNames[shape.placeholder]
        : isTextBox
        ? 'TextBox'
        : _shapeNames[shape.kind];
    _xml
      ..write('<p:sp><p:nvSpPr><p:cNvPr id="$id" name="$name ${id - 1}"/>')
      ..write(
        ph != null
            ? '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
                  '<p:nvPr><p:ph $ph/></p:nvPr>'
            : '<p:cNvSpPr${isTextBox ? ' txBox="1"' : ''}/><p:nvPr/>',
      )
      ..write('</p:nvSpPr><p:spPr>');
    _transform(shape, flipH: shape.flipH, flipV: shape.flipV);
    _xml
      ..write('<a:prstGeom prst="${_presets[shape.kind]}"><a:avLst/>')
      ..write('</a:prstGeom>')
      ..write(_fill(shape.fill));
    _outline(shape);
    _xml.write('</p:spPr>');
    _textBody(shape);
    _xml.write('</p:sp>');
  }

  void _line(ShapeElement line, int id) {
    _xml
      ..write('<p:cxnSp><p:nvCxnSpPr>')
      ..write('<p:cNvPr id="$id" name="Straight Connector ${id - 1}"/>')
      ..write('<p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr>');
    _transform(line, flipH: line.flipH, flipV: line.flipV);
    _xml.write('<a:prstGeom prst="line"><a:avLst/></a:prstGeom>');
    String end(String name, bool arrow) =>
        '<a:$name type="${arrow ? 'triangle' : 'none'}"/>';
    _outline(
      line,
      ends: end('headEnd', line.startArrow) + end('tailEnd', line.endArrow),
    );
    _xml.write('</p:spPr></p:cxnSp>');
  }

  void _picture(ImageElement picture, int id) {
    _xml
      ..write('<p:pic><p:nvPicPr>')
      ..write('<p:cNvPr id="$id" name="Picture ${id - 1}"/>')
      ..write('<p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>')
      ..write('<p:nvPr/></p:nvPicPr><p:blipFill>')
      ..write('<a:blip r:embed="${_imageId(picture.image)}"/>');
    final crop = picture.crop;
    if (crop != Rect.zero) {
      String side(String name, double fraction) {
        final value = fraction.isFinite
            ? fractionToPercent(fraction.clamp(0.0, 1.0))
            : 0;
        return value == 0 ? '' : ' $name="$value"';
      }

      _xml
        ..write('<a:srcRect')
        ..write(side('l', crop.left))
        ..write(side('t', crop.top))
        ..write(side('r', crop.right))
        ..write(side('b', crop.bottom))
        ..write('/>');
    }
    _xml.write('<a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr>');
    _transform(picture);
    _xml.write(
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>',
    );
  }

  void _textBody(ShapeElement shape) {
    final insets = shape.insets;
    int inset(double points) => _emu(points).clamp(0, 51206400);
    _xml
      ..write('<p:txBody><a:bodyPr wrap="square" ')
      ..write('lIns="${inset(insets.left)}" tIns="${inset(insets.top)}" ')
      ..write('rIns="${inset(insets.right)}" bIns="${inset(insets.bottom)}" ')
      ..write('anchor="${_anchors[shape.anchor]}" rtlCol="0">')
      ..write(shape.autoFit ? '<a:spAutoFit/>' : '<a:noAutofit/>')
      ..write('</a:bodyPr><a:lstStyle/>');
    shape.text.paragraphs.forEach(_paragraph);
    _xml.write('</p:txBody>');
  }

  void _paragraph(Paragraph paragraph) {
    final firstSize = paragraph.runs.first.style.size;
    final level = paragraph.level.clamp(0, Paragraph.maxLevel);
    // The bullet hangs in the margin, so wrapped lines align with the text.
    final hanging = switch (paragraph.bullet) {
      BulletKind.none => 0.0,
      BulletKind.bullet => firstSize * 0.9,
      BulletKind.number => firstSize * 1.6,
    };
    int hundredths(double value, int limit) =>
        value.isFinite ? (value * 100).round().clamp(0, limit) : 0;
    final lineSpacing = paragraph.lineSpacing.isFinite
        ? fractionToPercent(paragraph.lineSpacing).clamp(0, 13200000)
        : 100000;
    _xml
      ..write('<a:p><a:pPr marL="${_size(level * 36 + hanging)}" ')
      ..write('indent="${-_size(hanging)}" lvl="$level" ')
      ..write('algn="${_alignments[paragraph.align]}">')
      ..write('<a:lnSpc><a:spcPct val="$lineSpacing"/></a:lnSpc>')
      ..write('<a:spcBef><a:spcPts val="')
      ..write(hundredths(paragraph.spaceBefore, 158400))
      ..write('"/></a:spcBef><a:spcAft><a:spcPts val="')
      ..write(hundredths(paragraph.spaceAfter, 158400))
      ..write('"/></a:spcAft>')
      ..write(switch (paragraph.bullet) {
        BulletKind.none => '<a:buNone/>',
        BulletKind.bullet =>
          '<a:buFont typeface="$defaultFont"/><a:buChar char="&#8226;"/>',
        BulletKind.number =>
          '<a:buFont typeface="+mj-lt"/><a:buAutoNum type="arabicPeriod"/>',
      })
      ..write('</a:pPr>');
    var hasText = false;
    for (final run in paragraph.runs) {
      if (run.text.isEmpty) continue;
      hasText = true;
      _run(run);
    }
    if (!hasText) {
      final properties = _runProperties(paragraph.runs.first.style);
      _xml.write('<a:endParaRPr$properties</a:endParaRPr>');
    }
    _xml.write('</a:p>');
  }

  void _run(TextRun run) {
    final properties = _runProperties(run.style);
    final text = run.text;
    var start = 0;
    while (true) {
      final next = text.indexOf(softBreak, start);
      final end = next < 0 ? text.length : next;
      if (end > start) {
        _xml
          ..write('<a:r><a:rPr$properties</a:rPr><a:t>')
          ..write(escapeXml(text.substring(start, end)))
          ..write('</a:t></a:r>');
      }
      if (next < 0) return;
      _xml.write('<a:br><a:rPr$properties</a:rPr></a:br>');
      start = next + softBreak.length;
    }
  }

  /// Attributes and children of an `a:rPr`, from the space before the first
  /// attribute to the last child. Runs in a row often share one style.
  String _runProperties(RunStyle style) {
    if (style == _lastStyle) return _lastProperties;
    final size = style.size.isFinite
        ? (style.size * 100).round().clamp(100, 400000)
        : 1800;
    final font = escapeAttribute(style.font.isEmpty ? defaultFont : style.font);
    _lastStyle = style;
    return _lastProperties =
        ' lang="en-US" sz="$size" b="${style.bold ? 1 : 0}" '
        'i="${style.italic ? 1 : 0}" u="${style.underline ? 'sng' : 'none'}" '
        'strike="${style.strike ? 'sngStrike' : 'noStrike'}" dirty="0">'
        '${_solidFill(style.color)}'
        '<a:latin typeface="$font"/><a:cs typeface="$font"/>';
  }
}
