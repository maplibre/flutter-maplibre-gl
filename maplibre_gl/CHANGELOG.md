## [0.25.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.24.1...v0.25.0) - 2026-01-07

### Added
* Logo customization options including visibility and position settings (#b4fb174).
* Explicit annotation manager initialization with clear error handling (#668).
* iOS: Attribution support for tile and raster sources with HTML link parsing.

### Changed
* MapLibre Android SDK upgraded from `11.13.5` to `12.3.0` (#690).
  - Includes synchronous GeoJSON source updates
  - Support for MLT-format vector tile sources
  - Better frustum offset support
  - See [MapLibre Native Android 12.3.0 release notes](https://github.com/maplibre/maplibre-native/releases/tag/android-v12.3.0)
* OkHttp updated from `4.12.0` to `5.3.2` for Node.js 24 compatibility (#676, #700).
* Kotlin updated to `2.3.0` (#697, #698).
* Android Gradle Plugin updated to `8.13.2` (#695, #674).
* Android Application Plugin updated to `8.13.2` (#696, #689).
* GitHub Actions: `actions/checkout` updated from v5 to v6 (#672, #693).
* GitHub Actions: `actions/upload-artifact` updated from v4 to v6 (#688, #694).

### Fixed
* Min/max zoom preference on iOS (#5230fab).
* `queryRenderedFeatures` now returns all targets when supplying empty layers list on iOS, aligning behavior with Android (#680).
* iOS: Enhanced LayerPropertyConverter to handle null values and improve expression parsing (#98660dc).
* Fixed `lineDasharray` and patterns reset to null in layer properties (#2b550ed).
* Improved MapLibreMapController disposing to prevent memory leaks.
* Removed unnecessary disposing of mapController in example app (#f989797).
* Fixed `setLayerProperties` and pattern images on web and Android (#9ce52a6).
  - Pattern images now correctly converted to RGBA format on web
  - Fixed mismatched image size error when loading pattern images

### Refactor
* Complete refactor of example app with new UI and improved user experience (#ac877a4).
* Refactored `cameraTargetBounds` implementation on Android and iOS for consistent behavior (#8bcd74a).

**Full Changelog**: [v0.24.1...v0.25.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.24.1...v0.25.0)

## [0.24.1](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.24.0...v0.24.1)

### Fixed
* Annotation tap call callbacks twice. (#652)
* Annotation APIs: use null-aware access for manager-backed collections (symbols, lines, circles, fills) to avoid null errors before style load. (#657)
* Add methods enforce explicit manager initialization with clear exceptions when style is not loaded. (#657)
* Calling add* before style load now fails fast with a clear Exception instead of risking null dereferences or silent failures. (#657)

### Changed
* Rollback maplibre-gl to `4.7.1` version. (#660)

### Added
* Added `onCameraMove` callback in the controller and in MapLibreMap class. (#643)

## [0.24.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.23.0...v0.24.0)
> **Note**: This release has breaking changes.\
> We apologize for the quick change in 0.24.0: this version definitively stabilizes the signatures of feature interaction callbacks.

This release restores the  **feature id** and makes the `Annotation` parameter **nullable** for all feature interaction callbacks (`tap` / `drag` / `hover`).\
This unblocks interaction with style-layer features not managed by annotation managers (i.e. added via `addLayer*` / style APIs).

### Breaking Changes
 * **Tap**: `OnFeatureInteractionCallback` → `(Point<double> point, LatLng coordinates, String id, String layerId, Annotation? annotation)`.

* **Drag**: `OnFeatureDragCallback` → `(Point<double> point, LatLng origin, LatLng current, LatLng delta, String id, Annotation? annotation, DragEventType eventType)`.

* **Hover**: `OnFeatureHoverCallback` → `Point<double> point, LatLng coordinates, String id, Annotation? annotation, HoverEventType eventType)`.

* **Update existing listeners**: The short‑lived 0.23.0-only signatures (without `id`) are removed.
  * For unmanaged style layer features `annotation` is `null` (`unmanaged` means sources/layers you add via style APIs like `addGeoJsonSource` + `addSymbolLayer`).
  * For managed annotations it is the `Annotation` object.

### Reasoning
In 0.23.0 the move to annotation objects inadvertently dropped interaction for unmanaged style features. Reintroducing `id` (and making `annotation` nullable) normalizes all three interaction paths without creating phantom annotation wrappers.

### Migration Example
Before (0.23.0):
```
controller.onFeatureTapped.add((p, latLng, annotation, layerId) {
  print(annotation.id);
});
```
After (>=0.24.0):
```
controller.onFeatureTapped.add((p, latLng, id, layerId, annotation) {
  print('feature id=$id managed=${annotation != null}');
});
```

### Refactor / Quality
* (web) Refactored `onMapClick` (degenerate bbox + interactive layer filter) to surface features inserted via style APIs (unmanaged style-layer features) in `onFeatureTapped` (previously skipped; returned now with `id`, `layerId` and `annotation = null`) (#646).
* (web) Ensure map container stretches vertically by adding `style.height = '100%'` to the registered div (prevents occasional zero-height layout issues in flexible parents) (#641)

**Full Changelog**: [v0.23.0...v0.24.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.23.0...v0.24.0)

## [0.23.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.22.0...v0.23.0)
> **Note**: This release has breaking changes.

This release aligns the plugin with the latest MapLibre Native (Android 11.9.0 / iOS 6.14.0), introduces runtime style switching APIs, hover interaction callbacks, and several annotation interaction improvements. It also contains a small breaking change for feature interaction callbacks.

A big thank you to everyone who contributed to this update!

### Breaking Changes
* `onFeatureDrag` / `onFeatureTapped` callback signatures now provide an `Annotation annotation` object instead of an `id` parameter. Update your handlers to remove the `id` argument and use `annotation.id` (or other annotation fields) as needed.

### Highlights
* Runtime style switching via controller (`setStyle…`) without tearing down the map (#444, #603).
* Hover interaction events (`onFeatureHover`) for richer desktop/web UX (#614).
* Improved event handling reliability (cancellation & consumption fixes) (#621, #623).
* Offline region download crash fix in example (#569) and style loaded safety checks (#563).
* Updated MapLibre Native bringing PMTiles & performance improvements (#552, #582).

### Added / Updated
* **Feature:** added set style method on controller (#444) & support setting raw style JSON on iOS/web (#603).
* **Feature:** expose hovering events (`onFeatureHover`) (#614).
* **Update:** bump Android to 11.9.0 & iOS to 6.14.0 (#582).
* **Update:** update maplibre-native to the latest versions / PMTiles support (#552).
* **CI/Tooling:** upgrade Flutter Gradle Plugin & compatibility with Flutter 3.29.0 (#542).

### Fixed
* iOS code generation: corrected handling of Offset / Translate / expression arrays in generated bindings (#481).
* Annotation tap consumption now respected (`annotationConsumeTapEvents`).
* Prevent calling `notifyListeners()` after controller disposal (#621).
* Web: event listener cancellation & hover handling robustness (#623).
* Example: offline region download crash (#569).
* Added style readiness checks before access (#563).

### Refactor / Quality
* Enable and fix additional lint rules to enforce consistency (#452).

**Full Changelog**: [v0.22.0...v0.23.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.22.0...v0.23.0)

## [0.22.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.21.0...v0.22.0)

### Breaking changes

* Updated maplibre-native for iOS to v6.14.0. This mainly introduces PMTiles support. See the
  [maplibre-native changelog](https://github.com/maplibre/maplibre-native/blob/main/platform/ios/CHANGELOG.md#6121)
  for more information.
* Updated maplibre-native for Android to v11.9.0. This mainly introduces PMTiles support.
  Flutter version packed with OpenGL ES 3.0 build for now, later we could probably switch to Vulkan.
  See the [maplibre-native changelog](https://github.com/maplibre/maplibre-native/blob/main/platform/android/CHANGELOG.md#1181)
  for more information.
* queryRenderedFeaturesInRect support string feature ids on web (#576).

### Changed

* Added `await` to all `addLayer` calls (#558).

### Fixed

* Fixed `Unsupported operation` error on web (#551).

## [0.21.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.20.0...v0.21.0)

### Added

* added the `clearAmbientCache` functionality (#502).
* added the `contains` functionality to `LatLngBounds` (#498).
* added the possibility to set `LocationEnginePlatforms` properties for better device tracking on Android (#510).

### Changed

* BREAKING: `onFeatureTap` returns the `layerId` (#475).
* Changed iOS package name to support Swift Package Manager (#467).
* Move the `maplibre_gl` package to a subdirectory of the repository and add 
  melos to orchestrate all packages (#453).

### Removed

* Removed support for Dart SDKs older than `3.4.0` (`Flutter SDK 3.22.0`) (#542)

### Fixed

* Fixed exception when destroying mapView on Android by reordering cleanup (#459).


## 0.20.0

A lot of files/classes have been renamed and moved around in this release.
If you notice any build errors, please make sure to run `flutter clean`.

### Breaking changes

* All Dart enums have been migrated from mixed cases to lower camelcase
  according to the `camel_case_types` lint rule.
* Move `MapLibreStyles` to the main `maplibre_gl` package. You can now use the  
  demo style without adding `maplibre_gl_platform_interface` as a dependency.
* Updated maplibre-native for ios to v6.5.0. This introduces the new
  iOS Metal renderer and the OpenGL ES renderer now uses OpenGL ES 3.0. Only
  iOS Devices with an Apple A7 GPU or later are supported onwards. See the
  [maplibre-native changelog](https://github.com/maplibre/maplibre-native/blob/main/platform/ios/CHANGELOG.md#600)
  for more information.
* Updated maplibre-native for android to v11.0.0. This version uses
  OpenGL ES 3.0. See the
  [maplibre-native changelog](https://github.com/maplibre/maplibre-native/blob/main/platform/android/CHANGELOG.md#1100)
  for more information.
* Renamed the method channel to `plugins.flutter.io/maplibre_gl_*` in all
  packages.
* Renamed "Maplibre" to "MapLibre" to be in line with maplibre-native 
  (affects for example the classes `MaplibreMap` and `MaplibreMapController`).

### Changes

* Added support for Swift Package Manager usage on iOS.
* Migrated main iOS plugin class from Objective-C to Swift.
* Renamed iOS plugin classes from `Mapbox` to `MapLibre`.
* Removed support for Kotlin versions older than `1.9.0` (#460).

**Full Changelog**:
[v0.19.0+2...v0.20.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.19.0+2...v0.20.0)

## 0.19.0

This is the first version where all packages are published on pub.dev. Please
use the `maplibre_gl` package directly from pub.dev from now on. Check the
`README` documentation on how to include it in your project.

### Changes

* Bump min Dart SDK to 3.0.0 (this was already implicitly required by transitive
  dependencies)
* Prepare all packages for publishing
  to [pub.dev](https://pub.dev/packages/maplibre_gl)
* Add support for
  the [Fill Extrusion layer](https://maplibre.org/maplibre-style-spec/layers/#fill-extrusion)
* Add support for
  the [Heatmap layer](https://maplibre.org/maplibre-style-spec/layers/#heatmap)
* Update documentation
* (android) Bump Android `compileSdkVersion` to 34
* (iOS) Add `iosLongClickDuration` as parameter to customize the long click
  duration.
* (web) Loosen the dependency constraint of [js](https://pub.dev/packages/js) to
  allow `0.6.x` and `0.7.x`.

### Bug Fixes

* (android) Fix support for newer gradle versions (Add support for Gradle/AGP
  namespace configuration)
* (android) Fix `NullPointerException` when changing the visibility of a layer (
  layer#setVisibility)
* (android) Fix enum parsing for the `onCameraTracking` callback
* (iOS) Fix tap detection on features if the feature id is null
* (web) Fix flickering when the style takes time to load

**Full Changelog**:
[0.18.0...v0.19.0](https://github.com/maplibre/flutter-maplibre-gl/compare/0.18.0...v0.19.0)

## 0.18.0

### Breaking Change:

Already since 0.17.0, developers do not need to adapt their Podfile for iOS apps
anymore as it was previously described in the Readme. Developers who previously
added these lines should remove them, since not removing these lines may cause a
build failure on iOS. (This change actually already landed in 0.17.0, but it may
not have been sufficiently clear that not removing these lines might break
builds).

### Other Changes:

* new feature: set arbitrary layer properties by @m0nac0
  in [#303](https://github.com/maplibre/flutter-maplibre-gl/pull/303)
* Update release process by @m0nac0
  in [#315](https://github.com/maplibre/flutter-maplibre-gl/pull/315)
* Add workflows for automated publishing to pub.dev by @m0nac0
  in [#328](https://github.com/maplibre/flutter-maplibre-gl/pull/328)
* Fix example app pubspec by @m0nac0
  in [#329](https://github.com/maplibre/flutter-maplibre-gl/pull/329)
* Updated location plugin version for example app by @varunlohade
  in [#334](https://github.com/maplibre/flutter-maplibre-gl/pull/334)
* Housekeeping: Improve docs and update outdated references to point to MapLibre
  by @m0nac0 in [#330](https://github.com/maplibre/flutter-maplibre-gl/pull/330)

**Full Changelog**:
[0.17.0...0.18.0](https://github.com/maplibre/flutter-maplibre-gl/compare/0.17.0...0.18.0)

## 0.17.0

* **Repository transfer**: The project repository was transferred to the
  MapLibre GitHub organization. More information
  at [#221](https://github.com/maplibre/flutter-maplibre-gl/issues/221)
* Developers do not need to adapt their Podfile for iOS apps anymore as it was
  previously described in the
  Readme. [#278](https://github.com/maplibre/flutter-maplibre-gl/pull/278)

### Breaking Change:

* `maplibre_gl/mapbox_gl.dart` was renamed to `maplibre_gl/maplibre_gl.dart`.
  You can do a replace-all from `import 'package:maplibre_gl/mapbox_gl.dart';`
  to `import 'package:maplibre_gl/maplibre_gl.dart';`
* `useDelayedDisposal` was removed since its now fixed
  in [#259](https://github.com/maplibre/flutter-maplibre-gl/pull/259)
* `useHybridCompositionOverride` was removed since it was added in the following
  fix: [#203](https://github.com/maplibre/flutter-maplibre-gl/pull/203) and we
  reverted
  the fix and used another approach to fix the actual issue.
* The default for `myLocationRenderMode` was changed from `COMPASS` to `NORMAL`
  in [#244](https://github.com/maplibre/flutter-maplibre-gl/pull/244), since the
  previous default value of `COMPASS` implicitly enables displaying the location
  on iOS, which could crash apps that didn't want to display the device
  location. If you want to continue to use `MyLocationRenderMode.COMPASS`,
  please explicitly specify it in the constructor like this:

```dart
@override
Widget build() {
  return MapLibreMap(
    myLocationRenderMode: MyLocationRenderMode.COMPASS,
    // ...
  );
}
```

* The old api `registerWith` was removed from the MapboxMapsPlugin.java, since
  there is no need for that.
* The `minSdkVersion` was bumped to at least 21 now, since the native android
  sdk constraint expect that.
* Changed the minimum Dart version from sdk: `2.12.0` to `2.14.0`
  in `maplibre_gl_platform_interface/pubspec.yaml`.

### Further changes

Note: This list only contains a subset of all contributions, notably excluding
those that e.g. only affect the GitHub Actions CI or documentation. See the link
at the end for a full changelog.

* feat: add support for reading style json from file in ios by @TimAlber
  in [#132](https://github.com/maplibre/flutter-maplibre-gl/pull/132)
* Add podspecs in correct Cocoapods layout by @kuhnroyal
  in [#128](https://github.com/maplibre/flutter-maplibre-gl/pull/128)
* fix: fix the queryRenderedFeatures code on iOS by @TimAlber
  in [#137](https://github.com/maplibre/flutter-maplibre-gl/pull/137)
* feat: Set layer visibility by @m0nac0
  in [#138](https://github.com/maplibre/flutter-maplibre-gl/pull/138)
* feat: add support for changing the receiver’s viewport to fit given bounds by
  @TimAlber in [#133](https://github.com/maplibre/flutter-maplibre-gl/pull/133)
* Change feature JSON encoding from .ascii to .utf8 by @SunBro-Marko
  in [#142](https://github.com/maplibre/flutter-maplibre-gl/pull/142)
* web: implement setCameraBounds by @m0nac0
  in [#145](https://github.com/maplibre/flutter-maplibre-gl/pull/145)
* Use offical maplibre-gl.js and add README info by @Robbendebiene
  in [#163](https://github.com/maplibre/flutter-maplibre-gl/pull/163)
* android: adding tileSize to raster source by @mariusvn
  in [#166](https://github.com/maplibre/flutter-maplibre-gl/pull/166)
* Readme: document git default values for codespaces by @m0nac0
  in [#170](https://github.com/maplibre/flutter-maplibre-gl/pull/170)
* query source features by @Grodien
  in [#154](https://github.com/maplibre/flutter-maplibre-gl/pull/154)
* Trimming styleString to simplify the JSON detection by @mariusvn
  in [#175](https://github.com/maplibre/flutter-maplibre-gl/pull/175)
* Fix getVisibleRegion method by @BartoszStasiurka
  in [#179](https://github.com/maplibre/flutter-maplibre-gl/pull/179)
* Reenable textureMode which was disabled in f8b2d1 by @maxammann
  in [#194](https://github.com/maplibre/flutter-maplibre-gl/pull/194)
* android: Bump MapLibre SDK to 9.6.0 & OkHttp to 4.9.3 by @mariusvn
  in [#184](https://github.com/maplibre/flutter-maplibre-gl/pull/184)
* Added getSourceIds to the controller by @mariusvn
  in [#197](https://github.com/maplibre/flutter-maplibre-gl/pull/197)
* Moved EventChannel creation in the downloadOfflineRegion method by @mariusvn
  in [#205](https://github.com/maplibre/flutter-maplibre-gl/pull/205)
* Fix crash android dispose nullpointerdereference by @GaelleJoubert
  in [#203](https://github.com/maplibre/flutter-maplibre-gl/pull/203)
* Migrate links in README, pubspec to MapLibre by @kuhnroyal
  in [#224](https://github.com/maplibre/flutter-maplibre-gl/pull/224)
* Update LICENSE file by @mariusvn
  in [#230](https://github.com/maplibre/flutter-maplibre-gl/pull/230)
* upgrade dependency image by @m0nac0
  in [#248](https://github.com/maplibre/flutter-maplibre-gl/pull/248)
* fix-example-app by @JulianBissekkou
  in [#261](https://github.com/maplibre/flutter-maplibre-gl/pull/261)
* 162-animate-camera-on-web-fix by @JulianBissekkou
  in [#254](https://github.com/maplibre/flutter-maplibre-gl/pull/254)
* 243-fix-crash-when-no-location-permission by @JulianBissekkou
  in [#244](https://github.com/maplibre/flutter-maplibre-gl/pull/244)
* 182-disposal-null-ref-crash by @JulianBissekkou
  in [#259](https://github.com/maplibre/flutter-maplibre-gl/pull/259)
* New android sdk version by @stefanschaller
  in [#270](https://github.com/maplibre/flutter-maplibre-gl/pull/270)
* 250-change-language-fixes by @stefanschaller
  in [#275](https://github.com/maplibre/flutter-maplibre-gl/pull/275)
* upgrade-ios-version by @JulianBissekkou
  in [#277](https://github.com/maplibre/flutter-maplibre-gl/pull/277)
* Simplify iOS usage instructions and example podfile by @m0nac0
  in [#278](https://github.com/maplibre/flutter-maplibre-gl/pull/278)
* Add opportunity to use map in widget tests by @ManoyloK
  in [#281](https://github.com/maplibre/flutter-maplibre-gl/pull/281)
* fix-layers-prod-build by @stefanschaller
  in [#291](https://github.com/maplibre/flutter-maplibre-gl/pull/291)
* Fix the codespace by upgrading the docker image by @ouvreboite
  in [#297](https://github.com/maplibre/flutter-maplibre-gl/pull/297)
* Add `updateImageSource`. by @CaviarChen
  in [#271](https://github.com/maplibre/flutter-maplibre-gl/pull/271)
* fix "unexpected null value" error when onStyleLoadedCallback is null by
  @m0nac0 in [#307](https://github.com/maplibre/flutter-maplibre-gl/pull/307)
* attributionButtonPosition for web by @ouvreboite
  in [#304](https://github.com/maplibre/flutter-maplibre-gl/pull/304)

**Full Changelog**:
https://github.com/maplibre/flutter-maplibre-gl/compare/0.16.0...0.17.0

## 0.16.0, Jun 28, 2022

* cherry-picked all commits from upstream up
  to [https://github.com/flutter-mapbox-gl/maps/commit/3496907955cd4b442e4eb905d67e8d46692174f1),
  including up to release 0.16.0 from upstream
* updated MapLibre GL JS for web

## 0.15.1, May 24, 2022

* cherry-picked all commits from upstream up
  to [upstream release 0.15.0](https://github.com/flutter-mapbox-gl/maps/releases/tag/0.15.0)
* improved documentation
* betted adapted the example app to MapLibre
* hide logo on Android/iOS to match web

## 0.15.0, Oct 26, 2021

* Fix bug when changing line color (see #448) by @vberthet
  in [#15](https://github.com/m0nac0/flutter-maplibre-gl/pull/15)
* Remove unnecessary imports by @m0nac0
  in [#34](https://github.com/m0nac0/flutter-maplibre-gl/pull/34)
* Update example with Flutter 2.5.3 by @kuhnroyal
  in [#35](https://github.com/m0nac0/flutter-maplibre-gl/pull/35)
* CI: Use separate scheduled pipeline for Flutter beta builds by @kuhnroyal
  in [#28](https://github.com/m0nac0/flutter-maplibre-gl/pull/28)
* Null safety (cherry-pick from upstream) by @m0nac0
  in [#31](https://github.com/m0nac0/flutter-maplibre-gl/pull/31)
* [web] add missing removeLines, removeCircles and removeFills (cherry-pick
  tobrun#622) by @m0nac0
  in [#32](https://github.com/m0nac0/flutter-maplibre-gl/pull/32)
* Replace style string in local style example by @m0nac0
  in [#33](https://github.com/m0nac0/flutter-maplibre-gl/pull/33)
* [web] add getSymbolLatLng and getLineLatLngs by @m0nac0
  in [#37](https://github.com/m0nac0/flutter-maplibre-gl/pull/37)

## 0.14.0

### Breaking changes:

* Remove access token, update libraries, replace example
  styles [#25](https://github.com/m0nac0/flutter-maplibre-gl/pull/25) (also
  see [#21](https://github.com/m0nac0/flutter-maplibre-gl/issues/21))
    * The parameter `accessToken` of class `MaplibreMap` was removed. If you
      want to continue using a tile provider that requires an API key, specify
      that key directly in the URL of the tile source (
      see [https://github.com/m0nac0/flutter-maplibre-gl#tile-sources-requiring-an-api-key](https://github.com/m0nac0/flutter-maplibre-gl#tile-sources-requiring-an-api-key))
    * The built-in constants for specific styles were also removed. You can
      continue using these styles by using the styles' URL

### Other changes:

* Remove warning about missing access token on
  Android [#22](https://github.com/m0nac0/flutter-maplibre-gl/pull/22)
* Example: use maplibre styles and add new demo
  style [#23](https://github.com/m0nac0/flutter-maplibre-gl/pull/23)
* Add about button to example
  app [#26](https://github.com/m0nac0/flutter-maplibre-gl/pull/26)
* various improvements to the CI
* fixed formatting for some files that were not correctly formatted

## 0.13.0, Oct 6, 2021

🎉 The first release of flutter-maplibre-gl with the complete transition to
MapLibre libraries. 🎉

Further improvements:

* Update to MapLibre-Android-SDK 9.4.2
* Update to MapLibre-iOS-SDK 5.12.0
* Fix onUserLocationUpdated not firing on
  android [#14](https://github.com/m0nac0/flutter-maplibre-gl/pull/14)
* Add speed to
  UserLocation [#11](https://github.com/m0nac0/flutter-maplibre-gl/pull/11)
* Fix queryRenderedFeaturesInRect for
  iOS [#10](https://github.com/m0nac0/flutter-maplibre-gl/pull/10)

### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.12.0

* Batch creation/removal for circles, fills and
  lines [#576](https://github.com/tobrun/flutter-mapbox-gl/pull/576)
* Dependencies: updated image
  package [#598](https://github.com/tobrun/flutter-mapbox-gl/pull/598)
* Improve description to enable location
  features [#596](https://github.com/tobrun/flutter-mapbox-gl/pull/596)
* Fix feature manager on release
  build [#593](https://github.com/tobrun/flutter-mapbox-gl/pull/593)
* Emit onTap only for the feature above the
  others [#589](https://github.com/tobrun/flutter-mapbox-gl/pull/589)
* Add annotationOrder to
  web [#588](https://github.com/tobrun/flutter-mapbox-gl/pull/588)

### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.11.0

* Fixed issues caused by new android
  API [#544](https://github.com/tobrun/flutter-mapbox-gl/pull/544)
* Add option to set maximum offline tile
  count [#549](https://github.com/tobrun/flutter-mapbox-gl/pull/549)
* Fixed web build failure due to http package
  upgrade [#550](https://github.com/tobrun/flutter-mapbox-gl/pull/550)
* Update OfflineRegion/OfflineRegionDefinition interfaces, synchronize with iOS
  and Android [#545](https://github.com/tobrun/flutter-mapbox-gl/pull/545)
* Fix Mapbox GL JS CSS embedding on
  web [#551](https://github.com/tobrun/flutter-mapbox-gl/pull/551)
* Update Podfile to fix iOS
  CI [#565](https://github.com/tobrun/flutter-mapbox-gl/pull/565)
* Update deprecated patterns to fix CI static
  analysis [#568](https://github.com/tobrun/flutter-mapbox-gl/pull/568)
* Add setOffline method on
  Android [#537](https://github.com/tobrun/flutter-mapbox-gl/pull/537)
* Add batch mode of screen
  locations [#554](https://github.com/tobrun/flutter-mapbox-gl/pull/554)
* Define which annotations consume the tap
  events [#575](https://github.com/tobrun/flutter-mapbox-gl/pull/575)
* Remove failed offline region
  downloads [#583](https://github.com/tobrun/flutter-mapbox-gl/pull/583)

## Below is the original changelog of the tobrun/flutter-mapbox-gl project, before the fork.

## 0.10.0, February 12, 2020

* Merge offline
  regions [#532](https://github.com/tobrun/flutter-mapbox-gl/pull/532)
* Update offline region
  metadata [#530](https://github.com/tobrun/flutter-mapbox-gl/pull/530)
* Added web support for
  fills [#501](https://github.com/tobrun/flutter-mapbox-gl/pull/501)
* Support styleString as "Documents directory/Temporary
  directory" [#520](https://github.com/tobrun/flutter-mapbox-gl/pull/520)
* Use offline region
  ids [#491](https://github.com/tobrun/flutter-mapbox-gl/pull/491)
* Ability to define annotation layer
  order [#523](https://github.com/tobrun/flutter-mapbox-gl/pull/523)
* Clear fills API [#527](https://github.com/tobrun/flutter-mapbox-gl/pull/527)
* Add heading to UserLocation and expose UserLocation
  type [#522](https://github.com/tobrun/flutter-mapbox-gl/pull/522)
* Patch addFill with data
  parameter [#524](https://github.com/tobrun/flutter-mapbox-gl/pull/524)
* Fix style annotation is not deselected on
  iOS [#512](https://github.com/tobrun/flutter-mapbox-gl/pull/512)
* Update tracked camera position in
  camera#onIdle [#500](https://github.com/tobrun/flutter-mapbox-gl/pull/500)
* Fix iOS implementation of map#toLatLng on
  iOS [#495](https://github.com/tobrun/flutter-mapbox-gl/pull/495)
* Migrate to new Android flutter plugin
  architecture [#488](https://github.com/tobrun/flutter-mapbox-gl/pull/488)
* Update readme to fix
  UnsatisfiedLinkError [#422](https://github.com/tobrun/flutter-mapbox-gl/pull/442)
* Improved Image Source
  Support [#469](https://github.com/tobrun/flutter-mapbox-gl/pull/469)
* Avoid white space when resizing map on
  web [#474](https://github.com/tobrun/flutter-mapbox-gl/pull/474)
* Allow MapboxMap() to override Widget
  Key. [#475](https://github.com/tobrun/flutter-mapbox-gl/pull/475)
* Offline region
  feature [#336](https://github.com/tobrun/flutter-mapbox-gl/pull/336)
* Fix iOS symbol tapped
  interaction [#443](https://github.com/tobrun/flutter-mapbox-gl/pull/443)

## 0.9.0, October 24. 2020

* Fix data parameter for addLine and
  addCircle [#388](https://github.com/tobrun/flutter-mapbox-gl/pull/388)
* Re-enable attribution on
  Android [#383](https://github.com/tobrun/flutter-mapbox-gl/pull/383)
* Upgrade annotation plugin to
  v0.9 [#381](https://github.com/tobrun/flutter-mapbox-gl/pull/381)
* Breaking change: CameraUpdate.newLatLngBounds() now supports setting different
  padding values for left, top, right, bottom with default of 0 for all.
  Implementations using the old approach with only one padding value for all
  edges have to be
  updated. [#382](https://github.com/tobrun/flutter-mapbox-gl/pull/382)
* web:ignore myLocationTrackingMode if myLocationEnabled is
  false [#363](https://github.com/tobrun/flutter-mapbox-gl/pull/363)
* Add methods to access
  projection [#380](https://github.com/tobrun/flutter-mapbox-gl/pull/380)
* Add fill API support for Android and
  iOS [#49](https://github.com/tobrun/flutter-mapbox-gl/pull/49)
* Listen to OnUserLocationUpdated to provide user location to
  app [#237](https://github.com/tobrun/flutter-mapbox-gl/pull/237)
* Correct integration in Activity lifecycle on
  Android [#266](https://github.com/tobrun/flutter-mapbox-gl/pull/266)
* Add support for custom font stackn in symbol
  options [#359](https://github.com/tobrun/flutter-mapbox-gl/pull/359)
* Fix memory leak on iOS caused by strong self
  reference [#370](https://github.com/tobrun/flutter-mapbox-gl/pull/370)
* Basic ImageSource
  Support [#409](https://github.com/tobrun/flutter-mapbox-gl/pull/409)
* Get meters per pixel at
  latitude [#416](https://github.com/tobrun/flutter-mapbox-gl/pull/416)
* Fix
  onStyleLoadedCallback [#418](https://github.com/tobrun/flutter-mapbox-gl/pull/418)

## 0.8.0, August 22, 2020

- implementation of feature
  querying [#177](https://github.com/tobrun/flutter-mapbox-gl/pull/177)
- Batch create/delete of
  symbols [#279](https://github.com/tobrun/flutter-mapbox-gl/pull/279)
- Add multi map
  support [#315](https://github.com/tobrun/flutter-mapbox-gl/pull/315)
- Fix OnCameraIdle not being
  invoked [#313](https://github.com/tobrun/flutter-mapbox-gl/pull/313)
- Fix android zIndex symbol
  option [#312](https://github.com/tobrun/flutter-mapbox-gl/pull/312)
- Set dependencies from
  git [#319](https://github.com/tobrun/flutter-mapbox-gl/pull/319)
- Add line#getGeometry and
  symbol#getGeometry [#281](https://github.com/tobrun/flutter-mapbox-gl/pull/281)

## 0.7.0, June 6, 2020

* Introduction of mapbox_gl_platform_interface library
* Introduction of mapbox_gl_web library
* Integrate web support through mapbox-gl-js
* Add icon-allow-overlap configurations

## 0.0.6, May 31, 2020

* Update mapbox depdendency to 9.2.0 (android) and 5.6.0 (iOS)
* Long press handlers for both iOS as Android
* Change default location tracking to none
* OnCameraIdle listener support
* Add image to style
* Add animation duration to animateCamera
* Content insets
* Visible region support on iOS
* Numerous bug fixes

## 0.0.5, December 21, 2019

* iOS support for annotation extensions (circle, symbol, line)
* Update SDK to 8.5.0 (Android) and 5.5.0 (iOS)
* Integrate style loaded callback api
* Add Map click event (iOS)
* Cache management API (Android/iOS)
* Various fixes to showing user location and configurations (Android/iOS)
* Last location API (Android)
* Throttle max FPS of user location component (Android)
* Fix for handling permission handling of the test application (Android)
* Support for loading symbol images from assets (iOS/Android)

## v0.0.4, Nov 2, 2019

* Update SDK to 8.4.0 (Android) and 5.4.0 (iOS)
* Add support for sideloading offline maps (Android/iOS)
* Add user tracking mode (iOS)
* Invert compassView.isHidden logic (iOS)
* Specific swift version (iOS)

## v0.0.3, Mar 30, 2019

* Camera API (iOS)
* Line API (Android)
* Update codebase to AndroidX
* Update Mapbox Maps SDK for Android to v7.3.0

## v0.0.2, Mar 23, 2019

* Support for iOS
* Migration to embedded Android and iOS SDK View system
* Style URL API
* Style JSON API (Android)
* Gesture support
* Gesture restrictions (Android)
* Symbol API (Android)
* Location component (Android)
* Camera API (Android)

## v0.0.1, May 7, 2018

* Initial Android surface rendering POC
