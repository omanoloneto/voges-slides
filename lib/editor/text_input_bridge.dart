import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../deck/deck_controller.dart';
import '../deck/text_body.dart';

/// Connects the keyboard of the system to the text being edited on the
/// slide, so typing, dead keys and input methods work as in a text field.
class TextInputBridge with TextInputClient {
  TextInputBridge({required this.controller, required this.focusNode});

  final DeckController controller;

  /// The focus of the canvas, where the commands of the keyboard are sent.
  final FocusNode focusNode;

  TextInputConnection? _connection;
  var _remote = TextEditingValue.empty;

  /// Opens, updates or closes the connection so the system sees the text
  /// being edited while the canvas has the focus.
  void sync(int viewId) {
    final shape = focusNode.hasFocus ? controller.editing : null;
    if (shape == null) {
      close();
      return;
    }
    final text = shape.text.text.replaceAll(softBreak, '\n');
    final selection = controller.textSelection;
    var connection = _connection;
    if (connection == null || !connection.attached) {
      connection = _connection = TextInput.attach(
        this,
        TextInputConfiguration(
          viewId: viewId,
          inputType: TextInputType.multiline,
          inputAction: TextInputAction.newline,
          autocorrect: false,
          enableSuggestions: false,
        ),
      )..show();
    } else if (text == _remote.text && selection == _remote.selection) {
      return;
    }
    _remote = TextEditingValue(text: text, selection: selection);
    connection.setEditingState(_remote);
  }

  void close() {
    _connection?.close();
    _connection = null;
    _remote = TextEditingValue.empty;
  }

  @override
  TextEditingValue? get currentTextEditingValue => _remote;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    if (controller.editing == null) return;
    final before = _remote.text, after = value.text;
    final caret = _remote.selection.isValid ? _remote.selection.start : 0;
    _remote = value;
    final selection = value.selection.isValid ? value.selection : null;
    if (before == after) {
      if (selection != null) controller.setTextSelection(selection);
      return;
    }
    // the change starts no later than the caret, so what is typed takes the
    // style of where it was typed even among repeated letters
    final shortest = math.min(before.length, after.length);
    final limit = math.min(shortest, caret);
    var prefix = 0;
    while (prefix < limit &&
        before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < shortest - prefix &&
        before.codeUnitAt(before.length - 1 - suffix) ==
            after.codeUnitAt(after.length - 1 - suffix)) {
      suffix++;
    }
    controller.replaceTextRange(
      prefix,
      before.length - suffix,
      after.substring(prefix, after.length - suffix),
      selection: selection,
    );
  }

  @override
  void performSelector(String selectorName) {
    final intent = intentForMacOSSelector(selectorName);
    final context = focusNode.context;
    if (intent != null && context != null) Actions.maybeInvoke(context, intent);
  }

  @override
  void connectionClosed() {
    _connection = null;
    _remote = TextEditingValue.empty;
  }

  @override
  void performAction(TextInputAction action) {}

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}
}
