part of '../maplibre_gl_web.dart';

class MapLibreMapPlugin {
  /// Registers this class as the default instance of [MapLibrePlatform].
  static void registerWith(Registrar registrar) {
    MapLibrePlatform.createInstance = () => MapLibreMapController();
  }
}
