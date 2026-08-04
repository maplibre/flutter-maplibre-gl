import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

import '../engine/engine_host.dart';
import '../protocol/protocol.dart';
import '../presentation/ornaments/ornament_config.dart';
import '../presentation/platform/ffi_platform.dart';

/// Entry point to opt a Flutter app into the FFI backend.
class MapLibreGlNative {
  MapLibreGlNative._();

  /// The COMMAND transport of the live engine host: `'isolate'`, or `'none'`
  /// when no host has been bootstrapped yet.
  ///
  /// This says nothing about which thread draws: rendering happens on a
  /// display-paced native thread by default (the frame stats' `source` field
  /// names the drawing side). Benchmark harnesses assert on this instead of
  /// assuming.
  static String get activeEngineTransport =>
      EngineHost.instance == null ? 'none' : 'isolate';

  /// Routes every subsequently created `MapLibreMap` widget through the FFI
  /// backend instead of the method-channel platform views.
  ///
  /// The MapLibre runtime and maps run on a dedicated engine isolate, and
  /// rendering runs on a display-paced native thread, so neither heavy tile
  /// integration nor a display frame ever runs on the UI thread; the first
  /// map creation throws a [StateError] if the engine isolate cannot be
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
  ///
  /// Independent of the per-map `controller.setCustomHeaders`: the engine
  /// merges the two sets (a per-map header wins on a name collision), and
  /// clearing one never clears the other.
  static void setGlobalHttpHeaders(Map<String, String> headers) {
    EngineHost.globalHttpHeaders = Map.unmodifiable(headers);
    EngineHost.instance?.send(
      SetHttpHeadersCommand(headers, scope: HttpHeadersScope.global),
    );
  }

  /// Shows the metric scale bar ornament on every `MapLibreMap` created after
  /// this is set to true (top-left corner, next to the compass's default).
  ///
  /// The scale bar has no maplibre_gl option key (the Android SDK has no
  /// scale bar ornament), so unlike the compass it cannot be toggled through
  /// the widget's options; this process-global switch is the only lever, and
  /// it is off by default. It does not affect maps already on screen.
  static bool get scaleBarEnabled => OrnamentConfig.scaleBarEnabledDefault;
  static set scaleBarEnabled(bool enabled) =>
      OrnamentConfig.scaleBarEnabledDefault = enabled;
}
