# Various Sources

flutter-maplibre-gl supports multiple data source types for loading map data. Each source type serves a different purpose, from inline GeoJSON to remote vector tile servers.

!!! note "Add sources and layers after the style loads"
    Every call below needs a loaded style. Run them from `onStyleLoadedCallback`,
    not from `onMapCreated`, and run them there again after a style change: a new
    style discards every source and layer you added. See
    [Constraints and gotchas](../concepts/annotations-vs-layers.md#constraints-and-gotchas).

## Source types overview

| Source | Class | Use for |
|---|---|---|
| GeoJSON | `GeojsonSourceProperties` | Inline Dart data or remote `.geojson` URL |
| Vector tiles | `VectorSourceProperties` | MVT tile servers (pbf/mvt format) |
| Raster tiles | `RasterSourceProperties` | Raster tile servers (png/jpg tiles) |
| Raster DEM | `RasterDemSourceProperties` | Terrain elevation data (RGB-encoded DEM tiles) |
| Image | `ImageSourceProperties` | A single geo-referenced image overlay |

## GeoJSON source

Inline Dart data or a remote `.geojson` URL, updated whole or feature by
feature. See [GeoJSON Source](geojson-source.md) for the full walkthrough,
including clustering.

## Vector tile source

For MVT vector tile servers, the format used by OpenMapTiles and most modern tile servers:

```dart
await controller.addSource(
  'openmaptiles',
  const VectorSourceProperties(
    url: 'https://tiles.example.com/tiles.json',
    // or specify tiles array directly:
    // tiles: ['https://tiles.example.com/{z}/{x}/{y}.pbf'],
    // minzoom: 0,
    // maxzoom: 14,
  ),
);

// Add a layer referencing a specific source-layer from the tiles
await controller.addFillLayer(
  'openmaptiles',
  'buildings-layer',
  const FillLayerProperties(fillColor: '#d4d0c8'),
  sourceLayer: 'building',  // the vector tile layer name
);
```

!!! tip "Source layers"
    Vector tile sources contain named layers (e.g. `building`, `water`, `road`). You must specify `sourceLayer` when adding a style layer over a vector source.

!!! warning "Attribution"
    Set `attribution` on every source you add. It is what the map's attribution control shows, and most tile providers and data licences, OpenStreetMap's ODbL among them, require the credit to stay visible.

## Raster tile source

For traditional raster tile servers (PNG or JPEG tiles):

```dart
await controller.addSource(
  'satellite',
  const RasterSourceProperties(
    tiles: ['https://tiles.example.com/satellite/{z}/{x}/{y}.jpg'],
    tileSize: 256,
    attribution: '© Example Imagery',
  ),
);

await controller.addRasterLayer(
  'satellite',
  'satellite-layer',
  const RasterLayerProperties(
    rasterOpacity: 0.8,
  ),
);
```

## Raster DEM source (terrain)

Elevation data for 3D terrain rendering:

```dart
await controller.addSource(
  'terrain-dem',
  const RasterDemSourceProperties(
    url: 'https://demotiles.maplibre.org/terrain-tiles/tiles.json',
    tileSize: 256,
  ),
);
```

A raster DEM source feeds a hillshade layer for shaded relief, or a
[color relief layer](color-relief.md) to colour the terrain by elevation.

## Image source (geo-referenced overlay)

Overlay a single image at specific geographic coordinates:

```dart
await controller.addSource(
  'weather-radar',
  ImageSourceProperties(
    url: 'https://example.com/radar.png',
    coordinates: [
      [-80.425, 46.437],   // top-left  [lng, lat]
      [-71.516, 46.437],   // top-right
      [-71.516, 37.936],   // bottom-right
      [-80.425, 37.936],   // bottom-left
    ],
  ),
);
```

## PMTiles

PMTiles is a self-hosted single-file vector tile format. It uses a `pmtiles://` URL scheme in the style JSON, with no special Dart code needed. See the [PMTiles guide](../advanced/pmtiles.md) for the full walkthrough.

## Key APIs

- [`MapLibreMapController.addSource()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/addSource.html)
- [`MapLibreMapController.addGeoJsonSource()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/addGeoJsonSource.html)
- [`GeojsonSourceProperties`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/GeojsonSourceProperties-class.html)
- [`VectorSourceProperties`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/VectorSourceProperties-class.html)
- [`RasterSourceProperties`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/RasterSourceProperties-class.html)
