import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../deck/deck_controller.dart';
import '../deck/element.dart';
import '../deck/presentation.dart';
import '../deck/text_body.dart';
import '../deck/text_ops.dart';
import '../l10n/l10n.dart';
import '../render/slide_images.dart';
import '../render/slide_painter.dart';
import 'canvas_geometry.dart';
import 'canvas_overlay.dart';
import 'context_menu.dart';
import 'status_bar.dart';
import 'text_actions.dart';
import 'text_input_bridge.dart';

enum _DragKind { move, resize, rotate, line, marquee, text }

class _Drag {
  _Drag(
    this.kind,
    this.start,
    this.startLocal, {
    this.originals = const [],
    this.handle,
    this.editOnClick = false,
    this.kept = const {},
    this.base = 0,
  });

  final _DragKind kind;

  /// Where the button went down, on the slide and on the canvas.
  final Offset start;
  final Offset startLocal;
  final List<SlideElement> originals;
  final Handle? handle;

  /// A click that does not become a drag starts typing in the shape.
  final bool editOnClick;

  /// What stays selected whatever the marquee catches.
  final Set<int> kept;

  /// Where the text selection being dragged begins.
  final int base;

  var started = false;

  bool get changesElements =>
      kind != _DragKind.marquee && kind != _DragKind.text;
}

/// The slide being edited, with selection, drag handles and typing.
class SlideCanvas extends StatefulWidget {
  const SlideCanvas({
    required this.controller,
    required this.images,
    required this.focusNode,
    required this.zoom,
    required this.scale,
    required this.onZoom,
    required this.onCut,
    required this.onCopy,
    required this.onPaste,
    super.key,
  });

  final DeckController controller;
  final SlideImages images;
  final FocusNode focusNode;

  /// Null fits the slide in the view.
  final double? zoom;

  /// Told the scale the slide ends up drawn at.
  final ValueNotifier<double> scale;
  final ValueChanged<double?> onZoom;
  final VoidCallback onCut;
  final VoidCallback onCopy;
  final VoidCallback onPaste;

  @override
  State<SlideCanvas> createState() => _SlideCanvasState();
}

class _SlideCanvasState extends State<SlideCanvas> {
  static const _padding = 24.0;
  static const _reach = 8.0;
  static const _dragSlop = 3.0;
  static const _doubleClick = Duration(milliseconds: 400);

  late final _bridge = TextInputBridge(
    controller: widget.controller,
    focusNode: widget.focusNode,
  );
  late final _textActions = TextEditingActions(
    controller: widget.controller,
    cut: () => widget.onCut(),
    copy: () => widget.onCopy(),
    paste: () => widget.onPaste(),
  );
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final _cursor = ValueNotifier<MouseCursor>(SystemMouseCursors.basic);
  final _marquee = ValueNotifier<Rect?>(null);
  final _caretOn = ValueNotifier(true);
  final _slideChanges = ValueNotifier(0);
  Timer? _blink;

  late Size _slideSize = widget.controller.presentation.size;
  ({Slide slide, int? editingId})? _painted;
  var _origin = Offset.zero;
  var _scale = 1.0;

  _Drag? _drag;
  var _clicks = 0;
  var _lastDown = Duration.zero;
  var _lastDownAt = Offset.zero;

  DeckController get _deck => widget.controller;

