import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../deck/deck_controller.dart';
import '../deck/text_body.dart';
import '../deck/text_ops.dart';
import '../text/text_layout.dart';

/// What the keys of a text field do to the text being edited on the slide.
class TextEditingActions {
  TextEditingActions({
    required this.controller,
    required this.cut,
    required this.copy,
    required this.paste,
  });

  final DeckController controller;
  final VoidCallback cut;
  final VoidCallback copy;
  final VoidCallback paste;

  /// The column the caret keeps while it travels up and down.
  ({int position, double x})? _column;

  late final Map<Type, Action<Intent>> actions = {
    // lets the system keyboard have the keys the framework would otherwise
    // spend moving the focus
    DoNothingAndStopPropagationTextIntent: DoNothingAction(consumesKey: false),
    DeleteCharacterIntent: _on<DeleteCharacterIntent>(_deleteCharacter),
    DeleteToNextWordBoundaryIntent: _on<DeleteToNextWordBoundaryIntent>(
      (intent) => _delete((from) => _wordEdge(from, intent.forward)),
    ),
    DeleteToLineBreakIntent: _on<DeleteToLineBreakIntent>(
      (intent) => _delete((from) => _lineEdge(from, intent.forward)),
    ),
    ExtendSelectionByCharacterIntent: _on<ExtendSelectionByCharacterIntent>(
      _byCharacter,
    ),
    ExtendSelectionToNextWordBoundaryIntent:
        _on<ExtendSelectionToNextWordBoundaryIntent>(
          (intent) => _move(
            _wordEdge(_extent, intent.forward),
            intent.collapseSelection,
          ),
        ),
    ExtendSelectionToNextWordBoundaryOrCaretLocationIntent:
        _on<ExtendSelectionToNextWordBoundaryOrCaretLocationIntent>(
          (intent) =>
              _move(_notPastBase(_wordEdge(_extent, intent.forward)), false),
        ),
    ExtendSelectionToLineBreakIntent: _on<ExtendSelectionToLineBreakIntent>((
      intent,
    ) {
      final edge = _lineEdge(_extent, intent.forward);
      _move(
        intent.collapseAtReversal ? _notPastBase(edge) : edge,
        intent.collapseSelection,
      );
    }),
    ExpandSelectionToLineBreakIntent: _on<ExpandSelectionToLineBreakIntent>(
      (intent) => _expand(
        intent.forward,
        _lineEdge(
          intent.forward ? _selection.end : _selection.start,
          intent.forward,
        ),
      ),
    ),
    ExtendSelectionVerticallyToAdjacentLineIntent:
        _on<ExtendSelectionVerticallyToAdjacentLineIntent>(_vertically),
    ExtendSelectionToNextParagraphBoundaryIntent:
        _on<ExtendSelectionToNextParagraphBoundaryIntent>(
          (intent) => _move(
            _paragraphEdge(_extent, intent.forward),
            intent.collapseSelection,
          ),
        ),
    ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent:
        _on<ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent>(
          (intent) => _move(
            _notPastBase(_paragraphEdge(_extent, intent.forward)),
            false,
          ),
        ),
    ExtendSelectionToDocumentBoundaryIntent:
        _on<ExtendSelectionToDocumentBoundaryIntent>(
          (intent) => _move(
            intent.forward ? _text.length : 0,
            intent.collapseSelection,
          ),
        ),
    ExpandSelectionToDocumentBoundaryIntent:
        _on<ExpandSelectionToDocumentBoundaryIntent>(
          (intent) =>
              _expand(intent.forward, intent.forward ? _text.length : 0),
        ),
    SelectAllTextIntent: _on<SelectAllTextIntent>(
      (_) => controller.setTextSelection(
        TextSelection(baseOffset: 0, extentOffset: _text.length),
      ),
    ),
    CopySelectionTextIntent: _on<CopySelectionTextIntent>(
      (intent) => intent.collapseSelection ? cut() : copy(),
    ),
    PasteTextIntent: _on<PasteTextIntent>((_) => paste()),
    UndoTextIntent: _on<UndoTextIntent>((_) => controller.undo()),
    RedoTextIntent: _on<RedoTextIntent>((_) => controller.redo()),
  };

