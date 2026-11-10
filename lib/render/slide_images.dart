import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../deck/element.dart';

const _maxPixels = 120 * 1000 * 1000;
const _maxWidth = 2560;

class _Entry {
  ui.Image? image;
}

/// The pictures of the presentation decoded for drawing. Each is decoded
/// once, the first time a slide shows it; listeners hear when it is ready.
class SlideImages extends ChangeNotifier {
  final _entries = Expando<_Entry>();
  var _disposed = false;

  /// Null while the picture is being decoded, and for good when it cannot
  /// be drawn.
  ui.Image? of(ImageData data) {
    final known = _entries[data];
    if (known != null) return known.image;
    final entry = _entries[data] = _Entry();
    if (data.decodable) _decode(data, entry);
    return null;
  }

  Future<void> _decode(ImageData data, _Entry entry) async {
    try {
      entry.image = await decodeImage(data.bytes);
    } catch (_) {
      return;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

Future<T> _describe<T>(
  Uint8List bytes,
  Future<T> Function(ui.ImageDescriptor descriptor) use,
) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      // a huge picture in a hostile file would exhaust the memory
      if (descriptor.width * descriptor.height > _maxPixels) {
        throw const FormatException('Image too large');
      }
      return await use(descriptor);
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

/// Decodes a picture, no wider than a large screen needs. Throws when the
/// bytes are not a picture the platform reads.
Future<ui.Image> decodeImage(Uint8List bytes) =>
    _describe(bytes, (descriptor) async {
      final codec = await descriptor.instantiateCodec(
        targetWidth: descriptor.width > _maxWidth ? _maxWidth : null,
      );
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    });

/// The size of a picture in pixels. Throws like [decodeImage].
Future<ui.Size> imageSizeOf(Uint8List bytes) => _describe(
  bytes,
  (descriptor) async =>
      ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble()),
);
