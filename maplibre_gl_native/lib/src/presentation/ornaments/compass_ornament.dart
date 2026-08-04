import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compass ornament: a round dial with a north/south needle that rotates
/// against the map bearing, hides when the map is north-up, and resets the
/// bearing when tapped.
class CompassOrnament extends StatelessWidget {
  const CompassOrnament({
    super.key,
    required this.bearing,
    required this.onTap,
  });

  /// Bearing tolerance, in degrees, within which the map counts as north-up
  /// and the compass hides itself.
  static const _northUpTolerance = 0.5;

  static const _diameter = 44.0;

  final double bearing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final northUp =
        bearing.abs() < _northUpTolerance ||
        (bearing.abs() - 360).abs() < _northUpTolerance;
    return AnimatedOpacity(
      opacity: northUp ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: northUp,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: _diameter,
            height: _diameter,
            decoration: const BoxDecoration(
              color: Color(0xF2FFFFFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            // The needle points to the map's north: rotate opposite to the
            // camera bearing.
            child: Transform.rotate(
              angle: -bearing * math.pi / 180,
              child: const CustomPaint(painter: _CompassDialPainter()),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassDialPainter extends CustomPainter {
  const _CompassDialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // Dial ring with the four cardinal ticks.
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = const Color(0xFFB6BDC6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final tickPaint = Paint()
      ..color = const Color(0xFF9AA3AD)
      ..strokeWidth = 1.6;
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final direction = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawLine(
        center + direction * (radius - 6.5),
        center + direction * (radius - 3.5),
        tickPaint,
      );
    }

    // Needle: red toward north, grey toward south, waist at the center.
    final needleLength = radius - 9;
    const needleHalfWidth = 5.5;
    final north = Path()
      ..moveTo(center.dx - needleHalfWidth, center.dy)
      ..lineTo(center.dx, center.dy - needleLength)
      ..lineTo(center.dx + needleHalfWidth, center.dy)
      ..close();
    final south = Path()
      ..moveTo(center.dx - needleHalfWidth, center.dy)
      ..lineTo(center.dx, center.dy + needleLength)
      ..lineTo(center.dx + needleHalfWidth, center.dy)
      ..close();
    canvas.drawPath(north, Paint()..color = const Color(0xFFE53935));
    canvas.drawPath(south, Paint()..color = const Color(0xFFB0BEC5));

    // Center pivot.
    canvas.drawCircle(center, 2.4, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(
      center,
      2.4,
      Paint()
        ..color = const Color(0xFF78909C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) => false;
}