  Action<T> _on<T extends Intent>(void Function(T intent) run) =>
      CallbackAction<T>(
        onInvoke: (intent) {
          if (controller.editing != null) run(intent);
          return null;
        },
      );

  String get _text => controller.editing!.text.text;
  TextSelection get _selection => controller.textSelection;
  int get _extent => _selection.extentOffset;
  BodyLayout get _layout => layoutOf(controller.editing!);

  void _move(int position, bool collapse) => controller.setTextSelection(
    collapse
        ? TextSelection.collapsed(offset: position)
        : TextSelection(
            baseOffset: _selection.baseOffset,
            extentOffset: position,
          ),
  );

  /// Grows the selection to [edge], whichever way it was made.
  void _expand(bool forward, int edge) => controller.setTextSelection(
    TextSelection(
      baseOffset: forward ? _selection.start : _selection.end,
      extentOffset: edge,
    ),
  );

  /// Stops a selection being shrunk at the point where it started.
  int _notPastBase(int position) {
    final base = _selection.baseOffset, extent = _extent;
    final crossed =
        (extent < base && position > base) ||
        (extent > base && position < base);
    return crossed ? base : position;
  }

  int _characterEdge(int from, bool forward) =>
      forward ? nextCharacter(_text, from) : previousCharacter(_text, from);

  int _wordEdge(int from, bool forward) =>
      forward ? nextWord(_text, from) : previousWord(_text, from);

  int _lineEdge(int from, bool forward) =>
      forward ? _layout.lineEnd(from) : _layout.lineStart(from);

  int _paragraphEdge(int from, bool forward) {
    final text = _text;
    if (forward) {
      final skip = from < text.length && text.codeUnitAt(from) == 0x0A ? 1 : 0;
      final end = text.indexOf('\n', from + skip);
      return end < 0 ? text.length : end;
    }
    final start = from > 0 && text.codeUnitAt(from - 1) == 0x0A
        ? from - 1
        : from;
    return start <= 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  }

  void _byCharacter(ExtendSelectionByCharacterIntent intent) {
    final selection = _selection;
    if (intent.collapseSelection && !selection.isCollapsed) {
      _move(intent.forward ? selection.end : selection.start, true);
    } else {
      _move(_characterEdge(_extent, intent.forward), intent.collapseSelection);
    }
  }

  void _vertically(ExtendSelectionVerticallyToAdjacentLineIntent intent) {
    final extent = _extent, layout = _layout, kept = _column;
    final x = kept != null && kept.position == extent
        ? kept.x
        : layout.caretRect(extent).left;
    final position = layout.verticalMove(extent, intent.forward ? 1 : -1, x: x);
    _move(position, intent.collapseSelection);
    _column = (position: position, x: x);
  }

  void _delete(int Function(int from) edge) {
    final selection = _selection;
    if (!selection.isCollapsed) {
      controller.replaceTextRange(selection.start, selection.end, '');
      return;
    }
    final from = selection.extentOffset, to = edge(from);
    controller.replaceTextRange(math.min(from, to), math.max(from, to), '');
  }

  void _deleteCharacter(DeleteCharacterIntent intent) {
    final selection = _selection;
    if (!intent.forward && selection.isCollapsed) {
      final body = controller.editing!.text;
      final at = locate(body, selection.start);
      // backspace at the start of a list item first takes it off the list
      if (at.offset == 0 &&
          body.paragraphs[at.paragraph].bullet != BulletKind.none) {
        controller.formatParagraphs(
          (paragraph) => paragraph.copyWith(bullet: BulletKind.none),
        );
        return;
      }
    }
    _delete((from) => _characterEdge(from, intent.forward));
  }
}
