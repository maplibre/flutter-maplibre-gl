part of '../maplibre_gl_web.dart';

class MapLibreMapController extends MapLibrePlatform
    implements MapLibreMapOptionsSink {
  late web.HTMLDivElement _mapElement;

  late Map<String, dynamic> _creationParams;
  late MapLibreMap _map;
  dynamic _draggedFeatureId;
  LatLng? _dragOrigin;
  LatLng? _dragPrevious;
  bool _dragEnabled = true;
  final _addedFeaturesByLayer = <String, FeatureCollection>{};
  final _hoveredFeatureIdsByLayer = <String, List<dynamic>>{};
  Set<String>? _assetManifest;

  final _interactiveFeatureLayerIds = <String>{};

  bool _trackCameraPosition = false;
  GeolocateControl? _geolocateControl;
  LatLng? _myLastLocation;

  String? _navigationControlPosition;
  NavigationControl? _navigationControl;
  AttributionControl? _attributionControl;
  ScaleControl? _scaleControl;
  String? _scaleControlPosition;
  Timer? lastResizeObserverTimer;

  @override
  Widget buildView(
      Map<String, dynamic> creationParams,
      OnPlatformViewCreatedCallback onPlatformViewCreated,
      Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers) {
    _creationParams = creationParams;
    _registerViewFactory(onPlatformViewCreated, hashCode);
    return HtmlElementView(
        viewType: 'plugins.flutter.io/maplibre_gl_$hashCode');
  }

  @override
  void dispose() {
    _map.remove();
    super.dispose();
  }

  void _registerViewFactory(Function(int) callback, int identifier) {
    ui_web.platformViewRegistry.registerViewFactory(
        'plugins.flutter.io/maplibre_gl_$identifier', (int viewId) {
      _mapElement = (web.document.createElement('div') as web.HTMLDivElement)
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.bottom = '0'
        ..style.height = '100%'
        ..style.width = '100%';
      callback(viewId);
      return _mapElement;
    });
  }

  @override
  Future<void> initPlatform(int id) async {
    final camera =
        _creationParams['initialCameraPosition'] as Map<String, dynamic>?;
    final styleString = _sanitizeStyleObject(_creationParams['styleString']);
    _dragEnabled = _creationParams['dragEnabled'] ?? true;

    _map = MapLibreMap(
      MapOptions(
        container: _mapElement,
        center: (camera != null)
            ? LngLat(camera['target'][1], camera['target'][0])
            : null,
        zoom: camera?['zoom'],
        bearing: camera?['bearing'],
        pitch: camera?['tilt'],
        style: styleString,
        preserveDrawingBuffer: _creationParams['webPreserveDrawingBuffer'],
        attributionControl: false, //avoid duplicate control
      ),
    );
    _map.on('style.load', _onStyleLoaded);
    _map.on('click', _onMapClick);
    // long click not available in web, so it is mapped to double click
    _map.on('dblclick', _onMapLongClick);
    _map.on('movestart', _onCameraMoveStarted);
    _map.on('move', _onCameraMove);
    _map.on('moveend', _onCameraIdle);
    _map.on('resize', (_) => _onMapResize());
    _map.on('styleimagemissing', _loadFromAssets);
    if (_dragEnabled) {
      _map.on('mouseup', _onMouseUp);
      _map.on('mousemove', _onMouseMove);
    }

    _initResizeObserver();

    final options = _creationParams['options'] ?? {};
    Convert.interpretMapLibreMapOptions(options, this, ignoreStyle: true);
  }

  void _initResizeObserver() {
    final resizeObserver = web.ResizeObserver(((JSAny entries, JSAny observer) {
      // The resize observer might be called a lot of times when the user resizes the browser window with the mouse for example.
      // Due to the fact that the resize call is quite expensive it should not be called for every triggered event but only the last one, like "onMoveEnd".
      // But because there is no event type for the end, there is only the option to spawn timers and cancel the previous ones if they get overwritten by a new event.
      lastResizeObserverTimer?.cancel();
      lastResizeObserverTimer = Timer(const Duration(milliseconds: 50), () {
        _onMapResize();
      });
    }).toJS);
    resizeObserver.observe(_mapElement);
  }

  Future<Set<String>> _loadAssetManifest() async {
    if (_assetManifest != null) return _assetManifest!;

    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = assetManifest.listAssets();
      _assetManifest = assets.toSet();
    } catch (_) {
      // If the manifest can't be read, assume no declared assets
      _assetManifest = <String>{};
    }

    return _assetManifest!;
  }

  Future<void> _loadFromAssets(Event event) async {
    final imagePath = event.id;

    // Check if the image is already added
    if (_map.hasImage(imagePath)) return;

    // Check if the image is declared in the assets loaded
    final manifest = await _loadAssetManifest();
    if (!manifest.contains(imagePath) &&
        !manifest.contains('assets/$imagePath')) {
      return;
    }

    try {
      final bytes = await rootBundle.load(imagePath);
      await addImage(imagePath, bytes.buffer.asUint8List());
    } catch (_) {
      // If it still fails, ignore so MapLibre can continue without the image.
    }
  }

  void _onMouseDown(Event e, String? layerId) {
    // Check if there are features under the mouse cursor
    if (e.features.isEmpty) return;

    final isDraggable = e.features.first.getProperty('draggable');
    if (isDraggable != null && isDraggable) {
      // Prevent the default map drag behavior.
      e.preventDefault();
      _draggedFeatureId = e.features.first.id;
      _map.getCanvas().style.cursor = 'grabbing';
      final coords = e.lngLat;
      _dragOrigin = LatLng(coords.lat as double, coords.lng as double);

      if (_draggedFeatureId != null) {
        final current =
            LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble());
        final payload = {
          'id': _draggedFeatureId,
          'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
          'origin': _dragOrigin,
          'current': current,
          'delta': const LatLng(0, 0),
          'eventType': 'start'
        };
        onFeatureDraggedPlatform(payload);
      }
    }
  }

  _onMouseUp(Event e) {
    if (_draggedFeatureId != null) {
      final current = LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble());
      final payload = {
        'id': _draggedFeatureId,
        'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
        'origin': _dragOrigin,
        'current': current,
        'delta': current - (_dragPrevious ?? _dragOrigin!),
        'eventType': 'end'
      };
      onFeatureDraggedPlatform(payload);
    }
    _draggedFeatureId = null;
    _dragPrevious = null;
    _dragOrigin = null;
    _map.getCanvas().style.cursor = '';
  }

  _onMouseMove(Event e) {
    if (_draggedFeatureId != null) {
      final current = LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble());
      final payload = {
        'id': _draggedFeatureId,
        'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
        'origin': _dragOrigin,
        'current': current,
        'delta': current - (_dragPrevious ?? _dragOrigin!),
        'eventType': 'drag'
      };
      _dragPrevious = current;
      onFeatureDraggedPlatform(payload);
    }
  }

  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> optionsUpdate,
  ) async {
    Convert.interpretMapLibreMapOptions(optionsUpdate, this);
    return _getCameraPosition();
  }

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate,
      {Duration? duration}) async {
    final cameraOptions = Convert.toCameraOptions(cameraUpdate, _map);

    // Use the existing CameraOptions wrapper which has proper WASM-compatible accessors
    final around = cameraOptions.around;
    final bearing = cameraOptions.bearing;
    final center = cameraOptions.center;
    final pitch = cameraOptions.pitch;
    final zoom = cameraOptions.zoom;

    _map.flyTo({
      if (around != null) 'around': around.jsObject,
      if (bearing != null) 'bearing': bearing,
      if (center != null) 'center': center.jsObject,
      if (pitch != null) 'pitch': pitch,
      if (zoom != null) 'zoom': zoom,
      if (duration != null) 'duration': duration.inMilliseconds,
    });

    return true;
  }

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    final cameraOptions = Convert.toCameraOptions(cameraUpdate, _map);
    _map.jumpTo(cameraOptions);
    return true;
  }

  @override
  Future<void> updateMyLocationTrackingMode(
      MyLocationTrackingMode myLocationTrackingMode) async {
    setMyLocationTrackingMode(myLocationTrackingMode.index);
  }

  @override
  Future<void> matchMapLanguageWithDeviceDefault() async {
    // Fix in https://github.com/maplibre/flutter-maplibre-gl/issues/263
    // ignore: deprecated_member_use
    setMapLanguage(ui.window.locale.languageCode);
  }

  @override
  Future<void> setMapLanguage(String language) async {
    final layers = _map.getLayers();

    final languageRegex = RegExp("(name:[a-z]+)");

    final symbolLayers = layers.where((layer) => layer.type == "symbol");

    for (final layer in symbolLayers) {
      final dynamic properties = _map.getLayoutProperty(layer.id, 'text-field');

      if (properties == null) {
        continue;
      }

      // We could skip the current iteration, whenever there is not current language.
      if (!languageRegex.hasMatch(properties.toString())) {
        continue;
      }

      final newProperties = [
        "coalesce",
        ["get", "name:$language"],
        ["get", "name:latin"],
        ["get", "name"],
      ];

      _map.setLayoutProperty(layer.id, 'text-field', newProperties);
    }
  }

  @override
  Future<void> setTelemetryEnabled(bool enabled) async {
    print('Telemetry not available in web');
    return;
  }

  @override
  Future<bool> getTelemetryEnabled() async {
    print('Telemetry not available in web');
    return false;
  }

  @override
  Future<void> setMaximumFps(int fps) async {
    // Web implementation: MapLibre GL JS doesn't have direct FPS control
    // We can implement this by controlling render frequency if needed
    print('setMaximumFps not fully supported in web, fps: $fps');
    // For future implementation, we could use requestAnimationFrame throttling
  }

  @override
  Future<void> forceOnlineMode() async {
    // Web implementation: Force online mode
    // In web, we can ensure network requests are enabled
    print('forceOnlineMode called in web');
    // This is mostly a no-op in web as it's always online
  }

  @override
  Future<bool> easeCamera(CameraUpdate cameraUpdate,
      {Duration? duration}) async {
    // Web implementation: MapLibre GL JS doesn't have direct duration control
    // We can implement this by using the animate method with duration
    print('easeCamera called in web, duration: $duration');
    // For future implementation, we could use MapLibre GL JS animate method
    throw UnimplementedError();
  }

  @override
  Future<CameraPosition?> queryCameraPosition() async {
    // Web implementation: MapLibre GL JS doesn't have direct camera position query
    print('queryCameraPosition called in web');
    // For future implementation, we could query the map's camera state
    throw UnimplementedError();
  }

  @override
  Future<bool> editGeoJsonSource(String id, String data) async {
    // Web implementation: MapLibre GL JS doesn't have direct GeoJSON source editing
    print('editGeoJsonSource called in web, id: $id');
    // For future implementation, we could use MapLibre GL JS source methods
    throw UnimplementedError();
  }

  @override
  Future<bool> editGeoJsonUrl(String id, String url) async {
    // Web implementation: MapLibre GL JS doesn't have direct GeoJSON URL editing
    print('editGeoJsonUrl called in web, id: $id, url: $url');
    // For future implementation, we could use MapLibre GL JS source methods
    throw UnimplementedError();
  }

  @override
  Future<bool> setLayerFilter(String layerId, String filter) async {
    // Web implementation: MapLibre GL JS doesn't have direct layer filter setting
    print('setLayerFilter called in web, layerId: $layerId, filter: $filter');
    // For future implementation, we could use MapLibre GL JS layer filter methods
    throw UnimplementedError();
  }

  @override
  Future<String?> getStyle() async {
    final styleJs = _map.getStyle();
    if (styleJs == null) return null;

    // Convert JS object to Dart map, then to JSON string
    final styleMap = dartify(styleJs);
    return jsonEncode(styleMap);
  }

  @override
  Future<void> setCustomHeaders(
      Map<String, String> headers, List<String> filter) async {
    // Web implementation: MapLibre GL JS doesn't have direct custom headers setting
    print('setCustomHeaders called in web, headers: $headers, filter: $filter');
    // For future implementation, we could use MapLibre GL JS HTTP configuration
    throw UnimplementedError();
  }

  @override
  Future<Map<String, String>> getCustomHeaders() async {
    // Web implementation: MapLibre GL JS doesn't have direct custom headers retrieval
    print('getCustomHeaders called in web');
    // For future implementation, we could use MapLibre GL JS HTTP configuration
    throw UnimplementedError();
  }

  @override
  Future<List> queryRenderedFeatures(
      Point<double> point, List<String> layerIds, List<Object>? filter) async {
    if (!_map.isStyleLoaded()) {
      // Style is not loaded yet, return empty list
      print(
          'MapLibreMapController: queryRenderedFeatures, Style not loaded yet, returning empty list');
      return [];
    }

    final options = <String, dynamic>{};
    if (layerIds.isNotEmpty) {
      options['layers'] = layerIds;
    }
    if (filter != null) {
      options['filter'] = filter;
    }

    // avoid issues with the js point type
    final geometry = jsify([point.x, point.y]);
    if (geometry == null) return [];

    return _map
        .queryRenderedFeatures(geometry, options)
        .map((feature) => <String, dynamic>{
              'type': 'Feature',
              'id': feature.id,
              'geometry': <String, dynamic>{
                'type': feature.geometry.type,
                'coordinates': feature.geometry.coordinates,
              },
              'properties': feature.properties,
              'source': feature.source,
            })
        .toList();
  }

  @override
  Future<List> queryRenderedFeaturesInRect(
      Rect rect, List<String> layerIds, String? filter) async {
    if (!_map.isStyleLoaded()) {
      // Style is not loaded yet, return empty list
      print(
          'MapLibreMapController: queryRenderedFeaturesInRect, Style not loaded yet, returning empty list');
      return [];
    }

    final options = <String, dynamic>{};
    if (layerIds.isNotEmpty) {
      options['layers'] = layerIds;
    }
    if (filter != null) {
      options['filter'] = filter;
    }

    final geometry = jsify([
      [rect.left, rect.bottom],
      [rect.right, rect.top],
    ]);
    if (geometry == null) return [];
    return _map
        .queryRenderedFeatures(geometry, options)
        .map((feature) => <String, dynamic>{
              'type': 'Feature',
              'id': feature.id,
              'geometry': <String, dynamic>{
                'type': feature.geometry.type,
                'coordinates': feature.geometry.coordinates,
              },
              'properties': feature.properties,
              'source': feature.source,
            })
        .toList();
  }

  @override
  Future<List> querySourceFeatures(
      String sourceId, String? sourceLayerId, List<Object>? filter) async {
    if (!_map.isStyleLoaded()) {
      // Style is not loaded yet, return empty list
      print(
          'MapLibreMapController: querySourceFeatures, Style not loaded yet, returning empty list');
      return [];
    }

    final parameters = <String, dynamic>{};

    if (sourceLayerId != null) {
      parameters['sourceLayer'] = sourceLayerId;
    }

    if (filter != null) {
      parameters['filter'] = filter;
    }
    print('Query source features parameters: $parameters');

    return _map
        .querySourceFeatures(sourceId, parameters)
        .map((feature) => <String, dynamic>{
              'type': 'Feature',
              'id': feature.id,
              'geometry': <String, dynamic>{
                'type': feature.geometry.type,
                'coordinates': feature.geometry.coordinates,
              },
              'properties': feature.properties,
              'source': feature.source,
            })
        .toList();
  }

  @override
  Future invalidateAmbientCache() async {
    print('Offline storage not available in web');
  }

  @override
  Future clearAmbientCache() async {
    print('Offline storage not available in web');
  }

  @override
  Future<LatLng?> requestMyLocationLatLng() async {
    return _myLastLocation;
  }

  @override
  Future<LatLngBounds> getVisibleRegion() async {
    final bounds = _map.getBounds();
    return LatLngBounds(
      southwest: LatLng(
        bounds.getSouthWest().lat as double,
        bounds.getSouthWest().lng as double,
      ),
      northeast: LatLng(
        bounds.getNorthEast().lat as double,
        bounds.getNorthEast().lng as double,
      ),
    );
  }

  @override
  Future<void> addImage(String name, Uint8List bytes,
      [bool sdf = false]) async {
    final photo = decodeImage(bytes)!;
    if (!_map.hasImage(name)) {
      // Convert image to RGBA format with proper byte ordering
      final rgbaBytes = photo.convert(numChannels: 4).getBytes();
      final data = Uint8List.fromList(rgbaBytes);

      await _map.addImage(
        name,
        {
          'width': photo.width,
          'height': photo.height,
          'data': data,
        },
        {'sdf': sdf, 'pixelRatio': 1},
      );
    } else {
      print('MapLibreMapController: Image already exists on map: $name');
    }
  }

  @override
  Future<void> removeSource(String sourceId) async {
    _map.removeSource(sourceId);
  }

  CameraPosition? _getCameraPosition() {
    if (_trackCameraPosition) {
      final center = _map.getCenter();
      return CameraPosition(
        bearing: _map.getBearing() as double,
        target: LatLng(center.lat as double, center.lng as double),
        tilt: _map.getPitch() as double,
        zoom: _map.getZoom() as double,
      );
    }
    return null;
  }

  void _onStyleLoaded(data) {
    final loaded = _map.isStyleLoaded();
    if (!loaded) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _onStyleLoaded(data);
      });
      return;
    }
    _onMapResize();
    onMapStyleLoadedPlatform(null);
  }

  void _onMapResize() {
    Timer(Duration.zero, () {
      final container = _map.getContainer();
      final canvas = _map.getCanvas();
      final widthMismatch = canvas.clientWidth != container.clientWidth;
      final heightMismatch = canvas.clientHeight != container.clientHeight;
      if (widthMismatch || heightMismatch) {
        _map.resize();
      }
    });
  }

  /// Handle map click event
  ///
  /// If the click intersects with any features in interactive layers, trigger
  /// `onFeatureTappedPlatform` with the first feature's info.
  /// Otherwise, trigger `onMapClickPlatform`.
  ///
  /// Both events include the click point and latLng.
  void _onMapClick(Event e) {
    final geometry = jsify([
      [e.point.x, e.point.y],
      [e.point.x, e.point.y]
    ]);
    if (geometry == null) return;
    // Query rendered features in the point box
    final features = _map.queryRenderedFeatures(geometry);

    // Keep only interactive-layer features (preserve order)
    final filtered = features
        .where((f) => _interactiveFeatureLayerIds.contains(f.layerId))
        .toList(growable: false);

    // Prepare common payload for both events (mapClick or featureTapped)
    final payload = <String, dynamic>{
      'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
      'latLng': LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble()),
    };

    if (filtered.isNotEmpty) {
      // Add 'first' feature info to payload
      payload['layerId'] = filtered.first.layerId;
      payload['id'] = filtered.first.id;
      onFeatureTappedPlatform(payload);
    }

    // Always fire onMapClickPlatform for all map clicks
    onMapClickPlatform(payload);
  }

  void _onMapLongClick(e) {
    onMapLongClickPlatform({
      'point': Point<double>(e.point.x, e.point.y),
      'latLng': LatLng(e.lngLat.lat, e.lngLat.lng),
    });
  }

  void _onCameraMoveStarted(_) {
    onCameraMoveStartedPlatform(null);
  }

  void _onCameraMove(_) {
    final center = _map.getCenter();
    final camera = CameraPosition(
      bearing: _map.getBearing() as double,
      target: LatLng(center.lat as double, center.lng as double),
      tilt: _map.getPitch() as double,
      zoom: _map.getZoom() as double,
    );
    onCameraMovePlatform(camera);
  }

  void _onCameraIdle(_) {
    final center = _map.getCenter();
    final camera = CameraPosition(
      bearing: _map.getBearing() as double,
      target: LatLng(center.lat as double, center.lng as double),
      tilt: _map.getPitch() as double,
      zoom: _map.getZoom() as double,
    );
    onCameraIdlePlatform(camera);
  }

  void _onCameraTrackingChanged(bool isTracking) {
    if (isTracking) {
      onCameraTrackingChangedPlatform(MyLocationTrackingMode.tracking);
    } else {
      onCameraTrackingChangedPlatform(MyLocationTrackingMode.none);
    }
  }

  void _onCameraTrackingDismissed() {
    onCameraTrackingDismissedPlatform(null);
  }

  void _addGeolocateControl({bool trackUserLocation = false}) {
    _removeGeolocateControl();
    _geolocateControl = GeolocateControl(
      GeolocateControlOptions(
        positionOptions: PositionOptions(enableHighAccuracy: true),
        trackUserLocation: trackUserLocation,
        showAccuracyCircle: true,
        showUserLocation: true,
      ),
    );
    _geolocateControl!.on('geolocate', (e) {
      _myLastLocation = LatLng(e.coords.latitude, e.coords.longitude);
      onUserLocationUpdatedPlatform(UserLocation(
          position: LatLng(e.coords.latitude, e.coords.longitude),
          altitude: e.coords.altitude,
          bearing: e.coords.heading,
          speed: e.coords.speed,
          horizontalAccuracy: e.coords.accuracy,
          verticalAccuracy: e.coords.altitudeAccuracy,
          heading: null,
          timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestamp)));
    });
    _geolocateControl!.on('trackuserlocationstart', (_) {
      _onCameraTrackingChanged(true);
    });
    _geolocateControl!.on('trackuserlocationend', (_) {
      _onCameraTrackingChanged(false);
      _onCameraTrackingDismissed();
    });
    _map.addControl(_geolocateControl, 'bottom-right');
  }

  void _removeGeolocateControl() {
    if (_geolocateControl != null) {
      _map.removeControl(_geolocateControl);
      _geolocateControl = null;
    }
  }

  void _updateNavigationControl({
    bool? compassEnabled,
    CompassViewPosition? position,
  }) {
    bool? prevShowCompass;
    if (_navigationControl != null) {
      prevShowCompass = _navigationControl!.options.showCompass;
    }
    final prevPosition = _navigationControlPosition;

    final positionString = switch (position) {
      CompassViewPosition.topRight => 'top-right',
      CompassViewPosition.topLeft => 'top-left',
      CompassViewPosition.bottomRight => 'bottom-right',
      CompassViewPosition.bottomLeft => 'bottom-left',
      _ => null,
    };

    final newShowCompass = compassEnabled ?? prevShowCompass ?? false;
    final newPosition = positionString ?? prevPosition;

    _removeNavigationControl();
    _navigationControl = NavigationControl(NavigationControlOptions(
      showCompass: newShowCompass,
      showZoom: false,
      visualizePitch: false,
    ));

    if (newPosition == null) {
      _map.addControl(_navigationControl);
    } else {
      _map.addControl(_navigationControl, newPosition);
      _navigationControlPosition = newPosition;
    }
  }

  void _removeNavigationControl() {
    if (_navigationControl != null) {
      _map.removeControl(_navigationControl);
      _navigationControl = null;
    }
  }

  void _updateAttributionButton(
    AttributionButtonPosition position,
  ) {
    String? positionString;
    switch (position) {
      case AttributionButtonPosition.topRight:
        positionString = 'top-right';
      case AttributionButtonPosition.topLeft:
        positionString = 'top-left';
      case AttributionButtonPosition.bottomRight:
        positionString = 'bottom-right';
      case AttributionButtonPosition.bottomLeft:
        positionString = 'bottom-left';
    }

    _removeAttributionButton();
    _attributionControl = AttributionControl(AttributionControlOptions());
    _map.addControl(_attributionControl, positionString);
  }

  void _removeAttributionButton() {
    if (_attributionControl != null) {
      _map.removeControl(_attributionControl);
      _attributionControl = null;
    }
  }

  /*
   *  MapLibreMapOptionsSink
   */
  @override
  void setAttributionButtonMargins(int x, int y) {
    print('setAttributionButtonMargins not available in web');
  }

  @override
  void setScaleControlEnabled(bool enabled) {
    if (enabled) {
      _addScaleControl();
    } else {
      _removeScaleControl();
    }
  }

  @override
  void setScaleControlPosition(ScaleControlPosition position) {
    final positionString = switch (position) {
      ScaleControlPosition.topLeft => 'top-left',
      ScaleControlPosition.topRight => 'top-right',
      ScaleControlPosition.bottomLeft => 'bottom-left',
      ScaleControlPosition.bottomRight => 'bottom-right',
    };
    // Only re-add if position changed
    if (_scaleControl != null && _scaleControlPosition != positionString) {
      _addScaleControl(position: position);
    }
  }

  @override
  void setScaleControlUnit(ScaleControlUnit unit) {
    if (_scaleControl != null) {
      final unitString = switch (unit) {
        ScaleControlUnit.metric => 'metric',
        ScaleControlUnit.imperial => 'imperial',
        ScaleControlUnit.nautical => 'nautical',
      };
      _scaleControl!.setUnit(unitString);
    }
  }

  void _addScaleControl({ScaleControlPosition? position}) {
    _removeScaleControl();

    final positionString =
        switch (position ?? ScaleControlPosition.bottomLeft) {
      ScaleControlPosition.topLeft => 'top-left',
      ScaleControlPosition.topRight => 'top-right',
      ScaleControlPosition.bottomLeft => 'bottom-left',
      ScaleControlPosition.bottomRight => 'bottom-right',
    };

    _scaleControl = ScaleControl(
      ScaleControlOptions(
        maxWidth: 80,
      ),
    );
    _scaleControlPosition = positionString;
    _map.addControl(_scaleControl, positionString);
  }

  void _removeScaleControl() {
    if (_scaleControl != null) {
      _map.removeControl(_scaleControl);
      _scaleControl = null;
      _scaleControlPosition = null;
    }
  }

  @override
  void setCameraTargetBounds(LatLngBounds? bounds) {
    if (bounds == null) {
      _map.setMaxBounds(null);
    } else {
      _map.setMaxBounds(
        LngLatBounds(
          LngLat(
            bounds.southwest.longitude,
            bounds.southwest.latitude,
          ),
          LngLat(
            bounds.northeast.longitude,
            bounds.northeast.latitude,
          ),
        ),
      );
    }
  }

  @override
  void setCompassEnabled(bool compassEnabled) {
    _updateNavigationControl(compassEnabled: compassEnabled);
  }

  @override
  void setCompassAlignment(CompassViewPosition position) {
    _updateNavigationControl(position: position);
  }

  @override
  void setAttributionButtonAlignment(AttributionButtonPosition position) {
    _updateAttributionButton(position);
  }

  @override
  void setCompassViewMargins(int x, int y) {
    print('setCompassViewMargins not available in web');
  }

  @override
  void setLogoViewAlignment(LogoViewPosition position) {
    print('setLogoViewAlignment not available in web');
  }

  @override
  void setLogoViewMargins(int x, int y) {
    print('setLogoViewMargins not available in web');
  }

  @override
  void setMinMaxZoomPreference(num? min, num? max) {
    // FIX: why is called indefinitely? (map_ui page)
    _map.setMinZoom(min);
    _map.setMaxZoom(max);
  }

  @override
  void setMyLocationEnabled(bool myLocationEnabled) {
    if (myLocationEnabled) {
      _addGeolocateControl();
    } else {
      _removeGeolocateControl();
    }
  }

  @override
  void setMyLocationRenderMode(int myLocationRenderMode) {
    print('myLocationRenderMode not available in web');
  }

  @override
  void setMyLocationTrackingMode(int myLocationTrackingMode) {
    if (_geolocateControl == null) {
      //myLocationEnabled is false, ignore myLocationTrackingMode
      return;
    }
    if (myLocationTrackingMode == 0) {
      _addGeolocateControl();
    } else {
      print('Only one tracking mode available in web');
      _addGeolocateControl(trackUserLocation: true);
    }
  }

  /// Sets the map style.
  ///
  /// The [styleString] parameter can be one of the following:
  /// - A JSON string representing a MapLibre style object.
  /// - A URL (http/https) pointing to a MapLibre style JSON document.
  /// - An absolute file path to a MapLibre style JSON file.
  /// - An asset path (prefixed with 'assets/') to a style JSON included in the app bundle.
  ///
  /// The style must conform to the MapLibre Style Specification:
  /// https://maplibre.org/projects/maplibre-gl-js/style-spec/
  ///
  /// Example usage:
  /// ```dart
  /// await controller.setStyle('https://demotiles.maplibre.org/style.json');
  /// await controller.setStyle('{"version":8,"sources":{...},"layers":[...]}');
  /// await controller.setStyle('/absolute/path/to/style.json');
  /// await controller.setStyle('assets/styles/my_style.json');
  /// ```
  @override
  Future<void> setStyle(dynamic styleObject) async {
    //remove old mouseenter callbacks to avoid multicalling
    for (final layerId in _interactiveFeatureLayerIds) {
      _map.off('mouseenter', layerId, _handleLayerMouseMove);
      _map.off('mousemove', layerId, _handleLayerMouseMove);
      _map.off('mouseleave', layerId, _handleLayerMouseMove);
      if (_dragEnabled) _map.off('mousedown', layerId, _onMouseDown);
    }
    _interactiveFeatureLayerIds.clear();

    final sanitizedStyle = _sanitizeStyleObject(styleObject);
    _map.setStyle(sanitizedStyle, {'diff': false});
  }

  /// Sanitizes the style object to ensure it is in the correct format.
  /// If the style object is a JSON string, use JavaScript's native JSON.parse
  /// to avoid Dart object metadata leaking into web workers.
  dynamic _sanitizeStyleObject(dynamic styleObject) {
    if (styleObject is String &&
        (styleObject.startsWith('{') || styleObject.startsWith('['))) {
      // Use JavaScript's native JSON.parse to create pure JS objects
      return jsonParse(styleObject);
    } else {
      return styleObject;
    }
  }

  @override
  void setTrackCameraPosition(bool trackCameraPosition) {
    _trackCameraPosition = trackCameraPosition;
  }

  @override
  Future<LatLng> toLatLng(Point<num> screenLocation) async {
    final lngLat =
        _map.unproject(geo_point.Point(screenLocation.x, screenLocation.y));
    return LatLng(lngLat.lat as double, lngLat.lng as double);
  }

  @override
  Future<Point> toScreenLocation(LatLng latLng) async {
    final screenPosition =
        _map.project(LngLat(latLng.longitude, latLng.latitude));
    final point = Point(screenPosition.x.round(), screenPosition.y.round());

    return point;
  }

  @override
  Future<List<Point<num>>> toScreenLocationBatch(
      Iterable<LatLng> latLngs) async {
    return latLngs.map((latLng) {
      final screenPosition =
          _map.project(LngLat(latLng.longitude, latLng.latitude));
      return Point(screenPosition.x.round(), screenPosition.y.round());
    }).toList(growable: false);
  }

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) async {
    //https://wiki.openstreetmap.org/wiki/Zoom_levels
    const circumference = 40075017.686;
    final zoom = _map.getZoom();
    return circumference * cos(latitude * (pi / 180)) / pow(2, zoom + 9);
  }

  @override
  Future<void> removeLayer(String imageLayerId) async {
    _interactiveFeatureLayerIds.remove(imageLayerId);
    _map.removeLayer(imageLayerId);
  }

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {
    _map.setFilter(layerId, filter);
  }

  @override
  Future<void> addGeoJsonSource(String sourceId, Map<String, dynamic> geojson,
      {String? promoteId}) async {
    final data = _makeFeatureCollection(geojson);
    _addedFeaturesByLayer[sourceId] = data;
    _map.addSource(sourceId, <String, dynamic>{
      "type": 'geojson',
      "data": geojson, // pass the raw string here to avoid errors
      if (promoteId != null) "promoteId": promoteId
    });
  }

  Feature _makeFeature(Map<String, dynamic> geojsonFeature) {
    final geometry =
        Map<String, dynamic>.from(geojsonFeature["geometry"] as Map);
    final propertiesRaw = geojsonFeature["properties"];
    final properties = propertiesRaw != null
        ? Map<String, dynamic>.from(propertiesRaw as Map)
        : null;

    return Feature(
      geometry: Geometry(
          type: geometry["type"], coordinates: geometry["coordinates"]),
      properties: properties,
      id: properties?["id"] ?? geojsonFeature["id"],
    );
  }

  FeatureCollection _makeFeatureCollection(Map<String, dynamic> geojson) {
    return FeatureCollection(
        features: [for (final f in geojson["features"] ?? []) _makeFeature(f)]);
  }

  @override
  Future<void> setGeoJsonSource(
      String sourceId, Map<String, dynamic> geojson) async {
    final source = _map.getSource(sourceId) as GeoJsonSource;
    final data = _makeFeatureCollection(geojson);
    _addedFeaturesByLayer[sourceId] = data;
    source.setData(data);
  }

  @override
  Future setCameraBounds({
    required double west,
    required double north,
    required double south,
    required double east,
    required int padding,
  }) async {
    _map.fitBounds(LngLatBounds(LngLat(west, south), LngLat(east, north)),
        {'padding': padding});
  }

  @override
  Future<void> addFillExtrusionLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      dynamic filter,
      required bool enableInteraction}) async {
    return _addLayer(sourceId, layerId, properties, "fill-extrusion",
        belowLayerId: belowLayerId,
        sourceLayer: sourceLayer,
        minzoom: minzoom,
        maxzoom: maxzoom,
        filter: filter,
        enableInteraction: enableInteraction);
  }

  @override
  Future<void> addCircleLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      dynamic filter,
      required bool enableInteraction}) async {
    return _addLayer(sourceId, layerId, properties, "circle",
        belowLayerId: belowLayerId,
        sourceLayer: sourceLayer,
        minzoom: minzoom,
        maxzoom: maxzoom,
        filter: filter,
        enableInteraction: enableInteraction);
  }

  @override
  Future<void> addFillLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      dynamic filter,
      required bool enableInteraction}) async {
    return _addLayer(sourceId, layerId, properties, "fill",
        belowLayerId: belowLayerId,
        sourceLayer: sourceLayer,
        minzoom: minzoom,
        maxzoom: maxzoom,
        filter: filter,
        enableInteraction: enableInteraction);
  }

  @override
  Future<void> addLineLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      dynamic filter,
      required bool enableInteraction}) async {
    return _addLayer(sourceId, layerId, properties, "line",
        belowLayerId: belowLayerId,
        sourceLayer: sourceLayer,
        minzoom: minzoom,
        maxzoom: maxzoom,
        filter: filter,
        enableInteraction: enableInteraction);
  }

  @override
  Future<void> setLayerProperties(
      String layerId, Map<String, dynamic> properties) async {
    for (final entry in properties.entries) {
      // Try paint property first (most common), then layout property
      try {
        _map.setPaintProperty(layerId, entry.key, entry.value);
      } catch (e) {
        // If setPaintProperty fails, try setLayoutProperty
        try {
          _map.setLayoutProperty(layerId, entry.key, entry.value);
        } catch (e) {
          // If both fail, the property doesn't exist on this layer type
          print(
              'Warning: Could not set property "${entry.key}" on layer "$layerId" for value "${entry.value}": $e');
        }
      }
    }
  }

  @override
  Future<void> addSymbolLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      dynamic filter,
      required bool enableInteraction}) async {
    return _addLayer(sourceId, layerId, properties, "symbol",
        belowLayerId: belowLayerId,
        sourceLayer: sourceLayer,
        minzoom: minzoom,
        maxzoom: maxzoom,
        filter: filter,
        enableInteraction: enableInteraction);
  }

  @override
  Future<void> addHillshadeLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom}) async {
    return _addLayer(sourceId, layerId, properties, "hillshade",
        belowLayerId: belowLayerId,
        sourceLayer: sourceLayer,
        minzoom: minzoom,
        maxzoom: maxzoom,
        enableInteraction: false);
  }

  @override
  Future<void> addHeatmapLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom}) async {
    return _addLayer(sourceId, layerId, properties, "heatmap",
        belowLayerId: belowLayerId,
        sourceLayer: sourceLayer,
        minzoom: minzoom,
        maxzoom: maxzoom,
        enableInteraction: false);
  }

  @override
  Future<void> addRasterLayer(
      String sourceId, String layerId, Map<String, dynamic> properties,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom}) async {
    await _addLayer(sourceId, layerId, properties, "raster",
        belowLayerId: belowLayerId,
        sourceLayer: sourceLayer,
        minzoom: minzoom,
        maxzoom: maxzoom,
        enableInteraction: false);
  }

  Future<void> _addLayer(String sourceId, String layerId,
      Map<String, dynamic> properties, String layerType,
      {String? belowLayerId,
      String? sourceLayer,
      double? minzoom,
      double? maxzoom,
      dynamic filter,
      required bool enableInteraction}) async {
    final layout = Map<String, dynamic>.fromEntries(
        properties.entries.where((entry) => isLayoutProperty(entry.key)));
    final paint = Map<String, dynamic>.fromEntries(
        properties.entries.where((entry) => !isLayoutProperty(entry.key)));

    _map.addLayer(<String, dynamic>{
      'id': layerId,
      'type': layerType,
      'source': sourceId,
      'layout': layout,
      'paint': paint,
      if (sourceLayer != null) 'source-layer': sourceLayer,
      if (minzoom != null) 'minzoom': minzoom,
      if (maxzoom != null) 'maxzoom': maxzoom,
      if (filter != null) 'filter': filter,
    }, belowLayerId);

    if (enableInteraction) {
      _interactiveFeatureLayerIds.add(layerId);
      _map.on('mouseenter', layerId, _handleLayerMouseMove);
      _map.on('mousemove', layerId, _handleLayerMouseMove);
      _map.on('mouseleave', layerId, _handleLayerMouseMove);
      if (_dragEnabled) _map.on('mousedown', layerId, _onMouseDown);
    }
  }

  void _handleLayerMouseMove(Event e, String layerId) {
    // Normalize feature ids to String to avoid type mismatch (ids can be int, String, etc.)
    final currentHoveredFeatures =
        e.features.map((f) => f.id?.toString()).whereType<String>().toList();
    final lastHoveredFeatures = _hoveredFeatureIdsByLayer[layerId] ?? [];
    final features = <String>{
      ...currentHoveredFeatures,
      ...lastHoveredFeatures,
    };
    _hoveredFeatureIdsByLayer[layerId] = currentHoveredFeatures;

    for (final feature in features) {
      final isCurrentlyHovered = currentHoveredFeatures.contains(feature);
      final isPreviouslyHovered = lastHoveredFeatures.contains(feature);
      late final String eventType;
      if (isCurrentlyHovered && isPreviouslyHovered) {
        eventType = 'move';
      } else if (isCurrentlyHovered && !isPreviouslyHovered) {
        eventType = 'enter';
        if (_draggedFeatureId == null) {
          _map.getCanvas().style.cursor = 'pointer';
        }
      } else if (!isCurrentlyHovered && isPreviouslyHovered) {
        eventType = 'leave';
      }

      onFeatureHoverPlatform({
        'id': feature,
        'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
        'latLng': LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble()),
        'eventType': eventType
      });
    }

    final isAnyFeatureHovered = _hoveredFeatureIdsByLayer.values
        .any((hoveredFeatures) => hoveredFeatures.isNotEmpty);
    if (isAnyFeatureHovered && _draggedFeatureId == null) {
      _map.getCanvas().style.cursor = 'pointer';
    }
    if (!isAnyFeatureHovered) {
      _map.getCanvas().style.cursor = '';
    }
  }

  @override
  void setGestures(
      {required bool rotateGesturesEnabled,
      required bool scrollGesturesEnabled,
      required bool tiltGesturesEnabled,
      required bool zoomGesturesEnabled,
      required bool doubleClickZoomEnabled}) {
    if (rotateGesturesEnabled &&
        scrollGesturesEnabled &&
        tiltGesturesEnabled &&
        zoomGesturesEnabled) {
      _map.keyboard.enable();
    } else {
      _map.keyboard.disable();
    }

    if (scrollGesturesEnabled) {
      _map.dragPan.enable();
    } else {
      _map.dragPan.disable();
    }

    if (zoomGesturesEnabled) {
      _map.doubleClickZoom.enable();
      _map.boxZoom.enable();
      _map.scrollZoom.enable();
      _map.touchZoomRotate.enable();
    } else {
      _map.doubleClickZoom.disable();
      _map.boxZoom.disable();
      _map.scrollZoom.disable();
      _map.touchZoomRotate.disable();
    }

    if (doubleClickZoomEnabled) {
      _map.doubleClickZoom.enable();
    } else {
      _map.doubleClickZoom.disable();
    }

    if (rotateGesturesEnabled) {
      _map.touchZoomRotate.enableRotation();
    } else {
      _map.touchZoomRotate.disableRotation();
    }

    // dragRotate is shared by both gestures
    if (tiltGesturesEnabled && rotateGesturesEnabled) {
      _map.dragRotate.enable();
    } else {
      _map.dragRotate.disable();
    }
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    _map.addSource(sourceId, properties.toJson());
  }

  @override
  Future<void> addImageSource(
      String imageSourceId, Uint8List bytes, LatLngQuad coordinates) {
    // TODO: implement addImageSource
    throw UnimplementedError();
  }

  @override
  Future<void> updateImageSource(
      String imageSourceId, Uint8List? bytes, LatLngQuad? coordinates) {
    // TODO: implement updateImageSource
    throw UnimplementedError();
  }

  @override
  Future<void> addLayer(String imageLayerId, String imageSourceId,
      double? minzoom, double? maxzoom) {
    // TODO: implement addLayer
    throw UnimplementedError();
  }

  @override
  Future<void> addLayerBelow(String imageLayerId, String imageSourceId,
      String belowLayerId, double? minzoom, double? maxzoom) {
    // TODO: implement addLayerBelow
    throw UnimplementedError();
  }

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) {
    // TODO: implement updateContentInsets
    throw UnimplementedError();
  }

  @override
  Future<void> setFeatureForGeoJsonSource(
      String sourceId, Map<String, dynamic> geojsonFeature) async {
    final source = _map.getSource(sourceId) as GeoJsonSource?;
    final data = _addedFeaturesByLayer[sourceId];

    if (source != null && data != null) {
      final feature = _makeFeature(geojsonFeature);
      final features = data.features.toList();
      final index = features.indexWhere((f) => f.id == feature.id);
      if (index >= 0) {
        features[index] = feature;
        final newData = FeatureCollection(features: features);
        _addedFeaturesByLayer[sourceId] = newData;

        source.setData(newData);
      }
    }
  }

  @override
  void resizeWebMap() {
    _onMapResize();
  }

  @override
  void forceResizeWebMap() {
    _map.resize();
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    _map.setLayoutProperty(layerId, 'visibility', visible ? 'visible' : 'none');
  }

  @override
  Future getFilter(String layerId) async {
    return _map.getFilter(layerId);
  }

  @override
  Future<List> getLayerIds() async {
    final layers = _map.getLayers();
    return layers.map((layer) => layer.id).toList();
  }

  @override
  Future<List> getSourceIds() async {
    final sourceIds = _map.getSourceIds();
    return sourceIds;
  }

  @override
  Future<bool?> getLayerVisibility(String layerId) async {
    final property = _map.getLayoutProperty(layerId, 'visibility');
    if (property == null) return true;
    if (property is String) return property != 'none';
    return true;
  }

  @override
  Future<void> waitUntilMapIsIdleAfterMovement() async {
    final complete = Completer<void>();
    _map.once('idle', (_) => complete.complete());
    return complete.future;
  }

  @override
  Future<void> waitUntilMapTilesAreLoaded() async {
    if (_map.areTilesLoaded()) {
      return;
    }

    final tilesLoadedCompleter = Completer<void>();
    late void Function(dynamic) listener;
    listener = (_) {
      if (_map.areTilesLoaded()) {
        _map.off('sourcedata', listener);
        if (!tilesLoadedCompleter.isCompleted) {
          tilesLoadedCompleter.complete();
        }
      }
    };
    _map.on('sourcedata', listener);

    await tilesLoadedCompleter.future;
  }

  @override
  Future<ui.Size> setWebMapToCustomSize(ui.Size size) async {
    final initialSize = ui.Size(
      _map.getContainer().clientWidth.toDouble(),
      _map.getContainer().clientHeight.toDouble(),
    );

    _map.getContainer().style.width = '${size.width}px';
    _map.getContainer().style.height = '${size.height}px';
    _map.resize();

    await waitUntilMapIsIdleAfterMovement();
    return initialSize;
  }

  @override
  Future<String> takeWebSnapshot() async {
    // "preserveDrawingBuffer" is set to false in the WebGL context to get the best possible performance,
    // therefore we cannot directly use the canvas.toDataURL() method to get a snapshot of the map because it would be blank then.
    // That's the reason why we trigger a repaint and then directly catch the image data from the canvas during the rendering.

    final completer = Completer<String>();
    _map.once('render', (_) {
      final canvas = _map.getCanvas();
      final dataUrl = canvas.toDataUrl('image/png');
      completer.complete(dataUrl);
    });
    _map.triggerRepaint();
    return completer.future;
  }
}
