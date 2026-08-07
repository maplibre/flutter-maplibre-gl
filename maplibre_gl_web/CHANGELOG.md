See top-level [CHANGELOG.md](../CHANGELOG.md) for full details.

## [0.27.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.26.2...v0.27.0)

### Added
* `queryCameraPosition()` is implemented; it used to throw `UnimplementedError` (#892).
* `updateContentInsets()` and the new `setPadding()` are implemented through the camera `padding` option; both used to throw `UnimplementedError` (#258).
* `getLayerProperties()` and `getSourceProperties()` read a layer's or source's properties from the live style, in the same shape as Android and iOS (#513).
* The manual location puck is drawn by the plugin, since maplibre-gl-js has no injectable location component. It reuses maplibre-gl-js' own user-location classes plus a bearing arrow, so it needs `maplibre-gl.css`, which the plugin loads with the library (#840).
* The plugin loads maplibre-gl-js itself before the first map is built, so apps should remove the script and stylesheet tags from `web/index.html`. It loads the exact build its interop is written against, or whatever `MapLibreMap.webLibrarySource` configures, and reuses an existing `maplibregl` global as it is. A failed stylesheet only logs, since it affects how the controls and the puck look and not the map; a failed import clears the memoized attempt so the next map build retries (#928).
* `MapLibreGlobalWeb` implements the new `MapLibreGlobalPlatform` at plugin registration, which is how `MapLibreMap.preWarm()` and `MapLibreMap.ensureWebLibraryLoaded()` get their web behaviour (#928).
* `getClusterExpansionZoom()`, `getClusterChildren()` and `getClusterLeaves()` read a clustered GeoJSON source. maplibre-gl-js 6 returns promises from all three, where version 5 took a trailing callback, so the interop is typed as promises. A rejection, which is how the library reports a source that is not clustered or an unknown cluster id, answers 0 or an empty list, matching Android and iOS (#896).
* `setTrackingCameraOptions()` throws an `UnsupportedError` naming the platform. maplibre-gl-js has no location component, and `GeolocateControl` stops following the user on any programmatic camera change it did not make itself, firing `trackuserlocationend`, which this package forwards as a tracking dismissal. Suppressing those events would report tracking that is no longer happening (#888).
### Changed
* MapLibre GL JS 5 replaced by 6. Version 6 ships as an ES module only, with no UMD bundle and no global of its own, so the loader imports it with `importModule` and publishes the namespace as `globalThis.maplibregl`, which is what every `@JS` binding here addresses. `MapLibreJsSource.urls` now points at the `.mjs` build, and a page using `MapLibreJsSource.preloaded` has to publish the global itself (#943).
* `setGeoJsonSource()` and `setFeatureForGeoJsonSource()` complete once the data has been applied, rather than as soon as it has been handed over. Version 6 returns a promise from `GeoJSONSource.setData` where version 5 returned the source, so the promise is awaited when there is one, which also stops a rejection on invalid GeoJSON from going unhandled (#943).
* The loader only publishes an imported namespace that carries the library. An older, non-module bundle imported as a module runs, exports nothing, and defines the global itself, so publishing that empty namespace would have replaced a working library with an empty object (#943).
* Missing style images are supplied through `Map.setMissingStyleImageResolver` instead of a `styleimagemissing` listener: since version 6 the listener can observe the request but calling `addImage` from it no longer resolves it, which would have silently stopped asset images from loading. The listener is kept as a fallback when the library on the page has no resolver, so a page still providing version 5 keeps working (#943).
* A map that comes up without a renderer now reports why through `FlutterError.reportError`, once per distinct cause. Version 6 requires WebGL2 and dropped the WebGL1 fallback, and rather than throwing like version 5 it fires an `error` from inside the constructor, too early to subscribe to, so the map would otherwise just be blank. The message tells a WebGL1 only browser apart from one with no WebGL at all, and names the version 5 build as the way out of the first (#943).

### Fixed
* `getFeatureState()` returns the state instead of throwing, and reports no state as null rather than as an empty map, matching Android. It converted the JS object with `dartify()` and cast the result to `Map<String, dynamic>`, which that conversion never produces, so every call that found a state threw (#889).
* `removeFeatureState(sourceId)` with no feature id resets the whole source. It built the target with `id: null`, and maplibre-gl-js only treats a missing id as "every feature of this source", so the call matched nothing and cleared nothing, without an error. A `stateKey` with no `featureId` now raises the same `INVALID_ARGUMENT` as Android instead of being ignored (#889).
* `onMapIdle` now fires, matching Android and iOS; code waiting on it never ran (#857).
* `querySourceFeatures()` raises `STYLE_NOT_READY` when the style has not loaded yet, instead of logging and answering with an empty list that the caller cannot tell apart from a source holding no features. The two `queryRenderedFeatures` calls keep answering with an empty list, since nothing is rendered yet either way. The debug print of the query parameters is gone too (#952).
* `queryRenderedFeaturesInRect()` decodes the JSON string filter before handing it to maplibre-gl-js, which accepts only the expression itself. The filter was ignored, so the call answered with every feature in the rectangle (#953).

## [0.26.2](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.26.1...v0.26.2)

No web-specific changes; version aligned with the `maplibre_gl` 0.26.2 release. See top-level [CHANGELOG.md](../CHANGELOG.md) for full details.

## [0.26.1](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.26.0...v0.26.1)

No web-specific changes; version aligned with the `maplibre_gl` 0.26.1 release. See top-level [CHANGELOG.md](../CHANGELOG.md) for full details.

## [0.26.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.25.0...v0.26.0)

### Breaking
* Upgraded MapLibre GL JS from 4.7.1 to 5.24.0 (#761, #651).
  * `initialCameraPosition` is now ignored if the map style contains camera properties (`center`, `zoom`, `bearing`, `pitch`). MapLibre GL JS v5 gives priority to style-defined camera values over constructor options. Use `MapLibreMapController.moveCamera()` or `MapLibreMapController.animateCamera()` after map load to override.
  * `preserveDrawingBuffer`, `antialias`, `failIfMajorPerformanceCaveat` now set via `canvasContextAttributes` (MapLibre GL JS v5 API change).
  * `on()`/`off()`/`once()` adapted for v5 `Subscription` return type.
  * Removed `customAttribution` from `MapOptionsJsImpl` (moved to `AttributionControl` options in v5).

### Added
* Exposed `onMouseMove` and added feature state management (`setFeatureState`, `getFeatureState`, `removeFeatureState`) (#718).
* Added `getLayerVisibility`, web snapshot, and map sizing features (#722).
* Added Scale Control (#720).
* Location engine properties support — `enableHighAccuracy`, `maximumAge`, `timeout` from `LocationEnginePlatforms.web()` passed to `GeolocateControl`'s `PositionOptions`.
* `trackUserLocation` on `GeolocateControl` managed based on `MyLocationTrackingMode`.
* `GeolocateControl.trigger()` called programmatically when tracking mode is enabled.
* `easeCamera` fully implemented via MapLibre GL JS `map.easeTo({easing})`; all four `CameraAnimationInterpolation` values are honored via cubic-bezier easing callbacks. Previously threw `UnimplementedError` (#789).
  * `easeInOut` → cubic-bezier `(0.42, 0, 0.58, 1)`
  * `easeOut` → cubic-bezier `(0, 0, 0.58, 1)`
  * `fastOutLinearIn` → cubic-bezier `(0.4, 0, 1, 1)` (Material Design)
  * `linear` → identity
  * Omitting the parameter falls through to MapLibre GL JS's built-in default curve.

### Changed
* `easeTo` wrapper on `MapLibreMap` now jsifies Dart `Map` options the same way `flyTo` already did, enabling the new `easeCamera` implementation to pass a plain Dart options dict.

### Fixed
* Improved `styleimagemissing` handling (#725).
* Fixed JS Interop and WASM compilation in release mode (#714).
* `removeLayer` and `removeSource` no longer throw when the layer/source doesn't exist.
* `setGeoJsonSource` returns early instead of crashing when the source doesn't exist.

## [0.25.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.24.1...v0.25.0) - 2026-01-07

### Major Changes

#### **BREAKING**: Migration to Modern JS Interop (#687)
* **WASM Compatible**: Migrated from deprecated `dart:js_util` to modern `dart:js_interop` API
* Required for Flutter 3.38.4+ compatibility
* Now fully compatible with Flutter's WASM compilation target
* **No public API changes** - this is an internal implementation update

#### Technical Details of JS Interop Migration:
* Replaced `dart:js_util` with `dart:js_interop` and `dart:js_interop_unsafe`
* Updated all JS interop classes to use `@staticInterop` + extension methods pattern
* Migrated from `@JS()` factory constructors to new interop model
* Converted `allowInterop()` callbacks to `.toJS`
* Updated property access from `getProperty()`/`setProperty()` to native JS property access
* Replaced `jsify()`/`dartify()` utilities to work with `JSAny`/`JSObject` types
* Fixed primitive type conversions: `JSString.toDart`, `JSNumber.toDartDouble`, `JSArray.toDart`
* Converted static methods to top-level functions (e.g., `LngLat.convert()` → `lngLatConvert()`)

### Added
* Implemented `getStyle()` - returns map style as JSON string (previously threw `UnimplementedError`)
* Implemented `getSourceIds()` - returns list of source IDs from current style
* Improved `getLayers()` - safely handles null styles and returns empty list instead of crashing

### Fixed
* Fixed `setPaintProperty` and `setLayoutProperty` to handle nullable `JSAny` values correctly (#12dfad2)
* Improved `jsify` function to create JS arrays correctly
* Enhanced error handling in `getLayer()`, `getFilter()`, and `isStyleLoaded()` with null-safety checks
* Fixed pattern images loading - all images now correctly converted to RGBA format (#9ce52a6)
  - Resolves mismatched image size errors when loading pattern images
  - Ensures consistent image format across all image uploads

### Refactor
* Improved null safety across the web platform
* Enhanced type safety for JS ↔ Dart conversions
* More descriptive error messages in the web implementation
* Example app improvements:
  - Maps now use responsive sizing (50-60% of screen height)
  - Removed fixed width constraints for full-screen responsiveness
  - Better button and control layouts

## [0.24.1](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.24.0...v0.24.1)

* Rollback maplibre-gl to `4.7.1` version. (#660)

## 0.24.0

### Refactor / Quality (web)
* Refactored `onMapClick` (degenerate bbox + interactive layer filter) so unmanaged style-layer features now trigger `onFeatureTapped` (feature id + layer id, `annotation = null`).
* Ensured map container stretches vertically by setting `style.height = '100%'` on the registered div to avoid zero-height issues in flexible layouts.

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

## 0.13.0, Oct 6, 2021

🎉 The first release of flutter-maplibre-gl with the complete transition to
MapLibre libraries. 🎉

### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.12.0

* Dependencies: updated image
  package [#598](https://github.com/tobrun/flutter-mapbox-gl/pull/598)
* Fix feature manager on release
  build [#593](https://github.com/tobrun/flutter-mapbox-gl/pull/593)
* Emit onTap only for the feature above the
  others [#589](https://github.com/tobrun/flutter-mapbox-gl/pull/589)
* Add annotationOrder to
  web [#588](https://github.com/tobrun/flutter-mapbox-gl/pull/588)

### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.11.0

* Fix Mapbox GL JS CSS embedding on
  web [#551](https://github.com/tobrun/flutter-mapbox-gl/pull/551)
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

## 0.9.0, October 24. 2020

* Breaking change: CameraUpdate.newLatLngBounds() now supports setting different
  padding values for left, top, right, bottom with default of 0 for all.
  Implementations using the old approach with only one padding value for all
  edges have to be
  updated. [#382](https://github.com/tobrun/flutter-mapbox-gl/pull/382)
* web:ignore myLocationTrackingMode if myLocationEnabled is
  false [#363](https://github.com/tobrun/flutter-mapbox-gl/pull/363)
* Add methods to access
  projection [#380](https://github.com/tobrun/flutter-mapbox-gl/pull/380)
* Listen to OnUserLocationUpdated to provide user location to
  app [#237](https://github.com/tobrun/flutter-mapbox-gl/pull/237)
* Get meters per pixel at
  latitude [#416](https://github.com/tobrun/flutter-mapbox-gl/pull/416)

## 0.8.0, August 22, 2020

- implementation of feature
  querying [#177](https://github.com/tobrun/flutter-mapbox-gl/pull/177)
- Allow setting accesstoken in
  flutter [#321](https://github.com/tobrun/flutter-mapbox-gl/pull/321)
- Batch create/delete of
  symbols [#279](https://github.com/tobrun/flutter-mapbox-gl/pull/279)
- Set dependencies from
  git [#319](https://github.com/tobrun/flutter-mapbox-gl/pull/319)
- Add multi map
  support [#315](https://github.com/tobrun/flutter-mapbox-gl/pull/315)

## 0.7.0

- Initial version
