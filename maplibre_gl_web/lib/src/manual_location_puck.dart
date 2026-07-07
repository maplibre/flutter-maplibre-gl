import 'dart:math';

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/src/geo/lng_lat.dart';
import 'package:maplibre_gl_web/src/ui/camera.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';
import 'package:maplibre_gl_web/src/ui/marker.dart';
import 'package:maplibre_gl_web/src/util/evented.dart';
import 'package:web/web.dart' as web;

/// Renders and drives the app-provided ("manual") user-location puck on web.
///
/// maplibre-gl-js' `GeolocateControl` reads only the browser Geolocation API
/// and cannot be fed an arbitrary position, so when the map uses
/// `ManualLocationSource` this draws its own puck from HTML [Marker]s:
///  * the location dot and accuracy circle reuse maplibre-gl-js' built-in
///    `maplibregl-user-location-*` CSS classes so they match the native look
///    (host apps already include `maplibre-gl.css`);
///  * the bearing arrow is a small custom element (maplibre ships no arrow).
///
/// The controller owns the source/enabled flags and creates one instance
/// lazily; this class owns everything else about the puck.
class ManualLocationPuck {
  ManualLocationPuck(
    this._map, {
    required void Function(bool) onTrackingChanged,
  }) : _onTrackingChanged = onTrackingChanged;

  final MapLibreMap _map;

  /// Called when tracking turns on/off, so the controller can forward the
  /// platform `onCameraTrackingChanged` callback.
  final void Function(bool) _onTrackingChanged;

  Marker? _dotMarker;
  Marker? _accuracyMarker;
  web.HTMLDivElement? _accuracyEl;
  web.HTMLDivElement? _arrowEl;
  final _resizeSubscriptions = <Subscription>[];

  LatLng? _position;
  double? _accuracyMeters;
  double? _bearing;

  /// Tracking mode index ([MyLocationTrackingMode.index]): 0 none, 1 tracking,
  /// 2 trackingCompass, 3 trackingGps. GPS mode rotates the map to the fix
  /// bearing (matching Android); the others only recenter.
  int _trackingMode = 0;
  bool get _tracking => _trackingMode != 0;

  /// Base diameter (px) of the accuracy circle element. The element keeps this
  /// fixed size and is scaled with a CSS `transform` to represent the reported
  /// accuracy in meters on the ground.
  static const double _accuracyBaseDiameterPx = 100;

  /// Whether the one-time arrow CSS has been injected into the document.
  static bool _styleInjected = false;

  /// The most recent position pushed via [update], or null if none yet.
  LatLng? get lastPosition => _position;

  /// Pushes a new fix: (re)builds the puck if needed, moves it, updates the
  /// accuracy circle and bearing arrow, and recenters the camera when tracking.
  void update(
    LatLng position, {
    double? accuracyMeters,
    double? bearing,
  }) {
    _position = position;
    _accuracyMeters = accuracyMeters;
    _bearing = bearing;

    _build();
    final lngLat = LngLat(position.longitude, position.latitude);
    _dotMarker?.setLngLat(lngLat);
    _accuracyMarker?.setLngLat(lngLat);
    _applyBearing(bearing);
    _updateAccuracyCircle();

    if (_tracking) {
      _recenter(position, bearing: bearing);
    }
  }

  /// Sets the tracking mode. Any non-none mode recenters the camera on the last
  /// fix; GPS mode also rotates the map to the fix bearing (matching Android).
  /// Compass mode has no web equivalent, so it behaves like plain tracking.
  void setTrackingMode(int modeIndex) {
    final wasTracking = _tracking;
    _trackingMode = modeIndex;
    if (_tracking != wasTracking) {
      _onTrackingChanged(_tracking);
    }
    if (_tracking && _position != null) {
      _recenter(_position!, bearing: _bearing);
    }
  }

  /// Removes the puck markers and their listeners.
  void dispose() {
    for (final sub in _resizeSubscriptions) {
      sub.unsubscribe();
    }
    _resizeSubscriptions.clear();
    _dotMarker?.remove();
    _dotMarker = null;
    _accuracyMarker?.remove();
    _accuracyMarker = null;
    _accuracyEl = null;
    _arrowEl = null;
  }

