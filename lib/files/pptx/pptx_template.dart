import 'dart:ui' show Rect, Size;

import '../../deck/text_body.dart';
import 'pptx_xml.dart';

/// The parts every saved file carries whatever its slides hold: theme,
/// master, layouts and the package plumbing around them.

const applicationName = 'Voges Slides';

const drawingNamespaces =
    'xmlns:a="${PptxNamespaces.drawing}" '
    'xmlns:r="${PptxNamespaces.relationships}" '
    'xmlns:p="${PptxNamespaces.presentation}"';

const _officeRelationships =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _presentationTypes =
    'application/vnd.openxmlformats-officedocument.presentationml';

/// The layouts of the one master, in the order of their part numbers.
enum TemplateLayout {
  titleSlide('Title Slide', 'title'),
  titleContent('Title and Content', 'obj'),
  titleOnly('Title Only', 'titleOnly'),
  blank('Blank', 'blank');

  const TemplateLayout(this.label, this.type);

  final String label;
  final String type;

  int get number => index + 1;
  String get path => 'ppt/slideLayouts/slideLayout$number.xml';
}

const themePath = 'ppt/theme/theme1.xml';
const masterPath = 'ppt/slideMasters/slideMaster1.xml';

String slidePath(int number) => 'ppt/slides/slide$number.xml';

/// Content types of the picture formats a deck may carry.
const _mediaTypes = {
  'png': 'image/png',
  'jpeg': 'image/jpeg',
  'jpg': 'image/jpeg',
  'gif': 'image/gif',
  'bmp': 'image/bmp',
  'webp': 'image/webp',
  'tiff': 'image/tiff',
  'tif': 'image/tiff',
  'emf': 'image/x-emf',
  'wmf': 'image/x-wmf',
  'svg': 'image/svg+xml',
};

String contentTypesXml({
  required int slideCount,
  required Iterable<String> mediaExtensions,
}) {
  final buffer = StringBuffer(xmlDeclaration)
    ..write('<Types xmlns="${PptxNamespaces.contentTypes}">')
    ..write(
      '<Default Extension="rels" '
      'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>',
    );
  for (final extension in mediaExtensions) {
    final type = _mediaTypes[extension] ?? 'application/octet-stream';
    buffer.write('<Default Extension="$extension" ContentType="$type"/>');
  }
  void part(String path, String type) =>
      buffer.write('<Override PartName="/$path" ContentType="$type"/>');
  part('ppt/presentation.xml', '$_presentationTypes.presentation.main+xml');
  part(masterPath, '$_presentationTypes.slideMaster+xml');
  for (final layout in TemplateLayout.values) {
    part(layout.path, '$_presentationTypes.slideLayout+xml');
  }
  for (var number = 1; number <= slideCount; number++) {
    part(slidePath(number), '$_presentationTypes.slide+xml');
  }
  part(themePath, 'application/vnd.openxmlformats-officedocument.theme+xml');
  part(
    'docProps/core.xml',
    'application/vnd.openxmlformats-package.core-properties+xml',
  );
  part(
    'docProps/app.xml',
    'application/vnd.openxmlformats-officedocument.extended-properties+xml',
  );
  buffer.write('</Types>');
  return buffer.toString();
}

/// A `.rels` part; ids are `rId1`, `rId2`… in the order of [targets]. Types
/// are the last word of the Office relationship type.
String relationshipsXml(List<({String type, String target})> targets) {
  final buffer = StringBuffer(xmlDeclaration)
    ..write('<Relationships xmlns="${PptxNamespaces.packageRelationships}">');
  for (var i = 0; i < targets.length; i++) {
    final type = targets[i].type;
    buffer.write(
      '<Relationship Id="rId${i + 1}" '
      'Type="${type.contains('/') ? type : '$_officeRelationships/$type'}" '
      'Target="${targets[i].target}"/>',
    );
  }
  buffer.write('</Relationships>');
  return buffer.toString();
}

final packageRelationshipsXml = relationshipsXml(const [
  (type: 'officeDocument', target: 'ppt/presentation.xml'),
  (
    type:
        'http://schemas.openxmlformats.org/package/2006/relationships/'
        'metadata/core-properties',
    target: 'docProps/core.xml',
  ),
  (type: 'extended-properties', target: 'docProps/app.xml'),
]);

