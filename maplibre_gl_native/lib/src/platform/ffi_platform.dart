import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data' show BytesBuilder;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

import '../engine/engine_isolate.dart';
import '../engine/engine_protocol.dart';
import '../view/ffi_map_view.dart';
import 'ffi_platform_base.dart';
import '../view/ornaments.dart';
import '../io/style_string_resolver.dart';
import '../io/texture_bridge.dart';

/// Style-spec layout properties, used to split the flat property maps of the
/// existing maplibre_gl API into the paint/layout objects that raw style
/// layer JSON requires. Everything not listed here is a paint property.
///
/// NOTE(spike): the long-term implementation should generate this table from
/// the style spec in `scripts/` instead of hand-maintaining it.
const Set<String> _layoutPropertyKeys = {
  'visibility',
  // symbol
  'symbol-placement', 'symbol-spacing', 'symbol-avoid-edges',
  'symbol-sort-key', 'symbol-z-order',
  'icon-allow-overlap', 'icon-overlap', 'icon-ignore-placement',
  'icon-optional', 'icon-rotation-alignment', 'icon-size', 'icon-text-fit',
  'icon-text-fit-padding', 'icon-image', 'icon-rotate', 'icon-padding',
  'icon-keep-upright', 'icon-offset', 'icon-anchor', 'icon-pitch-alignment',
  'text-pitch-alignment', 'text-rotation-alignment', 'text-field',
  'text-font', 'text-size', 'text-max-width', 'text-line-height',
  'text-letter-spacing', 'text-justify', 'text-radial-offset',
  'text-variable-anchor', 'text-variable-anchor-offset', 'text-anchor',
  'text-max-angle', 'text-writing-mode', 'text-rotate', 'text-padding',
  'text-keep-upright', 'text-transform', 'text-offset', 'text-allow-overlap',
  'text-overlap', 'text-ignore-placement', 'text-optional',
  // line
  'line-cap', 'line-join', 'line-miter-limit', 'line-round-limit',
  'line-sort-key',
  // fill / circle
  'fill-sort-key', 'circle-sort-key',
};

/// Mutable gesture configuration shared between [MapLibreFfiPlatform] and the
/// map widget, mirroring the maplibre_gl widget options.
class FfiGestureConfig {
  bool scrollEnabled = true;
  bool zoomEnabled = true;
  bool rotateEnabled = true;
  bool tiltEnabled = true;
  bool doubleClickZoomEnabled = true;
}

/// [MapLibrePlatform] backend implemented over the MapLibre Native C API via
/// dart:ffi, rendering into a Flutter [Texture].
///
/// Pure protocol adapter: translates the platform-interface contract into
/// [EngineHost] commands/queries and engine events back into the platform
/// callback sinks. It never touches a native handle directly.
///
/// Spike scope: camera, style loading, projection, GeoJSON sources, style
/// layers by JSON, and runtime events. Everything else throws through
/// [MapLibreFfiPlatformBase].
class MapLibreFfiPlatform extends MapLibreFfiPlatformBase {
  EngineHost? _host;
  int? _sessionId;
  final _ready = Completer<void>();

  /// Gesture flags consumed by the map widget.
  final gestures = FfiGestureConfig();

  /// Ornament (compass, attribution, logo) configuration consumed by the map
  /// widget.
  final ornaments = FfiOrnamentConfig();

  /// Layer ids added with `enableInteraction`, in add order (bottom to top).
  final List<String> _interactiveLayerIds = <String>[];

  /// Whether annotation drag is enabled (widget `dragEnabled`).
  bool dragEnabled = true;

  /// Whether a consumed feature tap also emits the map click.
  bool _featureTapsTriggersMapClick = false;

  (EngineHost, int) _requireSession() {
    final host = _host;
    final sessionId = _sessionId;
    if (host == null || sessionId == null) {
      throw StateError('The FFI map session is not ready yet');
    }
    return (host, sessionId);
  }

  void _send(EngineCommand command) {
    final (host, _) = _requireSession();
    host.send(command);
  }

  /// Called by the widget once the texture, map, and render session exist.
  void attach(EngineHost host, int sessionId) {
    _host = host;
    _sessionId = sessionId;
    host.addEventListener(_onEngineEvent);
    if (_myLocationEnabled) unawaited(_enableLocation());
    if (!_ready.isCompleted) _ready.complete();
  }

  void _onEngineEvent(EngineEvent event) {
    if (event.sessionId != _sessionId) return;
    switch (event) {
      case CameraWillChangeEvent():
        onCameraMoveStartedPlatform(null);
      case CameraIsChangingEvent():
        onCameraMovePlatform(_toCameraPosition(event.camera));
      case MapIdleEvent():
        onCameraIdlePlatform(_toCameraPosition(event.camera));
        onMapIdlePlatform(null);
      case StyleLoadedEvent():
        // A style load drops runtime images and layers: re-establish the
        // location indicator before apps re-add their own content. Without
        // a fix yet, the first one will show it instead.
        if (_myLocationEnabled) {
          _locationImagesRegistered = false;
          _locationIndicatorVisible = false;
          if (_lastLocation != null) unawaited(_showLocationIndicator());
        }
        onMapStyleLoadedPlatform(null);
      case SnapshotResultEvent():
        _resolveSnapshot(event);
      case MapLoadingFailedEvent() || RenderPendingEvent():
        break;
      // Offline events are engine-scoped (sessionId 0) and consumed by
      // MapLibreGlNativeOffline's own listener.
      case OfflineResultEvent() ||
          OfflineRegionProgressEvent() ||
          OfflineRegionErrorEvent():
        break;
    }
  }

  static CameraPosition _toCameraPosition(CameraSnapshot camera) {
    return CameraPosition(
      target: LatLng(camera.latitude, camera.longitude),
      zoom: camera.zoom,
      bearing: camera.bearing,
      tilt: camera.pitch,
    );
  }

