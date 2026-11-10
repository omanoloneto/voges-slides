import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/deck/element.dart';
import 'package:voges_slides/deck/presentation.dart';
import 'package:voges_slides/deck/text_body.dart';
import 'package:voges_slides/files/pptx/pptx_import.dart';
import 'package:voges_slides/files/pptx/pptx_reader.dart';
import 'package:voges_slides/files/presentation_file_exception.dart';

const namespaces =
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
    'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
    'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"';

const _officeRelationships =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

const _declaration = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

const presentationPath = 'ppt/presentation.xml';
const themePath = 'ppt/theme/theme1.xml';
const masterPath = 'ppt/slideMasters/slideMaster1.xml';
const layoutPath = 'ppt/slideLayouts/slideLayout1.xml';

String slidePath(int number) => 'ppt/slides/slide$number.xml';

String slideRelationshipsPath(int number) =>
    'ppt/slides/_rels/slide$number.xml.rels';

/// A zip holding [parts]: text is stored as UTF-8, anything else as bytes.
Uint8List zipParts(Map<String, Object> parts) {
  final archive = Archive();
  parts.forEach((name, content) {
    final data = content is String
        ? utf8.encode(content)
        : content as List<int>;
    archive.add(ArchiveFile.bytes(name, data));
  });
  return ZipEncoder().encodeBytes(archive);
}

/// The parts of a zip by name, in the order they are stored.
Map<String, Uint8List> unzip(Uint8List bytes) => {
  for (final file in ZipDecoder().decodeBytes(bytes).files)
    if (file.isFile) file.name: file.readBytes()!,
};

PptxImport read(Map<String, Object> parts) => readPptx(zipParts(parts));

Matcher throwsProblem(PresentationProblem problem) => throwsA(
  isA<PresentationFileException>().having(
    (error) => error.problem,
    'problem',
    problem,
  ),
);

final pictureBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);

String relationship(
  String id,
  String type,
  String target, {
  bool external = false,
}) =>
    '<Relationship Id="$id" Type="$_officeRelationships/$type" '
    'Target="$target"${external ? ' TargetMode="External"' : ''}/>';

String relationshipsPart(String entries) =>
    '$_declaration<Relationships '
    'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '$entries</Relationships>';

/// A slide, layout or master: a `p:cSld` with [shapes] in its tree.
String treePart(
  String root, {
  String shapes = '',
  String background = '',
  String attributes = '',
  String after = '',
}) =>
    '$_declaration<p:$root $namespaces $attributes><p:cSld>$background'
    '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/>'
    '<p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>$shapes</p:spTree></p:cSld>'
    '$after</p:$root>';

/// One slide of [deckParts]. Its `rId1` is the layout; [relationships]
/// holds any further `Relationship` elements.
class SlideFixture {
  const SlideFixture({
    this.shapes = '',
    this.background = '',
    this.attributes = '',
    this.after = '',
    this.relationships = '',
  });

  final String shapes;
  final String background;
  final String attributes;
  final String after;
  final String relationships;
}

const defaultColorMap =
    'bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" '
    'accent2="accent2" accent3="accent3" accent4="accent4" '
    'accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"';

String themeXml({
  Map<String, String> colors = const {},
  String major = 'Arial',
  String minor = 'Arial',
  String lines = '',
}) {
  final scheme = {
    'dk1': '000000',
    'lt1': 'FFFFFF',
    'dk2': '44546A',
    'lt2': 'E7E6E6',
    'accent1': '4472C4',
    'accent2': 'ED7D31',
    ...colors,
  };
  return '$_declaration<a:theme $namespaces name="Fixture"><a:themeElements>'
      '<a:clrScheme name="Fixture">'
      '${[for (final slot in scheme.entries) '<a:${slot.key}><a:srgbClr val="${slot.value}"/></a:${slot.key}>'].join()}'
      '</a:clrScheme>'
      '<a:fontScheme name="Fixture">'
      '<a:majorFont><a:latin typeface="$major"/></a:majorFont>'
      '<a:minorFont><a:latin typeface="$minor"/></a:minorFont>'
      '</a:fontScheme>'
      '<a:fmtScheme name="Fixture"><a:lnStyleLst>$lines</a:lnStyleLst>'
      '</a:fmtScheme></a:themeElements></a:theme>';
}

