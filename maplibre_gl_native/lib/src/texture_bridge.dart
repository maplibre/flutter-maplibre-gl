import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import 'engine_protocol.dart' show SessionBackend;

/// Handles returned by the Android shim when a texture is created.
///
/// All handles are raw native values encoded as int64, created on the
/// platform side (EGL14 in Kotlin for OpenGL builds, the Vulkan bootstrap in
/// shim.c for Vulkan builds) and borrowed by the MapLibre Native render
/// session through the Dart bindings.
class NativeTextureHandles {
  const NativeTextureHandles({
    required this.backend,
    required this.textureId,
    required this.surface,
    this.eglDisplay,
    this.eglConfig,
    this.eglContext,
    this.vkInstance,
    this.vkPhysicalDevice,
    this.vkDevice,
    this.vkQueue,
    this.vkQueueFamilyIndex,
    this.vkGetInstanceProcAddr,
    this.vkGetDeviceProcAddr,
  });

  factory NativeTextureHandles.fromMap(Map<Object?, Object?> map) {
    final backend = map['backend'] == 'vulkan'
        ? SessionBackend.vulkan
        : SessionBackend.opengl;
    return NativeTextureHandles(
      backend: backend,
      textureId: map['textureId']! as int,
      surface: map['surface']! as int,
      eglDisplay: map['eglDisplay'] as int?,
      eglConfig: map['eglConfig'] as int?,
      eglContext: map['eglContext'] as int?,
      vkInstance: map['vkInstance'] as int?,
      vkPhysicalDevice: map['vkPhysicalDevice'] as int?,
      vkDevice: map['vkDevice'] as int?,
      vkQueue: map['vkQueue'] as int?,
      vkQueueFamilyIndex: map['vkQueueFamilyIndex'] as int?,
      vkGetInstanceProcAddr: map['vkGetInstanceProcAddr'] as int?,
      vkGetDeviceProcAddr: map['vkGetDeviceProcAddr'] as int?,
    );
  }

  /// Backend the handles belong to.
  final SessionBackend backend;

  /// Flutter engine texture id, consumed by the [Texture] widget.
  final int textureId;

  /// Borrowed backend surface over the SurfaceProducer's Surface:
  /// an EGLSurface for OpenGL, a VkSurfaceKHR for Vulkan.
  final int surface;

  /// Borrowed EGLDisplay (OpenGL builds).
  final int? eglDisplay;

  /// Borrowed EGLConfig (OpenGL builds).
  final int? eglConfig;

  /// Borrowed EGLContext whose share group the render session joins
  /// (OpenGL builds).
  final int? eglContext;

  /// Borrowed VkInstance (Vulkan builds).
  final int? vkInstance;

  /// Borrowed VkPhysicalDevice (Vulkan builds).
  final int? vkPhysicalDevice;

  /// Borrowed VkDevice (Vulkan builds).
  final int? vkDevice;

  /// Borrowed graphics VkQueue (Vulkan builds).
  final int? vkQueue;

  /// Queue family index of [vkQueue] (Vulkan builds).
  final int? vkQueueFamilyIndex;

  /// PFN_vkGetInstanceProcAddr of the loader (Vulkan builds).
  final int? vkGetInstanceProcAddr;

  /// PFN_vkGetDeviceProcAddr of the device loader (Vulkan builds).
  final int? vkGetDeviceProcAddr;
}

/// Dart side of the minimal per-platform texture shim.
///
/// This is intentionally the ONLY platform channel in the FFI backend: its
/// sole job is to register an external texture with the Flutter engine and
/// hand raw backend handles to Dart. Every map/style/render call goes through
/// dart:ffi instead.
class MapLibreGlNativeBridge {
  MapLibreGlNativeBridge._();

  static const _channel = MethodChannel('maplibre_gl_native');

  static bool _initialized = false;

  /// Callback invoked when the producer surface of [textureId] was destroyed
  /// (e.g. the app went to background) and rendering must stop.
  static void Function(int textureId)? onSurfaceDestroyed;

