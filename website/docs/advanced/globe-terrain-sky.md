# Globe, Terrain and Sky

!!! note "Platform support"
    The projection, terrain and sky style root objects are **web only**. On Android and iOS `setProjection`, `setTerrain` and `setSky` throw an `UnsupportedError`, because MapLibre Native renders the mercator projection on a flat map and implements neither 3D terrain nor the sky yet. `setLight`, at the bottom of this page, works everywhere.

These three calls change the style itself rather than a layer, so a style change
discards them: run them from `onStyleLoadedCallback`, like sources and layers.

## Projection

`setProjection` takes `mercator`, `globe` or `vertical-perspective`:

```dart
await controller.setProjection('globe');
```

It also takes an expression, which is how you fade from a globe when zoomed out
to a flat map when zoomed in:

```dart
await controller.setProjection([
  Expressions.interpolate,
  ['linear'],
  [Expressions.zoom],
  10, 'vertical-perspective',
  12, 'mercator',
]);
```

## Terrain

Terrain raises the map by the elevation of a raster DEM source, so add the
source first and then point `TerrainProperties` at it. `exaggeration` scales the
height; a null argument removes the terrain.

```dart
await controller.addSource(
  'terrain-dem',
  const RasterDemSourceProperties(
    tiles: [
      'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png',
    ],
    tileSize: 256,
    encoding: 'terrarium',
    attribution: '© AWS Terrain Tiles',
  ),
);

await controller.setTerrain(
  const TerrainProperties(source: 'terrain-dem', exaggeration: 1.5),
);

// Back to a flat map
await controller.setTerrain(null);
```

## Sky

The sky draws above the horizon, and the fog properties blend it into 3D
terrain. Every field accepts an expression, which is worth using for
`atmosphereBlend` so the atmosphere fades out as the globe fills the screen.

```dart
await controller.setSky(
  const SkyProperties(
    skyColor: '#199EF3',
    horizonColor: '#ffffff',
    fogColor: '#ffffff',
    fogGroundBlend: 0.5,
    horizonFogBlend: 0.5,
    skyHorizonBlend: 0.6,
    atmosphereBlend: [
      Expressions.interpolate,
      ['linear'],
      [Expressions.zoom],
      0, 1,
      10, 1,
      12, 0,
    ],
  ),
);
```

## Light

The light source shades extruded geometries, so it changes how a fill extrusion
layer looks. Unlike the three calls above it works on **all platforms**, with one
difference: Android and iOS take constant values only, while web also accepts
expressions.

```dart
await controller.setLight(
  const LightProperties(
    anchor: 'map',
    position: [1.5, 90, 80], // radial, azimuthal, polar
    color: '#ffffff',
    intensity: 0.4,
  ),
);
```

## Key APIs

- [`MapLibreMapController.setProjection()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/setProjection.html)
- [`MapLibreMapController.setTerrain()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/setTerrain.html)
- [`MapLibreMapController.setSky()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/setSky.html)
- [`MapLibreMapController.setLight()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/setLight.html)
- [Various Sources](../layers/various-sources.md): the raster DEM source terrain needs
- [Data-Driven Expressions](expressions.md): for the zoom-interpolated forms above
