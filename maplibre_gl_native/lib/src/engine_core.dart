import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:maplibre_native_ffi/maplibre_native_ffi.dart' as mln;

import 'engine_protocol.dart';
import 'frame_stats.dart';
import 'geojson_convert.dart';
import 'http_resource_provider.dart';
import 'json_convert.dart';

/// Style layer id of the location indicator (puck) managed by the engine.
const String _locationIndicatorLayerId = 'maplibre-gl-native-location';

/// Owns every MapLibre Native handle (runtime, maps, render sessions) and is
/// the only file allowed to touch `mln.*` types.
///
/// The presentation side talks to it exclusively through the sendable
/// [EngineMessage]/[EngineEvent] protocol, so that phase 3 of the
/// render-isolate plan can move this whole class to a dedicated isolate by
/// swapping the transport (see docs/rfc-native-ffi-engine.md, "Performance
/// profiling"). Runtime, maps, and sessions are OS-thread affine: everything
/// in this file must run on the thread that called [ensure].
class FfiEngineCore {
  FfiEngineCore._(this._runtime);

  static FfiEngineCore? _instance;

  final mln.RuntimeHandle _runtime;
  final Map<int, _EngineSession> _sessions = <int, _EngineSession>{};
  final List<_SnapshotJob> _snapshots = <_SnapshotJob>[];
  final Map<int, _PendingOfflineOp> _offlineOps = <int, _PendingOfflineOp>{};
  int _nextSessionId = 1;

  /// Sink for events pushed to the presentation side.
  void Function(EngineEvent event)? onEvent;

  /// Frame cap requested via [SetMaximumFpsCommand]; null means the default
  /// pacing. Read by the engine-isolate frame driver.
  int? maxFps;

  /// Lazily creates the shared runtime. The Android services
  /// (`mln_android_init` via the texture bridge) must be initialized by the
  /// caller BEFORE the first call.
  ///
  /// [cachePath] is the platform cache directory backing the persistent tile
  /// cache database (ambient cache, offline regions); without it the runtime
  /// falls back to an in-memory cache.
  factory FfiEngineCore.ensure({String? cachePath}) {
    final existing = _instance;
    if (existing != null) return existing;
    mln.Maplibre.setLogCallback((record) {
      debugPrint(
        '[MapLibreNative] ${record.severity} ${record.event}: '
        '${record.message}',
      );
    });
    final runtime = mln.RuntimeHandle.create(
      options: mln.RuntimeOptions(
        cachePath: cachePath == null
            ? ':memory:'
            : '$cachePath/maplibre_ffi_cache.db',
      ),
    );
    // Fetch styles/tiles/glyphs/sprites through Dart instead of the built-in
    // Rust HTTP client (whose TLS verification failed on some devices).
    HttpResourceProvider.install(runtime);
    final core = FfiEngineCore._(runtime);
    _instance = core;
    return core;
  }

  void _emit(EngineEvent event) => onEvent?.call(event);

  /// Rebinds the runtime and every handle it owns to the calling OS thread
  /// (local upstream patch; see upstream_patches/0002). Called by the isolate
  /// driver when the VM resumed the engine isolate on a different thread.
  void rebindThread() => _runtime.rebindThread();

  /// Whether the bundled native library was compiled with the Vulkan render
  /// backend. Decides which native surface the platform bridge prepares.
  static bool get supportsVulkan => mln.Maplibre.supportedRenderBackends()
      .contains(mln.RenderBackendMask.vulkan);

  _EngineSession _session(int sessionId) {
    final session = _sessions[sessionId];
    if (session == null) {
      throw StateError('Unknown or disposed engine session $sessionId');
    }
    return session;
  }

  // --- Frame driving ---------------------------------------------------------

  /// Pumps the runtime and renders every dirty session. Returns whether any
  /// frame was actually rendered. Used by the self-driving isolate loop.
  bool frame() {
    pump();
    var rendered = false;
    for (final session in _sessions.values) {
      rendered = session.renderIfNeeded() || rendered;
    }
    return _renderSnapshots() || rendered;
  }