/// A deck with one theme, one master and one layout shared by [slides].
/// The result can be changed before it is zipped.
Map<String, Object> deckParts({
  List<SlideFixture> slides = const [SlideFixture()],
  String? theme,
  String masterShapes = '',
  String masterBackground = '',
  String masterStyles = '',
  String colorMap = defaultColorMap,
  String layoutShapes = '',
  String layoutBackground = '',
  String layoutAttributes = '',
  String layoutAfter = '',
  String defaultTextStyle = '',
  String size = '<p:sldSz cx="12192000" cy="6858000"/>',
}) {
  final slideIds = StringBuffer();
  final slideRelationships = StringBuffer();
  for (var i = 0; i < slides.length; i++) {
    slideIds.write('<p:sldId id="${256 + i}" r:id="rId${i + 3}"/>');
    slideRelationships.write(
      relationship('rId${i + 3}', 'slide', 'slides/slide${i + 1}.xml'),
    );
  }
  return {
    '[Content_Types].xml':
        '$_declaration<Types '
        'xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="xml" ContentType="application/xml"/></Types>',
    '_rels/.rels': relationshipsPart(
      relationship('rId1', 'officeDocument', presentationPath),
    ),
    presentationPath:
        '$_declaration<p:presentation $namespaces><p:sldMasterIdLst>'
        '<p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
        '<p:sldIdLst>$slideIds</p:sldIdLst>$size'
        '<p:notesSz cx="6858000" cy="9144000"/>'
        '${defaultTextStyle.isEmpty ? '' : '<p:defaultTextStyle>$defaultTextStyle</p:defaultTextStyle>'}'
        '</p:presentation>',
    'ppt/_rels/presentation.xml.rels': relationshipsPart(
      relationship('rId1', 'slideMaster', 'slideMasters/slideMaster1.xml') +
          relationship('rId2', 'theme', 'theme/theme1.xml') +
          slideRelationships.toString(),
    ),
    themePath: theme ?? themeXml(),
    masterPath: treePart(
      'sldMaster',
      shapes: masterShapes,
      background: masterBackground,
      after:
          '<p:clrMap $colorMap/><p:sldLayoutIdLst>'
          '<p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>'
          '<p:txStyles>$masterStyles</p:txStyles>',
    ),
    'ppt/slideMasters/_rels/slideMaster1.xml.rels': relationshipsPart(
      relationship('rId1', 'slideLayout', '../slideLayouts/slideLayout1.xml') +
          relationship('rId2', 'theme', '../theme/theme1.xml'),
    ),
    layoutPath: treePart(
      'sldLayout',
      shapes: layoutShapes,
      background: layoutBackground,
      attributes: layoutAttributes,
      after: layoutAfter,
    ),
    'ppt/slideLayouts/_rels/slideLayout1.xml.rels': relationshipsPart(
      relationship('rId1', 'slideMaster', '../slideMasters/slideMaster1.xml'),
    ),
    for (var i = 0; i < slides.length; i++) ...{
      slidePath(i + 1): treePart(
        'sld',
        shapes: slides[i].shapes,
        background: slides[i].background,
        attributes: slides[i].attributes,
        after: slides[i].after,
      ),
      slideRelationshipsPath(i + 1): relationshipsPart(
        relationship(
              'rId1',
              'slideLayout',
              '../slideLayouts/slideLayout1.xml',
            ) +
            slides[i].relationships,
      ),
    },
  };
}

/// Reads a deck of one slide holding [shapes] and returns that slide.
Slide readSlide(String shapes) => read(
  deckParts(slides: [SlideFixture(shapes: shapes)]),
).presentation.slides.single;

int emu(num points) => (points * 12700).round();