  @override
  void initState() {
    super.initState();
    _deck.addListener(_onDeckChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _deck.removeListener(_onDeckChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _blink?.cancel();
    _bridge.close();
    _vertical.dispose();
    _horizontal.dispose();
    _cursor.dispose();
    _marquee.dispose();
    _caretOn.dispose();
    _slideChanges.dispose();
    super.dispose();
  }

  void _onDeckChanged() {
    final slide = _deck.slide, editingId = _deck.editingId;
    final painted = _painted;
    if (painted == null ||
        !identical(painted.slide, slide) ||
        painted.editingId != editingId) {
      _painted = (slide: slide, editingId: editingId);
      _slideChanges.value++;
    }
    final size = _deck.presentation.size;
    if (size != _slideSize) setState(() => _slideSize = size);
    _onFocusChanged();
  }

  void _onFocusChanged() {
    _bridge.sync(View.of(context).viewId);
    _blink?.cancel();
    _blink = null;
    _caretOn.value = true;
    if (_deck.editing == null || !widget.focusNode.hasFocus) return;
    _blink = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _caretOn.value = !_caretOn.value,
    );
  }

  Offset _toSlide(Offset local) => (local - _origin) / _scale;

  double get _slop => _reach / _scale;
  double get _rotateGap => rotateHandleGap / _scale;

  bool get _shift => HardwareKeyboard.instance.isShiftPressed;

  bool get _command =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  int _countClick(PointerDownEvent event) {
    final again =
        event.timeStamp - _lastDown <= _doubleClick &&
        (event.localPosition - _lastDownAt).distance <= 4;
    _clicks = again ? _clicks + 1 : 1;
    _lastDown = event.timeStamp;
    _lastDownAt = event.localPosition;
    return _clicks;
  }

  void _onDown(PointerDownEvent event) {
    widget.focusNode.requestFocus();
    final point = _toSlide(event.localPosition);
    if (event.buttons & kSecondaryMouseButton != 0) {
      _openMenu(event.position, point);
      return;
    }
    if (event.buttons & kPrimaryMouseButton == 0) return;
    final clicks = _countClick(event);
    final local = event.localPosition;

    final editing = _deck.editing;
    if (editing != null) {
      final handle = handleAt(editing, point, _slop, _rotateGap);
      if (handle != null) {
        _drag = _handleDrag(editing, handle, point, local);
        return;
      }
      if (hits(editing, point, _slop)) {
        _placeCaret(editing, point, local, clicks, extend: _shift);
        return;
      }
      _deck.stopEditing();
    }
    final single = _deck.single;
    final handle = single == null
        ? null
        : handleAt(single, point, _slop, _rotateGap);
    if (single != null && handle != null) {
      _drag = _handleDrag(single, handle, point, local);
      return;
    }
    final hit = elementAt(_deck.slide, point, _slop);
    if (hit == null) {
      final kept = _shift ? _deck.selection : const <int>{};
      if (!_shift) _deck.clearSelection();
      _drag = _Drag(_DragKind.marquee, point, local, kept: kept);
      return;
    }
    if (_shift) {
      _deck.toggleSelection(hit.id);
      return;
    }
    final takesText = hit is ShapeElement && !hit.isLine;
    if (clicks >= 2 && takesText) {
      _deck.startEditing(hit.id);
      final shape = _deck.editing;
      if (shape != null) {
        _placeCaret(shape, point, local, clicks, extend: false);
      }
      return;
    }
    final wasAlone = single != null && single.id == hit.id;
    if (!_deck.selection.contains(hit.id)) _deck.select({hit.id});
    _drag = _Drag(
      _DragKind.move,
      point,
      local,
      originals: _deck.selected,
      editOnClick: wasAlone && takesText,
    );
  }

  _Drag _handleDrag(
    SlideElement element,
    Handle handle,
    Offset point,
    Offset local,
  ) => _Drag(
    switch (handle.kind) {
      HandleKind.resize => _DragKind.resize,
      HandleKind.rotate => _DragKind.rotate,
      HandleKind.lineStart || HandleKind.lineEnd => _DragKind.line,
    },
    point,
    local,
    originals: [element],
    handle: handle,
  );

  /// A click in the text being typed: one puts the caret, two take the
  /// word, three the paragraph.
  void _placeCaret(
    ShapeElement shape,
    Offset point,
    Offset local,
    int clicks, {
    required bool extend,
  }) {
    final position = textPositionAt(shape, point);
    final text = shape.text.text;
    var base = position, extent = position;
    if (clicks == 2) {
      final word = wordAround(text, position);
      base = word.start;
      extent = word.end;
    } else if (clicks >= 3) {
      base = position == 0 ? 0 : text.lastIndexOf('\n', position - 1) + 1;
      final end = text.indexOf('\n', position);
      extent = end < 0 ? text.length : end;
    } else if (extend) {
      base = _deck.textSelection.baseOffset;
    }
    _deck.setTextSelection(
      TextSelection(baseOffset: base, extentOffset: extent),
    );
    _drag = _Drag(_DragKind.text, point, local, base: base);
  }

  void _onMove(PointerMoveEvent event) {
    final drag = _drag;
    if (drag == null) return;
    if (!drag.started) {
      if ((event.localPosition - drag.startLocal).distance < _dragSlop) return;
      drag.started = true;
      if (drag.changesElements) _deck.beginGesture();
    }
    final point = _toSlide(event.localPosition);
    switch (drag.kind) {
      case _DragKind.move:
        var by = point - drag.start;
        if (_shift) {
          by = by.dx.abs() >= by.dy.abs() ? Offset(by.dx, 0) : Offset(0, by.dy);
        }
        _deck.replaceElements([
          for (final element in drag.originals)
            element.withGeometry(frame: element.frame.shift(by)),
        ]);
      case _DragKind.resize:
        final original = drag.originals.single, handle = drag.handle!;
        _deck.replaceElements([
          resized(
            original,
            handle,
            point,
            keepAspect: handle.isCorner && (original is ImageElement || _shift),
          ),
        ]);
      case _DragKind.rotate:
        final original = drag.originals.single;
        _deck.replaceElements([
          original.withGeometry(
            rotation: rotationToward(original, point, snap: _shift),
          ),
        ]);
      case _DragKind.line:
        final line = drag.originals.single as ShapeElement;
        final movesStart = drag.handle!.kind == HandleKind.lineStart;
        final anchor = movesStart ? line.lineEnd : line.lineStart;
        final end = _shift ? snappedLineEnd(anchor, point) : point;
        _deck.replaceElements([
          movesStart
              ? lineBetween(line, end, anchor)
              : lineBetween(line, anchor, end),
        ]);
      case _DragKind.marquee:
        _marquee.value = Rect.fromPoints(drag.start, point);
      case _DragKind.text:
        final shape = _deck.editing;
        if (shape == null) return;
        _deck.setTextSelection(
          TextSelection(
            baseOffset: drag.base,
            extentOffset: textPositionAt(shape, point),
          ),
        );
    }
  }

  void _onUp(PointerEvent event) {
    final drag = _drag;
    _drag = null;
    if (drag == null) return;
    if (drag.kind == _DragKind.marquee) {
      final box = _marquee.value;
      _marquee.value = null;
      if (box == null) return;
      _deck.select({
        ...drag.kept,
        for (final element in _deck.slide.elements)
          if (!element.locked && boundsOf(element).overlaps(box)) element.id,
      });
      return;
    }
    if (drag.started) {
      if (drag.changesElements) _deck.endGesture();
      return;
    }
    if (!drag.editOnClick || event is! PointerUpEvent) return;
    final shape = _deck.single;
    if (shape is ShapeElement) {
      _deck.startEditing(shape.id, position: textPositionAt(shape, drag.start));
    }
  }

  void _openMenu(Offset global, Offset point) {
    final editing = _deck.editing;
    final inText = editing != null && hits(editing, point, _slop);
    if (!inText) {
      final hit = elementAt(_deck.slide, point, _slop);
      if (hit == null) {
        _deck.clearSelection();
      } else if (!_deck.selection.contains(hit.id)) {
        _deck.select({hit.id});
      } else {
        _deck.stopEditing();
      }
    }
    final l10n = context.l10n;
    final any = _deck.selection.isNotEmpty;
    showContextMenu(context, global, [
      if (any) ...[
        ContextMenuEntry(Icons.content_cut, l10n.cut, widget.onCut),
        ContextMenuEntry(Icons.content_copy, l10n.copy, widget.onCopy),
      ],
      ContextMenuEntry(Icons.content_paste, l10n.paste, widget.onPaste),
      if (any && !inText) ...[
        ContextMenuEntry(
          Icons.control_point_duplicate,
          l10n.duplicate,
          _deck.duplicateSelection,
        ),
        ContextMenuEntry(
          Icons.delete_outline,
          l10n.delete,
          _deck.deleteSelection,
        ),
        ContextMenuEntry(
          Icons.flip_to_front,
          l10n.bringToFront,
          () => _deck.arrange(Arrange.front),
        ),
        ContextMenuEntry(
          Icons.flip_to_back,
          l10n.sendToBack,
          () => _deck.arrange(Arrange.back),
        ),
      ],
      if (!any && _deck.hasLocked)
        ContextMenuEntry(
          Icons.lock_open,
          l10n.unlockBackground,
          _deck.unlockBackground,
        ),
    ]);
  }

  void _onHover(PointerHoverEvent event) =>
      _cursor.value = _cursorAt(_toSlide(event.localPosition));

  MouseCursor _cursorAt(Offset point) {
    final single = _deck.single;
    final handle = single == null
        ? null
        : handleAt(single, point, _slop, _rotateGap);
    if (single != null && handle != null) return _handleCursor(single, handle);
    final editing = _deck.editing;
    if (editing != null && hits(editing, point, _slop)) {
      return SystemMouseCursors.text;
    }
    return elementAt(_deck.slide, point, _slop) == null
        ? SystemMouseCursors.basic
        : SystemMouseCursors.move;
  }

  MouseCursor _handleCursor(SlideElement element, Handle handle) {
    switch (handle.kind) {
      case HandleKind.rotate:
        return SystemMouseCursors.grab;
      case HandleKind.lineStart || HandleKind.lineEnd:
        return SystemMouseCursors.precise;
      case HandleKind.resize:
        final pull = rotated(
          Offset(handle.hx.toDouble(), handle.hy.toDouble()),
          element.rotation,
        );
        final angle = (pull.direction * 180 / math.pi) % 180;
        if (angle < 22.5 || angle >= 157.5) {
          return SystemMouseCursors.resizeLeftRight;
        }
        if (angle < 67.5) return SystemMouseCursors.resizeUpLeftDownRight;
        if (angle < 112.5) return SystemMouseCursors.resizeUpDown;
        return SystemMouseCursors.resizeUpRightDownLeft;
    }
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_command) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final delta = (event as PointerScrollEvent).scrollDelta.dy;
      if (delta == 0) return;
      widget.onZoom(clampZoom(_scale * (delta < 0 ? 1.1 : 1 / 1.1)));
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_command || HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    return _deck.editing != null
        ? _onTextKey(key)
        : _onElementKey(key, event.character);
  }

