## [0.27.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.26.2...v0.27.0)

See top-level [CHANGELOG.md](../CHANGELOG.md) for full details.

### Added
* `getLayerProperties(layerId)` and `getSourceProperties(sourceId)`, returning a layer's or source's properties as a style-spec map, or `null` for an unknown id (#513).
* `LocationEnginePlatforms.iOS` accepts `intervalMs` and `pulseWindowMs`, forwarded to the iOS location engine so GPS can be pulsed instead of tracked continuously (#901).
* An app-provided location source: `LocationSource` with `ManualLocationSource` and `PlatformLocationSource`, the `ManualLocationUpdate` model, and the `setLocationSource` and `updateManualLocation` calls (#840).
* `MapLibreJsSource`, describing where the web implementation loads MapLibre GL JS from. It lives here so apps can configure it through `maplibre_gl` without importing the web package; Android and iOS ignore it (#928).
* `MapLibreGlobalPlatform`, for calls global to the plugin rather than tied to a single map, with `MapLibreGlobalMethodChannel` as the default. The web package replaces the instance at registration, which is what routes `preWarm()` and `ensureWebLibraryLoaded()` to the web implementation (#928).
* `setFeatureState`, `removeFeatureState` and `getFeatureState` are forwarded over the channel instead of throwing `UnimplementedError`, so feature state works on Android. iOS throws an `UnsupportedError` naming the platform (#889).
* `getClusterExpansionZoom`, `getClusterChildren` and `getClusterLeaves`, forwarded over the channel as `source#getCluster*`. Each takes the cluster's integer `cluster_id`; the two feature calls decode a list of JSON strings, as `querySourceFeatures` does, so nested properties survive the channel (#896).
* `setTrackingCameraOptions` on `MapLibrePlatform`, forwarded over the channel as `locationComponent#setTrackingCameraOptions` with a `tilt` and an optional `duration`. It answers with whether the pitch animation ran (#888).
### Fixed
* A large GeoJSON payload is encoded on a background isolate instead of blocking the UI for the whole encode; smaller ones keep the faster synchronous path, and writes to the same source id stay in the order they were issued (#366).

## [0.26.2](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.26.1...v0.26.2)

No platform-interface changes; version aligned with the `maplibre_gl` 0.26.2 release. See top-level [CHANGELOG.md](../CHANGELOG.md) for full details.

## [0.26.1](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.26.0...v0.26.1)

See top-level [CHANGELOG.md](../CHANGELOG.md) for full details.

### Fixed
* **Android**: Forward `textureMode` through the method channel so hybrid composition can enable it when necessary (#816).

## [0.26.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.25.0...v0.26.0)

See top-level [CHANGELOG.md](../CHANGELOG.md) for full details.

### Breaking
* `initialCameraPosition` is now nullable to support style-defined camera options (#769).
* `LocationEnginePlatforms` unnamed constructor is now private. Use `.android()`, `.iOS()`, `.web()`, or `.defaultPlatform`.
* Removed `LocationEngineAndroidProperties`. All fields flattened into `LocationEnginePlatforms` with nullable platform-specific fields.
* `MapLibrePlatform.easeCamera` gained an optional named parameter `CameraAnimationInterpolation? interpolation`. Callers are unaffected, but subclasses that override `easeCamera` must add the new parameter to their signature (#789).

### Added
* Cross-platform map snapshot functionality via `takeSnapshot()` (#726).
* `featureTapsTriggersMapClick` option to control whether feature taps also trigger map click callbacks (#729).
* Feature state management APIs (`setFeatureState`, `getFeatureState`, `removeFeatureState`) (#718).
* Platform-specific constructors: `LocationEnginePlatforms.android()`, `.iOS()`, `.web()`.
* iOS and web serialization support in `toList()`.
* Expanded unit tests for platform-specific serialization and constructor behavior.
* `CameraAnimationInterpolation` enum (`linear`, `easeInOut`, `easeOut`, `fastOutLinearIn`) and corresponding `interpolation` parameter on the `camera#ease` method channel (#789).

### Changed
* Updated to align with main package v0.26.0.

## [0.25.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.24.1...v0.25.0) - 2026-01-07

See top-level [CHANGELOG.md](../CHANGELOG.md) for full details.

### Changed
* Updated to align with main package v0.25.0.
* No breaking changes to the platform interface in this release.

## [0.24.1](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.24.0...v0.24.1)

See top-level CHANGELOG.md

## 0.23.0

> Note: This release has breaking changes.

see top-level CHANGELOG.md

## newer releases

see top-level CHANGELOG.md

## 0.15.1, May 24, 2022

see top-level CHANGELOG.md

## 0.15.0, Oct 26, 2021

see top-level CHANGELOG.md

## 0.14.0, Oct 14, 2021

### Breaking changes:

* Replace example
  styles [#25](https://github.com/m0nac0/flutter-maplibre-gl/pull/25) (also
  see [#21](https://github.com/m0nac0/flutter-maplibre-gl/issues/21))
    * The built-in constants for specific styles were removed. You can continue
      using these styles by using the styles' URL

## 0.13.0, Oct 6, 2021

🎉 The first release of flutter-maplibre-gl with the complete transition to
MapLibre libraries. 🎉

### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.12.0

* Batch creation/removal for circles, fills and
  lines [#576](https://github.com/tobrun/flutter-mapbox-gl/pull/576)

### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.11.0

* Add batch mode of screen
  locations [#554](https://github.com/tobrun/flutter-mapbox-gl/pull/554)

## Below is the original changelog of the tobrun/flutter-mapbox-gl project, before the fork.

## 0.10.0, February 12, 2020

* Added web support for
  fills [#501](https://github.com/tobrun/flutter-mapbox-gl/pull/501)
* Add heading to UserLocation and expose UserLocation
  type [#522](https://github.com/tobrun/flutter-mapbox-gl/pull/522)
* Update tracked camera position in
  camera#onIdle [#500](https://github.com/tobrun/flutter-mapbox-gl/pull/500)
* Improved Image Source
  Support [#469](https://github.com/tobrun/flutter-mapbox-gl/pull/469)

## 0.9.0, October 24, 2020

* Breaking change: CameraUpdate.newLatLngBounds() now supports setting different
  padding values for left, top, right, bottom with default of 0 for all.
  Implementations using the old approach with only one padding value for all
  edges have to be
  updated. [#382](https://github.com/tobrun/flutter-mapbox-gl/pull/382)
* Add methods to access
  projection [#380](https://github.com/tobrun/flutter-mapbox-gl/pull/380)
* Add fill API support for Android and
  iOS [#49](https://github.com/tobrun/flutter-mapbox-gl/pull/49)
* Listen to OnUserLocationUpdated to provide user location to
  app [#237](https://github.com/tobrun/flutter-mapbox-gl/pull/237)
* Add support for custom font stackn in symbol
  options [#359](https://github.com/tobrun/flutter-mapbox-gl/pull/359)
* Basic ImageSource
  Support [#409](https://github.com/tobrun/flutter-mapbox-gl/pull/409)
* Get meters per pixel at
  latitude [#416](https://github.com/tobrun/flutter-mapbox-gl/pull/416)

## 0.8.0, August 22, 2020

- implementation of feature
  querying [#177](https://github.com/tobrun/flutter-mapbox-gl/pull/177)
- Batch create/delete of
  symbols [#279](https://github.com/tobrun/flutter-mapbox-gl/pull/279)
- Add multi map
  support [#315](https://github.com/tobrun/flutter-mapbox-gl/pull/315)
- Add line#getGeometry and
  symbol#getGeometry [#281](https://github.com/tobrun/flutter-mapbox-gl/pull/281)

## 0.7.0

- Initial version
