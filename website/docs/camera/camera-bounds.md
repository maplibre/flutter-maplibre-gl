# Camera Bounds

Constrain the camera so users can't pan outside a geographic area or zoom beyond specified levels. Useful for apps focused on a specific region.

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

Users cannot pan outside the specified bounds. The map snaps back if they try.

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

## Platform notes

!!! info "iOS implementation"
    iOS lacks a native `setLatLngBoundsForCameraTarget` API equivalent to Android's. The current iOS implementation intercepts camera movement via the delegate's `shouldChangeFrom:to:` method and rejects out-of-bounds positions.

    **Known caveats on iOS:**
    - Only blocks user gestures (pan, pinch). Programmatic `animateCamera()` calls are not blocked.
    - No per-axis clamping: diagonal pans near the boundary may feel slightly sticky.
    - Android has the more complete implementation.

## Key APIs

- [`CameraTargetBounds`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/CameraTargetBounds-class.html)
- [`MinMaxZoomPreference`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MinMaxZoomPreference-class.html)
- [`CameraUpdate.newLatLngBounds()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/CameraUpdate/newLatLngBounds.html)
