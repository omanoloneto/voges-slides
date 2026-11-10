import 'package:xml/xml.dart';

abstract final class PptxNamespaces {
  static const drawing =
      'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const presentation =
      'http://schemas.openxmlformats.org/presentationml/2006/main';
  static const relationships =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const packageRelationships =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const contentTypes =
      'http://schemas.openxmlformats.org/package/2006/content-types';
}

const xmlDeclaration =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

const emuPerPoint = 12700;

double emuToPoints(num emu) => emu / emuPerPoint;

int pointsToEmu(double points) => (points * emuPerPoint).round();

/// DrawingML angles count 60000ths of a degree.
double angleToDegrees(num angle) => angle / 60000;

int degreesToAngle(double degrees) => (degrees * 60000).round();

/// DrawingML percentages count 100000ths.
int fractionToPercent(double fraction) => (fraction * 100000).round();

/// Plain XML escaping; characters XML 1.0 cannot carry are dropped.
String escapeXml(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    switch (unit) {
      case 0x26:
        buffer.write('&amp;');
      case 0x3C:
        buffer.write('&lt;');
      case 0x3E:
        buffer.write('&gt;');
      case < 0x20 when unit != 0x09 && unit != 0x0A && unit != 0x0D:
        break;
      case 0xFFFE || 0xFFFF:
        break;
      case >= 0xD800 && <= 0xDBFF when !_lowSurrogateAt(value, i + 1):
        break;
      case >= 0xDC00 && <= 0xDFFF when !_highSurrogateAt(value, i - 1):
        break;
      default:
        buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

String escapeAttribute(String value) =>
    escapeXml(value).replaceAll('"', '&quot;');

bool _lowSurrogateAt(String value, int index) =>
    index < value.length && (value.codeUnitAt(index) & 0xFC00) == 0xDC00;

bool _highSurrogateAt(String value, int index) =>
    index >= 0 && (value.codeUnitAt(index) & 0xFC00) == 0xD800;

XmlElement? child(XmlElement? parent, String localName) {
  if (parent == null) return null;
  for (final element in parent.childElements) {
    if (element.name.local == localName) return element;
  }
  return null;
}

Iterable<XmlElement> children(XmlElement parent, String localName) =>
    parent.childElements.where((element) => element.name.local == localName);

/// Follows [path] one child at a time; null as soon as a step is missing.
XmlElement? descend(XmlElement? parent, List<String> path) {
  var current = parent;
  for (final name in path) {
    if (current == null) return null;
    current = child(current, name);
  }
  return current;
}

/// The child elements of [parent], with every `mc:AlternateContent` replaced
/// by what its fallback holds (or its first choice when it has none).
Iterable<XmlElement> contentElements(XmlElement parent) sync* {
  for (final element in parent.childElements) {
    if (element.name.local != 'AlternateContent') {
      yield element;
      continue;
    }
    final branch = child(element, 'Fallback') ?? child(element, 'Choice');
    if (branch != null) yield* contentElements(branch);
  }
}

/// Reads `r:id`, `r:embed`, `r:link`… whatever the prefix or namespace
/// (transitional or strict).
String? relationshipAttribute(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName && attribute.name.prefix != null) {
      return attribute.value;
    }
  }
  return null;
}

int? intAttribute(XmlElement? element, String name) {
  final value = element?.getAttribute(name);
  return value == null ? null : int.tryParse(value.trim());
}

/// A length attribute in EMU, as points.
double? pointsAttribute(XmlElement? element, String name) {
  final emu = intAttribute(element, name);
  return emu == null ? null : emuToPoints(emu);
}

/// A percentage attribute as a fraction: `50000` and the strict `50%` are
/// both 0.5.
double? fractionAttribute(XmlElement? element, String name) {
  final value = element?.getAttribute(name)?.trim();
  if (value == null || value.isEmpty) return null;
  final parsed = value.endsWith('%')
      ? (double.tryParse(value.substring(0, value.length - 1)) ?? double.nan) /
            100
      : (double.tryParse(value) ?? double.nan) / 100000;
  return parsed.isFinite ? parsed : null;
}

bool? boolAttribute(XmlElement? element, String name) {
  final value = element?.getAttribute(name);
  if (value == null) return null;
  return value == '1' || value == 'true' || value == 'on';
}
