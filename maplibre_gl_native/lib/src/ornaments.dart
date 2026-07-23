import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Ornament (compass, attribution, logo, scale bar) configuration shared
/// between the platform and the map widget; notifies the widget on change.
///
/// Positions are the maplibre_gl enum indexes: 0 topLeft, 1 topRight,
/// 2 bottomLeft, 3 bottomRight. Margins are [x, y] logical pixels.
class FfiOrnamentConfig extends ChangeNotifier {
  bool compassEnabled = true;
  int compassPosition = 1;
  List<int> compassMargins = const [8, 8];

  bool attributionEnabled = true;
  int attributionPosition = 3;
  List<int> attributionMargins = const [8, 8];

  bool logoEnabled = true;
  int logoPosition = 2;
  List<int> logoMargins = const [8, 8];

  /// The scale bar has no maplibre_gl option key (the Android SDK has no
  /// scale bar ornament), so it is opt-in and off by default.
  bool scaleBarEnabled = false;
  int scaleBarPosition = 0;
  List<int> scaleBarMargins = const [8, 8];

  /// Applies the ornament keys of a maplibre_gl options map.
  void applyOptions(Map<String, dynamic> options) {
    var changed = false;
    bool boolOf(String key, bool current) {
      final value = options[key];
      if (value is bool && value != current) changed = true;
      return value is bool ? value : current;
    }

    int positionOf(String key, int current) {
      final value = options[key];
      if (value is int && value != current) changed = true;
      return value is int ? value : current;
    }

    List<int> marginsOf(String key, List<int> current) {
      final value = options[key];
      if (value is List && value.length >= 2) {
        final margins = [(value[0] as num).toInt(), (value[1] as num).toInt()];
        if (margins[0] != current[0] || margins[1] != current[1]) {
          changed = true;
        }
        return margins;
      }
      return current;
    }

    compassEnabled = boolOf('compassEnabled', compassEnabled);
    compassPosition = positionOf('compassViewPosition', compassPosition);
    compassMargins = marginsOf('compassViewMargins', compassMargins);
    attributionEnabled = boolOf('attributionButtonEnabled', attributionEnabled);
    attributionPosition = positionOf(
      'attributionButtonPosition',
      attributionPosition,
    );
    attributionMargins = marginsOf(
      'attributionButtonMargins',
      attributionMargins,
    );
    logoEnabled = boolOf('logoEnabled', logoEnabled);
    logoPosition = positionOf('logoViewPosition', logoPosition);
    logoMargins = marginsOf('logoViewMargins', logoMargins);
    if (changed) notifyListeners();
  }
}

/// Positions [child] in one of the four map corners.
class MapOrnament extends StatelessWidget {
  const MapOrnament({
    super.key,
    required this.position,
    required this.margins,
    required this.child,
  });

  /// Corner index: 0 topLeft, 1 topRight, 2 bottomLeft, 3 bottomRight.
  final int position;
  final List<int> margins;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final x = margins[0].toDouble();
    final y = margins[1].toDouble();
    return Positioned(
      left: position == 0 || position == 2 ? x : null,
      right: position == 1 || position == 3 ? x : null,
      top: position == 0 || position == 1 ? y : null,
      bottom: position == 2 || position == 3 ? y : null,
      child: child,
    );
  }
}

/// Compass ornament: a round dial with a north/south needle that rotates
/// against the map bearing, hides when the map is north-up, and resets the
/// bearing when tapped.
class CompassOrnament extends StatelessWidget {
  const CompassOrnament({
    super.key,
    required this.bearing,
    required this.onTap,
  });

