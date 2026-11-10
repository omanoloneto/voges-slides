import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/deck/element.dart';
import 'package:voges_slides/deck/presentation.dart';
import 'package:voges_slides/deck/text_body.dart';
import 'package:voges_slides/files/pptx/opc_package.dart';
import 'package:voges_slides/files/pptx/pptx_reader.dart';
import 'package:voges_slides/files/pptx/pptx_writer.dart';
import 'package:xml/xml.dart';

import 'fixtures.dart';

const _frame = Rect.fromLTWH(10, 20, 300, 100);

ShapeElement _shape(
  String text, {
  PlaceholderKind? placeholder,
  ShapeKind kind = ShapeKind.rectangle,
  int? fill,
  int? stroke,
  TextBody? body,
}) => ShapeElement(
  id: 0,
  frame: _frame,
  kind: kind,
  fill: fill,
  stroke: stroke,
  placeholder: placeholder,
  text: body ?? TextBody.plain(text, const RunStyle()),
);

Presentation _one(List<SlideElement> elements) =>
    Presentation(slides: [Slide(id: 0, elements: elements)]);

Map<String, String> _parts(Presentation presentation) => {
  for (final part in unzip(writePptx(presentation)).entries)
    if (part.key.endsWith('.xml') || part.key.endsWith('.rels'))
      part.key: utf8.decode(part.value),
};

String _slide(List<SlideElement> elements) =>
    _parts(_one(elements))[slidePath(1)]!;

/// Slides with every layout the writer can pick, and two pictures.
Presentation _deck() {
  final picture = ImageData(pictureBytes, 'png');
  final photo = ImageData(Uint8List.fromList([0xFF, 0xD8, 0xFF, 1]), 'jpeg');
  return Presentation(
    size: const Size(720, 540),
    slides: [
      Slide(
        id: 0,
        elements: [
          _shape('Title', placeholder: PlaceholderKind.title),
          _shape('Subtitle', placeholder: PlaceholderKind.subtitle),
        ],
      ),
      Slide(
        id: 0,
        elements: [
          _shape('Title', placeholder: PlaceholderKind.title),
          _shape('Body', placeholder: PlaceholderKind.body),
        ],
      ),
      Slide(
        id: 0,
        elements: [_shape('Title', placeholder: PlaceholderKind.title)],
      ),
      Slide(
        id: 0,
        backgroundImage: photo,
        elements: [
          _shape('Body alone', placeholder: PlaceholderKind.body),
          ImageElement(id: 0, frame: _frame, image: picture),
          ImageElement(id: 0, frame: _frame, image: picture),
        ],
      ),
      Slide(
        id: 0,
        elements: [ImageElement(id: 0, frame: _frame, image: picture)],
      ),
    ],
  );
}

String _relationshipsSource(String path) {
  final directory = path.substring(0, path.indexOf('_rels/'));
  final name = path.substring(path.lastIndexOf('/') + 1);
  return directory + name.substring(0, name.length - '.rels'.length);
}

