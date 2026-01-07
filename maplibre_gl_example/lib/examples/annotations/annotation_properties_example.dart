import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/util.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating dynamic annotation property updates
class AnnotationPropertiesExample extends ExamplePage {
  const AnnotationPropertiesExample({super.key})
      : super(
          const Icon(Icons.tune),
          'Annotation Properties',
          category: ExampleCategory.annotations,
        );

  @override
  Widget build(BuildContext context) => const _AnnotationPropertiesBody();
}

enum PropertyAnnotationType { symbol, circle, fill, line }

class _AnnotationPropertiesBody extends StatefulWidget {
  const _AnnotationPropertiesBody();

  @override
  State<_AnnotationPropertiesBody> createState() =>
      _AnnotationPropertiesBodyState();
}

class _AnnotationPropertiesBodyState extends State<_AnnotationPropertiesBody> {
  MapLibreMapController? _controller;
  PropertyAnnotationType _currentType = PropertyAnnotationType.symbol;

  // Single annotation of each type
  Symbol? _symbol;
  Circle? _circle;
  Fill? _fill;
  Line? _line;

  // Symbol properties
  double _iconSize = 2.0;
  double _iconRotate = 0.0;
  double _textSize = 12.0;
  String _textField = 'Symbol';

  // Circle properties
  double _circleRadius = 20.0;
  double _circleOpacity = 0.8;
  double _circleStrokeWidth = 2.0;
  String _circleColor = '#3498DB';

  // Fill properties
  double _fillOpacity = 0.6;
  String _fillColor = '#E74C3C';
  String _fillOutlineColor = '#C0392B';

  // Line properties
  double _lineWidth = 4.0;
  double _lineOpacity = 0.9;
  String _lineColor = '#2ECC71';
  double _lineBlur = 0.0;

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  Future<void> _onStyleLoaded() async {
    await _addInitialAnnotations();
  }

