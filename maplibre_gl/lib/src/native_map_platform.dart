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

  /// The [AndroidMapView] of this map, read on its first build so a later
  /// change cannot swap the widget and recreate a platform view already on
  /// screen.
  AndroidMapView? _androidView;

  /// The [AndroidMapView] the map asks for, or the one its deprecated flags
  /// spell, while it asks for none.
  static AndroidMapView _androidViewOf(Map<String, dynamic> creationParams) {
    final explicit = creationParams['androidView'] as AndroidMapView?;
    if (explicit != null) return explicit;
    final options = creationParams['options'] as Map<dynamic, dynamic>?;
    if (options?['translucentTextureSurface'] == true) {
      return const AndroidMapView(
        surface: AndroidMapSurface.translucentTextureView,
      );
    }
    // The deprecated spelling of a TextureView, honored until removed.
    // ignore: deprecated_member_use_from_same_package
    if (MapLibreMap.useHybridComposition) {
      return const AndroidMapView(surface: AndroidMapSurface.textureView);
    }
    return const AndroidMapView();
  }

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
      final view = _androidView ??= _androidViewOf(creationParams);
      final params = _creationParams(creationParams, android: view);
      // AndroidView lets Flutter draw the map into its frame; Hybrid
      // Composition needs the view created here.
      if (view.composition == AndroidComposition.hybridComposition) {
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
            final controller = PlatformViewsService.initExpensiveAndroidView(
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
        creationParams: _creationParams(creationParams),
        creationParamsCodec: MapLibreMapHostApi.pigeonChannelCodec,
      );
    }
    return Text(
      '$defaultTargetPlatform is not yet supported by the maps plugin',
    );
  }

  /// The creation params of the platform view, from the map [MapLibreMap]
  /// builds. Native decodes them with the generated codec.
  /// [android] is null on iOS.
  static PgCreationParams _creationParams(
    Map<String, dynamic> params, {
    AndroidMapView? android,
  }) {
    final options = params['options'] as Map<dynamic, dynamic>?;
    final camera = params['initialCameraPosition'] as Map<dynamic, dynamic>?;
    final mapOptions = _mapOptions(
      options?.cast<String, dynamic>() ?? const {},
    );
    if (android != null) {
      // The view decides the translucency, over the deprecated option.
      mapOptions.translucentTextureSurface =
          android.surface == AndroidMapSurface.translucentTextureView
              ? true
              : null;
    }
    return PgCreationParams(
      styleString: params['styleString'] as String?,
      options: mapOptions,
      initialCameraPosition: camera == null ? null : _pgCameraPosition(camera),
      // The default of MapLibreMap.dragEnabled, and of both platforms.
      dragEnabled: params['dragEnabled'] as bool? ?? true,
      iosLongClickDurationMs:
          params['iosLongClickDurationMilliseconds'] as int?,
      textureView:
          android != null && android.surface != AndroidMapSurface.surfaceView,
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
    onCameraMoveStartedPlatform(
      isGesture ? CameraMoveReason.gesture : CameraMoveReason.programmatic,
    );
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
    // A new style holds none of the sources added before it.
    _generatedIdSources.clear();
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
    final input = (data, _featureIdsOf(id));
    return _writeGeoJson(id, () async {
      final (json, reason) =
          data.length > _geoJsonTextOffloadLength
              ? await compute(_checkGeoJsonText, input)
              : _checkGeoJsonText(input);
      if (reason != null) throw invalidGeoJson(id, reason);
      return _api.mapEditGeoJsonSource(id, json!);
    });
  }

  @override
  Future<bool> editGeoJsonUrl(String id, String url) {
    final encoded = encodeUrl(url);
    // A url that cannot be one changes nothing, as on web.
    if (encoded == null) return Future.value(false);
    return _writeGeoJson(id, () => _api.mapEditGeoJsonUrl(id, encoded));
  }

  @override
  Future<bool> setLayerFilter(String layerId, String filter) async {
    return _inOrder(
      [_layerKey(layerId)],
      () => _api.mapSetLayerFilter(layerId, filter),
    );
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
    final features = await _inOrder(
      layerIds.map(_layerKey),
      () => _api.mapQueryRenderedFeaturesAtPoint(
        point.x,
        point.y,
        layerIds,
        _encodeFilter(filter),
      ),
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
    final features = await _inOrder(
      layerIds.map(_layerKey),
      () => _api.mapQueryRenderedFeaturesInRect(
        rect.left,
        rect.top,
        rect.right,
        rect.bottom,
        layerIds,
        filter,
      ),
    );
    return features.map(jsonDecode).toList();
  }

  @override
  Future<List> querySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object>? filter,
  ) async {
    final features = await _inOrder(
      [_sourceKey(sourceId)],
      () => _api.mapQuerySourceFeatures(
        sourceId,
        sourceLayerId,
        _encodeFilter(filter),
      ),
    );
    return features.map(jsonDecode).toList();
  }

  @override
  Future<int> getClusterExpansionZoom(String sourceId, int clusterId) async {
    return _inOrder(
      [_sourceKey(sourceId)],
      () => _api.sourceGetClusterExpansionZoom(sourceId, clusterId),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getClusterChildren(
    String sourceId,
    int clusterId,
  ) async {
    return _decodeFeatures(
      await _inOrder(
        [_sourceKey(sourceId)],
        () => _api.sourceGetClusterChildren(sourceId, clusterId),
      ),
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
      await _inOrder(
        [_sourceKey(sourceId)],
        () => _api.sourceGetClusterLeaves(sourceId, clusterId, limit, offset),
      ),
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
    double? pixelRatio,
  ]) async {
    await _api.styleAddImage(name, bytes, bytes.length, sdf, pixelRatio);
  }

  @override
  Future<void> addImageSource(
    String imageSourceId,
    Uint8List bytes,
    LatLngQuad coordinates,
  ) async {
    await _inOrder(
      [_sourceKey(imageSourceId)],
      () => _api.styleAddImageSource(
        imageSourceId,
        bytes,
        bytes.length,
        _pgLatLngQuad(coordinates),
      ),
    );
  }

  @override
  Future<void> updateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    LatLngQuad? coordinates,
  ) async {
    await _inOrder(
      [_sourceKey(imageSourceId)],
      () => _api.styleUpdateImageSource(
        imageSourceId,
        bytes,
        bytes?.length,
        coordinates == null ? null : _pgLatLngQuad(coordinates),
      ),
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
    // Nothing to ask native: iOS cannot read an empty buffer.
    if (latLngs.isEmpty) return [];
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
    // Cleared now, in call order with an addSource of the same id made
    // right after. A source that stays keeps its numbered ids.
    final generated = _generatedIdSources.remove(sourceId);
    try {
      await _inOrder(
        [_sourceKey(sourceId)],
        () => _api.styleRemoveSource(sourceId),
      );
    } catch (_) {
      if (generated) _generatedIdSources.add(sourceId);
      rethrow;
    }
  }

  @override
  Future<void> addLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  ) async {
    await _inOrder(
      _layerAddKeys(imageSourceId, imageLayerId, null),
      () => _api.styleAddLayer(imageLayerId, imageSourceId, minzoom, maxzoom),
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
    await _inOrder(
      _layerAddKeys(imageSourceId, imageLayerId, belowLayerId),
      () => _api.styleAddLayerBelow(
        imageLayerId,
        imageSourceId,
        belowLayerId,
        minzoom,
        maxzoom,
      ),
    );
  }

  @override
  Future<void> removeLayer(String imageLayerId) async {
    await _inOrder(
      [_layerKey(imageLayerId)],
      () => _api.styleRemoveLayer(imageLayerId),
    );
  }

  @override
  Future<void> moveLayer(String layerId, {String? belowLayerId}) async {
    await _inOrder(
      [_layerKey(layerId), if (belowLayerId != null) _layerKey(belowLayerId)],
      () => _api.styleMoveLayer(layerId, belowLayerId),
    );
  }

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {
    await _inOrder(
      [_layerKey(layerId)],
      () => _api.styleSetFilter(layerId, _encodeFilter(filter)),
    );
  }

  @override
  Future<dynamic> getFilter(String layerId) async {
    final filter = await _inOrder(
      [_layerKey(layerId)],
      () => _api.styleGetFilter(layerId),
    );
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
    return _addingSource(
      sourceId,
      generateIds: false,
      () => _writeGeoJson(sourceId, () async {
        await _api.sourceAddGeoJson(
          sourceId,
          await _encodeGeoJson(geojson, sourceId, _defaultFeatureIds),
        );
      }),
    );
  }

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson) {
    final ids = _featureIdsOf(sourceId);
    return _writeGeoJson(sourceId, () async {
      await _api.sourceSetGeoJson(
        sourceId,
        await _encodeGeoJson(geojson, sourceId, ids),
      );
    });
  }

  @override
  Future<void> setFeatureForGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojsonFeature,
  ) {
    // A feature replaces the one with its id, so it keeps that id.
    final ids =
        _featureIdsOf(sourceId) == _FeatureIds.generate
            ? _FeatureIds.asTheyAre
            : _defaultFeatureIds;
    return _writeGeoJson(sourceId, () async {
      await _api.sourceSetFeature(
        sourceId,
        await _encodeGeoJson(geojsonFeature, sourceId, ids, feature: true),
      );
    });
  }

  /// The GeoJSON sources added with `generateId`. MapLibre Native has no such
  /// option, so the plugin numbers the features of the data it sets to them,
  /// as maplibre-gl-js does.
  final Set<String> _generatedIdSources = {};

  /// What the data the plugin sets to the source [sourceId] gets for its ids.
  _FeatureIds _featureIdsOf(String sourceId) =>
      _generatedIdSources.contains(sourceId)
          ? _FeatureIds.generate
          : _defaultFeatureIds;

  /// What the ids of GeoJSON data get on this platform, without `generateId`.
  static _FeatureIds get _defaultFeatureIds =>
      _marksStringIds ? _FeatureIds.markStringIds : _FeatureIds.asTheyAre;

  /// Runs [add], which adds the source [sourceId], and notes whether the
  /// plugin numbers its features. A failed add leaves the note as it was.
  Future<void> _addingSource(
    String sourceId,
    Future<void> Function() add, {
    required bool generateIds,
  }) async {
    final before = _generatedIdSources.contains(sourceId);
    _noteGeneratedIds(sourceId, generateIds);
    try {
      await add();
    } catch (_) {
      _noteGeneratedIds(sourceId, before);
      rethrow;
    }
  }

  void _noteGeneratedIds(String sourceId, bool generateIds) {
    if (generateIds) {
      _generatedIdSources.add(sourceId);
    } else {
      _generatedIdSources.remove(sourceId);
    }
  }

  /// The call still in flight per source and layer that the calls made
  /// after it on the same source or layer must follow. See [_inOrder].
  final Map<String, Future<Object?>> _pendingCalls = {};

  /// Runs [call] after the calls still in flight on the sources and layers
  /// of [keys], and at once when there is none.
  ///
  /// A GeoJSON write checks and encodes its data first, for some data on
  /// another isolate, so it can reach native after a call made later. A
  /// layer added on that source would then find no source, and a write on
  /// it would be overwritten by the older data. Chaining the calls that name
  /// the same source or layer keeps native in call order, and a call on
  /// another source does not wait.
  ///
  /// With [always], [call] counts as in flight even when it runs at once:
  /// every GeoJSON write does, for its check. Any other call counts only
  /// while it waits.
  Future<T> _inOrder<T>(
    Iterable<String> keys,
    Future<T> Function() call, {
    bool always = false,
  }) {
    final names = keys.toSet();
    final pending = {
      for (final name in names)
        if (_pendingCalls[name] case final future?) future,
    };
    if (pending.isEmpty && !always) return call();
    // A failed call must not block the calls queued behind it, so its error
    // is ignored for chaining purposes only. Callers still see it through
    // the future returned here.
    final next =
        pending.isEmpty
            ? call()
            : Future.wait(
              pending.map(
                (future) => future.then<void>((_) {}, onError: (_) {}),
              ),
            ).then((_) => call());
    for (final name in names) {
      _pendingCalls[name] = next;
    }
    unawaited(
      next.then<void>((_) {}, onError: (_) {}).whenComplete(() {
        for (final name in names) {
          if (_pendingCalls[name] == next) {
            // The removed future is the one already handled just above, so
            // ignoring it here is deliberate rather than a dropped error.
            _pendingCalls.remove(name)?.ignore();
          }
        }
      }),
    );
    return next;
  }

  /// Runs [write], a call that sets the data of the GeoJSON source
  /// [sourceId], in call order with the other calls on it. See [_inOrder].
  Future<T> _writeGeoJson<T>(String sourceId, Future<T> Function() write) =>
      _inOrder([_sourceKey(sourceId)], write, always: true);

  /// The key of the source [sourceId] in [_pendingCalls].
  static String _sourceKey(String sourceId) => 'source $sourceId';

  /// The key of the layer [layerId] in [_pendingCalls].
  static String _layerKey(String layerId) => 'layer $layerId';

  /// The keys of a layer add: its source, the layer, and the layer it goes
  /// below.
  static List<String> _layerAddKeys(
    String? sourceId,
    String layerId,
    String? belowLayerId,
  ) => [
    if (sourceId != null) _sourceKey(sourceId),
    _layerKey(layerId),
    if (belowLayerId != null) _layerKey(belowLayerId),
  ];

  /// Checks [geojson], the data of the source [sourceId] or with [feature] one
  /// of its features, and encodes it to a JSON string, on a background
  /// isolate when that blocks the main one clearly less (see
  /// [encodesInBackground]). Throws `INVALID_GEOJSON` for data that is not
  /// valid GeoJSON.
  static Future<String> _encodeGeoJson(
    Map<String, dynamic> geojson,
    String sourceId,
    _FeatureIds ids, {
    bool feature = false,
  }) async {
    final encode = feature ? _checkAndEncodeFeature : _checkAndEncodeGeoJson;
    final input = (geojson, ids);
    final (json, reason) =
        encodesInBackground(geojson)
            ? await compute(encode, input)
            : encode(input);
    if (reason != null) {
      throw feature
          ? invalidGeoJsonFeature(sourceId, reason)
          : invalidGeoJson(sourceId, reason);
    }
    return json!;
  }

  /// [geojson] as JSON text, or why it is not GeoJSON, with its ids as
  /// [_FeatureIds] says.
  static (String?, String?) _checkAndEncodeGeoJson(
    (Map<String, dynamic>, _FeatureIds) input,
  ) {
    final (geojson, ids) = input;
    final json = _GeoJsonWriter.encode(geojson, ids);
    if (json != null) return (json, null);
    final (data, reason) = _checkFeatureIds(geojson, ids, geoJsonError);
    if (reason != null) return (null, reason);
    return _jsonOrReason(() => jsonEncode(data));
  }

  /// [geojson] as JSON text, or why it is not a GeoJSON Feature, with its id
  /// as [_FeatureIds] says.
  static (String?, String?) _checkAndEncodeFeature(
    (Map<String, dynamic>, _FeatureIds) input,
  ) {
    final (geojson, ids) = input;
    final json = _GeoJsonWriter.encode(geojson, ids, feature: true);
    if (json != null) return (json, null);
    final (data, reason) = _checkFeatureIds(geojson, ids, geoJsonFeatureError);
    if (reason != null) return (null, reason);
    return _jsonOrReason(() => jsonEncode(data));
  }

  /// Why INVALID_GEOJSON rejects a number that is NaN or infinite.
  static const _nonFiniteNumber =
      'A number is NaN or infinite, which JSON cannot hold.';

  /// What [encode] returns, or [_nonFiniteNumber] when it meets a number that
  /// is NaN or infinite: GeoJSON reaches MapLibre Native as JSON, which has
  /// no such number. Any other value `jsonEncode` cannot write still throws.
  static (T?, String?) _jsonOrReason<T>(T Function() encode) {
    try {
      return (encode(), null);
      // The error of jsonEncode, read for the value it could not write.
      // ignore: avoid_catching_errors
    } on JsonUnsupportedObjectError catch (error) {
      Object? cause = error;
      while (cause is JsonUnsupportedObjectError) {
        final value = cause.unsupportedObject;
        if (value is num && !value.isFinite) return (null, _nonFiniteNumber);
        cause = cause.cause;
      }
      rethrow;
    }
  }

  /// [text] as it goes to native, or why it is not GeoJSON, with its ids as
  /// [_FeatureIds] says. The text is encoded again only when its ids change.
  static (String?, String?) _checkGeoJsonText((String, _FeatureIds) input) {
    final (text, ids) = input;
    if (ids == _FeatureIds.asTheyAre) {
      final reason = geoJsonTextError(text);
      return reason == null ? (text, null) : (null, reason);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return (null, geoJsonTextError(text));
    }
    final (data, reason) = _checkFeatureIds(decoded, ids, geoJsonError);
    if (reason != null) return (null, reason);
    return (identical(data, decoded) ? text : jsonEncode(data), null);
  }

  /// [geojson] with its ids as [ids] says, or why [check] rejects it. Returns
  /// [geojson] itself when its ids stay as they are.
  static (Object?, String?) _checkFeatureIds(
    Object? geojson,
    _FeatureIds ids,
    String? Function(Object?, {GeoJsonFeatureVisitor? onFeature}) check,
  ) {
    final marked = <int>[];
    final reason = check(
      geojson,
      onFeature:
          ids == _FeatureIds.markStringIds ? _collectStringIds(marked) : null,
    );
    if (reason != null) return (null, reason);
    return switch (ids) {
      _FeatureIds.generate => (_withGeneratedIds(geojson), null),
      _ => (_withStringIdMarkers(geojson, marked), null),
    };
  }

  /// [geojson] with the ids `generateId` gives in maplibre-gl-js: each
  /// feature of a FeatureCollection its index, over any id it had, and a lone
  /// Feature 0.
  static Object? _withGeneratedIds(Object? geojson) {
    final json = jsonValueOf(geojson);
    if (json is! Map) return geojson;
    switch (jsonValueOf(json['type'])) {
      case 'Feature':
        return {...json, 'id': 0};
      case 'FeatureCollection':
        final features = jsonValueOf(json['features'])! as List;
        return {
          ...json,
          'features': [
            for (var i = 0; i < features.length; i++)
              {...jsonValueOf(features[i])! as Map, 'id': i},
          ],
        };
    }
    return geojson;
  }

  /// Whether this platform needs [_stringIdMarker]: the Android SDK hands
  /// every feature id over as text, so native cannot tell `"2"` from `2`.
  static bool get _marksStringIds =>
      defaultTargetPlatform == TargetPlatform.android;

  /// The property that marks a feature whose id is text that reads as a
  /// number, so that FeatureJson.java hands the id back as text. Native
  /// removes it from every feature it answers with.
  static const _stringIdMarker = 'maplibre_gl:string_id';

  /// The ids FeatureJson.java turns back into numbers.
  static final _numericText = RegExp(r'^-?(0|[1-9][0-9]*)(\.[0-9]+)?$');

  /// Adds to [indexes] the index of each feature whose id is text that reads
  /// as a number.
  static GeoJsonFeatureVisitor _collectStringIds(List<int> indexes) => (
    index,
    feature,
  ) {
    final id = feature['id'];
    if (id is String && _numericText.hasMatch(id)) indexes.add(index);
  };

  /// [geojson] with [_stringIdMarker] in the properties of the features at
  /// [indexes]: a FeatureCollection's, or 0 for a Feature. Returns [geojson]
  /// itself without any, and copies only what changes otherwise.
  static Object? _withStringIdMarkers(Object? geojson, List<int> indexes) {
    if (indexes.isEmpty) return geojson;
    final json = jsonValueOf(geojson)! as Map;
    if (jsonValueOf(json['type']) == 'Feature') {
      return _withStringIdMarker(json);
    }
    final features = List<Object?>.of(jsonValueOf(json['features'])! as List);
    for (final index in indexes) {
      features[index] = _withStringIdMarker(
        jsonValueOf(features[index])! as Map,
      );
    }
    return {...json, 'features': features};
  }

  static Map _withStringIdMarker(Map feature) => {
    ...feature,
    'properties': {
      ...?jsonValueOf(feature['properties']) as Map?,
      _stringIdMarker: true,
    },
  };

  /// The length of JSON text above which [editGeoJsonSource] checks it on a
  /// background isolate. Isolates share strings, so the text gets there
  /// without a copy and the whole check leaves the main isolate: about
  /// 0.6 ms at this length on a desktop machine.
  static const _geoJsonTextOffloadLength = 100000;

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
    await _inOrder(
      _layerAddKeys(sourceId, layerId, belowLayerId),
      () => _api.symbolLayerAdd(
        sourceId,
        layerId,
        belowLayerId,
        sourceLayer,
        minzoom,
        maxzoom,
        _encodeFilter(filter),
        enableInteraction,
        properties,
      ),
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
    await _inOrder(
      _layerAddKeys(sourceId, layerId, belowLayerId),
      () => _api.lineLayerAdd(
        sourceId,
        layerId,
        belowLayerId,
        sourceLayer,
        minzoom,
        maxzoom,
        _encodeFilter(filter),
        enableInteraction,
        properties,
      ),
    );
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  ) async {
    await _inOrder(
      [_layerKey(layerId)],
      () => _api.layerSetProperties(layerId, properties),
    );
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
    await _inOrder(
      _layerAddKeys(sourceId, layerId, belowLayerId),
      () => _api.circleLayerAdd(
        sourceId,
        layerId,
        belowLayerId,
        sourceLayer,
        minzoom,
        maxzoom,
        _encodeFilter(filter),
        enableInteraction,
        properties,
      ),
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
    await _inOrder(
      _layerAddKeys(sourceId, layerId, belowLayerId),
      () => _api.fillLayerAdd(
        sourceId,
        layerId,
        belowLayerId,
        sourceLayer,
        minzoom,
        maxzoom,
        _encodeFilter(filter),
        enableInteraction,
        properties,
      ),
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
    await _inOrder(
      _layerAddKeys(sourceId, layerId, belowLayerId),
      () => _api.fillExtrusionLayerAdd(
        sourceId,
        layerId,
        belowLayerId,
        sourceLayer,
        minzoom,
        maxzoom,
        _encodeFilter(filter),
        enableInteraction,
        properties,
      ),
    );
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    _ensureDemEncodingSupported(properties);
    final json = normalizeSource(properties.toJson());
    // A string is the url of the data.
    final data = jsonValueOf(json['data']);
    if (properties is! GeojsonSourceProperties) {
      return _inOrder(
        [_sourceKey(sourceId)],
        () => _api.styleAddSource(sourceId, json),
      );
    }
    final generateIds = properties.generateId ?? false;
    if (data == null || data is String) {
      return _addingSource(
        sourceId,
        generateIds: generateIds,
        () => _inOrder(
          [_sourceKey(sourceId)],
          () => _api.styleAddSource(sourceId, json),
        ),
      );
    }
    final input = (
      data,
      generateIds ? _FeatureIds.generate : _defaultFeatureIds,
    );
    return _addingSource(
      sourceId,
      generateIds: generateIds,
      () => _writeGeoJson(sourceId, () async {
        // Checked in place: the check costs less than copying the data to
        // another isolate would.
        final (plain, reason) = _checkSourceData(input);
        if (reason != null) throw invalidGeoJson(sourceId, reason);
        await _api.styleAddSource(sourceId, {...json, 'data': plain});
      }),
    );
  }

  /// [data], the GeoJSON data of `addSource`, with what `jsonEncode` writes in
  /// place of each object it reads through `toJson()` and its ids as
  /// [_FeatureIds] says, or why it is not GeoJSON. The platform channel takes
  /// plain JSON values only.
  static (Object?, String?) _checkSourceData((Object?, _FeatureIds) input) {
    final (data, ids) = input;
    if (_GeoJsonWriter.check(data, ids) case final marked?) {
      return switch (ids) {
        _FeatureIds.generate => (_withGeneratedIds(data), null),
        _ => (_withStringIdMarkers(data, marked), null),
      };
    }
    final (checked, reason) = _checkFeatureIds(data, ids, geoJsonError);
    if (reason != null) return (null, reason);
    return _jsonOrReason<Object?>(() => _plainJson(checked));
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
    await _inOrder(
      _layerAddKeys(sourceId, layerId, belowLayerId),
      () => _api.rasterLayerAdd(
        sourceId,
        layerId,
        belowLayerId,
        minzoom,
        maxzoom,
        properties,
      ),
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
    await _inOrder(
      _layerAddKeys(sourceId, layerId, belowLayerId),
      () => _api.hillshadeLayerAdd(
        sourceId,
        layerId,
        belowLayerId,
        minzoom,
        maxzoom,
        properties,
      ),
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
    await _inOrder(
      _layerAddKeys(sourceId, layerId, belowLayerId),
      () => _api.colorReliefLayerAdd(
        sourceId,
        layerId,
        belowLayerId,
        minzoom,
        maxzoom,
        properties,
      ),
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
    await _inOrder(
      _layerAddKeys(null, layerId, belowLayerId),
      () => _api.backgroundLayerAdd(
        layerId,
        belowLayerId,
        minzoom,
        maxzoom,
        properties,
      ),
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
    await _inOrder(
      _layerAddKeys(sourceId, layerId, belowLayerId),
      () => _api.heatmapLayerAdd(
        sourceId,
        layerId,
        belowLayerId,
        sourceLayer,
        minzoom,
        maxzoom,
        _encodeFilter(filter),
        properties,
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
    await _inOrder(
      [_sourceKey(sourceId)],
      () => _api.sourceSetFeatureState(sourceId, featureId, state, sourceLayer),
    );
  }

  @override
  Future<void> removeFeatureState(
    String sourceId, {
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  }) async {
    await _inOrder(
      [_sourceKey(sourceId)],
      () => _api.sourceRemoveFeatureState(
        sourceId,
        featureId,
        stateKey,
        sourceLayer,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>?> getFeatureState(
    String sourceId,
    String featureId, {
    String? sourceLayer,
  }) async {
    // Native sends the state as JSON text, so nested values arrive intact,
    // and sends null, not an empty object, when the feature has no state,
    // because callers tell the two apart.
    final state = await _inOrder(
      [_sourceKey(sourceId)],
      () => _api.sourceGetFeatureState(sourceId, featureId, sourceLayer),
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
    await _inOrder(
      [_layerKey(layerId)],
      () => _api.layerSetVisibility(layerId, visible),
    );
  }

  @override
  Future<List<String>> setLayersVisibility(
    List<String> layerIds,
    bool visible,
  ) async {
    final missing = await _inOrder(
      layerIds.map(_layerKey),
      () => _api.layerSetVisibilityBatch(layerIds, visible),
    );
    return missing ?? const [];
  }

  @override
  Future<void> setLayerZoomRange(
    String layerId,
    double minzoom,
    double maxzoom,
  ) async {
    await _inOrder(
      [_layerKey(layerId)],
      () => _api.layerSetZoomRange(layerId, minzoom, maxzoom),
    );
  }

  @override
  Future<bool?> getLayerVisibility(String layerId) async {
    return _inOrder(
      [_layerKey(layerId)],
      () => _api.layerGetVisibility(layerId),
    );
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
    return _styleObjectProperties(
      await _inOrder(
        [_layerKey(layerId)],
        () => _api.styleGetLayerProperties(layerId),
      ),
    );
  }

  @override
  Future<Map<String, dynamic>?> getSourceProperties(String sourceId) async {
    return _styleObjectProperties(
      await _inOrder(
        [_sourceKey(sourceId)],
        () => _api.styleGetSourceProperties(sourceId),
      ),
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

/// What the plugin does to the feature ids of GeoJSON data on its way to
/// native.
enum _FeatureIds {
  /// Nothing.
  asTheyAre,

  /// Marks the text ids that read as numbers: see
  /// [_MapLibreNativePlatform._withStringIdMarkers].
  markStringIds,

  /// Gives each feature its index, as `generateId` does in maplibre-gl-js.
  generate,
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
