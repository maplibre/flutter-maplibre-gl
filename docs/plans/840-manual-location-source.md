# Plan: App-provided / manual location source (issue #840)

Tracking issue: https://github.com/maplibre/flutter-maplibre-gl/issues/840
Milestone: 0.27.0
Branch: `feature/840-manual-location-display`

## Goal & approach

Let the Flutter app feed its own location updates into the map's **existing**
user-location component (the puck), instead of the SDK's native location engine
— while keeping accuracy ring, tracking modes, and `onUserLocationUpdated`
working.

Chosen API:

- **Declarative selector:** `MapLibreMap(locationSource: ManualLocationSource(), myLocationEnabled: true, ...)`.
- **Imperative push:** `controller.updateManualLocation(ManualLocationUpdate(...))`.
- **Scope:** Android + iOS implemented natively; **web throws `UnsupportedError`**.
- **Model:** new `ManualLocationUpdate` class.

Both native SDKs already support this (verified): Android
`LocationComponent.forceLocationUpdate(Location)` + `useDefaultLocationEngine(false)`
(SDK 13.3.0); iOS custom `MLNLocationManager` via settable `mapView.locationManager`
(SDK 6.27.0). No SDK upgrades needed.

## Wire-protocol additions (keep all 4 layers in sync)

1. **New option key** `locationSource` carrying a string token (`"manual"` /
   `"platform"`) produced by a `switch` expression over the `LocationSource` at the
   platform-channel boundary, inside the existing `options` map (`map#update` /
   creation params). The token → behavior mapping lives only on the native side.
2. **New method-channel method** `locationComponent#setManualLocation` (Dart→native)
   carrying the serialized `ManualLocationUpdate`.

Serialization mirrors existing conventions: `LatLng` → `[lat,lng]`, timestamp →
epoch ms, enums → `.index`.

## 1. New shared Dart types — `maplibre_gl_platform_interface`

**New file `maplibre_gl_platform_interface/lib/src/location_source.dart`**
(add `part 'src/location_source.dart';` to `maplibre_gl_platform_interface.dart:11-23`):

```dart
@immutable
sealed class LocationSource {        // Dart SDK is >=3.7, sealed OK
  const LocationSource();
}
class PlatformLocationSource extends LocationSource {   // default native engine
  const PlatformLocationSource();
}
class ManualLocationSource extends LocationSource {      // app-provided
  const ManualLocationSource();
}
```

The classes are pure markers — **no `wireValue` / serialization logic lives on them.**
A `switch` expression at the serialization boundary (§2) converts the source to a
string token; deciding what each token *means* (engine vs. no-engine activation) is
done exclusively on the native side (§3 Android, §4 iOS).

**Append to `maplibre_gl_platform_interface/lib/src/location.dart`**
(after `UserLocation`, ~line 232) a `ManualLocationUpdate` mirroring the issue's shape:

```dart
class ManualLocationUpdate {
  final LatLng target;                 // required
  final double? horizontalAccuracy;
  final double? verticalAccuracy;
  final double? altitude;
  final double? bearing;               // direction of travel (GPS arrow)
  final double? speed;
  final DateTime? timestamp;
  const ManualLocationUpdate({required this.target, ...});
  Map<String, dynamic> toMap() => { 'position':[target.latitude,target.longitude],
    'horizontalAccuracy':..., 'timestamp': (timestamp ?? DateTime.now()).millisecondsSinceEpoch, ... };
}
```

(No separate `heading` field: compass-render heading is device-sensor driven on
both platforms; `bearing` covers GPS direction. Documented below.)

**Abstract platform contract**
`maplibre_gl_platform_interface/lib/src/maplibre_gl_platform_interface.dart`
(near `updateMyLocationTrackingMode`, line 108):

```dart
Future<void> setManualLocation(ManualLocationUpdate update);
```

**Method channel** `method_channel_maplibre_gl.dart` (near line 228):

```dart
@override
Future<void> setManualLocation(ManualLocationUpdate update) =>
  _channel.invokeMethod('locationComponent#setManualLocation', update.toMap());
```

## 2. Public API — `maplibre_gl`

**`maplibre_gl/lib/src/maplibre_map.dart`:**

- Add field `final LocationSource locationSource;`, constructor default
  `this.locationSource = const PlatformLocationSource()` (near line 20/80). Add doc
  noting it requires `myLocationEnabled: true`.
- `MapLibreMapOptions`: add field + `fromWidget` mapping (lines 454/462) + serialize
  in `toMap()` (after line 599) by converting the source to a string token with a
  `switch` expression at the platform-channel boundary (no `wireValue` on the model):

  ```dart
  addIfNonNull('locationSource', switch (locationSource) {
    ManualLocationSource() => 'manual',
    PlatformLocationSource() => 'platform',
  });
  ```

  The native side maps the `'manual'`/`'platform'` token to actual location-component
  behavior (§3/§4).

**`maplibre_gl/lib/src/controller.dart`** (near `requestMyLocationLatLng`, line 1639):

```dart
/// Pushes an app-provided location into the user-location component.
/// Requires the map to be created with `locationSource: ManualLocationSource()`.
Future<void> updateManualLocation(ManualLocationUpdate update) =>
  _maplibrePlatform.setManualLocation(update);
```

**Re-exports** `maplibre_gl/lib/maplibre_gl.dart` (lines 50-90): export
`LocationSource`, `PlatformLocationSource`, `ManualLocationSource`,
`ManualLocationUpdate`.

