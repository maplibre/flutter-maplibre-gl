# Background Layer

A background layer paints the whole map with a colour or a repeating image. It
is the only layer type without a source, so it draws everywhere the layers above
it leave the map bare: over the sea in a land-only style, or behind semi
transparent fills.

!!! note "Add sources and layers after the style loads"
    Every call below needs a loaded style. Run them from `onStyleLoadedCallback`,
    not from `onMapCreated`, and run them there again after a style change: a new
    style discards every source and layer you added. See
    [Constraints and gotchas](../concepts/annotations-vs-layers.md#constraints-and-gotchas).

## Basic setup

```dart
await controller.addBackgroundLayer(
  'ocean-background',
  const BackgroundLayerProperties(
    backgroundColor: '#1b3a5c',
    backgroundOpacity: 1.0,
  ),
);
```

A background layer added last sits on top of every other layer and hides them,
so pass `belowLayerId` to place it under the layers it should back:

Anchor it above the style's own background layer, which most styles put first.
Below that one your layer is covered by an opaque colour and nothing shows:

```dart
final layerIds = await controller.getLayerIds();

await controller.addBackgroundLayer(
  'ocean-background',
  const BackgroundLayerProperties(backgroundColor: '#1b3a5c'),
  belowLayerId: layerIds.length < 2 ? null : layerIds[1] as String,
);
```

!!! warning "Changing the properties later"
    With the style's own background layer still in place, changing this layer's
    properties afterwards can stop it drawing. Remove the style's background
    layer first, or set the properties you want when you add this one.
    Tracked upstream in [maplibre-native#4502](https://github.com/maplibre/maplibre-native/issues/4502).

## Pattern

`backgroundPattern` tiles an image from the style sprite instead of a flat
colour. Add the image first with
[`addImage()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/addImage.html),
then name it in the property. For a seamless result its width and height must be
a power of two.

```dart
await controller.addBackgroundLayer(
  'paper-background',
  const BackgroundLayerProperties(backgroundPattern: 'paper-texture'),
);
```

## Key `BackgroundLayerProperties` fields

| Property | Description |
|---|---|
| `backgroundColor` | Fill colour, ignored when `backgroundPattern` is set |
| `backgroundPattern` | Name of a sprite image to tile |
| `backgroundOpacity` | Layer opacity 0 to 1 |
| `visibility` | `visible` or `none` |

## Key APIs

- [`MapLibreMapController.addBackgroundLayer()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/addBackgroundLayer.html)
- [`BackgroundLayerProperties`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/BackgroundLayerProperties-class.html)
- [Expressions](../advanced/expressions.md): to drive the colour by zoom
