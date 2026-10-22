part of '../maplibre_gl.dart';

/// The [MapLibrePlatform] of Android and iOS: one per map, talking to the
/// native map through the messages generated from `pigeons/messages.dart`.
///
/// The messages of each map travel on their own channels, told apart by the
/// platform view id [initPlatform] receives. This class turns the values of
/// the public API into their typed arguments, and their answers back.
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
        MapLibreMapHostApi(
          binaryMessenger: const _MapCallMessenger(),
          messageChannelSuffix: '$id',
        );
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
      final params = _creationParams(
        creationParams,
        useHybridComposition: useHybridComposition,
      );
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
          onCreatePlatformView: (viewParams) {
            final controller = PlatformViewsService.initAndroidView(
              id: viewParams.id,
              viewType: 'plugins.flutter.io/maplibre_gl',
              layoutDirection: TextDirection.ltr,
              creationParams: params,
              creationParamsCodec: MapLibreMapHostApi.pigeonChannelCodec,
              onFocus: () => viewParams.onFocusChanged(true),
            );

            controller.addOnPlatformViewCreatedListener(
              viewParams.onPlatformViewCreated,
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
          creationParams: params,
          creationParamsCodec: MapLibreMapHostApi.pigeonChannelCodec,
        );
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'plugins.flutter.io/maplibre_gl',
        onPlatformViewCreated: onPlatformViewCreated,
        gestureRecognizers: gestureRecognizers,
        creationParams: _creationParams(
          creationParams,
          useHybridComposition: false,
        ),
        creationParamsCodec: MapLibreMapHostApi.pigeonChannelCodec,
      );
    }
    return Text(
      '$defaultTargetPlatform is not yet supported by the maps plugin',
    );
  }

  /// The creation params of the platform view, from the map [MapLibreMap]
  /// builds. Native decodes them with the generated codec.
  static PgCreationParams _creationParams(
    Map<String, dynamic> params, {
    required bool useHybridComposition,
  }) {
    final options = params['options'] as Map<dynamic, dynamic>?;
    final camera = params['initialCameraPosition'] as Map<dynamic, dynamic>?;
    return PgCreationParams(
      styleString: params['styleString'] as String?,
      options: _mapOptions(options?.cast<String, dynamic>() ?? const {}),
      initialCameraPosition: camera == null ? null : _pgCameraPosition(camera),
      // The default of MapLibreMap.dragEnabled, and of both platforms.
      dragEnabled: params['dragEnabled'] as bool? ?? true,
      iosLongClickDurationMs:
          params['iosLongClickDurationMilliseconds'] as int?,
      useHybridComposition: useHybridComposition,
    );
  }

  /// The options of the map, from the map `MapLibreMapOptions.toMap` writes.
  /// What the map leaves out stays null, which native reads as "keep as it
  /// is". The web-only options have no field and are dropped.
  static PgMapOptions _mapOptions(Map<String, dynamic> options) {
    bool? flag(String key) => options[key] as bool?;
    T? enumAt<T>(List<T> values, String key) {
      final index = options[key] as int?;
      return index == null ? null : values[index];
    }

    PgScreenPoint? margins(String key) {
      final margins = options[key] as List<dynamic>?;
      return margins == null ? null : _pgScreenPoint(margins);
    }

    // `[bounds]`, where null bounds lift the restriction.
    final targetBounds = options['cameraTargetBounds'] as List<dynamic>?;
    // `[minZoom, maxZoom]`, where a null end leaves that side unbounded.
    final zoomRange = options['minMaxZoomPreference'] as List<dynamic>?;
    final puckStyle = options['myLocationStyle'] as Map<dynamic, dynamic>?;
    final engine = options['locationEngineProperties'] as List<dynamic>?;
    final locationSource = options['locationSource'] as String?;
    return PgMapOptions(
      compassEnabled: flag('compassEnabled'),
      cameraTargetBounds:
          targetBounds == null
              ? null
              : PgCameraTargetBounds(
                bounds:
                    targetBounds.first == null
                        ? null
                        : _pgLatLngBounds(targetBounds.first as List<dynamic>),
              ),
      styleString: options['styleString'] as String?,
      minMaxZoomPreference:
          zoomRange == null
              ? null
              : PgMinMaxZoomPreference(
                minZoom: (zoomRange[0] as num?)?.toDouble(),
                maxZoom: (zoomRange[1] as num?)?.toDouble(),
              ),
      rotateGesturesEnabled: flag('rotateGesturesEnabled'),
      scrollGesturesEnabled: flag('scrollGesturesEnabled'),
      tiltGesturesEnabled: flag('tiltGesturesEnabled'),
      zoomGesturesEnabled: flag('zoomGesturesEnabled'),
      doubleClickZoomEnabled: flag('doubleClickZoomEnabled'),
      panInertia: enumAt(PgPanInertia.values, 'panInertia'),
      hapticFeedbackEnabled: flag('hapticFeedbackEnabled'),
      trackCameraPosition: flag('trackCameraPosition'),
      myLocationEnabled: flag('myLocationEnabled'),
      myLocationTrackingMode: enumAt(
        PgMyLocationTrackingMode.values,
        'myLocationTrackingMode',
      ),
      myLocationRenderMode: enumAt(
        PgMyLocationRenderMode.values,
        'myLocationRenderMode',
      ),
      myLocationStyle:
          puckStyle == null
              ? null
              : PgMyLocationStyle(
                fillColor: puckStyle['fillColor'] as int?,
                bearingColor: puckStyle['bearingColor'] as int?,
                accuracyColor: puckStyle['accuracyColor'] as int?,
                accuracyCircleEnabled:
                    puckStyle['accuracyCircleEnabled'] as bool? ?? true,
                pulseEnabled: puckStyle['pulseEnabled'] as bool?,
                pulseColor: puckStyle['pulseColor'] as int?,
              ),
      logoEnabled: flag('logoEnabled'),
      logoViewPosition: enumAt(PgOrnamentPosition.values, 'logoViewPosition'),
      logoViewMargins: margins('logoViewMargins'),
      compassViewPosition: enumAt(
        PgOrnamentPosition.values,
        'compassViewPosition',
      ),
      compassViewMargins: margins('compassViewMargins'),
      attributionEnabled: flag('attributionEnabled'),
      attributionButtonPosition: enumAt(
        PgOrnamentPosition.values,
        'attributionButtonPosition',
      ),
      attributionButtonMargins: margins('attributionButtonMargins'),
      attributionButtonColor: options['attributionButtonColor'] as int?,
      locationEngineProperties:
          engine == null ? null : _locationEngineProperties(engine),
      locationSource:
          locationSource == null
              ? null
              : PgLocationSource.values.byName(locationSource),
      foregroundLoadColor: options['foregroundLoadColor'] as int?,
      translucentTextureSurface: flag('translucentTextureSurface'),
      featureTapsTriggersMapClick: flag('featureTapsTriggersMapClick'),
      symbolPlacementTransitionsEnabled: flag(
        'symbolPlacementTransitionsEnabled',
      ),
    );
  }

  /// The location engine settings, from the list
  /// `LocationEnginePlatforms.toList` writes for the platform it runs on:
  /// `[interval, priority, displacement]` on Android, and
  /// `[enableHighAccuracy, displacement, intervalMs, pulseWindowMs]` on iOS,
  /// with the flag as 1 or 0. Elsewhere the list is empty.
  static PgLocationEngineProperties? _locationEngineProperties(
    List<dynamic> values,
  ) {
    if (values.isEmpty) return null;
    int at(int index) => values[index] as int;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return PgLocationEngineProperties(
        enableHighAccuracy: at(0) == 1,
        displacement: at(1),
        intervalMs: at(2),
        pulseWindowMs: at(3),
      );
    }
    return PgLocationEngineProperties(
      interval: at(0),
      priority: PgLocationPriority.values[at(1)],
      displacement: at(2),
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
  Future<void> mapOnCameraTrackingChanged(PgMyLocationTrackingMode mode) async {
    onCameraTrackingChangedPlatform(MyLocationTrackingMode.values[mode.index]);
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

  static PgLatLng _toPgLatLng(LatLng latLng) =>
      PgLatLng(latitude: latLng.latitude, longitude: latLng.longitude);

  static PgLatLngQuad _pgLatLngQuad(LatLngQuad quad) => PgLatLngQuad(
    topLeft: _toPgLatLng(quad.topLeft),
    topRight: _toPgLatLng(quad.topRight),
    bottomRight: _toPgLatLng(quad.bottomRight),
    bottomLeft: _toPgLatLng(quad.bottomLeft),
  );

  // The readers below take the JSON-like values the public classes write,
  // such as `LatLng.toJson`, where a number may be an int.

  /// A `[latitude, longitude]` list.
  static PgLatLng _pgLatLng(Object? json) {
    final latLng = json! as List<dynamic>;
    return PgLatLng(
      latitude: (latLng[0] as num).toDouble(),
      longitude: (latLng[1] as num).toDouble(),
    );
  }

  /// A `[southwest, northeast]` list, as `LatLngBounds.toList` writes it.
  static PgLatLngBounds _pgLatLngBounds(List<dynamic> json) => PgLatLngBounds(
    southwest: _pgLatLng(json[0]),
    northeast: _pgLatLng(json[1]),
  );

  /// An `[x, y]` list.
  static PgScreenPoint _pgScreenPoint(List<dynamic> json) => PgScreenPoint(
    x: (json[0] as num).toDouble(),
    y: (json[1] as num).toDouble(),
  );

  /// A camera position map, as `CameraPosition.toMap` writes it.
  static PgCameraPosition _pgCameraPosition(Map<dynamic, dynamic> json) =>
      PgCameraPosition(
        bearing: (json['bearing'] as num).toDouble(),
        target: _pgLatLng(json['target']),
        tilt: (json['tilt'] as num).toDouble(),
        zoom: (json['zoom'] as num).toDouble(),
      );

  /// [update] as the subclass of [PgCameraUpdate] of its kind, read from
  /// `CameraUpdate.toJson`, the only way into its value.
  ///
  /// Throws INVALID_ARGUMENT for an update of no known kind, such as one from
  /// a subclass that overrides `toJson`.
  static PgCameraUpdate _pgCameraUpdate(CameraUpdate update) {
    final json = update.toJson();
    try {
      final values = json as List<dynamic>;
      double at(int index) => (values[index] as num).toDouble();
      switch (values.first) {
        case 'newCameraPosition':
          return PgCameraUpdateNewCameraPosition(
            cameraPosition: _pgCameraPosition(values[1] as Map),
          );
        case 'newLatLng':
          return PgCameraUpdateNewLatLng(latLng: _pgLatLng(values[1]));
        case 'newLatLngBounds':
          return PgCameraUpdateNewLatLngBounds(
            bounds: _pgLatLngBounds(values[1] as List<dynamic>),
            padding: PgEdgeInsets(
              left: at(2),
              top: at(3),
              right: at(4),
              bottom: at(5),
            ),
          );
        case 'newLatLngZoom':
          return PgCameraUpdateNewLatLngZoom(
            latLng: _pgLatLng(values[1]),
            zoom: at(2),
          );
        case 'scrollBy':
          return PgCameraUpdateScrollBy(dx: at(1), dy: at(2));
        case 'zoomBy':
          return PgCameraUpdateZoomBy(
            amount: at(1),
            focus:
                values.length > 2
                    ? _pgScreenPoint(values[2] as List<dynamic>)
                    : null,
          );
        case 'zoomIn':
          return PgCameraUpdateZoomIn();
        case 'zoomOut':
          return PgCameraUpdateZoomOut();
        case 'zoomTo':
          return PgCameraUpdateZoomTo(zoom: at(1));
        case 'bearingTo':
          return PgCameraUpdateBearingTo(bearing: at(1));
        case 'tiltTo':
          return PgCameraUpdateTiltTo(tilt: at(1));
      }
    } on Object {
      // A value of the wrong type or a missing one, reported below.
    }
    throw PlatformException(
      code: 'INVALID_ARGUMENT',
      message: 'Cannot interpret $json as CameraUpdate.',
    );
  }

  /// [filter], an expression, as the JSON text native takes, or null when
  /// there is no filter.
  static String? _encodeFilter(Object? filter) =>
      filter == null ? null : jsonEncode(filter);

  // Calls to native.

  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> optionsUpdate,
  ) async {
    final position = await _api.mapUpdate(_mapOptions(optionsUpdate));
    return position == null ? null : _cameraPosition(position);
  }

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    return _api.cameraAnimate(
      _pgCameraUpdate(cameraUpdate),
      duration?.inMilliseconds,
    );
  }

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    return _api.cameraMove(_pgCameraUpdate(cameraUpdate));
  }

  @override
  Future<void> updateMyLocationTrackingMode(
    MyLocationTrackingMode myLocationTrackingMode,
  ) async {
    await _api.mapUpdateMyLocationTrackingMode(
      PgMyLocationTrackingMode.values[myLocationTrackingMode.index],
    );
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
    await _api.locationComponentSetManualLocation(
      PgManualLocationUpdate(
        position: _toPgLatLng(update.target),
        // As ManualLocationUpdate.toMap: the time of the call when unset.
        timestamp: (update.timestamp ?? DateTime.now()).millisecondsSinceEpoch,
        horizontalAccuracy: update.horizontalAccuracy,
        verticalAccuracy: update.verticalAccuracy,
        altitude: update.altitude,
        bearing: update.bearing,
        speed: update.speed,
      ),
    );
  }

  @override
  Future<void> matchMapLanguageWithDeviceDefault() async {
    await _api.mapMatchMapLanguageWithDeviceDefault();
  }

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) async {
    await _api.mapUpdateContentInsets(
      PgEdgeInsets(
        top: insets.top,
        left: insets.left,
        bottom: insets.bottom,
        right: insets.right,
      ),
      animated,
    );
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
      _pgCameraUpdate(cameraUpdate),
      duration?.inMilliseconds,
      interpolation == null
          ? null
          : PgCameraAnimationInterpolation.values[interpolation.index],
    );
  }

  @override
  Future<CameraPosition?> queryCameraPosition() async {
    return _cameraPosition(await _api.mapQueryCameraPosition());
  }

  @override
  Future<bool> editGeoJsonSource(String id, String data) {
    return _writeGeoJson(id, () async {
      final reason =
          data.length > _geoJsonTextOffloadLength
              ? await compute(geoJsonTextError, data)
              : geoJsonTextError(data);
      if (reason != null) throw invalidGeoJson(id, reason);
      return _api.mapEditGeoJsonSource(id, data);
    });
  }

  @override
  Future<bool> editGeoJsonUrl(String id, String url) {
    return _writeGeoJson(id, () => _api.mapEditGeoJsonUrl(id, url));
  }

  @override
  Future<bool> setLayerFilter(String layerId, String filter) async {
    return _api.mapSetLayerFilter(layerId, filter);
  }

  @override
  Future<String?> getStyle() async {
    return _api.mapGetStyle();
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
    // A map of its own, which the caller may change.
    return Map<String, String>.of(await _api.mapGetCustomHeaders());
  }

  @override
  Future<List> queryRenderedFeatures(
    Point<double> point,
    List<String> layerIds,
    List<Object>? filter,
  ) async {
    final features = await _api.mapQueryRenderedFeaturesAtPoint(
      point.x,
      point.y,
      layerIds,
      _encodeFilter(filter),
    );
    return features.map(jsonDecode).toList();
  }

  @override
  Future<List> queryRenderedFeaturesInRect(
    Rect rect,
    List<String> layerIds,
    String? filter,
  ) async {
    // The filter comes encoded already.
    final features = await _api.mapQueryRenderedFeaturesInRect(
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
      layerIds,
      filter,
    );
    return features.map(jsonDecode).toList();
  }

  @override
  Future<List> querySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object>? filter,
  ) async {
    final features = await _api.mapQuerySourceFeatures(
      sourceId,
      sourceLayerId,
      _encodeFilter(filter),
    );
    return features.map(jsonDecode).toList();
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

  /// Decodes features, each one GeoJSON text so that nested properties keep
  /// their shape on the way to Dart.
  static List<Map<String, dynamic>> _decodeFeatures(List<String> features) {
    return features
        .map((feature) => (jsonDecode(feature) as Map).cast<String, dynamic>())
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
      return _latLng(await _api.locationComponentGetLastLocation());
    } on PlatformException {
      // A failed lookup has always read as no known location.
      return null;
    }
  }

  @override
  Future<LatLngBounds> getVisibleRegion() async {
    final region = await _api.mapGetVisibleRegion();
    return LatLngBounds(
      southwest: _latLng(region.southwest),
      northeast: _latLng(region.northeast),
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
      _pgLatLngQuad(coordinates),
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
      coordinates == null ? null : _pgLatLngQuad(coordinates),
    );
  }

  @override
  Future<Point> toScreenLocation(LatLng latLng) async {
    final point = await _api.mapToScreenLocation(
      latLng.latitude,
      latLng.longitude,
    );
    return Point<num>(point.x, point.y);
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
    await _api.styleSetFilter(layerId, _encodeFilter(filter));
  }

  @override
  Future<dynamic> getFilter(String layerId) async {
    final filter = await _api.styleGetFilter(layerId);
    return filter != null ? jsonDecode(filter) : null;
  }

  @override
  Future<LatLng> toLatLng(Point screenLocation) async {
    return _latLng(
      await _api.mapToLatLng(
        screenLocation.x.toDouble(),
        screenLocation.y.toDouble(),
      ),
    );
  }

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) async {
    return _api.mapGetMetersPerPixelAtLatitude(latitude);
  }

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) {
    return _writeGeoJson(sourceId, () async {
      await _api.sourceAddGeoJson(
        sourceId,
        await _encodeGeoJson(geojson, sourceId),
      );
    });
  }

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson) {
    return _writeGeoJson(sourceId, () async {
      await _api.sourceSetGeoJson(
        sourceId,
        await _encodeGeoJson(geojson, sourceId),
      );
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
        await _encodeGeoJson(geojsonFeature, sourceId, feature: true),
      );
    });
  }

  /// Pending GeoJSON write per source id. See [_writeGeoJson].
  final Map<String, Future<Object?>> _pendingGeoJsonWrites = {};

  /// Runs [write] after any GeoJSON write already in flight for [sourceId],
  /// and at once when there is none.
  ///
  /// Checking and encoding can finish asynchronously, and take longer the
  /// larger the payload is. Two writes fired without `await` on the same
  /// source would otherwise be able to reach native in reverse order, leaving
  /// the source holding the older data. Chaining per source id keeps native
  /// in call order. Every call that sets the data of a GeoJSON source goes
  /// through here.
  Future<T> _writeGeoJson<T>(String sourceId, Future<T> Function() write) {
    final pending = _pendingGeoJsonWrites[sourceId];
    // A failed write must not block the writes queued behind it, so its error
    // is ignored for chaining purposes only. Callers still see it through the
    // future returned here.
    final next =
        pending == null
            ? write()
            : pending.then<void>((_) {}, onError: (_) {}).then((_) => write());
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

  /// Checks [geojson], the data of the source [sourceId] or with [feature] one
  /// of its features, and encodes it to a JSON string, on a background
  /// isolate when the payload is large (see [_isLargeGeoJson]). Throws
  /// `INVALID_GEOJSON` for data that is not valid GeoJSON.
  static Future<String> _encodeGeoJson(
    Map<String, dynamic> geojson,
    String sourceId, {
    bool feature = false,
  }) async {
    final encode = feature ? _checkAndEncodeFeature : _checkAndEncodeGeoJson;
    final (json, reason) =
        _isLargeGeoJson(geojson)
            ? await compute(encode, geojson)
            : encode(geojson);
    if (reason != null) {
      throw feature
          ? invalidGeoJsonFeature(sourceId, reason)
          : invalidGeoJson(sourceId, reason);
    }
    return json!;
  }

  /// [geojson] as JSON text, or why it is not GeoJSON.
  static (String?, String?) _checkAndEncodeGeoJson(
    Map<String, dynamic> geojson,
  ) {
    final reason = geoJsonError(geojson);
    return reason == null ? (jsonEncode(geojson), null) : (null, reason);
  }

  /// [geojson] as JSON text, or why it is not a GeoJSON Feature.
  static (String?, String?) _checkAndEncodeFeature(
    Map<String, dynamic> geojson,
  ) {
    final reason = geoJsonFeatureError(geojson);
    return reason == null ? (jsonEncode(geojson), null) : (null, reason);
  }

  /// The length of JSON text above which [editGeoJsonSource] checks it on a
  /// background isolate.
  static const _geoJsonTextOffloadLength = 100000;

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
  static bool _isLargeGeoJson(Map<dynamic, dynamic> geojson) {
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
      _encodeFilter(filter),
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
      _encodeFilter(filter),
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
      _encodeFilter(filter),
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
      _encodeFilter(filter),
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
      _encodeFilter(filter),
      enableInteraction,
      properties,
    );
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    _ensureDemEncodingSupported(properties);
    final json = properties.toJson();
    // A string is the url of the data.
    final data = jsonValueOf(json['data']);
    if (properties is! GeojsonSourceProperties ||
        data == null ||
        data is String) {
      return _api.styleAddSource(sourceId, json);
    }
    return _writeGeoJson(sourceId, () async {
      final (plain, reason) =
          data is Map && _isLargeGeoJson(data)
              ? await compute(_checkSourceData, data)
              : _checkSourceData(data);
      if (reason != null) throw invalidGeoJson(sourceId, reason);
      await _api.styleAddSource(sourceId, {...json, 'data': plain});
    });
  }

  /// [data], the GeoJSON data of `addSource`, with what `jsonEncode` writes in
  /// place of each object it reads through `toJson()`, or why it is not
  /// GeoJSON. The platform channel takes plain JSON values only.
  static (Object?, String?) _checkSourceData(Object? data) {
    final reason = geoJsonError(data);
    return reason == null ? (_plainJson(data), null) : (null, reason);
  }

  /// [value] with each object in it that is not a JSON value replaced by
  /// what its `toJson()` returns, as `jsonEncode` writes it. [value] itself
  /// when nothing is replaced. Throws a [JsonUnsupportedObjectError] for what
  /// `jsonEncode` cannot write, a number that is not finite included.
  static Object? _plainJson(Object? value) {
    final json = jsonValueOf(value);
    if (json == null || json is bool || json is String) return json;
    if (json is num) {
      if (json.isFinite) return json;
      throw JsonUnsupportedObjectError(json);
    }
    if (json is List) {
      List<Object?>? copy;
      for (var i = 0; i < json.length; i++) {
        final item = json[i];
        final plain = _plainJson(item);
        if (!identical(plain, item)) {
          (copy ??= List<Object?>.of(json))[i] = plain;
        }
      }
      return copy ?? json;
    }
    if (json is Map) {
      Map<Object?, Object?>? copy;
      for (final entry in json.entries) {
        final plain = _plainJson(entry.value);
        if (!identical(plain, entry.value)) {
          (copy ??= Map<Object?, Object?>.of(json))[entry.key] = plain;
        }
      }
      return copy ?? json;
    }
    throw JsonUnsupportedObjectError(value);
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
      _encodeFilter(filter),
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
    // Native sends the state as JSON text, so nested values arrive intact,
    // and sends null, not an empty object, when the feature has no state,
    // because callers tell the two apart.
    final state = await _api.sourceGetFeatureState(
      sourceId,
      featureId,
      sourceLayer,
    );
    if (state == null) return null;
    return (jsonDecode(state) as Map).cast<String, dynamic>();
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
    // A growable list of its own, which the caller may change.
    return <dynamic>[...await _api.styleGetLayerIds()];
  }

  @override
  Future<List> getSourceIds() async {
    return <dynamic>[...await _api.styleGetSourceIds()];
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
  /// Native serializes the layer or source to style-spec JSON text, so
  /// nested expressions arrive intact, and sends null when the object does
  /// not exist.
  static Map<String, dynamic>? _styleObjectProperties(String? properties) {
    if (properties == null) return null;
    return shapeStyleProperties(jsonDecode(properties) as Map);
  }

  @override
  Future<void> setStyle(String styleString) async {
    await _api.styleSetStyle(styleString);
  }
}