  /// Renders pending offscreen snapshot jobs; returns whether any rendered.
  bool _renderSnapshots() {
    var rendered = false;
    for (final job in List.of(_snapshots)) {
      if (job.done || !job.renderPending) continue;
      job.renderPending = false;
      try {
        job.session.renderUpdate();
        rendered = true;
      } on mln.MaplibreException catch (error) {
        _finishSnapshot(job, error: '$error');
      }
    }
    return rendered;
  }

  /// Pumps the runtime and reports whether any session has a frame pending.
  bool pumpAndCheckAnyRenderPending() {
    pump();
    return _sessions.values.any((session) => session.renderPending);
  }

  /// Runs one owner-thread task and dispatches queued runtime events to the
  /// sessions they belong to.
  void pump() {
    _runtime.runOnce();
    while (true) {
      final event = _runtime.pollEvent();
      if (event == null) break;
      if (_handleOfflineEvent(event)) continue;
      final source = event.source;
      if (source is! mln.MapRuntimeEventSource) continue;
      var handled = false;
      for (final session in _sessions.values) {
        if (identical(session.map, source.map)) {
          session.handleEvent(event);
          handled = true;
          break;
        }
      }
      if (!handled) {
        for (final job in List.of(_snapshots)) {
          if (identical(job.map, source.map)) {
            _handleSnapshotEvent(job, event);
            break;
          }
        }
      }
    }
    // A continuous pan/zoom emits a burst of mapCameraIsChanging events per
    // frame; the listener re-reads the current camera each time, so only the
    // last one matters. Coalescing them to a single dispatch here removes the
    // per-event allocation + callback churn that would otherwise dominate the
    // UI thread.
    for (final session in _sessions.values) {
      session.flushCameraChanging();
    }
  }

  // --- Message dispatch ------------------------------------------------------

