import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/util.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating symbol layer properties
class SymbolLayerExample extends ExamplePage {
  const SymbolLayerExample({super.key})
      : super(
          const Icon(Icons.place),
          'Symbol Layer',
          category: ExampleCategory.layers,
        );

  @override
  Widget build(BuildContext context) => const _SymbolLayerBody();
}

class _SymbolLayerBody extends StatefulWidget {
  const _SymbolLayerBody();

  @override
  State<_SymbolLayerBody> createState() => _SymbolLayerBodyState();
}

class _SymbolLayerBodyState extends State<_SymbolLayerBody> {
  MapLibreMapController? _controller;

  static const _sourceId = 'symbol_source';
  static const _layerId = 'symbol_layer';

  // Text properties
  double _textSize = 14.0;
  Color _textColor = const Color(0xFF2C3E50);
  double _textOpacity = 1.0;
  double _textHaloWidth = 2.0;
  Color _textHaloColor = Colors.white;
  double _textHaloBlur = 1.0;
  double _textRotate = 0.0;
  double _textOffsetX = 0.0;
  double _textOffsetY = 0.0;
  String _textAnchor = 'center'; // center, left, right, top, bottom
  String _textJustify = 'center'; // left, center, right
  bool _textAllowOverlap = false;
  bool _textIgnorePlacement = false;

  // Icon properties
  bool _showIcon = true;
  double _iconSize = 1.0;
  double _iconRotate = 0.0;
  double _iconOffsetX = 0.0;
  double _iconOffsetY = -1.5;
  bool _iconAllowOverlap = false;
  bool _iconIgnorePlacement = false;

