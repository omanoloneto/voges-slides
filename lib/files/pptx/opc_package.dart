import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../presentation_file_exception.dart';

class Relationship {
  const Relationship({
    required this.id,
    required this.type,
    required this.target,
    this.external = false,
  });

  final String id;
  final String type;
  final String target;

  /// Points outside the package (`TargetMode="External"`): never followed.
  final bool external;

  /// Matches both transitional and strict OOXML relationship types.
  bool hasType(String suffix) => type.endsWith('/$suffix');
}

/// The parts of a `.pptx` zip, read lazily so only what is used is inflated.
class OpcPackage {
  OpcPackage._(this._archive);

  factory OpcPackage.decode(Uint8List bytes) {
    _rejectNonZip(bytes);
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw PresentationFileException(PresentationProblem.notPresentation);
    }
    var declaredSize = 0;
    for (final file in archive.files) {
      // A zip64 size over 2^63 reads as negative.
      if (file.size < 0 || file.size > maxUncompressedBytes - declaredSize) {
        throw PresentationFileException(PresentationProblem.tooLarge);
      }
      declaredSize += file.size;
    }
    final package = OpcPackage._(archive);
    if (package.text('mimetype')?.trim() == _openDocumentType) {
      throw PresentationFileException(PresentationProblem.openDocument);
    }
    package.mainPath = package._findMainPart();
    return package;
  }

  /// Guards against compressed files that blow up in memory.
  static const maxUncompressedBytes = 1024 * 1024 * 1024;

  static const _openDocumentType =
      'application/vnd.oasis.opendocument.presentation';

  final Archive _archive;

  /// The presentation part named by the package relationships, usually
  /// `ppt/presentation.xml`.
  late final String mainPath;

  Map<String, ArchiveFile>? _byLowercaseName;

  static const _zipMagic = [0x50, 0x4B, 0x03, 0x04];
  static const _compoundMagic = [
    0xD0,
    0xCF,
    0x11,
    0xE0,
    0xA1,
    0xB1,
    0x1A,
    0xE1,
  ];

  /// `.ppt` files and password-protected `.pptx` files are both OLE compound
  /// files; the encrypted ones hold an `EncryptedPackage` stream.
  static void _rejectNonZip(Uint8List bytes) {
    if (_startsWith(bytes, _zipMagic)) return;
    if (_startsWith(bytes, _compoundMagic)) {
      final marker = [
        for (final unit in 'EncryptedPackage'.codeUnits) ...[unit, 0],
      ];
      throw PresentationFileException(
        _contains(bytes, marker)
            ? PresentationProblem.encrypted
            : PresentationProblem.legacyPowerPoint,
      );
    }
    throw PresentationFileException(PresentationProblem.notPresentation);
  }

  static bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static bool _contains(Uint8List bytes, List<int> pattern) {
    final first = pattern.first;
    outer:
    for (var i = 0; i <= bytes.length - pattern.length; i++) {
      if (bytes[i] != first) continue;
      for (var j = 1; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  String _findMainPart() {
    for (final relationship in relationships('')) {
      if (!relationship.hasType('officeDocument')) continue;
      final path = targetOf('', relationship);
      if (path != null && has(path)) return path;
    }
    throw PresentationFileException(PresentationProblem.notPresentation);
  }

  /// Part names are case-insensitive in OPC, and some writers rely on it.
  ArchiveFile? _find(String path) {
    final exact = _archive.find(path);
    if (exact != null) return exact.isFile ? exact : null;
    final byName = _byLowercaseName ??= {
      for (final file in _archive.files)
        if (file.isFile) file.name.toLowerCase(): file,
    };
    return byName[path.toLowerCase()];
  }

  bool has(String path) => _find(path) != null;

  /// Null when the part is missing or its data cannot be inflated.
  Uint8List? bytes(String path) {
    final file = _find(path);
    if (file == null) return null;
    try {
      return file.readBytes();
    } catch (_) {
      return null;
    }
  }

  String? text(String path) {
    final data = bytes(path);
    if (data == null) return null;
    final decoded = utf8.decode(data, allowMalformed: true);
    return decoded.startsWith('﻿') ? decoded.substring(1) : decoded;
  }

  /// Null when the part is missing; malformed XML is a broken file.
  XmlDocument? xml(String path) {
    final source = text(path);
    if (source == null) return null;
    try {
      return XmlDocument.parse(source);
    } on XmlException {
      throw PresentationFileException(
        PresentationProblem.notPresentation,
        'Malformed XML in $path',
      );
    }
  }

  /// The relationships of the part at [sourcePath]; the package's own when
  /// it is empty.
  List<Relationship> relationships(String sourcePath) {
    final document = xml(relationshipsPath(sourcePath));
    if (document == null) return const [];
    return [
      for (final element in document.rootElement.childElements)
        if (element.name.local == 'Relationship')
          Relationship(
            id: element.getAttribute('Id') ?? '',
            type: element.getAttribute('Type') ?? '',
            target: element.getAttribute('Target') ?? '',
            external: element.getAttribute('TargetMode') == 'External',
          ),
    ];
  }

  /// The part [relationship] of [sourcePath] points to, or null when it
  /// leads outside the package.
  String? targetOf(String sourcePath, Relationship relationship) =>
      relationship.external ? null : resolve(sourcePath, relationship.target);

  static String relationshipsPath(String sourcePath) {
    if (sourcePath.isEmpty) return '_rels/.rels';
    final slash = sourcePath.lastIndexOf('/');
    final directory = slash < 0 ? '' : sourcePath.substring(0, slash + 1);
    return '${directory}_rels/${sourcePath.substring(slash + 1)}.rels';
  }

  /// The part name [target] means when written in the relationships of
  /// [sourcePath]. Null for anything that is not inside the package: a URL
  /// or a path that climbs above the root.
  static String? resolve(String sourcePath, String target) {
    final path = _unescaped(target);
    if (path == null ||
        path.isEmpty ||
        path.contains(':') ||
        path.contains('\\')) {
      return null;
    }
    final List<String> segments;
    if (path.startsWith('/')) {
      segments = [];
    } else {
      final slash = sourcePath.lastIndexOf('/');
      segments = slash < 0 ? [] : sourcePath.substring(0, slash).split('/');
    }
    for (final segment in path.split('/')) {
      if (segment == '..') {
        if (segments.isEmpty) return null;
        segments.removeLast();
      } else if (segment.isNotEmpty && segment != '.') {
        segments.add(segment);
      }
    }
    return segments.isEmpty ? null : segments.join('/');
  }

  /// Null when the percent escapes of [target] cannot be decoded.
  static String? _unescaped(String target) {
    if (!target.contains('%')) return target;
    try {
      return Uri.decodeComponent(target);
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  static const contentTypesPath = '[Content_Types].xml';

  /// Zip entries need a date; a fixed one keeps the output the same for the
  /// same input. Every time zone reads it as before 1980, the first year a
  /// zip can hold, so the stored date does not depend on the machine.
  static final _fixedDate = DateTime.utc(1979, 12, 30);

  /// Builds a zip with `[Content_Types].xml` first, as Office expects. XML
  /// is deflated; everything else is media that is already compressed and
  /// is stored as it is.
  static Uint8List encode(Map<String, List<int>> parts) {
    final archive = Archive();
    final names = [
      if (parts.containsKey(contentTypesPath)) contentTypesPath,
      ...parts.keys.where((name) => name != contentTypesPath),
    ];
    for (final name in names) {
      final data = parts[name]!;
      archive.add(
        name.endsWith('.xml') || name.endsWith('.rels')
            ? ArchiveFile.bytes(name, data)
            : ArchiveFile.noCompress(name, data.length, data),
      );
    }
    return ZipEncoder().encodeBytes(
      archive,
      level: DeflateLevel.defaultCompression,
      modified: _fixedDate,
    );
  }
}
