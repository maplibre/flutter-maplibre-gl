/// EXPERIMENTAL: maplibre_gl backend built on the MapLibre Native C API via
/// dart:ffi, rendering into a Flutter [Texture] instead of a platform view.
///
/// This package is the Android spike of the "same API, new engine" plan (see
/// `docs/rfc-native-ffi-engine.md`). Activate it before `runApp`:
///
/// ```dart
/// import 'package:maplibre_gl_native/maplibre_gl_native.dart';
///
/// void main() {
///   MapLibreGlNative.use();
///   runApp(const MyApp());
/// }
/// ```
library;

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

import 'src/engine/engine_isolate.dart';
import 'src/engine/engine_protocol.dart';
import 'src/platform/ffi_platform.dart';

export 'src/engine/engine_isolate.dart' show EngineHost;
export 'src/engine/engine_protocol.dart';
export 'src/platform/ffi_platform.dart' show MapLibreFfiPlatform;
export 'src/platform/offline_api.dart' show MapLibreGlNativeOffline;

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
  /// backend cannot intercept (see docs/ffi-api-expansion-plan.md). Safe to
  /// call before the first map is created.
  static void setGlobalHttpHeaders(Map<String, String> headers) {
    EngineHost.globalHttpHeaders = Map.unmodifiable(headers);
    EngineHost.instance?.send(SetHttpHeadersCommand(headers));
  }
}
