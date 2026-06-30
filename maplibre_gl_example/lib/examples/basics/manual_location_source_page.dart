import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating an app-provided (manual) location source.
///
/// The user-location puck is fed by `controller.updateManualLocation(...)`
/// instead of the device's location engine. This is useful when the location
/// comes from an external source (a paired GPS device, a replayed track, a
/// backend, a simulation, ...). No location permission is required.
///
/// The tracking mode and the reported horizontal accuracy (the accuracy ring)
/// can be changed at runtime from the controls below.
///
/// Not supported on web — there `updateManualLocation` throws an
/// [UnsupportedError].
class ManualLocationSourcePage extends ExamplePage {
  const ManualLocationSourcePage({super.key})
    : super(
        const Icon(Icons.edit_location_alt),
        'Manual Location Source',
        needsLocationPermission: false,
        category: ExampleCategory.basics,
      );

  @override
  Widget build(BuildContext context) => const _ManualLocationSourceBody();
}

class _ManualLocationSourceBody extends StatefulWidget {
  const _ManualLocationSourceBody();

  @override
  State<_ManualLocationSourceBody> createState() =>
      _ManualLocationSourceBodyState();
}

class _ManualLocationSourceBodyState extends State<_ManualLocationSourceBody> {
  // Center of the simulated loop (Cupertino, CA).
  static const LatLng _center = LatLng(37.33233141, -122.0312186);
  static const double _radiusDeg = 0.0015;

  MapLibreMapController? _controller;
  Timer? _timer;
  bool _simulating = false;

  // Current simulated fix. Kept in state so the accuracy slider can re-emit at
  // the same position without advancing the track.
  double _angle = 0; // radians around the loop
  LatLng _position = LatLng(
    _center.latitude + _radiusDeg,
    _center.longitude,
  );
  double _bearing = 0;
  bool _started = false;

  // Live-controllable parameters.
  double _accuracy = 8; // meters (horizontal accuracy / ring radius)
  MyLocationTrackingMode _trackingMode = MyLocationTrackingMode.trackingGps;
  // Defaults to `normal` so the accuracy ring is visible. On Android the `gps`
  // render mode draws the navigation arrow but intentionally hides the accuracy
  // ring (see the note in the UI / the `RenderMode.GPS` branch in the SDK).
  MyLocationRenderMode _renderMode = MyLocationRenderMode.normal;

  UserLocation? _lastUpdate;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  void _onUserLocationUpdated(UserLocation location) {
    if (mounted) {
      setState(() => _lastUpdate = location);
    }
  }

  static double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Pushes the current fix (position/bearing/accuracy) into the puck.
  Future<void> _push() async {
    final controller = _controller;
    if (controller == null) return;
    _started = true;
    await controller.updateManualLocation(
      ManualLocationUpdate(
        target: _position,
        bearing: _bearing,
        speed: _simulating ? 4.2 : 0,
        altitude: 16,
        horizontalAccuracy: _accuracy,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Advances one step along the circular track, then pushes the new fix.
  Future<void> _step() async {
    _angle += math.pi / 18; // advance 10° each tick
    final next = LatLng(
      _center.latitude + _radiusDeg * math.cos(_angle),
      _center.longitude + _radiusDeg * math.sin(_angle),
    );
    _bearing = _bearingBetween(_position, next); // GPS arrow direction
    _position = next;
    await _push();
  }

  void _toggleSimulation() {
    if (_simulating) {
      _timer?.cancel();
      _timer = null;
      setState(() => _simulating = false);
      return;
    }
    setState(() => _simulating = true);
    unawaited(_step());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_step()),
    );
  }

  void _onAccuracyChanged(double value) {
    setState(() => _accuracy = value);
    // Re-emit the current fix so the accuracy ring updates live (only once a
    // location has actually been pushed, so the puck doesn't appear early).
    if (_started) {
      unawaited(_push());
    }
  }

  Future<void> _setTrackingMode(MyLocationTrackingMode mode) async {
    setState(() => _trackingMode = mode);
    await _controller?.updateMyLocationTrackingMode(mode);
  }

  // Render mode is applied via the widget option (no dedicated controller
  // method); updating state rebuilds the map and pushes the option change.
  void _setRenderMode(MyLocationRenderMode mode) {
    setState(() => _renderMode = mode);
  }

  static String _trackingLabel(MyLocationTrackingMode mode) {
    switch (mode) {
      case MyLocationTrackingMode.none:
        return 'None';
      case MyLocationTrackingMode.tracking:
        return 'Tracking';
      case MyLocationTrackingMode.trackingCompass:
        return 'Compass';
      case MyLocationTrackingMode.trackingGps:
        return 'GPS';
    }
  }

  static String _renderLabel(MyLocationRenderMode mode) {
    switch (mode) {
      case MyLocationRenderMode.normal:
        return 'Normal';
      case MyLocationRenderMode.compass:
        return 'Compass';
      case MyLocationRenderMode.gps:
        return 'GPS';
    }
  }

  String _fmt(double? value, {int decimals = 5, String suffix = ''}) {
    if (value == null) return '--';
    return '${value.toStringAsFixed(decimals)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final hasController = _controller != null;

    if (kIsWeb) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: InfoCard(
          title: 'Not supported on web',
          subtitle:
              'ManualLocationSource is only available on Android and iOS. '
              'On web, use the default PlatformLocationSource.',
          icon: Icons.public_off,
        ),
      );
    }

