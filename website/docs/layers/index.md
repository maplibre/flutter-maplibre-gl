# Layers & Sources

Style layers render data from a source with full control over how it looks, and
they scale to datasets the annotation API cannot. Start with the source, then
pick the layer that matches your geometry: symbol and circle for points, line
for paths, fill for areas, heatmap and cluster for many points at once.

- [Symbol Layer](symbol-layer.md): icons and text labels from a source
- [Circle Layer](circle-layer.md): circular points
- [Fill Layer](fill-layer.md): polygons and filled areas
- [Line Layer](line-layer.md): polylines and paths
- [Heatmap](heatmap.md): point density as a heat surface
- [Color Relief](color-relief.md): terrain coloured by elevation from a raster DEM
- [Background](background.md): a colour or pattern behind every other layer
- [Cluster](cluster.md): cluster many points into grouped circles
- [GeoJSON Source](geojson-source.md): feed layers from inline data or a URL
- [Various Sources](various-sources.md): GeoJSON, vector tiles, raster tiles, and more

## Manage layers

Once a layer is on the map, these calls change it without removing and adding it again:

```dart
// Draw 'labels' below 'roads'; without belowLayerId it goes on top.
await controller.moveLayer('labels', belowLayerId: 'roads');

// Draw 'buildings' only from zoom 14 up.
await controller.setLayerZoomRange('buildings', 14, 24);

// Hide a group of layers in one call, all in the same frame.
final missing = await controller.setLayersVisibility(['roads', 'labels'], false);
```

* `moveLayer` keeps the layer's properties, filter and source.
* `setLayerZoomRange` takes zooms from 0 to 24: `minzoom` is inclusive, `maxzoom` exclusive.
* `setLayersVisibility` skips the ids the style does not have, and returns them.

## When a call fails

Layer and source calls throw a `PlatformException` with the same code on every platform, and a failed call changes nothing. The message names the property, layer or source at fault, and [Errors](../concepts/errors.md) lists every code.
