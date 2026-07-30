import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

import '../../engine/engine_host.dart';
import '../../engine/map_session.dart';
import '../../protocol/protocol.dart';
import '../map/map_view.dart';
import 'camera_update_codec.dart';
import 'feature_interaction.dart';
import 'ffi_platform_base.dart';
import 'image_codec.dart';
import 'location_component.dart';
import 'map_options.dart';
import '../ornaments/ornament_config.dart';
import 'snapshot_service.dart';
import 'style_layers.dart';
import 'style_string_resolver.dart';
import '../../utils/projection.dart';

/// [MapLibrePlatform] backend implemented over the MapLibre Native C API via
/// dart:ffi, rendering into a Flutter [Texture].
///
/// Pure protocol adapter: translates the platform-interface contract into
/// [EngineHost] commands/queries and engine events back into the platform
/// callback sinks. It never touches a native handle directly.
///
/// Covers nearly the whole `MapLibrePlatform` contract (see the package
/// README's "API coverage" section for the current list and the few known
/// gaps); the remaining unimplemented methods throw through
/// [MapLibreFfiPlatformBase].
class MapLibreFfiPlatform extends MapLibreFfiPlatformBase {
  /// The live map session, set by [attach] once the widget has created it.
  MapSession? _session;
  final _ready = Completer<void>();

  /// Gesture flags consumed by the map widget.
  final gestures = GestureConfig();

  /// Ornament (compass, attribution, logo) configuration consumed by the map
  /// widget.
  final ornaments = OrnamentConfig();

  /// Hit-testing of the interactive layers and the feature tap/drag events
  /// that come out of it; also consumed directly by the gesture handler.
  late final FeatureInteraction features = FeatureInteraction(
    session: () => _session,
    onFeatureTapped: onFeatureTappedPlatform.call,
    onMapClick: onMapClickPlatform.call,
    onFeatureDragged: onFeatureDraggedPlatform.call,
  );

  MapSession _requireSession() => requireSession(_session);

  void _send(EngineCommand command) => _requireSession().send(command);

  /// Called by the widget once the texture, map, and render session exist.
  void attach(MapSession session) {
    _session = session;
    session.host.addEventListener(_onEngineEvent);
    _location.onSessionAttached();
    if (!_ready.isCompleted) _ready.complete();
  }

  void _onEngineEvent(EngineEvent event) {
    // Engine-scoped events (the offline database) are not ours: they have
    // their own listener in MapLibreGlNativeOffline.
    if (event is! SessionEvent || event.sessionId != _session?.id) return;
    switch (event) {
      case CameraWillChangeEvent():
        onCameraMoveStartedPlatform(null);
      case CameraIsChangingEvent():
        onCameraMovePlatform(_toCameraPosition(event.camera));
      case MapIdleEvent():
        onCameraIdlePlatform(_toCameraPosition(event.camera));
        onMapIdlePlatform(null);
      case StyleLoadedEvent():
        _location.onStyleLoaded();
        onMapStyleLoadedPlatform(null);
      case SnapshotResultEvent():
        _snapshots.resolve(event);
      case MapLoadingFailedEvent() || RenderPendingEvent():
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
    final session = _requireSession();
    return _toCameraPosition(await session.query(GetCameraQuery(session.id)));
  }

  // Lifecycle.

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
    _location.applyOptions(options);
    ornaments.applyOptions(options);
    features.dragEnabled = creationParams['dragEnabled'] as bool? ?? true;
    return MapView(
      platform: this,
      creationParams: creationParams,
      onViewCreated: onPlatformViewCreated,
    );
  }

  @override
  void dispose() {
    // The widget owns the session and the texture; just drop the references.
    _session?.host.removeEventListener(_onEngineEvent);
    _session = null;
    super.dispose();
  }

  // Map options.

