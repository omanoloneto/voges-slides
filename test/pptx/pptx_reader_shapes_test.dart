import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/deck/element.dart';
import 'package:voges_slides/deck/presentation.dart';
import 'package:voges_slides/deck/text_body.dart';
import 'package:voges_slides/files/pptx/pptx_import.dart';

import 'fixtures.dart';

final _frame = xfrm(10, 10, 300, 100);

const _invertedMap =
    'bg1="dk1" tx1="lt1" bg2="dk2" tx2="lt2" accent1="accent1" '
    'accent2="accent2" accent3="accent3" accent4="accent4" '
    'accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"';

PptxImport _readShapes(String shapes) =>
    read(deckParts(slides: [SlideFixture(shapes: shapes)]));

String _connector(String spPr, {int id = 7}) =>
    '<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="$id" name="Line $id"/>'
    '<p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr>$spPr</p:spPr></p:cxnSp>';

/// A `p:grpSp`; [transform] is its whole `a:xfrm`.
String _group(String transform, String children, {String fill = ''}) =>
    '<p:grpSp><p:nvGrpSpPr><p:cNvPr id="20" name="Group"/><p:cNvGrpSpPr/>'
    '<p:nvPr/></p:nvGrpSpPr><p:grpSpPr>$transform$fill</p:grpSpPr>'
    '$children</p:grpSp>';

String _childSpace(num x, num y, num width, num height) =>
    '<a:chOff x="${emu(x)}" y="${emu(y)}"/>'
    '<a:chExt cx="${emu(width)}" cy="${emu(height)}"/>';

String _background(String fill) =>
    '<p:bg><p:bgPr>$fill<a:effectLst/></p:bgPr></p:bg>';

const _pictureFill =
    '<a:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/>'
    '</a:stretch></a:blipFill>';

/// A deck of one slide whose `rId2` is the picture at [target].
Map<String, Object> _pictureDeck(
  String shapes, {
  String target = '../media/image1.png',
  String background = '',
}) => {
  ...deckParts(
    slides: [
      SlideFixture(
        shapes: shapes,
        background: background,
        relationships: relationship('rId2', 'image', target),
      ),
    ],
  ),
  'ppt/media/image1.png': pictureBytes,
};