    return MapExampleScaffold(
      map: MapLibreMap(
        styleString:
            "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json",
        onMapCreated: _onMapCreated,
        onUserLocationUpdated: _onUserLocationUpdated,
        // App-provided location source: no permission required, the native
        // location engine is disabled.
        locationSource: const ManualLocationSource(),
        myLocationEnabled: true,
        myLocationTrackingMode: _trackingMode,
        myLocationRenderMode: _renderMode,
        initialCameraPosition: const CameraPosition(
          target: _center,
          zoom: 15,
        ),
        trackCameraPosition: true,
      ),
      controls: [
        const InfoCard(
          title: 'Manual Location Source',
          subtitle:
              'The puck is driven by controller.updateManualLocation(...). '
              'No location permission is required.',
          icon: Icons.edit_location_alt,
        ),
        const SizedBox(height: 8),
        ControlGroup(
          title: 'Simulation',
          vertical: false,
          children: [
            ExampleButton(
              label: _simulating ? 'Stop' : 'Start moving track',
              icon: _simulating ? Icons.stop : Icons.play_arrow,
              onPressed: hasController ? _toggleSimulation : null,
              style: ExampleButtonStyle.filled,
            ),
            ExampleButton(
              label: 'Push one update',
              icon: Icons.my_location,
              onPressed:
                  hasController && !_simulating
                      ? () => unawaited(_step())
                      : null,
              style: ExampleButtonStyle.tonal,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ControlGroup(
          title: 'Tracking mode',
          vertical: false,
          children: [
            for (final mode in MyLocationTrackingMode.values)
              ChoiceChip(
                label: Text(_trackingLabel(mode)),
                selected: _trackingMode == mode,
                onSelected:
                    hasController
                        ? (_) => unawaited(_setTrackingMode(mode))
                        : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ControlGroup(
          title: 'Render mode',
          vertical: true,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final mode in MyLocationRenderMode.values)
                  ChoiceChip(
                    label: Text(_renderLabel(mode)),
                    selected: _renderMode == mode,
                    onSelected:
                        hasController ? (_) => _setRenderMode(mode) : null,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ControlGroup(
          title: 'Horizontal accuracy (ring)',
          vertical: true,
          children: [
            Row(
              children: [
                const Icon(Icons.radar, size: 20),
                const SizedBox(width: 8),
                Text('${_accuracy.round()} m'),
              ],
            ),
            Slider(
              value: _accuracy,
              min: 1,
              max: 300,
              divisions: 299,
              label: '${_accuracy.round()} m',
              onChanged: hasController ? _onAccuracyChanged : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ControlGroup(
          title: 'Last onUserLocationUpdated',
          vertical: true,
          children: [
            _tile(
              'Latitude',
              _fmt(_lastUpdate?.position.latitude, decimals: 6),
              Icons.pin_drop,
            ),
            _tile(
              'Longitude',
              _fmt(_lastUpdate?.position.longitude, decimals: 6),
              Icons.pin_drop,
            ),
            _tile(
              'Bearing',
              _fmt(_lastUpdate?.bearing, decimals: 1, suffix: '°'),
              Icons.explore,
            ),
            _tile(
              'Speed',
              _fmt(_lastUpdate?.speed, decimals: 1, suffix: ' m/s'),
              Icons.speed,
            ),
            _tile(
              'Accuracy',
              _fmt(_lastUpdate?.horizontalAccuracy, decimals: 1, suffix: ' m'),
              Icons.radar,
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: SelectableText(
        value,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
