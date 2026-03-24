import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../page.dart';
import '../../shared/shared.dart';

/// Example demonstrating GPS location tracking
class GpsLocationPage extends ExamplePage {
  const GpsLocationPage({super.key})
    : super(
        const Icon(Icons.gps_fixed),
        'GPS Location',
        needsLocationPermission: false,
        category: ExampleCategory.basics,
      );

  @override
  Widget build(BuildContext context) => const _GpsLocationBody();
}

class _GpsLocationBody extends StatefulWidget {
  const _GpsLocationBody();

  @override
  State<_GpsLocationBody> createState() => _GpsLocationBodyState();
}

class _GpsLocationBodyState extends State<_GpsLocationBody> {
  MapLibreMapController? _controller;
  LocationData? _currentLocation;
  bool _useHighAccuracy = false;
  PermissionStatus? _permissionStatus;
  MyLocationTrackingMode _trackingMode = MyLocationTrackingMode.none;
  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    unawaited(_checkPermission());
  }

  Future<void> _checkPermission() async {
    if (kIsWeb) {
      // On web, location_web's hasPermission() is broken.
      // Enable location directly — the browser handles the permission
      // prompt via the GeolocateControl when it tries to access location.
      if (mounted) {
        setState(() => _permissionStatus = PermissionStatus.granted);
      }
      return;
    }
    final status = await _location.hasPermission();
    if (mounted) {
      setState(() => _permissionStatus = status);
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => _controller = controller);
  }

  void _onCameraTrackingChanged(MyLocationTrackingMode mode) {
    if (mounted) {
      setState(() => _trackingMode = mode);
    }
  }

  void _onUserLocationUpdated(UserLocation location) {
    if (mounted) {
      setState(() {
        _currentLocation = LocationData.fromMap({
          'latitude': location.position.latitude,
          'longitude': location.position.longitude,
          'altitude': location.altitude,
          'accuracy': location.horizontalAccuracy,
          'verticalAccuracy': location.verticalAccuracy,
          'heading': location.heading?.trueHeading,
          'speed': location.speed,
        });
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await _location.requestPermission();
    if (mounted) {
      setState(() => _permissionStatus = status);
    }
  }

  static const _highAccuracyProperties =
      kIsWeb
          ? LocationEnginePlatforms.web(enableHighAccuracy: true)
          : LocationEnginePlatforms.android(
            enableHighAccuracy: true,
            interval: 1000,
            displacement: 1,
          );

  Future<void> _toggleAccuracy() async {
    setState(() => _useHighAccuracy = !_useHighAccuracy);
  }

  Future<void> _cycleTrackingMode() async {
    // On web, only None and Tracking are meaningful — compass/GPS
    // distinctions don't exist in the browser's GeolocateControl.
    const webTrackingModes = <MyLocationTrackingMode>[
      MyLocationTrackingMode.none,
      MyLocationTrackingMode.tracking,
    ];

    const modes = kIsWeb ? webTrackingModes : MyLocationTrackingMode.values;
    final currentIndex = modes.indexOf(_trackingMode);
    final nextMode = modes[(currentIndex + 1) % modes.length];

    if (_controller != null) {
      await _controller!.updateMyLocationTrackingMode(nextMode);
      setState(() => _trackingMode = nextMode);
    }
  }

  String _getTrackingModeLabel() {
    switch (_trackingMode) {
      case MyLocationTrackingMode.none:
        return 'None';
      case MyLocationTrackingMode.tracking:
        return kIsWeb ? 'Active tracking' : 'Tracking';
      case MyLocationTrackingMode.trackingCompass:
        return 'Tracking + Compass';
      case MyLocationTrackingMode.trackingGps:
        return 'Tracking GPS';
    }
  }

  String _getTrackingModeDescription() {
    switch (_trackingMode) {
      case MyLocationTrackingMode.none:
        return kIsWeb
            ? 'Location dot shown, camera does not follow'
            : 'No tracking active';
      case MyLocationTrackingMode.tracking:
        return kIsWeb ? 'Camera follows user location' : 'Follow user location';
      case MyLocationTrackingMode.trackingCompass:
        return 'Follow location and rotation';
      case MyLocationTrackingMode.trackingGps:
        return 'GPS-based tracking';
    }
  }

  String _formatCoordinate(double? value, {int decimals = 6}) {
    if (value == null) return '--';
    return value.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    final hasController = _controller != null;
    final hasPermission = _permissionStatus == PermissionStatus.granted;
    final hasLocation = _currentLocation != null;

    return MapExampleScaffold(
      map: MapLibreMap(
        styleString: ExampleConstants.demoMapStyle,
        onMapCreated: _onMapCreated,
        onUserLocationUpdated: _onUserLocationUpdated,
        onCameraTrackingChanged: _onCameraTrackingChanged,
        initialCameraPosition: const CameraPosition(
          target: LatLng(37.3, -121.8),
          zoom: 7,
        ),
        trackCameraPosition: true,
        myLocationEnabled: hasPermission,
        myLocationTrackingMode: _trackingMode,
        locationEnginePlatforms:
            _useHighAccuracy
                ? _highAccuracyProperties
                : LocationEnginePlatforms.defaultPlatform,
      ),
      controls: [
        InfoCard(
          title: 'GPS Location Tracking',
          subtitle:
              hasPermission
                  ? 'Track your device location on the map'
                  : 'Location permission required',
          icon: hasPermission ? Icons.gps_fixed : Icons.gps_off,
          color: hasPermission ? null : Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 8),
        if (!hasPermission)
          ControlGroup(
            title: 'Permission Required',
            vertical: false,
            children: [
              ExampleButton(
                label: 'Grant Permission',
                onPressed: _requestPermission,
                icon: Icons.lock_open,
                style: ExampleButtonStyle.filled,
              ),
            ],
          ),
        if (hasPermission) ...[
          ControlGroup(
            title: 'Tracking Mode',
            vertical: true,
            children: [
              ListTile(
                title: Text(_getTrackingModeLabel()),
                subtitle: Text(_getTrackingModeDescription()),
                trailing: FilledButton.tonal(
                  onPressed: hasController ? _cycleTrackingMode : null,
                  child: const Text('Change'),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ControlGroup(
            title: 'Settings',
            vertical: true,
            children: [
              SwitchListTile(
                title: const Text('High Accuracy Mode'),
                subtitle: Text(
                  _useHighAccuracy
                      ? 'GPS with high accuracy'
                      : 'Default location settings',
                ),
                value: _useHighAccuracy,
                onChanged: (_) => _toggleAccuracy(),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          if (hasLocation) ...[
            const SizedBox(height: 8),
            ControlGroup(
              title: 'Current Location',
              vertical: true,
              children: [
                _buildLocationTile(
                  'Latitude',
                  _formatCoordinate(_currentLocation?.latitude),
                  Icons.pin_drop,
                ),
                _buildLocationTile(
                  'Longitude',
                  _formatCoordinate(_currentLocation?.longitude),
                  Icons.pin_drop,
                ),
                if (_currentLocation?.accuracy != null)
                  _buildLocationTile(
                    'Accuracy',
                    '${_currentLocation!.accuracy!.toStringAsFixed(1)} m',
                    Icons.radar,
                  ),
                if (_currentLocation?.altitude != null)
                  _buildLocationTile(
                    'Altitude',
                    '${_currentLocation!.altitude!.toStringAsFixed(1)} m',
                    Icons.terrain,
                  ),
                if (_currentLocation?.speed != null &&
                    _currentLocation!.speed! > 0)
                  _buildLocationTile(
                    'Speed',
                    '${_currentLocation!.speed!.toStringAsFixed(1)} m/s',
                    Icons.speed,
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildLocationTile(String label, String value, IconData icon) {
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
