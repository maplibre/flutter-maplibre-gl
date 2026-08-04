# Annotations

Annotations are interactive overlays drawn on top of the map. flutter-maplibre-gl supports four annotation types managed via the `MapLibreMapController`:

| Type | Class | Use for |
|------|-------|---------|
| Symbol | `Symbol` | Point markers with icons or text labels |
| Circle | `Circle` | Filled circular points |
| Line | `Line` | Polylines and paths |
| Fill | `Fill` | Polygons and filled areas |

- [Markers](markers.md): add and style symbol annotations, including custom image icons
- [Animated](animated.md): animate annotation position changes
- [Draggable](draggable.md): allow users to drag annotations

## Prerequisites

Two conditions apply to **all four types**. If either is missing, `addSymbol()`,
`addCircle()`, `addLine()` and `addFill()` throw an exception reporting that the
annotation manager for that type has not been initialized.

1. **The style must be loaded.** Add annotations from `onStyleLoadedCallback`,
   not from `onMapCreated`. The annotation managers are created as part of style
   loading, and `onStyleLoadedCallback` runs once they are ready. It also fires
   again after every style change, and annotations do not survive one, so this
   is where you re-add them.
2. **The annotation type must be enabled** in the `annotationOrder` parameter of
   the `MapLibreMap` widget. The default enables all four types, so you only hit
   this if you pass the parameter yourself. An **empty** list disables
   annotations entirely.

```dart
MapLibreMap(
  styleString: 'https://demotiles.maplibre.org/style.json',
  // Default: all four types enabled. Narrow it only if you know you need to.
  annotationOrder: const [AnnotationType.symbol],
  onStyleLoadedCallback: () async {
    await controller.addSymbol(/* ... */);
  },
)
```

`annotationOrder` also sets the stacking order, from bottom to top, and it is
read once when the map is created: changing it later has no effect. Tap and drag
callbacks additionally require the type to be listed in
`annotationConsumeTapEvents` (all four by default).

See [Constraints and gotchas](../concepts/annotations-vs-layers.md#constraints-and-gotchas)
for the full list, including what applies to style layers.
