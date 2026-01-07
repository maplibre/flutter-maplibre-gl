See top-level [CHANGELOG.md](../CHANGELOG.md) for full details.

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
