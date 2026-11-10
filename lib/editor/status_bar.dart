import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../deck/deck_controller.dart';
import '../l10n/l10n.dart';

const minZoom = 0.25, maxZoom = 4.0;

double clampZoom(double zoom) => zoom.clamp(minZoom, maxZoom);

/// Which slide is open and the zoom of the canvas.
class StatusBar extends StatelessWidget {
  const StatusBar({
    required this.controller,
    required this.scale,
    required this.onZoom,
    this.trailing,
    super.key,
  });

  final DeckController controller;

  /// The scale the slide is drawn at, whether chosen or fitted.
  final ValueListenable<double> scale;

  /// Null asks for the slide to fit the window again.
  final ValueChanged<double?> onZoom;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final style = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: scheme.surfaceContainer,
      child: Row(
        children: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Text(
              l10n.slideOf(controller.slideIndex + 1, controller.slides.length),
              style: style,
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: trailing,
            ),
          ),
          ValueListenableBuilder(
            valueListenable: scale,
            builder: (context, scale, _) {
              final zoom = clampZoom(scale);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.zoomOut,
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onZoom(clampZoom(zoom - 0.1)),
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 120,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                      ),
                      child: Slider(
                        value: zoom,
                        min: minZoom,
                        max: maxZoom,
                        onChanged: onZoom,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.zoomIn,
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onZoom(clampZoom(zoom + 0.1)),
                    icon: const Icon(Icons.add),
                  ),
                  Tooltip(
                    message: l10n.fitZoom,
                    child: TextButton(
                      onPressed: () => onZoom(null),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(56, 28),
                      ),
                      child: Text('${(scale * 100).round()}%', style: style),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
