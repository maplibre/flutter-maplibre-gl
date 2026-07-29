// One live map session plus the offline and snapshot record types.
//
// A `part` of engine_core.dart: same library, so these members keep access
// to the core's private state. Split for readability only; execution
// semantics are identical.

part of 'engine_core.dart';

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
  // CameraIsChangingEvent at the end of the drain (see EngineCore.pump).
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
    // Attaching is the one map operation the library runs on the render
    // session's owner rather than the map's, so it goes through a reference
    // that carries only the map's address and can therefore cross an isolate.
    // Both live on this isolate today, which makes the hop a formality; it is
    // also the seam that would let the render leave this isolate later.
    final attachRef = map.attachRef();
    switch (_spec) {
      case final OpenGlSessionQuery spec:
        _renderSession = attachRef.attachOpenGLSurface(
          mln.OpenGLSurfaceDescriptor(
            extent: extent,
            context: _eglContext(spec),
            surface: mln.NativePointer(surface),
          ),
        );
      case final VulkanSessionQuery spec:
        _renderSession = attachRef.attachVulkanSurface(
          mln.VulkanSurfaceDescriptor(
            extent: extent,
            context: _vulkanContext(spec),
            surface: mln.NativePointer(surface),
          ),
        );
    }
    _surfaceLost = false;
    map.requestRepaint();
    _renderPending = true;
  }

  static mln.EglContextDescriptor _eglContext(OpenGlSessionQuery spec) =>
      mln.EglContextDescriptor(
        display: mln.NativePointer(spec.eglDisplay),
        config: mln.NativePointer(spec.eglConfig),
        shareContext: mln.NativePointer(spec.eglContext),
      );

  static mln.VulkanContextDescriptor _vulkanContext(
    VulkanSessionQuery spec,
  ) => mln.VulkanContextDescriptor(
    instance: mln.NativePointer(spec.vkInstance),
    physicalDevice: mln.NativePointer(spec.vkPhysicalDevice),
    device: mln.NativePointer(spec.vkDevice),
    graphicsQueue: mln.NativePointer(spec.vkQueue),
    graphicsQueueFamilyIndex: spec.vkQueueFamilyIndex,
    getInstanceProcAddr: mln.NativePointer(spec.vkGetInstanceProcAddr),
    getDeviceProcAddr: mln.NativePointer(spec.vkGetDeviceProcAddr),
  );

  /// Creates an offscreen snapshot job: a static-mode map sharing this
  /// session's GPU context, rendering the live style and camera into an
  /// engine-owned texture that is read back when the still image finishes.
  ///
  /// [width]/[height] are the requested logical size; each falls back to the
  /// live surface dimension when null. The requested size is rendered at the
  /// session's own scale factor with the live camera unchanged, so an
  /// off-aspect size reveals more of the map rather than distorting it.
  _SnapshotJob createSnapshotJob(
    mln.RuntimeHandle runtime,
    int requestId, {
    int? width,
    int? height,
  }) {
    final snapshotWidth = width ?? logicalWidth;
    final snapshotHeight = height ?? logicalHeight;
    final snapshotMap = mln.MapHandle.create(
      runtime,
      options: mln.MapOptions(
        width: snapshotWidth,
        height: snapshotHeight,
        scaleFactor: scaleFactor,
        mapMode: mln.MapMode.staticMap,
      ),
    );
    mln.RenderSessionHandle? snapshotSession;
    try {
      final extent = mln.RenderTargetExtent(
        width: snapshotWidth,
        height: snapshotHeight,
        scaleFactor: scaleFactor,
      );
      final snapshotAttachRef = snapshotMap.attachRef();
      snapshotSession = switch (_spec) {
        final OpenGlSessionQuery spec => snapshotAttachRef
            .attachOpenGLOwnedTexture(
              mln.OpenGLOwnedTextureDescriptor(
                extent: extent,
                context: _eglContext(spec),
              ),
            ),
        final VulkanSessionQuery spec => snapshotAttachRef
            .attachVulkanOwnedTexture(
              mln.VulkanOwnedTextureDescriptor(
                extent: extent,
                context: _vulkanContext(spec),
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
