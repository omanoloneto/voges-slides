part of 'deck_controller.dart';

enum Arrange { front, back, forward, backward }

mixin _Elements on _Deck {
  List<SlideElement> _clip = const [];

  bool get canPasteElements => _clip.isNotEmpty;
  bool get hasLocked => slide.elements.any((element) => element.locked);

  void select(Set<int> ids) {
    stopEditing();
    final present = {
      for (final id in ids)
        if (slide.element(id) != null) id,
    };
    if (setEquals(present, _selection)) return;
    _selection = present;
    _coalesceKey = null;
    notifyListeners();
  }

  void toggleSelection(int id) => select(
    _selection.contains(id)
        ? ({..._selection}..remove(id))
        : {..._selection, id},
  );

  void clearSelection() => select(const {});

  void selectAll() => select({
    for (final element in slide.elements)
      if (!element.locked) element.id,
  });

  /// Walks the selection through the elements, as Tab does.
  void selectNext({bool backwards = false}) {
    final ids = [
      for (final element in slide.elements)
        if (!element.locked) element.id,
    ];
    if (ids.isEmpty) return;
    final current = _selection.length == 1 ? ids.indexOf(_selection.first) : -1;
    final next = current < 0
        ? (backwards ? ids.length - 1 : 0)
        : (current + (backwards ? -1 : 1)) % ids.length;
    select({ids[next]});
  }

  Offset get _center => _presentation.size.center(Offset.zero);

  double get _fontSize =>
      math.max(8, (18 * _presentation.size.height / 540).roundToDouble());

  void addTextBox() {
    stopEditing();
    _record();
    final look = LayoutLook.of(slide);
    final box = _refit(
      ShapeElement(
        id: _newId(),
        frame: Rect.fromCenter(
          center: _center,
          width: _presentation.size.width * 0.32,
          height: 30,
        ),
        autoFit: true,
        text: TextBody.empty(
          RunStyle(font: look.bodyFont, size: _fontSize, color: look.bodyColor),
        ),
      ),
    );
    _add(box);
    startEditing(box.id);
  }

  void addShape(ShapeKind kind, {bool arrow = false}) {
    stopEditing();
    _record();
    final isLine = kind == ShapeKind.line;
    final unit = _presentation.size.shortestSide;
    _add(
      ShapeElement(
        id: _newId(),
        frame: Rect.fromCenter(
          center: _center,
          width: isLine ? unit * 0.37 : unit / 3,
          height: isLine ? 0 : unit * 2 / 9,
        ),
        kind: kind,
        fill: isLine ? null : 0xFF4472C4,
        stroke: isLine ? 0xFF000000 : null,
        strokeWidth: isLine ? 1.5 : 1,
        endArrow: arrow,
        anchor: TextAnchor.middle,
        text: TextBody([
          Paragraph(
            runs: [
              TextRun(
                '',
                RunStyle(
                  font: LayoutLook.of(slide).bodyFont,
                  size: _fontSize,
                  color: 0xFFFFFFFF,
                ),
              ),
            ],
            align: ParagraphAlign.center,
          ),
        ]),
      ),
    );
  }

  /// Adds a picture of [pixels] size, no larger than most of the slide.
  void addImage(ImageData image, Size pixels) {
    stopEditing();
    _record();
    final size = _presentation.size;
    final scale = [
      0.75,
      size.width * 0.6 / math.max(1, pixels.width),
      size.height * 0.6 / math.max(1, pixels.height),
    ].reduce(math.min);
    _add(
      ImageElement(
        id: _newId(),
        frame: Rect.fromCenter(
          center: _center,
          width: pixels.width * scale,
          height: pixels.height * scale,
        ),
        image: image,
      ),
    );
  }

  void deleteSelection() {
    if (_selection.isEmpty) return;
    _record();
    _setElements([
      for (final element in slide.elements)
        if (!_selection.contains(element.id)) element,
    ]);
    _selection = const {};
    _editingId = null;
    _textSelection = _noSelection;
    notifyListeners();
  }

  /// Starts a drag: what [replaceElements] does until [endGesture] is one
  /// step of the history.
  void beginGesture() {
    _coalesceKey = null;
    _gesture = _snapshot;
  }

  void replaceElements(Iterable<SlideElement> changed) {
    _record();
    _swap(changed.map(_refit));
    notifyListeners();
  }

  void endGesture() {
    final before = _gesture;
    _gesture = null;
    if (before != null && !identical(before.presentation, _presentation)) {
      _history.record(before);
      notifyListeners();
    }
  }

  void nudge(Offset delta) {
    if (_selection.isEmpty) return;
    _record(coalesce: 'nudge');
    _swap([
      for (final element in selected)
        element.withGeometry(frame: element.frame.shift(delta)),
    ]);
    notifyListeners();
  }

  void arrange(Arrange how) {
    if (_selection.isEmpty) return;
    bool picked(SlideElement element) => _selection.contains(element.id);
    final order = [...slide.elements];
    switch (how) {
      case Arrange.front:
        order
          ..removeWhere(picked)
          ..addAll(selected);
      case Arrange.back:
        order.removeWhere(picked);
        // locked elements are the backdrop of the slide; nothing goes below
        final floor = order.lastIndexWhere((element) => element.locked) + 1;
        order.insertAll(floor, selected);
      case Arrange.forward:
        for (var index = order.length - 2; index >= 0; index--) {
          if (picked(order[index]) && !picked(order[index + 1])) {
            final above = order[index + 1];
            order[index + 1] = order[index];
            order[index] = above;
          }
        }
      case Arrange.backward:
        for (var index = 1; index < order.length; index++) {
          final below = order[index - 1];
          if (picked(order[index]) && !picked(below) && !below.locked) {
            order[index - 1] = order[index];
            order[index] = below;
          }
        }
    }
    if (listEquals(order, slide.elements)) return;
    _record();
    _setElements(order);
    notifyListeners();
  }

  void setFill(int? color) =>
      _changeShapes((shape) => shape.copyWith(fill: color), lines: false);

  void setStroke(int? color) => _changeShapes(
    (shape) => shape.copyWith(
      stroke: color,
      strokeWidth: shape.strokeWidth > 0 ? null : 1,
    ),
  );

  void setStrokeWidth(double width) => _changeShapes(
    (shape) =>
        shape.copyWith(strokeWidth: width, stroke: shape.stroke ?? 0xFF000000),
  );

  void setAnchor(TextAnchor anchor) => _changeShapes(
    (shape) => _refit(shape.copyWith(anchor: anchor)) as ShapeElement,
    lines: false,
  );

  /// The first shape selected, whose fill and outline the ribbon shows.
  ShapeElement? get firstShape {
    for (final element in selected) {
      if (element is ShapeElement) return element;
    }
    return null;
  }

  /// Copies the selection; returns its text for the system clipboard.
  String copyElements() {
    _clip = selected;
    return [
      for (final element in _clip)
        if (element is ShapeElement && !element.text.isEmpty)
          plainText(element.text, 0, element.text.length),
    ].join('\n');
  }

  void pasteElements() {
    if (_clip.isEmpty) return;
    _clip = _addCopies(_clip);
  }

  void duplicateSelection() {
    if (_selection.isNotEmpty) _addCopies(selected);
  }

  void unlockBackground() {
    if (!hasLocked) return;
    _record();
    _setElements([
      for (final element in slide.elements)
        element.locked ? element.withLocked(false) : element,
    ]);
    notifyListeners();
  }

  List<SlideElement> _addCopies(List<SlideElement> sources) {
    stopEditing();
    _record();
    final copies = [
      for (final source in sources)
        _fresh(
          source.withLocked(false),
        ).withGeometry(frame: source.frame.shift(const Offset(12, 12))),
    ];
    _setElements([...slide.elements, ...copies]);
    _selection = {for (final copy in copies) copy.id};
    notifyListeners();
    return copies;
  }

  void _add(SlideElement element) {
    _setElements([...slide.elements, element]);
    _selection = {element.id};
    notifyListeners();
  }

  void _changeShapes(
    ShapeElement Function(ShapeElement shape) change, {
    bool lines = true,
  }) {
    final changed = [
      for (final element in selected)
        if (element is ShapeElement && (lines || !element.isLine))
          change(element),
    ];
    if (changed.isEmpty) return;
    _record();
    _swap(changed);
    notifyListeners();
  }
}
