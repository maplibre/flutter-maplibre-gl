import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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

  /// Builds a target that carries only the fields it is given.
  ///
  /// An absent field and a null one are different things here: maplibre-gl-js
  /// reads a missing `id` as "every feature of this source" but a null one as
  /// an id to look up, so passing null where the caller meant "not set" turns
  /// a source-wide remove into a silent no-op. Dart cannot tell the two apart,
  /// which is why every call site should come through this instead of building
  /// the literal itself.
  factory FeatureIdentifierJsImpl.of({
    required String source,
    JSAny? id,
    String? sourceLayer,
  }) {
    final target = JSObject()..setProperty('source'.toJS, source.toJS);
    if (id != null) target.setProperty('id'.toJS, id);
    if (sourceLayer != null) {
      target.setProperty('sourceLayer'.toJS, sourceLayer.toJS);
    }
    return FeatureIdentifierJsImpl._(target);
  }
}
