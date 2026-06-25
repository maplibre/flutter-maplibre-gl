# Symbol Layer

A symbol layer renders icons, text labels, or both at point locations from a GeoJSON source. It's the style-layer equivalent of `addSymbol()`, but scales to any number of features and supports data-driven styling.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/demo/?example=doc-symbol-layer"
  title="Symbol layer"
  loading="lazy"
></iframe>

Ten European cities with custom marker icons and text labels, rendered from a GeoJSON source.

## Basic setup

```dart
// 1. Register a custom icon
await addImageFromAsset(controller, 'my-marker', 'assets/marker.png');

// 2. Add a GeoJSON source with point features
await controller.addGeoJsonSource('cities', {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'properties': {'name': 'Paris'},
      'geometry': {'type': 'Point', 'coordinates': [2.3522, 48.8566]},
    },
  ],
});

// 3. Add a symbol layer referencing the source
await controller.addSymbolLayer(
  'cities',
  'cities-layer',
  const SymbolLayerProperties(
    iconImage: 'my-marker',
    iconSize: 1.0,
    iconAnchor: 'bottom',
    iconAllowOverlap: true,
    textField: [Expressions.get, 'name'],
    textSize: 13,
    textOffset: [0, 1.2],
    textAnchor: 'top',
    textHaloColor: '#ffffff',
    textHaloWidth: 2,
  ),
);
```

## Data-driven icon and text

```dart
SymbolLayerProperties(
  // Different icon per category
  iconImage: [
    Expressions.match,
    [Expressions.get, 'type'],
    'restaurant', 'restaurant-icon',
    'hotel', 'hotel-icon',
    'default-icon', // fallback
  ],

  // Text from a property
  textField: [Expressions.get, 'name'],

  // Text size driven by a rank property
  textSize: [
    Expressions.interpolate, ['linear'],
    [Expressions.get, 'rank'],
    1, 16.0,   // rank 1 -> 16px
    5, 10.0,   // rank 5 -> 10px
  ],
)
```

## Collision behavior

Symbols automatically avoid each other. Control this:

```dart
SymbolLayerProperties(
  iconAllowOverlap: true,        // icons always show, even if overlapping
  iconIgnorePlacement: false,    // icons consider others' space
  textAllowOverlap: false,       // labels hide if they overlap
  symbolAvoidEdges: true,        // keep symbols away from map edges
)
```

## Text layout

```dart
SymbolLayerProperties(
  textField: [Expressions.get, 'name'],
  textSize: 13,
  textAnchor: 'top',             // relative to the symbol point
  textJustify: 'center',         // left, center, right
  textOffset: [0, 1.5],          // [x, y] in ems
  textRotate: 0,                 // degrees
  textMaxWidth: 8,               // wrap at 8 ems
  textLetterSpacing: 0.05,
)
```

## Update layer properties

```dart
await controller.setLayerProperties(
  'cities-layer',
  const SymbolLayerProperties(
    textSize: 16,
    iconSize: 1.5,
  ),
);
```

## Filter by property

```dart
await controller.addSymbolLayer(
  'cities', 'major-cities',
  SymbolLayerProperties(...),
  filter: ['>=', ['get', 'population'], 1000000], // only cities with pop >= 1M
);
```

## Key `SymbolLayerProperties` fields

| Property | Description |
|---|---|
| `iconImage` | Icon name (registered via `addImage`) |
| `iconSize` | Scale factor (1.0 = original) |
| `iconAnchor` | Which part of icon touches the point |
| `iconOffset` | [x, y] pixel offset |
| `iconColor` | Tint color (SDF icons only) |
| `iconAllowOverlap` | Show even if overlapping other icons |
| `textField` | Label text (string or expression) |
| `textSize` | Font size in pixels |
| `textColor` | Label color |
| `textHaloColor` / `textHaloWidth` | Outline around text |
| `textAnchor` | Anchor relative to point |
| `textOffset` | [x, y] offset in ems |
| `symbolPlacement` | `point` or `line` |

## Key APIs

- [`MapLibreMapController.addSymbolLayer()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/addSymbolLayer.html)
- [`SymbolLayerProperties`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/SymbolLayerProperties-class.html)
- [Expressions](../advanced/expressions.md)
- [GeoJSON Source](geojson-source.md)
