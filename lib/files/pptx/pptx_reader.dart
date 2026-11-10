import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:xml/xml.dart';

import '../../deck/element.dart';
import '../../deck/presentation.dart';
import '../presentation_file_exception.dart';
import 'opc_package.dart';
import 'pptx_import.dart';
import 'pptx_parts.dart';
import 'pptx_text.dart';
import 'pptx_theme.dart';
import 'pptx_tree.dart';
import 'pptx_xml.dart';

/// Reads a `.pptx` file into the model, with everything a slide inherits
/// from its layout, master and theme already resolved.
///
/// Throws a [PresentationFileException] when [bytes] cannot be read as a
/// presentation. Uses no Flutter binding, so it can run in an isolate.
PptxImport readPptx(Uint8List bytes) {
  try {
    return _PptxReader(ImportSession(OpcPackage.decode(bytes))).read();
  } on PresentationFileException {
    rethrow;
  } catch (_) {
    throw PresentationFileException(PresentationProblem.notPresentation);
  }
}

class _PptxReader {
  _PptxReader(this.session);

  final ImportSession session;

  final _layouts = <String, LayoutPart?>{};
  final _masters = <String, MasterPart?>{};
  final _themes = <String, PptxTheme>{};
  late final TextChain _defaults;

  OpcPackage get _package => session.package;

  /// The theme of slides whose layout or master cannot be read.
  late final PptxTheme _fallbackTheme = _theme(
    session.related(_package.mainPath, 'theme'),
  );

  PptxImport read() {
    final mainPath = _package.mainPath;
    final root = _package.xml(mainPath)?.rootElement;
    if (root == null || root.name.local != 'presentation') {
      throw PresentationFileException(PresentationProblem.notPresentation);
    }
    _defaults = TextChain(
      null,
      ListStyle.parse(child(root, 'defaultTextStyle')),
    );
    final relationships = {
      for (final relationship in _package.relationships(mainPath))
        relationship.id: relationship,
    };

    final slides = <Slide>[];
    final list = child(root, 'sldIdLst');
    if (list != null) {
      for (final entry in children(list, 'sldId')) {
        final relationship = relationships[relationshipAttribute(entry, 'id')];
        if (relationship == null) continue;
        final path = _package.targetOf(mainPath, relationship);
        final slide = path == null ? null : _package.xml(path)?.rootElement;
        if (slide == null || slide.name.local != 'sld') continue;
        slides.add(_slide(path!, slide));
      }
    }
    if (slides.isEmpty) slides.add(Slide(id: session.nextId()));
    return PptxImport(
      Presentation(size: _slideSize(child(root, 'sldSz')), slides: slides),
      session.losses,
    );
  }

  static Size _slideSize(XmlElement? size) {
    final width = pointsAttribute(size, 'cx');
    final height = pointsAttribute(size, 'cy');
    if (width == null || height == null || width < 1 || height < 1) {
      return defaultSlideSize;
    }
    return Size(width, height);
  }

  Slide _slide(String path, XmlElement root) {
    final layout = _layout(session.related(path, 'slideLayout'));
    final master = layout?.master;
    final theme = master?.theme ?? _fallbackTheme;
    final override = readColorMapOverride(root);
    final colors = PptxColors(
      theme,
      override ?? layout?.colorMapOverride ?? master?.colorMap ?? const {},
    );

    final id = session.nextId();
    final elements = <SlideElement>[];
    if (layout != null && (boolAttribute(root, 'showMasterSp') ?? true)) {
      final decorations = override == null
          ? layout.decorations ??= _decorations(layout, colors)
          : _decorations(layout, colors);
      for (final decoration in decorations) {
        elements.add(decoration.withId(session.nextId()));
      }
    }
    elements.addAll(
      TreeReader(
        session,
        partPath: path,
        colors: colors,
        text: TextReader(theme, colors),
        defaults: _defaults,
        master: master,
        layout: layout,
      ).read(root),
    );

    final background =
        _background(path, root, colors) ??
        (layout == null
            ? null
            : override == null
            ? _sharedBackground(layout, colors)
            : _inheritedBackground(layout, colors));
    _checkNotes(path);
    _checkAnimations(root);
    return Slide(
      id: id,
      background: background?.color ?? 0xFFFFFFFF,
      backgroundImage: background?.image,
      elements: elements,
    );
  }

