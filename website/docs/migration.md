# Migration Guide

## Upgrading to 0.28.0

0.28.0 makes Android, iOS and web behave the same: the same error codes, the same results, the same gestures. Most apps compile unchanged. Check the sections below if your app calls `setLayerFilter`, catches platform errors, or works around a platform quirk.

Update your `pubspec.yaml`:

```yaml
dependencies:
  maplibre_gl: ^0.28.0
```

Then run `flutter pub upgrade maplibre_gl`. The [CHANGELOG](https://github.com/maplibre/flutter-maplibre-gl/blob/main/CHANGELOG.md) lists every change.

### Minimum versions

* Flutter 3.44 and Dart 3.12. Apps on an older Flutter stay on 0.27.x.
* iOS 15.5, which MapLibre iOS 7 requires: raise `IPHONEOS_DEPLOYMENT_TARGET` in Xcode and, with CocoaPods, `platform :ios, '15.5'` in `ios/Podfile`.
* Android API 24 (`minSdkVersion`), the default of Flutter 3.44 apps: raise a lower `minSdk` in `android/app/build.gradle`.

Flutter 3.44 builds the iOS plugin with Swift Package Manager, and MapLibre iOS no longer publishes to CocoaPods. If your app turned [Swift Package Manager](getting-started.md#swift-package-manager) off, turn it back on. Add-to-app modules keep using CocoaPods.

### Layer filters

`setLayerFilter` returns `Future<void>` and throws on failure instead of returning `false`. It also takes the filter as an expression list, besides a JSON string:

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

`setFilter` and `getFilter` keep working as deprecated aliases. `setLayerFilter(id, null)` and `removeLayerFilter(id)` remove a filter.

### Error codes

Every platform reports the same codes, in `SCREAMING_SNAKE_CASE`. The iOS codes are renamed:

| Before (iOS) | 0.28.0 |
|---|---|
| `layerNotFound` | `LAYER_NOT_FOUND_ERROR` |
| `invalidExpression` | `INVALID_EXPRESSION` |
| `invalidLayerType` | `INVALID_LAYER_TYPE` |
| `sourceAlreadyExists`, `duplicateSource` | `SOURCE_ALREADY_EXISTS` |
| `layerAlreadyExists`, `duplicateLayer` | `LAYER_ALREADY_EXISTS` |
| `styleNotFound` | `STYLE_NOT_READY` |
| `sourceNotFound`, `noSuchSource` | `SOURCE_NOT_FOUND` |
| `invalidSourceType` | `UNSUPPORTED_SOURCE_TYPE`, or `INVALID_ARGUMENT` for source properties that cannot build a source |
| `parseError` | `INVALID_GEOJSON` |

On Android, the ambient cache calls fail with `AMBIENT_CACHE_ERROR`, as on iOS, and `setMapLanguage` and `matchMapLanguageWithDeviceDefault` with `LOCALIZATION_ERROR`. Android also has its own `MAP_NOT_READY`, for a call made while the map view is rebuilt after the activity was recreated.

The offline codes, of the calls and of the download `Error` events, are renamed on Android and iOS. [Errors](advanced/offline-regions.md#errors) says when each one fires:

| Before | 0.28.0 |
|---|---|
| `invalidRegionDefinition` | `INVALID_REGION_DEFINITION` |
| `tileCountLimitExceeded` | `TILE_COUNT_LIMIT_EXCEEDED` |
| `RegionDeleted` | `REGION_DELETED` |
| `RegionReplaced` | `REGION_REPLACED` |
| `DatabaseReset` | `DATABASE_RESET` |
| `UpdateMetadataError`, `DeleteRegionError`, `PauseRegionError`, `ResumeRegionError`, `GetRegionStatusError` for an id no region has | `REGION_NOT_FOUND` |
| `mergeOfflineRegions Error`, `RegionListError`, `ResetDatabaseError`, and the five codes above for any other failure of the database | `OFFLINE_DATABASE_ERROR` |
| `ClearAmbientCacheError`, `SetMaximumAmbientCacheSizeError` | `AMBIENT_CACHE_ERROR` |
| `SetOfflineTileCountLimitError` and `SetMaximumAmbientCacheSizeError` for a negative value (iOS), `InvalidMaxRequests`, `InvalidMaxRequestsPerHost` (Android), `UpdateMetadataError` for metadata that is not JSON-encodable (iOS) | `INVALID_ARGUMENT` |
| `SetHttpHeadersError`, `SetMaxConcurrentRequestsError` (Android) | `HTTP_CLIENT_ERROR` |

#### Calls that now throw

Calls that did nothing, or crashed, on some platforms now throw on all of them. Add a `catch` where your app can hit them:

* Source, layer and image calls made before the style has loaded throw `STYLE_NOT_READY`.
* A missing layer throws `LAYER_NOT_FOUND_ERROR`, and a source or layer id already in use `SOURCE_ALREADY_EXISTS` or `LAYER_ALREADY_EXISTS`.
* Data that is not valid GeoJSON throws `INVALID_GEOJSON` from the GeoJSON calls and `addSource`. A feature with `"id": null` counts as invalid.
* A layer property value MapLibre rejects throws `INVALID_EXPRESSION` for an expression or `INVALID_ARGUMENT` for any other value, and changes nothing.
* A layer whose type cannot draw its source, such as a raster layer on a GeoJSON source, throws `UNSUPPORTED_SOURCE_TYPE`.
* A layer on a vector source without `sourceLayer` throws `SOURCE_LAYER_REQUIRED`.
* `addSource` throws `INVALID_ARGUMENT` for an image source without `url` or corners, or a source without `url`, `tiles` or `data`. Image bytes go through `addImageSource`.
* The cluster calls throw `CLUSTER_NOT_FOUND` for an unknown cluster, and `getClusterLeaves` throws `INVALID_ARGUMENT` for a negative `limit` or `offset`.
* `addImage` throws `INVALID_IMAGE` for bytes that are not an image.
* `installOfflineMapTiles` throws `INVALID_ARGUMENT` for a missing file and `OFFLINE_DATABASE_ERROR` when the copy fails.
* **Android, iOS**: `setLight` throws `INVALID_ARGUMENT` for a value it cannot apply.
* **Android, iOS**: GeoJSON with a NaN or infinite number throws `INVALID_GEOJSON`, since JSON cannot hold it. Web takes such a number.
* **Android, iOS**: offline metadata `jsonEncode` cannot encode, such as `NaN`, throws `INVALID_ARGUMENT`, and so do a negative `setOfflineTileCountLimit` and a `setOfflineMaxConcurrentRequests` below 1.
* **Web**: a layer `minzoom` or `maxzoom` outside 0 to 24 throws `INVALID_ARGUMENT`. Android and iOS take any zoom.

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

Ids come back as they are in the data, except for GeoJSON loaded from a URL or declared in the style: on Android and web only its integer ids are sure to match. With `generateId: true`, Android and iOS number the features by index too.

### iOS: hex colors with alpha

On iOS `#rgba` and `#rrggbbaa` read the alpha last, as in CSS and on Android and web. If you wrote `#aarrggbb` for iOS, move the alpha to the end:

```dart
// Before (iOS): red at 50% opacity
fillColor: '#80ff0000',

// After (every platform)
fillColor: '#ff000080',
```

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

### Android and iOS: Pigeon messages

The plugin talks to Android and iOS through typed [Pigeon](https://pub.dev/packages/pigeon) messages instead of method channels. Map code works as before, with these differences:

* A call on a disposed map throws a `PlatformException` with code `MAP_DISPOSED` instead of a `MissingPluginException`.
* `setOffline`, `setOfflineTileCountLimit` and `deleteOfflineRegion` return `Future<void>`: their value was always `null`.
* Tests that mock the plugin's method channels no longer intercept anything. Install a fake `MapLibrePlatform` through `MapLibrePlatform.createInstance`, and a fake `MapLibreGlobalPlatform` as `MapLibreGlobalPlatform.instance`.
* `MapLibreMethodChannel` and `MapLibreGlobalMethodChannel` are removed: a fake or a platform package extends `MapLibrePlatform` or `MapLibreGlobalPlatform`.
* A fake or a platform package passes what started a camera move to `onCameraMoveStartedPlatform`, which no longer takes `null`.

```dart
// Before
class FakeMapPlatform extends MapLibreMethodChannel { ... }
tearDown(() => MapLibreGlobalPlatform.instance = MapLibreGlobalMethodChannel());
onCameraMoveStartedPlatform(null);

// After
class FakeMapPlatform extends MapLibrePlatform {
  // Override what the test calls; any other call throws.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
final previous = MapLibreGlobalPlatform.instance;
addTearDown(() => MapLibreGlobalPlatform.instance = previous);
onCameraMoveStartedPlatform(CameraMoveReason.programmatic); // or .gesture
```

### Feature drag and hit testing

Dragging annotations and draggable features works the same on every platform:

* A drag starts only after the finger or mouse moves a little, so a tap on a draggable feature stays a tap, with no drag events.
* A second finger ends the drag with an `end` event and lets the map pinch.
* **Android**: a drag no longer fires `onMapLongClick`.
* **Android, iOS**: taps and drags pick the nearest feature within 8 logical pixels, so a tap next to a feature can now select it.
* **Web**: features can be dragged with a finger on touch screens too.

If a flow relied on a drag starting at touch down, or on tapping right next to a feature without selecting it, check it.

### Web: browsers without WebGL2

On a browser without WebGL2 the map is no longer created blank: the controller future completes with an error and `onMapCreated` is not called. The error says whether a MapLibre GL JS 5 build would work, see [Web: the engine moves to MapLibre GL JS 6](#web-the-engine-moves-to-maplibre-gl-js-6).

### Android: building without Google Play Services

Nothing changes for apps that use Google Play Services. F-Droid and other FOSS builds can leave it out with one line:

```properties title="android/gradle.properties"
maplibre_gl.playServicesLocation=false
```

See [Building without Google Play Services](advanced/user-location.md#building-without-google-play-services), and [F-Droid](advanced/user-location.md#f-droid) for its `prebuild` step.

### Android: platform view mode

`useHybridComposition` and `translucentTextureSurface` are deprecated in favor of `androidView`, which sets for each map the view it draws into and how Flutter places it:

```dart
// Before
MapLibreMap.useHybridComposition = true; // or MapLibreMethodChannel.useHybridComposition
MapLibreMap(translucentTextureSurface: true);

// After
MapLibreMap(androidView: const AndroidMapView(surface: AndroidMapSurface.textureView));
MapLibreMap(androidView: const AndroidMapView(surface: AndroidMapSurface.translucentTextureView));
```

Despite its name, `useHybridComposition` never selected Hybrid Composition: that is `composition: AndroidComposition.hybridComposition`. See [Platform view mode (Android)](advanced/performance.md#platform-view-mode-android).

### Behaviour changes

None of these need a code change, but code that worked before can behave differently.

#### Camera

* `animateCamera` and `easeCamera` complete when the camera arrives, with `false` when interrupted, so code after an awaited call runs after the animation.
* **Android, iOS**: they complete with `false` when the map is disposed mid-animation, instead of never: check `mounted` before calling `setState`.
* **Android**: `CameraUpdate.scrollBy` pans as on iOS and web, so a positive `x` moves the view east: remove any Android-only sign flip.
* **Android**: `setCameraBounds` `padding` is in logical pixels, as on iOS and web: drop any scaling by the pixel ratio.
* **iOS**: `moveCamera` completes with `true` instead of `null`, and `newLatLng` and `newLatLngZoom` keep the requested zoom.
* **iOS**: `onCameraMove` also fires for moves without animation, and its last call has the position where the camera stopped.
* **iOS, Web**: `cameraTargetBounds` keeps the camera target inside the bounds, as on Android, so the map no longer zooms in to fit them.
* **Web**: `onCameraMove` and `controller.cameraPosition` need `trackCameraPosition: true`, as on Android and iOS.

#### Layers and sources

* The `setSymbol*Overlap` and `setSymbol*IgnorePlacement` setters keep the symbol layer in its place instead of moving it on top.
* A source url with a space, such as an iOS path under `Library/Application Support`, is percent-encoded and loads on every platform.
* Tile source `bounds` that cross the antimeridian, with west greater than east, load the tiles on both sides.
* **Android, iOS**: fill annotations without a `fillOutlineColor` get an outline in their fill color instead of a transparent one.
* **Android, iOS**: `line-pattern` images are drawn at the size MapLibre GL JS uses, about 1.7 times smaller than before.
* **iOS**: an `iconImage` naming an asset with `2.0x` or `3.0x` variants is sized like `Image.asset`: drop any iOS-only `iconSize` that made up for it.
* **iOS**: [feature state](advanced/feature-state.md) works, so a platform guard can go. Features need a top-level `id`: `promoteId` is web only.
* **iOS**: `getLayerProperties` and `getSourceProperties` read layers and sources added at runtime, and colors read as `rgba(...)` text, like Android.
* **Web**: `querySourceFeatures` applies its `filter`, and `removeFeatureState` with a `stateKey` removes only that key.

#### Offline and network

* **Android**: the `setCustomHeaders` filter matches anywhere in the URL, as on iOS, so headers can reach more URLs: anchor it with `^` and `$`.
* **Android**: `resumeOfflineRegionDownload` resumes a region paused in an earlier app session, as on iOS. Follow it with `getOfflineRegionStatus`: it sends no events.
* **Android, iOS**: offline region metadata is stored as `jsonEncode` writes it, so a `Uint8List` is a list of numbers.
* **iOS, Web**: `setOffline` throws an `UnsupportedError`: neither can force the map offline, so call it on Android only.
* **Web**: the offline calls, `setHttpHeaders`, `setCustomHeaders` and `getCustomHeaders` throw an `UnsupportedError` that names the call.

#### Location

* `updateManualLocation` works on every map created with `ManualLocationSource()`, also while `myLocationEnabled` is off: the puck appears once it is on.
* **Android**: on Android 12 and later without Google Play Services, high accuracy uses the `fused` provider, so a network fix can arrive before the GPS one.
* **Web**: `updateManualLocation` throws `MANUAL_LOCATION_SOURCE_DISABLED` without `ManualLocationSource()`, as on Android and iOS.

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
