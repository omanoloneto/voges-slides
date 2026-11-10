import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voges_slides/files/pptx/opc_package.dart';
import 'package:voges_slides/files/presentation_file_exception.dart';

import 'fixtures.dart';

const _strictRelationships =
    'http://purl.oclc.org/ooxml/officeDocument/relationships';

void main() {
  group('relationship targets', () {
    const slide = 'ppt/slides/slide1.xml';

    test('are read from the folder of the part that names them', () {
      expect(
        OpcPackage.resolve(slide, '../media/image1.png'),
        'ppt/media/image1.png',
      );
      expect(OpcPackage.resolve(presentationPath, 'slides/slide1.xml'), slide);
      expect(OpcPackage.resolve(slide, './notes.xml'), 'ppt/slides/notes.xml');
      expect(OpcPackage.resolve(slide, '..//media/a.png'), 'ppt/media/a.png');
      expect(OpcPackage.resolve('', presentationPath), presentationPath);
      expect(OpcPackage.resolve('part.xml', 'other.xml'), 'other.xml');
    });

    test('that start with a slash are read from the root', () {
      expect(
        OpcPackage.resolve(slide, '/ppt/media/image1.png'),
        'ppt/media/image1.png',
      );
      expect(
        OpcPackage.resolve(slide, '/ppt/../docProps/app.xml'),
        'docProps/app.xml',
      );
    });

    test('have their percent escapes decoded', () {
      expect(
        OpcPackage.resolve(slide, '../media/my%20picture.png'),
        'ppt/media/my picture.png',
      );
    });

    test('that climb above the root lead nowhere', () {
      expect(OpcPackage.resolve(slide, '../../../etc/passwd'), isNull);
      expect(OpcPackage.resolve(slide, '../../..'), isNull);
      expect(OpcPackage.resolve('', '../outside.xml'), isNull);
      expect(OpcPackage.resolve(slide, '/../outside.xml'), isNull);
      expect(OpcPackage.resolve(slide, '%2E%2E/%2E%2E/%2E%2E/outside'), isNull);
      expect(OpcPackage.resolve(slide, '..%2F..%2F..%2Foutside'), isNull);
    });

    test('that are not a path inside the package lead nowhere', () {
      expect(OpcPackage.resolve(slide, ''), isNull);
      expect(OpcPackage.resolve(slide, '/'), isNull);
      expect(OpcPackage.resolve(slide, '..'), 'ppt');
      expect(OpcPackage.resolve(slide, 'https://example.com/a.png'), isNull);
      expect(OpcPackage.resolve(slide, 'file:///etc/passwd'), isNull);
      expect(OpcPackage.resolve(slide, r'C:\Users\me\a.png'), isNull);
      expect(OpcPackage.resolve(slide, r'..\..\..\outside'), isNull);
      expect(OpcPackage.resolve(slide, '%5C%5Cserver%5Cshare'), isNull);
      expect(OpcPackage.resolve(slide, 'file%3A%2F%2F%2Fetc%2Fpasswd'), isNull);
      expect(OpcPackage.resolve(slide, '../media/%zz.png'), isNull);
      expect(OpcPackage.resolve(slide, '../media/%FF.png'), isNull);
      expect(OpcPackage.resolve(slide, '../media/a%'), isNull);
    });

    test('a relationship marked as external is never followed', () {
      final package = OpcPackage.decode(zipParts(deckParts()));

      expect(
        package.targetOf(
          slide,
          const Relationship(
            id: 'rId2',
            type: '$_strictRelationships/image',
            target: '../media/image1.png',
            external: true,
          ),
        ),
        isNull,
      );
    });
  });

  test('the relationships of a part are kept beside it', () {
    expect(OpcPackage.relationshipsPath(''), '_rels/.rels');
    expect(
      OpcPackage.relationshipsPath(presentationPath),
      'ppt/_rels/presentation.xml.rels',
    );
    expect(OpcPackage.relationshipsPath('part.xml'), '_rels/part.xml.rels');
  });

  test('a relationship type is matched in both flavors of the format', () {
    const transitional = Relationship(
      id: 'rId1',
      type:
          'http://schemas.openxmlformats.org/officeDocument/2006/'
          'relationships/slideLayout',
      target: 'a.xml',
    );
    const strict = Relationship(
      id: 'rId1',
      type: '$_strictRelationships/slide',
      target: 'a.xml',
    );

    expect(transitional.hasType('slideLayout'), isTrue);
    expect(transitional.hasType('slide'), isFalse);
    expect(transitional.hasType('Layout'), isFalse);
    expect(strict.hasType('slide'), isTrue);
    expect(strict.hasType('notesSlide'), isFalse);
  });

  group('a decoded package', () {
    test('names the presentation part and reads its relationships', () {
      final package = OpcPackage.decode(zipParts(deckParts()));

      expect(package.mainPath, presentationPath);
      expect(
        [
          for (final relationship in package.relationships(presentationPath))
            (relationship.id, package.targetOf(presentationPath, relationship)),
        ],
        [('rId1', masterPath), ('rId2', themePath), ('rId3', slidePath(1))],
      );
      expect(package.relationships(themePath), isEmpty);
    });

    test('finds parts whatever the case of their names', () {
      final parts = deckParts();
      final package = OpcPackage.decode(
        zipParts({
          for (final part in parts.entries)
            (part.key == presentationPath ? 'PPT/Presentation.XML' : part.key):
                part.value,
        }),
      );

      expect(package.mainPath, presentationPath);
      expect(package.has(presentationPath), isTrue);
      expect(package.has('ppt/PRESENTATION.xml'), isTrue);
      expect(
        package.xml(presentationPath)!.rootElement.name.local,
        'presentation',
      );
    });

    test('gives nothing for a part that is not there', () {
      final package = OpcPackage.decode(zipParts(deckParts()));

      expect(package.has('ppt/media/image1.png'), isFalse);
      expect(package.bytes('ppt/media/image1.png'), isNull);
      expect(package.text('ppt/media/image1.png'), isNull);
      expect(package.xml('ppt/media/image1.png'), isNull);
      expect(package.has('ppt'), isFalse);
    });

    test('reads text without its byte order mark', () {
      final package = OpcPackage.decode(
        zipParts({
          ...deckParts(),
          'docProps/note.xml': [0xEF, 0xBB, 0xBF, ...'<a>é</a>'.codeUnits],
          'docProps/broken.xml': '<a><b></a>',
        }),
      );

      expect(package.text('docProps/note.xml'), startsWith('<a>'));
      expect(package.xml('docProps/note.xml')!.rootElement.name.local, 'a');
      expect(
        () => package.xml('docProps/broken.xml'),
        throwsProblem(PresentationProblem.notPresentation),
      );
    });
  });

  group('an encoded package', () {
    final parts = <String, List<int>>{
      'ppt/presentation.xml': '<p/>'.codeUnits,
      'ppt/media/image1.png': pictureBytes,
      '_rels/.rels': '<Relationships/>'.codeUnits,
      OpcPackage.contentTypesPath: '<Types/>'.codeUnits,
    };

    test(
      'starts with the content types and keeps the other parts in order',
      () {
        expect(unzip(OpcPackage.encode(parts)).keys, [
          OpcPackage.contentTypesPath,
          'ppt/presentation.xml',
          'ppt/media/image1.png',
          '_rels/.rels',
        ]);
      },
    );

    test('deflates XML and stores media as it is', () {
      final files = {
        for (final file in ZipDecoder().decodeBytes(OpcPackage.encode(parts)))
          file.name: file,
      };

      expect(files['ppt/media/image1.png']!.compression, CompressionType.none);
      expect(
        files['ppt/presentation.xml']!.compression,
        CompressionType.deflate,
      );
      expect(files['_rels/.rels']!.compression, CompressionType.deflate);
      expect(files['ppt/media/image1.png']!.readBytes(), pictureBytes);
      expect(files['ppt/presentation.xml']!.readBytes(), '<p/>'.codeUnits);
    });

    test('is the same bytes every time', () {
      expect(OpcPackage.encode(parts), OpcPackage.encode(parts));
    });

    test('can be decoded again', () {
      final bytes = OpcPackage.encode({
        for (final part in deckParts().entries)
          part.key: (part.value as String).codeUnits,
      });

      final package = OpcPackage.decode(Uint8List.fromList(bytes));

      expect(package.mainPath, presentationPath);
    });
  });
}
