// Command dispatch of the engine core: every fire-and-forget mutation.
//
// A `part` of engine_core.dart: same library, so these members keep access
// to the core's private state. Split for readability only; execution
// semantics are identical.

part of 'engine_core.dart';

extension EngineCommandDispatch on EngineCore {
  /// Executes a fire-and-forget mutation.
  void handleCommand(EngineCommand command) {
    switch (command) {
      case SetHttpHeadersCommand():
        // The provider is not installed by default (native HTTP serves
        // everything); headers are the one feature that still needs the Dart
        // fetch path, so install it on first use. Clearing headers does not
        // uninstall: requests keep flowing through Dart with no extras added.
        if (command.headers.isNotEmpty) {
          HttpResourceProvider.install(_runtime);
        }
        HttpResourceProvider.setHeaders(
          command.headers,
          urlFilters: command.urlFilters,
        );
      case SetNetworkStatusCommand():
        mln.Maplibre.setNetworkStatus(
          command.online ? mln.NetworkStatus.online : mln.NetworkStatus.offline,
        );
      case RunAmbientCacheOperationCommand():
        // Fire-and-forget: completion is reported via a runtime event and
        // ambient cache operations carry no result payload.
        _runtime.runAmbientCacheOperation(switch (command.operation) {
          AmbientCacheOperationKind.resetDatabase =>
            mln.AmbientCacheOperation.resetDatabase,
          AmbientCacheOperationKind.packDatabase =>
            mln.AmbientCacheOperation.packDatabase,
          AmbientCacheOperationKind.invalidate =>
            mln.AmbientCacheOperation.invalidate,
          AmbientCacheOperationKind.clear => mln.AmbientCacheOperation.clear,
        }).discard();
      case SetMaximumFpsCommand():
        maxFps = command.fps <= 0 ? null : command.fps;
      case CreateOfflineRegionCommand():
        _startOfflineOp(
          command.requestId,
          () => _runtime.createOfflineRegion(
            mln.OfflineTilePyramidRegionDefinition(
              styleUrl: command.styleUrl,
              bounds: _latLngBounds(command.bounds),
              minZoom: command.minZoom,
              maxZoom: command.maxZoom,
              pixelRatio: command.pixelRatio,
              includeIdeographs: command.includeIdeographs,
            ),
            metadata: command.metadata,
          ),
          (handle) => OfflineResultEvent(
            command.requestId,
            regions: [_regionToMap(handle.takeCreatedRegion())],
          ),
        );
      case ListOfflineRegionsCommand():
        _startOfflineOp(
          command.requestId,
          _runtime.listOfflineRegions,
          (handle) => OfflineResultEvent(
            command.requestId,
            regions: [
              for (final region in handle.takeRegionList())
                _regionToMap(region),
            ],
          ),
        );
      case MergeOfflineRegionsCommand():
        _startOfflineOp(
          command.requestId,
          () => _runtime.mergeOfflineRegionDatabase(command.path),
          (handle) => OfflineResultEvent(
            command.requestId,
            regions: [
              for (final region in handle.takeMergedRegionList())
                _regionToMap(region),
            ],
          ),
        );
      case UpdateOfflineRegionMetadataCommand():
        _startOfflineOp(
          command.requestId,
          () => _runtime.updateOfflineRegionMetadata(
            command.regionId,
            command.metadata,
          ),
          (handle) => OfflineResultEvent(
            command.requestId,
            regions: [_regionToMap(handle.takeUpdatedRegionMetadata())],
          ),
        );
      case GetOfflineRegionStatusCommand():
        _startOfflineOp(
          command.requestId,
          () => _runtime.getOfflineRegionStatus(command.regionId),
          (handle) => OfflineResultEvent(
            command.requestId,
            status: _statusToMap(handle.takeRegionStatus()),
          ),
        );
      case DeleteOfflineRegionCommand():
        _startOfflineOp(
          command.requestId,
          () => _runtime.deleteOfflineRegion(command.regionId),
          (_) => OfflineResultEvent(command.requestId),
        );
      case SetOfflineRegionDownloadStateCommand():
        // Fire-and-forget: register the two handles for cleanup only.
        _startOfflineOp(
          null,
          () => _runtime.setOfflineRegionObserved(
            command.regionId,
            command.observed,
          ),
          null,
        );
        _startOfflineOp(
          null,
          () => _runtime.setOfflineRegionDownloadState(
            command.regionId,
            command.active
                ? mln.OfflineRegionDownloadState.active
                : mln.OfflineRegionDownloadState.inactive,
          ),
          null,
        );
      case SurfaceLostCommand():
        _session(command.sessionId).onSurfaceLost();
      case AttachSurfaceCommand():
        _session(command.sessionId).attachRenderTarget(command.eglSurface);
      case ResizeSessionCommand():
        _session(command.sessionId).resize(
          newLogicalWidth: command.logicalWidth,
          newLogicalHeight: command.logicalHeight,
          newScaleFactor: command.scaleFactor,
          eglSurface: command.eglSurface,
        );
      case DisposeSessionCommand():
        final session = _sessions.remove(command.sessionId);
        session?.close();
      case RequestRenderCommand():
        _session(command.sessionId).requestRender();
      case JumpToCommand():
        final session = _session(command.sessionId);
        session.map.jumpTo(
          _cameraOptions(command.camera, command.anchorX, command.anchorY),
        );
        session.requestRender();
      case EaseToCommand():
        final session = _session(command.sessionId);
        final easing = command.easing;
        session.map.easeTo(
          _cameraOptions(command.camera, null, null),
          animation: mln.AnimationOptions(
            durationMs: command.durationMs,
            easing: easing == null
                ? null
                : mln.UnitBezier(easing[0], easing[1], easing[2], easing[3]),
          ),
        );
        session.requestRender();
      case MoveByCommand():
        final session = _session(command.sessionId);
        session.map.moveBy(
          command.dx,
          command.dy,
          animation: _animation(command.durationMs, null),
        );
        session.requestRender();
      case ScaleByCommand():
        final session = _session(command.sessionId);
        session.map.scaleBy(
          command.factor,
          anchor: command.anchorX == null || command.anchorY == null
              ? null
              : mln.ScreenPoint(command.anchorX!, command.anchorY!),
          animation: _animation(command.durationMs, null),
        );
        session.requestRender();
      case RotateByCommand():
        final session = _session(command.sessionId);
        final bearing = session.map.camera().bearing ?? 0;
        session.map.jumpTo(
          mln.CameraOptions(
            bearing: bearing + command.deltaDegrees,
            anchor: mln.ScreenPoint(command.anchorX, command.anchorY),
          ),
        );
        session.requestRender();
      case PitchByCommand():
        final session = _session(command.sessionId);
        final pitch = session.map.camera().pitch ?? 0;
        session.map.jumpTo(
          mln.CameraOptions(
            pitch: (pitch + command.deltaDegrees).clamp(
              command.minPitch,
              command.maxPitch,
            ),
          ),
        );
        session.requestRender();
      case FitBoundsCommand():
        final session = _session(command.sessionId);
        final camera = session.map.cameraForLatLngBounds(
          _latLngBounds(command.bounds),
          fitOptions: mln.CameraFitOptions(
            padding: mln.EdgeInsets(
              left: command.paddingLeft,
              top: command.paddingTop,
              right: command.paddingRight,
              bottom: command.paddingBottom,
            ),
          ),
        );
        final animation = _animation(command.durationMs, command.easing);
        animation == null
            ? session.map.jumpTo(camera)
            : session.map.easeTo(camera, animation: animation);
        session.requestRender();
      case CancelTransitionsCommand():
        _session(command.sessionId).map.cancelTransitions();
      case SetGestureInProgressCommand():
        _session(
          command.sessionId,
        ).map.setGestureInProgress(command.inProgress);
      case SetBoundsCommand():
        final session = _session(command.sessionId);
        final bounds = command.bounds;
        // Native setBounds applies only the options that are set, so a
        // command that carries just a zoom range preserves the target bounds
        // set by an earlier one.
        session.map.setBounds(
          mln.BoundOptions(
            bounds: switch (bounds) {
              null => null,
              BoundsConstraintSpec(bounds: final box?) =>
                mln.BoundsConstraint.bounded(_latLngBounds(box)),
              BoundsConstraintSpec() => const mln.BoundsConstraint.unbounded(),
            },
            minZoom: command.minZoom,
            maxZoom: command.maxZoom,
            minPitch: command.minPitch,
            maxPitch: command.maxPitch,
          ),
        );
        session.requestRender();
      case SetPaddingCommand():
        final session = _session(command.sessionId);
        final camera = mln.CameraOptions(
          padding: mln.EdgeInsets(
            left: command.left,
            top: command.top,
            right: command.right,
            bottom: command.bottom,
          ),
        );
        final animation = _animation(command.durationMs, null);
        animation == null
            ? session.map.jumpTo(camera)
            : session.map.easeTo(camera, animation: animation);
        session.requestRender();
      case SetStyleCommand():
        final session = _session(command.sessionId);
        final trimmed = command.styleString.trim();
        // Timed because this call can carry the style parse inline, which is
        // the single longest thing a command can do on this isolate; knowing
        // its real size is what the isolate-vs-root decision rests on.
        final styleClock = Stopwatch()..start();
        trimmed.startsWith('{')
            ? session.map.setStyleJson(trimmed)
            : session.map.setStyleUrl(trimmed);
        final styleMs = styleClock.elapsedMilliseconds;
        if (styleMs >= 8) {
          debugPrint(
            '[maplibre_gl_native] setStyle call took $styleMs ms '
            '(inline work on the engine isolate)',
          );
        }
        // A style load drops every source added on top of the old style.
        session.geojsonCache.clear();
        session.requestRender();
      case AddSourceJsonCommand():
        final session = _session(command.sessionId);
        session.map.addStyleSourceJson(
          command.sourceId,
          jsonValueFromDart(command.source),
        );
        // Keep a decoded copy of inline GeoJSON data so single-feature
        // updates (SetGeoJsonFeatureCommand) can merge engine-side.
        final data = command.source['data'];
        if (command.source['type'] == 'geojson' && data is Map) {
          session.geojsonCache[command.sourceId] = data.cast<String, dynamic>();
        }
        session.requestRender();
      case SetGeoJsonSourceDataCommand():
        final session = _session(command.sessionId);
        try {
          session.map.setGeoJsonSourceData(
            command.sourceId,
            geoJsonFromDart(command.data),
          );
        } on Object {
          // The generic command-failure log has no payload details; name the
          // source so a failure is attributable (e.g. annotation-manager
          // sources updated after a style reload dropped them).
          debugPrint(
            '[maplibre_gl_native] setGeoJsonSourceData failed for source '
            '"${command.sourceId}"',
          );
          rethrow;
        }
        session.geojsonCache[command.sourceId] = command.data;
        session.requestRender();
      case SetGeoJsonSourceUrlCommand():
        final session = _session(command.sessionId);
        session.map.setGeoJsonSourceUrl(command.sourceId, command.url);
        session.geojsonCache.remove(command.sourceId);
        session.requestRender();
      case SetPlacementTransitionsCommand():
        // Replaces the whole style-wide transition override; duration and
        // delay stay absent so the style's own values keep applying.
        _session(command.sessionId).map.setStyleTransitionOptions(
          mln.StyleTransitionOptions(
            enablePlacementTransitions: command.enabled,
          ),
        );
      case SetGeoJsonFeatureCommand():
        final session = _session(command.sessionId);
        final document = session.geojsonCache[command.sourceId];
        if (document == null) {
          debugPrint(
            '[maplibre_gl_native] setGeoJsonFeature: no cached data for '
            'source "${command.sourceId}", ignoring',
          );
          return;
        }
        _mergeFeature(document, command.feature);
        session.map.setGeoJsonSourceData(
          command.sourceId,
          geoJsonFromDart(document),
        );
        session.requestRender();
      case SetLayerPropertiesCommand():
        final session = _session(command.sessionId);
        for (final entry in command.properties.entries) {
          session.map.setLayerProperty(
            command.layerId,
            entry.key,
            jsonValueFromDart(entry.value),
          );
        }
        session.requestRender();
      case SetFilterCommand():
        final session = _session(command.sessionId);
        final filter = command.filter;
        session.map.setLayerFilter(
          command.layerId,
          filter == null ? null : jsonValueFromDart(filter),
        );
        session.requestRender();
      case SetMapLanguageCommand():
        final session = _session(command.sessionId);
        final map = session.map;
        for (final layerId in map.listStyleLayerIds()) {
          final value = map.getLayerProperty(layerId, 'text-field');
          if (value == null) continue;
          // Adapt only text fields that reference the "name" data property
          // (OSM-style localized names), like the reference backends.
          final encoded = jsonEncode(jsonValueToDart(value));
          if (!encoded.contains('"name')) continue;
          map.setLayerProperty(
            layerId,
            'text-field',
            jsonValueFromDart([
              'coalesce',
              ['get', 'name:${command.language}'],
              ['get', 'name'],
            ]),
          );
        }
        session.requestRender();
      case TakeSnapshotCommand():
        final session = _session(command.sessionId);
        try {
          _snapshots.add(
            session.createSnapshotJob(
              _runtime,
              command.requestId,
              width: command.width,
              height: command.height,
            ),
          );
        } catch (error) {
          _emit(
            SnapshotResultEvent(
              command.sessionId,
              command.requestId,
              error: '$error',
            ),
          );
        }
      case ShowLocationIndicatorCommand():
        final session = _session(command.sessionId);
        final map = session.map;
        if (!map.styleLayerExists(_locationIndicatorLayerId)) {
          map.addLocationIndicatorLayer(_locationIndicatorLayerId);
        }
        map.setLocationIndicatorImageName(
          _locationIndicatorLayerId,
          mln.LocationIndicatorImageKind.top,
          command.topImage,
        );
        final bearingImage = command.bearingImage;
        if (bearingImage != null) {
          map.setLocationIndicatorImageName(
            _locationIndicatorLayerId,
            mln.LocationIndicatorImageKind.bearing,
            bearingImage,
          );
        }
        final shadowImage = command.shadowImage;
        if (shadowImage != null) {
          map.setLocationIndicatorImageName(
            _locationIndicatorLayerId,
            mln.LocationIndicatorImageKind.shadow,
            shadowImage,
          );
        }
        // Soft blue accuracy circle, matching the SDKs' default puck styling.
        map.setLayerProperty(
          _locationIndicatorLayerId,
          'accuracy-radius-color',
          jsonValueFromDart('rgba(66, 133, 244, 0.15)'),
        );
        map.setLayerProperty(
          _locationIndicatorLayerId,
          'accuracy-radius-border-color',
          jsonValueFromDart('rgba(66, 133, 244, 0.4)'),
        );
        session.requestRender();
      case UpdateLocationIndicatorCommand():
        final session = _session(command.sessionId);
        final map = session.map;
        if (!map.styleLayerExists(_locationIndicatorLayerId)) return;
        map.setLocationIndicatorLocation(
          _locationIndicatorLayerId,
          mln.LatLng(command.latitude, command.longitude),
        );
        final bearing = command.bearing;
        if (bearing != null) {
          map.setLocationIndicatorBearing(_locationIndicatorLayerId, bearing);
        }
        final accuracyRadius = command.accuracyRadius;
        if (accuracyRadius != null) {
          map.setLocationIndicatorAccuracyRadius(
            _locationIndicatorLayerId,
            accuracyRadius,
          );
        }
        session.requestRender();
      case RemoveLocationIndicatorCommand():
        final session = _session(command.sessionId);
        if (session.map.styleLayerExists(_locationIndicatorLayerId)) {
          session.map.removeStyleLayer(_locationIndicatorLayerId);
        }
        session.requestRender();
      case SetStyleImageCommand():
        final session = _session(command.sessionId);
        session.map.setStyleImage(
          command.name,
          _rgbaImage(command.rgba, command.width, command.height),
          options: mln.StyleImageOptions(
            pixelRatio: command.pixelRatio,
            sdf: command.sdf,
          ),
        );
        session.requestRender();
      case AddImageSourceCommand():
        final session = _session(command.sessionId);
        session.map.addImageSourceImage(
          command.sourceId,
          _quad(command.coordinates),
          _rgbaImage(command.rgba, command.width, command.height),
        );
        session.requestRender();
      case UpdateImageSourceCommand():
        final session = _session(command.sessionId);
        final rgba = command.rgba;
        if (rgba != null) {
          session.map.setImageSourceImage(
            command.sourceId,
            _rgbaImage(rgba, command.width!, command.height!),
          );
        }
        final coordinates = command.coordinates;
        if (coordinates != null) {
          session.map.setImageSourceCoordinates(
            command.sourceId,
            _quad(coordinates),
          );
        }
        session.requestRender();
      case SetFeatureStateCommand():
        final session = _session(command.sessionId);
        session.onRenderThread(
          (render) => render.setFeatureState(
            mln.FeatureStateSelector(
              sourceId: command.sourceId,
              sourceLayerId: command.sourceLayerId,
              featureId: command.featureId,
            ),
            jsonValueFromDart(command.state) as mln.JsonObject,
          ),
        );
        session.requestRender();
      case RemoveFeatureStateCommand():
        final session = _session(command.sessionId);
        session.onRenderThread(
          (render) => render.removeFeatureState(
            mln.FeatureStateSelector(
              sourceId: command.sourceId,
              sourceLayerId: command.sourceLayerId,
              featureId: command.featureId,
              stateKey: command.stateKey,
            ),
          ),
        );
        session.requestRender();
      case AddLayerJsonCommand():
        final session = _session(command.sessionId);
        session.map.addStyleLayerJson(
          jsonValueFromDart(command.layer),
          beforeLayerId: command.beforeLayerId,
        );
        session.requestRender();
      case RemoveSourceCommand():
        final session = _session(command.sessionId);
        session.map.removeStyleSource(command.sourceId);
        session.geojsonCache.remove(command.sourceId);
        session.requestRender();
      case RemoveLayerCommand():
        final session = _session(command.sessionId);
        session.map.removeStyleLayer(command.layerId);
        session.requestRender();
      case SetFrameStatsEnabledCommand():
        _session(command.sessionId).setFrameStatsEnabled(command.enabled);
    }
  }