String xfrm(
  num x,
  num y,
  num width,
  num height, {
  String attributes = '',
  String children = '',
}) =>
    '<a:xfrm $attributes><a:off x="${emu(x)}" y="${emu(y)}"/>'
    '<a:ext cx="${emu(width)}" cy="${emu(height)}"/>$children</a:xfrm>';

String preset(String name) =>
    '<a:prstGeom prst="$name"><a:avLst/></a:prstGeom>';

String solid(String hex) =>
    '<a:solidFill><a:srgbClr val="$hex"/></a:solidFill>';

String scheme(String name, [String transforms = '']) =>
    '<a:solidFill><a:schemeClr val="$name">$transforms</a:schemeClr>'
    '</a:solidFill>';

/// A `p:sp`. [ph] is a whole `p:ph` element, [spPr] the children of
/// `p:spPr`, [style] a whole `p:style` and [text] a whole `p:txBody`.
String sp({
  int id = 2,
  String ph = '',
  String spPr = '',
  String style = '',
  String text = '',
  String nameAttributes = '',
}) =>
    '<p:sp><p:nvSpPr><p:cNvPr id="$id" name="Shape $id" $nameAttributes/>'
    '<p:cNvSpPr/><p:nvPr>$ph</p:nvPr></p:nvSpPr><p:spPr>$spPr</p:spPr>'
    '$style$text</p:sp>';

/// A `p:pic` showing the picture of relationship [embed].
String pic(String embed, {String spPr = '', String source = '', int id = 9}) =>
    '<p:pic><p:nvPicPr><p:cNvPr id="$id" name="Picture $id"/><p:cNvPicPr/>'
    '<p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="$embed"/>$source'
    '<a:stretch><a:fillRect/></a:stretch></p:blipFill>'
    '<p:spPr>$spPr</p:spPr></p:pic>';

String txBody(
  String paragraphs, {
  String bodyPr = '<a:bodyPr/>',
  String lstStyle = '',
}) =>
    '<p:txBody>$bodyPr<a:lstStyle>$lstStyle</a:lstStyle>$paragraphs</p:txBody>';

/// An `a:p`; [pPr] is a whole `a:pPr` element.
String para(String content, {String pPr = ''}) => '<a:p>$pPr$content</a:p>';

/// An `a:r`; [rPr] is a whole `a:rPr` element.
String run(String text, {String rPr = ''}) => '<a:r>$rPr<a:t>$text</a:t></a:r>';

ShapeElement shapeAt(Slide slide, int index) =>
    slide.elements[index] as ShapeElement;

RunStyle styleAt(ShapeElement shape, [int paragraph = 0, int run = 0]) =>
    shape.text.paragraphs[paragraph].runs[run].style;

void expectFrame(Rect actual, Rect expected, {String? reason}) {
  expect(actual.left, closeTo(expected.left, 0.001), reason: reason);
  expect(actual.top, closeTo(expected.top, 0.001), reason: reason);
  expect(actual.width, closeTo(expected.width, 0.001), reason: reason);
  expect(actual.height, closeTo(expected.height, 0.001), reason: reason);
}