  /// Creates the puck markers and adds them to the map. No-op if already built.
  ///
  /// A maplibre-gl-js [Marker] must have its `LngLat` set before it is added to
  /// the map: its internal `_update` (fired on style load, resize, and
  /// projection changes) dereferences the marker's position and throws if it is
  /// null. So we build only after the first fix and always `setLngLat` before
  /// `addTo`. Markers are DOM overlays, so unlike style layers they survive
  /// `setStyle`.
  void _build() {
    if (_dotMarker != null) return;
    final position = _position;
    if (position == null) return;
    final lngLat = LngLat(position.longitude, position.latitude);

    _injectStyle();

    // Accuracy circle. maplibre-gl-js owns the `transform` of a Marker's root
    // element (it writes `translate(...)` there every frame), so the circle we
    // scale must be an INNER child — otherwise our `scale(...)` is overwritten
    // and the ring never resizes. The inner element keeps a fixed base size and
    // is scaled with a compositor-only transform on zoom (see
    // [_updateAccuracyCircle]) to avoid per-update layout reflows.
    final accuracyWrapper =
        web.document.createElement('div') as web.HTMLDivElement;
    final accuracyEl =
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'maplibregl-user-location-accuracy-circle'
          ..style.width = '${_accuracyBaseDiameterPx}px'
          ..style.height = '${_accuracyBaseDiameterPx}px';
    accuracyWrapper.appendChild(accuracyEl);
    _accuracyEl = accuracyEl;
    _accuracyMarker =
        Marker(
            MarkerOptions(
              element: accuracyWrapper,
              pitchAlignment: 'map',
              // Sub-pixel positioning: without it maplibre snaps the marker to whole
              // pixels, which makes the puck visibly tremble when it is reprojected
              // every frame against a moving/tracking camera.
              subpixelPositioning: true,
            ),
          )
          ..setLngLat(lngLat)
          ..addTo(_map);

    // Dot: reuses maplibre-gl-js' own class (blue dot + pulse). The bearing
    // arrow is a child element rotated via CSS transform (maplibre-gl-js ships
    // no built-in heading arrow class).
    final dotEl =
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'maplibregl-user-location-dot';
    final arrowEl =
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'maplibre-gl-manual-location-arrow'
          ..style.display = 'none';
    dotEl.appendChild(arrowEl);
    _arrowEl = arrowEl;
    _dotMarker =
        Marker(
            MarkerOptions(element: dotEl, subpixelPositioning: true),
          )
          ..setLngLat(lngLat)
          ..addTo(_map);

    // The circle's ground size only depends on zoom (not pan), so resize on
    // 'zoom' alone. Wiring 'move' too would re-run this on every animation
    // frame during camera pans and cause visible lag. Keep the arrow aligned
    // with the true course as the map bearing changes (e.g. GPS mode).
    _resizeSubscriptions
      ..add(_map.on('zoom', (_) => _updateAccuracyCircle()))
      ..add(_map.on('rotate', (_) => _applyBearing(_bearing)));
  }

  /// Points the bearing arrow along [bearing] degrees, or hides it when null.
  ///
  /// The arrow is a screen-space DOM element, so it is rotated by the bearing
  /// relative to the map's current bearing. That keeps it pointing along the
  /// true course whether the map's north is fixed (tracking/none) or rotated to
  /// the direction of travel (GPS mode). Re-applied on map `rotate`.
  void _applyBearing(double? bearing) {
    final arrowEl = _arrowEl;
    if (arrowEl == null) return;
    if (bearing == null) {
      arrowEl.style.display = 'none';
      return;
    }
    final screenBearing = bearing - _map.getBearing();
    arrowEl.style.display = 'block';
    arrowEl.style.transformOrigin = 'bottom center';
    arrowEl.style.transform =
        'translate(-50%, -100%) rotate(${screenBearing.toStringAsFixed(1)}deg)';
  }

  /// Scales the accuracy circle to match the current zoom, so it represents the
  /// reported horizontal accuracy in meters on the ground.
  ///
  /// Uses a compositor-only CSS `transform: scale(...)` rather than changing
  /// `width`/`height`: mutating the box size forces a layout reflow on every
  /// update, whereas a transform is GPU-composited and does not reflow.
  ///
  /// Synchronous and cheap on purpose: it runs on every `zoom` event and
  /// computes meters-per-pixel inline. It does not depend on pan, so it is not
  /// wired to `move`.
  void _updateAccuracyCircle() {
    final accuracyEl = _accuracyEl;
    final position = _position;
    final accuracyMeters = _accuracyMeters;
    if (accuracyEl == null || position == null) return;
    if (accuracyMeters == null || accuracyMeters <= 0) {
      accuracyEl.style.display = 'none';
      return;
    }
    // https://wiki.openstreetmap.org/wiki/Zoom_levels
    const circumference = 40075017.686;
    final zoom = _map.getZoom();
    final metersPerPixel =
        circumference * cos(position.latitude * (pi / 180)) / pow(2, zoom + 9);
    if (metersPerPixel <= 0) return;
    final diameterPx = 2 * accuracyMeters / metersPerPixel;
    final scale = diameterPx / _accuracyBaseDiameterPx;
    accuracyEl.style.display = 'block';
    accuracyEl.style.transform = 'scale(${scale.toStringAsFixed(4)})';
  }

  /// Recenters the camera on [position] while a tracking mode is active. In GPS
  /// mode ([MyLocationTrackingMode.trackingGps], index 3) the map is also
  /// rotated so [bearing] points up, matching Android.
  ///
  /// Uses `jumpTo` (instant) rather than an animated `easeTo`: fixes can arrive
  /// at a high frequency (~60/s), and restarting a 300 ms ease on every fix
  /// would never settle and would stutter. The camera follows the puck 1:1,
  /// which is smooth as long as the fixes themselves are smooth.
  void _recenter(LatLng position, {double? bearing}) {
    _map.jumpTo(
      CameraOptions(
        center: LngLat(position.longitude, position.latitude),
        bearing: (_trackingMode == 3 && bearing != null) ? bearing : null,
      ),
    );
  }

  /// Injects the bearing-arrow CSS once. The dot and accuracy circle rely on
  /// maplibre-gl-js' own stylesheet (host apps already include it); only the
  /// custom arrow needs a rule.
  void _injectStyle() {
    if (_styleInjected) return;
    _styleInjected = true;
    final style =
        web.document.createElement('style') as web.HTMLStyleElement
          ..textContent = '''
            .maplibre-gl-manual-location-arrow {
              position: absolute;
              left: 50%;
              top: 50%;
              width: 0;
              height: 0;
              border-left: 6px solid transparent;
              border-right: 6px solid transparent;
              border-bottom: 10px solid #1da1f2;
              pointer-events: none;
            }
            ''';
    web.document.head?.appendChild(style);
  }
}