  // Symbol layout
  String _symbolPlacement = 'point'; // point, line
  double _symbolSpacing = 250.0;
  bool _symbolAvoidEdges = false;

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    await _addSymbolLayer();
  }

  Future<void> _addSymbolLayer() async {
    if (_controller == null) return;

    try {
      await addImageFromAsset(
        _controller!,
        "custom-marker",
        "assets/symbols/custom-marker.png",
      );

      // Add GeoJSON source with points
      await _controller!.addGeoJsonSource(
        _sourceId,
        {
          'type': 'FeatureCollection',
          'features': _generateRandomPoints(10),
        },
      );

      // Add symbol layer
      await _controller!.addSymbolLayer(
        _sourceId,
        _layerId,
        SymbolLayerProperties(
          // Icon properties
          iconImage: _showIcon ? 'custom-marker' : null,
          iconSize: _iconSize,
          iconRotate: _iconRotate,
          iconOffset: [_iconOffsetX, _iconOffsetY],
          iconAllowOverlap: _iconAllowOverlap,
          iconIgnorePlacement: _iconIgnorePlacement,
          // Text properties
          textField: '{name}',
          textSize: _textSize,
          textColor: '#${_textColor.toARGB32().toRadixString(16).substring(2)}',
          textOpacity: _textOpacity,
          textHaloWidth: _textHaloWidth,
          textHaloColor:
              '#${_textHaloColor.toARGB32().toRadixString(16).substring(2)}',
          textHaloBlur: _textHaloBlur,
          textRotate: _textRotate,
          textOffset: [_textOffsetX, _textOffsetY],
          textAnchor: _textAnchor,
          textJustify: _textJustify,
          textAllowOverlap: _textAllowOverlap,
          textIgnorePlacement: _textIgnorePlacement,
          symbolPlacement: _symbolPlacement,
          symbolSpacing: _symbolSpacing,
          symbolAvoidEdges: _symbolAvoidEdges,
        ),
      );

      setState(() {});
    } catch (e) {
      print('SymbolLayerExample: Error adding symbol layer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding symbol layer: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _generateRandomPoints(int count) {
    final random = Random();
    final points = <Map<String, dynamic>>[];
    final cities = [
      'Sydney',
      'Melbourne',
      'Brisbane',
      'Perth',
      'Adelaide',
      'Canberra',
      'Hobart',
      'Darwin',
      'Newcastle',
      'Wollongong',
    ];

    for (var i = 0; i < count; i++) {
      points.add({
        'type': 'Feature',
        'properties': {
          'name': cities[i % cities.length],
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [
            151.21 + (random.nextDouble() - 0.5) * 0.3,
            -33.87 + (random.nextDouble() - 0.5) * 0.3,
          ],
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
        SymbolLayerProperties(
          // Icon properties
          iconImage: _showIcon ? 'custom-marker' : null,
          iconSize: _iconSize,
          iconRotate: _iconRotate,
          iconOffset: [_iconOffsetX, _iconOffsetY],
          iconAllowOverlap: _iconAllowOverlap,
          iconIgnorePlacement: _iconIgnorePlacement,
          // Text properties
          textField: '{name}',
          textSize: _textSize,
          textColor: '#${_textColor.toARGB32().toRadixString(16).substring(2)}',
          textOpacity: _textOpacity,
          textHaloWidth: _textHaloWidth,
          textHaloColor:
              '#${_textHaloColor.toARGB32().toRadixString(16).substring(2)}',
          textHaloBlur: _textHaloBlur,
          textRotate: _textRotate,
          textOffset: [_textOffsetX, _textOffsetY],
          textAnchor: _textAnchor,
          textJustify: _textJustify,
          textAllowOverlap: _textAllowOverlap,
          textIgnorePlacement: _textIgnorePlacement,
          symbolPlacement: _symbolPlacement,
          symbolSpacing: _symbolSpacing,
          symbolAvoidEdges: _symbolAvoidEdges,
        ),
      );
    } catch (e) {
      print('SymbolLayerExample: Error updating symbol layer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating symbol layer: $e')),
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
                title: 'Icon Properties',
                children: [
                  ListTile(
                    title: Text('Icon Size: ${_iconSize.toStringAsFixed(1)}'),
                    subtitle: Slider(
                      value: _iconSize,
                      min: 0.5,
                      max: 3.0,
                      divisions: 25,
                      onChanged: (value) async {
                        setState(() => _iconSize = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                        'Icon Rotation: ${_iconRotate.toStringAsFixed(0)}°'),
                    subtitle: Slider(
                      value: _iconRotate,
                      min: 0.0,
                      max: 360.0,
                      divisions: 72,
                      onChanged: (value) async {
                        setState(() => _iconRotate = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                        'Icon Offset X: ${_iconOffsetX.toStringAsFixed(1)}'),
                    subtitle: Slider(
                      value: _iconOffsetX,
                      min: -3.0,
                      max: 3.0,
                      divisions: 60,
                      onChanged: (value) async {
                        setState(() => _iconOffsetX = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                        'Icon Offset Y: ${_iconOffsetY.toStringAsFixed(1)}'),
                    subtitle: Slider(
                      value: _iconOffsetY,
                      min: -3.0,
                      max: 3.0,
                      divisions: 60,
                      onChanged: (value) async {
                        setState(() => _iconOffsetY = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Icon Allow Overlap'),
                    subtitle: const Text('Allow icons to overlap'),
                    value: _iconAllowOverlap,
                    onChanged: (value) async {
                      setState(() => _iconAllowOverlap = value);
                      await _updateLayer();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Icon Ignore Placement'),
                    subtitle: const Text('Ignore icon collision detection'),
                    value: _iconIgnorePlacement,
                    onChanged: (value) async {
                      setState(() => _iconIgnorePlacement = value);
                      await _updateLayer();
                    },
                  ),
                ],
              ),
              ControlGroup(
                title: 'Text Appearance',
                children: [
                  ListTile(
                    title: Text('Size: ${_textSize.toStringAsFixed(1)}'),
                    subtitle: Slider(
                      value: _textSize,
                      min: 8.0,
                      max: 32.0,
                      divisions: 48,
                      onChanged: (value) async {
                        setState(() => _textSize = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Text Color'),
                    trailing: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _textColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onTap: () => _pickColor(true),
                  ),
                  ListTile(
                    title: Text(
                        'Opacity: ${(_textOpacity * 100).toStringAsFixed(0)}%'),
                    subtitle: Slider(
                      value: _textOpacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (value) async {
                        setState(() => _textOpacity = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Text Halo',
                children: [
                  ListTile(
                    title: Text(
                        'Halo Width: ${_textHaloWidth.toStringAsFixed(1)}'),
                    subtitle: Slider(
                      value: _textHaloWidth,
                      min: 0.0,
                      max: 4.0,
                      divisions: 20,
                      onChanged: (value) async {
                        setState(() => _textHaloWidth = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Halo Color'),
                    trailing: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _textHaloColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onTap: () => _pickColor(false),
                  ),
                  ListTile(
                    title:
                        Text('Halo Blur: ${_textHaloBlur.toStringAsFixed(1)}'),
                    subtitle: Slider(
                      value: _textHaloBlur,
                      min: 0.0,
                      max: 4.0,
                      divisions: 20,
                      onChanged: (value) async {
                        setState(() => _textHaloBlur = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Text Layout',
                children: [
                  ListTile(
                    title: const Text('Anchor Position'),
                    subtitle: const Text('Text alignment relative to point'),
                    trailing: DropdownButton<String>(
                      value: _textAnchor,
                      items: const [
                        DropdownMenuItem(
                            value: 'center', child: Text('Center')),
                        DropdownMenuItem(value: 'top', child: Text('Top')),
                        DropdownMenuItem(
                            value: 'bottom', child: Text('Bottom')),
                        DropdownMenuItem(value: 'left', child: Text('Left')),
                        DropdownMenuItem(value: 'right', child: Text('Right')),
                        DropdownMenuItem(
                            value: 'top-left', child: Text('Top Left')),
                        DropdownMenuItem(
                            value: 'top-right', child: Text('Top Right')),
                        DropdownMenuItem(
                            value: 'bottom-left', child: Text('Bottom Left')),
                        DropdownMenuItem(
                            value: 'bottom-right', child: Text('Bottom Right')),
                      ],
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() => _textAnchor = value);
                          await _updateLayer();
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Text Justify'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Horizontal text alignment'),
                        const SizedBox(height: 8),
                        ExampleSegmentedButton<String>(
                          segments: const [
                            ExampleSegment(
                              value: 'left',
                              label: 'Left',
                            ),
                            ExampleSegment(
                              value: 'center',
                              label: 'Center',
                            ),
                            ExampleSegment(
                              value: 'right',
                              label: 'Right',
                            ),
                          ],
                          selected: _textJustify,
                          onSelectionChanged: (value) async {
                            setState(() => _textJustify = value);
                            await _updateLayer();
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text('Rotation: ${_textRotate.toStringAsFixed(0)}°'),
                    subtitle: Slider(
                      value: _textRotate,
                      min: 0.0,
                      max: 360.0,
                      divisions: 72,
                      onChanged: (value) async {
                        setState(() => _textRotate = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Text Position',
                children: [
                  ListTile(
                    title:
                        Text('Offset X: ${_textOffsetX.toStringAsFixed(1)} em'),
                    subtitle: Slider(
                      value: _textOffsetX,
                      min: -2.0,
                      max: 2.0,
                      divisions: 40,
                      onChanged: (value) async {
                        setState(() => _textOffsetX = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                  ListTile(
                    title:
                        Text('Offset Y: ${_textOffsetY.toStringAsFixed(1)} em'),
                    subtitle: Slider(
                      value: _textOffsetY,
                      min: -2.0,
                      max: 2.0,
                      divisions: 40,
                      onChanged: (value) async {
                        setState(() => _textOffsetY = value);
                        await _updateLayer();
                      },
                    ),
                  ),
                ],
              ),
              ControlGroup(
                title: 'Symbol Behavior',
                children: [
                  SwitchListTile(
                    title: const Text('Allow Overlap'),
                    subtitle: const Text('Allow symbols to overlap'),
                    value: _textAllowOverlap,
                    onChanged: (value) async {
                      setState(() => _textAllowOverlap = value);
                      await _updateLayer();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Ignore Placement'),
                    subtitle: const Text('Ignore collision detection'),
                    value: _textIgnorePlacement,
                    onChanged: (value) async {
                      setState(() => _textIgnorePlacement = value);
                      await _updateLayer();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Avoid Edges'),
                    subtitle: const Text('Keep symbols from map edges'),
                    value: _symbolAvoidEdges,
                    onChanged: (value) async {
                      setState(() => _symbolAvoidEdges = value);
                      await _updateLayer();
                    },
                  ),
                  ListTile(
                    title: const Text('Placement Type'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Point or line placement'),
                        const SizedBox(height: 8),
                        ExampleSegmentedButton<String>(
                          segments: const [
                            ExampleSegment(
                              value: 'point',
                              label: 'Point',
                            ),
                            ExampleSegment(
                              value: 'line',
                              label: 'Line',
                            ),
                          ],
                          selected: _symbolPlacement,
                          onSelectionChanged: (value) async {
                            setState(() => _symbolPlacement = value);
                            await _updateLayer();
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_symbolPlacement == 'line')
                    ListTile(
                      title: Text(
                          'Symbol Spacing: ${_symbolSpacing.toStringAsFixed(0)} px'),
                      subtitle: Slider(
                        value: _symbolSpacing,
                        min: 50.0,
                        max: 500.0,
                        divisions: 45,
                        onChanged: (value) async {
                          setState(() => _symbolSpacing = value);
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
                        // Icon properties
                        _showIcon = true;
                        _iconSize = 1.0;
                        _iconRotate = 0.0;
                        _iconOffsetX = 0.0;
                        _iconOffsetY = -1.5;
                        _iconAllowOverlap = false;
                        _iconIgnorePlacement = false;
                        // Text properties
                        _textSize = 14.0;
                        _textColor = const Color(0xFF2C3E50);
                        _textOpacity = 1.0;
                        _textHaloWidth = 2.0;
                        _textHaloColor = Colors.white;
                        _textHaloBlur = 1.0;
                        _textRotate = 0.0;
                        _textOffsetX = 0.0;
                        _textOffsetY = 0.0;
                        _textAnchor = 'center';
                        _textJustify = 'center';
                        _textAllowOverlap = false;
                        _textIgnorePlacement = false;
                        _symbolPlacement = 'point';
                        _symbolSpacing = 250.0;
                        _symbolAvoidEdges = false;
                      });
                      await _updateLayer();
                    },
                  ),
                ],
              ),
            ],
    );
  }

  Future<void> _pickColor(bool isTextColor) async {
    final currentColor = isTextColor ? _textColor : _textHaloColor;
    final title = isTextColor ? 'Select Text Color' : 'Select Halo Color';

    final selectedColor = await ColorPickerModal.show(
      context: context,
      title: title,
      currentColor: currentColor,
    );

    if (selectedColor != null) {
      setState(() {
        if (isTextColor) {
          _textColor = selectedColor;
        } else {
          _textHaloColor = selectedColor;
        }
      });
      await _updateLayer();
    }
  }
}
