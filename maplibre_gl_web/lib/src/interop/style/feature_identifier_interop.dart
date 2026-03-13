import 'dart:js_interop';

/// Identifies a feature for feature state operations.
/// Matches the MapLibre GL JS FeatureIdentifier type.
///
/// @see https://maplibre.org/maplibre-gl-js/docs/API/type-aliases/FeatureIdentifier/
extension type FeatureIdentifierJsImpl._(JSObject _) implements JSObject {
  /// The id of the vector or GeoJSON source.
  external String get source;

  /// Unique id of the feature. For GeoJSON sources, the feature's id must be
  /// an integer or a string that can be cast to an integer.
  external JSAny? get id;

  /// For vector tile sources, the source layer name.
  /// Required for vector tile sources.
  external String? get sourceLayer;

  external factory FeatureIdentifierJsImpl({
    required String source,
    JSAny? id,
    String? sourceLayer,
  });
}
