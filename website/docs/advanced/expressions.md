# Data-Driven Expressions

Expressions are MapLibre's way of making the map respond to your data. Instead of hardcoding a circle color, you write an expression that reads each feature's `magnitude` property and maps it to a color. The GPU evaluates this per-feature at render time, efficiently, for any number of features.

!!! note "Style Layers only"
    Expressions only work with [Style Layers](../concepts/annotations-vs-layers.md) (`addSymbolLayer`, `addCircleLayer`, etc.). The Annotation API (`addSymbol`, `addCircle`) uses fixed values per feature.

<iframe
  class="example-iframe"
  src="https://maplibre.github.io/flutter-maplibre-gl/?example=doc-expressions"
  title="Data-driven expressions"
  loading="lazy"
></iframe>

Countries colored by continent (`match` expression) and opacity driven by GDP per capita (`interpolate` expression).

## How expressions work

An expression is a JSON array where the first element is the operator name and the rest are arguments:

```
["operator", arg1, arg2, ...]
```

In Dart, you write them as `List<dynamic>` using `Expressions` constants for operator names:

```dart
// Equivalent to the style spec's ["get", "name"]
[Expressions.get, 'name']
```

## `get`: read a feature property

The simplest expression: read a property from the feature being rendered.

```dart
SymbolLayerProperties(
  // Show the feature's 'name' property as a label
  textField: [Expressions.get, 'name'],

  // Use the feature's 'icon' property as the icon image name
  iconImage: [Expressions.get, 'icon'],
)
```

Your GeoJSON feature must have matching properties:

```dart
{
  'type': 'Feature',
  'properties': {'name': 'Paris', 'icon': 'city-marker'},
  'geometry': {'type': 'Point', 'coordinates': [2.35, 48.86]},
}
```

## `interpolate`: map a number to a value range

Smoothly maps a numeric input to an output range (numbers, colors, arrays).

```dart
CircleLayerProperties(
  // Circle radius scales from 4px (magnitude 2) to 40px (magnitude 8)
  circleRadius: [
    Expressions.interpolate,
    ['linear'],             // interpolation type: linear, exponential, cubic-bezier
    [Expressions.get, 'magnitude'],  // input expression
    2.0, 4.0,   // input → output stop
    5.0, 14.0,
    8.0, 40.0,
  ],

  // Circle color interpolated from green to red
  circleColor: [
    Expressions.interpolate,
    ['linear'],
    [Expressions.get, 'magnitude'],
    2.0, '#4CAF50',   // green for small
    5.0, '#FF9800',   // orange for medium
    8.0, '#F44336',   // red for large
  ],
)
```

You can also interpolate by zoom level using `[Expressions.zoom]` as the input:

```dart
// Line width grows as you zoom in
lineWidth: [
  Expressions.interpolate,
  ['linear'],
  [Expressions.zoom],
  8,  1.0,
  14, 6.0,
  18, 12.0,
],
```

## `match`: categorical mapping

Maps discrete string or number values to outputs. Like a `switch` statement.

```dart
CircleLayerProperties(
  // Color by category string
  circleColor: [
    Expressions.match,
    [Expressions.get, 'category'],  // input
    'restaurant', '#E74C3C',
    'park',       '#2ECC71',
    'museum',     '#3498DB',
    'hotel',      '#F39C12',
    '#95A5A6',   // default (last argument, no key)
  ],
)
```

## `case`: conditional logic

Evaluates boolean conditions in order, returns the first matching output.

```dart
SymbolLayerProperties(
  // Show a different icon based on a boolean property
  iconImage: [
    Expressions.caseExpression,  // 'case' is a reserved word in Dart
    [Expressions.get, 'is_verified'], 'verified-marker',
    [Expressions.get, 'is_premium'], 'premium-marker',
    'default-marker',  // fallback
  ],
)
```

## `step`: stepped thresholds

Like `interpolate` but with abrupt jumps instead of smooth transitions. Useful for cluster bubble sizes.

```dart
CircleLayerProperties(
  circleRadius: [
    Expressions.step,
    [Expressions.get, 'point_count'],  // input
    16,       // output for input < 10
    10,  24,  // output for input >= 10
    50,  32,  // output for input >= 50
    100, 42,  // output for input >= 100
  ],
)
```

## Combining expressions

Expressions compose. Any argument can itself be an expression:

```dart
// Circle size interpolated by zoom, but capped at 20px by a max() expression
circleRadius: [
  'min',
  [
    Expressions.interpolate, ['linear'], [Expressions.zoom],
    0, 2,
    12, 30,
  ],
  20,  // max cap
],
```

## Full Dart example

```dart
await controller.addGeoJsonSource('earthquakes', geojsonData);

await controller.addCircleLayer(
  'earthquakes',
  'earthquake-circles',
  CircleLayerProperties(
    // Size driven by magnitude
    circleRadius: [
      Expressions.interpolate,
      ['linear'],
      [Expressions.get, 'magnitude'],
      2.0, 4.0,
      6.0, 20.0,
      9.0, 50.0,
    ],
    // Color driven by magnitude
    circleColor: [
      Expressions.interpolate,
      ['linear'],
      [Expressions.get, 'magnitude'],
      2.0, '#27AE60',
      5.0, '#F39C12',
      7.0, '#E74C3C',
    ],
    // Opacity driven by zoom (fade out at low zoom)
    circleOpacity: [
      Expressions.interpolate,
      ['linear'],
      [Expressions.zoom],
      3, 0.4,
      8, 0.9,
    ],
    circleStrokeWidth: 1.0,
    circleStrokeColor: '#ffffff',
  ),
);
```

## Key `Expressions` constants

| Constant | Style spec equivalent | Use case |
|---|---|---|
| `Expressions.get` | `"get"` | Read feature property |
| `Expressions.zoom` | `"zoom"` | Current zoom level |
| `Expressions.interpolate` | `"interpolate"` | Smooth range mapping |
| `Expressions.step` | `"step"` | Stepped thresholds |
| `Expressions.match` | `"match"` | Categorical switch |
| `Expressions.caseExpression` | `"case"` | Boolean conditions |
| `Expressions.heatmapDensity` | `"heatmap-density"` | Heatmap layer input |
| `Expressions.lineProgress` | `"line-progress"` | Line gradient position |
| `Expressions.has` | `"has"` | Check property exists |
| `Expressions.notHasExpression` | `"!"` + `"has"` | Negate |

For the full expression reference, see the [MapLibre Style Spec](https://maplibre.org/maplibre-style-spec/expressions/).