  void _applyGestureOptions(Map<String, dynamic> options) =>
      applyGestureOptions(
        options,
        gestures: gestures,
        setFeatureTapsTriggersMapClick: (enabled) =>
            features.featureTapsTriggersMapClick = enabled,
      );

  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> optionsUpdate,
  ) async {
    _applyGestureOptions(optionsUpdate);
    _location.applyOptions(optionsUpdate);
    ornaments.applyOptions(optionsUpdate);
    final styleString = optionsUpdate['styleString'];
    if (styleString is String) {
      await setStyle(styleString);
    }
    _applyConstraintOptions(optionsUpdate);
    return _currentCameraPosition();
  }

  void _applyConstraintOptions(Map<String, dynamic> options) {
    final session = _requireSession();
    cameraConstraintCommands(options, session.id).forEach(session.send);
  }

  // Camera.

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
      durationMs: _durationMs(duration),
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
      durationMs: _durationMs(duration),
      easing: easingCurve(interpolation),
    );
    return true;
  }

  static double _durationMs(Duration? duration) =>
      (duration ?? defaultCameraAnimationDuration).inMilliseconds.toDouble();

  void _applyCameraUpdate(
    CameraUpdate update, {
    required double? durationMs,
    required List<double>? easing,
  }) {
    final session = _requireSession();
    session.send(
      cameraUpdateCommand(
        update,
        sessionId: session.id,
        durationMs: durationMs,
        easing: easing,
      ),
    );
  }

  @override
  Future<CameraPosition?> queryCameraPosition() => _currentCameraPosition();

  @override
  Future<LatLngBounds> getVisibleRegion() async {
    final session = _requireSession();
    final region = await session.query(GetVisibleRegionQuery(session.id));
    return LatLngBounds(
      southwest: LatLng(region.south, region.west),
      northeast: LatLng(region.north, region.east),
    );
  }

  // Projection.

  @override
  Future<Point> toScreenLocation(LatLng latLng) async {
    final session = _requireSession();
    final point = await session.query(
      PixelForLatLngQuery(session.id, latLng.latitude, latLng.longitude),
    );
    return Point<double>(point.x, point.y);
  }

  @override
  Future<List<Point>> toScreenLocationBatch(Iterable<LatLng> latLngs) async {
    final session = _requireSession();
    final coordinates = latLngs.toList(growable: false);
    final pairs = Float64List(coordinates.length * 2);
    for (var i = 0; i < coordinates.length; i++) {
      pairs[i * 2] = coordinates[i].latitude;
      pairs[i * 2 + 1] = coordinates[i].longitude;
    }
    final points = await session.query(
      PixelsForLatLngsQuery(session.id, pairs),
    );
    return [
      for (var i = 0; i + 1 < points.length; i += 2)
        Point<double>(points[i], points[i + 1]),
    ];
  }

  @override
  Future<LatLng> toLatLng(Point screenLocation) async {
    final session = _requireSession();
    final coordinate = await session.query(
      LatLngForPixelQuery(
        session.id,
        screenLocation.x.toDouble(),
        screenLocation.y.toDouble(),
      ),
    );
    return LatLng(coordinate.latitude, coordinate.longitude);
  }

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) async {
    final session = _requireSession();
    final camera = await session.query(GetCameraQuery(session.id));
    return MercatorProjection.metersPerPixel(latitude, camera.zoom);
  }

  // Style.

  @override
  Future<void> setStyle(String styleString) async {
    final session = _requireSession();
    // Asset and file styles must be read here on the root isolate; the
    // engine only accepts raw JSON or http(s) URLs.
    final resolved = await resolveStyleString(styleString);
    session.send(SetStyleCommand(session.id, resolved));
  }

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) async {
    final session = _requireSession();
    session.send(
      AddSourceJsonCommand(session.id, sourceId, <String, dynamic>{
        'type': 'geojson',
        'data': geojson,
        'promoteId': ?promoteId,
      }),
    );
  }

  @override
  Future<void> removeSource(String sourceId) async {
    _send(RemoveSourceCommand(_requireSession().id, sourceId));
  }

  @override
  Future<void> removeLayer(String imageLayerId) async {
    features.unregisterLayer(imageLayerId);
    _send(RemoveLayerCommand(_requireSession().id, imageLayerId));
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
    type: StyleLayerType.symbol,
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
    type: StyleLayerType.line,
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
    type: StyleLayerType.circle,
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
    type: StyleLayerType.fill,
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
    type: StyleLayerType.fillExtrusion,
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
    type: StyleLayerType.raster,
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
    type: StyleLayerType.hillshade,
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
    type: StyleLayerType.heatmap,
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
    required StyleLayerType type,
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
    final session = _requireSession();
    if (enableInteraction) features.registerLayer(layerId);
    session.send(
      AddLayerJsonCommand(
        session.id,
        styleLayerJson(
          type: type,
          sourceId: sourceId,
          layerId: layerId,
          properties: properties,
          sourceLayer: sourceLayer,
          minzoom: minzoom,
          maxzoom: maxzoom,
          filter: filter,
        ),
        beforeLayerId: belowLayerId,
      ),
    );
  }

  // Style mutation and introspection.

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    final session = _requireSession();
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
        final (rgba, width, height) = await decodeRgba(
          await fetchImageBytes(url),
        );
        session.send(
          AddImageSourceCommand(
            session.id,
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
    session.send(
      AddSourceJsonCommand(session.id, sourceId, properties.toJson()),
    );
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    _send(SetGeoJsonSourceDataCommand(_requireSession().id, sourceId, geojson));
  }

  @override
  Future<void> setFeatureForGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojsonFeature,
  ) async {
    _send(
      SetGeoJsonFeatureCommand(_requireSession().id, sourceId, geojsonFeature),
    );
  }

  @override
  Future<bool> editGeoJsonSource(String id, String data) async {
    final document = (jsonDecode(data) as Map).cast<String, dynamic>();
    _send(SetGeoJsonSourceDataCommand(_requireSession().id, id, document));
    return true;
  }

  @override
  Future<bool> editGeoJsonUrl(String id, String url) async {
    _send(SetGeoJsonSourceUrlCommand(_requireSession().id, id, url));
    return true;
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  ) async {
    _send(SetLayerPropertiesCommand(_requireSession().id, layerId, properties));
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    _send(
      SetLayerPropertiesCommand(
        _requireSession().id,
        layerId,
        <String, dynamic>{
          'visibility': visible ? 'visible' : 'none',
        },
      ),
    );
  }

  @override
  Future<bool?> getLayerVisibility(String layerId) async {
    final session = _requireSession();
    return session.query(GetLayerVisibilityQuery(session.id, layerId));
  }

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {
    _send(SetFilterCommand(_requireSession().id, layerId, filter));
  }

  @override
  Future<dynamic> getFilter(String layerId) async {
    final session = _requireSession();
    final encoded = await session.query(GetFilterQuery(session.id, layerId));
    return encoded == null ? null : jsonDecode(encoded);
  }

  @override
  Future<bool> setLayerFilter(String layerId, String filter) async {
    _send(SetFilterCommand(_requireSession().id, layerId, jsonDecode(filter)));
    return true;
  }

  @override
  Future<List> getLayerIds() async {
    final session = _requireSession();
    return session.query(GetLayerIdsQuery(session.id));
  }

  @override
  Future<List> getSourceIds() async {
    final session = _requireSession();
    return session.query(GetSourceIdsQuery(session.id));
  }

  @override
  Future<String?> getStyle() async {
    final session = _requireSession();
    return session.query(GetStyleJsonQuery(session.id));
  }

  // Feature queries, interaction, feature state.

  @override
  Future<List> queryRenderedFeatures(
    Point<double> point,
    List<String> layerIds,
    List<Object>? filter,
  ) async {
    final session = _requireSession();
    return session.query(
      QueryRenderedFeaturesQuery.point(
        session.id,
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
    final session = _requireSession();
    return session.query(
      QueryRenderedFeaturesQuery.rect(
        session.id,
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
    final session = _requireSession();
    return session.query(
      QuerySourceFeaturesQuery(
        session.id,
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
        _requireSession().id,
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
        _requireSession().id,
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
    final session = _requireSession();
    return session.query(
      GetFeatureStateQuery(
        session.id,
        sourceId: sourceId,
        sourceLayerId: sourceLayer,
        featureId: featureId,
      ),
    );
  }

  // Images and image sources.

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool sdf = false,
  ]) async {
    final session = _requireSession();
    final (rgba, width, height) = await decodeRgba(bytes);
    session.send(
      SetStyleImageCommand(
        session.id,
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
    final session = _requireSession();
    final (rgba, width, height) = await decodeRgba(bytes);
    session.send(
      AddImageSourceCommand(
        session.id,
        imageSourceId,
        rgba,
        width: width,
        height: height,
        coordinates: imageSourceCorners(coordinates),
      ),
    );
  }

  @override
  Future<void> updateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    LatLngQuad? coordinates,
  ) async {
    final session = _requireSession();
    final (rgba, width, height) = bytes == null
        ? (null, null, null)
        : await decodeRgba(bytes);
    session.send(
      UpdateImageSourceCommand(
        session.id,
        imageSourceId,
        rgba: rgba,
        width: width,
        height: height,
        coordinates: coordinates == null
            ? null
            : imageSourceCorners(coordinates),
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
    final session = _requireSession();
    session.send(
      AddLayerJsonCommand(session.id, <String, dynamic>{
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
    final session = _requireSession();
    session.send(
      AddLayerJsonCommand(session.id, <String, dynamic>{
        'id': imageLayerId,
        'type': 'raster',
        'source': imageSourceId,
        'minzoom': ?minzoom,
        'maxzoom': ?maxzoom,
      }, beforeLayerId: belowLayerId),
    );
  }

  // Camera constraints and insets.

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
        _requireSession().id,
        bounds: BoundsConstraintSpec.bounded(
          BoundsSpec(south: south, west: west, north: north, east: east),
        ),
      ),
    );
  }

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) async {
    _send(
      SetPaddingCommand(
        _requireSession().id,
        left: insets.left,
        top: insets.top,
        right: insets.right,
        bottom: insets.bottom,
        durationMs: animated ? 300 : null,
      ),
    );
  }

  /// The myLocation subsystem: puck, tracking modes, platform fixes.
  late final LocationComponent _location = LocationComponent(
    session: () => _session,
    onLocationUpdated: onUserLocationUpdatedPlatform.call,
    onTrackingModeChanged: onCameraTrackingChangedPlatform.call,
    onTrackingDismissed: () => onCameraTrackingDismissedPlatform(null),
  );

  @override
  Future<void> updateMyLocationTrackingMode(
    MyLocationTrackingMode myLocationTrackingMode,
  ) async => _location.setTrackingMode(myLocationTrackingMode);

  @override
  Future<LatLng?> requestMyLocationLatLng() async => _location.lastPosition;

  /// Called by the map widget when a user gesture pans the camera:
  /// dismisses an active tracking mode like the reference backends.
  void notifyUserGesture() => _location.notifyUserGesture();

  /// Distinct attribution strings of the current style's sources, for the
  /// attribution ornament.
  Future<List<String>> getAttributions() async {
    final session = _requireSession();
    return session.query(GetAttributionsQuery(session.id));
  }

  // Snapshots and language.

  /// Offscreen snapshots, correlated by request id.
  late final SnapshotService _snapshots = SnapshotService(_requireSession);

  @override
  Future<Uint8List> takeSnapshot({int? width, int? height}) =>
      _snapshots.take(width: width, height: height);

  @override
  Future<void> setMapLanguage(String language) async {
    _send(SetMapLanguageCommand(_requireSession().id, language));
  }

  @override
  Future<void> matchMapLanguageWithDeviceDefault() =>
      setMapLanguage(ui.PlatformDispatcher.instance.locale.languageCode);

  // HTTP headers, cache, network.

  Map<String, String> _customHeaders = const {};

  @override
  Future<void> setCustomHeaders(
    Map<String, String> headers,
    List<String> filter,
  ) async {
    final session = _requireSession();
    _customHeaders = Map.of(headers);
    // The engine runtime (and its Dart HTTP provider) is shared per process,
    // so per-map headers apply engine-wide, like the reference backends'
    // per-view header maps applied to the shared HTTP stack.
    session.send(SetHttpHeadersCommand(headers, urlFilters: filter));
  }

  @override
  Future<Map<String, String>> getCustomHeaders() async =>
      Map.of(_customHeaders);

  @override
  Future<void> forceOnlineMode() async {
    final session = _requireSession();
    session.send(const SetNetworkStatusCommand(online: true));
  }

  @override
  Future invalidateAmbientCache() async {
    final session = _requireSession();
    session.send(
      const RunAmbientCacheOperationCommand(
        AmbientCacheOperationKind.invalidate,
      ),
    );
  }

  @override
  Future clearAmbientCache() async {
    final session = _requireSession();
    session.send(
      const RunAmbientCacheOperationCommand(AmbientCacheOperationKind.clear),
    );
  }

  // No-ops that keep the shared widget/controller flow working.

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
    final session = _requireSession();
    session.send(SetMaximumFpsCommand(fps));
  }

  @override
  Future<void> setFrameStatsEnabled(bool enabled) async {
    final session = _requireSession();
    session.send(SetFrameStatsEnabledCommand(session.id, enabled: enabled));
  }

  @override
  Future<Map<String, dynamic>?> takeFrameStats() {
    final session = _requireSession();
    return session.query(TakeFrameStatsQuery(session.id));
  }
}
