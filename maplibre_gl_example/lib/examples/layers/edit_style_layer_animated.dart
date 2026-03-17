import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating animated style layer property updates
class EditStyleLayerAnimatedExample extends ExamplePage {
  const EditStyleLayerAnimatedExample({super.key})
    : super(
        const Icon(Icons.animation),
        'Edit Style Layer (Animated)',
        category: ExampleCategory.layers,
      );

  @override
  Widget build(BuildContext context) => const _EditStyleLayerAnimatedBody();
}

class _EditStyleLayerAnimatedBody extends StatefulWidget {
  const _EditStyleLayerAnimatedBody();

  @override
  State<_EditStyleLayerAnimatedBody> createState() =>
      _EditStyleLayerAnimatedBodyState();
}

class _EditStyleLayerAnimatedBodyState
    extends State<_EditStyleLayerAnimatedBody>
    with SingleTickerProviderStateMixin {
  MapLibreMapController? _controller;

  static const _circleSourceId = 'animated_circle_source';
  static const _circleLayerId = 'animated_circle_layer';
  static const _lineSourceId = 'animated_line_source';
  static const _lineLayerId = 'animated_line_layer';
  static const _fillSourceId = 'animated_fill_source';
  static const _fillLayerId = 'animated_fill_layer';

  bool _isAnimating = false;
  Timer? _animationTimer;

  late AnimationController _colorAnimationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _colorAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _colorAnimation = ColorTween(
      begin: Colors.blue,
      end: Colors.purple,
    ).animate(_colorAnimationController)..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        unawaited(_colorAnimationController.reverse());
      } else if (status == AnimationStatus.dismissed) {
        unawaited(_colorAnimationController.forward());
      }
    });

    _colorAnimationController.addListener(() {
      unawaited(_updateLayerColors());
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
    await _addStyleLayers();
  }

  Future<void> _addStyleLayers() async {
    if (_controller == null) return;

    try {
      const center = ExampleConstants.sydneyCenter;

      // Add circle layer
      await _controller!.addGeoJsonSource(
        _circleSourceId,
        {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [center.longitude, center.latitude],
              },
              'properties': {'name': 'Animated Circle'},
            },
          ],
        },
      );

      await _controller!.addCircleLayer(
        _circleSourceId,
        _circleLayerId,
        const CircleLayerProperties(
          circleRadius: 20,
          circleColor: '#3498DB',
          circleOpacity: 0.8,
        ),
      );

      // Add line layer
      await _controller!.addGeoJsonSource(
        _lineSourceId,
        {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [center.longitude - 0.01, center.latitude - 0.01],
                  [center.longitude + 0.01, center.latitude - 0.01],
                ],
              },
              'properties': {'name': 'Animated Line'},
            },
          ],
        },
      );

      await _controller!.addLineLayer(
        _lineSourceId,
        _lineLayerId,
        const LineLayerProperties(
          lineColor: '#3498DB',
          lineWidth: 4,
          lineOpacity: 0.8,
        ),
      );

      // Add fill layer
      await _controller!.addGeoJsonSource(
        _fillSourceId,
        {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Polygon',
                'coordinates': [
                  [
                    [center.longitude - 0.005, center.latitude + 0.01],
                    [center.longitude + 0.005, center.latitude + 0.01],
                    [center.longitude + 0.005, center.latitude + 0.015],
                    [center.longitude - 0.005, center.latitude + 0.015],
                    [center.longitude - 0.005, center.latitude + 0.01],
                  ],
                ],
              },
              'properties': {'name': 'Animated Fill'},
            },
          ],
        },
      );

      await _controller!.addFillLayer(
        _fillSourceId,
        _fillLayerId,
        const FillLayerProperties(
          fillColor: '#3498DB',
          fillOpacity: 0.6,
        ),
      );

      setState(() {});
    } catch (e) {
      dev.log('Error adding style layers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding style layers: $e')),
        );
      }
    }
  }

  Future<void> _updateLayerColors() async {
    if (_controller == null) return;

    final color = _colorAnimation.value;
    if (color == null) return;

    final hexColor =
        '#${color.toARGB32().toRadixString(16).substring(2).padLeft(6, '0')}';

    try {
      await _controller!.setLayerProperties(
        _circleLayerId,
        CircleLayerProperties(circleColor: hexColor),
      );

      await _controller!.setLayerProperties(
        _lineLayerId,
        LineLayerProperties(lineColor: hexColor),
      );

      await _controller!.setLayerProperties(
        _fillLayerId,
        FillLayerProperties(fillColor: hexColor),
      );
    } catch (e) {
      dev.log('Error updating layer colors: $e');
    }
  }

  void _startColorAnimation() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    unawaited(_colorAnimationController.forward());
  }

  void _stopAnimation() {
    setState(() => _isAnimating = false);
    _colorAnimationController.stop();
  }

  Future<void> _animateCircleRadius() async {
    if (_controller == null) return;

    for (var i = 0; i < 30; i++) {
      final radius = 20 + 30 * sin(i * 0.2);
      if (radius < 0) continue; // Skip negative radius values

      await _controller!.setLayerProperties(
        _circleLayerId,
        CircleLayerProperties(circleRadius: radius),
      );
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _animateLineWidth() async {
    if (_controller == null) return;

    for (var i = 0; i < 30; i++) {
      final width = 4 + 6 * sin(i * 0.2);
      if (width < 0) continue; // Skip negative width values

      await _controller!.setLayerProperties(
        _lineLayerId,
        LineLayerProperties(lineWidth: width),
      );
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _animateOpacity() async {
    if (_controller == null) return;

    for (var i = 0; i < 30; i++) {
      final opacity = 0.3 + 0.7 * sin(i * 0.2).abs();

      await _controller!.setLayerProperties(
        _circleLayerId,
        CircleLayerProperties(circleOpacity: opacity),
      );

      await _controller!.setLayerProperties(
        _lineLayerId,
        LineLayerProperties(lineOpacity: opacity),
      );

      await _controller!.setLayerProperties(
        _fillLayerId,
        FillLayerProperties(fillOpacity: opacity),
      );

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _animateGeometry() async {
    if (_controller == null) return;

    const center = ExampleConstants.sydneyCenter;

    for (var i = 0; i < 30; i++) {
      final angle = i * 0.2;

      // Animate circle position
      final circleLng = center.longitude + 0.005 * sin(angle);
      final circleLat = center.latitude + 0.005 * cos(angle);

      if (circleLat < -90 ||
          circleLat > 90 ||
          circleLng < -180 ||
          circleLng > 180) {
        // Skip invalid latitude values
        continue;
      }

      await _controller!.setGeoJsonSource(
        _circleSourceId,
        {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [circleLng, circleLat],
              },
            },
          ],
        },
      );

      // Animate line (wave effect)
      final lineCoords = <List<double>>[];
      for (var j = 0; j < 20; j++) {
        final x = -0.01 + (0.02 * j / 19);
        final y = 0.003 * sin(angle + j * 0.3);

        // Skip invalid latitude values
        if (center.latitude - 0.01 + y < -90 ||
            center.latitude - 0.01 + y > 90) {
          continue;
        }
        if (center.longitude + x < -180 || center.longitude + x > 180) {
          continue;
        }
        lineCoords.add([
          center.longitude + x,
          center.latitude - 0.01 + y,
        ]);
      }

      await _controller!.setGeoJsonSource(
        _lineSourceId,
        {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': lineCoords,
              },
            },
          ],
        },
      );

      // Animate fill (rotate)
      final size = 0.005 + 0.002 * sin(angle);

      await _controller!.setGeoJsonSource(
        _fillSourceId,
        {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Polygon',
                'coordinates': [
                  [
                    [center.longitude - size, center.latitude + 0.01],
                    [center.longitude + size, center.latitude + 0.01],
                    [
                      center.longitude + size,
                      center.latitude + 0.01 + size * 2,
                    ],
                    [
                      center.longitude - size,
                      center.latitude + 0.01 + size * 2,
                    ],
                    [center.longitude - size, center.latitude + 0.01],
                  ],
                ],
              },
            },
          ],
        },
      );

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _removeLayers() async {
    _stopAnimation();
    if (_controller == null) return;

    try {
      await _controller!.removeLayer(_circleLayerId);
      await _controller!.removeLayer(_lineLayerId);
      await _controller!.removeLayer(_fillLayerId);
      await _controller!.removeSource(_circleSourceId);
      await _controller!.removeSource(_lineSourceId);
      await _controller!.removeSource(_fillSourceId);
    } catch (e) {
      dev.log('Error removing layers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasController = _controller != null;

    return MapExampleScaffold(
      map: MapLibreMap(
        initialCameraPosition: const CameraPosition(
          target: ExampleConstants.sydneyCenter,
          zoom: 14,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        styleString: ExampleConstants.demoMapStyle,
      ),
      controls: [_buildControls(hasController)],
    );
  }

  Widget _buildControls(bool hasController) {
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
                  'Edit Style Layer (Animated)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Demonstrates animating style layer properties like color, '
                  'size, opacity, and geometry using setLayerProperties and '
                  'setGeoJsonSource methods.',
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
                      'Color animation is running...',
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
              label: 'Reset Layers',
              icon: Icons.refresh,
              onPressed:
                  hasController
                      ? () async {
                        await _removeLayers();
                        await _addStyleLayers();
                      }
                      : null,
            ),
            ExampleButton(
              label: 'Remove Layers',
              icon: Icons.clear,
              onPressed: hasController ? _removeLayers : null,
              style: ExampleButtonStyle.destructive,
            ),
          ],
        ),
        ControlGroup(
          title: 'Color Animation',
          children: [
            ExampleButton(
              label: _isAnimating ? 'Stop Color' : 'Animate Color',
              icon: _isAnimating ? Icons.stop : Icons.palette,
              onPressed:
                  hasController
                      ? (_isAnimating ? _stopAnimation : _startColorAnimation)
                      : null,
            ),
          ],
        ),
        ControlGroup(
          title: 'Property Animations',
          children: [
            ExampleButton(
              label: 'Animate Circle Size',
              icon: Icons.radio_button_checked,
              onPressed: hasController ? _animateCircleRadius : null,
            ),
            ExampleButton(
              label: 'Animate Line Width',
              icon: Icons.line_weight,
              onPressed: hasController ? _animateLineWidth : null,
            ),
            ExampleButton(
              label: 'Animate Opacity',
              icon: Icons.opacity,
              onPressed: hasController ? _animateOpacity : null,
            ),
          ],
        ),
        ControlGroup(
          title: 'Geometry Animation',
          children: [
            ExampleButton(
              label: 'Animate Geometry',
              icon: Icons.timeline,
              onPressed: hasController ? _animateGeometry : null,
            ),
          ],
        ),
      ],
    );
  }
}