  /// Replaces (or appends) one feature inside a cached GeoJSON document,
  /// matched by feature id (top-level `id` or the `id` property used by the
  /// annotation managers' promoteId convention).
  static void _mergeFeature(
    Map<String, dynamic> document,
    Map<String, dynamic> feature,
  ) {
    Object? idOf(Map<String, dynamic> f) =>
        f['id'] ?? (f['properties'] as Map?)?['id'];

    final features = document['features'];
    if (document['type'] != 'FeatureCollection' || features is! List) {
      document
        ..clear()
        ..addAll(feature);
      return;
    }
    final id = idOf(feature);
    for (var i = 0; i < features.length; i++) {
      final candidate = features[i];
      if (candidate is Map &&
          idOf(candidate.cast<String, dynamic>()) == id &&
          id != null) {
        features[i] = feature;
        return;
      }
    }
    features.add(feature);
  }

  static mln.LatLngBounds _latLngBounds(BoundsSpec bounds) => mln.LatLngBounds(
    southwest: mln.LatLng(bounds.south, bounds.west),
    northeast: mln.LatLng(bounds.north, bounds.east),
  );

  static mln.CameraOptions _cameraOptions(
    CameraSpec spec,
    double? anchorX,
    double? anchorY,
  ) {
    return mln.CameraOptions(
      center: spec.latitude == null || spec.longitude == null
          ? null
          : mln.LatLng(spec.latitude!, spec.longitude!),
      zoom: spec.zoom,
      bearing: spec.bearing,
      pitch: spec.pitch,
      anchor: anchorX == null || anchorY == null
          ? null
          : mln.ScreenPoint(anchorX, anchorY),
    );
  }

  static mln.PremultipliedRgba8Image _rgbaImage(
    Uint8List rgba,
    int width,
    int height,
  ) {
    return mln.PremultipliedRgba8Image(
      width: width,
      height: height,
      stride: width * 4,
      bytes: rgba,
    );
  }

  /// [lat, lng] x 4 pairs to bindings coordinates.
  static List<mln.LatLng> _quad(List<double> coordinates) => [
    for (var i = 0; i + 1 < coordinates.length; i += 2)
      mln.LatLng(coordinates[i], coordinates[i + 1]),
  ];

  static mln.AnimationOptions? _animation(
    double? durationMs,
    List<double>? easing,
  ) {
    if (durationMs == null) return null;
    return mln.AnimationOptions(
      durationMs: durationMs,
      easing: easing == null
          ? null
          : mln.UnitBezier(easing[0], easing[1], easing[2], easing[3]),
    );
  }
}
