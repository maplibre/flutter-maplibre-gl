part of '../maplibre_gl_platform_interface.dart';

class MapLibreMethodChannel extends MapLibrePlatform {
  late MethodChannel _channel;

  /// Backing field of `MapLibreMap.useHybridComposition`, which is the
  /// documented way to set this and explains what each value selects. Android
  /// only: `false` keeps the map on a `SurfaceView`, `true` moves it to a
  /// `TextureView` via MapLibre's `textureMode`.
  static bool useHybridComposition = false;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'infoWindow#onTap':
        final String? symbolId = call.arguments['symbol'];
        if (symbolId != null) {
          onInfoWindowTappedPlatform(symbolId);
        }
      case 'feature#onTap':
        final id = call.arguments['id'];
        final double x = call.arguments['x'];
        final double y = call.arguments['y'];
        final double lng = call.arguments['lng'];
        final double lat = call.arguments['lat'];
        final String layerId = call.arguments['layerId'];
        onFeatureTappedPlatform({
          'id': id,
          'point': Point<double>(x, y),
          'latLng': LatLng(lat, lng),
          'layerId': layerId,
        });
      case 'feature#onDrag':
        final id = call.arguments['id'];
        final double x = call.arguments['x'];
        final double y = call.arguments['y'];
        final double originLat = call.arguments['originLat'];
        final double originLng = call.arguments['originLng'];

        final double currentLat = call.arguments['currentLat'];
        final double currentLng = call.arguments['currentLng'];

        final double deltaLat = call.arguments['deltaLat'];
        final double deltaLng = call.arguments['deltaLng'];
        final String eventType = call.arguments['eventType'];

