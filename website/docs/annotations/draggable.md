# Draggable Annotations

Allow users to drag annotations to new positions on the map.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/demo/?example=edit-annotation-draggable"
  title="Edit Annotation Draggable example"
  loading="lazy"
></iframe>

Add draggable symbols and circles over Sydney, then drag one to watch the drag phase and its start and current coordinates update live.

!!! note "Prerequisites"
    Annotations only work once the style has loaded and if their type is part of
    the widget's `annotationOrder`. See [Prerequisites](index.md#prerequisites).

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

There is a single drag callback, `onFeatureDrag`, and it covers all three
phases through its `DragEventType` argument: `start`, `drag` (continuous) and
`end`. For a dragged annotation the `annotation` argument is the typed object
(`Symbol`, `Circle`, `Line`, `Fill`), already moved to the new position, so you
only have to react to the drop:

```dart
controller.onFeatureDrag.add((
  Point<double> point,
  LatLng origin,
  LatLng current,
  LatLng delta,
  String id,
  Annotation? annotation,
  DragEventType eventType,
) {
  if (annotation is! Symbol) return;

  switch (eventType) {
    case DragEventType.start:
      print('Drag started at: $origin');
    case DragEventType.drag:
      print('Dragging: $current');
    case DragEventType.end:
      // annotation.options.geometry is already the dropped position.
      print('Dropped at: ${current.latitude}, ${current.longitude}');
      _saveNewPosition(current);
  }
});
```

`origin` is where the drag started, `current` the position under the finger,
and `delta` the movement since the previous event. `point` is the screen
position, a `Point<double>` from `dart:math`.

## Toggle draggable at runtime

```dart
await controller.updateSymbol(
  symbol,
  const SymbolOptions(draggable: false), // lock it in place
);
```

## Draggable circles, lines and fills

The `draggable` property is available on all four annotation types, so
`CircleOptions`, `LineOptions` and `FillOptions` behave exactly like
`SymbolOptions`, geometry included:

```dart
final circle = await controller.addCircle(
  CircleOptions(
    geometry: const LatLng(48.86, 2.35),
    circleRadius: 20,
    circleColor: '#296CA8',
    draggable: true,
  ),
);

controller.onFeatureDrag.add((point, origin, current, delta, id, annotation, eventType) {
  if (annotation is Circle && eventType == DragEventType.end) {
    print('Circle moved to: ${annotation.options.geometry}');
  }
});
```

## Dragging style-layer features too

Dragging is not limited to annotations. Features rendered from a GeoJSON source through a style layer can also be dragged. The setup differs:

1. Give each feature a `'draggable': true` property and a stable `id`.
2. Add the layer with `enableInteraction: true`. On web, add the source with
   `promoteId: 'id'` so the string id survives; `promoteId` is web only, so on
   Android and iOS the top-level `id` from step 1 is what identifies the feature.
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
}, promoteId: 'id'); // web only, native reads the top-level 'id'

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

The difference is not the callback, both go through `onFeatureDrag`: for an annotation the manager moves the geometry for you and hands you the typed object, while for a style-layer feature `annotation` is `null` and you own the source update. See [Annotations vs Style Layers](../concepts/annotations-vs-layers.md).

## Key APIs

- [`SymbolOptions.draggable`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/SymbolOptions/draggable.html)
- [`MapLibreMapController.onFeatureDrag`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/onFeatureDrag.html)
- [`MapLibreMap.dragEnabled`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMap/dragEnabled.html)
- [`MapLibreMapController.setGeoJsonFeature`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/setGeoJsonFeature.html)
