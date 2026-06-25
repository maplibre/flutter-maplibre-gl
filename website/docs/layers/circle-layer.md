# Circle Layer

A circle layer renders filled circles at point locations. It's ideal for data visualization: earthquakes sized by magnitude, events colored by category, density indicators.

<iframe
  class="example-iframe"
  src="https://maplibre.github.io/flutter-maplibre-gl/?example=doc-circle-layer"
  title="Circle layer"
  loading="lazy"
></iframe>

Simulated earthquake data. Circle size and color driven by the `magnitude` property using `interpolate` expressions.

## Basic setup

```dart
await controller.addGeoJsonSource('points', featureCollection);

await controller.addCircleLayer(
  'points',
  'points-layer',
  const CircleLayerProperties(
    circleRadius: 8,
    circleColor: '#296CA8',
    circleOpacity: 0.8,
    circleStrokeWidth: 2,
    circleStrokeColor: '#ffffff',
  ),
);
```

## Data-driven radius and color

This is the most common pattern: circle size and color both driven by a numeric property:

```dart
CircleLayerProperties(
  circleRadius: [
    Expressions.interpolate, ['linear'],
    [Expressions.get, 'magnitude'],
    2.0, 4.0,    // magnitude 2 -> 4px radius
    5.0, 14.0,
    8.0, 40.0,   // magnitude 8 -> 40px radius
  ],
  circleColor: [
    Expressions.interpolate, ['linear'],
    [Expressions.get, 'magnitude'],
    2.0, '#4CAF50',   // green
    5.0, '#FF9800',   // orange
    8.0, '#F44336',   // red
  ],
  circleOpacity: 0.75,
  circleStrokeWidth: 1.5,
  circleStrokeColor: '#ffffff',
)
```

## Zoom-responsive circles

```dart
CircleLayerProperties(
  circleRadius: [
    Expressions.interpolate, ['linear'],
    [Expressions.zoom],
    5,  3.0,   // zoom 5  -> 3px
    12, 12.0,  // zoom 12 -> 12px
  ],
)
```

## Handle taps via `queryRenderedFeatures`

Circle layers don't have built-in tap callbacks. Use `queryRenderedFeatures` instead:

```dart
MapLibreMap(
  onMapClick: (point, latLng) async {
    final features = await controller.queryRenderedFeatures(
      point,
      ['points-layer'],  // layer ids to query
      null,              // filter (optional)
    );
    if (features.isNotEmpty) {
      final props = features.first['properties'] as Map;
      print('Tapped: ${props['name']}');
    }
  },
)
```

## Key `CircleLayerProperties` fields

| Property | Description |
|---|---|
| `circleRadius` | Radius in pixels (or expression) |
| `circleColor` | Fill color (or expression) |
| `circleOpacity` | Fill opacity 0-1 |
| `circleStrokeWidth` | Outline width |
| `circleStrokeColor` | Outline color |
| `circleBlur` | Feather the edges |
| `circlePitchAlignment` | `map` or `viewport` (3D perspective) |
| `circleTranslate` | [x, y] pixel offset |

## Key APIs

- [`MapLibreMapController.addCircleLayer()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/addCircleLayer.html)
- [`CircleLayerProperties`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/CircleLayerProperties-class.html)
- [Expressions](../advanced/expressions.md)
