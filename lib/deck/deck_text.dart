part of 'deck_controller.dart';

mixin _Text on _Deck {
  var _typingStep = 0;

  TextSelection get _range => _textSelection;

  Iterable<ShapeElement> get _textShapes sync* {
    for (final element in selected) {
      if (element is ShapeElement && !element.isLine) yield element;
    }
  }

  @override
  void startEditing(int id, {int? position, bool selectAll = false}) {
    final element = slide.element(id);
    if (element is! ShapeElement || element.isLine || element.locked) return;
    if (_editingId != id) stopEditing();
    final length = element.text.length;
    _editingId = id;
    _selection = {id};
    _textSelection = selectAll
        ? TextSelection(baseOffset: 0, extentOffset: length)
        : TextSelection.collapsed(
            offset: (position ?? length).clamp(0, length),
          );
    _pendingStyle = null;
    _coalesceKey = null;
    notifyListeners();
  }

  @override
  void stopEditing() {
    if (_editingId == null) return;
    final shape = editing;
    _editingId = null;
    _textSelection = _noSelection;
    _pendingStyle = null;
    _coalesceKey = null;
    final abandoned =
        shape != null &&
        shape.autoFit &&
        shape.placeholder == null &&
        shape.fill == null &&
        shape.stroke == null &&
        shape.text.isEmpty;
    if (abandoned) {
      _setElements([
        for (final element in slide.elements)
          if (element.id != shape.id) element,
      ]);
      _selection = {..._selection}..remove(shape.id);
    }
    notifyListeners();
  }

  /// Replaces a range of the text being edited. Typing in a row is undone a
  /// word at a time.
  void replaceTextRange(
    int start,
    int end,
    String text, {
    TextSelection? selection,
    bool typing = true,
  }) {
    final shape = editing;
    if (shape == null) return;
    final body = shape.text;
    final from = start.clamp(0, body.length);
    final to = end.clamp(from, body.length);
    if (from == to && text.isEmpty) {
      if (selection != null) setTextSelection(selection);
      return;
    }
    if (text == '\n' && from == to && _leaveList(shape, from)) return;
    _record(
      coalesce: !typing
          ? null
          : text.isEmpty
          ? 'delete:${shape.id}'
          : 'type:${shape.id}:$_typingStep',
    );
    if (typing && text.isNotEmpty && text.trim().isEmpty) _typingStep++;
    final changed = replaceText(body, from, to, text, style: _pendingStyle);
    _pendingStyle = null;
    _swap([_refit(shape.copyWith(text: changed))]);
    _textSelection = _clamped(
      selection ?? TextSelection.collapsed(offset: from + text.length),
      changed.length,
    );
    notifyListeners();
  }

  /// Puts [text] in the place of what is selected in the text being edited.
  void insertText(String text, {bool typing = true}) =>
      replaceTextRange(_range.start, _range.end, text, typing: typing);

  void setTextSelection(TextSelection selection) {
    final shape = editing;
    if (shape == null) return;
    final clamped = _clamped(selection, shape.text.length);
    if (clamped == _textSelection) return;
    _textSelection = clamped;
    _pendingStyle = null;
    _coalesceKey = null;
    notifyListeners();
  }

  String get selectedText {
    final shape = editing;
    return shape == null ? '' : plainText(shape.text, _range.start, _range.end);
  }

  /// Restyles the selected text; with only a caret, what is typed next.
  /// Outside editing it restyles all the text of the selected shapes.
  void formatText(RunStyle Function(RunStyle style) change) {
    final shape = editing;
    if (shape == null) {
      final changed = [
        for (final element in _textShapes)
          _restyled(element, 0, element.text.length, change),
      ].nonNulls.toList();
      if (changed.isEmpty) return;
      _record();
      _swap(changed);
      notifyListeners();
      return;
    }
    final start = _range.start, end = _range.end;
    final changed = _restyled(shape, start, end, change);
    if (start == end) {
      _pendingStyle = change(
        _pendingStyle ?? insertionStyle(shape.text, start, end),
      );
    } else if (changed == null) {
      return;
    }
    if (changed != null) {
      _record();
      _swap([changed]);
    }
    notifyListeners();
  }

  /// Changes the paragraphs the selection touches, or every paragraph of
  /// the selected shapes outside editing.
  void formatParagraphs(Paragraph Function(Paragraph paragraph) change) {
    final shape = editing;
    final changed = [
      if (shape != null)
        shape.copyWith(
          text: mapParagraphs(shape.text, _range.start, _range.end, change),
        )
      else
        for (final element in _textShapes)
          element.copyWith(
            text: mapParagraphs(element.text, 0, element.text.length, change),
          ),
    ];
    if (changed.isEmpty) return;
    _record();
    _swap(changed.map(_refit));
    notifyListeners();
  }

  void changeLevel(int delta) => formatParagraphs(
    (paragraph) => paragraph.copyWith(
      level: (paragraph.level + delta).clamp(0, Paragraph.maxLevel),
    ),
  );

  /// The style the ribbon shows: of what is typed next, or of the first
  /// text selected.
  RunStyle? get currentStyle {
    final shape = editing;
    if (shape != null) {
      return _pendingStyle ??
          insertionStyle(shape.text, _range.start, _range.end);
    }
    for (final element in _textShapes) {
      return element.text.paragraphs.first.runs.first.style;
    }
    return null;
  }

  Paragraph? get currentParagraph {
    final shape = editing;
    if (shape != null) return paragraphAt(shape.text, _range.start);
    for (final element in _textShapes) {
      return element.text.paragraphs.first;
    }
    return null;
  }

  /// Whether all the text a format would change passes [test].
  bool everyStyle(bool Function(RunStyle style) test) {
    final shape = editing;
    if (shape != null) {
      final pending = _pendingStyle;
      return pending != null
          ? test(pending)
          : everyRun(shape.text, _range.start, _range.end, test);
    }
    var any = false;
    for (final element in _textShapes) {
      if (!everyRun(element.text, 0, element.text.length, test)) return false;
      any = true;
    }
    return any;
  }

  /// Whether every paragraph a format would change passes [test].
  bool everyParagraph(bool Function(Paragraph paragraph) test) {
    final shape = editing;
    if (shape != null) {
      final first = locate(shape.text, _range.start).paragraph;
      final last = locate(shape.text, _range.end).paragraph;
      return shape.text.paragraphs.getRange(first, last + 1).every(test);
    }
    var any = false;
    for (final element in _textShapes) {
      if (!element.text.paragraphs.every(test)) return false;
      any = true;
    }
    return any;
  }

  TextSelection _clamped(TextSelection selection, int length) =>
      selection.copyWith(
        baseOffset: selection.baseOffset.clamp(0, length),
        extentOffset: selection.extentOffset.clamp(0, length),
      );

  ShapeElement? _restyled(
    ShapeElement shape,
    int start,
    int end,
    RunStyle Function(RunStyle style) change,
  ) {
    final changed = mapRuns(shape.text, start, end, change);
    return identical(changed, shape.text)
        ? null
        : _refit(shape.copyWith(text: changed)) as ShapeElement;
  }

  /// Enter on an empty item of a list leaves the list a level at a time
  /// instead of adding another empty item.
  bool _leaveList(ShapeElement shape, int position) {
    final paragraph = paragraphAt(shape.text, position);
    if (paragraph.length > 0 || paragraph.bullet == BulletKind.none) {
      return false;
    }
    _record();
    _swap([
      _refit(
        shape.copyWith(
          text: mapParagraphs(
            shape.text,
            position,
            position,
            (paragraph) => paragraph.level > 0
                ? paragraph.copyWith(level: paragraph.level - 1)
                : paragraph.copyWith(bullet: BulletKind.none),
          ),
        ),
      ),
    ]);
    notifyListeners();
    return true;
  }
}
