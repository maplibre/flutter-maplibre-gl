# Camera Bounds

Keep the camera target inside a geographic area, or limit the zoom levels. Useful for apps focused on a specific region.

## Constrain geographic bounds

Pass `cameraTargetBounds` to `MapLibreMap`:

```dart
MapLibreMap(
  cameraTargetBounds: CameraTargetBounds(
    LatLngBounds(
      southwest: const LatLng(41.0, -5.5),  // SW corner
      northeast: const LatLng(51.5, 9.5),   // NE corner
    ),
  ),
  initialCameraPosition: const CameraPosition(
    target: LatLng(46.0, 2.0),
    zoom: 5.0,
  ),
)
```

The bounds limit the camera target, the center of the map view. The target stays inside them for gestures and for camera calls such as `moveCamera` and `animateCamera`. A target outside the bounds is moved to the nearest point inside them, so the map stops at the edge.

The bounds set no minimum zoom and do not clip the map: a zoomed out map can show area outside them. To keep the user from zooming out that far, set `minMaxZoomPreference`. Zoom, bearing and tilt are not changed by the bounds. When you change the bounds while the target is outside the new ones, the target moves inside at once.

The map behaves the same on Android, iOS and web, with one difference on web: when a drag goes past the edge and comes back in the same gesture, the map moves again only once the pointer is back where the target reached the edge.

## Remove bounds constraint

```dart
MapLibreMap(
  cameraTargetBounds: CameraTargetBounds.unbounded, // default
)
```

## Constrain zoom levels

```dart
MapLibreMap(
  minMaxZoomPreference: const MinMaxZoomPreference(8.0, 18.0),
  // minZoom: 8 : can't zoom out past city level
  // maxZoom: 18: can't zoom in past building level
)
```

## Fit camera to a bounding box

Constraining the camera and moving it to a region are different jobs. For the
one-off move, see [Fit a bounding box](camera-controls.md#fit-a-bounding-box).

## Key APIs

- [`CameraTargetBounds`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/CameraTargetBounds-class.html)
- [`MinMaxZoomPreference`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MinMaxZoomPreference-class.html)
- [`CameraUpdate.newLatLngBounds()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/CameraUpdate/newLatLngBounds.html)