  /// Callback invoked when the producer surface of [textureId] is available
  /// again and the render target can be recreated.
  static void Function(int textureId)? onSurfaceAvailable;

  /// Callback invoked with raw platform location fixes while
  /// [startLocationUpdates] is active. Keys: latitude, longitude, altitude?,
  /// bearing?, speed?, horizontalAccuracy?, verticalAccuracy?, timestamp
  /// (ms since epoch).
  static void Function(Map<Object?, Object?> fix)? onLocationUpdate;

  static void _ensureHandler() {
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments as Map<Object?, Object?>?;
      switch (call.method) {
        case 'onLocationUpdate':
          if (args != null) onLocationUpdate?.call(args);
        case 'onSurfaceDestroyed' || 'onSurfaceAvailable':
          final textureId = args?['textureId'] as int?;
          if (textureId == null) return;
          call.method == 'onSurfaceDestroyed'
              ? onSurfaceDestroyed?.call(textureId)
              : onSurfaceAvailable?.call(textureId);
      }
    });
  }

  /// Starts streaming platform location fixes ([onLocationUpdate]). The
  /// location permission must already be granted by the app; returns false
  /// (with a log) when it is not.
  static Future<bool> startLocationUpdates() async {
    try {
      await _channel.invokeMethod<void>('startLocationUpdates');
      return true;
    } on PlatformException catch (error) {
      debugPrint(
        '[maplibre_gl_native] location updates unavailable: ${error.message}',
      );
      return false;
    }
  }

  /// Stops streaming platform location fixes.
  static Future<void> stopLocationUpdates() =>
      _channel.invokeMethod<void>('stopLocationUpdates');

  /// Opens [uri] in the system browser (attribution links). Returns false
  /// when no activity could handle it.
  static Future<bool> openUri(String uri) async {
    try {
      return await _channel.invokeMethod<bool>('openUri', {'uri': uri}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Loads the native library on the platform side and initializes Android
  /// platform services (`mln_android_init`, required for TLS verification of
  /// HTTP requests issued by the MapLibre Native core).
  static Future<void> init() async {
    if (_initialized) return;
    _ensureHandler();
    await _channel.invokeMethod<void>('init');
    _initialized = true;
  }

  /// Returns the app's cache directory path; backs the persistent tile
  /// cache database of the engine runtime.
  static Future<String> getCacheDir() async {
    final result = await _channel.invokeMethod<String>('getCacheDir');
    return result!;
  }

  /// Registers a new external texture of [physicalWidth]x[physicalHeight]
  /// device pixels, prepared for [backend], and returns its Flutter texture
  /// id plus the native handles needed to attach a MapLibre Native surface
  /// render session.
  static Future<NativeTextureHandles> createTexture({
    required int physicalWidth,
    required int physicalHeight,
    required SessionBackend backend,
  }) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'createTexture',
      <String, Object>{
        'physicalWidth': physicalWidth,
        'physicalHeight': physicalHeight,
        'backend': backend.name,
      },
    );
    return NativeTextureHandles.fromMap(result!);
  }

  /// Resizes the producer surface behind [textureId] and returns the new
  /// backend surface handle (the old one is destroyed by the shim).
  static Future<int> resizeTexture({
    required int textureId,
    required int physicalWidth,
    required int physicalHeight,
  }) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'resizeTexture',
      <String, Object>{
        'textureId': textureId,
        'physicalWidth': physicalWidth,
        'physicalHeight': physicalHeight,
      },
    );
    return result!['surface']! as int;
  }

  /// Recreates the backend surface for [textureId] after the producer
  /// surface became available again, without changing its size.
  static Future<int> recreateSurface({required int textureId}) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'recreateSurface',
      <String, Object>{'textureId': textureId},
    );
    return result!['surface']! as int;
  }

  /// Destroys the backend surface and unregisters the external texture.
  static Future<void> disposeTexture({required int textureId}) {
    return _channel.invokeMethod<void>('disposeTexture', <String, Object>{
      'textureId': textureId,
    });
  }
}