void main() {
  group('placeholders', () {
    test('a placeholder takes its place from the layout or the master', () {
      final slides = read(
        deckParts(
          masterShapes:
              sp(ph: '<p:ph type="title"/>', spPr: xfrm(10, 20, 300, 40)) +
              sp(
                id: 3,
                ph: '<p:ph type="body" idx="1"/>',
                spPr:
                    '${xfrm(10, 80, 300, 200)}${solid('00FF00')}'
                    '<a:ln w="25400">${solid('0000FF')}</a:ln>',
              ),
          layoutShapes:
              sp(ph: '<p:ph type="title"/>') +
              sp(id: 3, ph: '<p:ph idx="1"/>', spPr: xfrm(50, 90, 200, 100)),
          slides: [
            SlideFixture(
              shapes:
                  sp(
                    ph: '<p:ph type="title"/>',
                    text: txBody(para(run('Title'))),
                  ) +
                  sp(
                    id: 3,
                    ph: '<p:ph idx="1"/>',
                    text: txBody(para(run('Body'))),
                  ),
            ),
            SlideFixture(
              shapes: sp(
                ph: '<p:ph type="title"/>',
                spPr: xfrm(1, 2, 3, 4) + solid('FF0000'),
              ),
            ),
          ],
        ),
      ).presentation.slides;

      final title = shapeAt(slides[0], 0);
      expectFrame(title.frame, const Rect.fromLTWH(10, 20, 300, 40));
      expect(title.placeholder, PlaceholderKind.title);
      expect(title.fill, isNull);
      expect(title.stroke, isNull);
      expect(title.locked, isFalse);
      final body = shapeAt(slides[0], 1);
      expectFrame(body.frame, const Rect.fromLTWH(50, 90, 200, 100));
      expect(body.placeholder, PlaceholderKind.body);
      expect(body.fill, 0xFF00FF00);
      expect(body.stroke, 0xFF0000FF);
      expect(body.strokeWidth, 2);
      expect(slides[0].elements, hasLength(2));

      final moved = shapeAt(slides[1], 0);
      expectFrame(moved.frame, const Rect.fromLTWH(1, 2, 3, 4));
      expect(moved.fill, 0xFFFF0000);
    });

    test('a title slide gives a title and a subtitle', () {
      final slide = read(
        deckParts(
          masterShapes:
              sp(ph: '<p:ph type="title"/>', spPr: xfrm(1, 1, 10, 10)) +
              sp(
                id: 3,
                ph: '<p:ph type="body" idx="1"/>',
                spPr: xfrm(2, 2, 20, 20),
              ),
          layoutShapes:
              sp(ph: '<p:ph type="ctrTitle"/>', spPr: xfrm(5, 5, 100, 20)) +
              sp(id: 3, ph: '<p:ph type="subTitle" idx="1"/>'),
          slides: [
            SlideFixture(
              shapes:
                  sp(ph: '<p:ph type="ctrTitle"/>') +
                  sp(id: 3, ph: '<p:ph type="subTitle" idx="1"/>'),
            ),
          ],
        ),
      ).presentation.slides.single;

      expect(shapeAt(slide, 0).placeholder, PlaceholderKind.title);
      expectFrame(shapeAt(slide, 0).frame, const Rect.fromLTWH(5, 5, 100, 20));
      expect(shapeAt(slide, 1).placeholder, PlaceholderKind.subtitle);
      expectFrame(shapeAt(slide, 1).frame, const Rect.fromLTWH(2, 2, 20, 20));
    });

    test('dates, footers and numbers show only when they hold text', () {
      final result = read(
        deckParts(
          masterShapes: sp(
            ph: '<p:ph type="sldNum" sz="quarter" idx="12"/>',
            spPr: xfrm(600, 500, 100, 30),
          ),
          slides: [
            SlideFixture(
              shapes:
                  sp(
                    ph: '<p:ph type="sldNum" sz="quarter" idx="12"/>',
                    text: txBody(
                      para(
                        '<a:fld id="{0}" type="slidenum"><a:t>3</a:t>'
                        '</a:fld>',
                      ),
                    ),
                  ) +
                  sp(
                    id: 3,
                    ph: '<p:ph type="ftr" sz="quarter" idx="11"/>',
                    spPr: _frame,
                    text: txBody(para('')),
                  ) +
                  sp(id: 4, ph: '<p:ph type="dt" sz="half" idx="10"/>'),
            ),
          ],
        ),
      );

      final number = shapeAt(result.presentation.slides.single, 0);
      expect(result.presentation.slides.single.elements, hasLength(1));
      expect(number.text.text, '3');
      expect(number.placeholder, isNull);
      expectFrame(number.frame, const Rect.fromLTWH(600, 500, 100, 30));
      expect(result.losses, isEmpty);
    });

    test('a shape with no place on the slide is left out', () {
      final result = _readShapes(
        sp(text: txBody(para(run('Nowhere')))) +
            sp(id: 3, ph: '<p:ph type="title"/>') +
            sp(
              id: 4,
              spPr:
                  '<a:xfrm><a:off x="0" y="0"/><a:ext cx="-5" cy="10"/>'
                  '</a:xfrm>',
            ) +
            sp(
              id: 5,
              spPr:
                  '<a:xfrm><a:off x="many" y="0"/><a:ext cx="5" cy="10"/>'
                  '</a:xfrm>',
            ) +
            sp(id: 6, spPr: _frame),
      );

      expect(result.presentation.slides.single.elements, hasLength(1));
    });
  });

  group('master and layout decoration', () {
    final decorated = deckParts(
      masterShapes:
          sp(
            spPr: xfrm(0, 0, 50, 50) + preset('rect') + solid('FF0000'),
            text: txBody(para(run('Brand'))),
          ) +
          sp(id: 3, ph: '<p:ph type="title"/>', spPr: _frame),
      layoutShapes:
          sp(spPr: xfrm(60, 0, 50, 50) + preset('ellipse')) +
          sp(id: 3, ph: '<p:ph type="title"/>'),
      slides: [
        SlideFixture(shapes: sp(spPr: _frame)),
        SlideFixture(
          shapes: sp(spPr: _frame),
          attributes: 'showMasterSp="0"',
        ),
        const SlideFixture(),
      ],
    );

    test('it lies under the slide content as locked elements', () {
      final result = read(decorated);
      final slide = result.presentation.slides.first;

      expect(slide.elements, hasLength(3));
      final brand = shapeAt(slide, 0);
      expect(brand.kind, ShapeKind.rectangle);
      expect(brand.locked, isTrue);
      expect(brand.fill, 0xFFFF0000);
      expect(brand.text.text, 'Brand');
      expect(brand.placeholder, isNull);
      expectFrame(brand.frame, const Rect.fromLTWH(0, 0, 50, 50));
      expect(shapeAt(slide, 1).kind, ShapeKind.ellipse);
      expect(shapeAt(slide, 1).locked, isTrue);
      expect(shapeAt(slide, 2).locked, isFalse);
      expect(result.losses, isEmpty);
    });

    test('a slide can hide it', () {
      final slides = read(decorated).presentation.slides;

      expect(slides[1].elements, hasLength(1));
      expect(slides[1].elements.single.locked, isFalse);
      expect(slides[2].elements, hasLength(2));
    });

    test('every copy gets an id of its own, counted from 1 as read', () {
      final slides = read(decorated).presentation.slides;
      final ids = [
        for (final slide in slides) ...[
          slide.id,
          for (final element in slide.elements) element.id,
        ],
      ];

      expect(ids, [for (var id = 1; id <= 9; id++) id]);
    });

    test('a layout can hide what the master draws', () {
      final slide = read(
        deckParts(
          masterShapes: sp(spPr: xfrm(0, 0, 50, 50) + preset('rect')),
          layoutShapes: sp(spPr: xfrm(60, 0, 50, 50) + preset('ellipse')),
          layoutAttributes: 'showMasterSp="0"',
          slides: [SlideFixture(shapes: sp(spPr: _frame + preset('diamond')))],
        ),
      ).presentation.slides.single;

      expect(
        [for (final element in slide.elements) (element as ShapeElement).kind],
        [ShapeKind.ellipse, ShapeKind.diamond],
      );
    });

    test('its colors follow the color map of the slide', () {
      final slides = read(
        deckParts(
          masterShapes: sp(spPr: _frame + scheme('bg1')),
          slides: [
            const SlideFixture(),
            const SlideFixture(
              after:
                  '<p:clrMapOvr><a:overrideClrMapping $_invertedMap/>'
                  '</p:clrMapOvr>',
            ),
            const SlideFixture(),
          ],
        ),
      ).presentation.slides;

      expect(
        [for (final slide in slides) shapeAt(slide, 0).fill],
        [0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF],
      );
    });
  });

  group('shapes', () {
    test('preset geometries map to the kinds the app draws', () {
      const presets = {
        'rect': ShapeKind.rectangle,
        'roundRect': ShapeKind.roundedRectangle,
        'ellipse': ShapeKind.ellipse,
        'triangle': ShapeKind.triangle,
        'rtTriangle': ShapeKind.rightTriangle,
        'diamond': ShapeKind.diamond,
        'pentagon': ShapeKind.pentagon,
        'hexagon': ShapeKind.hexagon,
        'star5': ShapeKind.star,
        'rightArrow': ShapeKind.rightArrow,
        'leftArrow': ShapeKind.leftArrow,
        'upArrow': ShapeKind.upArrow,
        'downArrow': ShapeKind.downArrow,
        'line': ShapeKind.line,
      };
      final result = _readShapes(
        [
          for (final name in presets.keys) sp(spPr: _frame + preset(name)),
          sp(spPr: _frame),
        ].join(),
      );

      expect(
        [
          for (final element in result.presentation.slides.single.elements)
            (element as ShapeElement).kind,
        ],
        [...presets.values, ShapeKind.rectangle],
      );
      expect(result.losses, isEmpty);
    });

    test('a geometry the app does not have is drawn close and reported', () {
      void expectClose(String geometry, ShapeKind kind) {
        final result = _readShapes(sp(spPr: _frame + geometry));

        expect(
          shapeAt(result.presentation.slides.single, 0).kind,
          kind,
          reason: geometry,
        );
        expect(result.losses, {ImportLoss.shapes}, reason: geometry);
      }

      expectClose(preset('cloud'), ShapeKind.rectangle);
      expectClose(preset('star8'), ShapeKind.star);
      expectClose('<a:custGeom><a:pathLst/></a:custGeom>', ShapeKind.rectangle);
    });

    test('fill, outline, rotation and flips are read', () {
      final result = _readShapes(
        sp(
              spPr: [
                xfrm(10, 20, 30, 40, attributes: 'rot="2700000" flipH="1"'),
                preset('rect'),
                solid('102030'),
                '<a:ln w="38100">${solid('405060')}</a:ln>',
              ].join(),
            ) +
            sp(
              id: 3,
              spPr: [
                xfrm(0, 0, 10, 10, attributes: 'rot="-5400000" flipV="1"'),
                '<a:noFill/><a:ln><a:noFill/></a:ln>',
              ].join(),
            ) +
            sp(id: 4, spPr: '$_frame<a:ln>${solid('405060')}</a:ln>'),
      );
      final slide = result.presentation.slides.single;

      final first = shapeAt(slide, 0);
      expectFrame(first.frame, const Rect.fromLTWH(10, 20, 30, 40));
      expect(first.rotation, 45);
      expect(first.flipH, isTrue);
      expect(first.flipV, isFalse);
      expect(first.fill, 0xFF102030);
      expect(first.stroke, 0xFF405060);
      expect(first.strokeWidth, 3);
      final second = shapeAt(slide, 1);
      expect(second.rotation, 270);
      expect(second.flipV, isTrue);
      expect(second.fill, isNull);
      expect(second.stroke, isNull);
      expect(shapeAt(slide, 2).strokeWidth, 0.75);
      expect(result.losses, isEmpty);
    });

    test('a gradient becomes its first color and is reported', () {
      final result = _readShapes(
        sp(
          spPr:
              '$_frame<a:gradFill><a:gsLst>'
              '<a:gs pos="0"><a:srgbClr val="AA0000"/></a:gs>'
              '<a:gs pos="100000"><a:srgbClr val="0000AA"/></a:gs>'
              '</a:gsLst></a:gradFill>',
        ),
      );

      expect(shapeAt(result.presentation.slides.single, 0).fill, 0xFFAA0000);
      expect(result.losses, {ImportLoss.shapes});
    });

    test('a shape style gives the fill, outline and font it points to', () {
      String style(int line) =>
          '<p:style><a:lnRef idx="$line"><a:schemeClr val="accent1"/>'
          '</a:lnRef><a:fillRef idx="1"><a:schemeClr val="accent2"/>'
          '</a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent1"/>'
          '</a:effectRef><a:fontRef idx="major"><a:schemeClr val="lt1"/>'
          '</a:fontRef></p:style>';
      final result = read(
        deckParts(
          theme: themeXml(
            major: 'Georgia',
            lines: '<a:ln w="6350"/><a:ln w="12700"/><a:ln w="19050"/>',
          ),
          slides: [
            SlideFixture(
              shapes:
                  sp(
                    spPr: _frame,
                    style: style(2),
                    text: txBody(para(run('Styled'))),
                  ) +
                  sp(
                    id: 3,
                    spPr: '$_frame<a:noFill/><a:ln w="38100"/>',
                    style: style(3),
                  ) +
                  sp(id: 4, spPr: _frame, style: style(0)),
            ),
          ],
        ),
      );
      final slide = result.presentation.slides.single;

      final styled = shapeAt(slide, 0);
      expect(styled.fill, 0xFFED7D31);
      expect(styled.stroke, 0xFF4472C4);
      expect(styled.strokeWidth, 1);
      expect(
        styleAt(styled),
        const RunStyle(font: 'Georgia', color: 0xFFFFFFFF),
      );
      final own = shapeAt(slide, 1);
      expect(own.fill, isNull);
      expect(own.stroke, 0xFF4472C4);
      expect(own.strokeWidth, 3);
      expect(shapeAt(slide, 2).stroke, isNull);
      expect(result.losses, isEmpty);
    });

    test('a hidden shape is left out without a word', () {
      final result = _readShapes(
        sp(spPr: _frame, nameAttributes: 'hidden="1"') +
            sp(id: 3, spPr: _frame),
      );

      expect(result.presentation.slides.single.elements, hasLength(1));
      expect(result.losses, isEmpty);
    });

    test('vertical text is reported', () {
      final result = _readShapes(
        sp(
          spPr: _frame,
          text: txBody(para(run('x')), bodyPr: '<a:bodyPr vert="vert270"/>'),
        ),
      );

      expect(result.losses, {ImportLoss.shapes});
    });
  });

  group('lines', () {
    test('a rotated line is read as the line between its two ends', () {
      final result = _readShapes(
        _connector(
              [
                xfrm(100, 100, 100, 0, attributes: 'rot="5400000"'),
                preset('line'),
                '<a:ln w="25400">${solid('FF0000')}',
                '<a:headEnd type="triangle"/><a:tailEnd type="none"/></a:ln>',
              ].join(),
            ) +
            _connector(
              [
                xfrm(100, 100, 100, 0, attributes: 'rot="10800000"'),
                preset('straightConnector1'),
                '<a:ln><a:tailEnd type="arrow"/></a:ln>',
              ].join(),
              id: 8,
            ) +
            _connector(
              xfrm(0, 0, 40, 30, attributes: 'flipV="1"') + preset('line'),
              id: 9,
            ),
      );
      final slide = result.presentation.slides.single;

      final turned = shapeAt(slide, 0);
      expect(turned.kind, ShapeKind.line);
      expectFrame(turned.frame, const Rect.fromLTWH(150, 50, 0, 100));
      expect(turned.rotation, 0);
      expect(turned.flipH, isFalse);
      expect(turned.flipV, isFalse);
      expect(turned.stroke, 0xFFFF0000);
      expect(turned.strokeWidth, 2);
      expect(turned.startArrow, isTrue);
      expect(turned.endArrow, isFalse);
      expect(turned.autoFit, isFalse);

      final reversed = shapeAt(slide, 1);
      expectFrame(reversed.frame, const Rect.fromLTWH(100, 100, 100, 0));
      expect(reversed.flipH, isTrue);
      expect(reversed.rotation, 0);
      expect(reversed.startArrow, isFalse);
      expect(reversed.endArrow, isTrue);

      final plain = shapeAt(slide, 2);
      expectFrame(plain.frame, const Rect.fromLTWH(0, 0, 40, 30));
      expect(plain.flipV, isTrue);
      expect(plain.stroke, isNull);
      expect(result.losses, isEmpty);
    });

    test('a shape with the line geometry is a line too', () {
      final result = _readShapes(
        sp(
          spPr: [
            xfrm(0, 0, 100, 100, attributes: 'rot="5400000"'),
            preset('line'),
            '<a:ln>${solid('000000')}</a:ln>',
          ].join(),
          text: txBody(para(run('Label'))),
        ),
      );

      final line = shapeAt(result.presentation.slides.single, 0);
      expect(line.kind, ShapeKind.line);
      expectFrame(line.frame, const Rect.fromLTWH(0, 0, 100, 100));
      expect(line.flipH, isTrue);
      expect(line.flipV, isFalse);
      expect(line.rotation, 0);
      expect(line.text.text, '');
    });

    test('a routed connector becomes a straight line and is reported', () {
      final result = _readShapes(
        _connector(xfrm(0, 0, 40, 30) + preset('bentConnector3')),
      );

      expect(
        shapeAt(result.presentation.slides.single, 0).kind,
        ShapeKind.line,
      );
      expect(result.losses, {ImportLoss.shapes});
    });
  });

  group('groups', () {
    test('a group is flattened with its children scaled into place', () {
      final result = _readShapes(
        _group(
          xfrm(100, 100, 200, 100, children: _childSpace(0, 0, 400, 200)),
          sp(spPr: '${xfrm(40, 20, 100, 60)}${preset('ellipse')}<a:grpFill/>') +
              _group(
                xfrm(200, 100, 100, 50, children: _childSpace(0, 0, 100, 50)),
                sp(id: 3, spPr: '${xfrm(10, 10, 20, 10)}<a:grpFill/>'),
              ) +
              _connector(xfrm(0, 200, 400, 0) + preset('line'), id: 4),
          fill: solid('00AA00'),
        ),
      );
      final slide = result.presentation.slides.single;

      expect(slide.elements, hasLength(3));
      expectFrame(
        shapeAt(slide, 0).frame,
        const Rect.fromLTWH(120, 110, 50, 30),
      );
      expect(shapeAt(slide, 0).kind, ShapeKind.ellipse);
      expect(shapeAt(slide, 0).fill, 0xFF00AA00);
      expectFrame(
        shapeAt(slide, 1).frame,
        const Rect.fromLTWH(205, 155, 10, 5),
      );
      expect(shapeAt(slide, 1).fill, isNull);
      expectFrame(
        shapeAt(slide, 2).frame,
        const Rect.fromLTWH(100, 200, 200, 0),
      );
      expect(result.losses, isEmpty);
    });

    test('a turned group turns its children around its center', () {
      final result = _readShapes(
        _group(
          xfrm(
            100,
            100,
            200,
            100,
            attributes: 'rot="5400000"',
            children: _childSpace(100, 100, 200, 100),
          ),
          sp(spPr: xfrm(100, 100, 50, 20)),
        ),
      );

      final shape = shapeAt(result.presentation.slides.single, 0);
      expectFrame(shape.frame, const Rect.fromLTWH(215, 65, 50, 20));
      expect(shape.rotation, 90);
      expect(result.losses, {ImportLoss.shapes});
    });

    test('a group without a transform leaves its children where they are', () {
      final slide = _readShapes(
        _group('', sp(spPr: xfrm(40, 20, 100, 60))),
      ).presentation.slides.single;

      expectFrame(
        shapeAt(slide, 0).frame,
        const Rect.fromLTWH(40, 20, 100, 60),
      );
    });

    test('groups nested without end are cut off, not followed forever', () {
      var nested = sp(spPr: _frame);
      for (var depth = 0; depth < 40; depth++) {
        nested = _group(
          xfrm(0, 0, 100, 100, children: _childSpace(0, 0, 100, 100)),
          nested,
        );
      }

      final result = _readShapes(nested + sp(id: 3, spPr: _frame));

      expect(result.presentation.slides.single.elements, hasLength(1));
      expect(result.losses, {ImportLoss.content});
    });
  });

  group('pictures', () {
    test('a picture is read with its crop and shared when shown twice', () {
      final result = read(
        _pictureDeck(
          pic(
                'rId2',
                spPr: xfrm(10, 20, 100, 50, attributes: 'rot="1800000"'),
                source: '<a:srcRect l="10000" t="20000" r="30000" b="40000"/>',
              ) +
              pic('rId2', spPr: xfrm(0, 0, 10, 10), id: 10),
        ),
      );
      final slide = result.presentation.slides.single;

      final first = slide.elements[0] as ImageElement;
      final second = slide.elements[1] as ImageElement;
      expectFrame(first.frame, const Rect.fromLTWH(10, 20, 100, 50));
      expect(first.rotation, 30);
      expect(first.crop.left, closeTo(0.1, 1e-9));
      expect(first.crop.top, closeTo(0.2, 1e-9));
      expect(first.crop.right, closeTo(0.3, 1e-9));
      expect(first.crop.bottom, closeTo(0.4, 1e-9));
      expect(first.image.bytes, pictureBytes);
      expect(first.image.extension, 'png');
      expect(second.image, same(first.image));
      expect(second.crop, Rect.zero);
      expect(result.losses, isEmpty);
    });

    test('a picture the app cannot draw is kept and reported', () {
      final parts = _pictureDeck(
        pic('rId2', spPr: _frame),
        target: '../media/Drawing.EMF',
      )..['ppt/media/Drawing.EMF'] = [1, 2, 3];

      final result = read(parts);

      final picture =
          result.presentation.slides.single.elements.single as ImageElement;
      expect(picture.image.bytes, [1, 2, 3]);
      expect(picture.image.extension, 'emf');
      expect(result.losses, {ImportLoss.images});
    });

    test('a picture whose file is not there is left out and reported', () {
      for (final shapes in [
        pic('rId2', spPr: _frame),
        pic('rId7', spPr: _frame),
      ]) {
        final parts = _pictureDeck(shapes, target: '../media/missing.png');

        final result = read(parts);

        expect(result.presentation.slides.single.elements, isEmpty);
        expect(result.losses, {ImportLoss.images});
      }
    });

    test('a video keeps its poster picture and is reported', () {
      final result = read(
        _pictureDeck(
          '<p:pic><p:nvPicPr><p:cNvPr id="4" name="Video"/><p:cNvPicPr/>'
          '<p:nvPr><a:videoFile r:link="rId9"/></p:nvPr></p:nvPicPr>'
          '<p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/>'
          '</a:stretch></p:blipFill><p:spPr>$_frame</p:spPr></p:pic>',
        ),
      );

      expect(result.presentation.slides.single.elements, hasLength(1));
      expect(result.losses, {ImportLoss.content});
    });
  });

  group('background', () {
    int background({
      String slide = '',
      String layout = '',
      String master = '',
    }) => read(
      deckParts(
        masterBackground: master,
        layoutBackground: layout,
        slides: [SlideFixture(background: slide)],
      ),
    ).presentation.slides.single.background;

    test('it comes from the slide, then the layout, then the master', () {
      final master = _background(solid('0000FF'));
      final layout = _background(solid('00FF00'));
      final slide = _background(solid('FF0000'));

      expect(background(), 0xFFFFFFFF);
      expect(background(master: master), 0xFF0000FF);
      expect(background(master: master, layout: layout), 0xFF00FF00);
      expect(
        background(master: master, layout: layout, slide: slide),
        0xFFFF0000,
      );
    });

    test('a reference to the theme follows the color map of the slide', () {
      final slides = read(
        deckParts(
          theme: themeXml(colors: {'lt1': 'FFEEDD', 'dk1': '112233'}),
          masterBackground:
              '<p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef>'
              '</p:bg>',
          slides: [
            const SlideFixture(),
            const SlideFixture(
              after:
                  '<p:clrMapOvr><a:overrideClrMapping $_invertedMap/>'
                  '</p:clrMapOvr>',
            ),
            const SlideFixture(),
          ],
        ),
      ).presentation.slides;

      expect(
        [for (final slide in slides) slide.background],
        [0xFFFFEEDD, 0xFF112233, 0xFFFFEEDD],
      );
    });

    test('a picture fills it', () {
      final result = read(
        _pictureDeck(
          pic('rId2', spPr: _frame),
          background: _background(_pictureFill),
        ),
      );
      final slide = result.presentation.slides.single;

      expect(slide.backgroundImage!.bytes, pictureBytes);
      expect(slide.background, 0xFFFFFFFF);
      expect(
        (slide.elements.single as ImageElement).image,
        same(slide.backgroundImage),
      );
      expect(result.losses, isEmpty);
    });

    test('a picture on the layout is shared by its slides', () {
      final parts =
          deckParts(
              layoutBackground: _background(_pictureFill),
              slides: [const SlideFixture(), const SlideFixture()],
            )
            ..['ppt/slideLayouts/_rels/slideLayout1.xml.rels'] =
                relationshipsPart(
                  relationship(
                        'rId1',
                        'slideMaster',
                        '../slideMasters/slideMaster1.xml',
                      ) +
                      relationship('rId2', 'image', '../media/image1.png'),
                )
            ..['ppt/media/image1.png'] = pictureBytes;

      final slides = read(parts).presentation.slides;

      expect(slides[0].backgroundImage!.bytes, pictureBytes);
      expect(slides[1].backgroundImage, same(slides[0].backgroundImage));
    });

    test('a gradient becomes its first color and is reported', () {
      final result = read(
        deckParts(
          slides: [
            SlideFixture(
              background: _background(
                '<a:gradFill><a:gsLst>'
                '<a:gs pos="0"><a:srgbClr val="AA0000"/></a:gs>'
                '<a:gs pos="100000"><a:srgbClr val="0000AA"/></a:gs>'
                '</a:gsLst></a:gradFill>',
              ),
            ),
          ],
        ),
      );

      expect(result.presentation.slides.single.background, 0xFFAA0000);
      expect(result.losses, {ImportLoss.shapes});
    });
  });

  group('what the app cannot keep', () {
    const table =
        '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="4" name="Table"/>'
        '<p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>'
        '<p:xfrm><a:off x="0" y="0"/><a:ext cx="100" cy="100"/></p:xfrm>'
        '<a:graphic><a:graphicData '
        'uri="http://schemas.openxmlformats.org/drawingml/2006/table">'
        '<a:tbl/></a:graphicData></a:graphic></p:graphicFrame>';

    test('a table or chart is left out and reported', () {
      final result = _readShapes(table + sp(spPr: _frame));

      expect(result.presentation.slides.single.elements, hasLength(1));
      expect(result.losses, {ImportLoss.content});
    });

    test('alternate content is read through its fallback', () {
      final result = _readShapes(
        '<mc:AlternateContent><mc:Choice Requires="p14">'
        '${sp(spPr: _frame + preset('ellipse'))}</mc:Choice><mc:Fallback>'
        '${sp(spPr: _frame + preset('diamond'))}</mc:Fallback>'
        '</mc:AlternateContent>'
        '<mc:AlternateContent><mc:Choice Requires="p14">'
        '${sp(id: 3, spPr: _frame + preset('hexagon'))}</mc:Choice>'
        '<mc:Choice Requires="p15">'
        '${sp(id: 4, spPr: _frame + preset('star5'))}</mc:Choice>'
        '</mc:AlternateContent>',
      );

      expect(
        [
          for (final element in result.presentation.slides.single.elements)
            (element as ShapeElement).kind,
        ],
        [ShapeKind.diamond, ShapeKind.hexagon],
      );
      expect(result.losses, isEmpty);
    });

    Set<ImportLoss> lossesWithNotes(String notesShapes) {
      final parts =
          deckParts(
              slides: [
                SlideFixture(
                  relationships: relationship(
                    'rId2',
                    'notesSlide',
                    '../notesSlides/notesSlide1.xml',
                  ),
                ),
              ],
            )
            ..['ppt/notesSlides/notesSlide1.xml'] = treePart(
              'notes',
              shapes: notesShapes,
            );
      return read(parts).losses;
    }

    test('speaker notes are reported when they hold text', () {
      final picture = sp(ph: '<p:ph type="sldImg"/>', spPr: _frame);
      final number = sp(
        id: 4,
        ph: '<p:ph type="sldNum" sz="quarter" idx="5"/>',
        text: txBody(para(run('1'))),
      );
      String notes(String text) => sp(
        id: 3,
        ph: '<p:ph type="body" idx="1"/>',
        text: txBody(para(text)),
      );

      expect(lossesWithNotes(picture + notes(run('Say hello')) + number), {
        ImportLoss.notes,
      });
      expect(lossesWithNotes(picture + notes('') + number), isEmpty);
      expect(lossesWithNotes(picture + notes(run('  ')) + number), isEmpty);
    });

    Set<ImportLoss> lossesAfterShapes(String after) =>
        read(deckParts(slides: [SlideFixture(after: after)])).losses;

    test('transitions and animations are reported', () {
      expect(
        lossesAfterShapes('<p:transition spd="slow"><p:fade/></p:transition>'),
        {ImportLoss.animations},
      );
      expect(
        lossesAfterShapes(
          '<p:timing><p:tnLst><p:par><p:cTn id="1" dur="indefinite" '
          'nodeType="tmRoot"/></p:par></p:tnLst></p:timing>',
        ),
        {ImportLoss.animations},
      );
      expect(
        lossesAfterShapes(
          '<mc:AlternateContent><mc:Choice Requires="p14">'
          '<p:transition spd="slow"/></mc:Choice><mc:Fallback>'
          '<p:transition spd="slow"/></mc:Fallback></mc:AlternateContent>',
        ),
        {ImportLoss.animations},
      );
      expect(lossesAfterShapes('<p:timing/>'), isEmpty);
      expect(lossesAfterShapes(''), isEmpty);
    });
  });

  group('presentation', () {
    test('the slide size is read in points', () {
      Size sizeOf(String size) => read(deckParts(size: size)).presentation.size;

      expect(
        sizeOf('<p:sldSz cx="9144000" cy="6858000" type="screen4x3"/>'),
        const Size(720, 540),
      );
      expect(sizeOf(''), defaultSlideSize);
      expect(sizeOf('<p:sldSz cx="0" cy="6858000"/>'), defaultSlideSize);
    });

    test('slides come in the order the presentation lists them', () {
      final parts = deckParts(
        slides: [
          SlideFixture(shapes: sp(spPr: _frame + preset('ellipse'))),
          SlideFixture(shapes: sp(spPr: _frame + preset('diamond'))),
        ],
      );
      parts[presentationPath] = (parts[presentationPath]! as String)
          .replaceFirst('r:id="rId3"', 'r:id="rIdX"')
          .replaceFirst('r:id="rId4"', 'r:id="rId3"')
          .replaceFirst('r:id="rIdX"', 'r:id="rId4"');

      final slides = read(parts).presentation.slides;

      expect(
        [for (final slide in slides) shapeAt(slide, 0).kind],
        [ShapeKind.diamond, ShapeKind.ellipse],
      );
    });

    test('a strict Open XML file is read like a transitional one', () {
      const transitional = 'http://schemas.openxmlformats.org';
      const strict = 'http://purl.oclc.org/ooxml';
      final parts = _pictureDeck(
        sp(ph: '<p:ph type="title"/>', text: txBody(para(run('Strict')))) +
            pic('rId2', spPr: _frame),
      );
      parts[layoutPath] = treePart(
        'sldLayout',
        shapes: sp(
          ph: '<p:ph type="title"/>',
          spPr: xfrm(5, 6, 70, 80) + scheme('accent1'),
        ),
      );

      final result = read({
        for (final part in parts.entries)
          part.key: part.value is String
              ? (part.value as String)
                    .replaceAll(
                      '$transitional/drawingml/2006/main',
                      '$strict/drawingml/main',
                    )
                    .replaceAll(
                      '$transitional/presentationml/2006/main',
                      '$strict/presentationml/main',
                    )
                    .replaceAll(
                      '$transitional/officeDocument/2006/relationships',
                      '$strict/officeDocument/relationships',
                    )
              : part.value,
      });
      final slide = result.presentation.slides.single;

      expect(slide.elements, hasLength(2));
      final title = shapeAt(slide, 0);
      expect(title.text.text, 'Strict');
      expect(title.placeholder, PlaceholderKind.title);
      expect(title.fill, 0xFF4472C4);
      expectFrame(title.frame, const Rect.fromLTWH(5, 6, 70, 80));
      expect((slide.elements[1] as ImageElement).image.bytes, pictureBytes);
      expect(result.losses, isEmpty);
    });

    test('a presentation without slides opens with an empty one', () {
      final result = read(deckParts(slides: const []));

      final slide = result.presentation.slides.single;
      expect(slide.elements, isEmpty);
      expect(slide.background, 0xFFFFFFFF);
      expect(result.losses, isEmpty);
    });
  });
}
