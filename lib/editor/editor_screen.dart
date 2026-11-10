// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:voges_updater/voges_updater.dart'
    show LaunchResult, UpdateCheck, UpdateStatusChip, UpdaterLocalizations;
import 'package:window_manager/window_manager.dart';

import '../deck/deck_controller.dart';
import '../deck/element.dart';
import '../deck/text_body.dart';
import '../files/presentation_codec.dart';
import '../files/presentation_files.dart';
import '../files/system_open.dart';
import '../fonts/system_fonts.dart';
import '../l10n/app_language.dart';
import '../l10n/l10n.dart';
import '../render/slide_images.dart';
import '../shell/platform.dart';
import '../shell/ribbon_style.dart';
import '../shell/title_bar.dart';
import '../shell/window_buttons.dart';
import 'dialogs.dart';
import 'file_panel.dart';
import 'ribbon.dart';
import 'slide_canvas.dart';
import 'slideshow.dart';
import 'status_bar.dart';
import 'thumbnails_panel.dart';

const _saveExtension = 'pptx';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    required this.controller,
    required this.files,
    required this.systemOpen,
    required this.language,
    required this.launchArguments,
    this.windowButtons = WindowButtonsLayout.right,
    this.updates,
    super.key,
  });

  final DeckController controller;
  final PresentationFiles files;
  final SystemOpen systemOpen;
  final AppLanguage language;
  final List<String> launchArguments;
  final WindowButtonsLayout windowButtons;

  /// Null off the desktop.
  final UpdateCheck? updates;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WindowListener {
  final _canvasFocus = FocusNode(debugLabel: 'canvas');
  final _thumbnailsFocus = FocusNode(debugLabel: 'thumbnails');
  final _images = SlideImages();
  final _scale = ValueNotifier<double>(1);
  late final AppLifecycleListener _lifecycle;

  /// Null fits the slide to the window.
  double? _zoom;
  var _fonts = const <String>[];
  var _closing = false;
  var _maximized = false;
  var _fullScreen = false;
  String? _title;

  /// The text this app put on the clipboard: pasting it back pastes the
  /// elements themselves, not just their text.
  String? _copiedText;

  DeckController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_updateTitle);
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    if (isDesktopPlatform) windowManager.addListener(this);
    widget.systemOpen.listen(_openFromSystem);
    _loadFonts();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _canvasFocus.requestFocus();
      _updateTitle();
      if (widget.updates case final updates?) {
        updates.check().ignore();
        updates.cleanUp().ignore();
      }
      final pending = await widget.systemOpen.pending(widget.launchArguments);
      if (pending.isNotEmpty) _load(pending.first);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    widget.files.titles = FileDialogTitles(
      open: l10n.openFileTitle,
      save: l10n.saveFileTitle,
      image: l10n.insertImageTitle,
    );
    _updateTitle();
  }

  @override
  void dispose() {
    controller.removeListener(_updateTitle);
    _lifecycle.dispose();
    if (isDesktopPlatform) windowManager.removeListener(this);
    _canvasFocus.dispose();
    _thumbnailsFocus.dispose();
    _images.dispose();
    _scale.dispose();
    super.dispose();
  }

  Future<void> _loadFonts() async {
    final List<String> fonts;
    try {
      fonts = [...await systemFontFamilies()]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } catch (_) {
      return;
    }
    if (mounted) setState(() => _fonts = fonts);
  }

  String get _name => controller.name ?? context.l10n.untitled;

  void _updateTitle() {
    if (!mounted) return;
    final title = '${controller.dirty ? '• ' : ''}$_name — Voges Slides';
    if (title == _title) return;
    _title = title;
    if (isDesktopPlatform) windowManager.setTitle(title).ignore();
  }

  Future<ui.AppExitResponse> _onExitRequested() async {
    if (_closing || await _confirmDiscard()) return ui.AppExitResponse.exit;
    return ui.AppExitResponse.cancel;
  }

  @override
  Future<void> onWindowClose() async {
    if (_closing || await _confirmDiscard()) {
      _closing = true;
      await windowManager.destroy();
    }
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  void onWindowEnterFullScreen() => setState(() => _fullScreen = true);

  @override
  void onWindowLeaveFullScreen() => setState(() => _fullScreen = false);

  /// The app closes for the updater to replace it, so unsaved work is
  /// handled first, exactly as when closing the window.
  Future<void> _startUpdate() async {
    final updates = widget.updates;
    if (updates == null || !await _confirmDiscard()) return;
    final presentation = controller.presentation;
    if (await updates.startUpdater() == LaunchResult.started) {
      // Windows copies the app for the updater first, and the presentation
      // may change meanwhile; if the user keeps it open, the updater waits
      if (!mounted) return;
      if (!identical(controller.presentation, presentation) &&
          !await _confirmDiscard()) {
        return;
      }
      _closing = true;
      await windowManager.destroy();
      return;
    }
    if (!mounted) return;
    final l10n = UpdaterLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.updateLaunchFailed),
        action: SnackBarAction(
          label: l10n.updateDownloadPage,
          onPressed: () => updates.openDownloadPage().ignore(),
        ),
      ),
    );
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // Files.

  Future<bool> _confirmDiscard() async {
    if (!controller.dirty) return true;
    switch (await askToSave(context, _name)) {
      case UnsavedChoice.save:
        return _save();
      case UnsavedChoice.discard:
        return true;
      case UnsavedChoice.cancel:
        return false;
    }
  }

  Future<void> _new() async {
    if (await _confirmDiscard()) controller.newPresentation();
  }

  Future<void> _open() async {
    if (!await _confirmDiscard()) return;
    final OpenedFile? file;
    try {
      file = await widget.files.pick();
    } catch (_) {
      if (mounted) _tell(context.l10n.openFailed);
      return;
    }
    if (file != null) await _load(file);
  }

  Future<void> _openFromSystem(OpenedFile file) async {
    if (await _confirmDiscard()) await _load(file);
  }

  Future<void> _load(OpenedFile file) async {
    final l10n = context.l10n;
    final PptxImport opened;
    try {
      opened = await decodePresentation(file);
    } on PresentationFileException catch (error) {
      _tell(isUnsupported(error) ? l10n.unsupportedFormat : l10n.openFailed);
      return;
    } catch (_) {
      _tell(l10n.openFailed);
      return;
    }
    if (!mounted) return;
    final complete = opened.losses.isEmpty;
    // a file that lost content on the way in, or of a kind the app does not
    // write, is never saved over: Save asks for a new file instead
    final keepPath = complete && file.extension == _saveExtension;
    controller.load(
      opened.presentation,
      name: file.name,
      path: keepPath ? file.path : null,
    );
    if (!complete) _tell(l10n.openedWithLosses);
  }

  Future<bool> _save() {
    final path = controller.path;
    return path == null ? _saveAs() : _write(path);
  }

  Future<bool> _saveAs() async {
    final name = _name;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final String? path;
    try {
      path = await widget.files.chooseSaveLocation('$base.$_saveExtension');
    } catch (_) {
      if (mounted) _tell(context.l10n.saveFailed);
      return false;
    }
    if (path == null) return false;
    return _write(path);
  }

  Future<bool> _write(String path) async {
    final l10n = context.l10n;
    final written = controller.presentation;
    try {
      await widget.files.write(path, await encodePresentation(written));
    } catch (_) {
      _tell(l10n.saveFailed);
      return false;
    }
    controller.markSaved(
      written,
      name: path.split(RegExp(r'[/\\]')).last,
      path: path,
    );
    return true;
  }

  Future<void> _insertImage() async {
    final l10n = context.l10n;
    try {
      final file = await widget.files.pickImage();
      if (file == null) return;
      final size = await imageSizeOf(file.bytes);
      controller.addImage(ImageData(file.bytes, file.extension), size);
    } catch (_) {
      _tell(l10n.imageFailed);
    }
  }

  // Clipboard: text while typing, slides from the thumbnails, elements
  // otherwise.

  bool get _onSlides => _thumbnailsFocus.hasFocus;

  Future<void> _copy({bool cut = false}) async {
    if (_onSlides) {
      controller.copySlide();
      if (cut) controller.deleteSlide();
      return;
    }
    if (controller.editing != null) {
      final text = controller.selectedText;
      if (text.isEmpty) return;
      if (cut) controller.insertText('', typing: false);
      await Clipboard.setData(ClipboardData(text: text));
      return;
    }
    if (controller.selection.isEmpty) return;
    final text = controller.copyElements();
    if (cut) controller.deleteSelection();
    _copiedText = text;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _paste() async {
    if (_onSlides && controller.canPasteSlide) {
      controller.pasteSlide();
      return;
    }
    final nothing = context.l10n.nothingToPaste;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (controller.editing != null) {
      if (text != null && text.isNotEmpty) {
        controller.insertText(text, typing: false);
      }
      return;
    }
    if (controller.canPasteElements && (text == null || text == _copiedText)) {
      controller.pasteElements();
    } else if (text == null || text.isEmpty) {
      _tell(nothing);
    } else {
      controller
        ..addTextBox()
        ..insertText(text, typing: false);
    }
  }

  void _selectAll() {
    final shape = controller.editing;
    if (shape == null) {
      controller.selectAll();
    } else {
      controller.setTextSelection(
        TextSelection(baseOffset: 0, extentOffset: shape.text.length),
      );
    }
  }

  void _duplicate() =>
      _onSlides ? controller.duplicateSlide() : controller.duplicateSelection();

  void _toggle(
    bool Function(RunStyle style) isOn,
    RunStyle Function(RunStyle style, bool on) set,
  ) {
    final on = !controller.everyStyle(isOn);
    controller.formatText((style) => set(style, on));
  }

  // View.

  void _setZoom(double? zoom) =>
      setState(() => _zoom = zoom == null ? null : clampZoom(zoom));

  Future<void> _present(int start) async {
    controller.stopEditing();
    final left = await showSlideshow(
      context,
      presentation: controller.presentation,
      images: _images,
      start: start,
    );
    if (!mounted) return;
    controller.selectSlide(left);
    _canvasFocus.requestFocus();
  }

  void _showFilePanel() => showFilePanel(
    context,
    name: _name,
    language: widget.language,
    actions: FilePanelActions(
      newFile: _new,
      open: _open,
      save: _save,
      saveAs: _saveAs,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        shortcut(LogicalKeyboardKey.keyN): _new,
        shortcut(LogicalKeyboardKey.keyO): _open,
        shortcut(LogicalKeyboardKey.keyS): _save,
        shortcut(LogicalKeyboardKey.keyS, shift: true): _saveAs,
        // ⌘M minimizes the window on macOS, so a new slide takes Shift+N
        shortcut(LogicalKeyboardKey.keyN, shift: true): controller.addSlide,
        shortcut(LogicalKeyboardKey.keyZ): controller.undo,
        shortcut(LogicalKeyboardKey.keyZ, shift: true): controller.redo,
        shortcut(LogicalKeyboardKey.keyY): controller.redo,
        shortcut(LogicalKeyboardKey.keyC): _copy,
        shortcut(LogicalKeyboardKey.keyX): () => _copy(cut: true),
        shortcut(LogicalKeyboardKey.keyV): _paste,
        shortcut(LogicalKeyboardKey.keyA): _selectAll,
        shortcut(LogicalKeyboardKey.keyD): _duplicate,
        shortcut(LogicalKeyboardKey.keyB): () => _toggle(
          (style) => style.bold,
          (style, on) => style.copyWith(bold: on),
        ),
        shortcut(LogicalKeyboardKey.keyI): () => _toggle(
          (style) => style.italic,
          (style, on) => style.copyWith(italic: on),
        ),
        shortcut(LogicalKeyboardKey.keyU): () => _toggle(
          (style) => style.underline,
          (style, on) => style.copyWith(underline: on),
        ),
        shortcut(LogicalKeyboardKey.equal): () => _setZoom(_scale.value * 1.1),
        shortcut(LogicalKeyboardKey.minus): () => _setZoom(_scale.value / 1.1),
        shortcut(LogicalKeyboardKey.digit0): () => _setZoom(null),
        const SingleActivator(LogicalKeyboardKey.f5): () => _present(0),
        const SingleActivator(LogicalKeyboardKey.f5, shift: true): () =>
            _present(controller.slideIndex),
      },
      child: _resizable(
        Scaffold(
          body: Column(
            children: [
              ColoredBox(
                color: RibbonColors.background,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      ListenableBuilder(
                        listenable: controller,
                        builder: (context, _) => AppTitleBar(
                          name: _name,
                          dirty: controller.dirty,
                          onFile: _showFilePanel,
                          isMaximized: _maximized,
                          isFullScreen: _fullScreen,
                          windowButtons: widget.windowButtons,
                          actions: QuickActions(
                            undo: controller.canUndo ? controller.undo : null,
                            redo: controller.canRedo ? controller.redo : null,
                            copy: _copy,
                            cut: () => _copy(cut: true),
                            paste: _paste,
                          ),
                        ),
                      ),
                      Ribbon(
                        controller: controller,
                        fonts: _fonts,
                        actions: RibbonActions(
                          cut: () => _copy(cut: true),
                          copy: _copy,
                          paste: _paste,
                          insertImage: _insertImage,
                          slideshowFromStart: () => _present(0),
                          slideshowFromCurrent: () =>
                              _present(controller.slideIndex),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    ThumbnailsPanel(
                      controller: controller,
                      images: _images,
                      focusNode: _thumbnailsFocus,
                    ),
                    Expanded(
                      child: SlideCanvas(
                        controller: controller,
                        images: _images,
                        focusNode: _canvasFocus,
                        zoom: _zoom,
                        scale: _scale,
                        onZoom: _setZoom,
                        onCut: () => _copy(cut: true),
                        onCopy: _copy,
                        onPaste: _paste,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBar(
                controller: controller,
                scale: _scale,
                onZoom: _setZoom,
                trailing: switch (widget.updates) {
                  final updates? => UpdateStatusChip(
                    check: updates,
                    onUpdate: _startUpdate,
                  ),
                  null => null,
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Without the system title bar the window needs resize edges: on Windows
  /// only the top one is missing; on Linux, with no frame, all of them are.
  Widget _resizable(Widget child) {
    if (!isDesktopPlatform || defaultTargetPlatform == TargetPlatform.macOS) {
      return child;
    }
    return DragToResizeArea(
      enableResizeEdges: _maximized || _fullScreen
          ? const []
          : defaultTargetPlatform == TargetPlatform.windows
          ? const [ResizeEdge.topLeft, ResizeEdge.top, ResizeEdge.topRight]
          : null,
      child: child,
    );
  }
}
