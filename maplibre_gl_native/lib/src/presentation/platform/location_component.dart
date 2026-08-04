import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

import '../../engine/map_session.dart';
import '../../native_bridge.dart';
import '../../protocol/protocol.dart';

/// The `myLocation` subsystem: platform location updates in, a puck on the map
/// and camera tracking out.
///
/// Owns everything the maplibre_gl location options imply, so the platform
/// adapter only has to forward them here. Mirrors the Android SDK's
/// LocationComponent, including its two events on a tracking dismissal.
class LocationComponent {
  LocationComponent({
    required MapSession? Function() session,
    required void Function(UserLocation location) onLocationUpdated,
    required void Function(MyLocationTrackingMode mode) onTrackingModeChanged,
    required void Function() onTrackingDismissed,
  }) : _session = session,
       _onLocationUpdated = onLocationUpdated,
       _onTrackingModeChanged = onTrackingModeChanged,
       _onTrackingDismissed = onTrackingDismissed;

  static const _topImage = 'maplibre-gl-native-location-top';
  static const _bearingImage = 'maplibre-gl-native-location-bearing';

  /// Duration of the camera ease onto a new fix while tracking, matching the
  /// reference backends.
  static const _trackingEaseMs = 500.0;

  /// `MyLocationRenderMode.normal`: the puck has no direction wedge.
  static const _renderModeNormal = 0;

  final MapSession? Function() _session;
  final void Function(UserLocation location) _onLocationUpdated;
  final void Function(MyLocationTrackingMode mode) _onTrackingModeChanged;
  final void Function() _onTrackingDismissed;

  bool _enabled = false;
  bool _imagesRegistered = false;
  bool _indicatorVisible = false;
  int _renderMode = _renderModeNormal;
  MyLocationTrackingMode _trackingMode = MyLocationTrackingMode.none;
  UserLocation? _lastLocation;

  /// Last known position, for `requestMyLocationLatLng`.
  LatLng? get lastPosition => _lastLocation?.position;

  /// Applies the location keys of a maplibre_gl options map.
  void applyOptions(Map<String, dynamic> options) {
    final renderMode = options['myLocationRenderMode'];
    if (renderMode is int) _renderMode = renderMode;

    final trackingMode = options['myLocationTrackingMode'];
    if (trackingMode is int &&
        trackingMode >= 0 &&
        trackingMode < MyLocationTrackingMode.values.length) {
      final mode = MyLocationTrackingMode.values[trackingMode];
      if (mode != _trackingMode) {
        _trackingMode = mode;
        _onTrackingModeChanged(mode);
        // Snap to the last known fix right away instead of waiting for the
        // next one, like the reference backends do on mode changes.
        _trackCameraIfNeeded();
      }
    }

    final enabled = options['myLocationEnabled'];
    if (enabled is bool && enabled != _enabled) {
      _enabled = enabled;
      if (_session() != null) {
        unawaited(enabled ? _start() : _stop());
      }
    }
  }

  /// The widget created the session: start streaming if the app asked for it
  /// before the map existed.
  void onSessionAttached() {
    if (_enabled) unawaited(_start());
  }

  /// Stops the component for good; called from the platform adapter's own
  /// dispose. Without this a closed map would leave the platform location
  /// stream running for the rest of the process, with the static
  /// [NativeBridge.onLocationUpdate] pinning this component (and through it
  /// the whole adapter) as a bonus.
  void dispose() {
    if (!_enabled) return;
    _enabled = false;
    unawaited(_stop());
  }

  /// A style load drops runtime images and layers: re-register the puck
  /// before the app re-adds its own content.
  void onStyleLoaded() {
    if (!_enabled) return;
    _imagesRegistered = false;
    _indicatorVisible = false;
    if (_lastLocation != null) unawaited(_showIndicator());
  }

  /// Sets the tracking mode from `updateMyLocationTrackingMode`.
  void setTrackingMode(MyLocationTrackingMode mode) {
    _trackingMode = mode;
    _onTrackingModeChanged(mode);
    _trackCameraIfNeeded();
  }

  /// A user gesture panned the camera: drop an active tracking mode, like the
  /// reference backends.
  void notifyUserGesture() {
    if (_trackingMode == MyLocationTrackingMode.none) return;
    _trackingMode = MyLocationTrackingMode.none;
    // The Android LocationComponent emits both: the mode change to none and
    // the dismissal event. Apps typically listen to the former.
    _onTrackingModeChanged(MyLocationTrackingMode.none);
    _onTrackingDismissed();
  }

