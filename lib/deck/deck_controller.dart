import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextSelection;

import '../text/text_layout.dart';
import 'element.dart';
import 'layouts.dart';
import 'presentation.dart';
import 'text_body.dart';
import 'text_ops.dart';
import 'undo_history.dart';

part 'deck_elements.dart';
part 'deck_slides.dart';
part 'deck_text.dart';

typedef _Snapshot = ({
  Presentation presentation,
  int slideIndex,
  Set<int> selection,
  int? editingId,
  TextSelection textSelection,
});

const _noSelection = TextSelection.collapsed(offset: 0);

Presentation _startingPresentation() {
  var id = 1;
  return Presentation(
    slides: [
      Slide(
        id: id++,
        elements: layoutElements(
          SlideLayout.titleSlide,
          defaultSlideSize,
          () => id++,
        ),
      ),
    ],
  );
}

/// The presentation being edited, what is selected in it and its history.
class DeckController extends _Deck with _Slides, _Elements, _Text {}

abstract class _Deck extends ChangeNotifier {
  _Deck() {
    _reset(_startingPresentation());
  }

  late Presentation _presentation;
  late Presentation _saved;
  var _slideIndex = 0;
  Set<int> _selection = const {};
  int? _editingId;
  var _textSelection = _noSelection;
  RunStyle? _pendingStyle;
  String? _name;
  String? _path;
  var _nextId = 1;
  final _history = UndoHistory<_Snapshot>();
  String? _coalesceKey;
  _Snapshot? _gesture;

  Presentation get presentation => _presentation;
  List<Slide> get slides => _presentation.slides;
  int get slideIndex => _slideIndex;
  Slide get slide => slides[_slideIndex];
  Set<int> get selection => _selection;
  int? get editingId => _editingId;
  TextSelection get textSelection => _textSelection;
  String? get name => _name;
  String? get path => _path;
  bool get dirty => !identical(_presentation, _saved);
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// The selected elements, from back to front.
  List<SlideElement> get selected => [
    for (final element in slide.elements)
      if (_selection.contains(element.id)) element,
  ];

  SlideElement? get single =>
      _selection.length == 1 ? slide.element(_selection.first) : null;

  /// The shape whose text is being typed.
  ShapeElement? get editing {
    final id = _editingId;
    final element = id == null ? null : slide.element(id);
    return element is ShapeElement ? element : null;
  }

  void newPresentation() => load(_startingPresentation());

  void load(Presentation presentation, {String? name, String? path}) {
    _reset(presentation);
    _name = name;
    _path = path;
    notifyListeners();
  }

  /// [written] is what went to the file; anything changed while it was
  /// being saved still counts as unsaved.
  void markSaved(
    Presentation written, {
    required String name,
    required String path,
  }) {
    _saved = written;
    _name = name;
    _path = path;
    notifyListeners();
  }

  void startEditing(int id, {int? position, bool selectAll = false});

  void stopEditing();

  void undo() => _travel(_history.takeUndo(_snapshot));

  void redo() => _travel(_history.takeRedo(_snapshot));

  void _reset(Presentation presentation) {
    _presentation = _saved = presentation;
    _slideIndex = 0;
    _selection = const {};
    _editingId = null;
    _textSelection = _noSelection;
    _pendingStyle = null;
    _history.clear();
    _coalesceKey = null;
    _gesture = null;
    var top = 0;
    for (final slide in presentation.slides) {
      top = math.max(top, slide.id);
      for (final element in slide.elements) {
        top = math.max(top, element.id);
      }
    }
    _nextId = top + 1;
  }

  int _newId() => _nextId++;

  _Snapshot get _snapshot => (
    presentation: _presentation,
    slideIndex: _slideIndex,
    selection: _selection,
    editingId: _editingId,
    textSelection: _textSelection,
  );

  void _travel(_Snapshot? to) {
    if (to == null) return;
    _presentation = to.presentation;
    _slideIndex = to.slideIndex;
    _selection = to.selection;
    _editingId = to.editingId;
    _textSelection = to.textSelection;
    _pendingStyle = null;
    _coalesceKey = null;
    _gesture = null;
    notifyListeners();
  }

  /// Keeps the state before a change. Changes in a row with the same
  /// [coalesce] key are undone together.
  void _record({String? coalesce}) {
    if (_gesture != null) return;
    if (coalesce == null || coalesce != _coalesceKey) {
      _history.record(_snapshot);
    }
    _coalesceKey = coalesce;
  }

  void _setSlides(List<Slide> slides) =>
      _presentation = _presentation.copyWith(slides: slides);

  void _setSlide(Slide changed) => _setSlides([
    for (var index = 0; index < slides.length; index++)
      index == _slideIndex ? changed : slides[index],
  ]);

  void _setElements(List<SlideElement> elements) =>
      _setSlide(slide.copyWith(elements: elements));

  /// Puts each of [changed] in the place of the element with its id.
  void _swap(Iterable<SlideElement> changed) {
    final byId = {for (final element in changed) element.id: element};
    if (byId.isEmpty) return;
    _setElements([
      for (final element in slide.elements) byId[element.id] ?? element,
    ]);
  }

  /// A copy of [element] that no other element shares the id with.
  SlideElement _fresh(SlideElement element) => element.withId(_newId());

  /// Makes a shape whose height follows its text as tall as the text.
  SlideElement _refit(SlideElement element) {
    if (element is! ShapeElement || !element.autoFit || element.isLine) {
      return element;
    }
    final frame = element.frame;
    final height = fittedHeightOf(element);
    if ((height - frame.height).abs() < 0.01) return element;
    final top = switch (element.anchor) {
      TextAnchor.top => frame.top,
      TextAnchor.middle => frame.center.dy - height / 2,
      TextAnchor.bottom => frame.bottom - height,
    };
    return element.copyWith(
      frame: Rect.fromLTWH(frame.left, top, frame.width, height),
    );
  }
}
