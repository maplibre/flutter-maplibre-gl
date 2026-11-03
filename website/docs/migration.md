# Migration Guide

## Upgrading to 0.28.0

0.28.0 makes Android, iOS and web behave the same, where possible. Most apps compile unchanged: raise the minimum versions, then go through the sections below in order, skipping those that do not apply to your app.

Update your `pubspec.yaml`, then run `flutter pub upgrade maplibre_gl`:

```yaml
dependencies:
  maplibre_gl: ^0.28.0
```

!!! tip "Using an AI coding agent?"
    Give it this page and ask it to apply the changes to your app and list what it could not check.

### Minimum versions

* Flutter 3.44 and Dart 3.12. Apps on an older Flutter stay on 0.27.x.
* iOS 15.5: raise `IPHONEOS_DEPLOYMENT_TARGET` in Xcode and, with CocoaPods, `platform :ios, '15.5'` in `ios/Podfile`.
* Android API 24: raise a lower `minSdk` in `android/app/build.gradle.kts`, or `build.gradle` in older apps.

Flutter 3.44 builds the iOS plugin with Swift Package Manager, and MapLibre iOS no longer publishes to CocoaPods. If your app turned [Swift Package Manager](getting-started.md#swift-package-manager) off, turn it back on. Add-to-app modules keep using CocoaPods.

### Error codes

Every platform now reports the same [error codes](concepts/errors.md). Two changes matter when upgrading.

#### Calls that now throw

Calls that did nothing, or crashed, on some platforms now throw. Add a `catch` where your app can hit them, or the error goes unhandled. The ones most apps meet:

* `STYLE_NOT_READY`: a source, layer or image call made before the style loaded. Move it to `onStyleLoadedCallback`.
* `LAYER_NOT_FOUND_ERROR`, `SOURCE_NOT_FOUND`, `LAYER_ALREADY_EXISTS`, `SOURCE_ALREADY_EXISTS`: an id that is missing, or already in use.
* `INVALID_GEOJSON`, `INVALID_EXPRESSION`, `INVALID_ARGUMENT`: data, a filter or a property value MapLibre cannot use.
* **Android, iOS**: a call on a disposed map throws `MAP_DISPOSED` instead of a `MissingPluginException`.
* **iOS, Web**: `setOffline` throws an `UnsupportedError`: call it on Android only.
* **Web**: the offline calls and the HTTP header calls throw an `UnsupportedError`: guard them with `kIsWeb`.

The [full list](concepts/errors.md#codes) says when each code fires.

#### Renamed codes

If your app compares `PlatformException.code`, update these:

| Before | Platform | 0.28.0 |
|---|---|---|
| `layerNotFound` | iOS | `LAYER_NOT_FOUND_ERROR` |
| `invalidExpression` | iOS | `INVALID_EXPRESSION` |
| `invalidLayerType` | iOS | `INVALID_LAYER_TYPE` |
| `sourceAlreadyExists`, `duplicateSource` | iOS | `SOURCE_ALREADY_EXISTS` |
| `layerAlreadyExists`, `duplicateLayer` | iOS | `LAYER_ALREADY_EXISTS` |
| `styleNotFound` | iOS | `STYLE_NOT_READY` |
| `sourceNotFound`, `noSuchSource` | iOS | `SOURCE_NOT_FOUND` |
| `invalidSourceType` | iOS | `UNSUPPORTED_SOURCE_TYPE`, or `INVALID_ARGUMENT` for bad source properties |
| `parseError` | iOS | `INVALID_GEOJSON` |
| Ambient cache errors | Android | `AMBIENT_CACHE_ERROR` |
| Map language errors | Android | `LOCALIZATION_ERROR` |
| `SetHttpHeadersError`, `SetMaxConcurrentRequestsError` | Android | `HTTP_CLIENT_ERROR` |
| Offline per-call codes, such as `DeleteRegionError` | Android, iOS | `REGION_NOT_FOUND` for an unknown id, `INVALID_ARGUMENT` for a bad value, `OFFLINE_DATABASE_ERROR` otherwise |

The other offline codes only change case, such as `RegionDeleted` to `REGION_DELETED`. [Errors](advanced/offline-regions.md#errors) lists every offline code and when it fires.

### Android: screen points in logical pixels

On Android screen points are in logical pixels, as on iOS and web: `toScreenLocation`, `toScreenLocationBatch`, `toLatLng`, the queries, and the point of `onMapClick`, `onMapLongClick`, `onFeatureTapped` and `onFeatureDrag`. Remove any Android-only scaling:

```dart
final point = await controller.toScreenLocation(latLng);

// Before
final ratio = Platform.isAndroid ? MediaQuery.of(context).devicePixelRatio : 1.0;
final left = point.x / ratio;

// After (every platform)
final left = point.x;
```

Code that only passes a point from one call to another, such as the `onMapClick` point to `queryRenderedFeatures`, works unchanged.

### Android: numeric feature ids

On Android numeric GeoJSON feature ids stay numbers, as on iOS and web. Read `feature['id']` as a `num` and compare it with `2`, not `"2"`:

```dart
// Source data: {'type': 'Feature', 'id': 2, ...}
final features = await controller.queryRenderedFeatures(point, ['pois'], null);

// Before (Android)
final isSelected = features.first['id'] == '2';
await controller.setLayerFilter('pois', ['==', ['id'], '2']);

// After (every platform)
final isSelected = features.first['id'] == 2;
await controller.setLayerFilter('pois', ['==', ['id'], 2]);
```

GeoJSON loaded from a URL or declared in the style is the exception: on Android and web only its integer ids are sure to match.

### Return types

`setLayerFilter` returns `Future<void>` and throws on failure instead of returning `false`:

```dart
// Before
final ok = await controller.setLayerFilter('pois', filterJson);
if (!ok) showError();

// After
try {
  await controller.setLayerFilter('pois', filter);
} on PlatformException catch (e) {
  showError(e.code); // LAYER_NOT_FOUND_ERROR, INVALID_LAYER_TYPE or INVALID_EXPRESSION
}
```

`setOffline`, `setOfflineTileCountLimit` and `deleteOfflineRegion` return `Future<void>`: drop any use of their value, which was always `null`.

### Camera

* Awaited `animateCamera` and `easeCamera` complete when the camera arrives, with `false` when interrupted. Code after them now runs after the animation.
* **Android, iOS**: they also complete with `false` when the map is disposed mid-animation: check `mounted` before calling `setState`.
* **Android**: a positive `x` in `CameraUpdate.scrollBy` moves the view east, as on iOS and web: remove any Android-only sign flip.
* **Android**: `setCameraBounds` `padding` is in logical pixels, as on iOS and web: remove any scaling by the pixel ratio.
* **iOS, Web**: `cameraTargetBounds` keeps the camera target inside the bounds, as on Android, so the map no longer zooms in to fit them.
* **Web**: `onCameraMove` and `controller.cameraPosition` need `trackCameraPosition: true`, as on Android and iOS: set it if you read them.

### Feature taps and drags

Taps and drags on annotations and draggable features work the same on every platform. Check flows that depend on them:

* A drag starts only after the finger or mouse moves a little, so a tap on a draggable feature stays a tap.
* A second finger ends the drag with an `end` event and lets the map pinch.
* **Android**: a drag no longer fires `onMapLongClick`.
* **Android, iOS**: taps and drags pick the nearest feature within 8 logical pixels, so a tap next to a feature can now select it.

### How the map looks

* **Android, iOS**: fill annotations without a `fillOutlineColor` get an outline in their fill color: set `fillOutlineColor` to keep the old look.
* **Android, iOS**: `line-pattern` images are drawn about 1.7 times smaller, the size MapLibre GL JS uses.
* **iOS**: an `iconImage` naming an asset with `2.0x` or `3.0x` variants is sized like `Image.asset`: remove any iOS-only `iconSize` that made up for it.
* **iOS**: `#rgba` and `#rrggbbaa` colors read the alpha last, as in CSS and on Android and web. Move the alpha of an `#aarrggbb` color to the end:

```dart
// Before (iOS): red at 50% opacity
fillColor: '#80ff0000',

// After (every platform)
fillColor: '#ff000080',
```

### Offline and HTTP headers

* **Android**: the `setCustomHeaders` filter matches anywhere in the URL, as on iOS: anchor it with `^` and `$` to match the whole URL.
* **Android, iOS**: offline region metadata is stored as `jsonEncode` writes it, so a `Uint8List` reads back as a list of numbers.

### Tests and platform packages

The plugin talks to Android and iOS through typed [Pigeon](https://pub.dev/packages/pigeon) messages instead of method channels. App code is not affected, but tests and platform packages are:

* Mocks of the plugin's method channels no longer intercept anything: install a fake `MapLibrePlatform` and `MapLibreGlobalPlatform` instead.
* `MapLibreMethodChannel` and `MapLibreGlobalMethodChannel` are removed: extend `MapLibrePlatform` or `MapLibreGlobalPlatform`.
* `onCameraMoveStartedPlatform` no longer takes `null`: pass what started the move.

```dart
// Before
class FakeMapPlatform extends MapLibreMethodChannel { ... }
tearDown(() => MapLibreGlobalPlatform.instance = MapLibreGlobalMethodChannel());
onCameraMoveStartedPlatform(null);

// After: MapLibreGlobalPlatform comes from maplibre_gl_platform_interface
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

class FakeMapPlatform extends MapLibrePlatform {
  // Override what the test calls; any other call throws.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
MapLibrePlatform.createInstance = FakeMapPlatform.new;
final previous = MapLibreGlobalPlatform.instance;
addTearDown(() => MapLibreGlobalPlatform.instance = previous);
onCameraMoveStartedPlatform(CameraMoveReason.programmatic); // or .gesture
```

### Android: platform view mode

`useHybridComposition` and `translucentTextureSurface` still work, but are deprecated in favor of `androidView`:

```dart
// Before
MapLibreMap.useHybridComposition = true;
MapLibreMap(translucentTextureSurface: true);

// After
MapLibreMap(androidView: const AndroidMapView(surface: AndroidMapSurface.textureView));
MapLibreMap(androidView: const AndroidMapView(surface: AndroidMapSurface.translucentTextureView));
```

Despite its name, `useHybridComposition` never selected Hybrid Composition: that is `composition: AndroidComposition.hybridComposition`. See [Platform view mode (Android)](advanced/performance.md#platform-view-mode-android).

### Web: browsers without WebGL2

On a browser without WebGL2 the map fails to create instead of showing up blank: the controller future completes with an error and `onMapCreated` is not called. To support those browsers, load a MapLibre GL JS 5 build: see [Web: the engine moves to MapLibre GL JS 6](#web-the-engine-moves-to-maplibre-gl-js-6).

## Upgrading to 0.27.1

A patch release: bug fixes only, no API changes, nothing to do beyond taking the new version.

```yaml
dependencies:
  maplibre_gl: ^0.27.1
```

Android apps that worked around the 0.27.0 build failure, by setting `android.builtInKotlin=true` or applying the Kotlin plugin to `:maplibre_gl` from their root `build.gradle`, can drop that again (#1008).

## Upgrading to 0.27.0

No breaking API changes, so nothing stops compiling. Two platforms do need action: Android apps need one code change, described under [Android: style content](#android-style-content), and web apps should delete two tags from `web/index.html`, described under [Web: remove the script and stylesheet tags](#web-remove-the-script-and-stylesheet-tags).

Update your `pubspec.yaml`:

```yaml
dependencies:
  maplibre_gl: ^0.27.1
```

Then run `flutter pub upgrade maplibre_gl`. See the [CHANGELOG](https://github.com/maplibre/flutter-maplibre-gl/blob/main/CHANGELOG.md) for the full list of changes. Minimum SDK versions are unchanged from 0.26.x; see [Minimum versions](getting-started.md#minimum-versions).

### Android: style content

A map on Android now survives its host activity being destroyed and recreated, whether by the "Don't keep activities" developer option, by a configuration change such as rotation, or under memory pressure. The `MapView` is rebuilt and the camera position is restored for you.

What is not restored automatically is style content: sources, layers, images and runtime style switches. Apply those inside `onStyleLoadedCallback`, which fires again after each recreation, so the content comes back with the new map:

```dart
MapLibreMapController? _controller;

MapLibreMap(
  onMapCreated: (controller) => _controller = controller,
  onStyleLoadedCallback: () async {
    // Runs on the first style load and again after every activity recreation.
    await _controller?.addGeoJsonSource('route', routeGeoJson);
    await _controller?.addLineLayer(
      'route',
      'route-line',
      const LineLayerProperties(lineColor: '#ff0000'),
    );
  },
)
```

If your app adds that content in `onMapCreated` or `initState` instead, move it into `onStyleLoadedCallback`. Without the move, the map comes back after a recreation with the base style only, and your own layers missing.

### Web: remove the script and stylesheet tags

The plugin now loads MapLibre GL JS itself, pinned to the exact build it is tested against, before the first map is built. The two tags every web app had to carry are no longer needed: delete the `<script>` tag that loads `maplibre-gl.js` and the `<link>` tag that loads `maplibre-gl.css` from your `web/index.html`.

If you leave them in, nothing breaks today: an existing `maplibregl` global is reused as it is. But your pinned copy then silently overrides the version the plugin is tested against, on this upgrade and every future one.

Two setups need more than deleting the tags:

* A Content-Security-Policy that blocks the CDN, or a self-hosted copy of the library: point the plugin at your copy with `MapLibreMap.webLibrarySource`. See [Self-hosting MapLibre GL JS](getting-started.md#self-hosting-maplibre-gl-js).
* Your own JS interop into MapLibre GL JS, for example registering a protocol with `addProtocol`: the `maplibregl` global no longer exists at page parse time, so await `MapLibreMap.ensureWebLibraryLoaded()` first. See [Calling MapLibre GL JS yourself](getting-started.md#calling-maplibre-gl-js-yourself).

### Web: the engine moves to MapLibre GL JS 6

The web build now runs on MapLibre GL JS 6, which ships as an ES module. The plugin imports it for you, so most apps need nothing. Three setups do:

* **You self-host the library.** Point `MapLibreJsSource.urls` at the `.mjs` build rather than `.js`, and serve the whole `dist` directory: the library resolves its worker relative to its own URL. Pointing at the old `.js` build still works, because the plugin keeps the global that build defines, but you stay on version 5 while the plugin's interop is written against 6.
* **The page loads the library itself** (`MapLibreJsSource.preloaded`). An ES module defines no global, so the page has to publish `globalThis.maplibregl` explicitly. A page that still loads a version 5 bundle keeps working as before.
* **Your users are not all on WebGL2.** Version 6 requires it and dropped the WebGL1 fallback, so a browser without WebGL2 now shows no map where version 5 showed a slow one. Where WebGL2 is missing altogether, as on Safari and iOS before 15, Flutter's own renderer still runs on WebGL1, so only the map goes missing and pointing `MapLibreJsSource.urls` at a version 5 build brings it back; the plugin logs as much. Where WebGL2 exists but no context can be created, a blocklisted GPU driver for example, Flutter does not fall back either and the whole app stays blank, which no library version changes. See [Requirements](getting-started.md#requirements).

Content-Security-Policy rules do not change: version 5 also built its Web Worker from a `blob:` URL, so `worker-src 'self' blob:` was already required and still is. What changes goes in your favour: version 6 only needs `blob:` when the library
is loaded cross-origin, so a self-hosted same-origin copy can now drop it. See [Content-Security-Policy](getting-started.md#content-security-policy).

`queryRenderedFeatures` can also return a different set of features. Version 6 slices vector tiles instead of overscaling them, which upstream turned on by default because it fixes label placement, and that changes both rendering and query results. The plugin follows that default; there is no per-app switch for it. If it costs you something concrete, please open an issue.

### Behaviour changes

None of these need a code change, but they are the places where code that worked before starts behaving differently.

* **Web**: `onMapIdle` now fires. If you worked around it never running on web, that workaround can go.
* **Web**: `queryCameraPosition()`, `updateContentInsets()` and the new `setPadding()` no longer throw `UnimplementedError`, so any guard you put around them for web is no longer needed.
* **Android, iOS**: symbol annotations now render their text in `Noto Sans Regular` instead of the old `Open Sans Regular,Arial Unicode MS Regular` default, which most glyph servers do not host. If your symbols were invisible, they appear now; if they were visible, the typeface changes. The font belongs to the annotation layer, so a different one means a symbol style layer with `textFont` set. See [Markers](annotations/markers.md).
* **Android**: [feature state](advanced/feature-state.md) works instead of throwing, so a `kIsWeb` guard around those calls can go. `promoteId` is still ignored outside web, so features must carry a top-level `id` in the GeoJSON for feature state to key off.
* **Android, iOS**: the offline download errors `mapboxTileCountLimitExceeded` and `mapboxInvalidRegionDefinition` are now `tileCountLimitExceeded` and `invalidRegionDefinition`. Code that matches on `PlatformException.code` from `downloadOfflineRegion` needs the new strings; nothing else changes.
* **Android, iOS**: downloading an area that is already downloaded replaces the existing region rather than adding a duplicate. On iOS the replacement keeps the region id the app already knows; on Android the SDK assigns the id when it creates a region, so the replacement gets a new one. Read the id back from the returned `OfflineRegion` after every download.

### Android apps on AGP 9

Nothing to do, on AGP 8 or AGP 9. The plugin applies the Kotlin Gradle Plugin only where nothing else compiles its Kotlin: on AGP 9 with built-in Kotlin enabled, AGP's own default, it applies nothing and AGP compiles it; where built-in Kotlin is disabled, which is what Flutter 3.44 and later write into `android/gradle.properties` as `android.builtInKotlin=false`, it applies KGP itself.

0.27.0 got that wrong and failed to configure with `Could not find method kotlin()` on AGP 9 whenever built-in Kotlin was disabled. It is fixed in 0.27.1. If you worked around it by setting `android.builtInKotlin=true`, or by applying `kotlin-android` to the module from your root `android/build.gradle`, remove the workaround: on a multi-plugin app the flag puts every other KGP-applying plugin into a conflicting configuration.

## Upgrading from earlier 0.26 releases

No structural changes to the public API. Run `flutter pub upgrade maplibre_gl` and check the [CHANGELOG](https://github.com/maplibre/flutter-maplibre-gl/blob/main/CHANGELOG.md) for any deprecation notices.

## Release history

What each release was about, most recent first. Full details live in the [CHANGELOG](https://github.com/maplibre/flutter-maplibre-gl/blob/main/CHANGELOG.md), also rendered on [pub.dev](https://pub.dev/packages/maplibre_gl/changelog).

| Version | Highlights |
|---------|------------|
| [0.28.0](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.28.0) | Behavioral parity across Android, iOS and web: shared error codes, layer filters, camera updates, queries and feature drag. Newer MapLibre on every platform. Breaking: `setLayerFilter` returns `Future<void>` and iOS error codes are renamed; see [Upgrading to 0.28.0](#upgrading-to-0280). |
| [0.27.1](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.27.1) | Patch: fixes the Android build failure on Flutter 3.44 templates, an iOS crash on the custom-header path, and offline regions whose bounds sit on whole degrees. No API changes. |
| [0.27.0](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.27.0) | Platform gaps closed (feature state on Android, cluster inspection, offline export/import), faster start-up with `preWarm()`, a newer web renderer, documentation site. No breaking API changes; see [Upgrading to 0.27.0](#upgrading-to-0270). |
| [0.26.2](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.26.2) | Enforces the Flutter 3.29 minimum in the package constraints; fixes redundant map updates on rebuild and `doubleClickZoomEnabled` on Android and iOS. |
| [0.26.1](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.26.1) | Android stability fixes after 0.26.0, including crashes on older hardware and disposal races. |
| [0.26.0](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.26.0) | Milestone release: WASM-compatible web build, a new example app, many long-standing fixes. Breaking: `initialCameraPosition` and `requestMyLocationLatLng()` became nullable. |
| [0.25.0](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.25.0) | Logo visibility and position options, web parity work (`getStyle()`, `getSourceIds()`), clearer annotation-manager errors. |
| [0.24.1](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.24.1) | Fixes double-fired annotation taps and add-before-style-load failures. |
| [0.24.0](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.24.0) | Breaking: feature interaction callbacks stabilized with the feature id and a nullable `Annotation`, unblocking taps on style-layer features. |
| [0.23.0](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.23.0) | Breaking: `Maplibre` renamed to `MapLibre` with lowerCamelCase enums. Runtime style switching, hover interactions, heatmaps. |
| [0.22.0](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.22.0) | Breaking: MapLibre Native updates on Android and iOS, bringing PMTiles support. |
| [0.21.0](https://github.com/maplibre/flutter-maplibre-gl/releases/tag/v0.21.0) | `clearAmbientCache()`, `LatLngBounds.contains()`, Android location engine options. Breaking: `onFeatureTap` gained the `layerId`. |
