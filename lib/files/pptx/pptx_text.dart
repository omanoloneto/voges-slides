import 'package:xml/xml.dart';

import '../../deck/text_body.dart';
import 'pptx_theme.dart';
import 'pptx_xml.dart';

/// Run properties as a file states them: null means "not said here", so the
/// next style down the inheritance chain decides.
class RunProps {
  RunProps();

  factory RunProps.parse(XmlElement? rPr) {
    final props = RunProps();
    if (rPr == null) return props;
    final size = intAttribute(rPr, 'sz');
    if (size != null && size > 0) props.size = size / 100;
    props.bold = boolAttribute(rPr, 'b');
    props.italic = boolAttribute(rPr, 'i');
    final underline = rPr.getAttribute('u');
    if (underline != null) props.underline = underline != 'none';
    final strike = rPr.getAttribute('strike');
    if (strike != null) props.strike = strike != 'noStrike';
    for (final element in rPr.childElements) {
      switch (element.name.local) {
        case 'solidFill' || 'gradFill' || 'pattFill':
          props.fill = rPr;
        case 'latin':
          props.font = element.getAttribute('typeface');
      }
    }
    return props;
  }

  String? font;
  double? size;
  bool? bold;
  bool? italic;
  bool? underline;
  bool? strike;

  /// The element whose fill or color child paints the text. Kept unresolved
  /// because the same master style means different colors under the color
  /// maps of different slides.
  XmlElement? fill;

  RunProps over(RunProps? base) {
    if (base == null) return this;
    return RunProps()
      ..font = font ?? base.font
      ..size = size ?? base.size
      ..bold = bold ?? base.bold
      ..italic = italic ?? base.italic
      ..underline = underline ?? base.underline
      ..strike = strike ?? base.strike
      ..fill = fill ?? base.fill;
  }
}

/// A paragraph spacing: a share of the line height or a fixed size in points.
class Spacing {
  const Spacing.percent(this.value) : isPercent = true;
  const Spacing.points(this.value) : isPercent = false;

  static Spacing? parse(XmlElement? element) {
    final percent = fractionAttribute(child(element, 'spcPct'), 'val');
    if (percent != null) return Spacing.percent(percent);
    final points = intAttribute(child(element, 'spcPts'), 'val');
    return points == null ? null : Spacing.points(points / 100);
  }

  final bool isPercent;
  final double value;
}

/// Paragraph properties of an `a:pPr` or `a:lvlNpPr`, with the run defaults
/// (`a:defRPr`) that come with them.
class ParaProps {
  ParaProps();

  factory ParaProps.parse(XmlElement pPr) {
    final props = ParaProps()..align = _alignments[pPr.getAttribute('algn')];
    for (final element in pPr.childElements) {
      switch (element.name.local) {
        case 'lnSpc':
          props.lineSpacing = Spacing.parse(element);
        case 'spcBef':
          props.spaceBefore = Spacing.parse(element);
        case 'spcAft':
          props.spaceAfter = Spacing.parse(element);
        case 'buNone':
          props.bullet = BulletKind.none;
        case 'buChar' || 'buBlip':
          props.bullet = BulletKind.bullet;
        case 'buAutoNum':
          props.bullet = BulletKind.number;
        case 'defRPr':
          props.run = RunProps.parse(element);
      }
    }
    return props;
  }

  static const _alignments = {
    'l': ParagraphAlign.left,
    'ctr': ParagraphAlign.center,
    'r': ParagraphAlign.right,
    'just': ParagraphAlign.justify,
    'justLow': ParagraphAlign.justify,
    'dist': ParagraphAlign.justify,
    'thaiDist': ParagraphAlign.justify,
  };

  static final none = ParaProps();

  ParagraphAlign? align;
  BulletKind? bullet;
  Spacing? lineSpacing;
  Spacing? spaceBefore;
  Spacing? spaceAfter;
  RunProps run = RunProps();

  ParaProps over(ParaProps? base) {
    if (base == null) return this;
    return ParaProps()
      ..align = align ?? base.align
      ..bullet = bullet ?? base.bullet
      ..lineSpacing = lineSpacing ?? base.lineSpacing
      ..spaceBefore = spaceBefore ?? base.spaceBefore
      ..spaceAfter = spaceAfter ?? base.spaceAfter
      ..run = run.over(base.run);
  }
}

/// One `a:lstStyle`-shaped element (`p:titleStyle`, `p:defaultTextStyle`…):
/// paragraph properties for each of the nine list levels.
class ListStyle {
  ListStyle._(this.levels);

  /// Null when [element] says nothing, the usual `<a:lstStyle/>`.
  static ListStyle? parse(XmlElement? element) {
    if (element == null || element.firstElementChild == null) return null;
    final levels = List<ParaProps?>.filled(levelCount, null);
    ParaProps? shared;
    for (final entry in element.childElements) {
      final name = entry.name.local;
      if (name == 'defPPr') {
        shared = ParaProps.parse(entry);
      } else if (name.length == 7 &&
          name.startsWith('lvl') &&
          name.endsWith('pPr')) {
        final level = name.codeUnitAt(3) - 0x31;
        if (level >= 0 && level < levelCount) {
          levels[level] = ParaProps.parse(entry);
        }
      }
    }
    if (shared != null) {
      for (var i = 0; i < levelCount; i++) {
        levels[i] = levels[i]?.over(shared) ?? shared;
      }
    }
    return ListStyle._(levels);
  }

  /// The same run defaults on every level, as `a:fontRef` gives a shape.
  factory ListStyle.uniform(RunProps run) =>
      ListStyle._(List.filled(levelCount, ParaProps()..run = run));