String appPropertiesXml(int slideCount) =>
    '$xmlDeclaration<Properties '
    'xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
    '<Application>$applicationName</Application>'
    '<Slides>$slideCount</Slides>'
    '</Properties>';

/// No dates: the same deck always saves to the same bytes.
const corePropertiesXml =
    '$xmlDeclaration<cp:coreProperties '
    'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/" '
    'xmlns:dcterms="http://purl.org/dc/terms/" '
    'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    '<dc:creator>$applicationName</dc:creator>'
    '</cp:coreProperties>';

/// PowerPoint refuses slides outside 1 to 56 inches.
int _slideExtent(double points) => pointsToEmu(points).clamp(914400, 51206400);

/// The master comes first in the relationships, then the theme, then the
/// slides: slide `n` is `rId(n + 2)`.
String presentationXml(Size size, int slideCount) {
  final buffer = StringBuffer(xmlDeclaration)
    ..write('<p:presentation $drawingNamespaces>')
    ..write(
      '<p:sldMasterIdLst>'
      '<p:sldMasterId id="$_masterId" r:id="rId1"/>'
      '</p:sldMasterIdLst>',
    )
    ..write('<p:sldIdLst>');
  for (var i = 0; i < slideCount; i++) {
    buffer.write('<p:sldId id="${256 + i}" r:id="rId${i + 3}"/>');
  }
  buffer
    ..write('</p:sldIdLst>')
    ..write(
      '<p:sldSz cx="${_slideExtent(size.width)}" '
      'cy="${_slideExtent(size.height)}"/>',
    )
    ..write('<p:notesSz cx="6858000" cy="9144000"/>')
    ..write('</p:presentation>');
  return buffer.toString();
}

String presentationRelationshipsXml(int slideCount) => relationshipsXml([
  (type: 'slideMaster', target: 'slideMasters/slideMaster1.xml'),
  (type: 'theme', target: 'theme/theme1.xml'),
  for (var number = 1; number <= slideCount; number++)
    (type: 'slide', target: 'slides/slide$number.xml'),
]);

/// Masters and layouts share one id space, starting at 2^31.
const _masterId = 2147483648;

const _flatFills =
    '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
    '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
    '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>';

String _themeLine(int width) =>
    '<a:ln w="$width" cap="flat" cmpd="sng" algn="ctr">'
    '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
    '<a:prstDash val="solid"/><a:miter lim="800000"/></a:ln>';

String _themeFont(String name) =>
    '<a:$name><a:latin typeface="$defaultFont"/>'
    '<a:ea typeface=""/><a:cs typeface=""/></a:$name>';

final themeXml =
    '$xmlDeclaration'
    '<a:theme xmlns:a="${PptxNamespaces.drawing}" name="$applicationName">'
    '<a:themeElements>'
    '<a:clrScheme name="Office">'
    '<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>'
    '<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
    '<a:dk2><a:srgbClr val="44546A"/></a:dk2>'
    '<a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>'
    '<a:accent1><a:srgbClr val="4472C4"/></a:accent1>'
    '<a:accent2><a:srgbClr val="ED7D31"/></a:accent2>'
    '<a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>'
    '<a:accent4><a:srgbClr val="FFC000"/></a:accent4>'
    '<a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>'
    '<a:accent6><a:srgbClr val="70AD47"/></a:accent6>'
    '<a:hlink><a:srgbClr val="0563C1"/></a:hlink>'
    '<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>'
    '</a:clrScheme>'
    '<a:fontScheme name="$applicationName">'
    '${_themeFont('majorFont')}${_themeFont('minorFont')}'
    '</a:fontScheme>'
    '<a:fmtScheme name="Office">'
    '<a:fillStyleLst>$_flatFills</a:fillStyleLst>'
    '<a:lnStyleLst>'
    '${_themeLine(6350)}${_themeLine(12700)}${_themeLine(19050)}'
    '</a:lnStyleLst>'
    '<a:effectStyleLst>'
    '<a:effectStyle><a:effectLst/></a:effectStyle>'
    '<a:effectStyle><a:effectLst/></a:effectStyle>'
    '<a:effectStyle><a:effectLst/></a:effectStyle>'
    '</a:effectStyleLst>'
    '<a:bgFillStyleLst>$_flatFills</a:bgFillStyleLst>'
    '</a:fmtScheme>'
    '</a:themeElements>'
    '<a:objectDefaults/><a:extraClrSchemeLst/>'
    '</a:theme>';

