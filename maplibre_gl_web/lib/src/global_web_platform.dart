@JS()
library;

import 'dart:js_interop';

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/src/js_loader.dart';

/// Calls `maplibregl.prewarm()` to pre-create the Web Worker pool.
@JS('maplibregl.prewarm')
external void _maplibrePrewarm();

/// The web [MapLibreGlobalPlatform]: plugin-global calls that must work
/// before any map widget, and therefore any [MapLibrePlatform] instance,
/// exists.
///
/// Installed by `MapLibreMapPlugin.registerWith`, which the generated web
/// bootstrap runs before the app's `main()`, so `preWarm()` and
/// `ensureWebLibraryLoaded()` reach this class even as the first statement of
/// `main()`.
class MapLibreGlobalWeb extends MapLibreGlobalPlatform {
  @override
  Future<void> preWarm() async {
    // On web the expensive part is fetching maplibre-gl-js itself; the worker
    // pool is cheap by comparison. Starting the download during app start-up
    // instead of at the first map build is what makes preWarm() earn its name
    // here.
    await MapLibreJsLoader.ensureLoaded();
    _maplibrePrewarm();
  }

  @override
  Future<void> ensureLibraryLoaded() => MapLibreJsLoader.ensureLoaded();
}
