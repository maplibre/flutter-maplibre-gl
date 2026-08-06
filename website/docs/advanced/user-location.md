# User Location

The map can show where the user is with a location puck: a dot, an accuracy ring, and optionally a heading indicator. Two things drive it: a **source** of positions, and a **tracking mode** that decides how the camera follows them.

## Show the puck

Set `myLocationEnabled: true` and make sure the platform permissions from [Installation & Setup](../getting-started.md) are in place. The plugin does not request permissions itself, so ask for them before enabling the puck, with a package such as [`permission_handler`](https://pub.dev/packages/permission_handler).

```dart
MapLibreMap(
  styleString: MapLibreStyles.demo,
  initialCameraPosition: const CameraPosition(target: LatLng(51.5, -0.09), zoom: 12),
  myLocationEnabled: true,
  myLocationTrackingMode: MyLocationTrackingMode.tracking,
  onUserLocationUpdated: (location) {
    debugPrint('now at ${location.position}');
  },
)
```

`MyLocationTrackingMode` controls the camera:

| Mode | Camera |
|------|--------|
| `none` | never moved by location updates |
| `tracking` | follows the position |
| `trackingCompass` | follows the position, rotates with the device compass |
| `trackingGps` | follows the position, rotates with the direction of travel |

On web only `none` and `tracking` are meaningful, since the browser exposes no compass heading.

## Tune the location engine

`locationEnginePlatforms` passes platform options straight through to the underlying engine, so each platform takes only what it understands:

```dart
MapLibreMap(
  myLocationEnabled: true,
  locationEnginePlatforms: kIsWeb
      ? const LocationEnginePlatforms.web(enableHighAccuracy: true)
      : const LocationEnginePlatforms.android(
          enableHighAccuracy: true,
          interval: 1000,
        ),
)
```

### Pulsed GPS on iOS

Continuous GPS is expensive on a map that stays open for a long time. On iOS the engine can run in pulses instead: GPS is active for `pulseWindowMs`, then off until the next `intervalMs`, and the puck holds its last position in between.

```dart
MapLibreMap(
  myLocationEnabled: true,
  locationEnginePlatforms: const LocationEnginePlatforms.iOS(
    intervalMs: 30000,    // one pulse every 30 s
    pulseWindowMs: 5000,  // GPS on for 5 s per pulse
  ),
)
```

`intervalMs: 0`, the default, keeps continuous tracking. This is iOS only; Android throttles through `interval` and `priority` instead.

## Drive the puck yourself

Sometimes the device's own GPS is not the source of truth: a paired external receiver, a replayed track, a simulation, or a position that arrives over the network. Build the map with `ManualLocationSource` and push each fix yourself.

```dart
MapLibreMap(
  myLocationEnabled: true,
  locationSource: const ManualLocationSource(),
  myLocationTrackingMode: MyLocationTrackingMode.trackingGps,
)
```

```dart
await controller.updateManualLocation(
  ManualLocationUpdate(
    target: const LatLng(51.5, -0.09),
    bearing: 42,              // direction of travel, degrees
    speed: 4.2,               // m/s
    horizontalAccuracy: 8,    // metres, drives the accuracy ring
    altitude: 16,
    timestamp: DateTime.now(),
  ),
);
```

Only `target` is required; omitted fields are not sent on. The accuracy ring, the tracking modes and `onUserLocationUpdated` keep working exactly as with the device engine.

!!! tip "No permission needed"
    In manual mode the SDK never queries the device, so no location permission is required. This also makes the puck testable: push a scripted track and the map behaves as if the user were walking it.

There is no `heading` field. On Android and iOS the compass heading comes from the device sensors, so it stays device-driven even in manual mode; `bearing` is the GPS-style direction of travel that `trackingGps` and the puck's arrow use.

Works on Android, iOS and web. On Android and iOS the pushed fixes drive the SDK's own user-location component; web has no such component, so the plugin draws the puck itself, styled from `maplibre-gl.css`.

## Key APIs

| API | Purpose |
|-----|---------|
| `myLocationEnabled` | show or hide the puck |
| `myLocationTrackingMode` | how the camera follows the user |
| `myLocationRenderMode` | how heading is drawn: `normal`, `compass`, or `gps` (not on iOS) |
| `locationSource` | `PlatformLocationSource` (default) or `ManualLocationSource` |
| `locationEnginePlatforms` | per-platform engine options, including iOS pulsing |
| `controller.updateManualLocation` | push a fix in manual mode |
| `controller.requestMyLocationLatLng` | read the last known position |
| `onUserLocationUpdated` | callback for every update, either source |

The example app's **Manual Location Source** page drives the puck around a simulated loop, with start and stop, single pushes, tracking-mode switching and a live accuracy ring.
