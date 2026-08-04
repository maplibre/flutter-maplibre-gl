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
    required RenderThread renderThread,
    required void Function(mln.RenderSessionHandle) retireRenderSession,
  }) : _spec = spec,
       logicalWidth = spec.logicalWidth,
       logicalHeight = spec.logicalHeight,
       scaleFactor = spec.scaleFactor,
       _emit = emit,
       _renderThread = renderThread,
       _retireRenderSession = retireRenderSession;

  final int sessionId;

  /// The native map handle. All calls are owner-thread affine.
  final mln.MapHandle map;

  /// Backend and borrowed native context handles the session was created
  /// with, reused to build the surface descriptor on every re-attach. The
  /// surface handle it carries is only the first one: resize/recreate pass
  /// the fresh surface straight to [attachRenderTarget], never back in here.
  final CreateSessionQuery _spec;
  final void Function(EngineEvent) _emit;

  /// Whoever is drawing this session, and the handover for the calls that stay
  /// here. Every call on [_renderSession] must go through [_onRenderThread],
  /// because the session's owner thread may be the display pulse thread.
  final RenderThread _renderThread;

  /// [EngineCore.retireRenderSession]: withdraws a session from the display
  /// thread AND re-offers a surviving one. Sessions must go through it (not
  /// [RenderThread.retire] directly), because only the core knows the other
  /// sessions to offer when the driving one bows out.
  final void Function(mln.RenderSessionHandle) _retireRenderSession;

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

  /// The live render session. Private on purpose: handing it out bare invites a
  /// call that skips [onRenderThread], and every session entry point is
  /// owner-thread checked, so such a call fails the moment the display thread
  /// holds the session or the VM has moved this isolate. Go through
  /// [onRenderThread].
  ///
  /// Stays valid while the surface is released (the renderer survives); only a
  /// disposed session has none at all.
  mln.RenderSessionHandle _requireRenderSession() {
    final session = _renderSession;
    if (session == null) {
      throw StateError('The render session is not available');
    }
    return session;
  }

  /// Runs [body] with the render session owned by this isolate.
  ///
  /// Every session entry point is owner-thread checked and the owner may be the
  /// display pulse thread, so feature queries, feature state, resize, surface
  /// replace and detach all have to borrow it back for the length of one call.
  /// Blocks until the frame in flight finishes, so keep [body] to a leaf call
  /// and never nest these.
  T onRenderThread<T>(T Function(mln.RenderSessionHandle session) body) {
    final session = _requireRenderSession();
    return _renderThread.borrow(session, () => body(session));
  }

  /// [onRenderThread] for a session that may not exist yet.
  T? _withRenderSession<T>(T Function(mln.RenderSessionHandle session) body) {
    final session = _renderSession;
    if (session == null) return null;
    return _renderThread.borrow(session, () => body(session));
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
  /// exists, the new surface is swapped in place with the upstream setTarget
  /// API, keeping the renderer and every GPU-side resource (uploaded tiles,
  /// glyph atlases); a brand new render session is only created on first
  /// attach or as a fallback.
  ///
  /// The outgoing VkSurfaceKHR must still be valid here: the session holds a
  /// swapchain built from it until the swap, and Vulkan destroys every
  /// swapchain before its surface. The platform side defers that destruction
  /// until this command has been processed (see MapView and
  /// releaseRetiredSurface).
  void attachRenderTarget(int surface) {
    if (_closed) return;
    if (_renderSession != null) {
      final extent = mln.RenderTargetExtent(
        width: logicalWidth,
        height: logicalHeight,
        scaleFactor: scaleFactor,
      );
      try {
        _withRenderSession(
          (session) => switch (_spec) {
            final OpenGlSessionQuery spec => session.setOpenGLSurfaceTarget(
              mln.OpenGLSurfaceDescriptor(
                extent: extent,
                context: _eglContext(spec),
                surface: mln.NativePointer(surface),
              ),
            ),
            final VulkanSessionQuery spec => session.setVulkanSurfaceTarget(
              mln.VulkanSurfaceDescriptor(
                extent: extent,
                context: _vulkanContext(spec),
                surface: mln.NativePointer(surface),
              ),
            ),
          },
        );
        // Offer the session back: onSurfaceLost withdrew it from the display
        // thread, and without this the fallback quietly draws here forever.
        // With several maps live this steals the display thread from the
        // previously offered one, by design: one thread draws one session,
        // and the last attach wins.
        _renderThread.bindSession(_renderSession!);
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
    // Attaching bound the session to this isolate. Offer it to the display
    // pulse thread, which takes the affinity on its next frame (with several
    // maps live, the last attach wins; the others draw on this isolate).
    _renderThread.bindSession(_renderSession!);
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
        final OpenGlSessionQuery spec =>
          snapshotAttachRef.attachOpenGLOwnedTexture(
            mln.OpenGLOwnedTextureDescriptor(
              extent: extent,
              context: _eglContext(spec),
            ),
          ),
        final VulkanSessionQuery spec =>
          snapshotAttachRef.attachVulkanOwnedTexture(
            mln.VulkanOwnedTextureDescriptor(
              extent: extent,
              context: _vulkanContext(spec),
            ),
          ),
      };
      snapshotMap.setStyleJson(map.getLoadedStyleJson());
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
    final session = _renderSession;
    if (session == null) return;
    // Withdraw before destroying, not with a borrow: withdrawing waits for the
    // frame in flight and then guarantees the render thread will not touch this
    // session again, whereas taking the borrow and destroying inside it would
    // need the withdrawal afterwards, and that takes the same non-recursive
    // native mutex the borrow is holding. The withdrawal is conditional on
    // THIS session being the bound one, so tearing this map down cannot blank
    // another map, and the core re-offers a survivor when it was.
    _retireRenderSession(session);
    try {
      // The render thread held the affinity; destroy is owner-thread checked.
      session.rebindThread();
      session.close();
    } on mln.MaplibreException catch (error) {
      // A session we cannot destroy is a native leak, and saying so is all we
      // can do: the handle is already out of Dart's reach after this.
      debugPrint('[maplibre_gl_native] render session teardown failed: $error');
    }
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
    // Keep the render session alive and untouched: since upstream #485 the
    // swap happens wholly inside setTarget, which tears the old swapchain
    // down right before adopting the new surface. Until then the session
    // keeps its swapchain over the dying surface, which is why the platform
    // side must not destroy the old VkSurfaceKHR before the swap has been
    // processed. The renderer and its GPU resources survive, so the next
    // attach is a cheap swapchain rebuild instead of a visible full re-render
    // of the map.
    final session = _renderSession;
    if (session == null) return;
    // Withdraw from the display thread: with the window gone every render
    // fails, and the service must not be left grinding through failures it
    // cannot interpret. Conditional on this session being the bound one
    // (another map's surface loss must not pull ours), with the core
    // re-offering a survivor; the next attach offers this one back.
    _retireRenderSession(session);
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
  ///
  /// When the display pulse thread is drawing this session, the draw is not
  /// ours: the pending flag is still cleared and reported, because the frame
  /// loop uses the answer only to decide whether the map still has work, and
  /// the pulse thread is about to draw exactly what is pending.
  bool renderIfNeeded() {
    if (!_renderPending || !canRender) return false;
    _renderPending = false;
    if (_renderThread.isDrivingSession(_renderSession!)) return true;
    try {
      // Drawing it ourselves (no display thread, a second map, or the debug
      // knob). Still through the borrow: it is what re-homes the session after
      // the VM moved this isolate, which the runtime rebind no longer does.
      final stats = _frameStats;
      _withRenderSession(
        (session) => stats == null
            ? session.renderUpdate()
            : stats.measure(session.renderUpdate),
      );
      return true;
    } on mln.MaplibreException catch (error) {
      debugPrint('[maplibre_gl_native] render failed: $error');
      _renderPending = true;
      return false;
    }
  }

  /// Arms (or disarms) frame statistics collection; arming resets samples.
  ///
  /// Armed on both sides, because which one draws is decided at pacing time and
  /// can change (pulses going stale hands drawing back to this isolate).
  void setFrameStatsEnabled(bool enabled) {
    _frameStats = enabled ? FrameStatsCollector() : null;
    _renderThread.setStatsEnabled(enabled);
  }

  /// Drains the collected samples without stopping the collection, merging
  /// both sides: which one draws is decided at pacing time and can flip
  /// mid-scenario, so returning only one would silently lose the other's
  /// frames. The `source` field says who actually drew.
  Map<String, dynamic> takeFrameStats() {
    final session = _renderSession;
    final fromDisplayThread = session == null
        ? null
        : _renderThread.takeStats(session);
    return FrameStatsCollector.mergeStats(
      fromDisplayThread,
      _frameStats?.take(),
    );
  }

  /// Tears down the render session and the map. The external texture is the
  /// presentation side's to dispose.
  void close() {
    if (_closed) return;
    _closed = true;
    // Disarm frame stats if a benchmark left them armed: the render thread
    // outlives this session (it lives as long as the engine), so its native
    // sample buffers would otherwise never be freed.
    if (_frameStats != null) setFrameStatsEnabled(false);
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
