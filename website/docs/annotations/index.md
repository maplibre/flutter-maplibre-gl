# Annotations

Annotations are interactive overlays drawn on top of the map. flutter-maplibre-gl supports four annotation types managed via the `MapLibreMapController`:

| Type | Class | Use for |
|------|-------|---------|
| Symbol | `Symbol` | Point markers with icons or text labels |
| Circle | `Circle` | Filled circular points |
| Line | `Line` | Polylines and paths |
| Fill | `Fill` | Polygons and filled areas |

All four types share the same two requirements: the style must be loaded, and the type must be part of the widget's `annotationOrder`. See [Prerequisites](markers.md#prerequisites).

- [Markers](markers.md): add and style symbol annotations, including custom image icons
- [Animated](animated.md): animate annotation position changes
- [Draggable](draggable.md): allow users to drag annotations
