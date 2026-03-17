import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math' show Point, Random;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/util.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating interactive style layer editing with draggable features
class EditStyleLayerDraggableExample extends ExamplePage {
  const EditStyleLayerDraggableExample({super.key})
      : super(
          const Icon(Icons.pan_tool),
          'Edit Style Layer (Draggable)',
          category: ExampleCategory.layers,
        );

  @override
  Widget build(BuildContext context) => const _EditStyleLayerDraggableBody();
}

class _EditStyleLayerDraggableBody extends StatefulWidget {
  const _EditStyleLayerDraggableBody();

  @override
  State<_EditStyleLayerDraggableBody> createState() =>
      _EditStyleLayerDraggableBodyState();
}

class _EditStyleLayerDraggableBodyState
    extends State<_EditStyleLayerDraggableBody> {
  MapLibreMapController? _controller;

  static const _circleSourceId = 'draggable_circle_source';
  static const _circleLayerId = 'draggable_circle_layer';
  static const _symbolSourceId = 'draggable_symbol_source';
  static const _symbolLayerId = 'draggable_symbol_layer';

  final List<Map<String, dynamic>> _circleFeatures = [];
  final List<Map<String, dynamic>> _symbolFeatures = [];

  String? _draggedFeatureId;
  DragEventType? _lastDragEvent;
  LatLng? _dragStartPosition;
  LatLng? _dragCurrentPosition;

  int _featureCounter = 0;
  bool _layersCreated = false;

  void _onMapCreated(MapLibreMapController controller) {
    controller.onFeatureDrag.add(_onFeatureDrag);
    setState(() => _controller = controller);
  }

  void _onFeatureDrag(
    Point<double> point,
    LatLng origin,
    LatLng current,
    LatLng delta,
    String id,
    Annotation? annotation,
    DragEventType eventType,
  ) {
    dev.log(
      'Feature dragged: $id, '
      'type: ${eventType.name}, '
      'origin: ${origin.latitude},${origin.longitude}, '
      'current: ${current.latitude},${current.longitude}',
    );

    setState(() {
      _draggedFeatureId = id;
      _lastDragEvent = eventType;

      if (_lastDragEvent == DragEventType.start) {
        _dragStartPosition = origin;
      }
      _dragCurrentPosition = current;

      // Update the feature position in real-time
      if (_lastDragEvent == DragEventType.drag ||
          _lastDragEvent == DragEventType.end) {
        unawaited(_updateFeaturePosition(id, current));
      }

      if (_lastDragEvent == DragEventType.end) {
        // Clear drag info after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _draggedFeatureId = null;
              _lastDragEvent = null;
              _dragStartPosition = null;
              _dragCurrentPosition = null;
            });
          }
        });
      }
    });
  }

  Future<void> _updateFeaturePosition(String id, LatLng position) async {
    if (_controller == null) return;

    // Update circle feature
    final circleIndex = _circleFeatures.indexWhere(
      (f) => f['properties']['id'] == id,
    );
    if (circleIndex != -1) {
      _circleFeatures[circleIndex]['geometry']['coordinates'] = [
        position.longitude,
        position.latitude,
      ];
      await _updateCircleSource();
      return;
    }

    // Update symbol feature
    final symbolIndex = _symbolFeatures.indexWhere(
      (f) => f['properties']['id'] == id,
    );
    if (symbolIndex != -1) {
      _symbolFeatures[symbolIndex]['geometry']['coordinates'] = [
        position.longitude,
        position.latitude,
      ];
      await _updateSymbolSource();
      return;
    }
  }

  Future<void> _onStyleLoaded() async {
    await addImageFromAsset(
      _controller!,
      "custom-marker",
      "assets/symbols/custom-marker.png",
    );
    await _createLayers();

    await _controller!.setSymbolIconAllowOverlap(true);
    await _controller!.setSymbolTextAllowOverlap(true);
  }

  Future<void> _createLayers() async {
    if (_controller == null || _layersCreated) return;

    try {
      // Create circle layer
      await _controller!.addGeoJsonSource(
        _circleSourceId,
        {
          'type': 'FeatureCollection',
          'features': [],
        },
        promoteId: 'id',
      );

      await _controller!.addCircleLayer(
        _circleSourceId,
        _circleLayerId,
        const CircleLayerProperties(
          circleRadius: 25,
          circleColor: '#3498DB',
          circleOpacity: 0.8,
          circleStrokeWidth: 2,
          circleStrokeColor: '#2C3E50',
        ),
        enableInteraction: true,
      );

      // Create symbol layer
      await _controller!.addGeoJsonSource(
        _symbolSourceId,
        {
          'type': 'FeatureCollection',
          'features': [],
        },
        promoteId: 'id',
      );

      await _controller!.addSymbolLayer(
        _symbolSourceId,
        _symbolLayerId,
        const SymbolLayerProperties(
          iconImage: 'custom-marker',
          iconSize: 1.2,
          iconAllowOverlap: true,
          textField: '{name}',
          textSize: 12,
          textOffset: [0, -2.5],
          textColor: '#2C3E50',
          textHaloWidth: 2,
          textHaloColor: '#FFFFFF',
          textAllowOverlap: true,
        ),
        enableInteraction: true,
      );

      setState(() => _layersCreated = true);
    } catch (e) {
      dev.log('Error creating layers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating layers: $e')),
        );
      }
    }
  }

  Future<void> _addCircleFeature() async {
    if (_controller == null || !_layersCreated) return;

    const center = ExampleConstants.sydneyCenter;
    final random = Random();
    final id = 'circle_${_featureCounter++}';

    final feature = {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'Point',
        'coordinates': [
          center.longitude + (random.nextDouble() - 0.5) * 0.02,
          center.latitude + (random.nextDouble() - 0.5) * 0.02,
        ],
      },
      'properties': {
        'id': id,
        'name': id,
        'type': 'circle',
        // NOTE: Make the feature draggable
        'draggable': true,
      },
    };

    _circleFeatures.add(feature);
    await _updateCircleSource();
  }

  Future<void> _addSymbolFeature() async {
    if (_controller == null || !_layersCreated) return;

    const center = ExampleConstants.sydneyCenter;
    final random = Random();
    final id = 'symbol_${_featureCounter++}';

    final feature = {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'Point',
        'coordinates': [
          center.longitude + (random.nextDouble() - 0.5) * 0.02,
          center.latitude + (random.nextDouble() - 0.5) * 0.02,
        ],
      },
      'properties': {
        'id': id,
        'name': id,
        'type': 'symbol',
        // NOTE: Make the feature draggable
        'draggable': true,
      },
    };

    _symbolFeatures.add(feature);
    await _updateSymbolSource();
  }

  Future<void> _updateCircleSource() async {
    if (_controller == null) return;

    await _controller!.setGeoJsonSource(
      _circleSourceId,
      {
        'type': 'FeatureCollection',
        'features': _circleFeatures,
      },
    );
  }

  Future<void> _updateSymbolSource() async {
    if (_controller == null) return;

    await _controller!.setGeoJsonSource(
      _symbolSourceId,
      {
        'type': 'FeatureCollection',
        'features': _symbolFeatures,
      },
    );
  }

  Future<void> _clearAll() async {
    if (_controller == null) return;

    setState(() {
      _circleFeatures.clear();
      _symbolFeatures.clear();
    });

    await _updateCircleSource();
    await _updateSymbolSource();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 4.0),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLatLng(LatLng? latLng) {
    if (latLng == null) return 'N/A';
    return '${latLng.latitude.toStringAsFixed(5)}, '
        '${latLng.longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasController = _controller != null && _layersCreated;
    final totalFeatures = _circleFeatures.length + _symbolFeatures.length;

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
      controls: [_buildControls(hasController, totalFeatures)],
    );
  }

  Widget _buildControls(bool hasController, int totalFeatures) {
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
                  'Edit Style Layer (Draggable)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add draggable features to style layers using GeoJSON sources. '
                  'Features can be moved and their positions are updated in the source.',
                ),
              ],
            ),
          ),
        ),
        if (_draggedFeatureId != null && _lastDragEvent != null)
          Card(
            margin: const EdgeInsets.all(ExampleConstants.paddingStandard),
            color: _lastDragEvent == DragEventType.start
                ? Colors.green.shade50
                : _lastDragEvent == DragEventType.drag
                    ? Colors.blue.shade50
                    : Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(ExampleConstants.paddingStandard),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _lastDragEvent == DragEventType.start
                            ? Icons.touch_app
                            : _lastDragEvent == DragEventType.drag
                                ? Icons.pan_tool
                                : Icons.check_circle,
                        color: _lastDragEvent == DragEventType.start
                            ? Colors.green
                            : _lastDragEvent == DragEventType.drag
                                ? Colors.blue
                                : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Drag Event: ${_lastDragEvent!.name.toUpperCase()}',
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  _buildInfoRow('Feature', _draggedFeatureId ?? 'N/A'),
                  if (_dragStartPosition != null)
                    _buildInfoRow('Start', _formatLatLng(_dragStartPosition)),
                  if (_dragCurrentPosition != null)
                    _buildInfoRow(
                      'Current',
                      _formatLatLng(_dragCurrentPosition),
                    ),
                ],
              ),
            ),
          ),
        ControlGroup(
          title: 'Add Draggable Features',
          children: [
            ExampleButton(
              label: 'Add Circle',
              icon: Icons.circle,
              onPressed: hasController ? _addCircleFeature : null,
            ),
            ExampleButton(
              label: 'Add Symbol',
              icon: Icons.place,
              onPressed: hasController ? _addSymbolFeature : null,
            ),
          ],
        ),
        ControlGroup(
          title: 'Actions',
          children: [
            ExampleButton(
              label: 'Clear All',
              icon: Icons.clear,
              onPressed: hasController && totalFeatures > 0 ? _clearAll : null,
              style: ExampleButtonStyle.destructive,
            ),
          ],
        ),
      ],
    );
  }
}
