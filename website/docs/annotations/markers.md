# Markers

The Annotation API lets you place individual interactive markers, circles, lines, and polygons on the map with built-in tap and drag callbacks.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/?example=doc-annotation-markers"
  title="Annotation markers"
  loading="lazy"
></iframe>

Five European landmark markers. Tap any to see its name.

## When to use the Annotation API

Use annotations when you have **fewer than ~50 features** and need individual interactivity (tap callbacks, draggable). For large datasets use [Style Layers](../concepts/annotations-vs-layers.md).

## Add a symbol (icon + text)

```dart
final symbol = await controller.addSymbol(
  const SymbolOptions(
    geometry: LatLng(48.8566, 2.3522),
    iconImage: 'marker-15',     // built-in MapLibre icon
    iconSize: 1.5,
    iconColor: '#E74C3C',
    textField: 'Paris',
    textOffset: Offset(0, 1.5),
    textAnchor: 'top',
    textSize: 14,
    textHaloColor: '#ffffff',
    textHaloWidth: 2,
  ),
);
```

## Tap callback

```dart
controller.onSymbolTapped.add((Symbol symbol) {
  print('Tapped: ${symbol.options.textField}');
});
```

## Update a symbol

```dart
await controller.updateSymbol(
  symbol,
  const SymbolOptions(
    iconColor: '#2ECC71',    // change color
    textField: 'Paris, FR', // change label
  ),
);
```

## Remove a symbol

```dart
await controller.removeSymbol(symbol);
await controller.clearSymbols(); // remove all
```

## Add multiple symbols at once

```dart
final symbols = await controller.addSymbols([
  const SymbolOptions(geometry: LatLng(48.86, 2.35), iconImage: 'marker-15'),
  const SymbolOptions(geometry: LatLng(51.50, -0.13), iconImage: 'marker-15'),
  const SymbolOptions(geometry: LatLng(52.52, 13.40), iconImage: 'marker-15'),
]);
```

## Built-in icon names

MapLibre ships a set of built-in icons from the Maki icon set. Common ones:

| Icon name | Use |
|---|---|
| `marker-15` | Simple teardrop marker |
| `circle-15` | Filled circle |
| `star-15` | Star shape |
| `restaurant-15` | Fork and knife |
| `lodging-15` | Bed icon |
| `hospital-15` | Medical cross |
| `airport-15` | Airplane |

### Custom image markers

To use your own image instead of a built-in Maki icon, register it once with `addImage()` (in `onStyleLoadedCallback`), then reference it by name as the `iconImage`:

```dart
final bytes = await rootBundle.load('assets/markers/pin.png');
await controller.addImage('my-pin', bytes.buffer.asUint8List());

await controller.addSymbol(
  const SymbolOptions(
    geometry: LatLng(48.8566, 2.3522),
    iconImage: 'my-pin',
    iconSize: 1.0,
  ),
);
```

## Other annotation types

```dart
// Circle
final circle = await controller.addCircle(
  CircleOptions(
    geometry: const LatLng(48.86, 2.35),
    circleRadius: 20,
    circleColor: '#296CA8',
    circleOpacity: 0.5,
  ),
);
controller.onCircleTapped.add((Circle c) { ... });

// Line
final line = await controller.addLine(
  LineOptions(
    geometry: const [LatLng(48.86, 2.35), LatLng(51.50, -0.13)],
    lineColor: '#E74C3C',
    lineWidth: 3,
  ),
);

// Fill (polygon)
final fill = await controller.addFill(
  FillOptions(
    geometry: const [
      [LatLng(48.7, 2.2), LatLng(49.0, 2.2), LatLng(49.0, 2.5), LatLng(48.7, 2.5)],
    ],
    fillColor: '#296CA8',
    fillOpacity: 0.3,
  ),
);
```

## Key APIs

- [`MapLibreMapController.addSymbol()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/addSymbol.html)
- [`SymbolOptions`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/SymbolOptions-class.html)
- [`MapLibreMapController.onSymbolTapped`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/onSymbolTapped.html)
