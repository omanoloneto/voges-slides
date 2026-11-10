import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/deck/element.dart';
import 'package:voges_slides/deck/text_body.dart';

import 'fixtures.dart';

final _frame = xfrm(10, 10, 300, 100);

const _invertedMap =
    'bg1="dk1" tx1="lt1" bg2="dk2" tx2="lt2" accent1="accent1" '
    'accent2="accent2" accent3="accent3" accent4="accent4" '
    'accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"';

/// An `a:lvlNpPr`: [run] holds the attributes of its `a:defRPr`,
/// [runChildren] what goes inside it and [before] what comes before it.
String _level(
  int level, {
  String attributes = '',
  String run = '',
  String runChildren = '',
  String before = '',
}) =>
    '<a:lvl${level}pPr $attributes>$before<a:defRPr $run>$runChildren'
    '</a:defRPr></a:lvl${level}pPr>';

String _latin(String typeface) => '<a:latin typeface="$typeface"/>';

/// A text box at [_frame] holding [text].
String _box(String text, {int id = 2}) => sp(id: id, spPr: _frame, text: text);

ShapeElement _readBox(String text) => shapeAt(readSlide(_box(text)), 0);

void main() {
  test('text styles come down the chain from the presentation to the run', () {
    final slide = read(
      deckParts(
        defaultTextStyle:
            _level(1, run: 'sz="1000" i="1"') + _level(2, run: 'i="1"'),
        masterStyles:
            '<p:titleStyle>'
            '${_level(1, attributes: 'algn="ctr"', run: 'sz="4000" b="1"')}'
            '</p:titleStyle>'
            '<p:bodyStyle>${_level(1, run: 'sz="2800"')}'
            '${_level(2, run: 'sz="2400"')}</p:bodyStyle>'
            '<p:otherStyle>${_level(1, run: 'sz="1200"')}</p:otherStyle>',
        masterShapes:
            sp(ph: '<p:ph type="title"/>', spPr: _frame) +
            sp(
              id: 3,
              ph: '<p:ph type="body" idx="1"/>',
              spPr: _frame,
              text: txBody(
                para(run('Master text')),
                lstStyle: _level(2, run: 'u="sng"'),
              ),
            ),
        layoutShapes: sp(
          ph: '<p:ph type="title"/>',
          text: txBody(
            para(run('Layout text')),
            lstStyle: _level(1, run: 'u="sng"'),
          ),
        ),
        slides: [
          SlideFixture(
            shapes:
                sp(
                  ph: '<p:ph type="title"/>',
                  text: txBody(
                    para(run('Title')) +
                        para(
                          run('Own', rPr: '<a:rPr sz="2000" b="0"/>'),
                          pPr: '<a:pPr algn="r"/>',
                        ),
                  ),
                ) +
                sp(
                  id: 3,
                  ph: '<p:ph idx="1"/>',
                  text: txBody(
                    para(run('First')) +
                        para(run('Second'), pPr: '<a:pPr lvl="1"/>'),
                    lstStyle: _level(2, run: 'strike="sngStrike"'),
                  ),
                ) +
                _box(txBody(para(run('Box'))), id: 4),
          ),
        ],
      ),
    ).presentation.slides.single;

    expect(slide.elements, hasLength(3));
    final title = shapeAt(slide, 0);
    expect(title.text.text, 'Title\nOwn');
    expect(
      styleAt(title),
      const RunStyle(size: 40, bold: true, italic: true, underline: true),
    );
    expect(title.text.paragraphs[0].align, ParagraphAlign.center);
    expect(
      styleAt(title, 1),
      const RunStyle(size: 20, italic: true, underline: true),
    );
    expect(title.text.paragraphs[1].align, ParagraphAlign.right);

    final body = shapeAt(slide, 1);
    expect(styleAt(body), const RunStyle(size: 28, italic: true));
    expect(body.text.paragraphs[0].align, ParagraphAlign.left);
    expect(
      styleAt(body, 1),
      const RunStyle(size: 24, italic: true, underline: true, strike: true),
    );
    expect(body.text.paragraphs[1].level, 1);

    expect(styleAt(shapeAt(slide, 2)), const RunStyle(size: 12, italic: true));
  });

  test('text nobody gave a size to is 18 points', () {
    final shape = _readBox(txBody(para(run('Text'))));

    expect(styleAt(shape), const RunStyle());
    expect(shape.text.paragraphs.single.bullet, BulletKind.none);
    expect(shape.text.paragraphs.single.lineSpacing, 1);
  });

  test('a color in a master style follows the color map of each slide', () {
    final title = sp(
      ph: '<p:ph type="title"/>',
      spPr: _frame,
      text: txBody(para(run('Title'))),
    );

    final slides = read(
      deckParts(
        colorMap: _invertedMap,
        masterStyles:
            '<p:titleStyle>'
            '${_level(1, runChildren: scheme('tx1'))}'
            '</p:titleStyle>',
        slides: [
          SlideFixture(shapes: title),
          SlideFixture(
            shapes: title,
            after:
                '<p:clrMapOvr><a:overrideClrMapping $defaultColorMap/>'
                '</p:clrMapOvr>',
          ),
          SlideFixture(
            shapes: title,
            after: '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>',
          ),
        ],
      ),
    ).presentation.slides;

    expect(styleAt(shapeAt(slides[0], 0)).color, 0xFFFFFFFF);
    expect(styleAt(shapeAt(slides[1], 0)).color, 0xFF000000);
    expect(styleAt(shapeAt(slides[2], 0)).color, 0xFFFFFFFF);
  });

  test('the layout can change the color map for its slides', () {
    final slide = read(
      deckParts(
        colorMap: _invertedMap,
        layoutAfter:
            '<p:clrMapOvr><a:overrideClrMapping $defaultColorMap/>'
            '</p:clrMapOvr>',
        slides: [
          SlideFixture(
            shapes: _box(
              txBody(para(run('x', rPr: '<a:rPr>${scheme('tx1')}</a:rPr>'))),
            ),
          ),
        ],
      ),
    ).presentation.slides.single;

    expect(styleAt(shapeAt(slide, 0)).color, 0xFF000000);
  });

  test('theme colors go through the color map and their transforms', () {
    const fills = [
      ('tx1', ''),
      ('bg1', ''),
      ('accent1', '<a:lumMod val="75000"/>'),
      ('accent1', '<a:lumMod val="60000"/><a:lumOff val="40000"/>'),
      ('bg1', '<a:tint val="40000"/>'),
      ('tx1', '<a:shade val="40000"/>'),
      ('accent1', '<a:alpha val="40000"/>'),
      ('lt1', '<a:shade val="40%"/>'),
    ];
    final slide = read(
      deckParts(
        theme: themeXml(colors: {'accent1': 'FF0000'}),
        colorMap: _invertedMap,
        slides: [
          SlideFixture(
            shapes: [
              for (final (name, transforms) in fills)
                sp(spPr: _frame + scheme(name, transforms)),
            ].join(),
          ),
        ],
      ),
    ).presentation.slides.single;

    expect(
      [for (final element in slide.elements) (element as ShapeElement).fill],
      [
        0xFFFFFFFF,
        0xFF000000,
        0xFFBF0000,
        0xFFFF6666,
        0xFF999999,
        0xFF666666,
        0x66FF0000,
        0xFF666666,
      ],
    );
  });

  test('colors that do not come from the theme are read too', () {
    String fill(String color) => '<a:solidFill>$color</a:solidFill>';
    final slide = readSlide(
      [
        fill('<a:srgbClr val="336699"><a:alpha val="40000"/></a:srgbClr>'),
        fill('<a:prstClr val="red"/>'),
        fill('<a:sysClr val="windowText" lastClr="112233"/>'),
        fill('<a:sysClr val="window"/>'),
        fill('<a:hslClr hue="7200000" sat="100000" lum="50000"/>'),
        fill('<a:scrgbClr r="100000" g="0" b="0"/>'),
        '<a:noFill/>',
        '',
      ].map((spPr) => sp(spPr: _frame + spPr)).join(),
    );

    expect(
      [for (final element in slide.elements) (element as ShapeElement).fill],
      [
        0x66336699,
        0xFFFF0000,
        0xFF112233,
        0xFFFFFFFF,
        0xFF00FF00,
        0xFFFF0000,
        null,
        null,
      ],
    );
  });

  test('theme fonts stand for the names that point to them', () {
    final slide = read(
      deckParts(
        theme: themeXml(major: 'Georgia', minor: 'Verdana'),
        masterStyles:
            '<p:titleStyle>'
            '${_level(1, runChildren: _latin('+mj-lt'))}</p:titleStyle>'
            '<p:bodyStyle>'
            '${_level(1, runChildren: _latin('+mn-lt'))}</p:bodyStyle>',
        slides: [
          SlideFixture(
            shapes:
                sp(
                  ph: '<p:ph type="title"/>',
                  spPr: _frame,
                  text: txBody(para(run('Title'))),
                ) +
                sp(
                  id: 3,
                  ph: '<p:ph type="body" idx="1"/>',
                  spPr: _frame,
                  text: txBody(para(run('Body'))),
                ) +
                _box(
                  txBody(
                    para(
                      run('Plain') +
                          run(
                            'Named',
                            rPr: '<a:rPr>${_latin('Courier New')}</a:rPr>',
                          ) +
                          run(
                            'Heading',
                            rPr: '<a:rPr>${_latin('+mj-lt')}</a:rPr>',
                          ),
                    ),
                  ),
                  id: 4,
                ),
          ),
        ],
      ),
    ).presentation.slides.single;

    expect(styleAt(shapeAt(slide, 0)).font, 'Georgia');
    expect(styleAt(shapeAt(slide, 1)).font, 'Verdana');
    final box = shapeAt(slide, 2);
    expect(
      [for (final run in box.text.paragraphs.single.runs) run.style.font],
      ['Verdana', 'Courier New', 'Georgia'],
    );
  });

  test('bullets are inherited and a paragraph can turn them off', () {
    final slide = read(
      deckParts(
        masterStyles:
            '<p:titleStyle>${_level(1)}</p:titleStyle>'
            '<p:bodyStyle>'
            '${_level(1, before: '<a:buChar char="&#8226;"/>')}'
            '${_level(2, before: '<a:buAutoNum type="arabicPeriod"/>')}'
            '${_level(3)}</p:bodyStyle>',
        slides: [
          SlideFixture(
            shapes:
                sp(
                  ph: '<p:ph type="title"/>',
                  spPr: _frame,
                  text: txBody(para(run('Title'))),
                ) +
                sp(
                  id: 3,
                  ph: '<p:ph type="body" idx="1"/>',
                  spPr: _frame,
                  text: txBody(
                    para(run('Inherited')) +
                        para(run('Off'), pPr: '<a:pPr><a:buNone/></a:pPr>') +
                        para(
                          run('Number'),
                          pPr:
                              '<a:pPr><a:buAutoNum type="alphaLcParenR"/>'
                              '</a:pPr>',
                        ) +
                        para(run('Second level'), pPr: '<a:pPr lvl="1"/>') +
                        para(run('Third level'), pPr: '<a:pPr lvl="2"/>') +
                        para(
                          run('Picture bullet'),
                          pPr: '<a:pPr lvl="2"><a:buBlip/></a:pPr>',
                        ),
                  ),
                ),
          ),
        ],
      ),
    ).presentation.slides.single;

    expect(shapeAt(slide, 0).text.paragraphs.single.bullet, BulletKind.none);
    expect(
      [
        for (final paragraph in shapeAt(slide, 1).text.paragraphs)
          paragraph.bullet,
      ],
      [
        BulletKind.bullet,
        BulletKind.none,
        BulletKind.number,
        BulletKind.number,
        BulletKind.none,
        BulletKind.bullet,
      ],
    );
    expect(
      [
        for (final paragraph in shapeAt(slide, 1).text.paragraphs)
          paragraph.level,
      ],
      [0, 0, 0, 1, 2, 2],
    );
  });

  test('text shrunk to fit is read at the size it is shown', () {
    final shape = _readBox(
      txBody(
        para(run('Big', rPr: '<a:rPr sz="4000"/>')) +
            para(
              run('Tight', rPr: '<a:rPr sz="2000"/>'),
              pPr:
                  '<a:pPr><a:lnSpc><a:spcPct val="90000"/></a:lnSpc>'
                  '</a:pPr>',
            ),
        bodyPr:
            '<a:bodyPr><a:normAutofit fontScale="50000" '
            'lnSpcReduction="20000"/></a:bodyPr>',
      ),
    );

    expect(styleAt(shape).size, 20);
    expect(shape.text.paragraphs[0].lineSpacing, closeTo(0.8, 1e-9));
    expect(styleAt(shape, 1).size, 10);
    expect(shape.text.paragraphs[1].lineSpacing, closeTo(0.7, 1e-9));
    expect(shape.autoFit, isFalse);
  });

  test('only a shape that resizes to its text is auto-fit', () {
    bool autoFit(String bodyPr) =>
        _readBox(txBody(para(run('x')), bodyPr: bodyPr)).autoFit;

    expect(autoFit('<a:bodyPr><a:spAutoFit/></a:bodyPr>'), isTrue);
    expect(autoFit('<a:bodyPr><a:noAutofit/></a:bodyPr>'), isFalse);
    expect(autoFit('<a:bodyPr><a:normAutofit/></a:bodyPr>'), isFalse);
    expect(autoFit('<a:bodyPr/>'), isFalse);
  });

  test('body properties come from the placeholders behind the shape', () {
    final slide = read(
      deckParts(
        masterShapes: sp(
          ph: '<p:ph type="body" idx="1"/>',
          spPr: _frame,
          text: txBody(
            para(run('Master text')),
            bodyPr: '<a:bodyPr lIns="0" tIns="0" bIns="0" anchor="ctr"/>',
          ),
        ),
        layoutShapes: sp(
          ph: '<p:ph idx="1"/>',
          text: txBody(
            para(run('Layout text')),
            bodyPr:
                '<a:bodyPr tIns="12700" anchor="b">'
                '<a:normAutofit fontScale="50000"/></a:bodyPr>',
          ),
        ),
        slides: [
          SlideFixture(
            shapes: sp(
              ph: '<p:ph idx="1"/>',
              text: txBody(
                para(run('Text')),
                bodyPr: '<a:bodyPr rIns="25400"/>',
              ),
            ),
          ),
        ],
      ),
    ).presentation.slides.single;

    final shape = shapeAt(slide, 0);
    expect(
      shape.insets,
      const TextInsets(left: 0, top: 1, right: 2, bottom: 0),
    );
    expect(shape.anchor, TextAnchor.bottom);
    expect(styleAt(shape).size, 9);
  });

  test('anchors and insets of a shape are read', () {
    ShapeElement shape(String bodyPr) =>
        _readBox(txBody(para(run('x')), bodyPr: bodyPr));

    expect(shape('<a:bodyPr anchor="t"/>').anchor, TextAnchor.top);
    expect(shape('<a:bodyPr anchor="ctr"/>').anchor, TextAnchor.middle);
    expect(shape('<a:bodyPr anchor="b"/>').anchor, TextAnchor.bottom);
    expect(shape('<a:bodyPr/>').insets, const TextInsets());
    expect(
      shape(
        '<a:bodyPr lIns="127000" tIns="0" rIns="63500" bIns="12700"/>',
      ).insets,
      const TextInsets(left: 10, top: 0, right: 5, bottom: 1),
    );
  });

  test('runs of one style are joined and line breaks stay in the text', () {
    final shape = _readBox(
      txBody(
        para(
              [
                run('One '),
                run('two'),
                '<a:br/>',
                run('three', rPr: '<a:rPr b="1"/>'),
                run('', rPr: '<a:rPr i="1"/>'),
                '<a:fld id="{0}" type="slidenum"><a:rPr/><a:t>7</a:t></a:fld>',
              ].join(),
            ) +
            para(run('a_x000B_b &amp; c')),
      ),
    );

    expect(shape.text.paragraphs[0].runs, const [
      TextRun('One two$softBreak', RunStyle()),
      TextRun('three', RunStyle(bold: true)),
      TextRun('7', RunStyle()),
    ]);
    expect(shape.text.paragraphs[1].runs, const [
      TextRun('a${softBreak}b & c', RunStyle()),
    ]);
  });

  test('an empty paragraph keeps the style typing there would have', () {
    final shape = _readBox(
      txBody(
        para('<a:endParaRPr sz="3200" b="1"/>') +
            para('') +
            para(run('', rPr: '<a:rPr i="1"/>')),
      ),
    );

    expect(shape.text.paragraphs, hasLength(3));
    expect(shape.text.paragraphs[0].runs, const [
      TextRun('', RunStyle(size: 32, bold: true)),
    ]);
    expect(shape.text.paragraphs[1].runs, const [TextRun('', RunStyle())]);
    expect(shape.text.paragraphs[2].runs, const [TextRun('', RunStyle())]);
  });

  test('a shape without text gets an empty body in the inherited style', () {
    final slide = read(
      deckParts(
        masterStyles:
            '<p:otherStyle>${_level(1, run: 'sz="1400" b="1"')}'
            '</p:otherStyle>',
        slides: [
          SlideFixture(
            shapes:
                sp(spPr: _frame) +
                _box('<p:txBody><a:bodyPr/></p:txBody>', id: 3),
          ),
        ],
      ),
    ).presentation.slides.single;

    for (final element in slide.elements) {
      final shape = element as ShapeElement;
      expect(shape.text.paragraphs.single.runs, const [
        TextRun('', RunStyle(size: 14, bold: true)),
      ]);
    }
  });

  test('alignment, level and spacing of a paragraph are read', () {
    String spaced(String spacing, {String attributes = ''}) => para(
      run('x', rPr: '<a:rPr sz="2000"/>'),
      pPr: '<a:pPr $attributes>$spacing</a:pPr>',
    );
    final shape = _readBox(
      txBody(
        spaced(
              '<a:lnSpc><a:spcPct val="150000"/></a:lnSpc>'
              '<a:spcBef><a:spcPts val="600"/></a:spcBef>'
              '<a:spcAft><a:spcPct val="50000"/></a:spcAft>',
              attributes: 'algn="just" lvl="3"',
            ) +
            spaced(
              '<a:lnSpc><a:spcPts val="3600"/></a:lnSpc>',
              attributes: 'algn="ctr" lvl="40"',
            ) +
            spaced(
              '<a:lnSpc><a:spcPct val="120%"/></a:lnSpc>',
              attributes: 'algn="dist"',
            ),
      ),
    );

    final first = shape.text.paragraphs[0];
    expect(first.align, ParagraphAlign.justify);
    expect(first.level, 3);
    expect(first.lineSpacing, closeTo(1.5, 1e-9));
    expect(first.spaceBefore, closeTo(6, 1e-9));
    expect(first.spaceAfter, closeTo(12, 1e-9));
    final second = shape.text.paragraphs[1];
    expect(second.align, ParagraphAlign.center);
    expect(second.level, Paragraph.maxLevel);
    expect(second.lineSpacing, closeTo(1.5, 1e-9));
    expect(second.spaceBefore, 0);
    expect(shape.text.paragraphs[2].align, ParagraphAlign.justify);
    expect(shape.text.paragraphs[2].lineSpacing, closeTo(1.2, 1e-9));
  });

  test('underline, strike and the color of a run are read', () {
    final shape = _readBox(
      txBody(
        para(
          run(
                'a',
                rPr:
                    '<a:rPr u="dbl" strike="dblStrike" i="true">'
                    '${solid('FF8800')}</a:rPr>',
              ) +
              run('b', rPr: '<a:rPr u="none" strike="noStrike" sz="1050"/>'),
        ),
      ),
    );

    expect(
      styleAt(shape),
      const RunStyle(
        italic: true,
        underline: true,
        strike: true,
        color: 0xFFFF8800,
      ),
    );
    expect(styleAt(shape, 0, 1), const RunStyle(size: 10.5));
  });
}
