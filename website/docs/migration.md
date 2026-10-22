# Migration Guide

## Upgrading to 0.28.0

0.28.0 makes Android, iOS and web behave the same: the same error codes, the same results for the same calls, the same gestures. Most apps compile unchanged, but `setLayerFilter` changes its return type, and code that catches platform errors or relied on a platform quirk needs a look. On Android and iOS the plugin also talks to native code in a new way, which matters mostly to tests that mock it.

Update your `pubspec.yaml`:

```yaml
dependencies:
  maplibre_gl: ^0.28.0
```

Then run `flutter pub upgrade maplibre_gl`. See the [CHANGELOG](https://github.com/maplibre/flutter-maplibre-gl/blob/main/CHANGELOG.md) for the full list of changes.

### Minimum versions

The declared Android `minSdkVersion` is now 23 (Android 6.0). MapLibre Android already required it, so an app that built with 0.27 builds with 0.28 too. Flutter, Dart and iOS minimums are unchanged; see [Minimum versions](getting-started.md#minimum-versions).

### Layer filters

`setLayerFilter` returns `Future<void>` instead of `Future<bool>` and throws on failure instead of returning `false`. It also takes the filter as an expression list, like `setFilter`, besides the JSON string it took before:

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

`setFilter` and `getFilter` still work as deprecated aliases of `setLayerFilter` and `getLayerFilter`. `setLayerFilter(id, null)` and the new `removeLayerFilter(id)` remove a filter, and `getLayerFilter` returns `null` for a layer without one.

### Error codes

Every platform now reports the same error codes, all in `SCREAMING_SNAKE_CASE`. On iOS they are renamed:

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

On Android, the controller's `invalidateAmbientCache` and `clearAmbientCache` fail with `AMBIENT_CACHE_ERROR` instead of `MAPBOX CACHE ERROR`. iOS reports the same code.

The error codes of the offline calls and of the download `Error` events are renamed, on Android and iOS alike. See [Errors](advanced/offline-regions.md#errors) for when each code fires:

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

Android now rejects a negative `setOfflineTileCountLimit` with `INVALID_ARGUMENT`, as iOS did, and iOS rejects a `setOfflineMaxConcurrentRequests` value below 1, as Android did.

On Android, `resumeOfflineRegionDownload` resumes a region that no download of the current app session follows, for example one paused before the app restarted, as iOS does. It used to fail with `ResumeRegionError`. Such a download sends no events, so follow it with `getOfflineRegionStatus`. Resuming a region that is already complete does nothing on either platform.

Calls that used to fail silently on some platforms now throw everywhere. Add a `catch` where your app can hit them:

* `removeLayer`, `setLayerVisibility` and `setLayerProperties` on a missing layer throw `LAYER_NOT_FOUND_ERROR` (it did nothing on Android and web).
* Adding a source or layer with an id already in use throws `SOURCE_ALREADY_EXISTS` or `LAYER_ALREADY_EXISTS` (Android ignored it, web failed with a generic error).
* `getClusterExpansionZoom`, `getClusterChildren` and `getClusterLeaves` throw `CLUSTER_NOT_FOUND` for an unknown cluster id. Android and iOS crashed, web answered 0 or an empty list.
* `addImage` throws `STYLE_NOT_READY` before the style has loaded on iOS, as on Android, and `INVALID_IMAGE` for bytes that are not an image.
* `setLight` throws `INVALID_ARGUMENT` for a value it cannot apply on Android and iOS.
* A layer whose type cannot draw its source, such as a raster layer on a GeoJSON source, throws `UNSUPPORTED_SOURCE_TYPE`. iOS crashed, Android threw a generic error, and web added nothing or a layer that drew nothing.
* A layer property value MapLibre rejects throws `INVALID_EXPRESSION` (an expression) or `INVALID_ARGUMENT` (any other value) from the layer adds and `setLayerProperties`, and the call changes nothing. Android ignored the value, iOS crashed or misread it, and web dropped the layer.
* Data that is not a valid GeoJSON FeatureCollection, Feature or geometry throws `INVALID_GEOJSON` from `addGeoJsonSource`, `setGeoJsonSource`, `setGeoJsonFeature`, `editGeoJsonSource` and `addSource`, where Android and web left the source empty. A feature with `"id": null` counts as invalid: MapLibre Native cannot read it.
* `addSource` throws `INVALID_ARGUMENT` for an image source without a `url` or four corners, and for a tiled source without `url` or `tiles` or a GeoJSON source without `data`, which web used to add. For image bytes, use `addImageSource`.
* On web, `removeLayer`, `removeSource`, `setLayerProperties`, `setLayerVisibility`, `setLayersVisibility`, `getLayerProperties` and `getSourceProperties` throw `STYLE_NOT_READY` before the style has loaded, like on Android and iOS.
* On web, a layer `minzoom` or `maxzoom` outside 0 to 24 throws `INVALID_ARGUMENT`, where MapLibre GL JS dropped the layer. Android and iOS take any zoom.
* On Android and iOS, GeoJSON with a NaN or infinite number, properties included, throws `INVALID_GEOJSON`, since JSON cannot hold it. It threw a `JsonUnsupportedObjectError`, and `addSource` crashed on iOS. Web takes such a number.

### Android: numeric feature ids

Numeric GeoJSON feature ids stay numbers in queries and filters on Android, as on iOS and web, where they used to turn into strings. Read `feature['id']` as a `num` and compare it with `2`, not `"2"`:

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

Ids come back as they are in the data on every platform: `2` and `2.5` as numbers, `"2"` and `"poi-12"` as strings. The exception is GeoJSON loaded from a URL or declared in the style, which does not pass through the plugin: on Android and web only its integer ids are sure to come back the same.

A source added with `addSource` and `generateId: true` now numbers its features by their index on Android and iOS too, where they had no id.

### iOS: hex colors with alpha

On iOS a hex color with alpha, `#rgba` or `#rrggbbaa`, reads the alpha last, as in CSS and on Android and web. It used to read it first. If you wrote `#aarrggbb` for iOS, move the alpha to the end:

```dart
// Before (iOS): red at 50% opacity
fillColor: '#80ff0000',

// After (every platform)
fillColor: '#ff000080',
```

The plugin's `UIColor(hexString:)` extension reads it the same way.

### Android and iOS: Pigeon messages

The plugin now talks to Android and iOS through typed messages generated with [Pigeon](https://pub.dev/packages/pigeon), instead of hand-written method channels. Your map code keeps working as before, with these differences:

* A call on a map that is already disposed throws a `PlatformException` with code `MAP_DISPOSED`, where it used to throw a `MissingPluginException`. If you caught `MissingPluginException` to ignore those calls, catch `MAP_DISPOSED` instead.
* Tests that mock the plugin's method channels, `plugins.flutter.io/maplibre_gl` and `plugins.flutter.io/maplibre_gl_<id>`, no longer intercept anything. Install fakes instead: a subclass of `MapLibrePlatform` through `MapLibrePlatform.createInstance` for the map calls, and a subclass of `MapLibreGlobalPlatform` as `MapLibreGlobalPlatform.instance` for the plugin-wide calls such as offline regions. Both come from `maplibre_gl_platform_interface`.
* `setOffline`, `setOfflineTileCountLimit` and `deleteOfflineRegion` return `Future<void>` instead of `Future<dynamic>`. Their value was always `null`, so drop any use of it.
* `MapLibreMethodChannel` is deprecated and no longer reaches native code. A package that extends it should extend `MapLibrePlatform` instead.

### Feature drag and hit testing

Dragging annotations and draggable features works the same on every platform:

* A drag starts only after the finger or mouse moves a little. A tap or click on a draggable feature is a plain tap with no drag events, and the `start` event has a zero delta. On Android a drag no longer fires `onMapLongClick`.
* A second finger during a drag ends it with an `end` event and lets the map pinch. To keep dragging, the user starts a new drag.
* On Android and iOS, taps and drags find a feature within 8 logical pixels of the finger, and the nearest one wins. Android used about 3 pixels and iOS the exact point, so small features are easier to hit, and a tap next to a feature can now select it. Only draggable features start a drag.

If your app relied on a drag starting at touch down, or on tapping exactly next to a feature without selecting it, check those flows.

### Camera events

`onCameraMove` reports the same positions on every platform:

* On iOS it fires for `moveCamera` and a zero duration `animateCamera` too, and its last call before `onCameraIdle` has the position where the camera stopped.
* On web it needs `trackCameraPosition: true`, as on Android and iOS, and so does `controller.cameraPosition` to follow the camera. If your web app reads the camera position without the flag, set it.

### Web: browsers without WebGL2

The MapLibre GL JS build the plugin now loads throws when it cannot get a WebGL2 context. On such a browser the map is no longer created as a blank map: the controller future completes with an error and `onMapCreated` is not called. The error report still says whether a MapLibre GL JS 5 build, configured through `MapLibreMap.webLibrarySource`, would work there. See [Web: the engine moves to MapLibre GL JS 6](#web-the-engine-moves-to-maplibre-gl-js-6).

### Android: building without Google Play Services

Nothing changes for apps that use Google Play Services. F-Droid and other FOSS builds can now leave it out with one line in `android/gradle.properties`:

```properties title="android/gradle.properties"
maplibre_gl.playServicesLocation=false
```

See [Building without Google Play Services](advanced/user-location.md#building-without-google-play-services). F-Droid builds also need a short `prebuild` step, described in [F-Droid](advanced/user-location.md#f-droid).

### Behaviour changes

None of these need a code change, but they are the places where code that worked before starts behaving differently.

* **iOS, Web**: `setOffline` throws an `UnsupportedError`, where it used to fail with a `MissingPluginException`. Neither MapLibre iOS nor MapLibre GL JS can force the map offline, so call it on Android only.
* **Web**: the offline region calls, `getOfflineDatabasePath`, `setHttpHeaders`, `installOfflineMapTiles` and `clearAmbientCache` throw an `UnsupportedError` that names the call, where they used to fail with a `MissingPluginException`. MapLibre GL JS has no offline storage.
* **Android**: `CameraUpdate.scrollBy` pans the same way as on iOS and web: positive `x` moves the view east. Remove any Android-only sign flip.
* **Android**: `setCameraBounds` `padding` is in logical pixels like on iOS and web. Drop any scaling by the device pixel ratio.
* **iOS**: `CameraUpdate.newLatLng` and `newLatLngZoom` keep the requested zoom when the latitude changes.
* **Web**: `querySourceFeatures` applies its `filter`, `removeFeatureState` with a `stateKey` removes only that key, and `easeCamera` and `animateCamera` complete when the camera arrives instead of when they start. `animateCamera` completes with `false` when another camera call or a gesture interrupts it.
* **iOS**: `animateCamera` and `easeCamera` complete when the camera arrives, with `true`, and with `false` when another camera call, a gesture or `setPadding` interrupts them. `animateCamera` used to complete with `null`, right away when no duration was given, and `easeCamera` always with `true`.
* **iOS**: `moveCamera` completes with `true` once the camera has moved, like on Android and web, instead of `null`.
* **Android, iOS**: `animateCamera` and `easeCamera` complete with `false` when the map is disposed, or its Android activity destroyed, mid-animation, like on web, instead of never completing, so the code after an awaited call now runs. Check `mounted` there before calling `setState`.
* The `setSymbol*Overlap` and `setSymbol*IgnorePlacement` setters keep the symbol layer where it is instead of moving it on top.
* Fill annotations without a `fillOutlineColor` get an outline in their fill color on Android and iOS, where it used to be transparent.
* **Android**: on Android 12 and later devices without Google Play Services, high accuracy positions come from Android's `fused` provider instead of `gps`, so a coarser network fix can arrive before the GPS one.
* A GeoJSON, image or raster-dem source url with a space or another character a url cannot hold is percent-encoded on every platform, as browsers and iOS 17 do, so an iOS file path under `Library/Application Support` loads. `editGeoJsonUrl` answers `false` for an empty url, where Android and web answered `true`.
* Tile source `bounds` with west greater than east, which cross the antimeridian, take every longitude, so the tiles on both sides load.
* **Android**: MapLibre Android 13.7 draws `line-pattern` images at the size MapLibre GL JS uses, about 1.7 times smaller than before. iOS keeps the old size until MapLibre iOS ships the same fix.

### New options

* `MapLibreMap.panInertia` sets how long the map glides after a pan: `none`, `short` or `normal`. The default, `normal`, keeps the current behavior.
* `MapLibreMap.hapticFeedbackEnabled` turns off the vibration iOS plays when the user rotates the map back to north.
* `setMaximumAmbientCacheSize(bytes)` sets the size limit of the ambient tile cache on Android and iOS.
* `MapLibreMap.symbolPlacementTransitionsEnabled` and `setSymbolPlacementTransitionsEnabled` turn off the symbol fade, so symbols fed by data you update often no longer flicker. See [Symbols that update often](layers/symbol-layer.md#symbols-that-update-often).

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