  final double bearing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final northUp = bearing.abs() < 0.5 || (bearing.abs() - 360).abs() < 0.5;
    return AnimatedOpacity(
      opacity: northUp ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: northUp,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
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

/// Attribution ornament: a pill that expands into the per-source attribution
/// strings of the current style, with tappable links. Starts expanded and
/// collapses to an info button on the first camera movement.
class AttributionOrnament extends StatefulWidget {
  const AttributionOrnament({
    super.key,
    required this.loadAttributions,
    required this.openUri,
    required this.collapseSignal,
    required this.refreshSignal,
    required this.iconAtStart,
  });

  /// Fetches the distinct attribution strings of the active style.
  final Future<List<String>> Function() loadAttributions;

  /// Opens an attribution link.
  final Future<void> Function(String uri) openUri;

  /// Bumped on camera movement: collapses the pill.
  final ValueListenable<int> collapseSignal;

  /// Bumped when a style finishes loading: refetches the attributions.
  final ValueListenable<int> refreshSignal;

  /// Whether the info button sits at the start (left corners) or at the end
  /// (right corners) of the expanded pill.
  final bool iconAtStart;

  @override
  State<AttributionOrnament> createState() => _AttributionOrnamentState();
}

class _AttributionOrnamentState extends State<AttributionOrnament> {
  static final _anchorPattern = RegExp(
    '<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
    caseSensitive: false,
    dotAll: true,
  );
  static final _tagPattern = RegExp('<[^>]*>');

  bool _expanded = true;
  List<String> _attributions = const [];
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    widget.collapseSignal.addListener(_collapse);
    widget.refreshSignal.addListener(_fetch);
    _fetch();
  }

  @override
  void dispose() {
    widget.collapseSignal.removeListener(_collapse);
    widget.refreshSignal.removeListener(_fetch);
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _collapse() {
    if (_expanded && mounted) setState(() => _expanded = false);
  }

  void _fetch() {
    unawaited(() async {
      List<String> attributions;
      try {
        attributions = await widget.loadAttributions();
      } catch (_) {
        attributions = const [];
      }
      if (mounted) setState(() => _attributions = attributions);
    }());
  }

  /// Converts one attribution HTML fragment into spans with tappable links.
  List<InlineSpan> _spansOf(String html, TextStyle linkStyle) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _anchorPattern.allMatches(html)) {
      if (match.start > cursor) {
        final text = html
            .substring(cursor, match.start)
            .replaceAll(_tagPattern, '');
        if (text.trim().isNotEmpty) spans.add(TextSpan(text: text));
      }
      final href = match.group(1)!;
      final label = match.group(2)!.replaceAll(_tagPattern, '').trim();
      if (label.isNotEmpty) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => unawaited(widget.openUri(href));
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(text: label, style: linkStyle, recognizer: recognizer),
        );
      }
      cursor = match.end;
    }
    if (cursor < html.length) {
      final text = html.substring(cursor).replaceAll(_tagPattern, '');
      if (text.trim().isNotEmpty) spans.add(TextSpan(text: text));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final maxTextWidth = MediaQuery.sizeOf(context).width * 0.6;

    final button = SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: () => setState(() => _expanded = !_expanded),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: const Icon(
          Icons.info_outline,
          size: 18,
          color: Color(0xFF4A5560),
        ),
      ),
    );

    Widget? text;
    if (_expanded) {
      _disposeRecognizers();
      const textStyle = TextStyle(
        color: Color(0xDD37474F),
        fontSize: 11,
        height: 1.3,
      );
      const linkStyle = TextStyle(
        color: Color(0xFF1E6BB0),
        decoration: TextDecoration.underline,
        decorationColor: Color(0x661E6BB0),
      );
      final hasMapLibre = _attributions.any(
        (a) => a.toLowerCase().contains('maplibre'),
      );
      final fragments = [
        if (!hasMapLibre) '<a href="https://maplibre.org/">MapLibre</a>',
        ..._attributions,
      ];
      final spans = <InlineSpan>[];
      for (var i = 0; i < fragments.length; i++) {
        if (i > 0) spans.add(const TextSpan(text: '  '));
        spans.addAll(_spansOf(fragments[i], linkStyle));
      }
      text = Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxTextWidth),
          child: RichText(
            text: TextSpan(style: textStyle, children: spans),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.iconAtStart) button,
            if (text != null) ...[
              const SizedBox(width: 2),
              text,
              const SizedBox(width: 6),
            ],
            if (!widget.iconAtStart) button,
          ],
        ),
      ),
    );
  }
}

/// The MapLibre mark: the official on-map logo (pin + wordmark) that the
/// native SDKs display bottom-left, at its native 88x23 dp size.
class LogoOrnament extends StatelessWidget {
  const LogoOrnament({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Image.asset(
        'assets/maplibre_logo.png',
        package: 'maplibre_gl_native',
        width: 88,
        height: 23,
      ),
    );
  }
}

/// Scale bar ornament: a bracket with a rounded metric distance sized to the
/// current meters-per-pixel of the camera. Opt-in (no maplibre_gl option).
class ScaleBarOrnament extends StatelessWidget {
  const ScaleBarOrnament({super.key, required this.metersPerPixel});

  /// Meters per logical pixel at the camera center latitude.
  final ValueListenable<double> metersPerPixel;

  /// Largest 1/2/5 x 10^n value not exceeding [maxMeters].
  static double _niceDistance(double maxMeters) {
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

  static String _label(double meters) {
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
          const maxWidth = 110.0;
          final meters = _niceDistance(maxWidth * mpp);
          final width = meters / mpp;
          return CustomPaint(
            size: Size(width, 22),
            painter: _ScaleBarPainter(label: _label(meters)),
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
      Offset((size.width - text.width) / 2, baseline - tickHeight - text.height),
    );
  }

  @override
  bool shouldRepaint(covariant _ScaleBarPainter oldDelegate) =>
      label != oldDelegate.label;
}