  /// What the master and the layout draw behind the content of a slide, as
  /// locked elements with id 0 for each slide to copy.
  List<SlideElement> _decorations(LayoutPart layout, PptxColors colors) {
    final master = layout.master;
    final text = TextReader(colors.theme, colors);
    List<SlideElement> read(String path, XmlElement root) => TreeReader(
      session,
      partPath: path,
      colors: colors,
      text: text,
      defaults: _defaults,
      master: master,
      decoration: true,
    ).read(root);

    return [
      if (master != null && layout.showMasterShapes)
        ...read(master.path, master.root),
      ...read(layout.path, layout.root),
    ];
  }

  Background? _sharedBackground(LayoutPart layout, PptxColors colors) {
    if (!layout.backgroundRead) {
      layout.background = _inheritedBackground(layout, colors);
      layout.backgroundRead = true;
    }
    return layout.background;
  }

  Background? _inheritedBackground(LayoutPart layout, PptxColors colors) {
    final master = layout.master;
    return _background(layout.path, layout.root, colors) ??
        (master == null ? null : _background(master.path, master.root, colors));
  }

  /// The `p:bg` of one part, or null when it leaves the background to the
  /// part it inherits from.
  Background? _background(String path, XmlElement root, PptxColors colors) {
    final background = descend(root, ['cSld', 'bg']);
    final properties = child(background, 'bgPr');
    if (properties == null) {
      final color = colors.colorIn(child(background, 'bgRef'));
      return color == null ? null : Background(color, null);
    }
    final blip = descend(properties, ['blipFill', 'blip']);
    if (blip != null) {
      final image = session.image(path, relationshipAttribute(blip, 'embed'));
      if (image == null || !image.decodable) {
        session.losses.add(ImportLoss.images);
      }
      return Background(null, image);
    }
    final fill = colors.fillIn(properties);
    if (fill == null) return null;
    if (fill.approximate) session.losses.add(ImportLoss.shapes);
    return Background(fill.color, null);
  }

  void _checkNotes(String slidePath) {
    if (session.losses.contains(ImportLoss.notes)) return;
    final path = session.related(slidePath, 'notesSlide');
    final tree = descend(_optionalRoot(path, 'notes'), ['cSld', 'spTree']);
    if (tree == null) return;
    for (final shape in contentElements(tree)) {
      if (shape.name.local != 'sp') continue;
      if (Placeholder.of(shape)?.getAttribute('type') != 'body') continue;
      final hasText = shape.descendantElements.any(
        (element) =>
            element.name.local == 't' && element.innerText.trim().isNotEmpty,
      );
      if (hasText) {
        session.losses.add(ImportLoss.notes);
        return;
      }
    }
  }

  void _checkAnimations(XmlElement root) {
    if (session.losses.contains(ImportLoss.animations)) return;
    for (final element in contentElements(root)) {
      final name = element.name.local;
      if (name == 'transition' ||
          (name == 'timing' && element.firstElementChild != null)) {
        session.losses.add(ImportLoss.animations);
        return;
      }
    }
  }

  LayoutPart? _layout(String? path) {
    if (path == null) return null;
    if (_layouts.containsKey(path)) return _layouts[path];
    final root = _optionalRoot(path, 'sldLayout');
    return _layouts[path] = root == null
        ? null
        : LayoutPart(
            path: path,
            root: root,
            master: _master(session.related(path, 'slideMaster')),
          );
  }

  MasterPart? _master(String? path) {
    if (path == null) return null;
    if (_masters.containsKey(path)) return _masters[path];
    final root = _optionalRoot(path, 'sldMaster');
    return _masters[path] = root == null
        ? null
        : MasterPart(
            path: path,
            root: root,
            theme: _theme(session.related(path, 'theme')),
            defaults: _defaults,
          );
  }

  PptxTheme _theme(String? path) {
    if (path == null) return const PptxTheme();
    return _themes[path] ??= PptxTheme.parse(_optionalRoot(path, 'theme'));
  }

  /// The root of a part a slide can be read without. Missing, malformed or
  /// of another kind all count as not there.
  XmlElement? _optionalRoot(String? path, String name) {
    if (path == null) return null;
    try {
      final root = _package.xml(path)?.rootElement;
      return root?.name.local == name ? root : null;
    } on FormatException {
      return null;
    }
  }
}