## 3. Android — `maplibre_gl/android/.../MapLibreMapController.java`

- Add field `private boolean manualLocationSource = false;` (~line 140).
- **`MapLibreMapOptionsSink.kt`** + **`Convert.java`** (parse `locationSource` ~line 225)
  + **`MapLibreMapBuilder.java`**: add `setLocationSource(String token)`. The **mapping
  lives here, native-side**: resolve `this.manualLocationSource = "manual".equals(token);`.
  Any other value (`"platform"`/unknown) resolves to the default native engine.
- **`enableLocationComponent` (lines 320-342)** — branch on the flag and bypass
  permission gate in manual mode:

  ```java
  if (manualLocationSource || hasLocationPermission()) {
    LocationComponentActivationOptions.Builder b =
        LocationComponentActivationOptions.builder(context, style)
          .locationComponentOptions(buildLocationComponentOptions(style));
    if (manualLocationSource) b.useDefaultLocationEngine(false);
    else b.locationEngine(myLocationEngineFactory.getLocationEngine(context));
    locationComponent.activateLocationComponent(b.build());
    ... // enable, modes, listener unchanged
  }
  ```

- **`startListeningForLocationUpdates` (2618-2638):** already no-ops when
  `getLocationEngine()==null`, so safe in manual mode (Flutter callback is fired
  manually instead — below).
- **New handler in `onMethodCall`** (near line 1603) `locationComponent#setManualLocation`:
  build `android.location.Location` from args, then:

  ```java
  locationComponent.forceLocationUpdate(location);
  onUserLocationUpdate(location);   // keeps map#onUserLocationUpdated working
  result.success(null);
  ```

- **`locationComponent#getLastLocation` (1603-1639):** in manual mode use
  `locationComponent.getLastKnownLocation()` (no engine).

## 4. iOS — `maplibre_gl/ios/.../`

- **New file `ManualLocationManager.swift`**: `class ManualLocationManager: NSObject, MLNLocationManager`
  storing `delegate`, returning authorized `authorizationStatus`, no-op start/stop,
  and `func push(_ loc: CLLocation) { delegate?.locationManager(self, didUpdateLocations: [loc]) }`.
- **`MapLibreMapController.swift`**: add `manualLocationSource` flag; `Convert.swift`
  (~50-62) + `MapLibreMapOptionsSink.swift` parse/set it. The **token → behavior mapping
  lives here, native-side** (e.g. `manualLocationSource = (token == "manual")`;
  any other value falls back to the default manager). Before `showsUserLocation`
  is first enabled (per SDK ordering rule — in init/apply ~lines 150-171, and guard in
  `updateMyLocationEnabled` line 1371), if manual:
  `mapView.locationManager = manualLocationManager`.
- **New `onMethodCall` case** (near lines 330-344) `locationComponent#setManualLocation`:
  build `CLLocation` from args, call `manualLocationManager.push(loc)`. Existing
  `mapView(_:didUpdate:)` (1602-1611) auto-fires `map#onUserLocationUpdated` — no
  manual forwarding needed.
- `locationComponent#getLastLocation` already reads `mapView.userLocation` — works
  unchanged.

## 5. Web — unsupported (explicit)

- **`maplibre_gl_web/lib/src/options_sink.dart`**: add `void setLocationSource(String token);`
- **`maplibre_gl_web/lib/src/convert.dart`**: parse `locationSource` → call sink.
- **`maplibre_gl_web/lib/src/maplibre_web_gl_platform.dart`**: web is also a platform
  impl, so it resolves the token here; `setLocationSource` → `debugPrint` warning when the
  token is the manual source (no-op); `setManualLocation` →
  `throw UnsupportedError('Manual location source is not supported on web')`.

## 6. Example app

- **New `maplibre_gl_example/lib/examples/basics/manual_location_source_page.dart`**:
  map with `myLocationEnabled: true`, `locationSource: ManualLocationSource()`,
  `myLocationTrackingMode: trackingGps`; a button/`Timer` simulating a moving track
  via `controller.updateManualLocation(...)`; shows `onUserLocationUpdated` value.
- **Register** in `maplibre_gl_example/lib/main.dart` (import + add
  `const ManualLocationSourcePage()` to the list near line 123).

## 7. Tests

- `maplibre_gl/test/helpers/fake_platform.dart`: implement `setManualLocation`
  (record call) — **required** or tests won't compile.
- New `maplibre_gl/test/manual_location_source_test.dart`: (a) `ManualLocationSource()`
  serializes `locationSource:'manual'` into creation-params options; (b)
  `controller.updateManualLocation(...)` calls `setManualLocation` with correct payload.
- `maplibre_gl_platform_interface/test/location_test.dart`: `ManualLocationUpdate.toMap()`
  serialization (incl. null-field omission, timestamp ms).

## 8. Docs & housekeeping

- `CHANGELOG.md`: add entry (milestone 0.27.0).
- Doc comments: manual source needs `myLocationEnabled: true`; **no location
  permission required** in manual mode; `MyLocationRenderMode.gps` arrow stays
  Android-only; compass heading is device-sensor driven (use `bearing` for GPS
  direction).

## Known limitations / decisions to confirm during build

- **Runtime source switching:** `locationSource` is applied at component activation.
  Changing it after creation won't re-activate the component (documented). Switching
  the live source can be a follow-up (deactivate+reactivate).
