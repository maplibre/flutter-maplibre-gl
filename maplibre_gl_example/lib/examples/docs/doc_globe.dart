import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../page.dart';
import '../../shared/shared.dart';

/// Documentation hero demo: a slowly turning globe with its atmosphere.
///
/// Purely ambient, so every gesture is disabled: it sits at the top of the
/// globe guide and of the docsite homepage as a living picture, not as a
/// playground. The background colour matches the documentation site, so the
/// globe floats on the page instead of sitting in a differently coloured box.
///
/// Two query parameters tune it per embed:
/// `bg` (hex, no hash) overrides the background colour, and `stars=0` hides
/// the star field; the homepage uses both to blend with either site theme.
class DocGlobeExample extends ExamplePage {
  const DocGlobeExample({super.key})
    : super(
        const Icon(Icons.public),
        'Doc Globe',
        category: ExampleCategory.advanced,
        needsLocationPermission: false,
      );

  @override
  Widget build(BuildContext context) => const _DocGlobeBody();
}

class _DocGlobeBody extends StatefulWidget {
  const _DocGlobeBody();

  @override
  State<_DocGlobeBody> createState() => _DocGlobeBodyState();
}

class _DocGlobeBodyState extends State<_DocGlobeBody> {
  /// --md-default-bg-color of the docsite's dark scheme.
  static const _docsiteBackground = Color(0xFF0D1420);

  /// Degrees of longitude per tick; one revolution takes about 75 seconds.
  static const _spinStep = 0.24;
  static const _tick = Duration(milliseconds: 50);

  late final bool _stars;
  late final Color _background;

  MapLibreMapController? _controller;
  Timer? _spinTimer;
  double _longitude = 10;

  @override
  void initState() {
    super.initState();
    final params = Uri.base.queryParameters;
    _stars = params['stars'] != '0' && params['stars'] != 'false';
    final bg = int.tryParse(params['bg'] ?? '', radix: 16);
    _background = bg == null ? _docsiteBackground : Color(0xFF000000 | bg);
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setProjection('globe');
    // Defaults for the sky colors; the halo is what matters here.
    await controller.setSky(const SkyProperties(atmosphereBlend: 1));
    _spinTimer ??= Timer.periodic(_tick, (_) {
      _longitude += _spinStep;
      if (_longitude > 180) _longitude -= 360;
      unawaited(
        _controller?.moveCamera(CameraUpdate.newLatLng(LatLng(18, _longitude))),
      );
    });
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The map canvas is transparent around the globe, so the star
          // field painted underneath shows through as the night sky.
          if (_stars) CustomPaint(painter: _StarFieldPainter(_background)),
          MapLibreMap(
            // Pinned to OpenFreeMap Liberty rather than the resolved demo
            // style: a hero image should look the same on every visit.
            styleString: ExampleConstants.fallbackMapStyle,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: const CameraPosition(
              target: LatLng(18, 10),
              zoom: 2.1,
            ),
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            dragEnabled: false,
            doubleClickZoomEnabled: false,
            compassEnabled: false,
          ),
        ],
      ),
    );
  }
}

/// A deterministic star field on the docsite's dark background.
class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter(this.background);

  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    // Seeded, so the sky does not twinkle on rebuilds.
    final random = Random(7);
    final star = Paint();
    for (var i = 0; i < 220; i++) {
      final brightness = 0.25 + random.nextDouble() * 0.65;
      star.color = Colors.white.withValues(alpha: brightness);
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.4 + random.nextDouble() * 0.9,
        star,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => false;
}
