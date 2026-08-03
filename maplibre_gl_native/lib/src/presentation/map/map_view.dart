import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show OnPlatformViewCreatedCallback;

import '../../engine/render_backend.dart';
import '../../engine/engine_host.dart';
import '../../engine/map_session.dart';
import '../../protocol/protocol.dart';
import '../platform/ffi_platform.dart';
import '../gestures/map_gestures.dart';
import 'map_gesture_detector.dart';
import 'map_view_placeholder.dart';
import '../ornaments/ornaments_overlay.dart';
import '../platform/style_string_resolver.dart';
import '../../native_bridge.dart';
import '../../utils/projection.dart';

/// Texture-backed map view driven entirely through dart:ffi.
///
/// Replaces the AndroidView/UiKitView platform view of the method-channel
/// backend: the MapLibre Native core renders into a native window surface
/// backed by a Flutter [Texture], paced by the engine isolate's own frame
/// loop.
///
/// This widget is pure presentation: it owns the external texture and the
/// ornaments overlay, wires the gesture callbacks to [MapGestureHandler],
/// and talks to the engine core exclusively through the [EngineHost] message
/// protocol.
class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.platform,
    required this.creationParams,
    required this.onViewCreated,
  });

  final MapLibreFfiPlatform platform;
  final Map<String, dynamic> creationParams;
  final OnPlatformViewCreatedCallback onViewCreated;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  /// The live session, or null until [_initialize] has created it (and again
  /// after [dispose]). Everything that talks to the engine goes through it.
  MapSession? _session;
  int? _textureId;

  bool _initStarted = false;
  bool _resizing = false;
  Object? _initError;
  Size? _appliedLogicalSize;
  double _devicePixelRatio = 1;

  /// The latest layout seen while a resize was already in flight. Discarding
  /// it would leave the map stretched at the in-flight size until some later
  /// layout pass happens to run, so it is replayed when the in-flight resize
  /// completes.
  (Size, double)? _pendingResize;

  /// All gesture recognition and arbitration lives in the handler; the view
  /// only wires the widget callbacks to it in [build].
  ///
  /// The handler gets exactly the four things it needs (the session, the
  /// gesture flags, feature hit-testing, and two event sinks) instead of the
  /// whole platform adapter, so touch behavior can be exercised without one.
  late final MapGestureHandler _gestures = MapGestureHandler(
    session: () => _session,
    config: widget.platform.gestures,
    features: widget.platform.features,
    cameraPitch: () => _pitch,
    mounted: () => mounted,
    onUserPan: widget.platform.notifyUserGesture,
    onMapLongClick: widget.platform.onMapLongClickPlatform.call,
  );

  // Camera bearing mirrored from engine events for the compass ornament: a
  // notifier (not setState) so a rotating camera repaints the compass alone,
  // never the whole map Stack. Pitch feeds the gesture fling tilt factor.
  final ValueNotifier<double> _bearing = ValueNotifier(0);
  double _pitch = 0;

  // Compass repaint gate: during a continuous rotation the per-frame dial
  // repaint pushed near-budget UI frames over the 90 Hz budget (rotate jank
  // 24% -> 47% in the phase-2 A/B), so the ornament follows at ~15 Hz while
  // the camera streams and snaps exactly on idle.
  static const _compassMinInterval = Duration(milliseconds: 66);
  final Stopwatch _compassClock = Stopwatch()..start();
  int _lastCompassUpdateMs = -1000;

  // Ornament signals updated from engine events without rebuilding the
  // whole Stack: camera movement collapses the attribution pill, style loads
  // refresh its content, and the scale bar follows meters-per-pixel.
  final ValueNotifier<int> _cameraGeneration = ValueNotifier(0);
  final ValueNotifier<int> _styleGeneration = ValueNotifier(0);
  final ValueNotifier<double> _metersPerPixel = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    widget.platform.ornaments.addListener(_onOrnamentsChanged);
  }

  void _onOrnamentsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.platform.ornaments.removeListener(_onOrnamentsChanged);
    final session = _session;
    final textureId = _textureId;
    _session = null;
    // Unsubscribe BEFORE disposing the notifiers _onEngineEvent writes to:
    // an event delivered in between would hit a disposed ChangeNotifier.
    session?.host.removeEventListener(_onEngineEvent);
    _cameraGeneration.dispose();
    _styleGeneration.dispose();
    _metersPerPixel.dispose();
    _bearing.dispose();
    if (session != null) {
      session.send(DisposeSessionCommand(session.id));
    }
    if (textureId != null) {
      // Without this the closures above keep receiving this texture's
      // surface events (and pin the disposed session) for the process life.
      NativeBridge.unregisterSurfaceHandlers(textureId);
      // The engine must have detached from the EGL surface (FIFO barrier)
      // before the platform releases the texture that backs it.
      final barrier =
          session?.query(const BarrierQuery()) ?? Future.value(true);
      unawaited(
        barrier.whenComplete(
          () => NativeBridge.disposeTexture(textureId: textureId),
        ),
      );
    }
    super.dispose();
  }

  Future<void> _initialize(Size logicalSize, double devicePixelRatio) async {
    _initStarted = true;
    _devicePixelRatio = devicePixelRatio;
    _appliedLogicalSize = logicalSize;
    try {
      final host = await EngineHost.ensure();
      // The bundled native library is compiled for exactly one render
      // backend; prepare the platform texture for the matching one.
      final backend = RenderBackendSupport.vulkan
          ? SessionBackend.vulkan
          : SessionBackend.opengl;
      final handles = await NativeBridge.createTexture(
        physicalWidth: (logicalSize.width * devicePixelRatio).round(),
        physicalHeight: (logicalSize.height * devicePixelRatio).round(),
        backend: backend,
      );
      if (!mounted) {
        await NativeBridge.disposeTexture(
          textureId: handles.textureId,
        );
        return;
      }
      final logicalWidth = logicalSize.width.round();
      final logicalHeight = logicalSize.height.round();
      final sessionId = await host.query(switch (handles) {
        final OpenGlTextureHandles gl => OpenGlSessionQuery(
          textureId: gl.textureId,
          surface: gl.surface,
          eglDisplay: gl.eglDisplay,
          eglConfig: gl.eglConfig,
          eglContext: gl.eglContext,
          logicalWidth: logicalWidth,
          logicalHeight: logicalHeight,
          scaleFactor: devicePixelRatio,
        ),
        final VulkanTextureHandles vk => VulkanSessionQuery(
          textureId: vk.textureId,
          surface: vk.surface,
          vkInstance: vk.vkInstance,
          vkPhysicalDevice: vk.vkPhysicalDevice,
          vkDevice: vk.vkDevice,
          vkQueue: vk.vkQueue,
          vkQueueFamilyIndex: vk.vkQueueFamilyIndex,
          vkGetInstanceProcAddr: vk.vkGetInstanceProcAddr,
          vkGetDeviceProcAddr: vk.vkGetDeviceProcAddr,
          logicalWidth: logicalWidth,
          logicalHeight: logicalHeight,
          scaleFactor: devicePixelRatio,
        ),
      });
      final session = MapSession(host, sessionId);
      _session = session;
      _textureId = handles.textureId;

      _applyCreationParams(session);
      host.addEventListener(_onEngineEvent);
      widget.platform.attach(session);

      NativeBridge.registerSurfaceHandlers(
        handles.textureId,
        onDestroyed: () => session.send(SurfaceLostCommand(session.id)),
        onAvailable: () =>
            unawaited(_recreateSurface(session, handles.textureId)),
      );

      setState(() {});
      // The channel backends report the id of the platform view they created;
      // there is no platform view here, and maplibre_gl ignores the value (it
      // only takes the callback as the "the view exists now" signal), so 0
      // stands for "not a platform view".
      widget.onViewCreated(0);
    } catch (error, stackTrace) {
      // A map that cannot initialize must not fail silently: report it the way
      // Flutter reports any framework error (so it reaches the app's error
      // handler and crash reporting), and leave the reason on screen in debug.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'maplibre_gl_native',
          context: ErrorDescription('while initializing the FFI map view'),
        ),
      );
      if (mounted) setState(() => _initError = error);
    }
  }

  void _applyCreationParams(MapSession session) {
    final params = widget.creationParams;
    final initialCamera = params['initialCameraPosition'];
    if (initialCamera is Map) {
      final target = initialCamera['target'] as List?;
      if (target != null) {
        session.send(
          JumpToCommand(
            session.id,
            CameraSpec(
              latitude: (target[0] as num).toDouble(),
              longitude: (target[1] as num).toDouble(),
              zoom: (initialCamera['zoom'] as num?)?.toDouble(),
              bearing: (initialCamera['bearing'] as num?)?.toDouble(),
              pitch: (initialCamera['tilt'] as num?)?.toDouble(),
            ),
          ),
        );
      }
    }
    final styleString = params['styleString'] as String?;
    if (styleString != null && styleString.trim().isNotEmpty) {
      unawaited(_applyInitialStyle(session, styleString));
    }
    session.send(RequestRenderCommand(session.id));
  }

  /// Asset and file styles are read on the root isolate before crossing to
  /// the engine, which only accepts raw JSON or http(s) URLs.
  Future<void> _applyInitialStyle(
    MapSession session,
    String styleString,
  ) async {
    try {
      final resolved = await resolveStyleString(styleString);
      if (!mounted || _session?.id != session.id) return;
      session.send(SetStyleCommand(session.id, resolved));
      session.send(RequestRenderCommand(session.id));
    } catch (error) {
      debugPrint(
        '[maplibre_gl_native] loading style "$styleString" failed: $error',
      );
    }
  }

  Future<void> _recreateSurface(MapSession session, int textureId) async {
    try {
      // The FIFO barrier orders the SurfaceLostCommand before the new surface
      // exists, so the engine has stopped rendering into the dying window.
      await session.query(const BarrierQuery());
      // The old backend surface is NOT destroyed here: the session keeps a
      // swapchain built from it until the engine swaps targets, and Vulkan
      // destroys every swapchain before its surface. recreateSurface retires
      // the old pair; releaseRetiredSurface destroys it after the swap.
      final eglSurface = await NativeBridge.recreateSurface(
        textureId: textureId,
      );
      if (!mounted || _session?.id != session.id) return;
      session.send(AttachSurfaceCommand(session.id, eglSurface: eglSurface));
      await session.query(const BarrierQuery());
      await NativeBridge.releaseRetiredSurface(textureId: textureId);
    } catch (error) {
      // The session stays surface-lost, which is a black map; do not also
      // lose the ways back. Nothing here latches (no flag like _resizing),
      // so the next onSurfaceAvailable retries this whole path, and clearing
      // the applied size makes the next layout pass rebuild the surface
      // through the resize path even if no surface event ever comes.
      debugPrint(
        '[maplibre_gl_native] recreating the map surface failed: $error',
      );
      _appliedLogicalSize = null;
    }
  }

  void _onEngineEvent(EngineEvent event) {
    if (event is! SessionEvent || event.sessionId != _session?.id) return;
    if (event is CameraWillChangeEvent) _cameraGeneration.value++;
    if (event is StyleLoadedEvent) _styleGeneration.value++;
    final camera = switch (event) {
      CameraIsChangingEvent(:final camera) => camera,
      MapIdleEvent(:final camera) => camera,
      _ => null,
    };
    if (camera == null || !mounted) return;
    // Pitch feeds the gesture fling tilt factor: keep it fresh per event.
    _pitch = camera.pitch;
    // Ornaments are driven through notifiers with deadbands so camera
    // streams repaint only the affected ornament, never the map Stack.
    final mpp = MercatorProjection.metersPerPixel(
      camera.latitude,
      camera.zoom,
    );
    final current = _metersPerPixel.value;
    if (current <= 0 || (mpp - current).abs() / current > 0.01) {
      _metersPerPixel.value = mpp;
    }
    final nowMs = _compassClock.elapsedMilliseconds;
    final settled = event is MapIdleEvent;
    if ((camera.bearing - _bearing.value).abs() > 0.2 &&
        (settled ||
            nowMs - _lastCompassUpdateMs >=
                _compassMinInterval.inMilliseconds)) {
      _lastCompassUpdateMs = nowMs;
      _bearing.value = camera.bearing;
    }
  }

  void _maybeResize(Size logicalSize, double devicePixelRatio) {
    final session = _session;
    final textureId = _textureId;
    if (session == null || textureId == null) return;
    // Zero-width layouts happen mid-transition and a texture cannot be
    // resized to nothing; wait for a real size (the init path at the bottom
    // of build has the same guard).
    if (logicalSize.width < 1 || logicalSize.height < 1) return;
    if (_resizing) {
      // Remember it instead of dropping it: _appliedLogicalSize tracks the
      // resize in flight, so a drop here would never be retried.
      _pendingResize = (logicalSize, devicePixelRatio);
      return;
    }
    final applied = _appliedLogicalSize;
    if (applied != null &&
        (applied.width - logicalSize.width).abs() < 1 &&
        (applied.height - logicalSize.height).abs() < 1 &&
        _devicePixelRatio == devicePixelRatio) {
      return;
    }
    _resizing = true;
    _appliedLogicalSize = logicalSize;
    _devicePixelRatio = devicePixelRatio;
    unawaited(
      _resizeSurface(session, textureId, logicalSize, devicePixelRatio),
    );
  }

  Future<void> _resizeSurface(
    MapSession session,
    int textureId,
    Size logicalSize,
    double devicePixelRatio,
  ) async {
    try {
      // The producer surface is replaced on resize. Pause the engine first
      // (the FIFO barrier orders it across isolates) so nothing renders into
      // the window while the producer swaps it out.
      session.send(SurfaceLostCommand(session.id));
      await session.query(const BarrierQuery());
      // resizeTexture retires the old backend surface instead of destroying
      // it: the session keeps a swapchain built from it until the engine
      // swaps targets, and Vulkan destroys every swapchain before its
      // surface. releaseRetiredSurface destroys it after the swap.
      final eglSurface = await NativeBridge.resizeTexture(
        textureId: textureId,
        physicalWidth: (logicalSize.width * devicePixelRatio).round(),
        physicalHeight: (logicalSize.height * devicePixelRatio).round(),
      );
      if (!mounted || _session?.id != session.id) return;
      session.send(
        ResizeSessionCommand(
          session.id,
          logicalWidth: logicalSize.width.round(),
          logicalHeight: logicalSize.height.round(),
          scaleFactor: devicePixelRatio,
          eglSurface: eglSurface,
        ),
      );
      await session.query(const BarrierQuery());
      await NativeBridge.releaseRetiredSurface(textureId: textureId);
    } catch (error) {
      // The SurfaceLostCommand already went out, so a failure here (a
      // PlatformException from the texture shim, an engine query timeout)
      // would otherwise leave the session paused forever: a black map with
      // no path back. Forget the size we failed to apply so the next layout
      // pass retries, and try to put the current producer surface back under
      // the session right away.
      debugPrint('[maplibre_gl_native] resizing the map surface failed: $error');
      _appliedLogicalSize = null;
      if (mounted && _session?.id == session.id) {
        await _recreateSurface(session, textureId);
      }
    } finally {
      _resizing = false;
      // Replay the layout that arrived while this resize was in flight; the
      // applied-size check in _maybeResize makes it a no-op when it matches.
      final pending = _pendingResize;
      _pendingResize = null;
      if (pending != null && mounted) _maybeResize(pending.$1, pending.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalSize = Size(constraints.maxWidth, constraints.maxHeight);
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final textureId = _textureId;

        if (textureId == null) {
          if (!_initStarted &&
              logicalSize.width >= 1 &&
              logicalSize.height >= 1) {
            unawaited(_initialize(logicalSize, devicePixelRatio));
          }
          return MapViewPlaceholder(error: _initError);
        }

        _maybeResize(logicalSize, devicePixelRatio);

        return Stack(
          fit: StackFit.expand,
          children: [
            MapGestureDetector(
              handler: _gestures,
              child: Texture(textureId: textureId),
            ),
            OrnamentsOverlay(
              config: widget.platform.ornaments,
              bearing: _bearing,
              metersPerPixel: _metersPerPixel,
              cameraGeneration: _cameraGeneration,
              styleGeneration: _styleGeneration,
              loadAttributions: widget.platform.getAttributions,
              openUri: NativeBridge.openUri,
              onCompassTap: _resetBearing,
            ),
          ],
        );
      },
    );
  }

  void _resetBearing() {
    final session = _session;
    if (session == null) return;
    session.send(
      EaseToCommand(session.id, const CameraSpec(bearing: 0), durationMs: 300),
    );
  }
}