/// The empty group every shape tree starts with.
const shapeTreeStart =
    '<p:spTree>'
    '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/>'
    '</p:nvGrpSpPr>'
    '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
    '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>';

/// Placeholder frames on a 960 x 540 slide; they follow the slide size.
const _titleFrame = Rect.fromLTWH(66, 28.75, 828, 104.375);
const _bodyFrame = Rect.fromLTWH(66, 143.75, 828, 342.625);
const _centerTitleFrame = Rect.fromLTWH(120, 88.375, 720, 188);
const _subtitleFrame = Rect.fromLTWH(120, 283.625, 720, 130.375);

String _frame(Rect frame, Size size) {
  final sx = size.width / 960, sy = size.height / 540;
  return '<a:xfrm>'
      '<a:off x="${pointsToEmu(frame.left * sx)}" '
      'y="${pointsToEmu(frame.top * sy)}"/>'
      '<a:ext cx="${pointsToEmu(frame.width * sx)}" '
      'cy="${pointsToEmu(frame.height * sy)}"/>'
      '</a:xfrm>';
}

/// A placeholder of the master or of a layout. Without a [frame] it keeps
/// the place the master gives it.
String _placeholder({
  required int id,
  required String name,
  required String ph,
  required String prompt,
  String? frame,
  String? anchor,
  String listStyle = '',
}) =>
    '<p:sp>'
    '<p:nvSpPr><p:cNvPr id="$id" name="$name"/>'
    '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
    '<p:nvPr><p:ph $ph/></p:nvPr></p:nvSpPr>'
    '<p:spPr>${frame == null ? '' : '$frame<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'}</p:spPr>'
    '<p:txBody>'
    '<a:bodyPr${anchor == null ? '' : ' vert="horz" lIns="91440" tIns="45720" rIns="91440" bIns="45720" rtlCol="0" anchor="$anchor"'}>'
    '${anchor == null ? '' : '<a:noAutofit/>'}</a:bodyPr>'
    '<a:lstStyle>$listStyle</a:lstStyle>'
    '<a:p><a:r><a:rPr lang="en-US"/><a:t>$prompt</a:t></a:r></a:p>'
    '</p:txBody>'
    '</p:sp>';

String _runDefaults(int size, String font) =>
    '<a:defRPr sz="$size" kern="1200">'
    '<a:solidFill><a:schemeClr val="tx1"/></a:solidFill>'
    '<a:latin typeface="+$font-lt"/><a:ea typeface="+$font-ea"/>'
    '<a:cs typeface="+$font-cs"/></a:defRPr>';

const _bodySizes = [2800, 2400, 2000, 1800, 1800, 1800, 1800, 1800, 1800];

String _bodyStyle() {
  final buffer = StringBuffer();
  for (var level = 0; level < _bodySizes.length; level++) {
    buffer.write(
      '<a:lvl${level + 1}pPr marL="${228600 + 457200 * level}" '
      'indent="-228600" algn="l">'
      '<a:spcBef><a:spcPts val="${level == 0 ? 1000 : 500}"/></a:spcBef>'
      '<a:buFont typeface="$defaultFont"/><a:buChar char="&#8226;"/>'
      '${_runDefaults(_bodySizes[level], 'mn')}'
      '</a:lvl${level + 1}pPr>',
    );
  }
  return buffer.toString();
}

/// Levels without bullets, for subtitles and loose text.
String _plainLevels(List<int> sizes, {String align = 'l'}) {
  final buffer = StringBuffer();
  for (var level = 0; level < sizes.length; level++) {
    buffer.write(
      '<a:lvl${level + 1}pPr marL="${457200 * level}" indent="0" '
      'algn="$align"><a:buNone/>'
      '${_runDefaults(sizes[level], 'mn')}'
      '</a:lvl${level + 1}pPr>',
    );
  }
  return buffer.toString();
}

