import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart' show OnPlatformViewCreatedCallback;

import 'engine_core.dart' show FfiEngineCore;
import 'engine_isolate.dart';
import 'engine_protocol.dart';
import 'ffi_platform.dart';
import 'map_gestures.dart';
import 'ornaments.dart';
import 'style_string_resolver.dart';
import 'texture_bridge.dart';

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

  // Camera bearing mirrored from engine events for the compass ornament;
  // pitch feeds the fling tilt factor of the gesture handler.
  double _bearing = 0;
  double _pitch = 0;

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
    _cameraGeneration.dispose();
    _styleGeneration.dispose();
    _metersPerPixel.dispose();
    final host = _host;
    final sessionId = _sessionId;
    final textureId = _textureId;
    _host = null;
    _sessionId = null;
    host?.removeEventListener(_onEngineEvent);
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
      final backend = FfiEngineCore.supportsVulkan ? SessionBackend.vulkan : SessionBackend.opengl;
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
    // Mirror the camera for the ornaments; rebuild only on visible changes
    // to keep gesture streams cheap.
    final camera = switch (event) {
      CameraIsChangingEvent(:final camera) => camera,
      MapIdleEvent(:final camera) => camera,
      _ => null,
    };
    if (camera == null || !mounted) return;
    _pitch = camera.pitch;
    // Meters per logical pixel at the camera latitude (style-spec 512px
    // world tile), for the scale bar.
    final mpp = cos(camera.latitude * pi / 180) * 2 * pi * 6378137 / (512 * pow(2, camera.zoom));
    final current = _metersPerPixel.value;
    if (current <= 0 || (mpp - current).abs() / current > 0.01) {
      _metersPerPixel.value = mpp;
    }
    if ((camera.bearing - _bearing).abs() > 0.2) {
      setState(() => _bearing = camera.bearing);
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
    if (applied != null && (applied.width - logicalSize.width).abs() < 1 && (applied.height - logicalSize.height).abs() < 1 && _devicePixelRatio == devicePixelRatio) {
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
          if (!_initStarted && logicalSize.width >= 1 && logicalSize.height >= 1) {
            unawaited(_initialize(logicalSize, devicePixelRatio));
          }
          return const ColoredBox(color: Color(0xFF111725));
        }

        _maybeResize(logicalSize, devicePixelRatio);

        final ornaments = widget.platform.ornaments;
        return Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              onPointerDown: _gestures.onPointerDown,
              onPointerMove: _gestures.onPointerMove,
              onPointerUp: _gestures.onPointerUp,
              onPointerCancel: _gestures.onPointerCancel,
              onPointerSignal: _gestures.onPointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _gestures.onScaleStart,
                onScaleUpdate: _gestures.onScaleUpdate,
                onScaleEnd: _gestures.onScaleEnd,
                onDoubleTapDown: _gestures.onDoubleTapDown,
                onDoubleTap: _gestures.onDoubleTap,
                onTapUp: _gestures.onTapUp,
                onLongPressStart: _gestures.onLongPressStart,
                onLongPressMoveUpdate: _gestures.onLongPressMoveUpdate,
                onLongPressEnd: _gestures.onLongPressEnd,
                child: Texture(textureId: textureId),
              ),
            ),
            if (ornaments.logoEnabled)
              MapOrnament(
                position: ornaments.logoPosition,
                margins: ornaments.logoMargins,
                child: const LogoOrnament(),
              ),
            if (ornaments.attributionEnabled)
              MapOrnament(
                position: ornaments.attributionPosition,
                // When the attribution shares a corner with the logo, shift
                // it past the logo's 88px width like the native SDKs do.
                margins: ornaments.logoEnabled && ornaments.attributionPosition == ornaments.logoPosition
                    ? [
                        ornaments.attributionMargins[0] + 96,
                        ornaments.attributionMargins[1],
                      ]
                    : ornaments.attributionMargins,
                child: AttributionOrnament(
                  loadAttributions: widget.platform.getAttributions,
                  openUri: MapLibreGlNativeBridge.openUri,
                  collapseSignal: _cameraGeneration,
                  refreshSignal: _styleGeneration,
                  iconAtStart: ornaments.attributionPosition == 0 || ornaments.attributionPosition == 2,
                ),
              ),
            if (ornaments.scaleBarEnabled)
              MapOrnament(
                position: ornaments.scaleBarPosition,
                margins: ornaments.scaleBarMargins,
                child: ScaleBarOrnament(metersPerPixel: _metersPerPixel),
              ),
            if (ornaments.compassEnabled)
              MapOrnament(
                position: ornaments.compassPosition,
                margins: ornaments.compassMargins,
                child: CompassOrnament(
                  bearing: _bearing,
                  onTap: _resetBearing,
                ),
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