  Future<void> _start() async {
    // The bridge streams one process-wide fix; the most recently enabled map
    // consumes it.
    NativeBridge.onLocationUpdate = _onFix;
    final started = await NativeBridge.startLocationUpdates();
    if (!started) {
      debugPrint(
        '[maplibre_gl_native] myLocationEnabled: platform location updates '
        'could not start (missing permission?)',
      );
    }
    // The puck is shown lazily on the first fix: the layer's style-spec
    // default location is (0, 0), so showing it earlier would render the
    // puck at Null Island.
    if (_lastLocation != null) await _showIndicator();
  }

  Future<void> _stop() async {
    if (identical(NativeBridge.onLocationUpdate, _onFix)) {
      NativeBridge.onLocationUpdate = null;
    }
    await NativeBridge.stopLocationUpdates();
    _indicatorVisible = false;
    final session = _session();
    if (session == null) return;
    session.send(RemoveLocationIndicatorCommand(session.id));
  }

  Future<void> _showIndicator() async {
    final session = _session();
    if (session == null) return;
    _indicatorVisible = true;
    if (!_imagesRegistered) {
      _imagesRegistered = true;
      final top = await _drawPuck(withBearing: false);
      final bearing = await _drawPuck(withBearing: true);
      session
        ..send(
          SetStyleImageCommand(
            session.id,
            _topImage,
            top.$1,
            width: top.$2,
            height: top.$3,
            pixelRatio: 2,
          ),
        )
        ..send(
          SetStyleImageCommand(
            session.id,
            _bearingImage,
            bearing.$1,
            width: bearing.$2,
            height: bearing.$3,
            pixelRatio: 2,
          ),
        );
    }
    session.send(
      ShowLocationIndicatorCommand(
        session.id,
        topImage: _topImage,
        // The bearing puck is used for the compass/gps render modes.
        bearingImage: _renderMode == _renderModeNormal ? null : _bearingImage,
      ),
    );
    final location = _lastLocation;
    if (location != null) _pushIndicatorLocation(location);
  }

  void _onFix(Map<Object?, Object?> fix) {
    if (_session() == null || !_enabled) return;
    final timestampMs = (fix['timestamp'] as num?)?.toInt();
    final location = UserLocation(
      position: LatLng(
        (fix['latitude']! as num).toDouble(),
        (fix['longitude']! as num).toDouble(),
      ),
      altitude: (fix['altitude'] as num?)?.toDouble(),
      bearing: (fix['bearing'] as num?)?.toDouble(),
      speed: (fix['speed'] as num?)?.toDouble(),
      horizontalAccuracy: (fix['horizontalAccuracy'] as num?)?.toDouble(),
      verticalAccuracy: (fix['verticalAccuracy'] as num?)?.toDouble(),
      timestamp: timestampMs == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestampMs),
      heading: null,
    );
    _lastLocation = location;
    _onLocationUpdated(location);
    if (_indicatorVisible) {
      _pushIndicatorLocation(location);
    } else {
      // First fix: show the puck now (ends by pushing this location).
      unawaited(_showIndicator());
    }
    _trackCameraIfNeeded();
  }

  void _pushIndicatorLocation(UserLocation location) {
    final session = _session();
    if (session == null) return;
    session.send(
      UpdateLocationIndicatorCommand(
        session.id,
        latitude: location.position.latitude,
        longitude: location.position.longitude,
        bearing: _renderMode == _renderModeNormal ? null : location.bearing,
        accuracyRadius: location.horizontalAccuracy,
      ),
    );
  }

  void _trackCameraIfNeeded() {
    if (_trackingMode == MyLocationTrackingMode.none) return;
    final session = _session();
    final location = _lastLocation;
    if (session == null || location == null) return;
    final followBearing = _trackingMode != MyLocationTrackingMode.tracking;
    session.send(
      EaseToCommand(
        session.id,
        CameraSpec(
          latitude: location.position.latitude,
          longitude: location.position.longitude,
          bearing: followBearing ? location.bearing : null,
        ),
        durationMs: _trackingEaseMs,
      ),
    );
  }

  /// Draws the default puck (blue dot, white ring, optional direction wedge)
  /// and returns raw premultiplied RGBA plus its pixel size.
  static Future<(Uint8List, int, int)> _drawPuck({
    required bool withBearing,
  }) async {
    const size = 48;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (withBearing) {
      final wedge = Path()
        ..moveTo(size / 2, 2)
        ..lineTo(size / 2 - 9, 17)
        ..lineTo(size / 2 + 9, 17)
        ..close();
      canvas.drawPath(wedge, Paint()..color = const Color(0xFF4285F4));
    }
    canvas.drawCircle(center, 15, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(center, 11, Paint()..color = const Color(0xFF4285F4));
    final image = await recorder.endRecording().toImage(size, size);
    try {
      final data = await image.toByteData();
      return (
        data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        image.width,
        image.height,
      );
    } finally {
      image.dispose();
    }
  }
}