  /// Executes a fire-and-forget mutation.
  void handleCommand(EngineCommand command) {
    switch (command) {
      case SetHttpHeadersCommand():
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
        _runtime
            .runAmbientCacheOperation(switch (command.operation) {
              AmbientCacheOperationKind.resetDatabase =>
                mln.AmbientCacheOperation.resetDatabase,
              AmbientCacheOperationKind.packDatabase =>
                mln.AmbientCacheOperation.packDatabase,
              AmbientCacheOperationKind.invalidate =>
                mln.AmbientCacheOperation.invalidate,
              AmbientCacheOperationKind.clear =>
                mln.AmbientCacheOperation.clear,
            })
            .discard();
      case SetMaximumFpsCommand():
        maxFps = command.fps <= 0 ? null : command.fps;
      case CreateOfflineRegionCommand():
        _startOfflineOp(
          command.requestId,
          () => _runtime.createOfflineRegion(
            mln.OfflineTilePyramidRegionDefinition(
              styleUrl: command.styleUrl,
              bounds: mln.LatLngBounds(
                mln.LatLng(
                  command.southwestLatitude,
                  command.southwestLongitude,
                ),
                mln.LatLng(
                  command.northeastLatitude,
                  command.northeastLongitude,
                ),
              ),
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
          mln.LatLngBounds(
            mln.LatLng(command.southwestLatitude, command.southwestLongitude),
            mln.LatLng(command.northeastLatitude, command.northeastLongitude),
          ),
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
        _session(command.sessionId).map.setGestureInProgress(command.inProgress);
      case SetBoundsCommand():
        final session = _session(command.sessionId);
        final hasBounds =
            command.southwestLatitude != null &&
            command.southwestLongitude != null &&
            command.northeastLatitude != null &&
            command.northeastLongitude != null;
        session.map.setBounds(
          mln.BoundOptions(
            bounds: hasBounds
                ? mln.LatLngBounds(
                    mln.LatLng(
                      command.southwestLatitude!,
                      command.southwestLongitude!,
                    ),
                    mln.LatLng(
                      command.northeastLatitude!,
                      command.northeastLongitude!,
                    ),
                  )
                : null,
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
        trimmed.startsWith('{')
            ? session.map.setStyleJson(trimmed)
            : session.map.setStyleUrl(trimmed);
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
        _session(command.sessionId).map.setStyleTransitionOptions(
          enablePlacementTransitions: command.enabled,
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
          _snapshots.add(session.createSnapshotJob(_runtime, command.requestId));
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
        session.requireRenderSession().setFeatureState(
          mln.FeatureStateSelector(
            sourceId: command.sourceId,
            sourceLayerId: command.sourceLayerId,
            featureId: command.featureId,
          ),
          jsonValueFromDart(command.state) as mln.JsonObject,
        );
        session.requestRender();
      case RemoveFeatureStateCommand():
        final session = _session(command.sessionId);
        session.requireRenderSession().removeFeatureState(
          mln.FeatureStateSelector(
            sourceId: command.sourceId,
            sourceLayerId: command.sourceLayerId,
            featureId: command.featureId,
            stateKey: command.stateKey,
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
      final GetLayerIdsQuery q =>
        _session(q.sessionId).map.listStyleLayerIds(),
      final GetSourceIdsQuery q =>
        _session(q.sessionId).map.listStyleSourceIds(),
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

  // --- Query handlers --------------------------------------------------------

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
    final state = _session(query.sessionId).requireRenderSession()
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

  // --- Offline regions -----------------------------------------------------------

  /// Starts an async offline operation. Its runtime completion event resolves
  /// it: [take] builds the reply (consuming the handle's result); a null
  /// [take] means fire-and-forget (the handle is just discarded).
  void _startOfflineOp(
    int? requestId,
    mln.OfflineOperationHandle Function() start,
    OfflineResultEvent Function(mln.OfflineOperationHandle)? take,
  ) {
    mln.OfflineOperationHandle handle;
    try {
      handle = start();
    } catch (error) {
      if (requestId != null) {
        _emit(OfflineResultEvent(requestId, error: '$error'));
      }
      return;
    }
    _offlineOps[handle.id] = _PendingOfflineOp(requestId, handle, take);
  }

  /// Routes offline runtime events; returns whether the event was consumed.
  bool _handleOfflineEvent(mln.RuntimeEvent event) {
    final payload = event.payload;
    switch (event.eventType) {
      case mln.RuntimeEventType.offlineOperationCompleted:
        if (payload is! mln.RuntimeEventOfflineOperationCompleted) return true;
        final pending = _offlineOps.remove(payload.operationId);
        if (pending == null) return true;
        final take = pending.take;
        final requestId = pending.requestId;
        try {
          if (take == null || requestId == null) {
            pending.handle.discard();
          } else if (payload.resultStatus != mln.MaplibreStatus.ok) {
            pending.handle.discard();
            _emit(
              OfflineResultEvent(
                requestId,
                error:
                    'offline operation failed: ${payload.resultStatus.name}',
              ),
            );
          } else {
            _emit(take(pending.handle));
          }
        } catch (error) {
          if (requestId != null) {
            _emit(OfflineResultEvent(requestId, error: '$error'));
          }
        }
        return true;
      case mln.RuntimeEventType.offlineRegionStatusChanged:
        if (payload is mln.RuntimeEventOfflineRegionStatus) {
          _emit(
            OfflineRegionProgressEvent(
              payload.regionId,
              _statusToMap(payload.status),
            ),
          );
        }
        return true;
      case mln.RuntimeEventType.offlineRegionResponseError:
        if (payload is mln.RuntimeEventOfflineRegionResponseError) {
          _emit(
            OfflineRegionErrorEvent(
              payload.regionId,
              'resource error: ${payload.reason.name}',
            ),
          );
        }
        return true;
      default:
        return false;
    }
  }

  static Map<String, dynamic> _regionToMap(mln.OfflineRegionInfo info) {
    final definition = info.definition;
    // Geometry-defined regions (creatable by non-Flutter consumers) are
    // reported through their bounding box equivalent when possible.
    final (styleUrl, bounds, minZoom, maxZoom, includeIdeographs) =
        switch (definition) {
          mln.OfflineTilePyramidRegionDefinition d => (
            d.styleUrl,
            d.bounds,
            d.minZoom,
            d.maxZoom,
            d.includeIdeographs,
          ),
          mln.OfflineGeometryRegionDefinition d => (
            d.styleUrl,
            null,
            d.minZoom,
            d.maxZoom,
            d.includeIdeographs,
          ),
        };
    return <String, dynamic>{
      'id': info.id,
      'definition': <String, dynamic>{
        'styleUrl': styleUrl,
        if (bounds != null)
          'bounds': <double>[
            bounds.southwest.latitude,
            bounds.southwest.longitude,
            bounds.northeast.latitude,
            bounds.northeast.longitude,
          ],
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'includeIdeographs': includeIdeographs,
      },
      'metadata': info.metadata,
    };
  }

  static Map<String, dynamic> _statusToMap(mln.OfflineRegionStatus status) {
    return <String, dynamic>{
      'downloadActive':
          status.downloadState == mln.OfflineRegionDownloadState.active,
      'completedResourceCount': status.completedResourceCount,
      'completedResourceSize': status.completedResourceSize,
      'completedTileCount': status.completedTileCount,
      'requiredTileCount': status.requiredTileCount,
      'completedTileSize': status.completedTileSize,
      'requiredResourceCount': status.requiredResourceCount,
      'requiredResourceCountIsPrecise': status.requiredResourceCountIsPrecise,
      'complete': status.complete,
    };
  }

  // --- Offscreen snapshots -----------------------------------------------------

  void _handleSnapshotEvent(_SnapshotJob job, mln.RuntimeEvent event) {
    switch (event.eventType) {
      case mln.RuntimeEventType.mapRenderUpdateAvailable:
        job.renderPending = true;
        // Wake an idle-parked driver so the offscreen render progresses.
        _emit(RenderPendingEvent(job.sourceSessionId));
      case mln.RuntimeEventType.mapRenderFrameFinished:
        final payload = event.payload;
        if (payload is mln.RuntimeEventRenderFrame && payload.needsRepaint) {
          job.renderPending = true;
        }
      case mln.RuntimeEventType.mapStillImageFinished:
        _finishSnapshot(job, error: null);
      case mln.RuntimeEventType.mapStillImageFailed:
      case mln.RuntimeEventType.mapLoadingFailed:
        _finishSnapshot(job, error: event.message ?? 'snapshot render failed');
      default:
        break;
    }
  }

  void _finishSnapshot(_SnapshotJob job, {required String? error}) {
    if (job.done) return;
    job.done = true;
    _snapshots.remove(job);
    try {
      if (error == null) {
        final image = job.session.readPremultipliedRgba8();
        _emit(
          SnapshotResultEvent(
            job.sourceSessionId,
            job.requestId,
            rgba: image.bytes,
            width: image.info.width,
            height: image.info.height,
            stride: image.info.stride,
          ),
        );
      } else {
        _emit(
          SnapshotResultEvent(job.sourceSessionId, job.requestId, error: error),
        );
      }
    } on mln.MaplibreException catch (readError) {
      _emit(
        SnapshotResultEvent(
          job.sourceSessionId,
          job.requestId,
          error: '$readError',
        ),
      );
    } finally {
      job.session.close();
      job.map.close();
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

  // --- Helpers ---------------------------------------------------------------

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

/// One live FFI-backed map: a [mln.MapHandle] plus its render session.
///
/// The external texture and its EGL surface belong to the presentation side;
/// this class only consumes the raw handles it is given.
class _EngineSession {
  _EngineSession({
    required this.sessionId,
    required this.map,
    required CreateSessionQuery spec,
    required void Function(EngineEvent) emit,
  }) : _spec = spec,
       logicalWidth = spec.logicalWidth,
       logicalHeight = spec.logicalHeight,
       scaleFactor = spec.scaleFactor,
       _emit = emit;

  final int sessionId;

  /// The native map handle. All calls are owner-thread affine.
  final mln.MapHandle map;

  /// Backend and borrowed native context handles the session was created
  /// with; the surface handle inside is replaced on resize/recreate.
  final CreateSessionQuery _spec;
  final void Function(EngineEvent) _emit;

  mln.RenderSessionHandle? _renderSession;

  /// Decoded GeoJSON documents of sources added with inline data, kept so
  /// single-feature updates can merge engine-side without resending the
  /// whole collection across the isolate boundary.
  final Map<String, Map<String, dynamic>> geojsonCache =
      <String, Map<String, dynamic>>{};

  int logicalWidth;
  int logicalHeight;
  double scaleFactor;

  bool _renderPending = true;
  bool _surfaceLost = false;
  bool _closed = false;

  /// Benchmark instrumentation; non-null while collection is armed.
  FrameStatsCollector? _frameStats;

  // Set while draining a frame's events; flushed to a single
  // CameraIsChangingEvent at the end of the drain (see FfiEngineCore.pump).
  bool _cameraChangingPending = false;

  /// Whether a frame is waiting to be rendered.
  bool get renderPending => _renderPending;

  /// Whether rendering is currently possible.
  bool get canRender => !_closed && !_surfaceLost && _renderSession != null;

  /// The live render session, required by feature queries and feature state.
  /// These stay valid while the surface is released (the renderer survives);
  /// only a disposed session has no render session at all.
  mln.RenderSessionHandle requireRenderSession() {
    final session = _renderSession;
    if (session == null) {
      throw StateError('The render session is not available');
    }
    return session;
  }

  CameraSnapshot cameraSnapshot() {
    final camera = map.camera();
    return CameraSnapshot(
      latitude: camera.center?.latitude ?? 0,
      longitude: camera.center?.longitude ?? 0,
      zoom: camera.zoom ?? 0,
      bearing: camera.bearing ?? 0,
      pitch: camera.pitch ?? 0,
    );
  }

  /// Attaches the map to a native render target. When a live session already
  /// exists (its surface was released on surface loss), the new surface is
  /// swapped in place via the patched replace API, keeping the renderer and
  /// every GPU-side resource (uploaded tiles, glyph atlases); a brand new
  /// render session is only created on first attach or as a fallback.
  void attachRenderTarget(int surface) {
    if (_closed) return;
    if (_renderSession != null) {
      try {
        _renderSession!.replaceSurface(
          mln.NativePointer(surface),
          logicalWidth,
          logicalHeight,
          scaleFactor: scaleFactor,
        );
        _surfaceLost = false;
        map.requestRepaint();
        _renderPending = true;
        return;
      } on mln.MaplibreException catch (error) {
        debugPrint(
          '[maplibre_gl_native] surface replace failed, reattaching: $error',
        );
        _detachRenderTarget();
      }
    }
    final extent = mln.RenderTargetExtent(
      width: logicalWidth,
      height: logicalHeight,
      scaleFactor: scaleFactor,
    );
    switch (_spec.backend) {
      case SessionBackend.opengl:
        _renderSession = map.attachOpenGLSurface(
          mln.OpenGLSurfaceDescriptor(
            extent: extent,
            context: _eglContext(),
            surface: mln.NativePointer(surface),
          ),
        );
      case SessionBackend.vulkan:
        _renderSession = map.attachVulkanSurface(
          mln.VulkanSurfaceDescriptor(
            extent: extent,
            context: _vulkanContext(),
            surface: mln.NativePointer(surface),
          ),
        );
    }
    _surfaceLost = false;
    map.requestRepaint();
    _renderPending = true;
  }

  mln.EglContextDescriptor _eglContext() => mln.EglContextDescriptor(
    display: mln.NativePointer(_spec.eglDisplay!),
    config: mln.NativePointer(_spec.eglConfig!),
    shareContext: mln.NativePointer(_spec.eglContext!),
  );

  mln.VulkanContextDescriptor _vulkanContext() => mln.VulkanContextDescriptor(
    instance: mln.NativePointer(_spec.vkInstance!),
    physicalDevice: mln.NativePointer(_spec.vkPhysicalDevice!),
    device: mln.NativePointer(_spec.vkDevice!),
    graphicsQueue: mln.NativePointer(_spec.vkQueue!),
    graphicsQueueFamilyIndex: _spec.vkQueueFamilyIndex!,
    getInstanceProcAddr: mln.NativePointer(_spec.vkGetInstanceProcAddr!),
    getDeviceProcAddr: mln.NativePointer(_spec.vkGetDeviceProcAddr!),
  );

  /// Creates an offscreen snapshot job: a static-mode map sharing this
  /// session's GPU context, rendering the live style and camera into an
  /// engine-owned texture that is read back when the still image finishes.
  _SnapshotJob createSnapshotJob(mln.RuntimeHandle runtime, int requestId) {
    final snapshotMap = mln.MapHandle.create(
      runtime,
      options: mln.MapOptions(
        width: logicalWidth,
        height: logicalHeight,
        scaleFactor: scaleFactor,
        mapMode: mln.MapMode.staticMap,
      ),
    );
    mln.RenderSessionHandle? snapshotSession;
    try {
      final extent = mln.RenderTargetExtent(
        width: logicalWidth,
        height: logicalHeight,
        scaleFactor: scaleFactor,
      );
      snapshotSession = switch (_spec.backend) {
        SessionBackend.opengl => snapshotMap.attachOpenGLOwnedTexture(
          mln.OpenGLOwnedTextureDescriptor(
            extent: extent,
            context: _eglContext(),
          ),
        ),
        SessionBackend.vulkan => snapshotMap.attachVulkanOwnedTexture(
          mln.VulkanOwnedTextureDescriptor(
            extent: extent,
            context: _vulkanContext(),
          ),
        ),
      };
      snapshotMap.setStyleJson(map.getStyleJson());
      snapshotMap.jumpTo(map.camera());
      snapshotMap.requestStillImage();
      return _SnapshotJob(
        sourceSessionId: sessionId,
        requestId: requestId,
        map: snapshotMap,
        session: snapshotSession,
      );
    } catch (error) {
      snapshotSession?.close();
      snapshotMap.close();
      rethrow;
    }
  }

  void _detachRenderTarget() {
    _renderSession?.close();
    _renderSession = null;
  }

  /// Marks the session dirty and wakes an idle-parked driver.
  void requestRender() {
    if (_closed) return;
    _renderPending = true;
    map.requestRepaint();
    _emit(RenderPendingEvent(sessionId));
  }

  void onSurfaceLost() {
    _surfaceLost = true;
    // Keep the render session alive: only the presentation objects bound to
    // the dying surface are dropped (for Vulkan the swapchain, which must be
    // destroyed before the host destroys the VkSurfaceKHR). The renderer and
    // its GPU resources survive, so the next attach is a cheap swapchain
    // rebuild instead of a visible full re-render of the map.
    final session = _renderSession;
    if (session == null) return;
    try {
      session.releaseSurface();
    } on mln.MaplibreException catch (error) {
      debugPrint(
        '[maplibre_gl_native] surface release failed, detaching: $error',
      );
      _detachRenderTarget();
    }
  }

  /// Resizes the render target; the producer surface was replaced, so the
  /// session's native surface is swapped in place (or the session recreated
  /// as a fallback) against the new extent.
  void resize({
    required int newLogicalWidth,
    required int newLogicalHeight,
    required double newScaleFactor,
    required int eglSurface,
  }) {
    if (_closed) return;
    logicalWidth = newLogicalWidth;
    logicalHeight = newLogicalHeight;
    scaleFactor = newScaleFactor;
    attachRenderTarget(eglSurface);
  }

  void handleEvent(mln.RuntimeEvent event) {
    switch (event.eventType) {
      case mln.RuntimeEventType.mapRenderUpdateAvailable:
        _renderPending = true;
        _emit(RenderPendingEvent(sessionId));
      case mln.RuntimeEventType.mapRenderFrameFinished:
        final payload = event.payload;
        if (payload is mln.RuntimeEventRenderFrame && payload.needsRepaint) {
          _renderPending = true;
        }
      case mln.RuntimeEventType.mapStyleLoaded:
        _renderPending = true;
        _emit(StyleLoadedEvent(sessionId));
      case mln.RuntimeEventType.mapCameraWillChange:
        flushCameraChanging();
        _emit(CameraWillChangeEvent(sessionId));
      case mln.RuntimeEventType.mapCameraIsChanging:
        _cameraChangingPending = true;
        _renderPending = true;
      case mln.RuntimeEventType.mapCameraDidChange:
        // Gesture deltas are jump transitions, which emit only will/did
        // change (is-changing only fires for animated transitions): mark
        // the coalesced camera event pending here too so camera moves
        // stream once per drained frame during gestures as well.
        _cameraChangingPending = true;
      case mln.RuntimeEventType.mapIdle:
        flushCameraChanging();
        _emit(MapIdleEvent(sessionId, cameraSnapshot()));
      case mln.RuntimeEventType.mapLoadingFailed:
        debugPrint('[maplibre_gl_native] map loading failed: ${event.message}');
        _emit(MapLoadingFailedEvent(sessionId, event.message ?? 'unknown'));
      default:
        break;
    }
  }

  /// Emits the coalesced camera-changing event accumulated during a drain.
  void flushCameraChanging() {
    if (!_cameraChangingPending || _closed) return;
    _cameraChangingPending = false;
    _emit(CameraIsChangingEvent(sessionId, cameraSnapshot()));
  }

  /// Renders a frame if one is pending. Returns true when a frame was
  /// actually rendered.
  bool renderIfNeeded() {
    if (!_renderPending || !canRender) return false;
    _renderPending = false;
    try {
      final stats = _frameStats;
      if (stats == null) {
        _renderSession!.renderUpdate();
      } else {
        stats.measure(_renderSession!.renderUpdate);
      }
      return true;
    } on mln.MaplibreException catch (error) {
      debugPrint('[maplibre_gl_native] render failed: $error');
      _renderPending = true;
      return false;
    }
  }

  /// Arms (or disarms) frame statistics collection; arming resets samples.
  void setFrameStatsEnabled(bool enabled) {
    _frameStats = enabled ? FrameStatsCollector() : null;
  }

  /// Drains the collected samples without stopping the collection.
  Map<String, dynamic> takeFrameStats() =>
      _frameStats?.take() ?? FrameStatsCollector.emptyStats();

  /// Tears down the render session and the map. The external texture is the
  /// presentation side's to dispose.
  void close() {
    if (_closed) return;
    _closed = true;
    _detachRenderTarget();
    map.close();
  }
}

/// One in-flight offline operation waiting for its completion event.
class _PendingOfflineOp {
  const _PendingOfflineOp(this.requestId, this.handle, this.take);

  /// Reply correlation id; null for fire-and-forget operations.
  final int? requestId;
  final mln.OfflineOperationHandle handle;
  final OfflineResultEvent Function(mln.OfflineOperationHandle)? take;
}

/// One in-flight offscreen snapshot: a static-mode map plus its owned
/// texture session, alive until the still image finishes (or fails) and its
/// pixels are read back.
class _SnapshotJob {
  _SnapshotJob({
    required this.sourceSessionId,
    required this.requestId,
    required this.map,
    required this.session,
  });

  final int sourceSessionId;
  final int requestId;
  final mln.MapHandle map;
  final mln.RenderSessionHandle session;
  bool renderPending = true;
  bool done = false;
}
