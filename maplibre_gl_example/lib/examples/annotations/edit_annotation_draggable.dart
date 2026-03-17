import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/util.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating draggable annotations with interactive editing
class EditAnnotationDraggableExample extends ExamplePage {
  const EditAnnotationDraggableExample({super.key})
      : super(
          const Icon(Icons.pan_tool),
          'Edit Annotation (Draggable)',
          category: ExampleCategory.annotations,
        );

  @override
  Widget build(BuildContext context) => const _EditAnnotationDraggableBody();
}

class _EditAnnotationDraggableBody extends StatefulWidget {
  const _EditAnnotationDraggableBody();

  @override
  State<_EditAnnotationDraggableBody> createState() =>
      _EditAnnotationDraggableBodyState();
}

class _EditAnnotationDraggableBodyState
    extends State<_EditAnnotationDraggableBody> {
  MapLibreMapController? _controller;

  final Map<String, Symbol> _symbols = {};
  final Map<String, Circle> _circles = {};
  final Map<String, Fill> _fills = {};

  String? _draggedAnnotationId;
  DragEventType? _lastDragEvent;
  LatLng? _dragStartPosition;
  LatLng? _dragCurrentPosition;

  int _counter = 0;

  void _onMapCreated(MapLibreMapController controller) {
    controller.onFeatureDrag.add(_onFeatureDrag);
    setState(() => _controller = controller);
  }

  void _onFeatureDrag(
    math.Point<double> point,
    LatLng origin,
    LatLng current,
    LatLng delta,
    String id,
    Annotation? annotation,
    DragEventType eventType,
  ) {
    setState(() {
      _draggedAnnotationId = id;
      _lastDragEvent = eventType;

      if (_lastDragEvent == DragEventType.start) {
        _dragStartPosition = origin;
      }
      _dragCurrentPosition = current;

      if (_lastDragEvent == DragEventType.end) {
        // Clear drag info after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _draggedAnnotationId = null;
              _lastDragEvent = null;
              _dragStartPosition = null;
              _dragCurrentPosition = null;
            });
          }
        });
      }
    });
  }

  Future<void> _onStyleLoaded() async {
    await addImageFromAsset(
      _controller!,
      "custom-marker",
      "assets/symbols/custom-marker.png",
    );
  }

  Future<void> _addSymbol() async {
    if (_controller == null) return;

    const center = ExampleConstants.sydneyCenter;
    final id = 'symbol_${_counter++}';

    final symbol = await _controller!.addSymbol(
      SymbolOptions(
        geometry: LatLng(
          center.latitude + (_counter * 0.003),
          center.longitude + (_counter * 0.003),
        ),
        iconImage: 'custom-marker',
        iconSize: 1.0,
        textField: id,
        textSize: 12,
        textOffset: const Offset(0, -2),
        draggable: true,
      ),
    );

    await _controller!.setSymbolIconAllowOverlap(true);
    await _controller!.setSymbolTextAllowOverlap(true);

    setState(() => _symbols[id] = symbol);
  }

  Future<void> _addCircle() async {
    if (_controller == null) return;

    const center = ExampleConstants.sydneyCenter;
    final id = 'circle_${_counter++}';

    final circle = await _controller!.addCircle(
      CircleOptions(
        geometry: LatLng(
          center.latitude - (_counter * 0.003),
          center.longitude + (_counter * 0.003),
        ),
        circleRadius: 20,
        circleColor: '#3498DB',
        circleOpacity: 0.8,
        draggable: true,
      ),
    );

    setState(() => _circles[id] = circle);
  }

  Future<void> _clearAll() async {
    if (_controller == null) return;

    await _controller!.clearSymbols();
    await _controller!.clearCircles();
    await _controller!.clearFills();

    setState(() {
      _symbols.clear();
      _circles.clear();
      _fills.clear();
      _draggedAnnotationId = null;
      _lastDragEvent = null;
      _dragStartPosition = null;
      _dragCurrentPosition = null;
    });
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
    final hasController = _controller != null;
    final totalCount = _symbols.length + _circles.length + _fills.length;

    return MapExampleScaffold(
      map: MapLibreMap(
        initialCameraPosition: const CameraPosition(
          target: ExampleConstants.sydneyCenter,
          zoom: 14,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        styleString: ExampleConstants.localStyleAsset,
      ),
      controls: [_buildControls(hasController, totalCount)],
    );
  }

  Widget _buildControls(bool hasController, int totalCount) {
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
                  'Edit Annotation (Draggable)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add draggable annotations and move them around. '
                  'Drag events are captured and displayed below.',
                ),
              ],
            ),
          ),
        ),
        if (_draggedAnnotationId != null && _lastDragEvent != null)
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
                  _buildInfoRow('Annotation', _draggedAnnotationId ?? 'N/A'),
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
          title: 'Add Draggable Annotations',
          children: [
            ExampleButton(
              label: 'Add Symbol',
              icon: Icons.place,
              onPressed: hasController ? _addSymbol : null,
            ),
            ExampleButton(
              label: 'Add Circle',
              icon: Icons.circle,
              onPressed: hasController ? _addCircle : null,
            ),
          ],
        ),
        ControlGroup(
          title: 'Actions',
          children: [
            ExampleButton(
              label: 'Clear All',
              icon: Icons.clear,
              onPressed: hasController && totalCount > 0 ? _clearAll : null,
              style: ExampleButtonStyle.destructive,
            ),
          ],
        ),
      ],
    );
  }
}
