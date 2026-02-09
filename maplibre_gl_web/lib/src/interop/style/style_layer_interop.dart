@JS('maplibregl')
library;

import 'dart:js_interop';

/// Represents a style layer object from MapLibre
/// See https://maplibre.org/maplibre-gl-js/docs/API/interfaces/StyleLayer/
extension type StyleLayerJsImpl._(JSObject _) implements JSObject {
  /// The layer's unique ID
  external String get id;

  /// The layer's type. One of: 'fill', 'line', 'symbol', 'circle', 'heatmap',
  /// 'fill-extrusion', 'raster', 'hillshade', 'background', 'sky'
  external String get type;

  /// Arbitrary properties useful to track with the layer, but do not influence rendering.
  /// Properties should be prefixed to avoid collisions, like 'mapbox:'.
  external JSObject? get metadata;

  /// Name of a source description to be used for this layer.
  /// Required for all layer types except background.
  external String? get source;

  /// Layer to use from a vector tile source. Required for vector tile sources;
  /// prohibited for all other source types, including GeoJSON sources.
  external String? get sourceLayer;

  /// The minimum zoom level for the layer. At zoom levels less than the minzoom,
  /// the layer will be hidden. A number between 0 and 24 inclusive.
  external num? get minzoom;

  /// The maximum zoom level for the layer. At zoom levels equal to or greater than
  /// the maxzoom, the layer will be hidden. A number between 0 and 24 inclusive.
  external num? get maxzoom;

  /// A expression specifying conditions on source features.
  /// Only features that match the filter are displayed.
  external JSAny? get filter;

  /// Layout properties for the layer.
  external JSObject? get layout;

  /// Default paint properties for this layer.
  external JSObject? get paint;
}