/// Compares everything but ids. Pictures must hold the same bytes and be
/// shared between the same elements.
void expectSamePresentation(Presentation actual, Presentation expected) {
  expect(actual.size.width, closeTo(expected.size.width, 0.001));
  expect(actual.size.height, closeTo(expected.size.height, 0.001));
  expect(actual.slides, hasLength(expected.slides.length));
  final images = Map<ImageData, ImageData>.identity();
  final seen = Set<ImageData>.identity();
  void expectImage(ImageData? found, ImageData? wanted, String where) {
    if (wanted == null) {
      expect(found, isNull, reason: where);
      return;
    }
    expect(found, isNotNull, reason: where);
    final known = images[wanted];
    if (known != null) {
      expect(found, same(known), reason: '$where: picture not shared');
      return;
    }
    expect(seen.add(found!), isTrue, reason: '$where: picture wrongly shared');
    images[wanted] = found;
    expect(found.bytes, wanted.bytes, reason: where);
    expect(found.extension, wanted.extension, reason: where);
  }

  for (var s = 0; s < expected.slides.length; s++) {
    final slide = actual.slides[s];
    final wanted = expected.slides[s];
    expect(slide.background, wanted.background, reason: 'slide $s background');
    expectImage(slide.backgroundImage, wanted.backgroundImage, 'slide $s');
    expect(
      slide.elements,
      hasLength(wanted.elements.length),
      reason: 'slide $s',
    );
    for (var e = 0; e < wanted.elements.length; e++) {
      final where = 'slide $s element $e';
      final element = slide.elements[e];
      final other = wanted.elements[e];
      expect(element.runtimeType, other.runtimeType, reason: where);
      expectFrame(element.frame, other.frame, reason: where);
      expect(
        element.rotation,
        closeTo(other.rotation, 0.001),
        reason: '$where rotation',
      );
      expect(element.locked, other.locked, reason: '$where locked');
      switch ((element, other)) {
        case (final ImageElement found, final ImageElement image):
          expectImage(found.image, image.image, where);
          expect(found.crop.left, closeTo(image.crop.left, 1e-5));
          expect(found.crop.top, closeTo(image.crop.top, 1e-5));
          expect(found.crop.right, closeTo(image.crop.right, 1e-5));
          expect(found.crop.bottom, closeTo(image.crop.bottom, 1e-5));
        case (final ShapeElement found, final ShapeElement shape):
          _expectSameShape(found, shape, where);
        default:
          fail('$where: different kinds of element');
      }
    }
  }
}

void _expectSameShape(ShapeElement found, ShapeElement shape, String where) {
  expect(found.kind, shape.kind, reason: '$where kind');
  expect(found.fill, shape.fill, reason: '$where fill');
  expect(found.stroke, shape.stroke, reason: '$where stroke');
  expect(
    found.strokeWidth,
    closeTo(shape.strokeWidth, 0.001),
    reason: '$where stroke width',
  );
  expect(found.flipH, shape.flipH, reason: '$where flipH');
  expect(found.flipV, shape.flipV, reason: '$where flipV');
  expect(found.startArrow, shape.startArrow, reason: '$where start arrow');
  expect(found.endArrow, shape.endArrow, reason: '$where end arrow');
  expect(found.anchor, shape.anchor, reason: '$where anchor');
  expect(found.insets.left, closeTo(shape.insets.left, 0.001), reason: where);
  expect(found.insets.top, closeTo(shape.insets.top, 0.001), reason: where);
  expect(found.insets.right, closeTo(shape.insets.right, 0.001), reason: where);
  expect(
    found.insets.bottom,
    closeTo(shape.insets.bottom, 0.001),
    reason: where,
  );
  expect(found.placeholder, shape.placeholder, reason: '$where placeholder');
  expect(found.autoFit, shape.autoFit, reason: '$where autoFit');
  expect(
    found.text.paragraphs,
    hasLength(shape.text.paragraphs.length),
    reason: '$where paragraphs',
  );
  for (var p = 0; p < shape.text.paragraphs.length; p++) {
    final paragraph = found.text.paragraphs[p];
    final wanted = shape.text.paragraphs[p];
    final here = '$where paragraph $p';
    expect(paragraph.runs, wanted.runs, reason: '$here runs');
    expect(paragraph.align, wanted.align, reason: '$here align');
    expect(paragraph.bullet, wanted.bullet, reason: '$here bullet');
    expect(paragraph.level, wanted.level, reason: '$here level');
    expect(
      paragraph.lineSpacing,
      closeTo(wanted.lineSpacing, 1e-5),
      reason: '$here line spacing',
    );
    expect(
      paragraph.spaceBefore,
      closeTo(wanted.spaceBefore, 0.01),
      reason: '$here space before',
    );
    expect(
      paragraph.spaceAfter,
      closeTo(wanted.spaceAfter, 0.01),
      reason: '$here space after',
    );
  }
}
