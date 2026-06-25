# Heatmap Layer

A heatmap visualizes the density or intensity of point data as a smooth color gradient. It's the right choice when you have many overlapping points and want to show concentration rather than individual features.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/?example=doc-heatmap"
  title="Heatmap layer"
  loading="lazy"
></iframe>

Simulated event density around major world cities. Color ramps from blue (sparse) to red (dense). Zoom in to see individual points emerge.

## When to use a heatmap

- You have hundreds to millions of point features
- Individual points overlap and become unreadable
- You want to show geographic density (crime, traffic, sales, weather)
- You want the map to transition from heatmap at low zoom to individual points at high zoom

## Basic setup

```dart
// 1. Add a GeoJSON source with point features
await controller.addGeoJsonSource('events', {
  'type': 'FeatureCollection',
  'features': myPointFeatures,
});

// 2. Add the heatmap layer
await controller.addHeatmapLayer(
  'events',
  'events-heat',
  HeatmapLayerProperties(
    heatmapRadius: 30,       // pixel radius per point
    heatmapOpacity: 0.8,
  ),
);
```

## Color ramp

The `heatmapColor` expression maps `heatmap-density` (0 to 1) to colors. Always start at `rgba(..., 0)` for the lowest density so sparse areas are transparent:

```dart
heatmapColor: [
  Expressions.interpolate,
  ['linear'],
  [Expressions.heatmapDensity],
  0.0, 'rgba(33, 102, 172, 0)',     // transparent
  0.2, 'rgb(103, 169, 207)',         // light blue
  0.4, 'rgb(209, 229, 240)',         // very light
  0.6, 'rgb(253, 219, 199)',         // light orange
  0.8, 'rgb(239, 138,  98)',         // orange
  1.0, 'rgb(178,  24,  43)',         // red
],
```

## Weight per point

If some points are more significant than others (e.g. earthquake magnitude, sales value), use `heatmapWeight` to drive intensity from a property:

```dart
heatmapWeight: [
  Expressions.interpolate,
  ['linear'],
  [Expressions.get, 'magnitude'],
  0, 0,    // magnitude 0 → no weight
  6, 1,    // magnitude 6 → full weight
],
```

## Zoom-responsive radius and intensity

Make the heatmap adapt as users zoom in:

```dart
HeatmapLayerProperties(
  heatmapRadius: [
    Expressions.interpolate,
    ['linear'],
    [Expressions.zoom],
    0,  2,    // tiny radius at world zoom
    9,  20,   // larger radius at city zoom
  ],
  heatmapIntensity: [
    Expressions.interpolate,
    ['linear'],
    [Expressions.zoom],
    0, 1,
    9, 3,
  ],
  heatmapOpacity: [
    Expressions.interpolate,
    ['linear'],
    [Expressions.zoom],
    7, 1.0,   // fully visible at zoom 7
    9, 0.5,   // fade out at zoom 9 (circles take over)
  ],
),
```

## Transition from heatmap to individual points

A common pattern is to show the heatmap at low zoom and individual circles at high zoom, creating a smooth transition:

```dart
// Heatmap: visible at low zoom, fades out
await controller.addHeatmapLayer('events', 'events-heat',
  HeatmapLayerProperties(
    heatmapOpacity: [
      Expressions.interpolate, ['linear'], [Expressions.zoom],
      7, 1.0,
      9, 0.0,  // fully transparent at zoom 9
    ],
  ),
  minzoom: 0,
  maxzoom: 9,
);

// Circles: invisible at low zoom, fade in
await controller.addCircleLayer('events', 'events-circles',
  CircleLayerProperties(
    circleOpacity: [
      Expressions.interpolate, ['linear'], [Expressions.zoom],
      7, 0.0,  // transparent at zoom 7
      9, 0.8,  // visible at zoom 9
    ],
    circleRadius: 4,
    circleColor: '#E74C3C',
  ),
  minzoom: 7,
);
```

## Key APIs

- [`MapLibreMapController.addHeatmapLayer()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/addHeatmapLayer.html)
- [`HeatmapLayerProperties`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/HeatmapLayerProperties-class.html)
- [Expressions](../advanced/expressions.md): for data-driven weight and color