  /// Keys the system keyboard would not give the text the way slides want.
  KeyEventResult _onTextKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.escape) {
      _deck.stopEditing();
    } else if (key == LogicalKeyboardKey.tab) {
      if (_deck.currentParagraph?.bullet != BulletKind.none) {
        _deck.changeLevel(_shift ? -1 : 1);
      } else if (!_shift) {
        _deck.insertText('\t');
      }
    } else if (_shift &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      _deck.insertText(softBreak);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _onElementKey(LogicalKeyboardKey key, String? character) {
    final step = _shift ? 10.0 : 1.0;
    final single = _deck.single;
    final shape = single is ShapeElement && !single.isLine ? single : null;
    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        _deck.nudge(Offset(-step, 0));
      case LogicalKeyboardKey.arrowRight:
        _deck.nudge(Offset(step, 0));
      case LogicalKeyboardKey.arrowUp:
        _deck.nudge(Offset(0, -step));
      case LogicalKeyboardKey.arrowDown:
        _deck.nudge(Offset(0, step));
      case LogicalKeyboardKey.delete || LogicalKeyboardKey.backspace:
        _deck.deleteSelection();
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (shape != null) _deck.startEditing(shape.id, selectAll: true);
      case LogicalKeyboardKey.f2:
        if (shape != null) _deck.startEditing(shape.id);
      case LogicalKeyboardKey.escape:
        _deck.clearSelection();
      case LogicalKeyboardKey.tab:
        _deck.selectNext(backwards: _shift);
      case LogicalKeyboardKey.pageUp:
        _deck.selectSlide(_deck.slideIndex - 1);
      case LogicalKeyboardKey.pageDown:
        _deck.selectSlide(_deck.slideIndex + 1);
      case LogicalKeyboardKey.home:
        _deck.selectSlide(0);
      case LogicalKeyboardKey.end:
        _deck.selectSlide(_deck.slides.length - 1);
      default:
        if (shape == null || !_isPrintable(character)) {
          return KeyEventResult.ignored;
        }
        // typing over a selected shape goes on from the end of its text
        _deck.startEditing(shape.id);
        _deck.insertText(character!);
    }
    return KeyEventResult.handled;
  }

  bool _isPrintable(String? character) {
    if (character == null || character.isEmpty) return false;
    final code = character.codeUnitAt(0);
    // the upper range is what macOS reports for function keys
    return code >= 0x20 && code != 0x7F && (code < 0xF700 || code > 0xF8FF);
  }

  void _report(double scale) {
    if (widget.scale.value == scale) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.scale.value = scale;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final prompts = SlidePrompts(
      title: l10n.promptTitle,
      subtitle: l10n.promptSubtitle,
      body: l10n.promptText,
    );
    return Actions(
      actions: _textActions.actions,
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: _onKey,
        child: ColoredBox(
          color: scheme.surfaceContainer,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final view = constraints.biggest, slide = _slideSize;
              final fit = math.min(
                (view.width - 2 * _padding) / slide.width,
                (view.height - 2 * _padding) / slide.height,
              );
              final zoom = widget.zoom;
              final scale = zoom == null
                  ? math.max(0.05, fit)
                  : clampZoom(zoom);
              final drawn = slide * scale;
              final content = Size(
                math.max(view.width, drawn.width + 2 * _padding),
                math.max(view.height, drawn.height + 2 * _padding),
              );
              final origin = Offset(
                (content.width - drawn.width) / 2,
                (content.height - drawn.height) / 2,
              );
              _scale = scale;
              _origin = origin;
              _report(scale);
              return Scrollbar(
                controller: _vertical,
                child: Scrollbar(
                  controller: _horizontal,
                  notificationPredicate: (notification) =>
                      notification.depth == 1,
                  child: SingleChildScrollView(
                    controller: _vertical,
                    child: SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox.fromSize(
                        size: content,
                        child: _surface(prompts, origin, scale, scheme.primary),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _surface(
    SlidePrompts prompts,
    Offset origin,
    double scale,
    Color accent,
  ) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _onDown,
    onPointerMove: _onMove,
    onPointerUp: _onUp,
    onPointerCancel: _onUp,
    onPointerSignal: _onSignal,
    child: ValueListenableBuilder(
      valueListenable: _cursor,
      builder: (context, cursor, child) =>
          MouseRegion(cursor: cursor, onHover: _onHover, child: child),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _SlidePainter(
                controller: _deck,
                images: widget.images,
                changes: _slideChanges,
                prompts: prompts,
                origin: origin,
                scale: scale,
              ),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              painter: CanvasOverlay(
                controller: _deck,
                focusNode: widget.focusNode,
                marquee: _marquee,
                caretOn: _caretOn,
                origin: origin,
                scale: scale,
                accent: accent,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SlidePainter extends CustomPainter {
  _SlidePainter({
    required this.controller,
    required this.images,
    required Listenable changes,
    required this.prompts,
    required this.origin,
    required this.scale,
  }) : super(repaint: Listenable.merge([changes, images]));

  final DeckController controller;
  final SlideImages images;
  final SlidePrompts prompts;
  final Offset origin;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final slideSize = controller.presentation.size;
    canvas.drawRect(
      (origin & (slideSize * scale)).inflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x33000000),
    );
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    paintSlide(
      canvas,
      controller.slide,
      slideSize,
      images,
      editingId: controller.editingId,
      prompts: prompts,
      clip: false,
    );
  }

  @override
  bool shouldRepaint(_SlidePainter old) =>
      old.origin != origin ||
      old.scale != scale ||
      old.prompts.title != prompts.title;
}
