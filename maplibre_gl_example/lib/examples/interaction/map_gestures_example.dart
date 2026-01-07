import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating gesture and interaction configuration
class MapGesturesExample extends ExamplePage {
  const MapGesturesExample({super.key})
      : super(
          const Icon(Icons.touch_app),
          'Map Gestures',
          category: ExampleCategory.interaction,
        );

  @override
  Widget build(BuildContext context) => const _MapGesturesBody();
}

class _MapGesturesBody extends StatefulWidget {
  const _MapGesturesBody();

  @override
  State<_MapGesturesBody> createState() => _MapGesturesBodyState();
}

class _MapGesturesBodyState extends State<_MapGesturesBody> {
  MapLibreMapController? _controller;

  // Gesture Settings
  bool _rotateGesturesEnabled = true;
  bool _scrollGesturesEnabled = true;
  bool _tiltGesturesEnabled = true;
  bool _zoomGesturesEnabled = true;
  bool _doubleClickToZoomEnabled = true;

  // Movement State
  bool _isMoving = false;
  String _lastGesture = 'None';

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.addListener(_onMapChanged);
  }

  void _onMapChanged() {
    final moving = _controller?.isCameraMoving ?? false;
    if (mounted && moving != _isMoving) {
      setState(() {
        _isMoving = moving;
        if (moving) {
          _lastGesture = 'Camera moving...';
        }
      });
    }
  }

  void _onCameraIdle() {
    if (mounted) {
      setState(() => _lastGesture = 'Camera idle');
    }
  }

  void _onMapClick(math.Point<double> point, LatLng coordinates) {
    setState(() => _lastGesture = 'Map clicked');
  }

  void _onMapLongClick(math.Point<double> point, LatLng coordinates) {
    setState(() => _lastGesture = 'Map long pressed');
  }

  Future<void> _updateRotateGestures(bool enabled) async {
    setState(() => _rotateGesturesEnabled = enabled);
  }

  Future<void> _updateScrollGestures(bool enabled) async {
    setState(() => _scrollGesturesEnabled = enabled);
  }

  Future<void> _updateTiltGestures(bool enabled) async {
    setState(() => _tiltGesturesEnabled = enabled);
  }

  Future<void> _updateZoomGestures(bool enabled) async {
    setState(() => _zoomGesturesEnabled = enabled);
  }

  Future<void> _updateDoubleClickZoom(bool enabled) async {
    setState(() => _doubleClickToZoomEnabled = enabled);
  }

  Future<void> _enableAllGestures() async {
    setState(() {
      _rotateGesturesEnabled = true;
      _scrollGesturesEnabled = true;
      _tiltGesturesEnabled = true;
      _zoomGesturesEnabled = true;
      _doubleClickToZoomEnabled = true;
    });
  }

  Future<void> _disableAllGestures() async {
    setState(() {
      _rotateGesturesEnabled = false;
      _scrollGesturesEnabled = false;
      _tiltGesturesEnabled = false;
      _zoomGesturesEnabled = false;
      _doubleClickToZoomEnabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onMapClick: _onMapClick,
        onMapLongClick: _onMapLongClick,
        onCameraIdle: _onCameraIdle,
        initialCameraPosition: ExampleConstants.defaultCameraPosition,
        trackCameraPosition: true,
        rotateGesturesEnabled: _rotateGesturesEnabled,
        scrollGesturesEnabled: _scrollGesturesEnabled,
        tiltGesturesEnabled: _tiltGesturesEnabled,
        zoomGesturesEnabled: _zoomGesturesEnabled,
        doubleClickZoomEnabled: _doubleClickToZoomEnabled,
      ),
      controls: [
        InfoCard(
          title: 'Gesture Status',
          subtitle: _lastGesture,
          icon: _isMoving ? Icons.touch_app : Icons.check_circle,
          color: _isMoving ? Colors.blue.shade100 : Colors.green.shade100,
        ),
        ControlGroup(
          title: 'Quick Actions',
          children: [
            ExampleButton(
              label: 'Enable All',
              icon: Icons.check_circle,
              onPressed: _enableAllGestures,
              style: ExampleButtonStyle.filled,
            ),
            ExampleButton(
              label: 'Disable All',
              icon: Icons.block,
              onPressed: _disableAllGestures,
              style: ExampleButtonStyle.destructive,
            ),
          ],
        ),
        ControlGroup(
          title: 'Gesture Settings',
          vertical: false,
          children: [
            SwitchListTile(
              title: const Text('Rotate Gestures'),
              subtitle: const Text('Two-finger rotation'),
              value: _rotateGesturesEnabled,
              onChanged: _updateRotateGestures,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Scroll Gestures'),
              subtitle: const Text('Pan to move map'),
              value: _scrollGesturesEnabled,
              onChanged: _updateScrollGestures,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Tilt Gestures'),
              subtitle: const Text('Two-finger tilt/pitch'),
              value: _tiltGesturesEnabled,
              onChanged: _updateTiltGestures,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Zoom Gestures'),
              subtitle: const Text('Pinch to zoom'),
              value: _zoomGesturesEnabled,
              onChanged: _updateZoomGestures,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Double-Click Zoom'),
              subtitle: const Text('Double tap to zoom in'),
              value: _doubleClickToZoomEnabled,
              onChanged: _updateDoubleClickZoom,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onMapChanged);
    super.dispose();
  }
}
