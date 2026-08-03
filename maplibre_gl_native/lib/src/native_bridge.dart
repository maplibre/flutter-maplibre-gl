import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import 'protocol/protocol.dart' show SessionBackend;

/// Handles returned by the Android shim when a texture is created.
///
/// All handles are raw native values encoded as int64, created on the
/// platform side (EGL14 in Kotlin for OpenGL builds, the Vulkan bootstrap in
/// shim.c for Vulkan builds) and borrowed by the MapLibre Native render
/// session through the Dart bindings.
///
/// One subtype per backend: the shim answers with the handle set of the
/// backend it was compiled for, and [fromMap] is the single place where that
/// untyped reply is checked. Everything downstream reads non-null fields.
sealed class NativeTextureHandles {
  const NativeTextureHandles({required this.textureId, required this.surface});

  /// Decodes the shim's reply. Throws if the shim announced a backend but
  /// omitted one of its handles, which would otherwise surface much later as
  /// a crash inside the render session.
  factory NativeTextureHandles.fromMap(Map<Object?, Object?> map) {
    int handle(String key) {
      final value = map[key];
      if (value is! int) {
        throw StateError(
          'the texture shim reply is missing the "$key" handle for the '
          '${map['backend']} backend',
        );
      }
      return value;
    }

    final textureId = handle('textureId');
    final surface = handle('surface');
    return map['backend'] == SessionBackend.vulkan.name
        ? VulkanTextureHandles(
            textureId: textureId,
            surface: surface,
            vkInstance: handle('vkInstance'),
            vkPhysicalDevice: handle('vkPhysicalDevice'),
            vkDevice: handle('vkDevice'),
            vkQueue: handle('vkQueue'),
            vkQueueFamilyIndex: handle('vkQueueFamilyIndex'),
            vkGetInstanceProcAddr: handle('vkGetInstanceProcAddr'),
            vkGetDeviceProcAddr: handle('vkGetDeviceProcAddr'),
          )
        : OpenGlTextureHandles(
            textureId: textureId,
            surface: surface,
            eglDisplay: handle('eglDisplay'),
            eglConfig: handle('eglConfig'),
            eglContext: handle('eglContext'),
          );
  }

  /// Flutter engine texture id, consumed by the [Texture] widget.
  final int textureId;

  /// Borrowed backend surface over the SurfaceProducer's Surface:
  /// an EGLSurface for OpenGL, a VkSurfaceKHR for Vulkan.
  final int surface;
}

/// Handles of an OpenGL build: the EGL objects the render session joins.
final class OpenGlTextureHandles extends NativeTextureHandles {
  const OpenGlTextureHandles({
    required super.textureId,
    required super.surface,
    required this.eglDisplay,
    required this.eglConfig,
    required this.eglContext,
  });

  final int eglDisplay;
  final int eglConfig;

  /// Borrowed EGLContext whose share group the render session joins.
  final int eglContext;
}

/// Handles of a Vulkan build: the instance, device and queue the shim
/// bootstrapped, plus the loader entry points.
final class VulkanTextureHandles extends NativeTextureHandles {
  const VulkanTextureHandles({
    required super.textureId,
    required super.surface,
    required this.vkInstance,
    required this.vkPhysicalDevice,
    required this.vkDevice,
    required this.vkQueue,
    required this.vkQueueFamilyIndex,
    required this.vkGetInstanceProcAddr,
    required this.vkGetDeviceProcAddr,
  });

  final int vkInstance;
  final int vkPhysicalDevice;
  final int vkDevice;

  /// Borrowed graphics VkQueue.
  final int vkQueue;

  /// Queue family index of [vkQueue].
  final int vkQueueFamilyIndex;

  /// PFN_vkGetInstanceProcAddr of the loader.
  final int vkGetInstanceProcAddr;

  /// PFN_vkGetDeviceProcAddr of the device loader.
  final int vkGetDeviceProcAddr;
}

/// Dart side of the minimal per-platform texture shim.
///
/// This is intentionally the ONLY platform channel in the FFI backend: its
/// sole job is to register an external texture with the Flutter engine and
/// hand raw backend handles to Dart. Every map/style/render call goes through
/// dart:ffi instead.
class NativeBridge {
  NativeBridge._();

  static const _channel = MethodChannel('maplibre_gl_native');

  static bool _initialized = false;

  /// Surface lifecycle handlers, one pair per live texture, registered by the
  /// MapView that owns the texture and removed in its dispose.
  ///
  /// Keyed by texture id because several maps can be live at once: a single
  /// static slot would let the newest map steal the events of every other one
  /// (a backgrounded first map would come back black), and the stale closure
  /// would pin its disposed session forever.
  static final Map<int, ({void Function() onDestroyed, void Function() onAvailable})>
  _surfaceHandlers = {};

  /// Registers the handlers called when the producer surface of [textureId]
  /// is destroyed (e.g. the app went to background, rendering must stop) or
  /// available again (the render target can be recreated). Replaces any
  /// previous registration for the same texture.
  static void registerSurfaceHandlers(
    int textureId, {
    required void Function() onDestroyed,
    required void Function() onAvailable,
  }) {
    _surfaceHandlers[textureId] = (
      onDestroyed: onDestroyed,
      onAvailable: onAvailable,
    );
  }

  /// Removes the surface handlers of [textureId]. Safe to call when none are
  /// registered.
  static void unregisterSurfaceHandlers(int textureId) {
    _surfaceHandlers.remove(textureId);
  }

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
          final handlers = _surfaceHandlers[textureId];
          if (handlers == null) return;
          call.method == 'onSurfaceDestroyed'
              ? handlers.onDestroyed()
              : handlers.onAvailable();
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

  /// Destroys the previous backend surface retired by [resizeTexture] or
  /// [recreateSurface].
  ///
  /// Kept alive until now because the render session holds a swapchain built
  /// from it up to the setTarget swap, and Vulkan destroys every swapchain
  /// before its surface. Call only after the engine has processed the attach
  /// or resize command (order it with a barrier query).
  static Future<void> releaseRetiredSurface({required int textureId}) {
    return _channel.invokeMethod<void>('releaseRetiredSurface', <String, Object>{
      'textureId': textureId,
    });
  }

  /// Destroys the backend surface and unregisters the external texture.
  static Future<void> disposeTexture({required int textureId}) {
    return _channel.invokeMethod<void>('disposeTexture', <String, Object>{
      'textureId': textureId,
    });
  }
}