String masterXml(Size size) {
  final buffer = StringBuffer(xmlDeclaration)
    ..write('<p:sldMaster $drawingNamespaces>')
    ..write('<p:cSld>')
    ..write(
      '<p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>',
    )
    ..write(shapeTreeStart)
    ..write(
      _placeholder(
        id: 2,
        name: 'Title Placeholder 1',
        ph: 'type="title"',
        prompt: 'Click to edit Master title style',
        frame: _frame(_titleFrame, size),
        anchor: 'ctr',
      ),
    )
    ..write(
      _placeholder(
        id: 3,
        name: 'Text Placeholder 2',
        ph: 'type="body" idx="1"',
        prompt: 'Click to edit Master text styles',
        frame: _frame(_bodyFrame, size),
        anchor: 't',
      ),
    )
    ..write('</p:spTree></p:cSld>')
    ..write(
      '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" '
      'accent1="accent1" accent2="accent2" accent3="accent3" '
      'accent4="accent4" accent5="accent5" accent6="accent6" '
      'hlink="hlink" folHlink="folHlink"/>',
    )
    ..write('<p:sldLayoutIdLst>');
  for (final layout in TemplateLayout.values) {
    buffer.write(
      '<p:sldLayoutId id="${_masterId + layout.number}" '
      'r:id="rId${layout.number}"/>',
    );
  }
  buffer
    ..write('</p:sldLayoutIdLst>')
    ..write('<p:txStyles>')
    ..write(
      '<p:titleStyle><a:lvl1pPr algn="l">'
      '<a:spcBef><a:spcPct val="0"/></a:spcBef><a:buNone/>'
      '${_runDefaults(4400, 'mj')}'
      '</a:lvl1pPr></p:titleStyle>',
    )
    ..write('<p:bodyStyle>${_bodyStyle()}</p:bodyStyle>')
    ..write(
      '<p:otherStyle>'
      '${_plainLevels(List.filled(_bodySizes.length, 1800))}'
      '</p:otherStyle>',
    )
    ..write('</p:txStyles>')
    ..write('</p:sldMaster>');
  return buffer.toString();
}

/// The layouts are `rId1`…`rId4`, the theme comes after them.
final masterRelationshipsXml = relationshipsXml([
  for (final layout in TemplateLayout.values)
    (
      type: 'slideLayout',
      target: '../slideLayouts/slideLayout${layout.number}.xml',
    ),
  (type: 'theme', target: '../theme/theme1.xml'),
]);

final layoutRelationshipsXml = relationshipsXml(const [
  (type: 'slideMaster', target: '../slideMasters/slideMaster1.xml'),
]);

const _titlePrompt = 'Click to edit Master title style';

String layoutXml(TemplateLayout layout, Size size) {
  final heading = _placeholder(
    id: 2,
    name: 'Title 1',
    ph: 'type="title"',
    prompt: _titlePrompt,
  );
  final shapes = switch (layout) {
    TemplateLayout.titleSlide =>
      _placeholder(
            id: 2,
            name: 'Title 1',
            ph: 'type="ctrTitle"',
            prompt: _titlePrompt,
            frame: _frame(_centerTitleFrame, size),
            anchor: 'b',
            listStyle:
                '<a:lvl1pPr algn="ctr"><a:defRPr sz="6000"/></a:lvl1pPr>',
          ) +
          _placeholder(
            id: 3,
            name: 'Subtitle 2',
            ph: 'type="subTitle" idx="1"',
            prompt: 'Click to edit Master subtitle style',
            frame: _frame(_subtitleFrame, size),
            listStyle: _plainLevels(const [
              2400,
              2000,
              1800,
              1600,
              1600,
              1600,
              1600,
              1600,
              1600,
            ], align: 'ctr'),
          ),
    TemplateLayout.titleContent =>
      heading +
          _placeholder(
            id: 3,
            name: 'Content Placeholder 2',
            ph: 'idx="1"',
            prompt: 'Click to edit Master text styles',
          ),
    TemplateLayout.titleOnly => heading,
    TemplateLayout.blank => '',
  };
  return '$xmlDeclaration'
      '<p:sldLayout $drawingNamespaces type="${layout.type}" preserve="1">'
      '<p:cSld name="${layout.label}">$shapeTreeStart$shapes</p:spTree></p:cSld>'
      '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'
      '</p:sldLayout>';
}
