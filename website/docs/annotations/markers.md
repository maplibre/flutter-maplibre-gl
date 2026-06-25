# Markers

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

## Add a symbol (icon + text)

`iconImage` references an image **from the active style's sprite**, or one you
registered yourself with `addImage` / `addImageFromAsset`. There are no icons
that exist in every style, so register your own first (see
[Custom image markers](#custom-image-markers) below) and reference it by name:

```dart
await addImageFromAsset(controller, 'my-pin', 'assets/markers/pin.png');

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

!!! warning "Icons are style-dependent"
    `iconImage` must name an image the map actually has. If you reference a name
    that isn't in the style's sprite and wasn't registered with `addImage`, the
    symbol renders nothing and the console logs *"image … could not be loaded"*.
    Many styles (including the MapLibre demo style) ship no general-purpose
    marker sprite, so register your own image rather than assuming a built-in
    name exists.

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

- **The active style's sprite** — some styles bundle a named icon set (e.g. a
  style built on the Maki icons exposes `marker-15`, `restaurant-15`, …). These
  names only exist if *that* style includes them; they are not guaranteed.
- **Images you register at runtime** with `addImage` / `addImageFromAsset` —
  always available regardless of the style. This is the portable choice.

Because the MapLibre demo style (and many others) ship no general-purpose
marker sprite, the examples here register their own image rather than relying on
a built-in name.

### Custom image markers

Register your image once with `addImage()` (in `onStyleLoadedCallback`), then reference it by name as the `iconImage`:

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
