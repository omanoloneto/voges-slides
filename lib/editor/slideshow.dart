import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../deck/presentation.dart';
import '../l10n/l10n.dart';
import '../render/slide_images.dart';
import '../render/slide_painter.dart';
import '../shell/platform.dart';

/// Shows the presentation over the whole screen from slide [start]. Answers
/// the slide it was left at.
Future<int> showSlideshow(
  BuildContext context, {
  required Presentation presentation,
  required SlideImages images,
  required int start,
}) async {
  final navigator = Navigator.of(context);
  final restore = await _enterFullScreen();
  final left = await navigator.push<int>(
    PageRouteBuilder(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, _) =>
          _Slideshow(presentation: presentation, images: images, start: start),
    ),
  );
  if (restore) await _setFullScreen(false);
  return left ?? start;
}

/// Whether the window has to be taken out of full screen afterwards.
Future<bool> _enterFullScreen() async {
  if (!isDesktopPlatform) return false;
  try {
    if (await windowManager.isFullScreen()) return false;
  } on Exception {
    return false;
  }
  return _setFullScreen(true);
}

Future<bool> _setFullScreen(bool on) async {
  try {
    await windowManager.setFullScreen(on);
    return true;
  } on Exception {
    return false;
  }
}

class _Slideshow extends StatefulWidget {
  const _Slideshow({
    required this.presentation,
    required this.images,
    required this.start,
  });

  final Presentation presentation;
  final SlideImages images;
  final int start;

  @override
  State<_Slideshow> createState() => _SlideshowState();
}

class _SlideshowState extends State<_Slideshow> {
  late var _index = widget.start;

  List<Slide> get _slides => widget.presentation.slides;

  /// One step past the last slide is the closing screen.
  void _go(int index) {
    if (index > _slides.length) {
      _leave();
    } else if (index >= 0 && index != _index) {
      setState(() => _index = index);
    }
  }

  void _leave() =>
      Navigator.of(context).pop(_index.clamp(0, _slides.length - 1));

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight ||
          LogicalKeyboardKey.arrowDown ||
          LogicalKeyboardKey.space ||
          LogicalKeyboardKey.enter ||
          LogicalKeyboardKey.numpadEnter ||
          LogicalKeyboardKey.pageDown ||
          LogicalKeyboardKey.keyN:
        _go(_index + 1);
      case LogicalKeyboardKey.arrowLeft ||
          LogicalKeyboardKey.arrowUp ||
          LogicalKeyboardKey.backspace ||
          LogicalKeyboardKey.pageUp ||
          LogicalKeyboardKey.keyP:
        _go(_index - 1);
      case LogicalKeyboardKey.home:
        _go(0);
      case LogicalKeyboardKey.end:
        _go(_slides.length - 1);
      case LogicalKeyboardKey.escape:
        _leave();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.presentation.size;
    final ended = _index >= _slides.length;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _go(_index + 1),
        onSecondaryTap: () => _go(_index - 1),
        child: ColoredBox(
          color: const Color(0xFF000000),
          child: Center(
            child: ended
                ? Text(
                    context.l10n.slideshowEnd,
                    style: const TextStyle(
                      color: Color(0xFFBDBDBD),
                      fontSize: 16,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w400,
                    ),
                  )
                : AspectRatio(
                    aspectRatio: size.width / size.height,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _ShowPainter(
                          _slides[_index],
                          size,
                          widget.images,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ShowPainter extends CustomPainter {
  _ShowPainter(this.slide, this.slideSize, this.images)
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
  bool shouldRepaint(_ShowPainter old) =>
      !identical(old.slide, slide) || old.slideSize != slideSize;
}
