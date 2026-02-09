import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating circle layer properties
class CircleLayerExample extends ExamplePage {
  const CircleLayerExample({super.key})
      : super(
          const Icon(Icons.circle_outlined),
          'Circle Layer',
          category: ExampleCategory.layers,
        );

  @override
  Widget build(BuildContext context) => const _CircleLayerBody();
}

class _CircleLayerBody extends StatefulWidget {
  const _CircleLayerBody();

  @override
  State<_CircleLayerBody> createState() => _CircleLayerBodyState();
}

class _CircleLayerBodyState extends State<_CircleLayerBody> {
  MapLibreMapController? _controller;

  static const _sourceId = 'circle_source';
  static const _layerId = 'circle_layer';

  // Circle properties
  double _circleRadius = 20.0;
  double _circleOpacity = 0.8;
  double _circleStrokeWidth = 2.0;
  double _circleStrokeOpacity = 1.0;
  Color _circleColor = Colors.blue;
  Color _circleStrokeColor = Colors.white;
  double _circleBlur = 0.0;
  double _circlePitchAlignment = 0.0; // 0 = viewport, 1 = map
  double _circleTranslateX = 0.0;
  double _circleTranslateY = 0.0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    await _addCircleLayer();
  }

  Future<void> _addCircleLayer() async {
    if (_controller == null) return;

    try {
      // Add GeoJSON source with multiple points
      await _controller!.addGeoJsonSource(
        _sourceId,
        {
          'type': 'FeatureCollection',
          'features': _generateRandomPoints(20),
        },
      );

      // Add circle layer
      await _controller!.addCircleLayer(
        _sourceId,
        _layerId,
        CircleLayerProperties(
          circleRadius: _circleRadius,
          circleColor:
              '#${_circleColor.toARGB32().toRadixString(16).substring(2)}',
          circleOpacity: _circleOpacity,
          circleStrokeWidth: _circleStrokeWidth,
          circleStrokeColor:
              '#${_circleStrokeColor.toARGB32().toRadixString(16).substring(2)}',
          circleStrokeOpacity: _circleStrokeOpacity,
          circleBlur: _circleBlur,
          circlePitchAlignment: _circlePitchAlignment == 0 ? 'viewport' : 'map',
          circleTranslate: [_circleTranslateX, _circleTranslateY],
        ),
      );

      setState(() {});
    } catch (e) {
      print('CircleLayerExample: Error adding circle layer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding circle layer: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _generateRandomPoints(int count) {
    final random = Random();
    final points = <Map<String, dynamic>>[];

    for (var i = 0; i < count; i++) {
      final lat = -33.87 + (random.nextDouble() - 0.5) * 0.2;
      final lng = 151.21 + (random.nextDouble() - 0.5) * 0.2;

      points.add({
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'Point',
          'coordinates': [lng, lat],
        },
      });
    }

    return points;
  }

  Future<void> _updateLayer() async {
    if (_controller == null) return;

    try {
      await _controller!.setLayerProperties(
        _layerId,
        CircleLayerProperties(
          circleRadius: _circleRadius,
          circleColor:
              '#${_circleColor.toARGB32().toRadixString(16).substring(2)}',
          circleOpacity: _circleOpacity,
          circleStrokeWidth: _circleStrokeWidth,
          circleStrokeColor:
              '#${_circleStrokeColor.toARGB32().toRadixString(16).substring(2)}',
          circleStrokeOpacity: _circleStrokeOpacity,
          circleBlur: _circleBlur,
          circlePitchAlignment: _circlePitchAlignment == 0 ? 'viewport' : 'map',
          circleTranslate: [_circleTranslateX, _circleTranslateY],
        ),
      );
    } catch (e) {
      print('CircleLayerExample: Error updating circle layer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating circle layer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        initialCameraPosition: const CameraPosition(
          target: ExampleConstants.sydneyCenter,
          zoom: 10,
        ),
        trackCameraPosition: true,
      ),
      controls: _controller == null
          ? []
          : [
              ControlGroup(
                title: 'Circle Size',
                children: [
                  ListTile(
                    title: Text('Radius: ${_circleRadius.toStringAsFixed(1)}'),
                    subtitle: Slider(
                      value: _circleRadius,
                      min: 5.0,
                      max: 50.0,
                      divisions: 45,
                      onChanged: (value) async {
                        setState(() => _circleRadius = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: Text('Blur: ${_circleBlur.toStringAsFixed(1)}'),
                    subtitle: Slider(
                      value: _circleBlur,
                      min: 0.0,
                      max: 4.0,
                      divisions: 20,
                      onChanged: (value) async {
                        setState(() => _circleBlur = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Circle Color',
                children: [
                  ListTile(
                    title: const Text('Fill Color'),
                    trailing: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _circleColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onTap: () => _pickColor('fill'),
                  ),
                  ListTile(
                    title: Text(
                        'Opacity: ${(_circleOpacity * 100).toStringAsFixed(0)}%'),
                    subtitle: Slider(
                      value: _circleOpacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (value) async {
                        setState(() => _circleOpacity = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Circle Stroke',
                children: [
                  ListTile(
                    title: Text(
                        'Stroke Width: ${_circleStrokeWidth.toStringAsFixed(1)}'),
                    subtitle: Slider(
                      value: _circleStrokeWidth,
                      min: 0.0,
                      max: 10.0,
                      divisions: 20,
                      onChanged: (value) async {
                        setState(() => _circleStrokeWidth = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Stroke Color'),
                    trailing: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _circleStrokeColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onTap: () => _pickColor('stroke'),
                  ),
                  ListTile(
                    title: Text(
                        'Stroke Opacity: ${(_circleStrokeOpacity * 100).toStringAsFixed(0)}%'),
                    subtitle: Slider(
                      value: _circleStrokeOpacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (value) async {
                        setState(() => _circleStrokeOpacity = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Circle Transform',
                children: [
                  ListTile(
                    title: const Text('Pitch Alignment'),
                    subtitle: ExampleSegmentedButton<double>(
                      segments: const [
                        ExampleSegment(
                          value: 0.0,
                          label: 'Viewport',
                        ),
                        ExampleSegment(
                          value: 1.0,
                          label: 'Map',
                        ),
                      ],
                      selected: _circlePitchAlignment,
                      onSelectionChanged: (value) async {
                        setState(() => _circlePitchAlignment = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                        'Translate X: ${_circleTranslateX.toStringAsFixed(0)}'),
                    subtitle: Slider(
                      value: _circleTranslateX,
                      min: -50.0,
                      max: 50.0,
                      divisions: 100,
                      onChanged: (value) async {
                        setState(() => _circleTranslateX = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                        'Translate Y: ${_circleTranslateY.toStringAsFixed(0)}'),
                    subtitle: Slider(
                      value: _circleTranslateY,
                      min: -50.0,
                      max: 50.0,
                      divisions: 100,
                      onChanged: (value) async {
                        setState(() => _circleTranslateY = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Actions',
                children: [
                  ExampleButton(
                    label: 'Reset Properties',
                    onPressed: () async {
                      setState(() {
                        _circleRadius = 20.0;
                        _circleOpacity = 0.8;
                        _circleStrokeWidth = 2.0;
                        _circleStrokeOpacity = 1.0;
                        _circleColor = Colors.blue;
                        _circleStrokeColor = Colors.white;
                        _circleBlur = 0.0;
                        _circlePitchAlignment = 0.0;
                        _circleTranslateX = 0.0;
                        _circleTranslateY = 0.0;
                      });
                      await _updateLayer();
                    },
                  ),
                ],
              ),
            ],
    );
  }

  Future<void> _pickColor(String type) async {
    final currentColor = type == 'fill' ? _circleColor : _circleStrokeColor;
    final title = type == 'fill' ? 'Select Fill Color' : 'Select Stroke Color';

    final selectedColor = await ColorPickerModal.show(
      context: context,
      title: title,
      currentColor: currentColor,
    );

    if (selectedColor != null) {
      setState(() {
        if (type == 'fill') {
          _circleColor = selectedColor;
        } else {
          _circleStrokeColor = selectedColor;
        }
      });
      await _updateLayer();
    }
  }
}
