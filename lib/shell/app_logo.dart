import 'package:flutter/material.dart';

/// The icon's colors, from light orange to dark.
const logoShades = [
  Color(0xFFFBA77A),
  Color(0xFFF2804F),
  Color(0xFFE5623A),
  Color(0xFFCF4A2B),
  Color(0xFFA9331C),
];

class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 24, this.outlined = false, super.key});

  final double size;

  /// Light outline so the icon does not vanish against the ribbon.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: const _SlicesPainter(),
          child: Center(
            child: Text(
              'S',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.64,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: 'Voges Slides',
      child: outlined
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.24),
                border: Border.all(color: const Color(0xB3FFFFFF)),
              ),
              child: logo,
            )
          : logo,
    );
  }
}

/// The three slices of the icon, as in `assets/icon`.
class _SlicesPainter extends CustomPainter {
  const _SlicesPainter();

  static const _fold = 0.789;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Path slice(List<Offset> points) => Path()
      ..addPolygon([
        for (final point in points) Offset(point.dx * w, point.dy * h),
      ], true);
    canvas
      ..drawPath(
        slice(const [
          Offset(0, 0),
          Offset(0.5, 0),
          Offset(0.5, 0.5),
          Offset(0, _fold),
        ]),
        Paint()..color = logoShades[2],
      )
      ..drawPath(
        slice(const [
          Offset(0.5, 0),
          Offset(1, 0),
          Offset(1, _fold),
          Offset(0.5, 0.5),
        ]),
        Paint()..color = logoShades[0],
      )
      ..drawPath(
        slice(const [
          Offset(0, _fold),
          Offset(0.5, 0.5),
          Offset(1, _fold),
          Offset(1, 1),
          Offset(0, 1),
        ]),
        Paint()..color = Color.lerp(logoShades[3], logoShades[4], 0.5)!,
      );
  }

  @override
  bool shouldRepaint(_SlicesPainter oldDelegate) => false;
}