  Future<void> _addInitialAnnotations() async {
    if (_controller == null) return;

    try {
      await addImageFromAsset(
        _controller!,
        "custom-marker",
        "assets/symbols/custom-marker.png",
      );

      const center = ExampleConstants.sydneyCenter;

      // Add one of each annotation type at different positions
      _symbol = await _controller!.addSymbol(
        SymbolOptions(
          geometry: LatLng(center.latitude + 0.15, center.longitude),
          iconImage: 'custom-marker',
          iconSize: _iconSize,
          iconRotate: _iconRotate,
          textField: _textField,
          textSize: _textSize,
          textOffset: const Offset(0, 2),
        ),
      );

      _circle = await _controller!.addCircle(
        CircleOptions(
          geometry: LatLng(center.latitude + 0.05, center.longitude),
          circleRadius: _circleRadius,
          circleColor: _circleColor,
          circleOpacity: _circleOpacity,
          circleStrokeWidth: _circleStrokeWidth,
          circleStrokeColor: '#FFFFFF',
        ),
      );

      _fill = await _controller!.addFill(
        FillOptions(
          geometry: [
            _generatePolygon(
              LatLng(center.latitude - 0.05, center.longitude),
            )
          ],
          fillColor: _fillColor,
          fillOpacity: _fillOpacity,
          fillOutlineColor: _fillOutlineColor,
        ),
      );

      _line = await _controller!.addLine(
        LineOptions(
          geometry: _generateLineString(
            LatLng(center.latitude - 0.15, center.longitude),
          ),
          lineColor: _lineColor,
          lineWidth: _lineWidth,
          lineOpacity: _lineOpacity,
          lineBlur: _lineBlur,
        ),
      );

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding annotations: $e')),
        );
      }
    }
  }

  List<LatLng> _generatePolygon(LatLng center) {
    final points = <LatLng>[];
    const size = 0.025;
    points.add(LatLng(center.latitude - size, center.longitude - size));
    points.add(LatLng(center.latitude - size, center.longitude + size));
    points.add(LatLng(center.latitude + size, center.longitude + size));
    points.add(LatLng(center.latitude + size, center.longitude - size));
    points.add(LatLng(center.latitude - size, center.longitude - size));
    return points;
  }

  List<LatLng> _generateLineString(LatLng center) {
    final points = <LatLng>[];
    const step = 0.02;
    for (var i = 0; i < 5; i++) {
      points.add(LatLng(
        center.latitude + (i * step * 0.3),
        center.longitude - (step * 2) + (i * step),
      ));
    }
    return points;
  }

  Future<void> _updateSymbolProperties() async {
    if (_controller == null || _symbol == null) return;

    try {
      await _controller!.updateSymbol(
        _symbol!,
        SymbolOptions(
          iconSize: _iconSize,
          iconRotate: _iconRotate,
          textField: _textField,
          textSize: _textSize,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating symbol: $e')),
        );
      }
    }
  }

  Future<void> _updateCircleProperties() async {
    if (_controller == null || _circle == null) return;

    try {
      await _controller!.updateCircle(
        _circle!,
        CircleOptions(
          circleRadius: _circleRadius,
          circleColor: _circleColor,
          circleOpacity: _circleOpacity,
          circleStrokeWidth: _circleStrokeWidth,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating circle: $e')),
        );
      }
    }
  }

  Future<void> _updateFillProperties() async {
    if (_controller == null || _fill == null) return;

    try {
      await _controller!.updateFill(
        _fill!,
        FillOptions(
          fillColor: _fillColor,
          fillOpacity: _fillOpacity,
          fillOutlineColor: _fillOutlineColor,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating fill: $e')),
        );
      }
    }
  }

  Future<void> _updateLineProperties() async {
    if (_controller == null || _line == null) return;

    try {
      await _controller!.updateLine(
        _line!,
        LineOptions(
          lineColor: _lineColor,
          lineWidth: _lineWidth,
          lineOpacity: _lineOpacity,
          lineBlur: _lineBlur,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating line: $e')),
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
          zoom: 9,
        ),
        trackCameraPosition: true,
      ),
      controls: _controller == null
          ? []
          : [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Annotation Type',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ExampleSegmentedButton<PropertyAnnotationType>(
                        segments: const [
                          ExampleSegment(
                            value: PropertyAnnotationType.symbol,
                            label: 'Symbol',
                            icon: Icons.place,
                          ),
                          ExampleSegment(
                            value: PropertyAnnotationType.circle,
                            label: 'Circle',
                            icon: Icons.circle_outlined,
                          ),
                          ExampleSegment(
                            value: PropertyAnnotationType.fill,
                            label: 'Fill',
                            icon: Icons.square,
                          ),
                          ExampleSegment(
                            value: PropertyAnnotationType.line,
                            label: 'Line',
                            icon: Icons.timeline,
                          ),
                        ],
                        selected: _currentType,
                        onSelectionChanged: (type) {
                          setState(() => _currentType = type);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_currentType == PropertyAnnotationType.symbol)
                ..._buildSymbolControls(),
              if (_currentType == PropertyAnnotationType.circle)
                ..._buildCircleControls(),
              if (_currentType == PropertyAnnotationType.fill)
                ..._buildFillControls(),
              if (_currentType == PropertyAnnotationType.line)
                ..._buildLineControls(),
            ],
    );
  }

  List<Widget> _buildSymbolControls() {
    return [
      ControlGroup(
        title: 'Icon Properties',
        children: [
          ListTile(
            title: Text('Icon Size: ${_iconSize.toStringAsFixed(1)}'),
            subtitle: Slider(
              value: _iconSize,
              min: 0.5,
              max: 4.0,
              divisions: 35,
              onChanged: (value) async {
                setState(() => _iconSize = value);
                await _updateSymbolProperties();
              },
            ),
          ),
          ListTile(
            title: Text('Icon Rotation: ${_iconRotate.toStringAsFixed(0)}°'),
            subtitle: Slider(
              value: _iconRotate,
              min: 0.0,
              max: 360.0,
              divisions: 72,
              onChanged: (value) async {
                setState(() => _iconRotate = value);
                await _updateSymbolProperties();
              },
            ),
          ),
        ],
      ),
      ControlGroup(
        title: 'Text Properties',
        children: [
          ListTile(
            title: const Text('Text Content'),
            subtitle: TextField(
              controller: TextEditingController(text: _textField)
                ..selection =
                    TextSelection.collapsed(offset: _textField.length),
              onChanged: (value) async {
                setState(() => _textField = value);
                await _updateSymbolProperties();
              },
              decoration: const InputDecoration(
                hintText: 'Enter text',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          ListTile(
            title: Text('Text Size: ${_textSize.toStringAsFixed(1)}'),
            subtitle: Slider(
              value: _textSize,
              min: 8.0,
              max: 24.0,
              divisions: 32,
              onChanged: (value) async {
                setState(() => _textSize = value);
                await _updateSymbolProperties();
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
                _iconSize = 2.0;
                _iconRotate = 0.0;
                _textSize = 12.0;
                _textField = 'Symbol';
              });
              await _updateSymbolProperties();
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildCircleControls() {
    return [
      ControlGroup(
        title: 'Circle Appearance',
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
                await _updateCircleProperties();
              },
            ),
          ),
          ListTile(
            title:
                Text('Opacity: ${(_circleOpacity * 100).toStringAsFixed(0)}%'),
            subtitle: Slider(
              value: _circleOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: (value) async {
                setState(() => _circleOpacity = value);
                await _updateCircleProperties();
              },
            ),
          ),
          ListTile(
            title:
                Text('Stroke Width: ${_circleStrokeWidth.toStringAsFixed(1)}'),
            subtitle: Slider(
              value: _circleStrokeWidth,
              min: 0.0,
              max: 10.0,
              divisions: 20,
              onChanged: (value) async {
                setState(() => _circleStrokeWidth = value);
                await _updateCircleProperties();
              },
            ),
          ),
          ListTile(
            title: const Text('Color'),
            trailing: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Color(int.parse(_circleColor.substring(1), radix: 16) +
                    0xFF000000),
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onTap: () => _pickColor('circle'),
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
                _circleColor = '#3498DB';
              });
              await _updateCircleProperties();
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildFillControls() {
    return [
      ControlGroup(
        title: 'Fill Appearance',
        children: [
          ListTile(
            title: Text('Opacity: ${(_fillOpacity * 100).toStringAsFixed(0)}%'),
            subtitle: Slider(
              value: _fillOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: (value) async {
                setState(() => _fillOpacity = value);
                await _updateFillProperties();
              },
            ),
          ),
          ListTile(
            title: const Text('Fill Color'),
            trailing: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Color(
                    int.parse(_fillColor.substring(1), radix: 16) + 0xFF000000),
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onTap: () => _pickColor('fill'),
          ),
          ListTile(
            title: const Text('Outline Color'),
            trailing: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Color(
                    int.parse(_fillOutlineColor.substring(1), radix: 16) +
                        0xFF000000),
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onTap: () => _pickColor('fillOutline'),
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
                _fillColor = '#E74C3C';
                _fillOutlineColor = '#C0392B';
              });
              await _updateFillProperties();
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildLineControls() {
    return [
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
                await _updateLineProperties();
              },
            ),
          ),
          ListTile(
            title: Text('Opacity: ${(_lineOpacity * 100).toStringAsFixed(0)}%'),
            subtitle: Slider(
              value: _lineOpacity,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: (value) async {
                setState(() => _lineOpacity = value);
                await _updateLineProperties();
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
                await _updateLineProperties();
              },
            ),
          ),
          ListTile(
            title: const Text('Color'),
            trailing: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Color(
                    int.parse(_lineColor.substring(1), radix: 16) + 0xFF000000),
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onTap: () => _pickColor('line'),
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
                _lineColor = '#2ECC71';
                _lineBlur = 0.0;
              });
              await _updateLineProperties();
            },
          ),
        ],
      ),
    ];
  }

  Future<void> _pickColor(String type) async {
    String? currentHexColor;
    switch (type) {
      case 'circle':
        currentHexColor = _circleColor;
      case 'fill':
        currentHexColor = _fillColor;
      case 'fillOutline':
        currentHexColor = _fillOutlineColor;
      case 'line':
        currentHexColor = _lineColor;
    }

    final selectedColor = await ColorPickerModal.showForHex(
      context: context,
      title: 'Select Color',
      currentHexColor: currentHexColor,
    );

    if (selectedColor != null) {
      switch (type) {
        case 'circle':
          setState(() => _circleColor = selectedColor);
          await _updateCircleProperties();
        case 'fill':
          setState(() => _fillColor = selectedColor);
          await _updateFillProperties();
        case 'fillOutline':
          setState(() => _fillOutlineColor = selectedColor);
          await _updateFillProperties();
        case 'line':
          setState(() => _lineColor = selectedColor);
          await _updateLineProperties();
      }
    }
  }
}
