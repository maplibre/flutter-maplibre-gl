# Camera Controls

The camera defines what the user sees: the center position, zoom level, bearing (rotation), and tilt. `MapLibreMapController` provides methods to move the camera programmatically with smooth animations or instant jumps.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/?example=doc-camera"
  title="Camera controls"
  loading="lazy"
></iframe>

Press the button to fly between cities around the world.

## `animateCamera`: smooth animation

```dart
// Fly to a location with zoom
await controller.animateCamera(
  CameraUpdate.newCameraPosition(
    const CameraPosition(
      target: LatLng(48.8566, 2.3522),
      zoom: 12.0,
      bearing: 45.0,  // rotate 45 degrees
      tilt: 30.0,     // pitch/tilt the view
    ),
  ),
  duration: const Duration(milliseconds: 2000),
);
```

## `moveCamera`: instant jump

```dart
// No animation: instant
await controller.moveCamera(
  CameraUpdate.newLatLngZoom(
    const LatLng(51.5074, -0.1278),
    12.0,
  ),
);
```

## `CameraUpdate` factory methods

| Method | Description |
|---|---|
| `CameraUpdate.newLatLng(LatLng)` | Move to position, keep zoom |
| `CameraUpdate.newLatLngZoom(LatLng, double)` | Move to position with zoom |
| `CameraUpdate.newCameraPosition(CameraPosition)` | Full control: position + zoom + bearing + tilt |
| `CameraUpdate.newLatLngBounds(LatLngBounds, {padding})` | Fit a bounding box into view |
| `CameraUpdate.zoomIn()` | Zoom in one level |
| `CameraUpdate.zoomOut()` | Zoom out one level |
| `CameraUpdate.zoomTo(double)` | Zoom to a specific level |
| `CameraUpdate.zoomBy(double)` | Relative zoom change |
| `CameraUpdate.bearingTo(double)` | Rotate to a bearing |
| `CameraUpdate.tiltTo(double)` | Set tilt angle |
| `CameraUpdate.scrollBy(double, double)` | Pan by pixel offset |

## Fit a bounding box

```dart
await controller.animateCamera(
  CameraUpdate.newLatLngBounds(
    LatLngBounds(
      southwest: const LatLng(41.0, -5.0),  // SW Spain
      northeast: const LatLng(51.5, 9.5),   // NE Germany
    ),
    left: 40, top: 40, right: 40, bottom: 40,  // padding in pixels
  ),
);
```

## Query current camera

```dart
final position = await controller.queryCameraPosition();
print('Center: ${position.target}');
print('Zoom: ${position.zoom}');
print('Bearing: ${position.bearing}');
print('Tilt: ${position.tilt}');
```

## `easeCamera`: interpolated animation

`easeCamera` is like `animateCamera` but uses MapLibre's easing functions instead of a linear interpolation:

```dart
await controller.easeCamera(
  CameraUpdate.newLatLng(const LatLng(35.6762, 139.6503)),
  duration: const Duration(seconds: 3),
);
```

## React to camera movement

```dart
MapLibreMap(
  onCameraIdle: () {
    // Called when camera stops moving
  },
  trackCameraPosition: true,  // enables onCameraMove
  onCameraMove: (CameraPosition pos) {
    // Called while camera is moving
  },
)
```

!!! tip "`trackCameraPosition: true`"
    Camera move callbacks are disabled by default for performance. Set `trackCameraPosition: true` on `MapLibreMap` to enable them.

## Key APIs

- [`MapLibreMapController.animateCamera()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/animateCamera.html)
- [`MapLibreMapController.moveCamera()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/moveCamera.html)
- [`MapLibreMapController.easeCamera()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/easeCamera.html)
- [`CameraUpdate`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/CameraUpdate-class.html)
- [`CameraPosition`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/CameraPosition-class.html)
