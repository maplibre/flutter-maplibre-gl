# Line Layer

A line layer renders LineString and Polygon geometries as stroked paths. Use it for routes, borders, paths, rivers, and any linear feature.

<iframe
  class="example-iframe"
  src="https://maplibre.github.io/flutter-maplibre-gl/?example=doc-line-layer"
  title="Line layer"
  loading="lazy"
></iframe>

A simplified Trans-Siberian Railway route rendered as a dashed line with a dark casing.

## Basic setup

```dart
await controller.addGeoJsonSource('route', {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'properties': {},
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [2.3522, 48.8566],   // Paris  [lng, lat]
          [13.4050, 52.5200],  // Berlin
        ],
      },
    }
  ],
});

await controller.addLineLayer(
  'route',
  'route-layer',
  const LineLayerProperties(
    lineColor: '#E74C3C',
    lineWidth: 3,
    lineCap: 'round',
    lineJoin: 'round',
  ),
);
```

## Casing (outline) pattern

Add a slightly wider dark line underneath for a casing effect:

```dart
// Casing (drawn first, wider)
await controller.addLineLayer(
  'route', 'route-casing',
  const LineLayerProperties(
    lineColor: '#1a1a2e',
    lineWidth: 6,
    lineCap: 'round',
    lineJoin: 'round',
  ),
);

// Main line (drawn on top)
await controller.addLineLayer(
  'route', 'route-main',
  const LineLayerProperties(
    lineColor: '#E74C3C',
    lineWidth: 3.5,
    lineCap: 'round',
    lineJoin: 'round',
    lineDasharray: [2, 1.5],  // dashed
  ),
);
```

## Zoom-responsive width

```dart
LineLayerProperties(
  lineWidth: [
    Expressions.interpolate, ['linear'],
    [Expressions.zoom],
    8,  1.0,    // thin at low zoom
    14, 6.0,    // thick at street zoom
    18, 12.0,
  ],
)
```

## Dashes

```dart
LineLayerProperties(
  lineDasharray: [2, 2],     // 2 units on, 2 units off
  lineCap: 'butt',           // use 'butt' cap with dashes (not 'round')
)
```

## GeoJSON geometry types that work with line layers

- `LineString`: open path
- `MultiLineString`: multiple paths in one feature
- `Polygon` and `MultiPolygon`: the outer rings are stroked (useful for outlines)

## Key `LineLayerProperties` fields

| Property | Description |
|---|---|
| `lineColor` | Stroke color |
| `lineWidth` | Width in pixels (or expression) |
| `lineOpacity` | Opacity 0-1 |
| `lineCap` | `butt`, `round`, `square` |
| `lineJoin` | `bevel`, `round`, `miter` |
| `lineDasharray` | `[on, off, ...]` dash pattern |
| `lineBlur` | Feather the edges |
| `lineOffset` | Perpendicular offset (positive = left side) |
| `lineGapWidth` | Inner gap for a double-line effect |
| `linePattern` | Repeat a registered image along the line |
| `lineTranslate` | [x, y] pixel shift |

## Key APIs

- [`MapLibreMapController.addLineLayer()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/addLineLayer.html)
- [`LineLayerProperties`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/LineLayerProperties-class.html)
- [Expressions](../advanced/expressions.md)
