// Query dispatch of the engine core: every read and its handlers.
//
// A `part` of engine_core.dart: same library, so these members keep access
// to the core's private state. Split for readability only; execution
// semantics are identical.

part of 'engine_core.dart';

extension EngineQueryDispatch on FfiEngineCore {
  /// Executes a read and returns its reply value.
  R handleQuery<R>(EngineQuery<R> query) {
    final result = switch (query) {
      BarrierQuery() => true,
      final CreateSessionQuery q => _createSession(q),
      final GetCameraQuery q => _session(q.sessionId).cameraSnapshot(),
      final GetVisibleRegionQuery q => _visibleRegion(q),
      final PixelForLatLngQuery q => _pixelForLatLng(q),
      final PixelsForLatLngsQuery q => _pixelsForLatLngs(q),
      final LatLngForPixelQuery q => _latLngForPixel(q),
      final GetStyleJsonQuery q => _session(q.sessionId).map.getStyleJson(),
      final GetLayerIdsQuery q => _session(q.sessionId).map.listStyleLayerIds(),
      final GetSourceIdsQuery q => _session(
        q.sessionId,
      ).map.listStyleSourceIds(),
      final GetFilterQuery q => _encodeJsonValue(
        _session(q.sessionId).map.getLayerFilter(q.layerId),
      ),
      final GetLayerPropertyQuery q => _encodeJsonValue(
        _session(q.sessionId).map.getLayerProperty(q.layerId, q.propertyName),
      ),
      final GetLayerVisibilityQuery q => _layerVisibility(q),
      final QueryRenderedFeaturesQuery q => _queryRenderedFeatures(q),
      final QuerySourceFeaturesQuery q => _querySourceFeatures(q),
      final QueryTopFeatureQuery q => _queryTopFeature(q),
      final GetFeatureStateQuery q => _featureState(q),
      final GetAttributionsQuery q => _attributions(q),
      final TakeFrameStatsQuery q => _session(q.sessionId).takeFrameStats(),
    };
    return result as R;
  }

  List<String> _attributions(GetAttributionsQuery query) {
    final map = _session(query.sessionId).map;
    final seen = <String>{};
    for (final sourceId in map.listStyleSourceIds()) {
      final attribution = map.getStyleSourceInfo(sourceId)?.attribution;
      if (attribution != null && attribution.trim().isNotEmpty) {
        seen.add(attribution.trim());
      }
    }
    return seen.toList(growable: false);
  }

  int _createSession(CreateSessionQuery query) {
    final map = mln.MapHandle.create(
      _runtime,
      options: mln.MapOptions(
        width: query.logicalWidth,
        height: query.logicalHeight,
        scaleFactor: query.scaleFactor,
      ),
    );
    final sessionId = _nextSessionId++;
    final session = _EngineSession(
      sessionId: sessionId,
      map: map,
      spec: query,
      emit: _emit,
    );
    session.attachRenderTarget(query.surface);
    _sessions[sessionId] = session;
    return sessionId;
  }

  List<double> _visibleRegion(GetVisibleRegionQuery query) {
    final map = _session(query.sessionId).map;
    final bounds = map.latLngBoundsForCamera(map.camera());
    return <double>[
      bounds.southwest.latitude,
      bounds.southwest.longitude,
      bounds.northeast.latitude,
      bounds.northeast.longitude,
    ];
  }

  List<double> _pixelForLatLng(PixelForLatLngQuery query) {
    final point = _session(query.sessionId).map.pixelForLatLng(
      mln.LatLng(query.latitude, query.longitude),
    );
    return <double>[point.x, point.y];
  }

  Float64List _pixelsForLatLngs(PixelsForLatLngsQuery query) {
    final pairs = query.latLngPairs;
    final points = _session(query.sessionId).map.pixelsForLatLngs([
      for (var i = 0; i + 1 < pairs.length; i += 2)
        mln.LatLng(pairs[i], pairs[i + 1]),
    ]);
    final out = Float64List(points.length * 2);
    for (var i = 0; i < points.length; i++) {
      out[i * 2] = points[i].x;
      out[i * 2 + 1] = points[i].y;
    }
    return out;
  }