  Future<CameraPosition> _currentCameraPosition() async {
    final (host, sessionId) = _requireSession();
    return _toCameraPosition(await host.query(GetCameraQuery(sessionId)));
  }

  // --- Lifecycle -----------------------------------------------------------

  @override
  Future<void> initPlatform(int id) => _ready.future;

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    final options =
        creationParams['options'] as Map<String, dynamic>? ?? const {};
    _applyGestureOptions(options);
    _applyLocationOptions(options);
    ornaments.applyOptions(options);
    dragEnabled = creationParams['dragEnabled'] as bool? ?? true;
    return FfiMapView(
      platform: this,
      creationParams: creationParams,
      onViewCreated: onPlatformViewCreated,
    );
  }

  @override
  void dispose() {
    // The widget owns the session and the texture; just drop the references.
    _host?.removeEventListener(_onEngineEvent);
    _host = null;
    _sessionId = null;
    super.dispose();
  }

  // --- Map options ---------------------------------------------------------

  void _applyGestureOptions(Map<String, dynamic> options) {
    void apply(String key, void Function(bool) setter) {
      final value = options[key];
      if (value is bool) setter(value);
    }

    apply('scrollGesturesEnabled', (v) => gestures.scrollEnabled = v);
    apply('zoomGesturesEnabled', (v) => gestures.zoomEnabled = v);
    apply('rotateGesturesEnabled', (v) => gestures.rotateEnabled = v);
    apply('tiltGesturesEnabled', (v) => gestures.tiltEnabled = v);
    apply('doubleClickZoomEnabled', (v) => gestures.doubleClickZoomEnabled = v);
    apply(
      'featureTapsTriggersMapClick',
      (v) => _featureTapsTriggersMapClick = v,
    );
  }

  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> optionsUpdate,
  ) async {
    _applyGestureOptions(optionsUpdate);
    _applyLocationOptions(optionsUpdate);
    ornaments.applyOptions(optionsUpdate);
    final styleString = optionsUpdate['styleString'];
    if (styleString is String) {
      await setStyle(styleString);
    }
    _applyConstraintOptions(optionsUpdate);
    return _currentCameraPosition();
  }

  // MapLibre Native camera constraint defaults, used to reset a preference.
  static const _defaultMinZoom = 0.0;
  static const _defaultMaxZoom = 25.5;

  void _applyConstraintOptions(Map<String, dynamic> options) {
    final (host, sessionId) = _requireSession();
    // CameraTargetBounds.toJson() is [boundsListOrNull] where the bounds list
    // is [[swLat, swLng], [neLat, neLng]]; a null entry means unbounded.
    final targetBounds = options['cameraTargetBounds'];
    if (targetBounds is List) {
      final bounds = targetBounds.isEmpty ? null : targetBounds[0] as List?;
      final southwest = bounds?[0] as List?;
      final northeast = bounds?[1] as List?;
      host.send(
        SetBoundsCommand(
          sessionId,
          // World bounds clear a previous constraint.
          southwestLatitude: (southwest?[0] as num?)?.toDouble() ?? -90,
          southwestLongitude: (southwest?[1] as num?)?.toDouble() ?? -180,
          northeastLatitude: (northeast?[0] as num?)?.toDouble() ?? 90,
          northeastLongitude: (northeast?[1] as num?)?.toDouble() ?? 180,
        ),
      );
    }
    // MinMaxZoomPreference.toJson() is [minZoom, maxZoom] with null meaning
    // unbounded on that side.
    final minMaxZoom = options['minMaxZoomPreference'];
    if (minMaxZoom is List && minMaxZoom.length >= 2) {
      host.send(
        SetBoundsCommand(
          sessionId,
          minZoom: (minMaxZoom[0] as num?)?.toDouble() ?? _defaultMinZoom,
          maxZoom: (minMaxZoom[1] as num?)?.toDouble() ?? _defaultMaxZoom,
        ),
      );
    }
  }

  // --- Camera --------------------------------------------------------------

  static const _easingCurves = <CameraAnimationInterpolation, List<double>>{
    CameraAnimationInterpolation.linear: [0, 0, 1, 1],
    CameraAnimationInterpolation.easeInOut: [0.42, 0, 0.58, 1],
    CameraAnimationInterpolation.easeOut: [0, 0, 0.58, 1],
    CameraAnimationInterpolation.fastOutLinearIn: [0.4, 0, 1, 1],
  };

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    _applyCameraUpdate(cameraUpdate, durationMs: null, easing: null);
    return true;
  }

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    _applyCameraUpdate(
      cameraUpdate,
      durationMs: (duration ?? const Duration(milliseconds: 300)).inMilliseconds
          .toDouble(),
      easing: null,
    );
    return true;
  }

  @override
  Future<bool> easeCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
    CameraAnimationInterpolation? interpolation,
  }) async {
    _applyCameraUpdate(
      cameraUpdate,
      durationMs: (duration ?? const Duration(milliseconds: 300)).inMilliseconds
          .toDouble(),
      easing:
          _easingCurves[interpolation ??
              CameraAnimationInterpolation.easeInOut],
    );
    return true;
  }

  void _applyCameraUpdate(
    CameraUpdate update, {
    required double? durationMs,
    required List<double>? easing,
  }) {
    final (host, sessionId) = _requireSession();
    final json = update.toJson() as List<dynamic>;
    final kind = json[0] as String;

    void goTo(CameraSpec camera) {
      host.send(
        durationMs == null
            ? JumpToCommand(sessionId, camera)
            : EaseToCommand(
                sessionId,
                camera,
                durationMs: durationMs,
                easing: easing,
              ),
      );
    }

    switch (kind) {
      case 'newCameraPosition':
        final position = json[1] as Map;
        final target = position['target'] as List;
        goTo(
          CameraSpec(
            latitude: (target[0] as num).toDouble(),
            longitude: (target[1] as num).toDouble(),
            zoom: (position['zoom'] as num?)?.toDouble(),
            bearing: (position['bearing'] as num?)?.toDouble(),
            pitch: (position['tilt'] as num?)?.toDouble(),
          ),
        );
      case 'newLatLng':
        final target = json[1] as List;
        goTo(
          CameraSpec(
            latitude: (target[0] as num).toDouble(),
            longitude: (target[1] as num).toDouble(),
          ),
        );
      case 'newLatLngZoom':
        final target = json[1] as List;
        goTo(
          CameraSpec(
            latitude: (target[0] as num).toDouble(),
            longitude: (target[1] as num).toDouble(),
            zoom: (json[2] as num).toDouble(),
          ),
        );
      case 'newLatLngBounds':
        final bounds = json[1] as List;
        final southwest = bounds[0] as List;
        final northeast = bounds[1] as List;
        host.send(
          FitBoundsCommand(
            sessionId,
            southwestLatitude: (southwest[0] as num).toDouble(),
            southwestLongitude: (southwest[1] as num).toDouble(),
            northeastLatitude: (northeast[0] as num).toDouble(),
            northeastLongitude: (northeast[1] as num).toDouble(),
            paddingLeft: (json[2] as num).toDouble(),
            paddingTop: (json[3] as num).toDouble(),
            paddingRight: (json[4] as num).toDouble(),
            paddingBottom: (json[5] as num).toDouble(),
            durationMs: durationMs,
            easing: easing,
          ),
        );
      case 'scrollBy':
        host.send(
          MoveByCommand(
            sessionId,
            -(json[1] as num).toDouble(),
            -(json[2] as num).toDouble(),
            durationMs: durationMs,
          ),
        );
      case 'zoomBy':
        final anchor = json.length > 2 ? (json[2] as List) : null;
        host.send(
          ScaleByCommand(
            sessionId,
            pow(2.0, (json[1] as num).toDouble()).toDouble(),
            anchorX: anchor == null ? null : (anchor[0] as num).toDouble(),
            anchorY: anchor == null ? null : (anchor[1] as num).toDouble(),
            durationMs: durationMs,
          ),
        );
      case 'zoomIn':
        host.send(ScaleByCommand(sessionId, 2, durationMs: durationMs));
      case 'zoomOut':
        host.send(ScaleByCommand(sessionId, 0.5, durationMs: durationMs));
      case 'zoomTo':
        goTo(CameraSpec(zoom: (json[1] as num).toDouble()));
      case 'bearingTo':
        goTo(CameraSpec(bearing: (json[1] as num).toDouble()));
      case 'tiltTo':
        goTo(CameraSpec(pitch: (json[1] as num).toDouble()));
      default:
        throw UnimplementedError('CameraUpdate "$kind" is not supported yet');
    }
  }

  @override
  Future<CameraPosition?> queryCameraPosition() => _currentCameraPosition();

  @override
  Future<LatLngBounds> getVisibleRegion() async {
    final (host, sessionId) = _requireSession();
    final bounds = await host.query(GetVisibleRegionQuery(sessionId));
    return LatLngBounds(
      southwest: LatLng(bounds[0], bounds[1]),
      northeast: LatLng(bounds[2], bounds[3]),
    );
  }

  // --- Projection ----------------------------------------------------------

  @override
  Future<Point> toScreenLocation(LatLng latLng) async {
    final (host, sessionId) = _requireSession();
    final point = await host.query(
      PixelForLatLngQuery(sessionId, latLng.latitude, latLng.longitude),
    );
    return Point<double>(point[0], point[1]);
  }

  @override
  Future<List<Point>> toScreenLocationBatch(Iterable<LatLng> latLngs) async {
    final (host, sessionId) = _requireSession();
    final coordinates = latLngs.toList(growable: false);
    final pairs = Float64List(coordinates.length * 2);
    for (var i = 0; i < coordinates.length; i++) {
      pairs[i * 2] = coordinates[i].latitude;
      pairs[i * 2 + 1] = coordinates[i].longitude;
    }
    final points = await host.query(PixelsForLatLngsQuery(sessionId, pairs));
    return [
      for (var i = 0; i + 1 < points.length; i += 2)
        Point<double>(points[i], points[i + 1]),
    ];
  }

  @override
  Future<LatLng> toLatLng(Point screenLocation) async {
    final (host, sessionId) = _requireSession();
    final coordinate = await host.query(
      LatLngForPixelQuery(
        sessionId,
        screenLocation.x.toDouble(),
        screenLocation.y.toDouble(),
      ),
    );
    return LatLng(coordinate[0], coordinate[1]);
  }

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) async {
    final (host, sessionId) = _requireSession();
    final camera = await host.query(GetCameraQuery(sessionId));
    // Web Mercator ground resolution with the 512px tile size MapLibre uses.
    const earthCircumference = 40075016.686;
    return earthCircumference *
        cos(latitude * pi / 180) /
        (512 * pow(2.0, camera.zoom));
  }

  // --- Style ---------------------------------------------------------------

  @override
  Future<void> setStyle(String styleString) async {
    final (host, sessionId) = _requireSession();
    // Asset and file styles must be read here on the root isolate; the
    // engine only accepts raw JSON or http(s) URLs.
    final resolved = await resolveStyleString(styleString);
    host.send(SetStyleCommand(sessionId, resolved));
  }

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) async {
    final (host, sessionId) = _requireSession();
    host.send(
      AddSourceJsonCommand(sessionId, sourceId, <String, dynamic>{
        'type': 'geojson',
        'data': geojson,
        'promoteId': ?promoteId,
      }),
    );
  }

  @override
  Future<void> removeSource(String sourceId) async {
    _send(RemoveSourceCommand(_sessionId!, sourceId));
  }

  @override
  Future<void> removeLayer(String imageLayerId) async {
    _interactiveLayerIds.remove(imageLayerId);
    _send(RemoveLayerCommand(_sessionId!, imageLayerId));
  }

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) => _addStyleLayer(
    type: 'symbol',
    sourceId: sourceId,
    layerId: layerId,
    properties: properties,
    belowLayerId: belowLayerId,
    sourceLayer: sourceLayer,
    minzoom: minzoom,
    maxzoom: maxzoom,
    filter: filter,
    enableInteraction: enableInteraction,
  );

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) => _addStyleLayer(
    type: 'line',
    sourceId: sourceId,
    layerId: layerId,
    properties: properties,
    belowLayerId: belowLayerId,
    sourceLayer: sourceLayer,
    minzoom: minzoom,
    maxzoom: maxzoom,
    filter: filter,
    enableInteraction: enableInteraction,
  );

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) => _addStyleLayer(
    type: 'circle',
    sourceId: sourceId,
    layerId: layerId,
    properties: properties,
    belowLayerId: belowLayerId,
    sourceLayer: sourceLayer,
    minzoom: minzoom,
    maxzoom: maxzoom,
    filter: filter,
    enableInteraction: enableInteraction,
  );

  @override
  Future<void> addFillLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) => _addStyleLayer(
    type: 'fill',
    sourceId: sourceId,
    layerId: layerId,
    properties: properties,
    belowLayerId: belowLayerId,
    sourceLayer: sourceLayer,
    minzoom: minzoom,
    maxzoom: maxzoom,
    filter: filter,
    enableInteraction: enableInteraction,
  );

  @override
  Future<void> addFillExtrusionLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) => _addStyleLayer(
    type: 'fill-extrusion',
    sourceId: sourceId,
    layerId: layerId,
    properties: properties,
    belowLayerId: belowLayerId,
    sourceLayer: sourceLayer,
    minzoom: minzoom,
    maxzoom: maxzoom,
    filter: filter,
    enableInteraction: enableInteraction,
  );

  @override
  Future<void> addRasterLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) => _addStyleLayer(
    type: 'raster',
    sourceId: sourceId,
    layerId: layerId,
    properties: properties,
    belowLayerId: belowLayerId,
    sourceLayer: sourceLayer,
    minzoom: minzoom,
    maxzoom: maxzoom,
    filter: null,
  );

  @override
  Future<void> addHillshadeLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) => _addStyleLayer(
    type: 'hillshade',
    sourceId: sourceId,
    layerId: layerId,
    properties: properties,
    belowLayerId: belowLayerId,
    sourceLayer: sourceLayer,
    minzoom: minzoom,
    maxzoom: maxzoom,
    filter: null,
  );

  @override
  Future<void> addHeatmapLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) => _addStyleLayer(
    type: 'heatmap',
    sourceId: sourceId,
    layerId: layerId,
    properties: properties,
    belowLayerId: belowLayerId,
    sourceLayer: sourceLayer,
    minzoom: minzoom,
    maxzoom: maxzoom,
    filter: null,
  );

  Future<void> _addStyleLayer({
    required String type,
    required String sourceId,
    required String layerId,
    required Map<String, dynamic> properties,
    required String? belowLayerId,
    required String? sourceLayer,
    required double? minzoom,
    required double? maxzoom,
    required dynamic filter,
    bool enableInteraction = false,
  }) async {
    final (host, sessionId) = _requireSession();
    if (enableInteraction && !_interactiveLayerIds.contains(layerId)) {
      _interactiveLayerIds.add(layerId);
    }
    final layout = <String, dynamic>{};
    final paint = <String, dynamic>{};
    for (final entry in properties.entries) {
      (_layoutPropertyKeys.contains(entry.key) ? layout : paint)[entry.key] =
          entry.value;
    }
    host.send(
      AddLayerJsonCommand(sessionId, <String, dynamic>{
        'id': layerId,
        'type': type,
        'source': sourceId,
        'source-layer': ?sourceLayer,
        'minzoom': ?minzoom,
        'maxzoom': ?maxzoom,
        'filter': ?filter,
        if (layout.isNotEmpty) 'layout': layout,
        if (paint.isNotEmpty) 'paint': paint,
      }, beforeLayerId: belowLayerId),
    );
  }

  // --- Style mutation and introspection --------------------------------------

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    final (host, sessionId) = _requireSession();
    if (properties is ImageSourceProperties) {
      final url = properties.url;
      final coordinates = properties.coordinates;
      if (url != null && coordinates != null && coordinates.length == 4) {
        // A style-spec image source makes the engine core decode the image,
        // and it only handles png/jpeg/webp ("The image format Gif is not
        // supported"); the method-channel backends decode with the platform
        // codecs instead. Fetch and decode here with dart:ui for the same
        // format coverage and hand raw pixels to the engine. An animated GIF
        // yields only its first frame, matching the platform backends
        // (animate by cycling updateImageSource with per-frame images).
        final (rgba, width, height) = await _decodeRgba(await _fetchBytes(url));
        host.send(
          AddImageSourceCommand(
            sessionId,
            sourceId,
            rgba,
            width: width,
            height: height,
            // Style-spec corners are [lng, lat]; the command wants lat, lng.
            coordinates: [
              for (final corner in coordinates) ...[
                (corner[1] as num).toDouble(),
                (corner[0] as num).toDouble(),
              ],
            ],
          ),
        );
        return;
      }
    }
    // The generated SourceProperties.toJson() includes the "type" key.
    host.send(AddSourceJsonCommand(sessionId, sourceId, properties.toJson()));
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    _send(SetGeoJsonSourceDataCommand(_sessionId!, sourceId, geojson));
  }

  @override
  Future<void> setFeatureForGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojsonFeature,
  ) async {
    _send(SetGeoJsonFeatureCommand(_sessionId!, sourceId, geojsonFeature));
  }

  @override
  Future<bool> editGeoJsonSource(String id, String data) async {
    final document = (jsonDecode(data) as Map).cast<String, dynamic>();
    _send(SetGeoJsonSourceDataCommand(_sessionId!, id, document));
    return true;
  }

  @override
  Future<bool> editGeoJsonUrl(String id, String url) async {
    _send(SetGeoJsonSourceUrlCommand(_sessionId!, id, url));
    return true;
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  ) async {
    _send(SetLayerPropertiesCommand(_sessionId!, layerId, properties));
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    _send(
      SetLayerPropertiesCommand(_sessionId!, layerId, <String, dynamic>{
        'visibility': visible ? 'visible' : 'none',
      }),
    );
  }

  @override
  Future<bool?> getLayerVisibility(String layerId) async {
    final (host, sessionId) = _requireSession();
    return host.query(GetLayerVisibilityQuery(sessionId, layerId));
  }

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {
    _send(SetFilterCommand(_sessionId!, layerId, filter));
  }

  @override
  Future<dynamic> getFilter(String layerId) async {
    final (host, sessionId) = _requireSession();
    final encoded = await host.query(GetFilterQuery(sessionId, layerId));
    return encoded == null ? null : jsonDecode(encoded);
  }

  @override
  Future<bool> setLayerFilter(String layerId, String filter) async {
    _send(SetFilterCommand(_sessionId!, layerId, jsonDecode(filter)));
    return true;
  }

  @override
  Future<List> getLayerIds() async {
    final (host, sessionId) = _requireSession();
    return host.query(GetLayerIdsQuery(sessionId));
  }

  @override
  Future<List> getSourceIds() async {
    final (host, sessionId) = _requireSession();
    return host.query(GetSourceIdsQuery(sessionId));
  }

  @override
  Future<String?> getStyle() async {
    final (host, sessionId) = _requireSession();
    return host.query(GetStyleJsonQuery(sessionId));
  }

  // --- Feature queries, interaction, feature state ----------------------------

  @override
  Future<List> queryRenderedFeatures(
    Point<double> point,
    List<String> layerIds,
    List<Object>? filter,
  ) async {
    final (host, sessionId) = _requireSession();
    return host.query(
      QueryRenderedFeaturesQuery.point(
        sessionId,
        x: point.x,
        y: point.y,
        layerIds: layerIds.isEmpty ? null : layerIds,
        filter: filter,
      ),
    );
  }

  @override
  Future<List> queryRenderedFeaturesInRect(
    Rect rect,
    List<String> layerIds,
    String? filter,
  ) async {
    final (host, sessionId) = _requireSession();
    return host.query(
      QueryRenderedFeaturesQuery.rect(
        sessionId,
        left: rect.left,
        top: rect.top,
        right: rect.right,
        bottom: rect.bottom,
        layerIds: layerIds.isEmpty ? null : layerIds,
        filter: filter == null ? null : jsonDecode(filter),
      ),
    );
  }

  @override
  Future<List> querySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object>? filter,
  ) async {
    final (host, sessionId) = _requireSession();
    return host.query(
      QuerySourceFeaturesQuery(
        sessionId,
        sourceId,
        sourceLayerId: sourceLayerId,
        filter: filter,
      ),
    );
  }

  @override
  Future<void> setFeatureState(
    String sourceId,
    String featureId,
    Map<String, dynamic> state, {
    String? sourceLayer,
  }) async {
    _send(
      SetFeatureStateCommand(
        _sessionId!,
        sourceId: sourceId,
        sourceLayerId: sourceLayer,
        featureId: featureId,
        state: state,
      ),
    );
  }

  @override
  Future<void> removeFeatureState(
    String sourceId, {
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  }) async {
    _send(
      RemoveFeatureStateCommand(
        _sessionId!,
        sourceId: sourceId,
        sourceLayerId: sourceLayer,
        featureId: featureId,
        stateKey: stateKey,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>?> getFeatureState(
    String sourceId,
    String featureId, {
    String? sourceLayer,
  }) async {
    final (host, sessionId) = _requireSession();
    return host.query(
      GetFeatureStateQuery(
        sessionId,
        sourceId: sourceId,
        sourceLayerId: sourceLayer,
        featureId: featureId,
      ),
    );
  }

  /// Interactive layer ids ordered topmost first, for hit-testing.
  List<String> get _hitTestLayerIds =>
      _interactiveLayerIds.reversed.toList(growable: false);

  static Object? _featureId(Map<String, dynamic> feature) =>
      feature['id'] ?? (feature['properties'] as Map?)?['id'];

  /// Tap entry point for the map widget: hit-tests the interactive layers and
  /// emits a feature tap (and/or the map click, matching the reference
  /// backends' featureTapsTriggersMapClick semantics).
  Future<void> handleTap(Point<double> point, LatLng latLng) async {
    Map<String, dynamic>? hit;
    if (_interactiveLayerIds.isNotEmpty) {
      final (host, sessionId) = _requireSession();
      hit = await host.query(
        QueryTopFeatureQuery(
          sessionId,
          x: point.x,
          y: point.y,
          layerIds: _hitTestLayerIds,
          // The Android implementation hit-tests taps with a +-10px rect.
          tolerance: 10,
        ),
      );
    }
    if (hit != null) {
      final feature = (hit['feature'] as Map).cast<String, dynamic>();
      onFeatureTappedPlatform(<String, dynamic>{
        'id': _featureId(feature),
        'point': point,
        'latLng': latLng,
        'layerId': hit['layerId'],
      });
      if (!_featureTapsTriggersMapClick) return;
    }
    onMapClickPlatform(<String, dynamic>{'point': point, 'latLng': latLng});
  }

  /// Hit-tests for a draggable feature at [point]; returns the feature map or
  /// null. Called by the widget's pan gesture to arbitrate drag vs camera pan.
  Future<Map<String, dynamic>?> queryDraggableFeature(
    Point<double> point,
  ) async {
    if (!dragEnabled || _interactiveLayerIds.isEmpty) return null;
    final (host, sessionId) = _requireSession();
    final hit = await host.query(
      QueryTopFeatureQuery(
        sessionId,
        x: point.x,
        y: point.y,
        layerIds: _hitTestLayerIds,
        // Finger-sized touch target: without it a feature must be hit on its
        // exact rendered geometry, which makes small symbols nearly
        // ungrabbable (the Android implementation uses a +-10px rect too).
        tolerance: 10,
      ),
    );
    if (hit == null) return null;
    final feature = (hit['feature'] as Map).cast<String, dynamic>();
    final properties = feature['properties'] as Map?;
    return properties?['draggable'] == true ? feature : null;
  }

  /// Emits a feature drag event with the exact payload shape the controller
  /// decodes (eventType is a DragEventType name: start/drag/end).
  void emitFeatureDrag({
    required Map<String, dynamic> feature,
    required Point<double> point,
    required LatLng origin,
    required LatLng current,
    required LatLng delta,
    required String eventType,
  }) {
    // Symbol placement changes normally cross-fade over ~300ms, which makes
    // a dragged symbol trail its position; disable the fade while a drag is
    // active so per-move source updates apply instantly.
    final sessionId = _sessionId;
    if (sessionId != null) {
      if (eventType == 'start') {
        _send(SetPlacementTransitionsCommand(sessionId, enabled: false));
      } else if (eventType == 'end') {
        _send(SetPlacementTransitionsCommand(sessionId, enabled: true));
      }
    }
    onFeatureDraggedPlatform(<String, dynamic>{
      'id': _featureId(feature),
      'point': point,
      'origin': origin,
      'current': current,
      'delta': delta,
      'eventType': eventType,
    });
  }

  // --- Images and image sources -----------------------------------------------

  /// Decodes an encoded image (PNG/JPEG/...) into raw premultiplied RGBA8
  /// pixels; [ui.ImageByteFormat.rawRgba] is premultiplied by contract.
  static Future<(Uint8List, int, int)> _decodeRgba(Uint8List encoded) async {
    final codec = await ui.instantiateImageCodec(encoded);
    try {
      final image = (await codec.getNextFrame()).image;
      final width = image.width;
      final height = image.height;
      // toByteData defaults to ImageByteFormat.rawRgba, which is
      // premultiplied per its contract (rawStraightRgba is the straight one).
      final data = await image.toByteData();
      image.dispose();
      if (data == null) {
        throw StateError('could not decode image pixels');
      }
      return (
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width,
        height,
      );
    } finally {
      codec.dispose();
    }
  }

  /// Reads image bytes for an image source: http(s) URLs from the network,
  /// anything else from the Flutter asset bundle.
  static Future<Uint8List> _fetchBytes(String url) async {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final client = HttpClient();
      try {
        final uri = Uri.parse(url);
        final response = await (await client.getUrl(uri)).close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('HTTP ${response.statusCode}', uri: uri);
        }
        final builder = BytesBuilder(copy: false);
        await response.forEach(builder.add);
        return builder.takeBytes();
      } finally {
        client.close();
      }
    }
    final data = await rootBundle.load(url);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static List<double> _quadToList(LatLngQuad coordinates) => <double>[
    coordinates.topLeft.latitude,
    coordinates.topLeft.longitude,
    coordinates.topRight.latitude,
    coordinates.topRight.longitude,
    coordinates.bottomRight.latitude,
    coordinates.bottomRight.longitude,
    coordinates.bottomLeft.latitude,
    coordinates.bottomLeft.longitude,
  ];

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool sdf = false,
  ]) async {
    final (host, sessionId) = _requireSession();
    final (rgba, width, height) = await _decodeRgba(bytes);
    host.send(
      SetStyleImageCommand(
        sessionId,
        name,
        rgba,
        width: width,
        height: height,
        sdf: sdf,
      ),
    );
  }

  @override
  Future<void> addImageSource(
    String imageSourceId,
    Uint8List bytes,
    LatLngQuad coordinates,
  ) async {
    final (host, sessionId) = _requireSession();
    final (rgba, width, height) = await _decodeRgba(bytes);
    host.send(
      AddImageSourceCommand(
        sessionId,
        imageSourceId,
        rgba,
        width: width,
        height: height,
        coordinates: _quadToList(coordinates),
      ),
    );
  }

  @override
  Future<void> updateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    LatLngQuad? coordinates,
  ) async {
    final (host, sessionId) = _requireSession();
    final (rgba, width, height) = bytes == null
        ? (null, null, null)
        : await _decodeRgba(bytes);
    host.send(
      UpdateImageSourceCommand(
        sessionId,
        imageSourceId,
        rgba: rgba,
        width: width,
        height: height,
        coordinates: coordinates == null ? null : _quadToList(coordinates),
      ),
    );
  }

  @override
  Future<void> addLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  ) async {
    final (host, sessionId) = _requireSession();
    host.send(
      AddLayerJsonCommand(sessionId, <String, dynamic>{
        'id': imageLayerId,
        'type': 'raster',
        'source': imageSourceId,
        'minzoom': ?minzoom,
        'maxzoom': ?maxzoom,
      }),
    );
  }

  @override
  Future<void> addLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  ) async {
    final (host, sessionId) = _requireSession();
    host.send(
      AddLayerJsonCommand(sessionId, <String, dynamic>{
        'id': imageLayerId,
        'type': 'raster',
        'source': imageSourceId,
        'minzoom': ?minzoom,
        'maxzoom': ?maxzoom,
      }, beforeLayerId: belowLayerId),
    );
  }

  // --- Camera constraints and insets ------------------------------------------

  @override
  Future<void> setCameraBounds({
    required double west,
    required double north,
    required double south,
    required double east,
    required int padding,
  }) async {
    // The reference implementations constrain the camera target only; the
    // padding argument has no native counterpart and is ignored there too.
    _send(
      SetBoundsCommand(
        _sessionId!,
        southwestLatitude: south,
        southwestLongitude: west,
        northeastLatitude: north,
        northeastLongitude: east,
      ),
    );
  }

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) async {
    _send(
      SetPaddingCommand(
        _sessionId!,
        left: insets.left,
        top: insets.top,
        right: insets.right,
        bottom: insets.bottom,
        durationMs: animated ? 300 : null,
      ),
    );
  }

  // --- Location component --------------------------------------------------------

  static const _locationTopImage = 'maplibre-gl-native-location-top';
  static const _locationBearingImage = 'maplibre-gl-native-location-bearing';

  bool _myLocationEnabled = false;
  bool _locationImagesRegistered = false;
  bool _locationIndicatorVisible = false;
  int _myLocationRenderMode = 0; // MyLocationRenderMode.normal index.
  MyLocationTrackingMode _trackingMode = MyLocationTrackingMode.none;
  UserLocation? _lastLocation;

  void _applyLocationOptions(Map<String, dynamic> options) {
    final renderMode = options['myLocationRenderMode'];
    if (renderMode is int) _myLocationRenderMode = renderMode;
    final trackingMode = options['myLocationTrackingMode'];
    if (trackingMode is int &&
        trackingMode >= 0 &&
        trackingMode < MyLocationTrackingMode.values.length) {
      final mode = MyLocationTrackingMode.values[trackingMode];
      if (mode != _trackingMode) {
        _trackingMode = mode;
        onCameraTrackingChangedPlatform(mode);
        // Snap to the last known fix right away instead of waiting for the
        // next one, like the reference backends do on mode changes.
        final host = _host;
        final sessionId = _sessionId;
        final location = _lastLocation;
        if (host != null && sessionId != null && location != null) {
          _maybeTrackCamera(host, sessionId, location);
        }
      }
    }
    final enabled = options['myLocationEnabled'];
    if (enabled is bool && enabled != _myLocationEnabled) {
      _myLocationEnabled = enabled;
      if (_sessionId != null) {
        unawaited(enabled ? _enableLocation() : _disableLocation());
      }
    }
  }

  Future<void> _enableLocation() async {
    // The bridge streams one process-wide fix; the platform of the most
    // recently enabled map consumes it.
    MapLibreGlNativeBridge.onLocationUpdate = _onLocationFix;
    final started = await MapLibreGlNativeBridge.startLocationUpdates();
    if (!started) {
      debugPrint(
        '[maplibre_gl_native] myLocationEnabled: platform location updates '
        'could not start (missing permission?)',
      );
    }
    // The puck is shown lazily on the first fix: the layer's style-spec
    // default location is (0, 0), so showing it earlier would render the
    // puck at Null Island.
    if (_lastLocation != null) await _showLocationIndicator();
  }

  Future<void> _disableLocation() async {
    if (identical(MapLibreGlNativeBridge.onLocationUpdate, _onLocationFix)) {
      MapLibreGlNativeBridge.onLocationUpdate = null;
    }
    await MapLibreGlNativeBridge.stopLocationUpdates();
    _locationIndicatorVisible = false;
    final (host, sessionId) = _requireSession();
    host.send(RemoveLocationIndicatorCommand(sessionId));
  }

  Future<void> _showLocationIndicator() async {
    final (host, sessionId) = _requireSession();
    _locationIndicatorVisible = true;
    if (!_locationImagesRegistered) {
      _locationImagesRegistered = true;
      final top = await _drawPuck(withBearing: false);
      final bearing = await _drawPuck(withBearing: true);
      host.send(
        SetStyleImageCommand(
          sessionId,
          _locationTopImage,
          top.$1,
          width: top.$2,
          height: top.$3,
          pixelRatio: 2,
        ),
      );
      host.send(
        SetStyleImageCommand(
          sessionId,
          _locationBearingImage,
          bearing.$1,
          width: bearing.$2,
          height: bearing.$3,
          pixelRatio: 2,
        ),
      );
    }
    host.send(
      ShowLocationIndicatorCommand(
        sessionId,
        topImage: _locationTopImage,
        // The bearing puck is used for the compass/gps render modes.
        bearingImage: _myLocationRenderMode == 0 ? null : _locationBearingImage,
      ),
    );
    final location = _lastLocation;
    if (location != null) _sendLocationIndicatorUpdate(location);
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

  void _onLocationFix(Map<Object?, Object?> fix) {
    final host = _host;
    final sessionId = _sessionId;
    if (host == null || sessionId == null || !_myLocationEnabled) return;
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
    onUserLocationUpdatedPlatform(location);
    if (_locationIndicatorVisible) {
      _sendLocationIndicatorUpdate(location);
    } else {
      // First fix: show the puck now (ends by pushing this location).
      unawaited(_showLocationIndicator());
    }
    _maybeTrackCamera(host, sessionId, location);
  }

  void _sendLocationIndicatorUpdate(UserLocation location) {
    final host = _host;
    final sessionId = _sessionId;
    if (host == null || sessionId == null) return;
    host.send(
      UpdateLocationIndicatorCommand(
        sessionId,
        latitude: location.position.latitude,
        longitude: location.position.longitude,
        bearing: _myLocationRenderMode == 0 ? null : location.bearing,
        accuracyRadius: location.horizontalAccuracy,
      ),
    );
  }

  void _maybeTrackCamera(
    EngineHost host,
    int sessionId,
    UserLocation location,
  ) {
    if (_trackingMode == MyLocationTrackingMode.none) return;
    final followBearing = _trackingMode != MyLocationTrackingMode.tracking;
    host.send(
      EaseToCommand(
        sessionId,
        CameraSpec(
          latitude: location.position.latitude,
          longitude: location.position.longitude,
          bearing: followBearing ? location.bearing : null,
        ),
        durationMs: 500,
      ),
    );
  }

  @override
  Future<void> updateMyLocationTrackingMode(
    MyLocationTrackingMode myLocationTrackingMode,
  ) async {
    _trackingMode = myLocationTrackingMode;
    onCameraTrackingChangedPlatform(myLocationTrackingMode);
    final host = _host;
    final sessionId = _sessionId;
    final location = _lastLocation;
    if (host != null && sessionId != null && location != null) {
      _maybeTrackCamera(host, sessionId, location);
    }
  }

  @override
  Future<LatLng?> requestMyLocationLatLng() async => _lastLocation?.position;

  /// Called by the map widget when a user gesture pans the camera:
  /// dismisses an active tracking mode like the reference backends.
  void notifyUserGesture() {
    if (_trackingMode == MyLocationTrackingMode.none) return;
    _trackingMode = MyLocationTrackingMode.none;
    // The Android LocationComponent emits both: the mode change to none and
    // the dismissal event. Apps typically listen to the former.
    onCameraTrackingChangedPlatform(MyLocationTrackingMode.none);
    onCameraTrackingDismissedPlatform(null);
  }

  /// Distinct attribution strings of the current style's sources, for the
  /// attribution ornament.
  Future<List<String>> getAttributions() async {
    final (host, sessionId) = _requireSession();
    return host.query(GetAttributionsQuery(sessionId));
  }

  // --- Snapshots and language --------------------------------------------------

  int _nextSnapshotRequestId = 1;
  final Map<int, Completer<Uint8List>> _pendingSnapshots =
      <int, Completer<Uint8List>>{};

  @override
  Future<Uint8List> takeSnapshot({int? width, int? height}) async {
    // The offscreen still image renders at the current surface size; the
    // explicit width/height override is not supported yet.
    final (host, sessionId) = _requireSession();
    final requestId = _nextSnapshotRequestId++;
    final completer = Completer<Uint8List>();
    _pendingSnapshots[requestId] = completer;
    host.send(TakeSnapshotCommand(sessionId, requestId));
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingSnapshots.remove(requestId);
        throw TimeoutException('takeSnapshot timed out');
      },
    );
  }

  void _resolveSnapshot(SnapshotResultEvent event) {
    final completer = _pendingSnapshots.remove(event.requestId);
    if (completer == null) return;
    final rgba = event.rgba;
    if (event.error != null || rgba == null) {
      completer.completeError(
        StateError(event.error ?? 'snapshot render produced no image'),
      );
      return;
    }
    unawaited(
      _encodeSnapshotPng(event).then(
        completer.complete,
        onError: completer.completeError,
      ),
    );
  }

  static Future<Uint8List> _encodeSnapshotPng(
    SnapshotResultEvent snapshot,
  ) async {
    var pixels = snapshot.rgba!;
    final rowBytes = snapshot.width * 4;
    if (snapshot.stride != rowBytes) {
      final packed = Uint8List(rowBytes * snapshot.height);
      for (var y = 0; y < snapshot.height; y++) {
        packed.setRange(
          y * rowBytes,
          (y + 1) * rowBytes,
          pixels,
          y * snapshot.stride,
        );
      }
      pixels = packed;
    }
    final decoded = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      snapshot.width,
      snapshot.height,
      ui.PixelFormat.rgba8888,
      decoded.complete,
    );
    final image = await decoded.future;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('could not encode the snapshot as PNG');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  @override
  Future<void> setMapLanguage(String language) async {
    _send(SetMapLanguageCommand(_sessionId!, language));
  }

  @override
  Future<void> matchMapLanguageWithDeviceDefault() =>
      setMapLanguage(ui.PlatformDispatcher.instance.locale.languageCode);

  // --- HTTP headers, cache, network -------------------------------------------

  Map<String, String> _customHeaders = const {};

  @override
  Future<void> setCustomHeaders(
    Map<String, String> headers,
    List<String> filter,
  ) async {
    final (host, _) = _requireSession();
    _customHeaders = Map.of(headers);
    // The engine runtime (and its Dart HTTP provider) is shared per process,
    // so per-map headers apply engine-wide, like the reference backends'
    // per-view header maps applied to the shared HTTP stack.
    host.send(SetHttpHeadersCommand(headers, urlFilters: filter));
  }

  @override
  Future<Map<String, String>> getCustomHeaders() async =>
      Map.of(_customHeaders);

  @override
  Future<void> forceOnlineMode() async {
    final (host, _) = _requireSession();
    host.send(const SetNetworkStatusCommand(online: true));
  }

  @override
  Future invalidateAmbientCache() async {
    final (host, _) = _requireSession();
    host.send(
      const RunAmbientCacheOperationCommand(
        AmbientCacheOperationKind.invalidate,
      ),
    );
  }

  @override
  Future clearAmbientCache() async {
    final (host, _) = _requireSession();
    host.send(
      const RunAmbientCacheOperationCommand(AmbientCacheOperationKind.clear),
    );
  }

  // --- No-ops that keep the shared widget/controller flow working ----------

  @override
  Future<void> setTelemetryEnabled(bool enabled) async {
    // The MapLibre Native core has no telemetry.
  }

  @override
  Future<bool> getTelemetryEnabled() async => false;

  @override
  void resizeWebMap() {
    // Web-only; mirrors the Android/iOS no-op behavior.
  }

  @override
  void forceResizeWebMap() {
    // Web-only; mirrors the Android/iOS no-op behavior.
  }

  @override
  Future<Size> setWebMapToCustomSize(Size size) async {
    // Web-only; the native backends return the requested size unchanged.
    return size;
  }

  @override
  Future<void> waitUntilMapIsIdleAfterMovement() async {
    // Test helper with no native counterpart; the method-channel backends
    // no-op it too.
  }

  @override
  Future<void> waitUntilMapTilesAreLoaded() async {
    // Test helper with no native counterpart; the method-channel backends
    // no-op it too.
  }

  @override
  Future<void> setMaximumFps(int fps) async {
    // Honored by the engine-isolate frame driver; the single-isolate engine
    // is paced by the widget's vsync ticker and ignores the cap.
    final (host, _) = _requireSession();
    host.send(SetMaximumFpsCommand(fps));
  }

  @override
  Future<void> setFrameStatsEnabled(bool enabled) async {
    final (host, sessionId) = _requireSession();
    host.send(SetFrameStatsEnabledCommand(sessionId, enabled: enabled));
  }

  @override
  Future<Map<String, dynamic>?> takeFrameStats() {
    final (host, sessionId) = _requireSession();
    return host.query(TakeFrameStatsQuery(sessionId));
  }
}
