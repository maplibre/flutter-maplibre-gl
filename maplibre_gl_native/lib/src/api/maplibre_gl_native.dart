import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

import '../engine/engine_host.dart';
import '../protocol/protocol.dart';
import '../presentation/platform/ffi_platform.dart';

/// Entry point to opt a Flutter app into the FFI backend.
class MapLibreGlNative {
  MapLibreGlNative._();

  /// The transport of the live engine host: `'isolate'`, or `'none'` when no
  /// host has been bootstrapped yet.
  ///
  /// The MapLibre runtime, maps, and rendering always run on a dedicated
  /// engine isolate; benchmark harnesses assert on this instead of assuming.
  static String get activeEngineTransport =>
      EngineHost.instance == null ? 'none' : 'isolate';

  /// Routes every subsequently created `MapLibreMap` widget through the FFI
  /// backend instead of the method-channel platform views.
  ///
  /// The MapLibre runtime, maps, and rendering run on a dedicated engine
  /// isolate, keeping heavy tile-integration frames off the UI thread; the
  /// first map creation throws a [StateError] if that isolate cannot be
  /// bootstrapped. EXPERIMENTAL.
  static void use() {
    MapLibrePlatform.createInstance = MapLibreFfiPlatform.new;
  }

  /// Sets process-global HTTP headers applied to every engine resource
  /// request (styles, tiles, glyphs, sprites); pass an empty map to clear.
  ///
  /// Stand-in for maplibre_gl's global `setHttpHeaders`, which talks to the
  /// method-channel backends over a global platform channel that a Dart
  /// backend cannot intercept. Safe to call before the first map is created.
  static void setGlobalHttpHeaders(Map<String, String> headers) {
    EngineHost.globalHttpHeaders = Map.unmodifiable(headers);
    EngineHost.instance?.send(SetHttpHeadersCommand(headers));
  }
}
