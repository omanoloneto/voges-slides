import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/deck/element.dart';
import 'package:voges_slides/files/pptx/pptx_import.dart';
import 'package:voges_slides/files/pptx/pptx_reader.dart';
import 'package:voges_slides/files/presentation_file_exception.dart';

import 'fixtures.dart';

final _frame = xfrm(10, 10, 300, 100);

const _presentationRelationshipsPath = 'ppt/_rels/presentation.xml.rels';
const _layoutRelationshipsPath = 'ppt/slideLayouts/_rels/slideLayout1.xml.rels';
const _masterRelationshipsPath = 'ppt/slideMasters/_rels/slideMaster1.xml.rels';
const _notesPath = 'ppt/notesSlides/notesSlide1.xml';

const _notPresentation = PresentationProblem.notPresentation;

Uint8List _bytes(Iterable<int> bytes) => Uint8List.fromList([...bytes]);

/// The start of an OLE compound file holding a stream called [stream].
Uint8List _compoundFile(String stream) => _bytes([
  ...[0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
  ...List.filled(504, 0),
  for (final unit in stream.codeUnits) ...[unit, 0],
  ...List.filled(64, 0),
]);

/// [zip] with every entry claiming to hold [size] bytes once inflated, in
/// both its local header and the central directory.
Uint8List _declaringSizes(Uint8List zip, int size) {
  final bytes = Uint8List.fromList(zip);
  final data = ByteData.sublistView(bytes);
  var end = bytes.length - 22;
  while (data.getUint32(end, Endian.little) != 0x06054b50) {
    end--;
  }
  final entries = data.getUint16(end + 10, Endian.little);
  var header = data.getUint32(end + 16, Endian.little);
  for (var i = 0; i < entries; i++) {
    final local = data.getUint32(header + 42, Endian.little);
    data.setUint32(header + 24, size, Endian.little);
    data.setUint32(local + 22, size, Endian.little);
    header +=
        46 +
        data.getUint16(header + 28, Endian.little) +
        data.getUint16(header + 30, Endian.little) +
        data.getUint16(header + 32, Endian.little);
  }
  return bytes;
}

/// A deck of one slide with a text box that says "Kept".
Map<String, Object> _deck({String relationships = '', String shapes = ''}) =>
    deckParts(
      slides: [
        SlideFixture(
          shapes: sp(spPr: _frame, text: txBody(para(run('Kept')))) + shapes,
          relationships: relationships,
        ),
      ],
    );

void _expectKept(Map<String, Object> parts, {String? reason}) {
  final slide = read(parts).presentation.slides.single;

  expect(slide.elements, hasLength(1), reason: reason);
  expect(shapeAt(slide, 0).text.text, 'Kept', reason: reason);
}

void main() {
  group('a file that is not a presentation', () {
    test('is refused when it is not a zip', () {
      for (final bytes in [
        Uint8List(0),
        _bytes([0x50, 0x4B]),
        _bytes('This is a text file, not slides.'.codeUnits),
        _bytes([...pictureBytes, ...List.filled(200, 7)]),
        _bytes([0xD0, 0xCF, 0x11]),
      ]) {
        expect(() => readPptx(bytes), throwsProblem(_notPresentation));
      }
    });

    test('is refused when the zip is damaged', () {
      final deck = zipParts(deckParts());

      for (final bytes in [
        _bytes([0x50, 0x4B, 0x03, 0x04]),
        _bytes([0x50, 0x4B, 0x03, 0x04, ...List.filled(300, 0xAB)]),
        Uint8List.sublistView(deck, 0, deck.length ~/ 2),
        Uint8List.sublistView(deck, 0, deck.length - 30),
      ]) {
        expect(() => readPptx(bytes), throwsProblem(_notPresentation));
      }
    });

    test('is told apart when it is an old or a protected PowerPoint file', () {
      expect(
        () => readPptx(_compoundFile('PowerPoint Document')),
        throwsProblem(PresentationProblem.legacyPowerPoint),
      );
      expect(
        () => readPptx(_compoundFile('EncryptedPackage')),
        throwsProblem(PresentationProblem.encrypted),
      );
    });

    test('is told apart when it is an OpenDocument presentation', () {
      Uint8List document(String type) => zipParts({
        'mimetype': type,
        'content.xml': '<office:document-content/>',
      });

      expect(
        () => readPptx(
          document('application/vnd.oasis.opendocument.presentation'),
        ),
        throwsProblem(PresentationProblem.openDocument),
      );
      expect(
        () => readPptx(
          document('application/vnd.oasis.opendocument.presentation\n'),
        ),
        throwsProblem(PresentationProblem.openDocument),
      );
      expect(
        () => readPptx(document('application/vnd.oasis.opendocument.text')),
        throwsProblem(_notPresentation),
      );
    });

    test('is refused when the zip names no presentation part', () {
      final missing = deckParts()..remove(presentationPath);
      final unnamed = deckParts()..remove('_rels/.rels');
      Map<String, Object> pointingTo(String entry) =>
          deckParts()..['_rels/.rels'] = relationshipsPart(entry);

      for (final parts in [
        {'notes.txt': 'Just a zip.'},
        missing,
        unnamed,
        pointingTo(''),
        pointingTo(relationship('rId1', 'officeDocument', 'ppt/gone.xml')),
        pointingTo(relationship('rId1', 'officeDocument', '../outside.xml')),
        pointingTo(
          relationship('rId1', 'extended-properties', presentationPath),
        ),
        pointingTo(
          relationship(
            'rId1',
            'officeDocument',
            presentationPath,
            external: true,
          ),
        ),
      ]) {
        expect(() => read(parts), throwsProblem(_notPresentation));
      }
    });

    test('is refused when it is another kind of Office document', () {
      final word = {
        '_rels/.rels': relationshipsPart(
          relationship('rId1', 'officeDocument', 'word/document.xml'),
        ),
        'word/document.xml':
            '<w:document xmlns:w="http://schemas.openxmlformats.org/'
            'wordprocessingml/2006/main"><w:body/></w:document>',
      };

      expect(() => read(word), throwsProblem(_notPresentation));
    });

    test('is refused when a part it cannot do without is broken', () {
      for (final path in [
        '_rels/.rels',
        presentationPath,
        _presentationRelationshipsPath,
        slidePath(1),
      ]) {
        for (final content in ['<p:broken', '', '<a><b></a>', 'plain text']) {
          final parts = deckParts()..[path] = content;

          expect(
            () => read(parts),
            throwsProblem(_notPresentation),
            reason: '$path holding "$content"',
          );
        }
      }
    });

    test('is refused before it is inflated when it claims to be huge', () {
      final deck = zipParts(deckParts());
      const megabyte = 1024 * 1024;

      expect(
        () => readPptx(_declaringSizes(deck, 0x7FFFFFFF)),
        throwsProblem(PresentationProblem.tooLarge),
      );
      expect(
        () => readPptx(_declaringSizes(deck, 200 * megabyte)),
        throwsProblem(PresentationProblem.tooLarge),
        reason: 'every part fits, all of them together do not',
      );
    });
  });

  group('a presentation with broken pieces', () {
    test('is read without the theme, layout or master it cannot use', () {
      for (final path in [
        themePath,
        layoutPath,
        masterPath,
        slideRelationshipsPath(1),
        _layoutRelationshipsPath,
        _masterRelationshipsPath,
        '[Content_Types].xml',
      ]) {
        _expectKept(_deck()..remove(path), reason: 'without $path');
        for (final content in ['<p:broken', '', '<!-- empty -->', '<other/>']) {
          _expectKept(
            _deck()..[path] = content,
            reason: '$path holding "$content"',
          );
        }
      }
    });

    test('is read when a layout or master leads out of the package', () {
      for (final target in ['../../../outside.xml', 'file:///outside.xml']) {
        _expectKept(
          _deck()
            ..[slideRelationshipsPath(1)] = relationshipsPart(
              relationship('rId1', 'slideLayout', target),
            ),
          reason: 'layout at $target',
        );
        _expectKept(
          _deck()
            ..[_layoutRelationshipsPath] = relationshipsPart(
              relationship('rId1', 'slideMaster', target),
            ),
          reason: 'master at $target',
        );
      }
    });

    test('is read when its notes cannot be', () {
      final notes = relationship(
        'rId2',
        'notesSlide',
        '../notesSlides/notesSlide1.xml',
      );

      _expectKept(_deck(relationships: notes), reason: 'missing notes');
      for (final content in ['<p:notes', '', '<other/>']) {
        final parts = _deck(relationships: notes)..[_notesPath] = content;

        _expectKept(parts, reason: 'notes holding "$content"');
        expect(read(parts).losses, isEmpty);
      }
    });

    test('skips a slide that is not there', () {
      Map<String, Object> deck() => deckParts(
        slides: [
          SlideFixture(shapes: sp(spPr: _frame + preset('ellipse'))),
          SlideFixture(shapes: sp(spPr: _frame + preset('hexagon'))),
          SlideFixture(shapes: sp(spPr: _frame + preset('diamond'))),
        ],
      );
      Map<String, Object> changing(String path, String from, String to) {
        final parts = deck();
        final content = parts[path]! as String;
        expect(content, contains(from));
        return parts..[path] = content.replaceFirst(from, to);
      }

      const second = 'Target="slides/slide2.xml"';
      for (final parts in [
        deck()..remove(slidePath(2)),
        deck()..[slidePath(2)] = treePart('sldLayout'),
        changing(presentationPath, 'r:id="rId4"', 'r:id="rId99"'),
        changing(presentationPath, ' r:id="rId4"', ''),
        for (final target in [
          'Target="slides/gone.xml"',
          'Target="../../outside.xml"',
          'Target="slideLayouts/slideLayout1.xml"',
          'Target="slides/slide2.xml" TargetMode="External"',
          'Target="https://example.com/slide2.xml" TargetMode="External"',
        ])
          changing(_presentationRelationshipsPath, second, target),
      ]) {
        final slides = read(parts).presentation.slides;

        expect(
          [for (final slide in slides) shapeAt(slide, 0).kind],
          [ShapeKind.ellipse, ShapeKind.diamond],
        );
      }
    });

    test('drops shapes whose numbers make no sense', () {
      String at(String x, String width) =>
          '<a:xfrm><a:off x="$x" y="0"/><a:ext cx="$width" cy="12700"/>'
          '</a:xfrm>';

      final result = read(
        _deck(
          shapes: [
            sp(id: 3, spPr: at('9223372036854775807', '12700')),
            sp(id: 4, spPr: at('0', '99999999999999999999999')),
            sp(id: 5, spPr: at('-9223372036854775808', '12700')),
            sp(id: 6, spPr: at('1e3', '12700')),
            sp(id: 7, spPr: at('0', '-12700')),
            sp(id: 8, spPr: at('NaN', 'Infinity')),
          ].join(),
        ),
      );

      expect(result.presentation.slides.single.elements, hasLength(1));
    });

    test('keeps text sizes and spacing within reason', () {
      final slide = read(
        deckParts(
          slides: [
            SlideFixture(
              shapes: sp(
                spPr: _frame,
                text: txBody(
                  para(
                        run('Huge', rPr: '<a:rPr sz="2000000000"/>'),
                        pPr:
                            '<a:pPr lvl="-3"><a:lnSpc>'
                            '<a:spcPct val="99999999999"/></a:lnSpc>'
                            '<a:spcBef><a:spcPts val="-500"/></a:spcBef>'
                            '</a:pPr>',
                      ) +
                      para(run('Tiny', rPr: '<a:rPr sz="1"/>')) +
                      para(run('Negative', rPr: '<a:rPr sz="-4000"/>')) +
                      para(run('Odd', rPr: '<a:rPr sz="big"/>')),
                  bodyPr:
                      '<a:bodyPr lIns="99999999999999" tIns="-12700" '
                      'rIns="x"/>',
                ),
              ),
            ),
          ],
        ),
      ).presentation.slides.single;

      final shape = shapeAt(slide, 0);
      final huge = shape.text.paragraphs[0];
      expect(huge.runs.single.style.size, 4000);
      expect(huge.level, 0);
      expect(huge.lineSpacing, 100);
      expect(huge.spaceBefore, 0);
      expect(styleAt(shape, 1).size, 1);
      expect(styleAt(shape, 2).size, 18);
      expect(styleAt(shape, 3).size, 18);
      expect(shape.insets.left, 10000);
      expect(shape.insets.top, 0);
      expect(shape.insets.right, 7.2);
    });

    test('does not expand entities the file declares', () {
      final parts = deckParts(
        slides: [
          SlideFixture(
            shapes: sp(spPr: _frame, text: txBody(para(run('&bomb;')))),
          ),
        ],
      );
      parts[slidePath(1)] = (parts[slidePath(1)]! as String).replaceFirst(
        '<p:sld ',
        '<!DOCTYPE p:sld [<!ENTITY a "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa">'
            '<!ENTITY bomb "&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;">]>'
            '<p:sld ',
      );

      final slide = read(parts).presentation.slides.single;

      expect(shapeAt(slide, 0).text.text, isNot(contains('aaaa')));
    });
  });

  group('a relationship that leads out of the package', () {
    Map<String, Object> deckWith(String imageRelationship) => {
      ..._deck(
        relationships: imageRelationship,
        shapes: pic('rId2', spPr: _frame),
      ),
      'ppt/media/image1.png': pictureBytes,
      'secret.png': pictureBytes,
      '../secret.png': pictureBytes,
    };

    test('is not followed for a picture', () {
      for (final entry in [
        relationship('rId2', 'image', '../../../secret.png'),
        relationship('rId2', 'image', '../../../../../etc/passwd'),
        relationship('rId2', 'image', '/../secret.png'),
        relationship('rId2', 'image', 'file:///etc/passwd'),
        relationship('rId2', 'image', r'..\..\secret.png'),
        relationship('rId2', 'image', '..%2F..%2F..%2Fsecret.png'),
        relationship('rId2', 'image', '%2E%2E/%2E%2E/%2E%2E/secret.png'),
        relationship('rId2', 'image', '../media/%FF.png'),
        relationship('rId2', 'image', 'https://example.com/a.png'),
        relationship(
          'rId2',
          'image',
          'https://example.com/a.png',
          external: true,
        ),
        relationship('rId2', 'image', '../media/image1.png', external: true),
      ]) {
        final result = read(deckWith(entry));

        _expectKept(deckWith(entry), reason: entry);
        expect(result.losses, {ImportLoss.images}, reason: entry);
      }
    });

    test('is followed when it only looks unusual', () {
      for (final target in [
        '/ppt/media/image1.png',
        '../media/./image1.png',
        '../../ppt/media/image1.png',
        '../media/%69mage1.png',
        '../MEDIA/Image1.PNG',
        '../../secret.png',
      ]) {
        final result = read(deckWith(relationship('rId2', 'image', target)));

        final elements = result.presentation.slides.single.elements;
        expect(elements, hasLength(2), reason: target);
        expect((elements[1] as ImageElement).image.bytes, pictureBytes);
        expect(result.losses, isEmpty, reason: target);
      }
    });

    test('is not followed for a background picture', () {
      final parts = deckParts(
        slides: [
          SlideFixture(
            background:
                '<p:bg><p:bgPr><a:blipFill><a:blip r:embed="rId2"/>'
                '</a:blipFill></p:bgPr></p:bg>',
            relationships: relationship('rId2', 'image', '../../../secret.png'),
          ),
        ],
      )..['../secret.png'] = pictureBytes;

      final result = read(parts);

      expect(result.presentation.slides.single.backgroundImage, isNull);
      expect(result.losses, {ImportLoss.images});
    });

    test('leaves out a picture that is empty', () {
      final parts = deckWith(
        relationship('rId2', 'image', '../media/image1.png'),
      )..['ppt/media/image1.png'] = <int>[];

      _expectKept(parts);
      expect(read(parts).losses, {ImportLoss.images});
    });
  });
}
