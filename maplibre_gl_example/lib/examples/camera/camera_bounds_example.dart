import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating camera bounds and constraints
class CameraBoundsExample extends ExamplePage {
  const CameraBoundsExample({super.key})
      : super(
          const Icon(Icons.crop),
          'Camera Bounds & Constraints',
          category: ExampleCategory.camera,
        );

  @override
  Widget build(BuildContext context) => const _CameraBoundsBody();
}

class _CameraBoundsBody extends StatefulWidget {
  const _CameraBoundsBody();

  @override
  State<_CameraBoundsBody> createState() => _CameraBoundsBodyState();
}

class _CameraBoundsBodyState extends State<_CameraBoundsBody> {
  MapLibreMapController? _controller;
  LatLngBounds? _currentBounds;
  double? _minZoom;
  double? _maxZoom;

  // Predefined bounds
  static final _sydneyBounds = LatLngBounds(
    southwest: const LatLng(-34.022631, 150.620685),
    northeast: const LatLng(-33.571835, 151.325952),
  );

  static final _sanFranciscoBounds = LatLngBounds(
    southwest: const LatLng(37.7, -122.5),
    northeast: const LatLng(37.8, -122.4),
  );

  static final _europeBounds = LatLngBounds(
    southwest: const LatLng(36.0, -10.0),
    northeast: const LatLng(71.0, 40.0),
  );

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
    await _updateInfo();
  }

  Future<void> _updateInfo() async {
    if (_controller == null) return;
    final bounds = await _controller!.getVisibleRegion();
    if (mounted) {
      setState(() => _currentBounds = bounds);
    }
  }

  Future<void> _setBounds(LatLngBounds bounds, String name) async {
    if (_controller == null) return;

    await _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: 50,
        top: 50,
        right: 50,
        bottom: 50,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera moved to $name bounds'),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    _updateInfo();
  }

  Future<void> _setMinZoom(double zoom) async {
    if (_controller == null) return;
    // Note: min/max zoom can be set via style, initial confing or options.
    setState(() => _minZoom = zoom);
  }

  Future<void> _setMaxZoom(double zoom) async {
    if (_controller == null) return;
    setState(() => _maxZoom = zoom);
  }

  Future<void> _clearZoomConstraints() async {
    if (_controller == null) return;
    setState(() {
      _minZoom = null;
      _maxZoom = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasController = _controller != null;
    final boundsInfo = _currentBounds != null
        ? 'SW: ${_currentBounds!.southwest.latitude.toStringAsFixed(2)}, ${_currentBounds!.southwest.longitude.toStringAsFixed(2)}\n'
            'NE: ${_currentBounds!.northeast.latitude.toStringAsFixed(2)}, ${_currentBounds!.northeast.longitude.toStringAsFixed(2)}'
        : 'Loading...';

    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onCameraIdle: _updateInfo,
        trackCameraPosition: true,
        initialCameraPosition: ExampleConstants.defaultCameraPosition,
        minMaxZoomPreference: MinMaxZoomPreference(_minZoom, _maxZoom),
      ),
      controls: [
        InfoCard(
          title: 'Visible Bounds',
          subtitle: boundsInfo,
          icon: Icons.crop,
        ),
        if (_minZoom != null || _maxZoom != null)
          InfoCard(
            title: 'Zoom Constraints',
            subtitle:
                'Min: ${_minZoom?.toStringAsFixed(0) ?? "None"} | Max: ${_maxZoom?.toStringAsFixed(0) ?? "None"}',
            icon: Icons.lock,
            color: Colors.orange.shade100,
          ),
        const SizedBox(height: 8),
        ControlGroup(
          title: 'Move to Bounds',
          children: [
            ExampleButton(
              label: 'Sydney',
              icon: Icons.map,
              onPressed: hasController
                  ? () => _setBounds(_sydneyBounds, 'Sydney')
                  : null,
            ),
            ExampleButton(
              label: 'San Francisco',
              icon: Icons.map,
              onPressed: hasController
                  ? () => _setBounds(_sanFranciscoBounds, 'San Francisco')
                  : null,
            ),
            ExampleButton(
              label: 'Europe',
              icon: Icons.map,
              onPressed: hasController
                  ? () => _setBounds(_europeBounds, 'Europe')
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ControlGroup(
          title: 'Zoom Limits',
          children: [
            ExampleButton(
              label: 'Min Zoom: 3',
              icon: Icons.zoom_out,
              onPressed: hasController ? () => _setMinZoom(3) : null,
              style: ExampleButtonStyle.tonal,
            ),
            ExampleButton(
              label: 'Max Zoom: 8',
              icon: Icons.zoom_in,
              onPressed: hasController ? () => _setMaxZoom(8) : null,
              style: ExampleButtonStyle.tonal,
            ),
            ExampleButton(
              label: 'Clear Limits',
              icon: Icons.lock_open,
              onPressed: hasController && (_minZoom != null || _maxZoom != null)
                  ? _clearZoomConstraints
                  : null,
              style: ExampleButtonStyle.outlined,
            ),
          ],
        ),
      ],
    );
  }
}
