import 'package:flutter/material.dart';

/// The soft circles drawn across the crimson-to-navy headers.
///
/// Two translucent rings of light, the kind a printed university brochure puts
/// behind a headline: they give the flat gradient a sense of volume without a
/// single extra color. Painted, not built out of widgets, so a header keeps the
/// same widget tree it had — and nothing here can be tapped.
class HeroDecor extends StatelessWidget {
  /// The color of the light; the header's foreground, usually.
  final Color color;

  const HeroDecor({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _HeroDecorPainter(color)),
      ),
    );
  }
}

class _HeroDecorPainter extends CustomPainter {
  final Color color;

  const _HeroDecorPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color.withValues(alpha: 0.07);
    final ring = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final big = size.shortestSide * 0.95;

    canvas.drawCircle(
      Offset(size.width - big * 0.18, -big * 0.12),
      big * 0.62,
      fill,
    );
    canvas.drawCircle(
      Offset(size.width - big * 0.05, size.height + big * 0.05),
      big * 0.42,
      fill,
    );
    canvas.drawCircle(
      Offset(size.width - big * 0.28, size.height * 0.2),
      big * 0.36,
      ring,
    );
  }

  @override
  bool shouldRepaint(_HeroDecorPainter old) => old.color != color;
}

/// The colored glow under a header that sits on the brand gradient, so it
/// lifts off the page instead of being printed on it.
List<BoxShadow> heroShadow(ColorScheme colors) => [
  BoxShadow(
    color: colors.primary.withValues(alpha: 0.28),
    blurRadius: 28,
    offset: const Offset(0, 12),
  ),
  BoxShadow(
    color: colors.secondary.withValues(alpha: 0.12),
    blurRadius: 6,
    offset: const Offset(0, 2),
  ),
];
