# Color Relief Layer

A color relief layer paints the terrain by elevation: every pixel of a digital
elevation model gets a colour from a ramp you define. It is the hypsometric tint
you see on physical maps, and it pairs well with a hillshade layer on top for
shaded relief.

!!! note "Add sources and layers after the style loads"
    Every call below needs a loaded style. Run them from `onStyleLoadedCallback`,
    not from `onMapCreated`, and run them there again after a style change: a new
    style discards every source and layer you added. See
    [Constraints and gotchas](../concepts/annotations-vs-layers.md#constraints-and-gotchas).

## The source

A color relief layer reads elevation, so it needs a raster DEM source
(`RasterDemSourceProperties`), the same source type a hillshade layer uses. Set
`encoding` to match how your tiles pack height into the RGB channels, or use
`custom` with `redFactor`, `greenFactor`, `blueFactor` and `baseShift` for a
tileset with an encoding of its own.

## Basic setup

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

await controller.addColorReliefLayer(
  'terrain-dem',
  'terrain-colors',
  const ColorReliefLayerProperties(
    colorReliefOpacity: 0.7,
    colorReliefColor: [
      Expressions.interpolate,
      ['linear'],
      [Expressions.elevation],
      0, '#2b83ba',      // sea level, blue
      500, '#abdda4',    // green
      1500, '#ffffbf',   // yellow
      2500, '#fdae61',   // orange
      3500, '#d7191c',   // red
      4500, '#ffffff',   // snow
    ],
  ),
);
```

## Colour ramp

`colorReliefColor` maps elevation in metres to a colour. Drive it with the
`elevation` expression, which reads the height of each pixel from the DEM, and
interpolate between the stops that suit your terrain: a coastal region needs
stops within the first few hundred metres, an alpine one spreads them over
thousands.

## Key `ColorReliefLayerProperties` fields

| Property | Description |
|---|---|
| `colorReliefColor` | Elevation-to-colour ramp, keyed on `elevation` |
| `colorReliefOpacity` | Layer opacity 0 to 1 |
| `resampling` | Web only: `linear` or `nearest` filtering when overscaled |
| `visibility` | `visible` or `none` |

## Key APIs

- [`MapLibreMapController.addColorReliefLayer()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/addColorReliefLayer.html)
- [`ColorReliefLayerProperties`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/ColorReliefLayerProperties-class.html)
- [Various Sources](various-sources.md): the raster DEM source this layer needs
- [Expressions](../advanced/expressions.md): for the elevation colour ramp
