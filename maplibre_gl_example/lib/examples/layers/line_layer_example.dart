import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/util.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating line layer properties
class LineLayerExample extends ExamplePage {
  const LineLayerExample({super.key})
      : super(
          const Icon(Icons.timeline),
          'Line Layer',
          category: ExampleCategory.layers,
        );

  @override
  Widget build(BuildContext context) => const _LineLayerBody();
}

class _LineLayerBody extends StatefulWidget {
  const _LineLayerBody();

  @override
  State<_LineLayerBody> createState() => _LineLayerBodyState();
}

class _LineLayerBodyState extends State<_LineLayerBody> {
  MapLibreMapController? _controller;

  static const _sourceId = 'line_source';
  static const _layerId = 'line_layer';

  // Line properties
  double _lineWidth = 4.0;
  double _lineOpacity = 0.9;
  Color _lineColor = const Color(0xFFE74C3C);
  double _lineBlur = 0.0;
  double _lineGapWidth = 0.0;
  double _lineOffset = 0.0;
  double _lineTranslateX = 0.0;
  double _lineTranslateY = 0.0;
  String _lineCap = 'round'; // butt, round, square
  String _lineJoin = 'round'; // bevel, round, miter
  double _lineMiterLimit = 2.0;
  double _lineRoundLimit = 1.05;
  String? _linePattern;
  _LineDashStyle _lineDasharray = _LineDashStyle.solid;

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    await _loadPatternImages();