  List<double> _latLngForPixel(LatLngForPixelQuery query) {
    final coordinate = _session(query.sessionId).map.latLngForPixel(
      mln.ScreenPoint(query.x, query.y),
    );
    return <double>[coordinate.latitude, coordinate.longitude];
  }

  bool? _layerVisibility(GetLayerVisibilityQuery query) {
    final map = _session(query.sessionId).map;
    if (!map.styleLayerExists(query.layerId)) return null;
    final value = map.getLayerProperty(query.layerId, 'visibility');
    // An unset visibility property means the style-spec default: visible.
    return value == null || jsonValueToDart(value) != 'none';
  }

  List<Map<String, dynamic>> _queryRenderedFeatures(
    QueryRenderedFeaturesQuery query,
  ) {
    final session = _session(query.sessionId);
    final geometry = query.x != null
        ? mln.RenderedQueryPoint(mln.ScreenPoint(query.x!, query.y!))
        : mln.RenderedQueryBox(
            mln.ScreenBox(
              mln.ScreenPoint(query.left!, query.top!),
              mln.ScreenPoint(query.right!, query.bottom!),
            ),
          );
    final layerIds = query.layerIds;
    final filter = query.filter;
    final features = session.requireRenderSession().queryRenderedFeatures(
      geometry,
      options: mln.RenderedFeatureQueryOptions(
        layerIds: layerIds == null || layerIds.isEmpty ? null : layerIds,
        filter: filter == null ? null : jsonValueFromDart(filter),
      ),
    );
    return [for (final queried in features) featureToDart(queried.feature)];
  }

  List<Map<String, dynamic>> _querySourceFeatures(
    QuerySourceFeaturesQuery query,
  ) {
    final session = _session(query.sessionId);
    final sourceLayerId = query.sourceLayerId;
    final filter = query.filter;
    final features = session.requireRenderSession().querySourceFeatures(
      query.sourceId,
      options: mln.SourceFeatureQueryOptions(
        sourceLayerIds: sourceLayerId == null ? null : [sourceLayerId],
        filter: filter == null ? null : jsonValueFromDart(filter),
      ),
    );
    return [for (final queried in features) featureToDart(queried.feature)];
  }

  Map<String, dynamic>? _queryTopFeature(QueryTopFeatureQuery query) {
    final session = _session(query.sessionId);
    final renderSession = session.requireRenderSession();
    final geometry = query.tolerance > 0
        ? mln.RenderedQueryBox(
            mln.ScreenBox(
              mln.ScreenPoint(
                query.x - query.tolerance,
                query.y - query.tolerance,
              ),
              mln.ScreenPoint(
                query.x + query.tolerance,
                query.y + query.tolerance,
              ),
            ),
          )
        : mln.RenderedQueryPoint(mln.ScreenPoint(query.x, query.y));
    for (final layerId in query.layerIds) {
      final features = renderSession.queryRenderedFeatures(
        geometry,
        options: mln.RenderedFeatureQueryOptions(layerIds: [layerId]),
      );
      if (features.isNotEmpty) {
        return <String, dynamic>{
          'layerId': layerId,
          'feature': featureToDart(features.first.feature),
        };
      }
    }
    return null;
  }

  Map<String, dynamic>? _featureState(GetFeatureStateQuery query) {
    final state = _session(query.sessionId)
        .requireRenderSession()
        .getFeatureState(
          mln.FeatureStateSelector(
            sourceId: query.sourceId,
            sourceLayerId: query.sourceLayerId,
            featureId: query.featureId,
          ),
        );
    if (state == null) return null;
    final decoded = jsonValueToDart(state);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  }

  static String? _encodeJsonValue(mln.JsonValue? value) {
    return value == null ? null : jsonEncode(jsonValueToDart(value));
  }
}
