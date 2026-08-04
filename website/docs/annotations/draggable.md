# Draggable Annotations

Allow users to drag annotations to new positions on the map.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/demo/?example=edit-annotation-draggable"
  title="Edit Annotation Draggable example"
  loading="lazy"
></iframe>

!!! note "Prerequisites"
    Annotations only work once the style has loaded and if their type is part of
    the widget's `annotationOrder`. See
    [Prerequisites](markers.md#prerequisites).

## Enable dragging

Dragging needs three things, and all of them are on by default except the last:

- `MapLibreMap.dragEnabled` must be `true` (the default). It is the global
  switch for the drag gesture listeners.
- The annotation type must be listed in `MapLibreMap.annotationConsumeTapEvents`
  (all four types by default). Only the layers of those types are hit-tested, so
  a type left out of it can never be dragged, even with `draggable: true`.
- The annotation itself must be created with `draggable: true`.

Set `draggable: true` in `SymbolOptions`:

```dart
final symbol = await controller.addSymbol(
  const SymbolOptions(
    geometry: LatLng(48.8566, 2.3522),
    iconImage: 'my-pin',
    draggable: true,
  ),
);
```

## Listen for drag events

Three callbacks are available: drag start, drag (continuous), and drag end:

```dart
// When drag begins
controller.onSymbolDragStart.add((Symbol symbol) {
  print('Drag started at: ${symbol.options.geometry}');
});

// Called on every position change during drag
controller.onSymbolDrag.add((Symbol symbol) {
  print('Dragging: ${symbol.options.geometry}');
});

// When the user releases the symbol
controller.onSymbolDragEnd.add((Symbol symbol) {
  final pos = symbol.options.geometry!;
  print('Dropped at: ${pos.latitude}, ${pos.longitude}');
  _saveNewPosition(pos);
});
```

## Toggle draggable at runtime

```dart
await controller.updateSymbol(
  symbol,
  const SymbolOptions(draggable: false), // lock it in place
);
```

## Draggable circles and fills

The `draggable` property is also available on `CircleOptions` and `FillOptions`:

```dart
final circle = await controller.addCircle(
  CircleOptions(
    geometry: const LatLng(48.86, 2.35),
    circleRadius: 20,
    circleColor: '#296CA8',
    draggable: true,
  ),
);

controller.onCircleDragEnd.add((Circle circle) {
  print('Circle moved to: ${circle.options.geometry}');
});
```

## Dragging style-layer features too

Dragging is not limited to annotations. Features rendered from a GeoJSON source through a style layer can also be dragged. The setup differs:

1. Give each feature a `'draggable': true` property and a stable `id`.
2. Add the source with `promoteId: 'id'` and the layer with `enableInteraction: true`.
3. Listen to `controller.onFeatureDrag` and write the new position back into the source.

```dart
await controller.addGeoJsonSource('points', {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'id': 'p1',
      'geometry': {'type': 'Point', 'coordinates': [2.35, 48.86]},
      'properties': {'id': 'p1', 'draggable': true},
    },
  ],
}, promoteId: 'id');

await controller.addCircleLayer(
  'points',
  'points-layer',
  const CircleLayerProperties(circleRadius: 20, circleColor: '#296CA8'),
  enableInteraction: true,
);

controller.onFeatureDrag.add((
  point, origin, current, delta, id, annotation, eventType,
) {
  if (eventType == DragEventType.drag || eventType == DragEventType.end) {
    // update the feature's coordinates in your source data, then call
    // controller.setGeoJsonSource('points', updatedFeatureCollection);
  }
});
```

The difference: annotations expose a typed `onSymbolDragEnd`/`onCircleDragEnd` and manage the geometry for you, while style layers give you a single low-level `onFeatureDrag` and you own the source update. See [Annotations vs Style Layers](../concepts/annotations-vs-layers.md).

## Key APIs

- [`SymbolOptions.draggable`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/SymbolOptions/draggable.html)
- [`MapLibreMapController.onSymbolDrag`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/onSymbolDrag.html)
- [`MapLibreMapController.onSymbolDragEnd`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/onSymbolDragEnd.html)
- [`MapLibreMapController.onFeatureDrag`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/onFeatureDrag.html)