    // Add GeoJSON source with multiple lines
    await _controller!.addGeoJsonSource(
      _sourceId,
      {
        'type': 'FeatureCollection',
        'features': _generateRandomLines(5),
      },
    );
    await _addLineLayer();
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
    } catch (e) {
      print('LineLayerExample: Error loading pattern images: $e');
    }
  }

  Future<void> _addLineLayer() async {
    if (_controller == null) return;

    try {
      // Add line layer
      await _controller!.addLineLayer(
        _sourceId,
        _layerId,
        LineLayerProperties(
          lineWidth: _lineWidth,
          lineOpacity: _lineOpacity,
          lineColor: '#${_lineColor.toARGB32().toRadixString(16).substring(2)}',
          lineBlur: _lineBlur,
          lineGapWidth: _lineGapWidth,
          lineOffset: _lineOffset,
          lineTranslate: [_lineTranslateX, _lineTranslateY],
          lineCap: _lineCap,
          lineJoin: _lineJoin,
          lineMiterLimit: _lineMiterLimit,
          lineRoundLimit: _lineRoundLimit,
          linePattern: _linePattern,
          lineDasharray: _lineDasharray.dashArray,
        ),
      );

      setState(() {});
    } catch (e) {
      print('LineLayerExample: Error adding line layer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding line layer: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _generateRandomLines(int count) {
    final random = Random();
    final lines = <Map<String, dynamic>>[];

    for (var i = 0; i < count; i++) {
      final startLat = -33.87 + (random.nextDouble() - 0.5) * 0.2;
      final startLng = 151.21 + (random.nextDouble() - 0.5) * 0.2;

      // Generate a curved line with multiple points
      final coordinates = <List<double>>[];
      for (var j = 0; j < 5; j++) {
        coordinates.add([
          startLng + j * 0.02 + (random.nextDouble() - 0.5) * 0.01,
          startLat + (random.nextDouble() - 0.5) * 0.04,
        ]);
      }

      lines.add({
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'LineString',
          'coordinates': coordinates,
        },
      });
    }

    return lines;
  }

  Future<void> _updateLayer() async {
    if (_controller == null) return;

    try {
      await _controller!.setLayerProperties(
        _layerId,
        LineLayerProperties(
          lineWidth: _lineWidth,
          lineOpacity: _lineOpacity,
          lineColor: '#${_lineColor.toARGB32().toRadixString(16).substring(2)}',
          lineBlur: _lineBlur,
          lineGapWidth: _lineGapWidth,
          lineOffset: _lineOffset,
          lineTranslate: [_lineTranslateX, _lineTranslateY],
          lineCap: _lineCap,
          lineJoin: _lineJoin,
          lineMiterLimit: _lineMiterLimit,
          lineRoundLimit: _lineRoundLimit,
          linePattern: _linePattern,
          lineDasharray: _lineDasharray.dashArray,
        ),
      );
    } catch (e) {
      print('LineLayerExample: Error updating line layer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating layer: $e')),
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
                title: 'Line Appearance',
                children: [
                  ListTile(
                    title: Text('Width: ${_lineWidth.toStringAsFixed(1)}'),
                    subtitle: Slider(
                      value: _lineWidth,
                      min: 1.0,
                      max: 20.0,
                      divisions: 38,
                      onChanged: (value) async {
                        setState(() => _lineWidth = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: Text('Blur: ${_lineBlur.toStringAsFixed(1)}'),
                    subtitle: Slider(
                      value: _lineBlur,
                      min: 0.0,
                      max: 10.0,
                      divisions: 20,
                      onChanged: (value) async {
                        setState(() => _lineBlur = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Color'),
                    trailing: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _lineColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onTap: _pickColor,
                  ),
                  ListTile(
                    title: Text(
                        'Opacity: ${(_lineOpacity * 100).toStringAsFixed(0)}%'),
                    subtitle: Slider(
                      value: _lineOpacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (value) async {
                        setState(() => _lineOpacity = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Line Style',
                children: [
                  ListTile(
                    title: const Text('Cap Style'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End of line appearance'),
                        const SizedBox(height: 8),
                        ExampleSegmentedButton<String>(
                          segments: const [
                            ExampleSegment(
                              value: 'butt',
                              label: 'Butt',
                            ),
                            ExampleSegment(
                              value: 'round',
                              label: 'Round',
                            ),
                            ExampleSegment(
                              value: 'square',
                              label: 'Square',
                            ),
                          ],
                          selected: _lineCap,
                          onSelectionChanged: (value) async {
                            setState(() => _lineCap = value);
                            await _updateLayer();
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: const Text('Join Style'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Line corner appearance'),
                        const SizedBox(height: 8),
                        ExampleSegmentedButton<String>(
                          segments: const [
                            ExampleSegment(
                              value: 'bevel',
                              label: 'Bevel',
                            ),
                            ExampleSegment(
                              value: 'round',
                              label: 'Round',
                            ),
                            ExampleSegment(
                              value: 'miter',
                              label: 'Miter',
                            ),
                          ],
                          selected: _lineJoin,
                          onSelectionChanged: (value) async {
                            setState(() => _lineJoin = value);
                            await _updateLayer();
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_lineJoin == 'miter')
                    ListTile(
                      title: Text(
                          'Miter Limit: ${_lineMiterLimit.toStringAsFixed(1)}'),
                      subtitle: const Text('Sharp corner threshold'),
                      trailing: SizedBox(
                        width: 200,
                        child: Slider(
                          value: _lineMiterLimit,
                          min: 1.0,
                          max: 10.0,
                          divisions: 18,
                          onChanged: (value) async {
                            setState(() => _lineMiterLimit = value);
                            await _updateLayer();
                          },
                        ),
                      ),
                    ),
                  if (_lineJoin == 'round')
                    ListTile(
                      title: Text(
                          'Round Limit: ${_lineRoundLimit.toStringAsFixed(2)}'),
                      subtitle: const Text('Round corner threshold'),
                      trailing: SizedBox(
                        width: 200,
                        child: Slider(
                          value: _lineRoundLimit,
                          min: 1.0,
                          max: 2.0,
                          divisions: 20,
                          onChanged: (value) async {
                            setState(() => _lineRoundLimit = value);
                            await _updateLayer();
                          },
                        ),
                      ),
                    ),
                ],
              ),
              ControlGroup(
                title: 'Line Layout',
                children: [
                  ListTile(
                    title:
                        Text('Gap Width: ${_lineGapWidth.toStringAsFixed(1)}'),
                    subtitle: const Text('Space between parallel lines'),
                    trailing: SizedBox(
                      width: 200,
                      child: Slider(
                        value: _lineGapWidth,
                        min: 0.0,
                        max: 20.0,
                        divisions: 20,
                        onChanged: (value) async {
                          setState(() => _lineGapWidth = value);
                          await _updateLayer();
                        },
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text('Offset: ${_lineOffset.toStringAsFixed(1)}'),
                    subtitle: const Text('Perpendicular shift'),
                    trailing: SizedBox(
                      width: 200,
                      child: Slider(
                        value: _lineOffset,
                        min: -20.0,
                        max: 20.0,
                        divisions: 40,
                        onChanged: (value) async {
                          setState(() => _lineOffset = value);
                          await _updateLayer();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Line Transform',
                children: [
                  ListTile(
                    title: Text(
                        'Translate X: ${_lineTranslateX.toStringAsFixed(0)}'),
                    subtitle: Slider(
                      value: _lineTranslateX,
                      min: -50.0,
                      max: 50.0,
                      divisions: 100,
                      onChanged: (value) async {
                        setState(() => _lineTranslateX = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                        'Translate Y: ${_lineTranslateY.toStringAsFixed(0)}'),
                    subtitle: Slider(
                      value: _lineTranslateY,
                      min: -50.0,
                      max: 50.0,
                      divisions: 100,
                      onChanged: (value) async {
                        setState(() => _lineTranslateY = value);
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
                    value: _linePattern != null,
                    title: const Text('Line Pattern'),
                    subtitle: Text(_linePattern ?? 'None'),
                    onChanged: (bool value) async {
                      setState(() {
                        _linePattern = value ? 'marker-pattern' : null;
                      });
                      await _updateLayer();
                    },
                  ),
                ],
              ),
              ControlGroup(
                title: 'Dash Array',
                children: [
                  ListTile(
                    title: const Text('Dash Style'),
                    subtitle: Text(_lineDasharray.label),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _selectDashArray(),
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
                        _lineWidth = 4.0;
                        _lineOpacity = 0.9;
                        _lineColor = const Color(0xFFE74C3C);
                        _lineBlur = 0.0;
                        _lineGapWidth = 0.0;
                        _lineOffset = 0.0;
                        _lineTranslateX = 0.0;
                        _lineTranslateY = 0.0;
                        _lineCap = 'round';
                        _lineJoin = 'round';
                        _lineMiterLimit = 2.0;
                        _lineRoundLimit = 1.05;
                        _linePattern = null;
                        _lineDasharray = _LineDashStyle.solid;
                      });
                      await _updateLayer();
                    },
                  ),
                ],
              ),
            ],
    );
  }

  Future<void> _pickColor() async {
    final selectedColor = await ColorPickerModal.show(
      context: context,
      title: 'Select Line Color',
      currentColor: _lineColor,
    );

    if (selectedColor != null) {
      setState(() => _lineColor = selectedColor);
      await _updateLayer();
    }
  }

  Future<void> _selectDashArray() async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Dash Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_LineDashStyle.solid.label),
              subtitle: const Text('No dashes'),
              leading: Icon(
                _lineDasharray == _LineDashStyle.solid
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onTap: () => Navigator.pop(context, _LineDashStyle.solid),
            ),
            ListTile(
              title: Text(_LineDashStyle.dotted.label),
              subtitle: Text(_LineDashStyle.dotted.dashArray.toString()),
              leading: Icon(
                _lineDasharray == _LineDashStyle.dotted
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onTap: () => Navigator.pop(context, _LineDashStyle.dotted),
            ),
            ListTile(
              title: Text(_LineDashStyle.dashed.label),
              subtitle: Text(_LineDashStyle.dashed.dashArray.toString()),
              leading: Icon(
                _lineDasharray == _LineDashStyle.dashed
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onTap: () => Navigator.pop(context, _LineDashStyle.dashed),
            ),
            ListTile(
              title: Text(_LineDashStyle.dashDot.label),
              subtitle: Text(_LineDashStyle.dashDot.dashArray.toString()),
              leading: Icon(
                _lineDasharray == _LineDashStyle.dashDot
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onTap: () => Navigator.pop(context, _LineDashStyle.dashDot),
            ),
            ListTile(
              title: Text(_LineDashStyle.custom.label),
              subtitle: Text(_LineDashStyle.custom.dashArray.toString()),
              leading: Icon(
                _lineDasharray == _LineDashStyle.custom
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onTap: () => Navigator.pop(context, _LineDashStyle.custom),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // Only update if a selection was made (not cancelled)
    if (result != null && result is _LineDashStyle) {
      setState(() => _lineDasharray = result);
      await _updateLayer();
    }
  }
}

enum _LineDashStyle {
  solid(label: 'Solid', dashArray: null),
  dotted(label: 'Dotted', dashArray: [0.1, 2]),
  dashed(label: 'Dashed', dashArray: [6, 3]),
  dashDot(label: 'Dash Dot', dashArray: [6, 2, 0.1, 2]),
  custom(label: 'Custom', dashArray: [10.0, 5.0, 2.0, 5.0]);

  final String label;
  final List<double>? dashArray;
  const _LineDashStyle({required this.label, required this.dashArray});
}
