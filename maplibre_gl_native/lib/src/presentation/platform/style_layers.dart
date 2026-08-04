/// Style layer kinds the maplibre_gl API can add.
///
/// The style-spec `type` string lives here once, instead of being repeated as
/// a literal at each `addXLayer` call site.
enum StyleLayerType {
  symbol,
  line,
  circle,
  fill,
  fillExtrusion('fill-extrusion'),
  raster,
  hillshade,
  heatmap
  ;

  const StyleLayerType([this._specName]);

  final String? _specName;

  /// The style-spec `type` value; the enum name unless it differs.
  String get specName => _specName ?? name;
}

/// Style-spec layout properties, used to split the flat property maps of the
/// existing maplibre_gl API into the paint/layout objects that raw style
/// layer JSON requires. Everything not listed here is a paint property.
///
/// Hand-maintained against the style spec; generating it from the spec in
/// `scripts/` would remove the maintenance burden if it ever grows stale.
const Set<String> _layoutPropertyKeys = {
  'visibility',
  // symbol
  'symbol-placement', 'symbol-spacing', 'symbol-avoid-edges',
  'symbol-sort-key', 'symbol-z-order',
  'icon-allow-overlap', 'icon-overlap', 'icon-ignore-placement',
  'icon-optional', 'icon-rotation-alignment', 'icon-size', 'icon-text-fit',
  'icon-text-fit-padding', 'icon-image', 'icon-rotate', 'icon-padding',
  'icon-keep-upright', 'icon-offset', 'icon-anchor', 'icon-pitch-alignment',
  'text-pitch-alignment', 'text-rotation-alignment', 'text-field',
  'text-font', 'text-size', 'text-max-width', 'text-line-height',
  'text-letter-spacing', 'text-justify', 'text-radial-offset',
  'text-variable-anchor', 'text-variable-anchor-offset', 'text-anchor',
  'text-max-angle', 'text-writing-mode', 'text-rotate', 'text-padding',
  'text-keep-upright', 'text-transform', 'text-offset', 'text-allow-overlap',
  'text-overlap', 'text-ignore-placement', 'text-optional',
  // line
  'line-cap', 'line-join', 'line-miter-limit', 'line-round-limit',
  'line-sort-key',
  // fill / circle
  'fill-sort-key', 'circle-sort-key',
};

/// Builds the style-spec JSON of one layer from the flat argument shape the
/// maplibre_gl `addXLayer` methods use.
///
/// The only difference between those methods is [type], which is why they all
/// funnel through here.
Map<String, dynamic> styleLayerJson({
  required StyleLayerType type,
  required String sourceId,
  required String layerId,
  required Map<String, dynamic> properties,
  String? sourceLayer,
  double? minzoom,
  double? maxzoom,
  Object? filter,
}) {
  final layout = <String, dynamic>{};
  final paint = <String, dynamic>{};
  for (final entry in properties.entries) {
    (_layoutPropertyKeys.contains(entry.key) ? layout : paint)[entry.key] =
        entry.value;
  }
  return <String, dynamic>{
    'id': layerId,
    'type': type.specName,
    'source': sourceId,
    'source-layer': ?sourceLayer,
    'minzoom': ?minzoom,
    'maxzoom': ?maxzoom,
    'filter': ?filter,
    if (layout.isNotEmpty) 'layout': layout,
    if (paint.isNotEmpty) 'paint': paint,
  };
}
