# Adding Annotations

The Annotation API lets you place individual interactive markers, circles, lines, and polygons on the map with built-in tap and drag callbacks.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/demo/?example=doc-annotation-markers"
  title="Annotation markers"
  loading="lazy"
></iframe>

Five European landmark markers. Tap any to see its name.

## When to use the Annotation API

Use annotations when you have **fewer than ~50 features** and need individual interactivity (tap callbacks, draggable). For large datasets use [Style Layers](../concepts/annotations-vs-layers.md).

!!! note "Prerequisites"
    Annotations only work once the style has loaded and if their type is part of
    the widget's `annotationOrder`. See [Prerequisites](index.md#prerequisites).

## Add a symbol (icon + text)

`iconImage` names an image the map already has: one from the active style's sprite, or
one you registered with `addImage`. No icon name exists in every style, so registering
your own is the portable choice (see [Where icons come from](#where-icons-come-from)):

```dart
final bytes = await rootBundle.load('assets/markers/pin.png');
await controller.addImage('my-pin', bytes.buffer.asUint8List());

final symbol = await controller.addSymbol(
  const SymbolOptions(
    geometry: LatLng(48.8566, 2.3522),
    iconImage: 'my-pin',        // a name you registered with addImage
    iconSize: 1.0,
    textField: 'Paris',
    textOffset: Offset(0, 1.5),
    textAnchor: 'top',
    textSize: 14,
    textColor: '#1a1a2e',
    textHaloColor: '#ffffff',
    textHaloWidth: 2,
  ),
);
```

!!! note "One font for all symbol annotations"
    Symbol annotations render in **Noto Sans Regular** on Android and iOS, which the
    common public glyph servers all host: a font the server does not have comes back 404
    and hides the whole symbol, icon included. The font belongs to the annotation layer
    rather than to each symbol, so for a different one add a symbol style layer with
    `addSymbolLayer` and set `textFont` there. On web the active style decides.

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
  const SymbolOptions(geometry: LatLng(48.86, 2.35), iconImage: 'my-pin'),
  const SymbolOptions(geometry: LatLng(51.50, -0.13), iconImage: 'my-pin'),
  const SymbolOptions(geometry: LatLng(52.52, 13.40), iconImage: 'my-pin'),
]);
```

## Where icons come from

`iconImage` resolves against the images the map currently has:

- **The active style's sprite**: some styles bundle a named icon set (a style built on
  the Maki icons exposes `marker-15`, `restaurant-15`, …). Those names exist only if
  *that* style includes them, and the MapLibre demo style ships no marker sprite at all.
- **Images you register at runtime** with `addImage`, from `onStyleLoadedCallback`:
  available whatever the style, which is why the examples here do it that way.

A name the map does not have renders nothing and only logs *"image … could not be
loaded"*, so it fails quietly.

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
