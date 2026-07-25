import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Scale bar ornament: a bracket with a rounded metric distance sized to the
/// current meters-per-pixel of the camera. Opt-in (no maplibre_gl option).
class ScaleBarOrnament extends StatelessWidget {
  const ScaleBarOrnament({super.key, required this.metersPerPixel});

  /// Widest the bar may draw, in logical pixels; the rounded distance is the
  /// largest nice value that fits.
  static const _maxWidth = 110.0;

  static const _height = 22.0;

  /// Meters per logical pixel at the camera center latitude.
  final ValueListenable<double> metersPerPixel;

  /// Largest 1/2/5 x 10^n value not exceeding [maxMeters].
  static double niceDistance(double maxMeters) {
    final exponent = (math.log(maxMeters) / math.ln10).floor();
    final magnitude = math.pow(10.0, exponent).toDouble();
    final fraction = maxMeters / magnitude;
    final nice = fraction >= 5
        ? 5.0
        : fraction >= 2
        ? 2.0
        : 1.0;
    return nice * magnitude;
  }

  /// Metric label for a rounded distance: kilometres past 1 km, else metres.
  static String label(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return km == km.roundToDouble()
          ? '${km.round()} km'
          : '${km.toStringAsFixed(1)} km';
    }
    return meters >= 1
        ? '${meters.round()} m'
        : '${meters.toStringAsFixed(2)} m';
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: metersPerPixel,
        builder: (context, mpp, _) {
          if (!mpp.isFinite || mpp <= 0) return const SizedBox.shrink();
          final meters = niceDistance(_maxWidth * mpp);
          return CustomPaint(
            size: Size(meters / mpp, _height),
            painter: _ScaleBarPainter(label: label(meters)),
          );
        },
      ),
    );
  }
}

class _ScaleBarPainter extends CustomPainter {
  const _ScaleBarPainter({required this.label});

  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height - 1.5;
    const tickHeight = 7.0;
    final halo = Paint()
      ..color = const Color(0xB3FFFFFF)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = const Color(0xE6263238)
      ..strokeWidth = 2;

    void bracket(Paint paint) {
      canvas
        ..drawLine(Offset(0, baseline), Offset(size.width, baseline), paint)
        ..drawLine(Offset(1, baseline), Offset(1, baseline - tickHeight), paint)
        ..drawLine(
          Offset(size.width - 1, baseline),
          Offset(size.width - 1, baseline - tickHeight),
          paint,
        );
    }

    bracket(halo);
    bracket(line);

    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xE6263238),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(color: Color(0xCCFFFFFF), blurRadius: 2),
            Shadow(color: Color(0xCCFFFFFF), blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(
        (size.width - text.width) / 2,
        baseline - tickHeight - text.height,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ScaleBarPainter oldDelegate) =>
      label != oldDelegate.label;
}
