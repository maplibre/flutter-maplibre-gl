import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/util.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating fill layer properties
class FillLayerExample extends ExamplePage {
  const FillLayerExample({super.key})
      : super(
          const Icon(Icons.square),
          'Fill Layer',
          category: ExampleCategory.layers,
        );

  @override
  Widget build(BuildContext context) => const _FillLayerBody();
}

class _FillLayerBody extends StatefulWidget {
  const _FillLayerBody();

  @override
  State<_FillLayerBody> createState() => _FillLayerBodyState();
}

class _FillLayerBodyState extends State<_FillLayerBody> {
  MapLibreMapController? _controller;

  static const _sourceId = 'fill_source';
  static const _layerId = 'fill_layer';

  // Fill properties
  double _fillOpacity = 0.6;
  Color _fillColor = const Color(0xFF3498DB);
  Color _fillOutlineColor = const Color(0xFF2C3E50);
  double _fillTranslateX = 0.0;
  double _fillTranslateY = 0.0;
  String _fillTranslateAnchor = 'map';
  bool _fillAntialias = true;
  String? _fillPattern;

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    await _loadPatternImages();
    await _addFillLayer();
  }

  Future<void> _loadPatternImages() async {
    if (_controller == null) return;

    try {
      // Load marker pattern from assets
      await addImageFromAsset(
        _controller!,
        'marker-pattern',
        ExampleConstants.markerPatternPath,
      );
      print('FillLayerExample: Pattern images loaded successfully');
    } catch (e) {
      print('FillLayerExample: Error loading pattern images: $e');
    }
  }

  Future<void> _addFillLayer() async {
    if (_controller == null) return;

    try {
      // Add GeoJSON source with multiple polygons
      await _controller!.addGeoJsonSource(
        _sourceId,
        {
          'type': 'FeatureCollection',
          'features': _generateRandomPolygons(5),
        },
      );

      // Add fill layer
      await _controller!.addFillLayer(
        _sourceId,
        _layerId,
        FillLayerProperties(
          fillOpacity: _fillOpacity,
          fillColor: '#${_fillColor.toARGB32().toRadixString(16).substring(2)}',
          fillOutlineColor:
              '#${_fillOutlineColor.toARGB32().toRadixString(16).substring(2)}',
          fillTranslate: [_fillTranslateX, _fillTranslateY],
          fillTranslateAnchor: _fillTranslateAnchor,
          fillAntialias: _fillAntialias,
          fillPattern: _fillPattern,
        ),
      );

      setState(() {});
    } catch (e) {
      print('FillLayerExample: Error adding fill layer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding fill layer: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _generateRandomPolygons(int count) {
    final random = Random();
    final polygons = <Map<String, dynamic>>[];

    for (var i = 0; i < count; i++) {
      final centerLat = -33.87 + (random.nextDouble() - 0.5) * 0.2;
      final centerLng = 151.21 + (random.nextDouble() - 0.5) * 0.2;
      final size = 0.01 + random.nextDouble() * 0.02;

      polygons.add({
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [centerLng - size, centerLat + size],
              [centerLng + size, centerLat + size],
              [centerLng + size, centerLat - size],
              [centerLng - size, centerLat - size],
              [centerLng - size, centerLat + size],
            ]
          ],
        },
      });
    }

    return polygons;
  }

  Future<void> _updateLayer() async {
    if (_controller == null) return;

    try {
      await _controller!.setLayerProperties(
        _layerId,
        FillLayerProperties(
          fillOpacity: _fillOpacity,
          fillColor: '#${_fillColor.toARGB32().toRadixString(16).substring(2)}',
          fillOutlineColor:
              '#${_fillOutlineColor.toARGB32().toRadixString(16).substring(2)}',
          fillTranslate: [_fillTranslateX, _fillTranslateY],
          fillTranslateAnchor: _fillTranslateAnchor,
          fillAntialias: _fillAntialias,
          fillPattern: _fillPattern,
        ),
      );
    } catch (e) {
      print('FillLayerExample: Error updating fill layer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating fill layer: $e')),
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
                title: 'Fill Color',
                children: [
                  ListTile(
                    title: const Text('Fill Color'),
                    trailing: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _fillColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onTap: () => _pickColor('fill'),
                  ),
                  ListTile(
                    title: Text(
                        'Opacity: ${(_fillOpacity * 100).toStringAsFixed(0)}%'),
                    subtitle: Slider(
                      value: _fillOpacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (value) async {
                        setState(() => _fillOpacity = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Fill Outline',
                children: [
                  ListTile(
                    title: const Text('Outline Color'),
                    trailing: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _fillOutlineColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onTap: () => _pickColor('outline'),
                  ),
                  SwitchListTile(
                    title: const Text('Antialias'),
                    subtitle: const Text('Smooth edges'),
                    value: _fillAntialias,
                    onChanged: (value) async {
                      setState(() => _fillAntialias = value);
                      await _updateLayer();
                    },
                  ),
                ],
              ),
              ControlGroup(
                title: 'Fill Transform',
                children: [
                  ListTile(
                    title: Text(
                        'Translate X: ${_fillTranslateX.toStringAsFixed(0)}'),
                    subtitle: Slider(
                      value: _fillTranslateX,
                      min: -50.0,
                      max: 50.0,
                      divisions: 100,
                      onChanged: (value) async {
                        setState(() => _fillTranslateX = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                        'Translate Y: ${_fillTranslateY.toStringAsFixed(0)}'),
                    subtitle: Slider(
                      value: _fillTranslateY,
                      min: -50.0,
                      max: 50.0,
                      divisions: 100,
                      onChanged: (value) async {
                        setState(() => _fillTranslateY = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Translate Anchor'),
                    subtitle: const Text('Reference frame for translation'),
                    trailing: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'map', label: Text('Map')),
                        ButtonSegment(
                            value: 'viewport', label: Text('Viewport')),
                      ],
                      selected: {_fillTranslateAnchor},
                      onSelectionChanged: (Set<String> selected) async {
                        setState(() => _fillTranslateAnchor = selected.first);
                        await _updateLayer();
                      },
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Pattern',
                children: [
                  SwitchListTile(
                    value: _fillPattern != null,
                    title: const Text('Fill Pattern'),
                    subtitle: Text(_fillPattern ?? 'None'),
                    onChanged: (bool value) async {
                      setState(() {
                        _fillPattern = value ? 'marker-pattern' : null;
                      });
                      await _updateLayer();
                    },
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
                        _fillOpacity = 0.6;
                        _fillColor = const Color(0xFF3498DB);
                        _fillOutlineColor = const Color(0xFF2C3E50);
                        _fillTranslateX = 0.0;
                        _fillTranslateY = 0.0;
                        _fillTranslateAnchor = 'map';
                        _fillAntialias = true;
                        _fillPattern = null;
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
    final currentColor = type == 'fill' ? _fillColor : _fillOutlineColor;
    final title = type == 'fill' ? 'Select Fill Color' : 'Select Outline Color';

    final selectedColor = await ColorPickerModal.show(
      context: context,
      title: title,
      currentColor: currentColor,
    );

    if (selectedColor != null) {
      setState(() {
        if (type == 'fill') {
          _fillColor = selectedColor;
        } else {
          _fillOutlineColor = selectedColor;
        }
      });
      await _updateLayer();
    }
  }
}
