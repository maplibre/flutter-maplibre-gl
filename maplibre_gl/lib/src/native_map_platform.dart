part of '../maplibre_gl.dart';

/// The [MapLibrePlatform] of Android and iOS: one per map, talking to the
/// native map through the messages generated from `pigeons/messages.dart`.
///
/// The messages of each map travel on their own channels, told apart by the
/// platform view id [initPlatform] receives. Native answers each call with
/// the payload the method channel these messages replace answered with, so
/// the replies are parsed here exactly as they were there.
class _MapLibreNativePlatform extends MapLibrePlatform
    implements MapLibreMapFlutterApi {
  _MapLibreNativePlatform([this._hostApiFactory]);

  /// Builds the client of the map with the given id in place of the
  /// generated one, for tests. See [MapLibreNativePlugin.registerWith].
  final MapLibreMapHostApi Function(int id)? _hostApiFactory;

  /// The platform view id, set by [initPlatform]. A map widget can be
  /// disposed before its platform view exists, so [dispose] has to cope with
  /// this never being set.
  int? _viewId;

  MapLibreMapHostApi? _hostApi;

  MapLibreMapHostApi get _api =>
      _hostApi ??
      (throw StateError(
        'The map is not ready: its platform view has not been created yet.',
      ));

  @override
  Future<void> initPlatform(int id) async {
    _viewId = id;
    // Listen before the first call: native may report events, such as the
    // style loading, before it answers waitForMap.
    MapLibreMapFlutterApi.setUp(this, messageChannelSuffix: '$id');
    final api =
        _hostApiFactory?.call(id) ??
        MapLibreMapHostApi(messageChannelSuffix: '$id');
    _hostApi = api;
    await api.mapWaitForMap();
  }

  @override
  void dispose() {
    final id = _viewId;
    if (id != null) {
      MapLibreMapFlutterApi.setUp(null, messageChannelSuffix: '$id');
    }
    super.dispose();
  }

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // The flag lives on MapLibreMethodChannel because
      // MapLibreMap.useHybridComposition has always stored it there.
      // ignore: deprecated_member_use
      final useHybridComposition = MapLibreMethodChannel.useHybridComposition;
      creationParams['options']?['useHybridComposition'] = useHybridComposition;
      if (useHybridComposition) {
        return PlatformViewLink(
          viewType: 'plugins.flutter.io/maplibre_gl',
          surfaceFactory: (context, controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers:
                  gestureRecognizers ??
                  const <Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
          onCreatePlatformView: (params) {
            final controller = PlatformViewsService.initAndroidView(
              id: params.id,
              viewType: 'plugins.flutter.io/maplibre_gl',
              layoutDirection: TextDirection.ltr,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
              onFocus: () => params.onFocusChanged(true),
            );

            controller.addOnPlatformViewCreatedListener(
              params.onPlatformViewCreated,
            );
            controller.addOnPlatformViewCreatedListener(onPlatformViewCreated);

            unawaited(controller.create());
            return controller;
          },
        );
      } else {
        return AndroidView(
          viewType: 'plugins.flutter.io/maplibre_gl',
          onPlatformViewCreated: onPlatformViewCreated,
          gestureRecognizers: gestureRecognizers,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'plugins.flutter.io/maplibre_gl',
        onPlatformViewCreated: onPlatformViewCreated,
        gestureRecognizers: gestureRecognizers,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return Text(
      '$defaultTargetPlatform is not yet supported by the maps plugin',
    );
  }

  // Events from native.

  @override
  Future<void> featureOnTap(PgFeatureTap tap) async {
    onFeatureTappedPlatform({
      'id': tap.id,
      'point': Point<double>(tap.point.x, tap.point.y),
      'latLng': _latLng(tap.latLng),
      'layerId': tap.layerId,
    });
  }

  @override
  Future<void> featureOnDrag(PgFeatureDrag drag) async {
    onFeatureDraggedPlatform({
      'id': drag.id,
      'point': Point<double>(drag.point.x, drag.point.y),
      'origin': _latLng(drag.origin),
      'current': _latLng(drag.current),
      'delta': _latLng(drag.delta),
      'eventType': drag.eventType,
    });
  }

  @override
  Future<void> cameraOnMoveStarted(bool isGesture) async {
    // Not exposed yet, as the method channel never passed it on: telling the
    // user's moves from the app's is #1019.
    onCameraMoveStartedPlatform(null);
  }

  @override
  Future<void> cameraOnMove(PgCameraPosition position) async {
    onCameraMovePlatform(_cameraPosition(position));
  }

  @override
  Future<void> cameraOnIdle(PgCameraPosition? position) async {
    onCameraIdlePlatform(position == null ? null : _cameraPosition(position));
  }

  @override
  Future<void> mapOnStyleLoaded() async {
    onMapStyleLoadedPlatform(null);
  }

  @override
  Future<void> mapOnMapClick(PgScreenPoint point, PgLatLng latLng) async {
    onMapClickPlatform({
      'point': Point<double>(point.x, point.y),
      'latLng': _latLng(latLng),
    });
  }

  @override
  Future<void> mapOnMapLongClick(PgScreenPoint point, PgLatLng latLng) async {
    onMapLongClickPlatform({
      'point': Point<double>(point.x, point.y),
      'latLng': _latLng(latLng),
    });
  }

  @override
  Future<void> mapOnCameraTrackingChanged(int mode) async {
    onCameraTrackingChangedPlatform(MyLocationTrackingMode.values[mode]);
  }

  @override
  Future<void> mapOnCameraTrackingDismissed() async {
    onCameraTrackingDismissedPlatform(null);
  }

  @override
  Future<void> mapOnIdle() async {
    onMapIdlePlatform(null);
  }

  @override
  Future<void> mapOnUserLocationUpdated(
    PgUserLocation userLocation,
    PgUserHeading? heading,
  ) async {
    onUserLocationUpdatedPlatform(
      UserLocation(
        position: _latLng(userLocation.position),
        altitude: userLocation.altitude,
        bearing: userLocation.bearing,
        speed: userLocation.speed,
        horizontalAccuracy: userLocation.horizontalAccuracy,
        verticalAccuracy: userLocation.verticalAccuracy,
        heading:
            heading == null
                ? null
                : UserHeading(
                  magneticHeading: heading.magneticHeading,
                  trueHeading: heading.trueHeading,
                  headingAccuracy: heading.headingAccuracy,
                  x: heading.x,
                  y: heading.y,
                  z: heading.z,
                  timestamp: DateTime.fromMillisecondsSinceEpoch(
                    heading.timestamp,
                  ),
                ),
        timestamp: DateTime.fromMillisecondsSinceEpoch(userLocation.timestamp),
      ),
    );
  }

  static LatLng _latLng(PgLatLng latLng) =>
      LatLng(latLng.latitude, latLng.longitude);

  static CameraPosition _cameraPosition(PgCameraPosition position) =>
      CameraPosition(
        bearing: position.bearing,
        target: _latLng(position.target),
        tilt: position.tilt,
        zoom: position.zoom,
      );

  /// The map native answers with, for the calls that always answer one. A
  /// null answer fails here, as it did when the method channel reply was
  /// assigned to a map.
  static Map<dynamic, dynamic> _replyMap(Object? reply) =>
      reply! as Map<dynamic, dynamic>;

  /// Reads a camera position map, the answer of `map#update` and
  /// `map#queryCameraPosition`, as `CameraPosition.fromMap` does.
  static CameraPosition? _cameraPositionFromMap(Object? reply) {
    if (reply == null) return null;
    final json = reply as Map<dynamic, dynamic>;
    final target = json['target'] as List<dynamic>;
    return CameraPosition(
      bearing: json['bearing'],
      // A JSON round trip may turn 60.0 into 60, hence num.
      target: LatLng(
        (target[0] as num).toDouble(),
        (target[1] as num).toDouble(),
      ),
      tilt: json['tilt'],
      zoom: json['zoom'],
    );
  }

  // Calls to native.

  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> optionsUpdate,
  ) async {
    return _cameraPositionFromMap(await _api.mapUpdate(optionsUpdate));
  }

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    return _api.cameraAnimate(cameraUpdate.toJson(), duration?.inMilliseconds);
  }

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    return _api.cameraMove(cameraUpdate.toJson());
  }

  @override
  Future<void> updateMyLocationTrackingMode(
    MyLocationTrackingMode myLocationTrackingMode,
  ) async {
    await _api.mapUpdateMyLocationTrackingMode(myLocationTrackingMode.index);
  }

  @override
  Future<bool> setTrackingCameraOptions({
    required double tilt,
    Duration? duration,
  }) async {
    final result = await _api.locationComponentSetTrackingCameraOptions(
      tilt,
      duration?.inMilliseconds,
    );
    return result == true;
  }

  @override
  Future<void> setManualLocation(ManualLocationUpdate update) async {
    await _api.locationComponentSetManualLocation(update.toMap());
  }

  @override
  Future<void> matchMapLanguageWithDeviceDefault() async {
    await _api.mapMatchMapLanguageWithDeviceDefault();
  }

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) async {
    await _api.mapUpdateContentInsets(<String, double>{
      'top': insets.top,
      'left': insets.left,
      'bottom': insets.bottom,
      'right': insets.right,
    }, animated);
  }

  @override
  Future<void> setMapLanguage(String language) async {
    await _api.mapSetMapLanguage(language);
  }

  @override
  Future<void> setTelemetryEnabled(bool enabled) async {
    await _api.mapSetTelemetryEnabled(enabled);
  }

  @override
  Future<bool> getTelemetryEnabled() async {
    return _api.mapGetTelemetryEnabled();
  }

  @override
  Future<void> setMaximumFps(int fps) async {
    await _api.mapSetMaximumFps(fps);
  }

  @override
  Future<void> forceOnlineMode() async {
    await _api.mapForceOnlineMode();
  }

  @override
  Future<void> pauseMap() async {
    await _api.mapPause();
  }

  @override
  Future<void> resumeMap() async {
    await _api.mapResume();
  }

  @override
  Future<bool> easeCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
    CameraAnimationInterpolation? interpolation,
  }) async {
    return _api.cameraEase(
      cameraUpdate.toJson(),
      duration?.inMilliseconds,
      interpolation?.name,
    );
  }

  @override
  Future<CameraPosition?> queryCameraPosition() async {
    return _cameraPositionFromMap(await _api.mapQueryCameraPosition());
  }

  @override
  Future<bool> editGeoJsonSource(String id, String data) async {
    final reply = _replyMap(await _api.mapEditGeoJsonSource(id, data));
    return reply['result'] == true;
  }

  @override
  Future<bool> editGeoJsonUrl(String id, String url) async {
    final reply = _replyMap(await _api.mapEditGeoJsonUrl(id, url));
    return reply['result'] == true;
  }

  @override
  Future<bool> setLayerFilter(String layerId, String filter) async {
    final reply = _replyMap(await _api.mapSetLayerFilter(layerId, filter));
    return reply['result'] == true;
  }

  @override
  Future<String?> getStyle() async {
    final reply = _replyMap(await _api.mapGetStyle());
    final result = reply['result'] as bool?;
    if (result ?? false) {
      return reply['json'] as String?;
    }
    return null;
  }

  @override
  Future<void> setCustomHeaders(
    Map<String, String> headers,
    List<String> filter,
  ) async {
    await _api.mapSetCustomHeaders(headers, filter);
  }

  @override
  Future<Map<String, String>> getCustomHeaders() async {
    final result = await _api.mapGetCustomHeaders() as Map<dynamic, dynamic>?;
    return result?.map(
          (key, value) =>
              MapEntry<String, String>(key.toString(), value.toString()),
        ) ??
        <String, String>{};
  }

  @override
  Future<List> queryRenderedFeatures(
    Point<double> point,
    List<String> layerIds,
    List<Object>? filter,
  ) async {
    final reply = _replyMap(
      await _api.mapQueryRenderedFeaturesAtPoint(
        point.x,
        point.y,
        layerIds,
        filter,
      ),
    );
    return reply['features'].map((feature) => jsonDecode(feature)).toList();
  }

  @override
  Future<List> queryRenderedFeaturesInRect(
    Rect rect,
    List<String> layerIds,
    String? filter,
  ) async {
    final reply = _replyMap(
      await _api.mapQueryRenderedFeaturesInRect(
        rect.left,
        rect.top,
        rect.right,
        rect.bottom,
        layerIds,
        filter,
      ),
    );
    return reply['features'].map((feature) => jsonDecode(feature)).toList();
  }

  @override
  Future<List> querySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object>? filter,
  ) async {
    final reply = _replyMap(
      await _api.mapQuerySourceFeatures(sourceId, sourceLayerId, filter),
    );
    return reply['features'].map((feature) => jsonDecode(feature)).toList();
  }

  @override
  Future<int> getClusterExpansionZoom(String sourceId, int clusterId) async {
    return _api.sourceGetClusterExpansionZoom(sourceId, clusterId);
  }

  @override
  Future<List<Map<String, dynamic>>> getClusterChildren(
    String sourceId,
    int clusterId,
  ) async {
    return _decodeFeatures(
      await _api.sourceGetClusterChildren(sourceId, clusterId),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getClusterLeaves(
    String sourceId,
    int clusterId, {
    int limit = 10,
    int offset = 0,
  }) async {
    return _decodeFeatures(
      await _api.sourceGetClusterLeaves(sourceId, clusterId, limit, offset),
    );
  }

  /// Decodes a `{'features': [json, ...]}` reply, the shape the native sides
  /// use to keep nested GeoJSON intact on the way to Dart.
  static List<Map<String, dynamic>> _decodeFeatures(Object? reply) {
    final features = (reply as Map?)?['features'] as List? ?? const [];
    return features
        .map(
          (feature) =>
              (jsonDecode(feature as String) as Map).cast<String, dynamic>(),
        )
        .toList();
  }

  @override
  Future<void> invalidateAmbientCache() async {
    await _api.mapInvalidateAmbientCache();
  }

  @override
  Future<void> clearAmbientCache() async {
    await _api.mapClearAmbientCache();
  }

  @override
  Future<LatLng?> requestMyLocationLatLng() async {
    try {
      final reply = await _api.locationComponentGetLastLocation();
      if (reply == null) {
        return null;
      }
      final data = reply as Map<dynamic, dynamic>;
      var latitude = 0.0;
      var longitude = 0.0;
      if (data.containsKey('latitude') && data['latitude'] != null) {
        latitude = double.parse(data['latitude'].toString());
      }
      if (data.containsKey('longitude') && data['longitude'] != null) {
        longitude = double.parse(data['longitude'].toString());
      }
      return LatLng(latitude, longitude);
    } on PlatformException {
      // A failed lookup has always read as no known location.
      return null;
    }
  }

  @override
  Future<LatLngBounds> getVisibleRegion() async {
    final reply = _replyMap(await _api.mapGetVisibleRegion());
    final southwest = reply['sw'] as List<dynamic>;
    final northeast = reply['ne'] as List<dynamic>;
    return LatLngBounds(
      southwest: LatLng(southwest[0], southwest[1]),
      northeast: LatLng(northeast[0], northeast[1]),
    );
  }

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool sdf = false,
  ]) async {
    await _api.styleAddImage(name, bytes, bytes.length, sdf);
  }

  @override
  Future<void> addImageSource(
    String imageSourceId,
    Uint8List bytes,
    LatLngQuad coordinates,
  ) async {
    await _api.styleAddImageSource(
      imageSourceId,
      bytes,
      bytes.length,
      coordinates.toList(),
    );
  }

  @override
  Future<void> updateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    LatLngQuad? coordinates,
  ) async {
    await _api.styleUpdateImageSource(
      imageSourceId,
      bytes,
      bytes?.length,
      coordinates?.toList(),
    );
  }

  @override
  Future<Point> toScreenLocation(LatLng latLng) async {
    final screenPosMap = _replyMap(
      await _api.mapToScreenLocation(latLng.latitude, latLng.longitude),
    );
    return Point(screenPosMap['x'], screenPosMap['y']);
  }

  @override
  Future<List<Point>> toScreenLocationBatch(Iterable<LatLng> latLngs) async {
    final coordinates = Float64List.fromList(
      latLngs.map((e) => [e.latitude, e.longitude]).expand((e) => e).toList(),
    );
    final result = await _api.mapToScreenLocationBatch(coordinates);

    final points = <Point>[];
    for (var i = 0; i < result.length; i += 2) {
      points.add(Point(result[i], result[i + 1]));
    }
    return points;
  }

  @override
  Future<void> removeSource(String sourceId) async {
    await _api.styleRemoveSource(sourceId);
  }

  @override
  Future<void> addLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  ) async {
    await _api.styleAddLayer(imageLayerId, imageSourceId, minzoom, maxzoom);
  }

  @override
  Future<void> addLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  ) async {
    await _api.styleAddLayerBelow(
      imageLayerId,
      imageSourceId,
      belowLayerId,
      minzoom,
      maxzoom,
    );
  }

  @override
  Future<void> removeLayer(String imageLayerId) async {
    await _api.styleRemoveLayer(imageLayerId);
  }

  @override
  Future<void> moveLayer(String layerId, {String? belowLayerId}) async {
    await _api.styleMoveLayer(layerId, belowLayerId);
  }

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {
    await _api.styleSetFilter(layerId, jsonEncode(filter));
  }

  @override
  Future<dynamic> getFilter(String layerId) async {
    final reply = _replyMap(await _api.styleGetFilter(layerId));
    final filter = reply['filter'];
    return filter != null ? jsonDecode(filter) : null;
  }

  @override
  Future<LatLng> toLatLng(Point screenLocation) async {
    final latLngMap = _replyMap(
      await _api.mapToLatLng(
        screenLocation.x.toDouble(),
        screenLocation.y.toDouble(),
      ),
    );
    return LatLng(latLngMap['latitude'], latLngMap['longitude']);
  }

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) async {
    final reply = _replyMap(
      await _api.mapGetMetersPerPixelAtLatitude(latitude),
    );
    return reply['metersperpixel'];
  }

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) {
    return _writeGeoJson(sourceId, () async {
      await _api.sourceAddGeoJson(sourceId, await _encodeGeoJson(geojson));
    });
  }

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson) {
    return _writeGeoJson(sourceId, () async {
      await _api.sourceSetGeoJson(sourceId, await _encodeGeoJson(geojson));
    });
  }

  @override
  Future<void> setFeatureForGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojsonFeature,
  ) {
    return _writeGeoJson(sourceId, () async {
      await _api.sourceSetFeature(
        sourceId,
        await _encodeGeoJson(geojsonFeature),
      );
    });
  }

  /// Pending GeoJSON write per source id. See [_writeGeoJson].
  final Map<String, Future<void>> _pendingGeoJsonWrites = {};

  /// Runs [write] after any GeoJSON write already in flight for [sourceId].
  ///
  /// Encoding can finish asynchronously, and it takes longer the larger the
  /// payload is. Two writes fired without `await` on the same source would
  /// otherwise be able to reach native in reverse order, leaving the source
  /// holding the older payload. Chaining per source id keeps native in call
  /// order.
  Future<void> _writeGeoJson(String sourceId, Future<void> Function() write) {
    final pending = _pendingGeoJsonWrites[sourceId];
    // A failed write must not block the writes queued behind it, so its error
    // is ignored for chaining purposes only. Callers still see it through the
    // future returned here.
    final next = (pending == null
            ? Future<void>.value()
            : pending.then<void>((_) {}, onError: (_) {}))
        .then((_) => write());
    _pendingGeoJsonWrites[sourceId] = next;
    unawaited(
      next.then<void>((_) {}, onError: (_) {}).whenComplete(() {
        if (_pendingGeoJsonWrites[sourceId] == next) {
          // The removed future is the one already handled just above, so
          // ignoring it here is deliberate rather than a dropped error.
          _pendingGeoJsonWrites.remove(sourceId)?.ignore();
        }
      }),
    );
    return next;
  }

  /// Thresholds above which GeoJSON encoding moves to a background isolate:
  /// the number of features in a collection, and the number of coordinate
  /// positions anywhere in the payload.
  ///
  /// Native only accepts a JSON string, so the encode happens either way, and
  /// `jsonEncode` on the main isolate froze the UI on large geometries (#366).
  /// Above these thresholds the encode goes through [compute]; below them it
  /// stays synchronous, since spawning an isolate would make the common case
  /// slower and asynchronous for nothing. The trade-offs behind the values
  /// are measured in the documentation of the same thresholds in the
  /// platform interface, which this class replaced on Android and iOS.
  static const _geoJsonOffloadFeatureCount = 100;
  static const _geoJsonOffloadPositionCount = 2000;

  /// Encodes [geojson] to a JSON string, offloading to a background isolate
  /// when the payload is large enough to be worth it. See [_isLargeGeoJson].
  static Future<String> _encodeGeoJson(Map<String, dynamic> geojson) {
    if (_isLargeGeoJson(geojson)) {
      return compute(jsonEncode, geojson);
    }
    return Future.value(jsonEncode(geojson));
  }

  /// Whether [geojson] is large enough that encoding it should move off the
  /// main isolate.
  ///
  /// Counting stops as soon as the threshold is reached, so this costs at most
  /// [_geoJsonOffloadPositionCount] steps no matter how large the payload is.
  /// Counting positions instead of the length of the top-level `coordinates`
  /// array is what makes this correct for areas: a `Polygon` holds one entry
  /// per ring, so a single ring of 50k points has a `coordinates` length of 1.
  /// The same applies to `MultiLineString`, `MultiPolygon` and
  /// `GeometryCollection`.
  static bool _isLargeGeoJson(Map<String, dynamic> geojson) {
    const limit = _geoJsonOffloadPositionCount;
    final features = geojson['features'];
    if (features is List) {
      if (features.length >= _geoJsonOffloadFeatureCount) return true;
      var positions = 0;
      for (final feature in features) {
        if (feature is! Map) continue;
        positions += _countGeometryPositions(
          feature['geometry'],
          limit - positions,
        );
        if (positions >= limit) return true;
      }
      return false;
    }
    return _countGeometryPositions(geojson['geometry'] ?? geojson, limit) >=
        limit;
  }

  /// Counts the coordinate positions of a single geometry, giving up once
  /// [limit] is reached. The result is capped at [limit].
  static int _countGeometryPositions(Object? geometry, int limit) {
    if (limit <= 0 || geometry is! Map) return 0;
    if (geometry['type'] == 'GeometryCollection') {
      final geometries = geometry['geometries'];
      if (geometries is! List) return 0;
      var positions = 0;
      for (final child in geometries) {
        positions += _countGeometryPositions(child, limit - positions);
        if (positions >= limit) return positions;
      }
      return positions;
    }
    return _countPositions(geometry['coordinates'], limit);
  }

  /// Counts positions inside a `coordinates` value of any nesting depth, giving
  /// up once [limit] is reached. A position is a list of numbers, so a list
  /// whose first entry is a number counts as one position.
  static int _countPositions(Object? coordinates, int limit) {
    if (limit <= 0 || coordinates is! List || coordinates.isEmpty) return 0;
    if (coordinates.first is num) return 1;
    var positions = 0;
    for (final child in coordinates) {
      positions += _countPositions(child, limit - positions);
      if (positions >= limit) return positions;
    }
    return positions;
  }

  @override
  Future<void> setCameraBounds({
    required double west,
    required double north,
    required double south,
    required double east,
    required int padding,
  }) async {
    await _api.mapSetCameraBounds(west, north, south, east, padding);
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
  }) async {
    await _api.symbolLayerAdd(
      sourceId,
      layerId,
      belowLayerId,
      sourceLayer,
      minzoom,
      maxzoom,
      jsonEncode(filter),
      enableInteraction,
      properties,
    );
  }

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
  }) async {
    await _api.lineLayerAdd(
      sourceId,
      layerId,
      belowLayerId,
      sourceLayer,
      minzoom,
      maxzoom,
      jsonEncode(filter),
      enableInteraction,
      properties,
    );
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  ) async {
    await _api.layerSetProperties(layerId, properties);
  }

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
  }) async {
    await _api.circleLayerAdd(
      sourceId,
      layerId,
      belowLayerId,
      sourceLayer,
      minzoom,
      maxzoom,
      jsonEncode(filter),
      enableInteraction,
      properties,
    );
  }

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
  }) async {
    await _api.fillLayerAdd(
      sourceId,
      layerId,
      belowLayerId,
      sourceLayer,
      minzoom,
      maxzoom,
      jsonEncode(filter),
      enableInteraction,
      properties,
    );
  }

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
  }) async {
    await _api.fillExtrusionLayerAdd(
      sourceId,
      layerId,
      belowLayerId,
      sourceLayer,
      minzoom,
      maxzoom,
      jsonEncode(filter),
      enableInteraction,
      properties,
    );
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    _ensureDemEncodingSupported(properties);
    await _api.styleAddSource(sourceId, properties.toJson());
  }

  /// The `custom` raster-dem encoding is a MapLibre GL JS feature. MapLibre
  /// Native decodes only its two built-in formulas (maplibre-native#2783) and
  /// would read custom tiles with the default one, so the map would render
  /// plausible but wrong elevations. Failing here says so instead.
  ///
  /// `redFactor`, `greenFactor`, `blueFactor` and `baseShift` are read only on
  /// a custom encoding, so on the built-in ones they stay the no-op they have
  /// always been on Android and iOS and are not rejected.
  static void _ensureDemEncodingSupported(SourceProperties properties) {
    if (properties is! RasterDemSourceProperties) return;
    if (properties.encoding != 'custom') return;

    throw UnsupportedError(
      'The custom raster-dem encoding is not available on Android and iOS '
      'because MapLibre Native decodes only the mapbox and terrarium '
      'encodings. Use encoding: "mapbox" or "terrarium", or serve the '
      'terrain tiles in one of those encodings. Custom encoding is '
      'supported on web. This check covers addSource() only: a raster-dem '
      'source declared inside MapLibreMap.styleString never reaches it and '
      'is decoded as mapbox without any error.',
    );
  }

  @override
  Future<void> addRasterLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) async {
    await _api.rasterLayerAdd(
      sourceId,
      layerId,
      belowLayerId,
      minzoom,
      maxzoom,
      properties,
    );
  }

  @override
  Future<void> addHillshadeLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) async {
    await _api.hillshadeLayerAdd(
      sourceId,
      layerId,
      belowLayerId,
      minzoom,
      maxzoom,
      properties,
    );
  }

  @override
  Future<void> addColorReliefLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
  }) async {
    await _api.colorReliefLayerAdd(
      sourceId,
      layerId,
      belowLayerId,
      minzoom,
      maxzoom,
      properties,
    );
  }

  @override
  Future<void> addBackgroundLayer(
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
  }) async {
    await _api.backgroundLayerAdd(
      layerId,
      belowLayerId,
      minzoom,
      maxzoom,
      properties,
    );
  }

  @override
  Future<void> addHeatmapLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
  }) async {
    await _api.heatmapLayerAdd(
      sourceId,
      layerId,
      belowLayerId,
      sourceLayer,
      minzoom,
      maxzoom,
      jsonEncode(filter),
      properties,
    );
  }

  /// Guard shared by the feature state methods: only the MapLibre Android SDK
  /// exposes the feature state API, so on iOS the call has no native
  /// counterpart to reach. Failing here keeps the error clear instead of
  /// surfacing as an unanswered call.
  static void _ensureFeatureStateAvailable(String methodName) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      throw UnsupportedError(
        '$methodName is not available on iOS because the MapLibre iOS SDK '
        'does not expose the feature state API yet. '
        'Feature state is supported on Android and web.',
      );
    }
  }

  @override
  Future<void> setFeatureState(
    String sourceId,
    String featureId,
    Map<String, dynamic> state, {
    String? sourceLayer,
  }) async {
    _ensureFeatureStateAvailable('setFeatureState');
    await _api.sourceSetFeatureState(sourceId, featureId, state, sourceLayer);
  }

  @override
  Future<void> removeFeatureState(
    String sourceId, {
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  }) async {
    _ensureFeatureStateAvailable('removeFeatureState');
    await _api.sourceRemoveFeatureState(
      sourceId,
      featureId,
      stateKey,
      sourceLayer,
    );
  }

  @override
  Future<Map<String, dynamic>?> getFeatureState(
    String sourceId,
    String featureId, {
    String? sourceLayer,
  }) async {
    _ensureFeatureStateAvailable('getFeatureState');
    final reply = await _api.sourceGetFeatureState(
      sourceId,
      featureId,
      sourceLayer,
    );
    // Native sends the state as a JSON string, so nested values arrive
    // intact, and sends null, not an empty map, when the feature has no
    // state, because callers tell the two apart.
    final state = (reply as Map?)?['state'];
    if (state == null) return null;
    return (jsonDecode(state as String) as Map).cast<String, dynamic>();
  }

  @override
  Future<void> setSky(SkyProperties sky) async {
    throw UnsupportedError(
      'setSky is not available on Android and iOS because MapLibre Native '
      'does not implement the sky style root object yet. '
      'The sky is supported on web.',
    );
  }

  @override
  Future<void> setTerrain(TerrainProperties? terrain) async {
    throw UnsupportedError(
      'setTerrain is not available on Android and iOS because MapLibre Native '
      'does not implement 3D terrain yet. Terrain is supported on web.',
    );
  }

  @override
  Future<void> setProjection(Object type) async {
    throw UnsupportedError(
      'setProjection is not available on Android and iOS because MapLibre '
      'Native only renders the mercator projection. '
      'Projections are supported on web.',
    );
  }

  @override
  Future<void> setGlobalStateProperty(String name, Object? value) async {
    throw UnsupportedError(
      'setGlobalStateProperty is not available on Android and iOS because '
      'MapLibre Native does not implement global state yet. '
      'Global state is supported on web.',
    );
  }

  @override
  Future<void> setLight(LightProperties light) async {
    await _api.styleSetLight(light.toJson());
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    await _api.layerSetVisibility(layerId, visible);
  }

  @override
  Future<List<String>> setLayersVisibility(
    List<String> layerIds,
    bool visible,
  ) async {
    final missing = await _api.layerSetVisibilityBatch(layerIds, visible);
    return missing ?? const [];
  }

  @override
  Future<void> setLayerZoomRange(
    String layerId,
    double minzoom,
    double maxzoom,
  ) async {
    await _api.layerSetZoomRange(layerId, minzoom, maxzoom);
  }

  @override
  Future<bool?> getLayerVisibility(String layerId) async {
    return _api.layerGetVisibility(layerId);
  }

  @override
  Future<Size> setWebMapToCustomSize(Size size) async {
    // Web only: Android and iOS keep their size and report the requested one.
    return size;
  }

  @override
  Future<void> waitUntilMapIsIdleAfterMovement() async {
    // Nothing to wait for on Android and iOS, where camera calls answer once
    // the movement is over.
  }

  @override
  Future<void> waitUntilMapTilesAreLoaded() async {
    // Web only.
  }

  @override
  Future<Uint8List> takeSnapshot({int? width, int? height}) async {
    final result = await _api.mapTakeSnapshot(width, height);
    if (result == null) {
      throw Exception('Failed to take map snapshot');
    }
    return result;
  }

  @override
  void forceResizeWebMap() {}

  @override
  void resizeWebMap() {}

  @override
  Future<List> getLayerIds() async {
    final reply = _replyMap(await _api.styleGetLayerIds());
    return reply['layers'].map((it) => it.toString()).toList();
  }

  @override
  Future<List> getSourceIds() async {
    final reply = _replyMap(await _api.styleGetSourceIds());
    return reply['sources'].map((it) => it.toString()).toList();
  }

  @override
  Future<Map<String, dynamic>?> getLayerProperties(String layerId) async {
    return _styleObjectProperties(await _api.styleGetLayerProperties(layerId));
  }

  @override
  Future<Map<String, dynamic>?> getSourceProperties(String sourceId) async {
    return _styleObjectProperties(
      await _api.styleGetSourceProperties(sourceId),
    );
  }

  /// Reads the answer of [getLayerProperties] and [getSourceProperties].
  ///
  /// Native serializes the layer or source to a style-spec JSON string, so
  /// nested expressions arrive intact, and sends it under `properties`, or
  /// leaves `properties` out when the object does not exist.
  static Map<String, dynamic>? _styleObjectProperties(Object? reply) {
    final properties = (reply as Map?)?['properties'];
    if (properties == null) return null;
    return shapeStyleProperties(jsonDecode(properties as String) as Map);
  }

  @override
  Future<void> setStyle(String styleString) async {
    await _api.styleSetStyle(styleString);
  }
}