/// The messenger of the calls of a map, which fails a call that finds no
/// handler on the channels of the map with `MAP_DISPOSED`.
///
/// Native removes the handlers of a map when the map goes away: Android in
/// `dispose()`, iOS when it releases the controller. A call after that gets
/// no answer, which Pigeon reports as a `channel-error`, while a call that
/// reaches the released iOS controller first is answered with `MAP_DISPOSED`.
/// Failing the first kind like the second makes the two platforms agree.
class _MapCallMessenger extends BinaryMessenger {
  const _MapCallMessenger();

  /// Looked up on each use, as Pigeon does when it is given no messenger.
  static BinaryMessenger get _messenger =>
      ServicesBinding.instance.defaultBinaryMessenger;

  @override
  Future<ByteData?> send(String channel, ByteData? message) async {
    final reply = await _messenger.send(channel, message);
    // Pigeon replies to every call native has a handler for, a void one
    // included, so no reply means no handler.
    if (reply == null) {
      throw PlatformException(
        code: 'MAP_DISPOSED',
        // The message iOS answers with.
        message: 'The map was disposed before the call reached it.',
      );
    }
    return reply;
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) =>
      _messenger.setMessageHandler(channel, handler);

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) {
    // BinaryMessenger requires it, though it deprecates it; the calls of a
    // map never use it.
    // ignore: deprecated_member_use
    return _messenger.handlePlatformMessage(channel, data, callback);
  }
}
