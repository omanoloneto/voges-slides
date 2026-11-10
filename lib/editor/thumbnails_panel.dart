import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../deck/deck_controller.dart';
import '../deck/presentation.dart';
import '../l10n/l10n.dart';
import '../render/slide_images.dart';
import '../render/slide_painter.dart';
import '../shell/platform.dart';
import 'context_menu.dart';

const thumbnailsWidth = 196.0;

const _numberWidth = 30.0;
const _trailing = 14.0;
const _gap = 6.0;
const _listPadding = 6.0;

/// The slides of the presentation in a column: click to open one, drag to
/// reorder.
class ThumbnailsPanel extends StatefulWidget {
  const ThumbnailsPanel({
    required this.controller,
    required this.images,
    required this.focusNode,
    super.key,
  });

  final DeckController controller;
  final SlideImages images;
  final FocusNode focusNode;

  @override
  State<ThumbnailsPanel> createState() => _ThumbnailsPanelState();
}

class _ThumbnailsPanelState extends State<ThumbnailsPanel> {
  final _scroll = ScrollController();
  var _followed = (-1, 0);

  DeckController get _deck => widget.controller;

  double get _extent {
    final size = _deck.presentation.size;
    final width = thumbnailsWidth - _numberWidth - _trailing;
    return width * size.height / size.width + 2 * _gap;
  }

  @override
  void initState() {
    super.initState();
    _deck.addListener(_follow);
  }

  @override
  void dispose() {
    _deck.removeListener(_follow);
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the open slide in sight when it changes.
  void _follow() {
    final now = (_deck.slideIndex, _deck.slides.length);
    if (now == _followed) return;
    _followed = now;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      final top = _listPadding + _deck.slideIndex * _extent;
      final bottom = top + _extent;
      if (top < position.pixels) {
        position.jumpTo(math.max(0, top - _listPadding));
      } else if (bottom > position.pixels + position.viewportDimension) {
        position.jumpTo(
          math.min(
            position.maxScrollExtent,
            bottom + _listPadding - position.viewportDimension,
          ),
        );
      }
    });
  }

  void _open(int index) {
    widget.focusNode.requestFocus();
    _deck.selectSlide(index);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final index = _deck.slideIndex, last = _deck.slides.length - 1;
    final keyboard = HardwareKeyboard.instance;
    final command = isApplePlatform
        ? keyboard.isMetaPressed
        : keyboard.isControlPressed;
    final step = switch (key) {
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.pageUp => -1,
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.pageDown => 1,
      _ => 0,
    };
    if (step != 0) {
      final target = (index + step).clamp(0, last);
      command ? _deck.moveSlide(index, target) : _deck.selectSlide(target);
    } else if (key == LogicalKeyboardKey.home) {
      _deck.selectSlide(0);
    } else if (key == LogicalKeyboardKey.end) {
      _deck.selectSlide(last);
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _deck.deleteSlide();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _deck.addSlide();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _menu(int index, Offset position) {
    _open(index);
    final l10n = context.l10n;
    final last = _deck.slides.length - 1;
    showContextMenu(context, position, [
      ContextMenuEntry(Icons.add, l10n.newSlide, _deck.addSlide),
      ContextMenuEntry(
        Icons.control_point_duplicate,
        l10n.duplicateSlide,
        _deck.duplicateSlide,
      ),
      ContextMenuEntry(
        Icons.delete_outline,
        l10n.deleteSlide,
        _deck.canDeleteSlide ? _deck.deleteSlide : null,
      ),
      ContextMenuEntry(
        Icons.arrow_upward,
        l10n.moveSlideUp,
        index > 0 ? () => _deck.moveSlide(index, index - 1) : null,
      ),
      ContextMenuEntry(
        Icons.arrow_downward,
        l10n.moveSlideDown,
        index < last ? () => _deck.moveSlide(index, index + 1) : null,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _onKey,
      child: Container(
        width: thumbnailsWidth,
        color: scheme.surfaceContainerLow,
        child: ListenableBuilder(
          listenable: _deck,
          builder: (context, _) {
            final slides = _deck.slides;
            return ReorderableListView.builder(
              scrollController: _scroll,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(vertical: _listPadding),
              itemExtent: _extent,
              itemCount: slides.length,
              onReorder: (from, to) =>
                  _deck.moveSlide(from, to > from ? to - 1 : to),
              itemBuilder: (context, index) {
                final slide = slides[index];
                return ReorderableDragStartListener(
                  key: ValueKey(slide.id),
                  index: index,
                  child: _Thumbnail(
                    slide: slide,
                    number: index + 1,
                    slideSize: _deck.presentation.size,
                    images: widget.images,
                    selected: index == _deck.slideIndex,
                    onOpen: () => _open(index),
                    onMenu: (position) => _menu(index, position),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.slide,
    required this.number,
    required this.slideSize,
    required this.images,
    required this.selected,
    required this.onOpen,
    required this.onMenu,
  });

  final Slide slide;
  final int number;
  final Size slideSize;
  final SlideImages images;
  final bool selected;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(4);
    return Listener(
      onPointerDown: (event) {
        if (event.buttons & kPrimaryButton != 0) onOpen();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (details) => onMenu(details.globalPosition),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, _gap, _trailing, _gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _numberWidth,
                child: Text(
                  '$number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _ThumbnailPainter(slide, slideSize, images),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  _ThumbnailPainter(this.slide, this.slideSize, this.images)
    : super(repaint: images);

  final Slide slide;
  final Size slideSize;
  final SlideImages images;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / slideSize.width);
    paintSlide(canvas, slide, slideSize, images);
  }

  @override
  bool shouldRepaint(_ThumbnailPainter old) =>
      !identical(old.slide, slide) || old.slideSize != slideSize;
}
