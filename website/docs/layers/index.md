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

## When a call fails

Layer and source calls throw a `PlatformException` with the same code on
every platform, and a failed call changes nothing:

| Code | When |
|---|---|
| `STYLE_NOT_READY` | The style has not loaded yet. |
| `SOURCE_NOT_FOUND`, `LAYER_NOT_FOUND_ERROR` | The id is not in the style. |
| `SOURCE_ALREADY_EXISTS`, `LAYER_ALREADY_EXISTS` | The id is already in use. |
| `UNSUPPORTED_SOURCE_TYPE` | The layer cannot draw the source's type (see [which layer draws which source](various-sources.md#which-layer-draws-which-source)), or the platform has no such source. |
| `INVALID_EXPRESSION` | MapLibre rejects a filter or a property expression. |
| `INVALID_ARGUMENT` | A property value has the wrong kind, or no source can be built from the source properties. |
| `INVALID_GEOJSON` | The data is not valid GeoJSON. |

The message names the property, layer or source at fault.
