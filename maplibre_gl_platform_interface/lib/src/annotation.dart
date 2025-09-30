part of '../maplibre_gl_platform_interface.dart';

/// Base interface for all data-driven map annotations drawn via
/// style layers (symbols, lines, fills, circles, etc.).
///
/// Implementations should be immutable value objects that describe the
/// geometry & styling properties needed for rendering. They are serialized
/// into GeoJSON features (see [toGeoJson]) and passed across the platform
/// boundary to the native/web MapLibre engines.
///
/// Typical workflow:
/// 1. Create a concrete annotation (e.g. [Symbol], [Line], [Fill], [Circle]).
/// 2. Add it through the corresponding manager (e.g. `SymbolManager.add`).
/// 3. When interaction (drag) occurs or you update the model, the manager
/// re-emits the updated GeoJSON using [toGeoJson].
abstract class Annotation {
  /// Unique stable identifier within its manager.
  String get id;

  /// Converts this annotation into a GeoJSON Feature (WGS84 lon/lat)
  /// map understood by the underlying MapLibre style source.
  Map<String, dynamic> toGeoJson();

  /// Moves the annotation by the given geographic delta.
  void translate(LatLng delta);
}