        onFeatureDraggedPlatform({
          'id': id,
          'point': Point<double>(x, y),
          'origin': LatLng(originLat, originLng),
          'current': LatLng(currentLat, currentLng),
          'delta': LatLng(deltaLat, deltaLng),
          'eventType': eventType,
        });
      case 'camera#onMoveStarted':
        onCameraMoveStartedPlatform(null);
      case 'camera#onMove':
        final cameraPosition =
            CameraPosition.fromMap(call.arguments['position'])!;
        onCameraMovePlatform(cameraPosition);
      case 'camera#onIdle':
        final cameraPosition = CameraPosition.fromMap(
          call.arguments['position'],
        );
        onCameraIdlePlatform(cameraPosition);
      case 'map#onStyleLoaded':
        onMapStyleLoadedPlatform(null);
      case 'map#onMapClick':
        final double x = call.arguments['x'];
        final double y = call.arguments['y'];
        final double lng = call.arguments['lng'];
        final double lat = call.arguments['lat'];
        onMapClickPlatform({
          'point': Point<double>(x, y),
          'latLng': LatLng(lat, lng),
        });
      case 'map#onMapLongClick':
        final double x = call.arguments['x'];
        final double y = call.arguments['y'];
        final double lng = call.arguments['lng'];
        final double lat = call.arguments['lat'];
        onMapLongClickPlatform({
          'point': Point<double>(x, y),
          'latLng': LatLng(lat, lng),
        });
      case 'map#onCameraTrackingChanged':
        final int mode = call.arguments['mode'];
        onCameraTrackingChangedPlatform(MyLocationTrackingMode.values[mode]);
      case 'map#onCameraTrackingDismissed':
        onCameraTrackingDismissedPlatform(null);
      case 'map#onIdle':
        onMapIdlePlatform(null);
      case 'map#onUserLocationUpdated':
        final dynamic userLocation = call.arguments['userLocation'];
        final dynamic heading = call.arguments['heading'];
        onUserLocationUpdatedPlatform(
          UserLocation(
            position: LatLng(
              userLocation['position'][0],
              userLocation['position'][1],
            ),
            altitude: userLocation['altitude'],
            bearing: userLocation['bearing'],
            speed: userLocation['speed'],
            horizontalAccuracy: userLocation['horizontalAccuracy'],
            verticalAccuracy: userLocation['verticalAccuracy'],
            heading:
                heading == null
                    ? null
                    : UserHeading(
                      magneticHeading: heading['magneticHeading'],
                      trueHeading: heading['trueHeading'],
                      headingAccuracy: heading['headingAccuracy'],
                      x: heading['x'],
                      y: heading['y'],
                      z: heading['z'],
                      timestamp: DateTime.fromMillisecondsSinceEpoch(
                        heading['timestamp'],
                      ),
                    ),
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              userLocation['timestamp'],
            ),
          ),
        );
      default:
        throw MissingPluginException();
    }
  }

  @override
  Future<void> initPlatform(int id) async {
    _channel = MethodChannel('plugins.flutter.io/maplibre_gl_$id');
    _channel.setMethodCallHandler(_handleMethodCall);
    await _channel.invokeMethod('map#waitForMap');
  }

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      creationParams['options']?['useHybridComposition'] = useHybridComposition;
      if (useHybridComposition) {
        return PlatformViewLink(
          viewType: 'plugins.flutter.io/maplibre_gl',
          surfaceFactory: (
            context,
            controller,
          ) {
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
            controller.addOnPlatformViewCreatedListener(
              onPlatformViewCreated,
            );

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

  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> optionsUpdate,
  ) async {
    final dynamic json = await _channel.invokeMethod(
      'map#update',
      <String, dynamic>{
        'options': optionsUpdate,
      },
    );
    return CameraPosition.fromMap(json);
  }

  @override
  Future<bool?> animateCamera(cameraUpdate, {Duration? duration}) async {
    return _channel.invokeMethod('camera#animate', <String, dynamic>{
      'cameraUpdate': cameraUpdate.toJson(),
      'duration': duration?.inMilliseconds,
    });
  }

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    return _channel.invokeMethod('camera#move', <String, dynamic>{
      'cameraUpdate': cameraUpdate.toJson(),
    });
  }

  @override
  Future<void> updateMyLocationTrackingMode(
    MyLocationTrackingMode myLocationTrackingMode,
  ) async {
    await _channel.invokeMethod(
      'map#updateMyLocationTrackingMode',
      <String, dynamic>{
        'mode': myLocationTrackingMode.index,
      },
    );
  }

  @override
  Future<void> setManualLocation(ManualLocationUpdate update) async {
    await _channel.invokeMethod(
      'locationComponent#setManualLocation',
      update.toMap(),
    );
  }

  @override
  Future<void> matchMapLanguageWithDeviceDefault() async {
    await _channel.invokeMethod('map#matchMapLanguageWithDeviceDefault');
  }

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) async {
    await _channel.invokeMethod('map#updateContentInsets', <String, dynamic>{
      'bounds': <String, double>{
        'top': insets.top,
        'left': insets.left,
        'bottom': insets.bottom,
        'right': insets.right,
      },
      'animated': animated,
    });
  }

  @override
  Future<void> setMapLanguage(String language) async {
    await _channel.invokeMethod('map#setMapLanguage', <String, dynamic>{
      'language': language,
    });
  }

  @override
  Future<void> setTelemetryEnabled(bool enabled) async {
    await _channel.invokeMethod('map#setTelemetryEnabled', <String, dynamic>{
      'enabled': enabled,
    });
  }

  @override
  Future<bool> getTelemetryEnabled() async {
    return await _channel.invokeMethod('map#getTelemetryEnabled');
  }

  @override
  Future<void> setMaximumFps(int fps) async {
    await _channel.invokeMethod('map#setMaximumFps', <String, dynamic>{
      'fps': fps,
    });
  }

  @override
  Future<void> forceOnlineMode() async {
    await _channel.invokeMethod('map#forceOnlineMode');
  }

  @override
  Future<void> pauseMap() async {
    await _channel.invokeMethod('map#pause');
  }

  @override
  Future<void> resumeMap() async {
    await _channel.invokeMethod('map#resume');
  }

  @override
  Future<bool> easeCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
    CameraAnimationInterpolation? interpolation,
  }) async {
    final result = await _channel.invokeMethod('camera#ease', <String, dynamic>{
      'cameraUpdate': cameraUpdate.toJson(),
      'duration': duration?.inMilliseconds,
      if (interpolation != null)
        'interpolation': interpolation.toString().split('.').last,
    });
    return result as bool;
  }

  @override
  Future<CameraPosition?> queryCameraPosition() async {
    final dynamic json = await _channel.invokeMethod('map#queryCameraPosition');
    return CameraPosition.fromMap(json);
  }

  @override
  Future<bool> editGeoJsonSource(String id, String data) async {
    final Map<Object?, Object?> reply = await _channel.invokeMethod(
      'map#editGeoJsonSource',
      <String, dynamic>{
        'id': id,
        'data': data,
      },
    );
    final result = reply['result'];
    return result == true;
  }

  @override
  Future<bool> editGeoJsonUrl(String id, String url) async {
    final Map<Object?, Object?> reply = await _channel.invokeMethod(
      'map#editGeoJsonUrl',
      <String, String>{
        'id': id,
        'url': url,
      },
    );
    final result = reply['result'];
    return result == true;
  }

  @override
  Future<bool> setLayerFilter(String layerId, String filter) async {
    final Map<Object?, Object?> reply = await _channel.invokeMethod(
      'map#setLayerFilter',
      <String, dynamic>{
        'id': layerId,
        'filter': filter,
      },
    );
    final result = reply['result'];
    return result == true;
  }

  @override
  Future<String?> getStyle() async {
    final Map<Object?, Object?> reply = await _channel.invokeMethod(
      'map#getStyle',
    );
    final result = reply['result'] as bool?;
    if (result ?? false) {
      final json = reply['json'] as String?;
      return json;
    }
    return null;
  }

  @override
  Future<void> setCustomHeaders(
    Map<String, String> headers,
    List<String> filter,
  ) async {
    try {
      await _channel.invokeMethod('map#setCustomHeaders', <String, dynamic>{
        'headers': headers,
        'filter': filter,
      });
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<Map<String, String>> getCustomHeaders() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'map#getCustomHeaders',
        <String, dynamic>{},
      );
      return result?.map(
            (key, value) =>
                MapEntry<String, String>(key.toString(), value.toString()),
          ) ??
          <String, String>{};
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<List> queryRenderedFeatures(
    Point<double> point,
    List<String> layerIds,
    List<Object>? filter,
  ) async {
    try {
      final Map<dynamic, dynamic> reply = await _channel.invokeMethod(
        'map#queryRenderedFeatures',
        <String, Object?>{
          'x': point.x,
          'y': point.y,
          'layerIds': layerIds,
          'filter': filter,
        },
      );
      return reply['features'].map((feature) => jsonDecode(feature)).toList();
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<List> queryRenderedFeaturesInRect(
    Rect rect,
    List<String> layerIds,
    String? filter,
  ) async {
    try {
      final Map<dynamic, dynamic> reply = await _channel.invokeMethod(
        'map#queryRenderedFeatures',
        <String, Object?>{
          'left': rect.left,
          'top': rect.top,
          'right': rect.right,
          'bottom': rect.bottom,
          'layerIds': layerIds,
          'filter': filter,
        },
      );
      return reply['features'].map((feature) => jsonDecode(feature)).toList();
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<List> querySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object>? filter,
  ) async {
    try {
      final Map<dynamic, dynamic> reply = await _channel.invokeMethod(
        'map#querySourceFeatures',
        <String, Object?>{
          'sourceId': sourceId,
          'sourceLayerId': sourceLayerId,
          'filter': filter,
        },
      );
      return reply['features'].map((feature) => jsonDecode(feature)).toList();
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future invalidateAmbientCache() async {
    try {
      await _channel.invokeMethod('map#invalidateAmbientCache');
      return null;
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future clearAmbientCache() async {
    try {
      await _channel.invokeMethod('map#clearAmbientCache');
      return null;
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<LatLng?> requestMyLocationLatLng() async {
    try {
      final reply = await _channel.invokeMethod(
        'locationComponent#getLastLocation',
      );
      if (reply == null) {
        return null;
      }
      final Map<dynamic, dynamic> data = reply;
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
      return null;
    }
  }

  @override
  Future<LatLngBounds> getVisibleRegion() async {
    try {
      final Map<dynamic, dynamic> reply = await _channel.invokeMethod(
        'map#getVisibleRegion',
      );
      final southwest = reply['sw'] as List<dynamic>;
      final northeast = reply['ne'] as List<dynamic>;
      return LatLngBounds(
        southwest: LatLng(southwest[0], southwest[1]),
        northeast: LatLng(northeast[0], northeast[1]),
      );
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool sdf = false,
  ]) async {
    try {
      return await _channel.invokeMethod('style#addImage', <String, Object>{
        'name': name,
        'bytes': bytes,
        'length': bytes.length,
        'sdf': sdf,
      });
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<void> addImageSource(
    String imageSourceId,
    Uint8List bytes,
    LatLngQuad coordinates,
  ) async {
    try {
      return await _channel.invokeMethod(
        'style#addImageSource',
        <String, Object>{
          'imageSourceId': imageSourceId,
          'bytes': bytes,
          'length': bytes.length,
          'coordinates': coordinates.toList(),
        },
      );
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<void> updateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    LatLngQuad? coordinates,
  ) async {
    try {
      return await _channel.invokeMethod(
        'style#updateImageSource',
        <String, Object?>{
          'imageSourceId': imageSourceId,
          'bytes': bytes,
          'length': bytes?.length,
          'coordinates': coordinates?.toList(),
        },
      );
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<Point> toScreenLocation(LatLng latLng) async {
    try {
      final screenPosMap = await _channel.invokeMethod(
        'map#toScreenLocation',
        <String, dynamic>{
          'latitude': latLng.latitude,
          'longitude': latLng.longitude,
        },
      );
      return Point(screenPosMap['x'], screenPosMap['y']);
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<List<Point>> toScreenLocationBatch(Iterable<LatLng> latLngs) async {
    try {
      final coordinates = Float64List.fromList(
        latLngs.map((e) => [e.latitude, e.longitude]).expand((e) => e).toList(),
      );
      final Float64List result = await _channel.invokeMethod(
        'map#toScreenLocationBatch',
        {"coordinates": coordinates},
      );

      final points = <Point>[];
      for (var i = 0; i < result.length; i += 2) {
        points.add(Point(result[i], result[i + 1]));
      }

      return points;
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<void> removeSource(String sourceId) async {
    try {
      return await _channel.invokeMethod(
        'style#removeSource',
        <String, Object>{'sourceId': sourceId},
      );
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<void> addLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  ) async {
    try {
      return await _channel.invokeMethod('style#addLayer', <String, dynamic>{
        'imageLayerId': imageLayerId,
        'imageSourceId': imageSourceId,
        'minzoom': minzoom,
        'maxzoom': maxzoom,
      });
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<void> addLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  ) async {
    try {
      return await _channel.invokeMethod(
        'style#addLayerBelow',
        <String, dynamic>{
          'imageLayerId': imageLayerId,
          'imageSourceId': imageSourceId,
          'belowLayerId': belowLayerId,
          'minzoom': minzoom,
          'maxzoom': maxzoom,
        },
      );
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<void> removeLayer(String imageLayerId) async {
    try {
      return await _channel.invokeMethod('style#removeLayer', <String, Object>{
        'layerId': imageLayerId,
      });
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {
    try {
      return await _channel.invokeMethod('style#setFilter', <String, Object>{
        'layerId': layerId,
        'filter': jsonEncode(filter),
      });
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<dynamic> getFilter(String layerId) async {
    try {
      final Map<dynamic, dynamic> reply = await _channel.invokeMethod(
        'style#getFilter',
        <String, dynamic>{
          'layerId': layerId,
        },
      );
      final filter = reply["filter"];
      return filter != null ? jsonDecode(filter) : null;
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<LatLng> toLatLng(Point screenLocation) async {
    try {
      final latLngMap = await _channel.invokeMethod(
        'map#toLatLng',
        <String, dynamic>{
          'x': screenLocation.x,
          'y': screenLocation.y,
        },
      );
      return LatLng(latLngMap['latitude'], latLngMap['longitude']);
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) async {
    try {
      final latLngMap = await _channel.invokeMethod(
        'map#getMetersPerPixelAtLatitude',
        <String, dynamic>{
          'latitude': latitude,
        },
      );
      return latLngMap['metersperpixel'];
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) {
    return _writeGeoJson(sourceId, () async {
      await _channel.invokeMethod('source#addGeoJson', <String, dynamic>{
        'sourceId': sourceId,
        'geojson': await _encodeGeoJson(geojson),
      });
    });
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) {
    return _writeGeoJson(sourceId, () async {
      await _channel.invokeMethod('source#setGeoJson', <String, dynamic>{
        'sourceId': sourceId,
        'geojson': await _encodeGeoJson(geojson),
      });
    });
  }

  /// Thresholds above which GeoJSON encoding moves to a background isolate:
  /// the number of features in a collection, and the number of coordinate
  /// positions anywhere in the payload.
  ///
  /// Native only accepts a JSON string, so the encode happens either way, and
  /// `jsonEncode` on the main isolate froze the UI on large geometries (#366).
  /// Above these thresholds the encode goes through [compute]; below them it
  /// stays synchronous, since spawning an isolate would make the common case
  /// slower and asynchronous for nothing.
  ///
  /// This buys a responsive UI, not speed: handing the payload over copies it on
  /// the calling side. Measured on a desktop machine, a 100k-point line blocks
  /// the main isolate for about 46 ms inline against about 30 ms offloaded,
  /// while total duration grows from about 45 ms to about 72 ms. Dropping that
  /// last 30 ms needs an API taking already encoded GeoJSON, since that copy is
  /// the cost. A long-lived worker isolate was measured and rejected: the spawn
  /// is only about 0.1 ms, and a shared worker queues a small write behind a
  /// large one (58 ms) instead of letting it take the synchronous path.
  ///
  /// Web never gets here: it hands the decoded map straight to maplibre-gl-js.
  static const _geoJsonOffloadFeatureCount = 100;
  static const _geoJsonOffloadPositionCount = 2000;

  /// Pending GeoJSON write per source id. See [_writeGeoJson].
  final Map<String, Future<void>> _pendingGeoJsonWrites = {};

  /// Runs [write] after any GeoJSON write already in flight for [sourceId].
  ///
  /// Encoding can now finish asynchronously, and it takes longer the larger the
  /// payload is. Two writes fired without `await` on the same source would
  /// otherwise be able to reach the platform channel in reverse order, leaving
  /// the source holding the older payload. Chaining per source id keeps the
  /// platform side in call order.
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

  /// Encodes [geojson] to a JSON string, offloading to a background isolate
  /// when the payload is large enough to be worth it. See [isLargeGeoJson].
  Future<String> _encodeGeoJson(Map<String, dynamic> geojson) {
    if (isLargeGeoJson(geojson)) {
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
  @visibleForTesting
  static bool isLargeGeoJson(Map<String, dynamic> geojson) {
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
  Future setCameraBounds({
    required double west,
    required double north,
    required double south,
    required double east,
    required int padding,
  }) async {
    try {
      await _channel.invokeMethod('map#setCameraBounds', <String, dynamic>{
        'west': west,
        'north': north,
        'south': south,
        'east': east,
        'padding': padding,
      });
    } on PlatformException catch (e) {
      return Future.error(e);
    }
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
    await _channel.invokeMethod('symbolLayer#add', <String, dynamic>{
      'sourceId': sourceId,
      'layerId': layerId,
      'belowLayerId': belowLayerId,
      'sourceLayer': sourceLayer,
      'minzoom': minzoom,
      'maxzoom': maxzoom,
      'filter': jsonEncode(filter),
      'enableInteraction': enableInteraction,
      'properties': properties,
    });
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
    await _channel.invokeMethod('lineLayer#add', <String, dynamic>{
      'sourceId': sourceId,
      'layerId': layerId,
      'belowLayerId': belowLayerId,
      'sourceLayer': sourceLayer,
      'minzoom': minzoom,
      'maxzoom': maxzoom,
      'filter': jsonEncode(filter),
      'enableInteraction': enableInteraction,
      'properties': properties,
    });
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  ) async {
    await _channel.invokeMethod('layer#setProperties', <String, dynamic>{
      'layerId': layerId,
      'properties': properties,
    });
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
    await _channel.invokeMethod('circleLayer#add', <String, dynamic>{
      'sourceId': sourceId,
      'layerId': layerId,
      'belowLayerId': belowLayerId,
      'sourceLayer': sourceLayer,
      'minzoom': minzoom,
      'maxzoom': maxzoom,
      'filter': jsonEncode(filter),
      'enableInteraction': enableInteraction,
      'properties': properties,
    });
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
    await _channel.invokeMethod('fillLayer#add', <String, dynamic>{
      'sourceId': sourceId,
      'layerId': layerId,
      'belowLayerId': belowLayerId,
      'sourceLayer': sourceLayer,
      'minzoom': minzoom,
      'maxzoom': maxzoom,
      'filter': jsonEncode(filter),
      'enableInteraction': enableInteraction,
      'properties': properties,
    });
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
    await _channel.invokeMethod('fillExtrusionLayer#add', <String, dynamic>{
      'sourceId': sourceId,
      'layerId': layerId,
      'belowLayerId': belowLayerId,
      'sourceLayer': sourceLayer,
      'minzoom': minzoom,
      'maxzoom': maxzoom,
      'filter': jsonEncode(filter),
      'enableInteraction': enableInteraction,
      'properties': properties,
    });
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    await _channel.invokeMethod('style#addSource', <String, dynamic>{
      'sourceId': sourceId,
      'properties': properties.toJson(),
    });
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
    await _channel.invokeMethod('rasterLayer#add', <String, dynamic>{
      'sourceId': sourceId,
      'layerId': layerId,
      'belowLayerId': belowLayerId,
      'minzoom': minzoom,
      'maxzoom': maxzoom,
      'properties': properties,
    });
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
    await _channel.invokeMethod('hillshadeLayer#add', <String, dynamic>{
      'sourceId': sourceId,
      'layerId': layerId,
      'belowLayerId': belowLayerId,
      'minzoom': minzoom,
      'maxzoom': maxzoom,
      'properties': properties,
    });
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
  }) async {
    await _channel.invokeMethod('heatmapLayer#add', <String, dynamic>{
      'sourceId': sourceId,
      'layerId': layerId,
      'belowLayerId': belowLayerId,
      'minzoom': minzoom,
      'maxzoom': maxzoom,
      'properties': properties,
    });
  }

  @override
  Future<void> setFeatureForGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojsonFeature,
  ) {
    return _writeGeoJson(sourceId, () async {
      await _channel.invokeMethod('source#setFeature', <String, dynamic>{
        'sourceId': sourceId,
        'geojsonFeature': await _encodeGeoJson(geojsonFeature),
      });
    });
  }

  /// Guard shared by the feature state methods. This class serves both
  /// Android and iOS, but only the MapLibre Android SDK exposes the feature
  /// state API, so on iOS the call has no native counterpart to reach.
  /// Failing here keeps the error clear instead of surfacing as a
  /// [MissingPluginException] from an unhandled channel call.
  void _ensureFeatureStateAvailable(String methodName) {
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
    await _channel.invokeMethod('source#setFeatureState', <String, dynamic>{
      'sourceId': sourceId,
      'featureId': featureId,
      'state': state,
      'sourceLayer': sourceLayer,
    });
  }

  @override
  Future<void> removeFeatureState(
    String sourceId, {
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  }) async {
    _ensureFeatureStateAvailable('removeFeatureState');
    await _channel.invokeMethod('source#removeFeatureState', <String, dynamic>{
      'sourceId': sourceId,
      'featureId': featureId,
      'stateKey': stateKey,
      'sourceLayer': sourceLayer,
    });
  }

  @override
  Future<Map<String, dynamic>?> getFeatureState(
    String sourceId,
    String featureId, {
    String? sourceLayer,
  }) async {
    _ensureFeatureStateAvailable('getFeatureState');
    final reply = await _channel.invokeMethod(
      'source#getFeatureState',
      <String, dynamic>{
        'sourceId': sourceId,
        'featureId': featureId,
        'sourceLayer': sourceLayer,
      },
    );
    // The native side sends the state as a JSON string (so nested values
    // survive the channel intact) and sends null, not an empty map, when the
    // feature has no state, because callers distinguish the two.
    final state = reply?['state'];
    if (state == null) return null;
    return (jsonDecode(state as String) as Map).cast<String, dynamic>();
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    await _channel.invokeMethod('layer#setVisibility', <String, dynamic>{
      'layerId': layerId,
      'visible': visible,
    });
  }

  @override
  Future<bool?> getLayerVisibility(String layerId) async {
    try {
      final result = await _channel.invokeMethod(
        'layer#getVisibility',
        <String, dynamic>{
          'layerId': layerId,
        },
      );
      return result as bool?;
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<Size> setWebMapToCustomSize(Size size) async {
    // Not supported on native platforms, return the requested size
    return size;
  }

  @override
  Future<void> waitUntilMapIsIdleAfterMovement() async {
    // On native platforms, this is a no-op as camera animations complete synchronously
  }

  @override
  Future<void> waitUntilMapTilesAreLoaded() async {
    // On native platforms, this is a no-op
  }

  @override
  Future<Uint8List> takeSnapshot({int? width, int? height}) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'map#takeSnapshot',
        <String, dynamic>{
          if (width != null) 'width': width,
          if (height != null) 'height': height,
        },
      );
      if (result == null) {
        throw Exception('Failed to take map snapshot');
      }
      return result;
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  void forceResizeWebMap() {}

  @override
  void resizeWebMap() {}

  @override
  Future<List> getLayerIds() async {
    try {
      final Map<dynamic, dynamic> reply = await _channel.invokeMethod(
        'style#getLayerIds',
      );
      return reply['layers'].map((it) => it.toString()).toList();
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<List> getSourceIds() async {
    try {
      final Map<dynamic, dynamic> reply = await _channel.invokeMethod(
        'style#getSourceIds',
      );
      return reply['sources'].map((it) => it.toString()).toList();
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<Map<String, dynamic>?> getLayerProperties(String layerId) async {
    return _getStyleObjectProperties('style#getLayerProperties', {
      'layerId': layerId,
    });
  }

  @override
  Future<Map<String, dynamic>?> getSourceProperties(String sourceId) async {
    return _getStyleObjectProperties('style#getSourceProperties', {
      'sourceId': sourceId,
    });
  }

  /// Shared transport for [getLayerProperties] / [getSourceProperties].
  ///
  /// The native side serializes the layer/source to a MapLibre style-spec JSON
  /// string (so nested expressions survive the platform channel intact) and
  /// returns it under `reply['properties']`. Returns null when the object does
  /// not exist.
  Future<Map<String, dynamic>?> _getStyleObjectProperties(
    String method,
    Map<String, dynamic> arguments,
  ) async {
    try {
      final reply = await _channel.invokeMethod(method, arguments);
      final properties = reply?['properties'];
      if (properties == null) return null;
      return (jsonDecode(properties as String) as Map).cast<String, dynamic>();
    } on PlatformException catch (e) {
      return Future.error(e);
    }
  }

  /// Method to set style string
  ///
  @override
  Future<void> setStyle(String styleString) async {
    try {
      await _channel.invokeMethod(
        'style#setStyle',
        <String, dynamic>{
          'style': styleString,
        },
      );
    } on PlatformException catch (e) {
      return Future.error(e);
    } catch (e) {
      return Future.error(e);
    }
  }
}
