## 0.17.0

**Repository transfer**: The project repository was transferred to the MapLibre GitHub organization. More information at  https://github.com/maplibre/flutter-maplibre-gl/issues/221

* Developers do not need to adapt their Podfile for iOS apps anymore as it was previously described in the Readme.  [https://github.com/maplibre/flutter-maplibre-gl/pull/278](https://github.com/maplibre/flutter-maplibre-gl/pull/278)
### Breaking Change:
* `maplibre_gl/mapbox_gl.dart` was renamed to `maplibre_gl/maplibre_gl.dart`. You can do a replace-all from `import 'package:maplibre_gl/mapbox_gl.dart';` to `import 'package:maplibre_gl/maplibre_gl.dart';`
* `useDelayedDisposal` was removed since its now fixed in https://github.com/maplibre/flutter-maplibre-gl/pull/259
* `useHybridCompositionOverride` was removed since it was added in the following fix: https://github.com/maplibre/flutter-maplibre-gl/pull/203 and we reverted the fix and used another approach to fix the actual issue.
* The default for `myLocationRenderMode` was changed from `COMPASS` to `NORMAL` in https://github.com/maplibre/flutter-maplibre-gl/pull/244, since the previous default value of `COMPASS` implicitly enables displaying the location on iOS, which could crash apps that didn't want to display the device location. If you want to continue to use `MyLocationRenderMode.COMPASS`, please explicitly specify it in the constructor like this:
```dart
MaplibreMap(
 myLocationRenderMode: MyLocationRenderMode.COMPASS,
 ...
)
```
* The old api `registerWith` was removed from the MapboxMapsPlugin.java, since there is no need for that. 
* The `minSdkVersion` was bumped to at least 21 now, since the native android sdk constraint expect that. 
* Changed the minimum Dart version from sdk: `2.12.0` to `2.14.0` in `maplibre_gl_platform_interface/pubspec.yaml`.


### Further changes
Note: This list only contains a subset of all contributions, notably excluding those that e.g. only affect the GitHub Actions CI or documentation. See the link at the end for a full changelog.

* feat: add support for reading style json from file in ios by @TimAlber in https://github.com/maplibre/flutter-maplibre-gl/pull/132
* Add podspecs in correct Cocoapods layout by @kuhnroyal in https://github.com/maplibre/flutter-maplibre-gl/pull/128
* fix: fix the queryRenderedFeatures code on iOS by @TimAlber in https://github.com/maplibre/flutter-maplibre-gl/pull/137
* feat: Set layer visibility by @m0nac0 in https://github.com/maplibre/flutter-maplibre-gl/pull/138
* feat: add support for changing the receiver’s viewport to fit given bounds by @TimAlber in https://github.com/maplibre/flutter-maplibre-gl/pull/133
* Change feature JSON encoding from .ascii to .utf8 by @SunBro-Marko in https://github.com/maplibre/flutter-maplibre-gl/pull/142
* web: implement setCameraBounds by @m0nac0 in https://github.com/maplibre/flutter-maplibre-gl/pull/145
* Use offical maplibre-gl.js and add README info by @Robbendebiene in https://github.com/maplibre/flutter-maplibre-gl/pull/163
* android: adding tileSize to raster source by @mariusvn in https://github.com/maplibre/flutter-maplibre-gl/pull/166
* Readme: document git default values for codespaces by @m0nac0 in https://github.com/maplibre/flutter-maplibre-gl/pull/170
* query source features by @Grodien in https://github.com/maplibre/flutter-maplibre-gl/pull/154
* Trimming styleString to simplify the JSON detection by @mariusvn in https://github.com/maplibre/flutter-maplibre-gl/pull/175
* Fix getVisibleRegion method by @BartoszStasiurka in https://github.com/maplibre/flutter-maplibre-gl/pull/179
* Reenable textureMode which was disabled in f8b2d1 by @maxammann in https://github.com/maplibre/flutter-maplibre-gl/pull/194
* android: Bump Maplibre SDK to 9.6.0 & OkHttp to 4.9.3 by @mariusvn in https://github.com/maplibre/flutter-maplibre-gl/pull/184
* Added getSourceIds to the controller by @mariusvn in https://github.com/maplibre/flutter-maplibre-gl/pull/197
* Moved EventChannel creation in the downloadOfflineRegion method by @mariusvn in https://github.com/maplibre/flutter-maplibre-gl/pull/205
* Fix crash android dispose nullpointerdereference by @GaelleJoubert in https://github.com/maplibre/flutter-maplibre-gl/pull/203
* Migrate links in README, pubspec to Maplibre by @kuhnroyal in https://github.com/maplibre/flutter-maplibre-gl/pull/224
* Update LICENSE file by @mariusvn in https://github.com/maplibre/flutter-maplibre-gl/pull/230
* upgrade dependency image by @m0nac0 in https://github.com/maplibre/flutter-maplibre-gl/pull/248
* fix-example-app by @JulianBissekkou in https://github.com/maplibre/flutter-maplibre-gl/pull/261
* 162-animate-camera-on-web-fix by @JulianBissekkou in https://github.com/maplibre/flutter-maplibre-gl/pull/254
* 243-fix-crash-when-no-location-permission by @JulianBissekkou in https://github.com/maplibre/flutter-maplibre-gl/pull/244
* 182-disposal-null-ref-crash by @JulianBissekkou in https://github.com/maplibre/flutter-maplibre-gl/pull/259
* New android sdk version by @stefanschaller in https://github.com/maplibre/flutter-maplibre-gl/pull/270
* 250-change-language-fixes by @stefanschaller in https://github.com/maplibre/flutter-maplibre-gl/pull/275
* upgrade-ios-version by @JulianBissekkou in https://github.com/maplibre/flutter-maplibre-gl/pull/277
* Simplify iOS usage instructions and example podfile by @m0nac0 in https://github.com/maplibre/flutter-maplibre-gl/pull/278
* Add opportunity to use map in widget tests by @ManoyloK in https://github.com/maplibre/flutter-maplibre-gl/pull/281
* fix-layers-prod-build by @stefanschaller in https://github.com/maplibre/flutter-maplibre-gl/pull/291
* Fix the codespace by upgrading the docker image by @ouvreboite in https://github.com/maplibre/flutter-maplibre-gl/pull/297
* Add `updateImageSource`. by @CaviarChen in https://github.com/maplibre/flutter-maplibre-gl/pull/271
* fix "unexpected null value" error when onStyleLoadedCallback is null by @m0nac0 in https://github.com/maplibre/flutter-maplibre-gl/pull/307
* attributionButtonPosition for web by @ouvreboite in https://github.com/maplibre/flutter-maplibre-gl/pull/304


**Full Changelog**: https://github.com/maplibre/flutter-maplibre-gl/compare/0.16.0...0.17.0

## 0.16.0, Jun 28, 2022
* cherry-picked all commits from upstream up to [https://github.com/flutter-mapbox-gl/maps/commit/3496907955cd4b442e4eb905d67e8d46692174f1), including up to release 0.16.0 from upstream
* updated Maplibre GL JS for web

## 0.15.1, May 24, 2022

* cherry-picked all commits from upstream up to [upstream release 0.15.0](https://github.com/flutter-mapbox-gl/maps/releases/tag/0.15.0)
* improved documentation
* betted adapted the example app to MapLibre
* hide logo on Android/iOS to match web

## 0.15.0, Oct 26, 2021

* Fix bug when changing line color (see #448) by @vberthet in https://github.com/m0nac0/flutter-maplibre-gl/pull/15
* Remove unnecessary imports by @m0nac0 in https://github.com/m0nac0/flutter-maplibre-gl/pull/34
* Update example with Flutter 2.5.3 by @kuhnroyal in https://github.com/m0nac0/flutter-maplibre-gl/pull/35
* CI: Use separate scheduled pipeline for Flutter beta builds by @kuhnroyal in https://github.com/m0nac0/flutter-maplibre-gl/pull/28
* Null safety (cherry-pick from upstream) by @m0nac0 in https://github.com/m0nac0/flutter-maplibre-gl/pull/31
* [web] add missing removeLines, removeCircles and removeFills (cherry-pick tobrun#622) by @m0nac0 in https://github.com/m0nac0/flutter-maplibre-gl/pull/32
* Replace style string in local style example by @m0nac0 in https://github.com/m0nac0/flutter-maplibre-gl/pull/33
* [web] add getSymbolLatLng and getLineLatLngs by @m0nac0 in https://github.com/m0nac0/flutter-maplibre-gl/pull/37

## 0.14.0
### Breaking changes:
* Remove access token, update libraries, replace example styles [#25](https://github.com/m0nac0/flutter-maplibre-gl/pull/25) (also see [#21](https://github.com/m0nac0/flutter-maplibre-gl/issues/21))
  * The parameter `accessToken` of class `MaplibreMap` was removed. If you want to continue using a tile provider that requires an API key, specify that key directly in the URL of the tile source (see [https://github.com/m0nac0/flutter-maplibre-gl#tile-sources-requiring-an-api-key](https://github.com/m0nac0/flutter-maplibre-gl#tile-sources-requiring-an-api-key))
  * The built-in constants for specific styles were also removed. You can continue using these styles by using the styles' URL

### Other changes:
* Remove warning about missing access token on Android [#22](https://github.com/m0nac0/flutter-maplibre-gl/pull/22)
* Example: use maplibre styles and add new demo style [#23](https://github.com/m0nac0/flutter-maplibre-gl/pull/23)
* Add about button to example app [#26](https://github.com/m0nac0/flutter-maplibre-gl/pull/26)
* various improvements to the CI
* fixed formatting for some files that were not correctly formatted


## 0.13.0, Oct 6, 2021
🎉 The first release of flutter-maplibre-gl with the complete transition to Maplibre libraries. 🎉

Further improvements: 
* Update to Maplibre-Android-SDK 9.4.2
* Update to MapLibre-iOS-SDK 5.12.0
* Fix onUserLocationUpdated not firing on android [#14](https://github.com/m0nac0/flutter-maplibre-gl/pull/14)
* Add speed to UserLocation [#11](https://github.com/m0nac0/flutter-maplibre-gl/pull/11)
* Fix queryRenderedFeaturesInRect for iOS [#10](https://github.com/m0nac0/flutter-maplibre-gl/pull/10)


### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.12.0
* Batch creation/removal for circles, fills and lines [#576](https://github.com/tobrun/flutter-mapbox-gl/pull/576)
* Dependencies: updated image package [#598](https://github.com/tobrun/flutter-mapbox-gl/pull/598)
* Improve description to enable location features [#596](https://github.com/tobrun/flutter-mapbox-gl/pull/596)
* Fix feature manager on release build [#593](https://github.com/tobrun/flutter-mapbox-gl/pull/593)
* Emit onTap only for the feature above the others [#589](https://github.com/tobrun/flutter-mapbox-gl/pull/589)
* Add annotationOrder to web [#588](https://github.com/tobrun/flutter-mapbox-gl/pull/588)


### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.11.0
* Fixed issues caused by new android API [#544](https://github.com/tobrun/flutter-mapbox-gl/pull/544)
* Add option to set maximum offline tile count [#549](https://github.com/tobrun/flutter-mapbox-gl/pull/549)
* Fixed web build failure due to http package upgrade [#550](https://github.com/tobrun/flutter-mapbox-gl/pull/550)
* Update OfflineRegion/OfflineRegionDefinition interfaces, synchronize with iOS and Android [#545](https://github.com/tobrun/flutter-mapbox-gl/pull/545)
* Fix Mapbox GL JS CSS embedding on web [#551](https://github.com/tobrun/flutter-mapbox-gl/pull/551)
* Update Podfile to fix iOS CI [#565](https://github.com/tobrun/flutter-mapbox-gl/pull/565)
* Update deprecated patterns to fix CI static analysis [#568](https://github.com/tobrun/flutter-mapbox-gl/pull/568)
* Add setOffline method on Android [#537](https://github.com/tobrun/flutter-mapbox-gl/pull/537)
* Add batch mode of screen locations [#554](https://github.com/tobrun/flutter-mapbox-gl/pull/554)
* Define which annotations consume the tap events [#575](https://github.com/tobrun/flutter-mapbox-gl/pull/575)
* Remove failed offline region downloads [#583](https://github.com/tobrun/flutter-mapbox-gl/pull/583)

## Below is the original changelog of the tobrun/flutter-mapbox-gl project, before the fork.


## 0.10.0, February 12, 2020
* Merge offline regions [#532](https://github.com/tobrun/flutter-mapbox-gl/pull/532)
* Update offline region metadata [#530](https://github.com/tobrun/flutter-mapbox-gl/pull/530)
* Added web support for fills [#501](https://github.com/tobrun/flutter-mapbox-gl/pull/501)
* Support styleString as "Documents directory/Temporary directory" [#520](https://github.com/tobrun/flutter-mapbox-gl/pull/520)
* Use offline region ids [#491](https://github.com/tobrun/flutter-mapbox-gl/pull/491)
* Ability to define annotation layer order [#523](https://github.com/tobrun/flutter-mapbox-gl/pull/523)
* Clear fills API [#527](https://github.com/tobrun/flutter-mapbox-gl/pull/527)
* Add heading to UserLocation and expose UserLocation type [#522](https://github.com/tobrun/flutter-mapbox-gl/pull/522)
* Patch addFill with data parameter [#524](https://github.com/tobrun/flutter-mapbox-gl/pull/524)
* Fix style annotation is not deselected on iOS [#512](https://github.com/tobrun/flutter-mapbox-gl/pull/512)
* Update tracked camera position in camera#onIdle [#500](https://github.com/tobrun/flutter-mapbox-gl/pull/500)
* Fix iOS implementation of map#toLatLng on iOS [#495](https://github.com/tobrun/flutter-mapbox-gl/pull/495)
* Migrate to new Android flutter plugin architecture [#488](https://github.com/tobrun/flutter-mapbox-gl/pull/488)
* Update readme to fix UnsatisfiedLinkError [#422](https://github.com/tobrun/flutter-mapbox-gl/pull/442)
* Improved Image Source Support [#469](https://github.com/tobrun/flutter-mapbox-gl/pull/469)
* Avoid white space when resizing map on web [#474](https://github.com/tobrun/flutter-mapbox-gl/pull/474)
* Allow MapboxMap() to override Widget Key. [#475](https://github.com/tobrun/flutter-mapbox-gl/pull/475)
* Offline region feature [#336](https://github.com/tobrun/flutter-mapbox-gl/pull/336)
* Fix iOS symbol tapped interaction [#443](https://github.com/tobrun/flutter-mapbox-gl/pull/443)

## 0.9.0,  October 24. 2020
* Fix data parameter for addLine and addCircle [#388](https://github.com/tobrun/flutter-mapbox-gl/pull/388)
* Re-enable attribution on Android [#383](https://github.com/tobrun/flutter-mapbox-gl/pull/383)
* Upgrade annotation plugin to v0.9 [#381](https://github.com/tobrun/flutter-mapbox-gl/pull/381)
* Breaking change: CameraUpdate.newLatLngBounds() now supports setting different padding values for left, top, right, bottom with default of 0 for all. Implementations using the old approach with only one padding value for all edges have to be updated. [#382](https://github.com/tobrun/flutter-mapbox-gl/pull/382)
* web:ignore myLocationTrackingMode if myLocationEnabled is false [#363](https://github.com/tobrun/flutter-mapbox-gl/pull/363)
* Add methods to access projection [#380](https://github.com/tobrun/flutter-mapbox-gl/pull/380)
* Add fill API support for Android and iOS [#49](https://github.com/tobrun/flutter-mapbox-gl/pull/49)
* Listen to OnUserLocationUpdated to provide user location to app [#237](https://github.com/tobrun/flutter-mapbox-gl/pull/237)
* Correct integration in Activity lifecycle on Android [#266](https://github.com/tobrun/flutter-mapbox-gl/pull/266)
* Add support for custom font stackn in symbol options [#359](https://github.com/tobrun/flutter-mapbox-gl/pull/359)
* Fix memory leak on iOS caused by strong self reference [#370](https://github.com/tobrun/flutter-mapbox-gl/pull/370)
* Basic ImageSource Support [#409](https://github.com/tobrun/flutter-mapbox-gl/pull/409)
* Get meters per pixel at latitude [#416](https://github.com/tobrun/flutter-mapbox-gl/pull/416)
* Fix onStyleLoadedCallback [#418](https://github.com/tobrun/flutter-mapbox-gl/pull/418)

## 0.8.0, August 22, 2020
- implementation of feature querying [#177](https://github.com/tobrun/flutter-mapbox-gl/pull/177)
- Batch create/delete of symbols [#279](https://github.com/tobrun/flutter-mapbox-gl/pull/279)
- Add multi map support [#315](https://github.com/tobrun/flutter-mapbox-gl/pull/315)
- Fix OnCameraIdle not being invoked [#313](https://github.com/tobrun/flutter-mapbox-gl/pull/313)
- Fix android zIndex symbol option [#312](https://github.com/tobrun/flutter-mapbox-gl/pull/312)
- Set dependencies from git [#319](https://github.com/tobrun/flutter-mapbox-gl/pull/319)
- Add line#getGeometry and symbol#getGeometry [#281](https://github.com/tobrun/flutter-mapbox-gl/pull/281)

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
