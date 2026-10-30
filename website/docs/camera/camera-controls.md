# Camera Controls

The camera defines what the user sees: the center position, zoom level, bearing (rotation), and tilt. `MapLibreMapController` provides methods to move the camera programmatically with smooth animations or instant jumps.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/demo/?example=doc-camera"
  title="Camera controls"
  loading="lazy"
></iframe>

Press the button to fly between cities around the world, or pan the map yourself: **Search this area** shows up only after your own moves, never after the flight.

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

The future completes when the animation ends: `true` once the camera has arrived, `false` if another camera call, a gesture or disposing the map cut it short. `easeCamera` completes the same way.

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
| `CameraUpdate.newLatLngBounds(LatLngBounds, {left, top, right, bottom})` | Fit a bounding box into view, with per-edge padding |
| `CameraUpdate.zoomIn()` | Zoom in one level |
| `CameraUpdate.zoomOut()` | Zoom out one level |
| `CameraUpdate.zoomTo(double)` | Zoom to a specific level |
| `CameraUpdate.zoomBy(double, [Offset])` | Relative zoom change, keeping the optional focus point in place |
| `CameraUpdate.bearingTo(double)` | Rotate to a bearing |
| `CameraUpdate.tiltTo(double)` | Set tilt angle |
| `CameraUpdate.scrollBy(double, double)` | Pan by logical pixels (positive x east, positive y south) |

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
if (position != null) {
  print('Center: ${position.target}');
  print('Zoom: ${position.zoom}');
  print('Bearing: ${position.bearing}');
  print('Tilt: ${position.tilt}');
}
```

## `easeCamera`: interpolated animation

`easeCamera` moves the camera along a single eased path, where `animateCamera` uses the
platform's fly-to animation. Pass `interpolation` to pick the curve; `linear` is the one to
use for continuous tracking, since it has no acceleration between successive calls:

```dart
await controller.easeCamera(
  CameraUpdate.newLatLng(const LatLng(35.6762, 139.6503)),
  duration: const Duration(seconds: 3),
  interpolation: CameraAnimationInterpolation.linear,
);
```

The default is `easeInOut`. Android only distinguishes linear from eased, so the other
curves render as its native ease-in/ease-out; see the
[Feature Matrix](../compare/feature-matrix.md).

## Padding: keep content centered behind an overlay

A bottom sheet or a side panel covers part of the map, so the geometric center of the widget is no longer the center the user sees. `setPadding` shifts the map's center by insetting the viewport, and every later camera call respects it, so you do not have to pass padding to each one:

```dart
// A 240 dp bottom sheet just opened.
await controller.setPadding(bottom: 240, animated: true);

// Centers in the visible part of the map, not behind the sheet.
await controller.animateCamera(CameraUpdate.newLatLng(marker));

// Sheet dismissed.
await controller.setPadding(animated: true);
```

Values are in logical pixels and default to zero, so a call with no arguments clears the padding. `setPadding` is a convenience wrapper around `updateContentInsets`, which takes an `EdgeInsets`; use whichever reads better. Both work on Android, iOS and web.

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
    Camera move callbacks are disabled by default for performance. Set `trackCameraPosition: true` on `MapLibreMap` to enable them. The last `onCameraMove` before `onCameraIdle` has the position where the camera stopped, also after `moveCamera`.

### Tell the user's moves from the app's

`onCameraMoveStarted` fires once at the start of every move, with or without `trackCameraPosition`, and says what started it:

| `CameraMoveReason` | Started by |
|---|---|
| `gesture` | A pan, pinch, rotation, tilt or double tap of the user, and the fling after it. On web also the mouse wheel and the keyboard |
| `programmatic` | Anything else: `animateCamera`, `easeCamera`, `moveCamera`, a tap on the compass, location tracking |

While the camera moves, `controller.cameraMoveReason` holds the same value. It is `null` when the camera is still, inside `onCameraIdle` too.

A move that takes over another before the camera stops, such as `animateCamera` during a fling, stays one move: one `onCameraMoveStarted` with the reason of the first, one `onCameraIdle` at the end.

#### Close a popup when the user moves the map

```dart
MapLibreMap(
  onCameraMoveStarted: (reason) {
    if (reason == CameraMoveReason.gesture) closePopup();
  },
)
```

Your own `animateCamera` to the selected feature leaves the popup open.

#### Show "Search this area" after the user pans

Keep the reason from `onCameraMoveStarted`, since the controller's is already `null` in `onCameraIdle`:

```dart
var movedByUser = false;

MapLibreMap(
  onCameraMoveStarted: (reason) {
    movedByUser = reason == CameraMoveReason.gesture;
    hideSearchButton();
  },
  onCameraIdle: () {
    if (movedByUser) showSearchButton();
  },
)
```

The demo at the top of this page does exactly this.

#### Skip the app's own moves in `onCameraMove`

```dart
MapLibreMap(
  trackCameraPosition: true,
  onMapCreated: (c) => controller = c,
  onCameraMove: (position) {
    if (controller?.cameraMoveReason != CameraMoveReason.gesture) return;
    showCoordinates(position.target);  // only while the user drags
  },
)
```

## Key APIs

- [`MapLibreMapController.animateCamera()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/animateCamera.html)
- [`MapLibreMapController.moveCamera()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/moveCamera.html)
- [`MapLibreMapController.easeCamera()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/easeCamera.html)
- [`CameraUpdate`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/CameraUpdate-class.html)
- [`CameraPosition`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/CameraPosition-class.html)
- [`CameraMoveReason`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/CameraMoveReason.html)
