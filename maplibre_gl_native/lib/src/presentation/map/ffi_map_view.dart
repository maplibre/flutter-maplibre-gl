import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show OnPlatformViewCreatedCallback;

import '../../engine/render_backend.dart';
import '../../engine/engine_host.dart';
import '../../protocol/protocol.dart';
import '../platform/ffi_platform.dart';
import '../gestures/map_gestures.dart';
import 'map_gesture_detector.dart';
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
class FfiMapView extends StatefulWidget {
  const FfiMapView({
    super.key,
    required this.platform,
    required this.creationParams,
    required this.onViewCreated,
  });

  final MapLibreFfiPlatform platform;
  final Map<String, dynamic> creationParams;
  final OnPlatformViewCreatedCallback onViewCreated;

  @override
  State<FfiMapView> createState() => _FfiMapViewState();
}

class _FfiMapViewState extends State<FfiMapView> {
  EngineHost? _host;
  int? _sessionId;
  int? _textureId;

  bool _initStarted = false;
  bool _resizing = false;
  Size? _appliedLogicalSize;
  double _devicePixelRatio = 1;

  /// All gesture recognition and arbitration lives in the handler; the view
  /// only wires the widget callbacks to it in [build].
  late final MapGestureHandler _gestures = MapGestureHandler(
    platform: widget.platform,
    host: () => _host,
    sessionId: () => _sessionId,
    cameraPitch: () => _pitch,
    mounted: () => mounted,
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
    final host = _host;
    final sessionId = _sessionId;
    final textureId = _textureId;
    _host = null;
    _sessionId = null;
    // Unsubscribe BEFORE disposing the notifiers _onEngineEvent writes to:
    // an event delivered in between would hit a disposed ChangeNotifier.
    host?.removeEventListener(_onEngineEvent);
    _cameraGeneration.dispose();
    _styleGeneration.dispose();
    _metersPerPixel.dispose();
    _bearing.dispose();
    if (host != null && sessionId != null) {
      host.send(DisposeSessionCommand(sessionId));
    }
    if (textureId != null) {
      // The engine must have detached from the EGL surface (FIFO barrier)
      // before the platform releases the texture that backs it.
      final barrier = host?.query(const BarrierQuery()) ?? Future.value(true);
      unawaited(
        barrier.whenComplete(
          () => MapLibreGlNativeBridge.disposeTexture(textureId: textureId),
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
      final handles = await MapLibreGlNativeBridge.createTexture(
        physicalWidth: (logicalSize.width * devicePixelRatio).round(),
        physicalHeight: (logicalSize.height * devicePixelRatio).round(),
        backend: backend,
      );
      if (!mounted) {
        await MapLibreGlNativeBridge.disposeTexture(
          textureId: handles.textureId,
        );
        return;
      }
      final logicalWidth = logicalSize.width.round();
      final logicalHeight = logicalSize.height.round();
      final sessionId = await host.query(switch (handles.backend) {
        SessionBackend.opengl => CreateSessionQuery.opengl(
          textureId: handles.textureId,
          surface: handles.surface,
          eglDisplay: handles.eglDisplay!,
          eglConfig: handles.eglConfig!,
          eglContext: handles.eglContext!,
          logicalWidth: logicalWidth,
          logicalHeight: logicalHeight,
          scaleFactor: devicePixelRatio,
        ),
        SessionBackend.vulkan => CreateSessionQuery.vulkan(
          textureId: handles.textureId,
          surface: handles.surface,
          vkInstance: handles.vkInstance!,
          vkPhysicalDevice: handles.vkPhysicalDevice!,
          vkDevice: handles.vkDevice!,
          vkQueue: handles.vkQueue!,
          vkQueueFamilyIndex: handles.vkQueueFamilyIndex!,
          vkGetInstanceProcAddr: handles.vkGetInstanceProcAddr!,
          vkGetDeviceProcAddr: handles.vkGetDeviceProcAddr!,
          logicalWidth: logicalWidth,
          logicalHeight: logicalHeight,
          scaleFactor: devicePixelRatio,
        ),
      });
      _host = host;
      _sessionId = sessionId;
      _textureId = handles.textureId;

      _applyCreationParams(host, sessionId);
      host.addEventListener(_onEngineEvent);
      widget.platform.attach(host, sessionId);

      MapLibreGlNativeBridge.onSurfaceDestroyed = (textureId) {
        if (textureId == handles.textureId) {
          host.send(SurfaceLostCommand(sessionId));
        }
      };
      MapLibreGlNativeBridge.onSurfaceAvailable = (textureId) {
        if (textureId == handles.textureId) {
          unawaited(_recreateSurface(host, sessionId, textureId));
        }
      };

      setState(() {});
      widget.onViewCreated(widget.platform.hashCode);
    } catch (error, stackTrace) {
      debugPrint('[maplibre_gl_native] map init failed: $error\n$stackTrace');
    }
  }

  void _applyCreationParams(EngineHost host, int sessionId) {
    final params = widget.creationParams;
    final initialCamera = params['initialCameraPosition'];
    if (initialCamera is Map) {
      final target = initialCamera['target'] as List?;
      if (target != null) {
        host.send(
          JumpToCommand(
            sessionId,
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
      unawaited(_applyInitialStyle(host, sessionId, styleString));
    }
    host.send(RequestRenderCommand(sessionId));
  }

  /// Asset and file styles are read on the root isolate before crossing to
  /// the engine, which only accepts raw JSON or http(s) URLs.
  Future<void> _applyInitialStyle(
    EngineHost host,
    int sessionId,
    String styleString,
  ) async {
    try {
      final resolved = await resolveStyleString(styleString);
      if (!mounted || _sessionId != sessionId) return;
      host.send(SetStyleCommand(sessionId, resolved));
      host.send(RequestRenderCommand(sessionId));
    } catch (error) {
      debugPrint(
        '[maplibre_gl_native] loading style "$styleString" failed: $error',
      );
    }
  }

  Future<void> _recreateSurface(
    EngineHost host,
    int sessionId,
    int textureId,
  ) async {
    // The engine released the swapchain when SurfaceLostCommand was
    // processed; the FIFO barrier guarantees that happened before the
    // platform destroys the old VkSurfaceKHR inside recreateSurface
    // (Vulkan mandates that destruction order).
    await host.query(const BarrierQuery());
    final eglSurface = await MapLibreGlNativeBridge.recreateSurface(
      textureId: textureId,
    );
    if (!mounted || _sessionId != sessionId) return;
    host.send(AttachSurfaceCommand(sessionId, eglSurface: eglSurface));
  }

  void _onEngineEvent(EngineEvent event) {
    if (event.sessionId != _sessionId) return;
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
    final host = _host;
    final sessionId = _sessionId;
    final textureId = _textureId;
    if (host == null || sessionId == null || textureId == null || _resizing) {
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
      _resizeSurface(host, sessionId, textureId, logicalSize, devicePixelRatio),
    );
  }

  Future<void> _resizeSurface(
    EngineHost host,
    int sessionId,
    int textureId,
    Size logicalSize,
    double devicePixelRatio,
  ) async {
    try {
      // The producer surface is replaced on resize. Have the engine release
      // the native surface first (dropping the Vulkan swapchain while the
      // renderer stays alive; the FIFO barrier orders this across isolates)
      // so the platform never destroys a surface that is still presented to.
      host.send(SurfaceLostCommand(sessionId));
      await host.query(const BarrierQuery());
      final eglSurface = await MapLibreGlNativeBridge.resizeTexture(
        textureId: textureId,
        physicalWidth: (logicalSize.width * devicePixelRatio).round(),
        physicalHeight: (logicalSize.height * devicePixelRatio).round(),
      );
      if (!mounted || _sessionId != sessionId) return;
      host.send(
        ResizeSessionCommand(
          sessionId,
          logicalWidth: logicalSize.width.round(),
          logicalHeight: logicalSize.height.round(),
          scaleFactor: devicePixelRatio,
          eglSurface: eglSurface,
        ),
      );
    } finally {
      _resizing = false;
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
          return const ColoredBox(color: Color(0xFF111725));
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
              openUri: MapLibreGlNativeBridge.openUri,
              onCompassTap: _resetBearing,
            ),
          ],
        );
      },
    );
  }

  void _resetBearing() {
    final host = _host;
    final sessionId = _sessionId;
    if (host == null || sessionId == null) return;
    host.send(
      EaseToCommand(sessionId, const CameraSpec(bearing: 0), durationMs: 300),
    );
  }
}
