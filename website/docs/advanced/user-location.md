# User Location

The map can show where the user is with a location puck: a dot, an accuracy ring, and optionally a heading indicator. Two things drive it: a **source** of positions, and a **tracking mode** that decides how the camera follows them.

## Show the puck

Set `myLocationEnabled: true` and make sure the platform permissions from [Getting Started](../getting-started.md) are in place. The plugin does not request permissions itself, so ask for them before enabling the puck, with a package such as [`permission_handler`](https://pub.dev/packages/permission_handler).

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

## Style the puck

`myLocationStyle` recolors the puck, for example to match your brand or to make it stand out on a light style. Every field is optional, and a field left out keeps the platform's own look:

```dart
MapLibreMap(
  myLocationEnabled: true,
  myLocationStyle: const MyLocationStyle(
    fillColor: Color(0xFFE53935),
    bearingColor: Color(0xFF1E88E5),
    accuracyColor: Color(0xFFE53935),
    pulseEnabled: true,
    pulseColor: Color(0xFFE53935),
  ),
)
```

The style can change while the map is shown, and setting it back to `null` restores the default look.

| Field | What it colors |
|-------|----------------|
| `fillColor` | the location dot |
| `bearingColor` | the arrow that points along the direction of the user |
| `accuracyColor` | the accuracy circle; only its color is used, not its alpha |
| `accuracyCircleEnabled` | `false` hides the accuracy circle |
| `pulseEnabled` | turns the pulse around the dot on or off; leave it `null` for the platform default |
| `pulseColor` | the color of the pulse |

Each platform draws the puck a little differently, so a few fields land on different parts:

* **Android**: `bearingColor` is the bearing chevron of `MyLocationRenderMode.compass`, and `fillColor` also colors the navigation arrow of `MyLocationRenderMode.gps`. The pulse is off by default, so `pulseColor` alone shows nothing: set `pulseEnabled: true` too. The dot still turns grey when no fix has arrived for a while.
* **iOS**: `bearingColor` is the arrow drawn in `MyLocationTrackingMode.trackingGps`, and `fillColor` also colors the heading arrow of `MyLocationRenderMode.compass`. The pulse is on by default but only drawn while the accuracy is 10 meters or better. While the user only grants an approximate location, iOS draws a wider halo in `accuracyColor` instead, and keeps it when `accuracyCircleEnabled` is `false`.
* **Web**: `bearingColor` is the arrow of the puck drawn for a `ManualLocationSource`; the browser geolocation puck shows no direction. The pulse is on by default.

The accuracy circle keeps each platform's own translucency, about 15% opacity on Android, 10% on iOS and 20% on web, so it never hides the map below.

## Pitch the camera while tracking

A navigation-style view wants both things at once: the camera pitched, and the map still following the user. The regular camera calls (`animateCamera`, `easeCamera`, `moveCamera`) are not tracking-aware, so on Android they end tracking outright: the map stops following and `onCameraTrackingChanged` reports `MyLocationTrackingMode.none`. Use `setTrackingCameraOptions` instead, which goes through the platform's tracking machinery and leaves the mode alone.

```dart
await controller.updateMyLocationTrackingMode(MyLocationTrackingMode.trackingGps);

await controller.setTrackingCameraOptions(
  tilt: 45,
  duration: const Duration(milliseconds: 250),
);
```

`tilt` is the pitch in degrees, from 0 to 60, the maximum both native SDKs allow. `duration` animates the change; omit it for the platform default. The call completes with `true` once the animation has run, or `false` if the platform cancelled it, which happens when another tracking-camera animation supersedes it or when the tracking mode is still transitioning.

A tracking mode other than `none` must already be active, so enable tracking first and set the tilt after. Calling it with tracking off throws a `PlatformException` with code `TRACKING_NOT_ACTIVE`.

!!! warning "Android and iOS only"
    Web throws an `UnsupportedError`. MapLibre GL JS has no location component, and its `GeolocateControl` gives up following the user on any programmatic camera change, so there is no way to pitch a tracking camera there. A pitch set *before* tracking starts does survive on web, since the control never writes the pitch itself.

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

### Fused location provider on Android

With high accuracy on Android (`enableHighAccuracy: true`, or `priority: LocationPriority.highAccuracy`), the plugin uses Google's fused location provider, which combines GPS with Wi-Fi and cell positioning. On devices without Google Play Services, such as Huawei devices without them, it uses the platform location manager instead: Android's own fused provider on Android 12 and later, GPS only before. Android's fused provider adds Wi-Fi and cell positioning only where the device has a network location provider, such as the vendor's or microG; without one it is GPS only too. Other priorities use the platform location engine either way.

### Building without Google Play Services

F-Droid and other FOSS builds cannot include Google Play Services. Add this line to your app's `android/gradle.properties`:

```properties title="android/gradle.properties"
maplibre_gl.playServicesLocation=false
```

The plugin then neither depends on Play Services location nor compiles the code that uses it, so nothing from Google is downloaded or ends up in the APK. High accuracy uses the platform location manager as described above. Where that means GPS only (Android 11 and earlier, or no network location provider), indoors there may be no fix at all.

#### F-Droid

F-Droid also scans the source of your dependencies, and its scanner matches the Play Services lines in the plugin's `build.gradle` even though the property turns them off. With the property set, those lines and the plugin's `src/gms` folder are unused, so the build recipe can remove them after `flutter pub get` and before the scan, for example in `prebuild`:

```bash
sed -i -e '/com\.google\.android\.gms/d' "$PUB_CACHE"/hosted/pub.dev/maplibre_gl-*/android/build.gradle
rm -rf "$PUB_CACHE"/hosted/pub.dev/maplibre_gl-*/android/src/gms
```

`PUB_CACHE` is the pub cache the recipe uses for `flutter pub get`. The app still builds the same way, and the F-Droid scanner then finds no Play Services in the source or in the APK.

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
| `controller.setTrackingCameraOptions` | pitch the camera without ending tracking (not on web) |
| `myLocationStyle` | colors of the dot, bearing arrow, accuracy circle and pulse |
| `myLocationRenderMode` | how heading is drawn: `normal`, `compass`, or `gps` (`gps` is not supported on iOS) |
| `locationSource` | `PlatformLocationSource` (default) or `ManualLocationSource` |
| `locationEnginePlatforms` | per-platform engine options, including iOS pulsing |
| `controller.updateManualLocation` | push a fix in manual mode |
| `controller.requestMyLocationLatLng` | read the last known position |
| `onUserLocationUpdated` | callback for every update, either source |

The example app's **Manual Location Source** page drives the puck around a simulated loop, with start and stop, single pushes, tracking-mode switching and a live accuracy ring. Its **GPS Location** page cycles the tracking modes and carries the tilt slider for `setTrackingCameraOptions`.
