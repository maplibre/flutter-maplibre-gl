part of '../maplibre_gl.dart';

@Deprecated('MaplibreStyles was renamed to MapLibreStyles.')
typedef MaplibreStyles = MapLibreStyles;

/// MapLibre styles used mostly for demonstration.
abstract class MapLibreStyles {
  /// A very simple MapLibre demo style that shows only countries with their
  /// boundaries.
  static const String demo = "https://demotiles.maplibre.org/style.json";
}