  static const levelCount = Paragraph.maxLevel + 1;

  final List<ParaProps?> levels;
}

/// A stack of list styles, each one over its [parent]. The merged result of
/// a level is worked out once, so slides sharing a layout placeholder share
/// the work.
class TextChain {
  TextChain(this.parent, this.style);

  final TextChain? parent;
  final ListStyle? style;

  final _levels = List<ParaProps?>.filled(ListStyle.levelCount, null);

  TextChain extend(ListStyle? style) =>
      style == null ? this : TextChain(this, style);

  ParaProps level(int level) => _levels[level] ??=
      style?.levels[level]?.over(parent?.level(level)) ??
      parent?.level(level) ??
      ParaProps.none;
}

/// `a:normAutofit`, already applied to what is read: the model has no
/// shrink-to-fit of its own.
class TextShrink {
  const TextShrink({this.fontScale = 1, this.spacingReduction = 0});

  static const none = TextShrink();

  final double fontScale;
  final double spacingReduction;
}

/// Reads `p:txBody` elements of one slide into the model.
class TextReader {
  TextReader(this.theme, this.colors);

  final PptxTheme theme;
  final PptxColors colors;

  static final _controls = RegExp('\r\n|[\n\r\v]|_x000[BbAaDd]_');

  RunStyle style(RunProps props, [double fontScale = 1]) {
    final size = ((props.size ?? 18) * fontScale).clamp(1.0, 4000.0);
    return RunStyle(
      font: theme.font(props.font),
      size: size,
      bold: props.bold ?? false,
      italic: props.italic ?? false,
      underline: props.underline ?? false,
      strike: props.strike ?? false,
      color: _textColor(props.fill),
    );
  }

  int _textColor(XmlElement? holder) {
    if (holder == null) return 0xFF000000;
    final color = holder.name.local == 'fontRef'
        ? colors.colorIn(holder)
        : colors.fillIn(holder)?.color;
    return color ?? 0xFF000000;
  }

  /// The style text typed into a shape without any would get.
  TextBody empty(TextChain chain) => TextBody.empty(style(chain.level(0).run));

  TextBody read(
    XmlElement txBody,
    TextChain inherited, {
    TextShrink shrink = TextShrink.none,
  }) {
    final chain = inherited.extend(ListStyle.parse(child(txBody, 'lstStyle')));
    final paragraphs = [
      for (final element in txBody.childElements)
        if (element.name.local == 'p') _paragraph(element, chain, shrink),
    ];
    return paragraphs.isEmpty ? empty(chain) : TextBody(paragraphs);
  }

  Paragraph _paragraph(XmlElement p, TextChain chain, TextShrink shrink) {
    final pPr = child(p, 'pPr');
    final level = (intAttribute(pPr, 'lvl') ?? 0).clamp(0, Paragraph.maxLevel);
    final inherited = chain.level(level);
    final props = pPr == null
        ? inherited
        : ParaProps.parse(pPr).over(inherited);
    final scale = shrink.fontScale;

    RunStyle? defaultStyle;
    RunStyle styleOf(XmlElement? rPr) {
      if (rPr == null ||
          (rPr.attributes.isEmpty && rPr.firstElementChild == null)) {
        return defaultStyle ??= style(props.run, scale);
      }
      return style(RunProps.parse(rPr).over(props.run), scale);
    }

    final runs = <TextRun>[];
    final pending = StringBuffer();
    RunStyle? pendingStyle;
    void add(String text, RunStyle style) {
      if (text.isEmpty) return;
      if (pendingStyle != null && pendingStyle != style) {
        runs.add(TextRun(pending.toString(), pendingStyle!));
        pending.clear();
      }
      pendingStyle = style;
      pending.write(text);
    }

    XmlElement? endProperties;
    for (final element in contentElements(p)) {
      switch (element.name.local) {
        case 'r' || 'fld':
          add(
            _clean(child(element, 't')?.innerText ?? ''),
            styleOf(child(element, 'rPr')),
          );
        case 'br':
          final rPr = child(element, 'rPr');
          add(
            softBreak,
            rPr == null ? pendingStyle ?? styleOf(null) : styleOf(rPr),
          );
        case 'endParaRPr':
          endProperties = element;
      }
    }
    if (pendingStyle != null) {
      runs.add(TextRun(pending.toString(), pendingStyle!));
    } else {
      runs.add(TextRun('', styleOf(endProperties)));
    }

    final lineHeight = runs.first.style.size * 1.2;
    double points(Spacing? spacing) => spacing == null
        ? 0
        : spacing.isPercent
        ? spacing.value * lineHeight
        : spacing.value;
    final line = props.lineSpacing;
    final lineSpacing =
        (line == null
            ? 1.0
            : line.isPercent
            ? line.value
            : line.value / lineHeight) -
        shrink.spacingReduction;
    return Paragraph(
      runs: runs,
      align: props.align ?? ParagraphAlign.left,
      bullet: props.bullet ?? BulletKind.none,
      level: level,
      lineSpacing: lineSpacing.isFinite ? lineSpacing.clamp(0.1, 100.0) : 1,
      spaceBefore: points(props.spaceBefore).clamp(0.0, 10000.0),
      spaceAfter: points(props.spaceAfter).clamp(0.0, 10000.0),
    );
  }

  /// Paragraphs are separate objects in the model, so a line break inside
  /// the text of a run can only be a soft one or stray white space.
  static String _clean(String text) {
    if (!text.contains(_controls)) return text;
    return text.replaceAllMapped(_controls, (match) {
      final found = match[0]!;
      return found == '\v' || found.toUpperCase() == '_X000B_'
          ? softBreak
          : ' ';
    });
  }
}
