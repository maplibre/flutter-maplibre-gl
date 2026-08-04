part of '../maplibre_gl_web.dart';

class MapLibreMapPlugin {
  /// Registers this class as the default instance of [MapLibrePlatform].
  static void registerWith(Registrar registrar) {
    MapLibrePlatform.createInstance = () => MapLibreMapController();
    // Plugin-global calls that run before any map widget exists. The
    // generated web bootstrap invokes registerWith before the app's main(),
    // so preWarm() and ensureWebLibraryLoaded() reach the web implementation
    // even as the first statement of main().
    MapLibreGlobalPlatform.instance = MapLibreGlobalWeb();
  }
}