void main() {
  test('the same deck always gives the same bytes', () {
    expect(writePptx(_deck()), writePptx(_deck()));
  });

  test('the content types come first in the zip', () {
    final names = unzip(writePptx(_deck())).keys.toList();

    expect(names.first, '[Content_Types].xml');
    expect(
      names,
      containsAll([
        '_rels/.rels',
        'docProps/app.xml',
        'docProps/core.xml',
        'ppt/presentation.xml',
        'ppt/_rels/presentation.xml.rels',
        'ppt/theme/theme1.xml',
        'ppt/slideMasters/slideMaster1.xml',
        for (var number = 1; number <= 4; number++)
          'ppt/slideLayouts/slideLayout$number.xml',
        for (var number = 1; number <= 5; number++) slidePath(number),
      ]),
    );
  });

  test('every XML part is well formed', () {
    final parts = _parts(_deck());

    expect(parts.length, greaterThan(20));
    for (final part in parts.entries) {
      expect(
        () => XmlDocument.parse(part.value),
        returnsNormally,
        reason: part.key,
      );
    }
  });

  test('every relationship points to a part of the package', () {
    final all = unzip(writePptx(_deck()));
    var checked = 0;

    for (final name in all.keys.where((name) => name.endsWith('.rels'))) {
      final source = _relationshipsSource(name);
      if (source.isNotEmpty) expect(all, contains(source), reason: name);
      final document = XmlDocument.parse(utf8.decode(all[name]!));
      final ids = <String>{};
      for (final relationship in document.rootElement.childElements) {
        final target = relationship.getAttribute('Target')!;
        expect(
          all,
          contains(OpcPackage.resolve(source, target)),
          reason: '$name: $target',
        );
        expect(ids.add(relationship.getAttribute('Id')!), isTrue);
        checked++;
      }
    }
    expect(checked, greaterThan(20));
  });

  test('every part has a content type', () {
    final all = unzip(writePptx(_deck()));
    final types = XmlDocument.parse(
      utf8.decode(all['[Content_Types].xml']!),
    ).rootElement;
    final defaults = {
      for (final element in types.findElements('Default'))
        element.getAttribute('Extension'),
    };
    final overrides = {
      for (final element in types.findElements('Override'))
        element.getAttribute('PartName'),
    };

    expect(defaults, containsAll(['rels', 'xml', 'png', 'jpeg']));
    for (final name in all.keys.skip(1)) {
      final extension = name.substring(name.lastIndexOf('.') + 1);
      expect(
        overrides.contains('/$name') || defaults.contains(extension),
        isTrue,
        reason: name,
      );
    }
    for (final name in overrides) {
      expect(all, contains(name!.substring(1)));
    }
  });

  test('a picture shown several times is stored once, uncompressed', () {
    final bytes = writePptx(_deck());
    final media = {
      for (final part in unzip(bytes).entries)
        if (part.key.startsWith('ppt/media/')) part.key: part.value,
    };

    expect(media.keys, ['ppt/media/image1.jpeg', 'ppt/media/image2.png']);
    expect(media['ppt/media/image2.png'], pictureBytes);
    final stored = ZipDecoder()
        .decodeBytes(bytes)
        .files
        .where((file) => file.name.startsWith('ppt/media/'));
    expect(
      stored.map((file) => file.compression),
      everyElement(CompressionType.none),
    );
  });

  test('a slide relates each of its pictures once', () {
    final parts = _parts(_deck());

    final relationships = XmlDocument.parse(
      parts[slideRelationshipsPath(4)]!,
    ).rootElement.childElements.toList();

    expect(
      [for (final entry in relationships) entry.getAttribute('Target')],
      [
        '../slideLayouts/slideLayout4.xml',
        '../media/image1.jpeg',
        '../media/image2.png',
      ],
    );
    expect(
      RegExp('r:embed="rId3"').allMatches(parts[slidePath(4)]!),
      hasLength(2),
    );
  });

  test('each slide gets the layout that fits its placeholders', () {
    final parts = _parts(_deck());
    String layoutOf(int slide) => RegExp(
      r'slideLayout\d\.xml',
    ).firstMatch(parts[slideRelationshipsPath(slide)]!)![0]!;

    expect(layoutOf(1), 'slideLayout1.xml');
    expect(parts[slidePath(1)], contains('<p:ph type="ctrTitle"/>'));
    expect(parts[slidePath(1)], contains('<p:ph type="subTitle" idx="1"/>'));
    expect(layoutOf(2), 'slideLayout2.xml');
    expect(parts[slidePath(2)], contains('<p:ph type="title"/>'));
    expect(parts[slidePath(2)], contains('<p:ph idx="1"/>'));
    expect(layoutOf(3), 'slideLayout3.xml');
    expect(parts[slidePath(3)], contains('<p:ph type="title"/>'));
    expect(layoutOf(4), 'slideLayout4.xml');
    expect(parts[slidePath(4)], isNot(contains('<p:ph')));
    expect(layoutOf(5), 'slideLayout4.xml');
  });

  test('the four layouts are the ones the app offers', () {
    final parts = _parts(_deck());
    String layout(int number) =>
        parts['ppt/slideLayouts/slideLayout$number.xml']!;

    expect(layout(1), contains('type="title"'));
    expect(layout(1), contains('<p:cSld name="Title Slide">'));
    expect(layout(1), contains('<p:ph type="ctrTitle"/>'));
    expect(layout(1), contains('<p:ph type="subTitle" idx="1"/>'));
    expect(layout(2), contains('type="obj"'));
    expect(layout(2), contains('<p:cSld name="Title and Content">'));
    expect(layout(3), contains('type="titleOnly"'));
    expect(layout(4), contains('type="blank"'));
    expect(layout(4), isNot(contains('<p:ph')));
  });

  test('only the first element of a placeholder kind fills it', () {
    final slide = _slide([
      _shape('Title', placeholder: PlaceholderKind.title),
      _shape('Second title', placeholder: PlaceholderKind.title),
      _shape('Body', placeholder: PlaceholderKind.body),
      _shape('Subtitle', placeholder: PlaceholderKind.subtitle),
    ]);

    expect(RegExp('<p:ph ').allMatches(slide), hasLength(2));
    expect(slide, contains('<p:ph type="ctrTitle"/>'));
    expect(slide, contains('<p:ph type="subTitle" idx="1"/>'));
  });

  test('the presentation part lists the slides and their size', () {
    final parts = _parts(_deck());
    final presentation = parts['ppt/presentation.xml']!;

    expect(presentation, contains('<p:sldMasterIdLst>'));
    expect(presentation, contains('<p:sldSz cx="9144000" cy="6858000"/>'));
    expect(presentation, contains('<p:notesSz '));
    expect(
      RegExp(
        r'<p:sldId id="(\d+)"',
      ).allMatches(presentation).map((match) => match[1]),
      ['256', '257', '258', '259', '260'],
    );
    expect(parts['docProps/app.xml'], contains('Voges Slides'));
    expect(parts['docProps/core.xml'], isNot(contains('dcterms:created')));
  });

  test('shape ids start at 2 and names say what the shape is', () {
    final slide = _slide([
      _shape('Title', placeholder: PlaceholderKind.title),
      _shape('Loose text'),
      _shape('Box', fill: 0xFFFF0000),
      ImageElement(id: 0, frame: _frame, image: ImageData(pictureBytes, 'png')),
      _shape('', kind: ShapeKind.line, stroke: 0xFF000000),
    ]);

    expect(slide, contains('<p:cNvPr id="2" name="Title 1"/>'));
    expect(slide, contains('<p:cNvPr id="3" name="TextBox 2"/>'));
    expect(slide, contains('<p:cNvSpPr txBox="1"/>'));
    expect(slide, contains('<p:cNvPr id="4" name="Rectangle 3"/>'));
    expect(slide, contains('<p:cNvPr id="5" name="Picture 4"/>'));
    expect(slide, contains('<p:cNvPr id="6" name="Straight Connector 5"/>'));
    expect(RegExp('txBox="1"').allMatches(slide), hasLength(1));
  });

  test('a shape states everything it shows', () {
    final slide = _slide([
      ShapeElement(
        id: 0,
        frame: _frame,
        rotation: 90,
        kind: ShapeKind.star,
        fill: 0x80FF0000,
        strokeWidth: 2,
        flipH: true,
        anchor: TextAnchor.middle,
        autoFit: true,
        text: TextBody([
          Paragraph.plain(
            'Point',
            const RunStyle(size: 20, bold: true),
            bullet: BulletKind.bullet,
            level: 1,
          ),
        ]),
      ),
    ]);

    expect(slide, contains('<a:xfrm rot="5400000" flipH="1">'));
    expect(slide, contains('<a:off x="127000" y="254000"/>'));
    expect(slide, contains('<a:ext cx="3810000" cy="1270000"/>'));
    expect(slide, contains('<a:prstGeom prst="star5"><a:avLst/></a:prstGeom>'));
    expect(
      slide,
      contains(
        '<a:solidFill><a:srgbClr val="FF0000"><a:alpha val="50196"/>'
        '</a:srgbClr></a:solidFill>',
      ),
    );
    expect(slide, contains('<a:ln w="25400"><a:noFill/></a:ln>'));
    expect(
      slide,
      contains(
        '<a:bodyPr wrap="square" lIns="91440" tIns="45720" rIns="91440" '
        'bIns="45720" anchor="ctr" rtlCol="0"><a:spAutoFit/></a:bodyPr>'
        '<a:lstStyle/>',
      ),
    );
    // Level 1 is 36 pt in, plus a hanging indent of 0.9 x 20 pt.
    expect(
      slide,
      contains('<a:pPr marL="685800" indent="-228600" lvl="1" algn="l">'),
    );
    expect(slide, contains('<a:lnSpc><a:spcPct val="100000"/></a:lnSpc>'));
    expect(slide, contains('<a:spcBef><a:spcPts val="0"/></a:spcBef>'));
    expect(slide, contains('<a:spcAft><a:spcPts val="0"/></a:spcAft>'));
    expect(
      slide,
      contains('<a:buFont typeface="Arial"/><a:buChar char="&#8226;"/>'),
    );
    expect(
      slide,
      contains(
        '<a:rPr lang="en-US" sz="2000" b="1" i="0" u="none" '
        'strike="noStrike" dirty="0"><a:solidFill><a:srgbClr val="000000"/>'
        '</a:solidFill><a:latin typeface="Arial"/><a:cs typeface="Arial"/>'
        '</a:rPr><a:t>Point</a:t>',
      ),
    );
  });

  test('numbers hang further than bullets and plain text does not hang', () {
    final slide = _slide([
      _shape(
        '',
        body: TextBody([
          Paragraph.plain(
            'One',
            const RunStyle(size: 10),
            bullet: BulletKind.number,
          ),
          Paragraph.plain('Plain', const RunStyle(size: 10), level: 2),
        ]),
      ),
    ]);

    expect(slide, contains('<a:pPr marL="203200" indent="-203200" lvl="0"'));
    expect(
      slide,
      contains(
        '<a:buFont typeface="+mj-lt"/><a:buAutoNum type="arabicPeriod"/>',
      ),
    );
    expect(slide, contains('<a:pPr marL="914400" indent="0" lvl="2"'));
    expect(slide, contains('<a:buNone/>'));
  });

  test('a line is a connector with its arrow heads', () {
    final slide = _slide([
      ShapeElement(
        id: 0,
        frame: _frame,
        kind: ShapeKind.line,
        stroke: 0xFF00FF00,
        flipV: true,
        endArrow: true,
        text: TextBody.empty(),
      ),
    ]);

    expect(slide, contains('<p:cxnSp>'));
    expect(slide, contains('<a:xfrm flipV="1">'));
    expect(slide, contains('<a:prstGeom prst="line">'));
    expect(
      slide,
      contains(
        '<a:ln w="12700"><a:solidFill><a:srgbClr val="00FF00"/></a:solidFill>'
        '<a:headEnd type="none"/><a:tailEnd type="triangle"/></a:ln>',
      ),
    );
    expect(slide, isNot(contains('<p:txBody>')));
  });

  test('a cropped picture carries its source rectangle', () {
    final image = ImageData(pictureBytes, 'png');
    final slide = _slide([
      ImageElement(
        id: 0,
        frame: _frame,
        image: image,
        crop: const Rect.fromLTRB(0.25, 0, 0.1, 0.5),
      ),
      ImageElement(id: 0, frame: _frame, image: image),
    ]);

    expect(slide, contains('<a:srcRect l="25000" r="10000" b="50000"/>'));
    expect(RegExp('<a:srcRect').allMatches(slide), hasLength(1));
    expect(
      RegExp(
        '<a:stretch><a:fillRect/></a:stretch></p:blipFill>',
      ).allMatches(slide),
      hasLength(2),
    );
  });

  test('the background is always written', () {
    final parts = _parts(_deck());

    expect(
      parts[slidePath(1)],
      contains(
        '<p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>'
        '<a:effectLst/></p:bgPr></p:bg>',
      ),
    );
    expect(
      parts[slidePath(4)],
      contains('<p:bg><p:bgPr><a:blipFill dpi="0" rotWithShape="1">'),
    );
  });

  test('text is escaped and characters XML cannot hold are dropped', () {
    const text = 'a < b & "c" > d\u0001￿\t!';
    final bytes = writePptx(_one([_shape(text)]));

    final slide = utf8.decode(unzip(bytes)[slidePath(1)]!);
    final read = readPptx(bytes).presentation.slides.single;

    expect(slide, contains('a &lt; b &amp; "c" &gt; d\t!'));
    expect(shapeAt(read, 0).text.text, 'a < b & "c" > d\t!');
  });

  test('a font name cannot break out of its attribute', () {
    const font = 'Odd "<Font>" & Co';
    final bytes = writePptx(
      _one([
        _shape('', body: TextBody.plain('Text', const RunStyle(font: font))),
      ]),
    );

    expect(
      styleAt(shapeAt(readPptx(bytes).presentation.slides.single, 0)).font,
      font,
    );
  });

  test('an odd picture extension cannot name another kind of part', () {
    final all = unzip(
      writePptx(
        _one([
          ImageElement(
            id: 0,
            frame: _frame,
            image: ImageData(pictureBytes, '../x.xml'),
          ),
          ImageElement(
            id: 0,
            frame: _frame,
            image: ImageData(pictureBytes, 'RELS'),
          ),
        ]),
      ),
    );

    expect(all.keys.where((name) => name.contains('media')), [
      'ppt/media/image1.bin',
      'ppt/media/image2.bin',
    ]);
  });

  test('numbers that are not finite do not break the file', () {
    final bytes = writePptx(
      _one([
        ShapeElement(
          id: 0,
          frame: const Rect.fromLTWH(double.nan, 0, double.infinity, 10),
          rotation: double.nan,
          strokeWidth: double.infinity,
          text: TextBody([
            Paragraph(
              runs: const [TextRun('x', RunStyle(size: double.nan))],
              lineSpacing: double.nan,
              spaceBefore: double.infinity,
            ),
          ]),
        ),
      ]),
    );

    expect(readPptx(bytes).presentation.slides.single.elements, hasLength(1));
  });
}
