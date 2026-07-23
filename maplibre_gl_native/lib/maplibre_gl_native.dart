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

import 'src/engine_host.dart';
import 'src/engine_protocol.dart';
import 'src/ffi_platform.dart';

export 'src/engine_host.dart' show EngineHost, LocalEngineHost;
export 'src/engine_isolate.dart' show IsolateEngineHost;
export 'src/engine_protocol.dart';
export 'src/ffi_platform.dart' show MapLibreFfiPlatform;
export 'src/offline_api.dart' show MapLibreGlNativeOffline;

/// Entry point to opt a Flutter app into the FFI backend.
class MapLibreGlNative {
  MapLibreGlNative._();

  static bool _engineIsolate = false;

  /// Whether the engine runs on a dedicated isolate (phase 3 of the
  /// render-isolate plan) instead of the root isolate.
  static bool get engineIsolateEnabled => _engineIsolate;

  /// The transport of the live engine host: `'isolate'`, `'local'`, or
  /// `'none'` when no host has been bootstrapped yet.
  ///
  /// The isolate bootstrap silently falls back to the single-isolate engine
  /// on failure, so anything that must know which mode actually runs (e.g. a
  /// benchmark harness) asserts on this instead of [engineIsolateEnabled].
  static String get activeEngineTransport {
    final host = FfiEngineConfig.activeHost;
    if (host == null) return 'none';
    return host.drivesFrames ? 'isolate' : 'local';
  }

  /// Routes every subsequently created `MapLibreMap` widget through the FFI
  /// backend instead of the method-channel platform views.
  ///
  /// With [engineIsolate] the MapLibre runtime, maps, and rendering run on a
  /// dedicated isolate, keeping heavy tile-integration frames off the UI
  /// thread. Falls back to the single-isolate engine if the isolate
  /// bootstrap fails. EXPERIMENTAL.
  static void use({bool engineIsolate = false}) {
    _engineIsolate = engineIsolate;
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
    FfiEngineConfig.globalHttpHeaders = Map.unmodifiable(headers);
    FfiEngineConfig.activeHost?.send(SetHttpHeadersCommand(headers));
  }
}
