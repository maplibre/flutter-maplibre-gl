# Fill Layer

A fill layer renders polygons from a GeoJSON source. Use it for choropleth maps, highlighted regions, administrative boundaries, and any area-based visualization.

<iframe
  class="example-iframe"
  src="https://maplibre.github.io/flutter-maplibre-gl/?example=doc-fill-layer"
  title="Fill layer"
  loading="lazy"
></iframe>

Four European regions, each with a data-driven fill color from a `color` property, plus a line layer for the outline.

## Basic setup

```dart
await controller.addGeoJsonSource('regions', polygonFeatureCollection);

await controller.addFillLayer(
  'regions',
  'regions-fill',
  FillLayerProperties(
    fillColor: '#296CA8',
    fillOpacity: 0.4,
    fillOutlineColor: '#1a4a7a',
  ),
);
```

## Data-driven fill color

Drive color from a feature property:

```dart
FillLayerProperties(
  fillColor: [Expressions.get, 'color'],   // read hex string from property
  fillOpacity: 0.35,
)
```

Or use `match` to map category strings to colors:

```dart
FillLayerProperties(
  fillColor: [
    Expressions.match,
    [Expressions.get, 'continent'],
    'Europe', '#2ECC71',
    'Americas', '#3498DB',
    'Asia', '#E74C3C',
    '#95A5A6',  // default
  ],
  fillOpacity: [
    Expressions.interpolate, ['linear'],
    [Expressions.get, 'gdp_per_capita'],
    1000,  0.2,
    60000, 0.75,
  ],
)
```

## Separate outline layer

`fillOutlineColor` only works for simple outlines. For full control (width, dash, cap), add a `lineLayer` on the same source:

```dart
// Fill
await controller.addFillLayer(
  'regions', 'regions-fill',
  const FillLayerProperties(fillColor: '#296CA8', fillOpacity: 0.3),
);

// Outline with full line control
await controller.addLineLayer(
  'regions', 'regions-outline',
  const LineLayerProperties(
    lineColor: '#1a4a7a',
    lineWidth: 2.0,
    lineOpacity: 0.9,
  ),
);
```

## GeoJSON polygon format

```dart
{
  'type': 'Feature',
  'properties': {'name': 'Zone A', 'color': '#3498DB'},
  'geometry': {
    'type': 'Polygon',
    'coordinates': [
      // Outer ring: first and last point must be identical
      [
        [2.0, 48.5],
        [2.5, 48.5],
        [2.5, 49.0],
        [2.0, 49.0],
        [2.0, 48.5], // close
      ],
      // Optional: inner ring (hole)
      [
        [2.1, 48.6],
        [2.4, 48.6],
        [2.4, 48.9],
        [2.1, 48.9],
        [2.1, 48.6],
      ],
    ],
  },
}
```

## Key `FillLayerProperties` fields

| Property | Description |
|---|---|
| `fillColor` | Fill color (or expression) |
| `fillOpacity` | Fill opacity 0-1 |
| `fillOutlineColor` | Simple border color (1px, no width control) |
| `fillPattern` | Repeat a registered image as a fill pattern |
| `fillTranslate` | [x, y] pixel offset |
| `fillAntialias` | Smooth edges (default true) |

## Key APIs

- [`MapLibreMapController.addFillLayer()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/addFillLayer.html)
- [`FillLayerProperties`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/FillLayerProperties-class.html)
- [Expressions](../advanced/expressions.md)
