import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/util.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating animated annotation updates
class EditAnnotationAnimatedExample extends ExamplePage {
  const EditAnnotationAnimatedExample({super.key})
    : super(
        const Icon(Icons.animation),
        'Edit Annotation (Animated)',
        category: ExampleCategory.annotations,
      );

  @override
  Widget build(BuildContext context) => const _EditAnnotationAnimatedBody();
}

class _EditAnnotationAnimatedBody extends StatefulWidget {
  const _EditAnnotationAnimatedBody();

  @override
  State<_EditAnnotationAnimatedBody> createState() =>
      _EditAnnotationAnimatedBodyState();
}

class _EditAnnotationAnimatedBodyState
    extends State<_EditAnnotationAnimatedBody>
    with SingleTickerProviderStateMixin {
  MapLibreMapController? _controller;
  Symbol? _animatedSymbol;
  Circle? _animatedCircle;
  Line? _animatedLine;

  Timer? _animationTimer;
  bool _isAnimating = false;

  late AnimationController _colorAnimationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _colorAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _colorAnimation = ColorTween(
      begin: Colors.blue,
      end: Colors.red,
    ).animate(_colorAnimationController)..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        unawaited(_colorAnimationController.reverse());
      } else if (status == AnimationStatus.dismissed) {
        unawaited(_colorAnimationController.forward());
      }
    });

    _colorAnimationController.addListener(() {
      unawaited(_updateAnnotationColors());
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _colorAnimationController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    await addImageFromAsset(
      _controller!,
      "custom-marker",
      "assets/symbols/custom-marker.png",
    );
    await _addInitialAnnotations();
  }

  Future<void> _addInitialAnnotations() async {
    if (_controller == null) return;

    const center = ExampleConstants.sydneyCenter;

    // Add a symbol
    final symbol = await _controller!.addSymbol(
      const SymbolOptions(
        geometry: center,
        iconImage: 'custom-marker',
        iconSize: 1.0,
        textField: 'Animated Symbol',
        textSize: 14,
        textOffset: Offset(0, -2),
        textColor: '#0000FF',
      ),
    );
    await _controller!.setSymbolIconAllowOverlap(true);
    await _controller!.setSymbolTextAllowOverlap(true);

    // Add a circle
    final circle = await _controller!.addCircle(
      CircleOptions(
        geometry: LatLng(center.latitude - 0.01, center.longitude),
        circleRadius: 15,
        circleColor: '#0000FF',
        circleOpacity: 0.8,
      ),
    );

    // Add a line
    final line = await _controller!.addLine(
      LineOptions(
        geometry: [
          LatLng(center.latitude + 0.01, center.longitude - 0.01),
          LatLng(center.latitude + 0.01, center.longitude + 0.01),
        ],
        lineColor: '#0000FF',
        lineWidth: 4,
      ),
    );

    setState(() {
      _animatedSymbol = symbol;
      _animatedCircle = circle;
      _animatedLine = line;
    });
  }

  Future<void> _updateAnnotationColors() async {
    if (_controller == null ||
        _animatedSymbol == null ||
        _animatedCircle == null ||
        _animatedLine == null) {
      return;
    }

    final color = _colorAnimation.value;
    if (color == null) return;

    final hexColor =
        '#${color.toARGB32().toRadixString(16).substring(2).padLeft(6, '0')}';

    try {
      // Update symbol color
      await _controller!.updateSymbol(
        _animatedSymbol!,
        SymbolOptions(textColor: hexColor),
      );

      // Update circle color
      await _controller!.updateCircle(
        _animatedCircle!,
        CircleOptions(circleColor: hexColor),
      );

      // Update line color
      await _controller!.updateLine(
        _animatedLine!,
        LineOptions(lineColor: hexColor),
      );
    } catch (e) {
      dev.log('Error updating annotation colors: $e');
    }
  }

  Future<void> _startPositionAnimation() async {
    if (_isAnimating) return;

    setState(() => _isAnimating = true);
    await _colorAnimationController.forward();

    const center = ExampleConstants.sydneyCenter;
    var step = 0;

    _animationTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) async {
        if (!_isAnimating || _controller == null) {
          timer.cancel();
          return;
        }

        step++;
        final angle = step * 0.1;
        const radius = 0.01;

        // Animate symbol in a circle
        if (_animatedSymbol != null) {
          final newLat = center.latitude + radius * sin(angle);
          final newLng = center.longitude + radius * cos(angle);
          await _controller!.updateSymbol(
            _animatedSymbol!,
            SymbolOptions(
              geometry: LatLng(newLat, newLng),
              iconRotate: angle * 180 / pi,
            ),
          );
        }

        // Animate circle in a figure-8 pattern
        if (_animatedCircle != null) {
          final newLat = center.latitude - 0.01 + 0.005 * sin(angle * 2);
          final newLng = center.longitude + 0.01 * sin(angle);
          await _controller!.updateCircle(
            _animatedCircle!,
            CircleOptions(
              geometry: LatLng(newLat, newLng),
              circleRadius: 15 + 5 * sin(angle * 3),
            ),
          );
        }

        // Animate line (wave effect)
        if (_animatedLine != null) {
          final points = <LatLng>[];
          for (var i = 0; i < 20; i++) {
            final x = -0.01 + (0.02 * i / 19);
            final y = 0.005 * sin(angle + i * 0.5);
            points.add(
              LatLng(center.latitude + 0.01 + y, center.longitude + x),
            );
          }
          await _controller!.updateLine(
            _animatedLine!,
            LineOptions(geometry: points),
          );
        }
      },
    );
  }

  void _stopAnimation() {
    setState(() => _isAnimating = false);
    _animationTimer?.cancel();
    _colorAnimationController.stop();
  }

  Future<void> _animateSize() async {
    if (_controller == null) return;

    for (var i = 0; i < 20; i++) {
      if (_animatedSymbol != null) {
        final size = 1.0 + sin(i * 0.3) * 0.5;
        await _controller!.updateSymbol(
          _animatedSymbol!,
          SymbolOptions(iconSize: size),
        );
      }

      if (_animatedCircle != null) {
        final radius = 15 + sin(i * 0.3) * 10;
        await _controller!.updateCircle(
          _animatedCircle!,
          CircleOptions(circleRadius: radius),
        );
      }

      if (_animatedLine != null) {
        final width = 4 + sin(i * 0.3) * 3;
        await _controller!.updateLine(
          _animatedLine!,
          LineOptions(lineWidth: width),
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _animateOpacity() async {
    if (_controller == null) return;

    for (var i = 0; i < 20; i++) {
      final opacity = 0.3 + 0.7 * sin(i * 0.3).abs();

      if (_animatedSymbol != null) {
        await _controller!.updateSymbol(
          _animatedSymbol!,
          SymbolOptions(iconOpacity: opacity),
        );
      }

      if (_animatedCircle != null) {
        await _controller!.updateCircle(
          _animatedCircle!,
          CircleOptions(circleOpacity: opacity),
        );
      }

      if (_animatedLine != null) {
        await _controller!.updateLine(
          _animatedLine!,
          LineOptions(lineOpacity: opacity),
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _clearAnnotations() async {
    _stopAnimation();
    await _controller?.clearSymbols();
    await _controller?.clearCircles();
    await _controller?.clearLines();
    setState(() {
      _animatedSymbol = null;
      _animatedCircle = null;
      _animatedLine = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasController = _controller != null;
    final hasAnnotations =
        _animatedSymbol != null ||
        _animatedCircle != null ||
        _animatedLine != null;

    return MapExampleScaffold(
      map: MapLibreMap(
        initialCameraPosition: const CameraPosition(
          target: ExampleConstants.sydneyCenter,
          zoom: 13,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        styleString: ExampleConstants.demoMapStyle,
      ),
      controls: [_buildControls(hasController, hasAnnotations)],
    );
  }

  Widget _buildControls(bool hasController, bool hasAnnotations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.all(ExampleConstants.paddingStandard),
          child: Padding(
            padding: const EdgeInsets.all(ExampleConstants.paddingStandard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Annotation (Animated)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Demonstrates animating annotation properties like position, '
                  'size, color, and opacity using the update methods.',
                ),
              ],
            ),
          ),
        ),
        if (_isAnimating)
          Card(
            margin: const EdgeInsets.all(ExampleConstants.paddingStandard),
            color: Colors.green.shade50,
            child: const Padding(
              padding: EdgeInsets.all(ExampleConstants.paddingStandard),
              child: Row(
                children: [
                  Icon(Icons.play_circle_filled, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Position and color animations are running...',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ControlGroup(
          title: 'Setup',
          children: [
            ExampleButton(
              label: hasAnnotations ? 'Reset Annotations' : 'Add Annotations',
              icon: hasAnnotations ? Icons.refresh : Icons.add,
              onPressed:
                  hasController
                      ? () async {
                        await _clearAnnotations();
                        await _addInitialAnnotations();
                      }
                      : null,
            ),
            ExampleButton(
              label: 'Clear All',
              icon: Icons.clear,
              onPressed:
                  hasController && hasAnnotations ? _clearAnnotations : null,
              style: ExampleButtonStyle.destructive,
            ),
          ],
        ),
        ControlGroup(
          title: 'Position Animation',
          children: [
            ExampleButton(
              label: _isAnimating ? 'Stop Movement' : 'Start Movement',
              icon: _isAnimating ? Icons.stop : Icons.play_arrow,
              onPressed:
                  hasController && hasAnnotations
                      ? (_isAnimating
                          ? _stopAnimation
                          : _startPositionAnimation)
                      : null,
            ),
          ],
        ),
        ControlGroup(
          title: 'Property Animations',
          children: [
            ExampleButton(
              label: 'Animate Size',
              icon: Icons.zoom_out_map,
              onPressed: hasController && hasAnnotations ? _animateSize : null,
            ),
            ExampleButton(
              label: 'Animate Opacity',
              icon: Icons.opacity,
              onPressed:
                  hasController && hasAnnotations ? _animateOpacity : null,
            ),
          ],
        ),
      ],
    );
  }
}
