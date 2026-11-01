# CHANGELOG

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## Unreleased

### Highlights
0.28.0 makes Android, iOS and web work alike: the same call now gives the same result, the same error code and the same gesture on every platform. On Android and iOS the plugin now talks to native code through typed messages generated with [Pigeon](https://pub.dev/packages/pigeon) instead of hand-written method channels, so a call that one platform lacks is caught before a release instead of failing in your app. Most apps upgrade without code changes: check Actions needed below and the [migration guide](https://maplibre.org/flutter-maplibre-gl/migration/#upgrading-to-0280).

### Actions needed
* `setLayerFilter` returns `Future<void>` instead of `Future<bool>`, and throws on failure instead of returning `false`. Replace checks on the result with a `try`/`catch` (#1055).
* Error codes are renamed to the same codes on every platform. Update any `catch` on the old ones (#1055, #1068, #1111, #1119, #1143):
  * **iOS**: `layerNotFound` is now `LAYER_NOT_FOUND_ERROR`
  * **iOS**: `invalidExpression` is now `INVALID_EXPRESSION`
  * **iOS**: `invalidLayerType` is now `INVALID_LAYER_TYPE`
  * **iOS**: `sourceAlreadyExists` and `duplicateSource` are now `SOURCE_ALREADY_EXISTS`
  * **iOS**: `layerAlreadyExists` and `duplicateLayer` are now `LAYER_ALREADY_EXISTS`
  * **Android**: `MAPBOX CACHE ERROR` from the controller's `invalidateAmbientCache` and `clearAmbientCache` is now `AMBIENT_CACHE_ERROR`
  * **Android**: `MAPBOX LOCALIZATION PLUGIN ERROR` from `setMapLanguage` and `matchMapLanguageWithDeviceDefault` is now `LOCALIZATION_ERROR`
  * **iOS**: `styleNotFound` is now `STYLE_NOT_READY`
  * **iOS**: `sourceNotFound` and `noSuchSource` are now `SOURCE_NOT_FOUND`
  * **iOS**: `invalidSourceType` is now `UNSUPPORTED_SOURCE_TYPE`, or `INVALID_ARGUMENT` for source properties that cannot build a source
  * **iOS**: `parseError` is now `INVALID_GEOJSON`
  * **Android, iOS**: the offline error codes are in `SCREAMING_SNAKE_CASE`, for example `invalidRegionDefinition` is now `INVALID_REGION_DEFINITION` and an unknown region id answers `REGION_NOT_FOUND`. The [migration guide](https://maplibre.org/flutter-maplibre-gl/migration/#error-codes) lists each one
* Some calls that used to do nothing, or crash the app, now throw. Add a `catch` where your app can hit them (#1065, #1068, #1119, #1123, #1140, #1143):
  * **Android, Web**: `removeLayer`, `setLayerVisibility` and `setLayerProperties` on a missing layer throw `LAYER_NOT_FOUND_ERROR`.
  * **Android, Web**: adding a source or layer with an id already in use throws `SOURCE_ALREADY_EXISTS` or `LAYER_ALREADY_EXISTS`.
  * `getClusterExpansionZoom`, `getClusterChildren` and `getClusterLeaves` throw `CLUSTER_NOT_FOUND` for an unknown cluster id. Android and iOS crashed, web answered 0 or an empty list.
  * Source and layer calls made before the style has loaded throw `STYLE_NOT_READY` on every platform. On Android the GeoJSON calls and `addSource` did nothing or failed with a generic error.
  * **Android, Web**: `setGeoJsonSource`, `setGeoJsonFeature` and the layer adds throw `SOURCE_NOT_FOUND` for a missing source.
  * Data MapLibre cannot use throws: `INVALID_GEOJSON` for data that is not GeoJSON, `INVALID_EXPRESSION` or `INVALID_ARGUMENT` for a filter or property value it rejects, `UNSUPPORTED_SOURCE_TYPE` for a layer that cannot draw its source, and `INVALID_ARGUMENT` for an `addSource` it cannot build. Android and web ignored these, iOS crashed on some.
  * A layer on a vector source without `sourceLayer` throws `SOURCE_LAYER_REQUIRED`. Android and iOS added a layer that drew nothing, web dropped it.
  * **Web**: a layer `minzoom` or `maxzoom` outside 0 to 24 throws `INVALID_ARGUMENT`, where MapLibre GL JS dropped the layer. Android and iOS take any zoom, as before.
  * `setGeoJsonSource` and `setGeoJsonFeature` on a source that is not GeoJSON throw `UNSUPPORTED_SOURCE_TYPE` instead of `SOURCE_NOT_FOUND`.
  * A hex color with a digit that is not hex, such as `#ggg`, throws `INVALID_ARGUMENT` instead of drawing black.
  * `addSource` throws `INVALID_ARGUMENT` for bounds, tile zoom levels or a GeoJSON url MapLibre cannot use. On Android an empty `url` counts as missing.
  * `getClusterLeaves` throws `INVALID_ARGUMENT` for a negative `limit` or `offset`. iOS read them as 0 and Android passed them on to MapLibre.
  * **Android, iOS**: `downloadOfflineRegion` and `updateOfflineRegionMetadata` throw `INVALID_ARGUMENT` for metadata `jsonEncode` cannot encode, such as `NaN` or a map with keys that are not strings. Other metadata is stored as `jsonEncode` writes it, so a `Uint8List`, which iOS rejected, is a list of numbers on both platforms.
  * **Android, iOS**: `installOfflineMapTiles` throws `INVALID_ARGUMENT` when there is no file at the path or asset, and `OFFLINE_DATABASE_ERROR` when the copy fails. iOS crashed on a missing asset, and both reported success after a failed copy.
* **Android**: the `filter` of `setCustomHeaders` matches a pattern found anywhere in the URL, as on iOS and as documented; anchor it with `^` and `$` to keep matching the whole URL (#1143).
* **Android**: numeric GeoJSON feature ids stay numbers in queries and filters, so read `feature['id']` as `num` (not `String`) and compare it with `2`, not `"2"`. Ids come back as they are in the data on every platform, except for GeoJSON loaded from a URL or declared in the style: see the migration guide (#1073, #1124).
* **Android, iOS**: tests that mock the plugin's method channels no longer intercept its calls, and `MapLibreMethodChannel` is removed. Install a fake `MapLibrePlatform` through `MapLibrePlatform.createInstance`, and a fake `MapLibreGlobalPlatform` as `MapLibreGlobalPlatform.instance` for the plugin-wide calls. See the [migration guide](https://maplibre.org/flutter-maplibre-gl/migration/#android-and-ios-pigeon-messages) (#1114, #1115, #1133).
* A fake `MapLibrePlatform` or a platform package passes what started the move to `onCameraMoveStartedPlatform`, which no longer takes `null`. Replace `onCameraMoveStartedPlatform(null)` with `onCameraMoveStartedPlatform(CameraMoveReason.programmatic)`. See the [migration guide](https://maplibre.org/flutter-maplibre-gl/migration/#camera-events) (#1159).
* **Web**: `setGeoJsonFeature` finds a feature by its top-level `id` only, as on Android and iOS. A feature with its id only in `properties['id']` is not updated (#1123).
* **Web**: `onCameraMove` and the controller's `cameraPosition` need `trackCameraPosition: true`, as on Android and iOS. Set it if your web app reads the camera position (#1126).
* **Android**: screen points are in logical pixels, like on iOS and web, instead of physical pixels: `toScreenLocation`, `toScreenLocationBatch`, `toLatLng`, `queryRenderedFeatures`, `queryRenderedFeaturesInRect`, and the point of `onMapClick`, `onMapLongClick`, `onFeatureTapped` and `onFeatureDrag`. Remove any Android-only multiplication or division by `devicePixelRatio` (#1130).

### Added
* `removeLayerFilter(layerId)` removes a layer's filter (#1055).
* `MapLibreMap.panInertia` sets how long the map keeps gliding after a pan: `none`, `short` or `normal` (#1032).
* **iOS**: `MapLibreMap.hapticFeedbackEnabled` turns off the light vibration played when the user rotates the map back to north (#1036).
* **Android, iOS**: `setMaximumAmbientCacheSize(bytes)` sets the size limit of the ambient tile cache; `0` turns it off (#1037).
* **Web**: `SymbolLayerProperties.symbolHeightOffset` and `symbolHeightAnchor` raise icons and text above the map. Android and iOS ignore them (#1084).
* `Expressions.semiliteral` builds an array whose elements are expressions, for properties such as `textOffset`. MapLibre Android 13.7 and iOS 6.31 support it, though the style spec does not list them yet (#1084).
* `MapLibreMap.symbolPlacementTransitionsEnabled` and `setSymbolPlacementTransitionsEnabled` turn off the symbol fade, so a symbol whose data just changed no longer flickers (#1056).
* `moveLayer(layerId, belowLayerId: ...)` moves a layer under another one, or to the top, without recreating it (#1086).
* `setLayerZoomRange(layerId, minzoom, maxzoom)` changes the zoom range in which a layer is drawn (#1092).
* `MapLibreMap.attributionEnabled` hides the attribution (i) button; the attribution must then be shown elsewhere (#1092).
* **Android**: `MapLibreMap.androidView` sets, for each map, the view the map draws into (`AndroidMapSurface`) and who puts it on screen with your widgets (`AndroidComposition`): Flutter, the default, or Android with the new `AndroidComposition.hybridComposition`. Try it when map updates show up late, only when something else on screen moves. See the [performance guide](https://maplibre.org/flutter-maplibre-gl/advanced/performance/#platform-view-mode-android) (#1161).
* **Android**: `maplibre_gl.playServicesLocation=false` in `android/gradle.properties` builds the plugin without Google Play Services, for F-Droid and other FOSS builds; high accuracy then uses the platform location engine (#1102).
* **Android**: `maplibre_gl.renderer` in `android/gradle.properties` picks the rendering backend: `opengl` (the default, as before), `vulkan`, or `auto` for Vulkan with an OpenGL ES fallback. The [performance guide](https://maplibre.org/flutter-maplibre-gl/advanced/performance/#rendering-backend-android) explains what each one costs (#1160).
* `MapLibreMap.myLocationStyle` recolors the user-location puck: dot, bearing arrow, accuracy circle and pulse (#1101).
* `setLayersVisibility(layerIds, visible)` shows or hides several layers in one call; ids with no layer are skipped and returned (#1109).
* **Web**: `addImageSource`, `updateImageSource`, `addImageLayer` and `addImageLayerBelow` work as on Android and iOS, with the same errors (#1119).
* `addImage` takes an optional `pixelRatio`, the number of image pixels per logical pixel. By default web draws one image pixel per logical pixel and Android and iOS one per device pixel; pass `MediaQuery.devicePixelRatioOf(context)` for the same size on every platform (#1129).
* `MapLibreMap.onCameraMoveStarted` tells whether a gesture of the user or something else, such as a camera call, moved the camera, and the controller's `cameraMoveReason` keeps it until the camera stops (#1159).

### Changed
* `setLayerFilter` and `getLayerFilter` are the methods for layer filters, like `setLayerProperties`. `setFilter` and `getFilter` are deprecated aliases (#1055).
* **Android**: `useHybridComposition` and `translucentTextureSurface` are deprecated in favor of `androidView`: they are `AndroidMapSurface.textureView` and `translucentTextureView`, and despite its name `useHybridComposition` never selected Flutter's Hybrid Composition. A map keeps the view of its first build: changing a flag later no longer recreates a map already on screen when it rebuilds. See the [migration guide](https://maplibre.org/flutter-maplibre-gl/migration/#android-platform-view-mode) (#1163, #1161).
* **Android**: MapLibre Native upgraded from 13.5.0 to 13.7.1 ([13.6.0](https://github.com/maplibre/maplibre-native/releases/tag/android-v13.6.0), [13.7.1](https://github.com/maplibre/maplibre-native/releases/tag/android-v13.7.1)). It fixes crashes when queries or feature state calls race with the map being disposed, and loads raster-dem tiles at the rounded zoom like web. The declared `minSdkVersion` is now 23, which MapLibre Android already required. `line-pattern` images are drawn at the size MapLibre GL JS uses, about 1.7x smaller than before; iOS keeps the old size until MapLibre iOS ships the same fix (#1080).
* **Web**: maplibre-gl-js upgraded from 6.4.1 to 6.14.0 ([release notes](https://github.com/maplibre/maplibre-gl-js/blob/main/CHANGELOG.md)): fewer main thread stalls, better complex scripts and right-to-left labels without a plugin, and a fix for a crash when `removeFeatureState` removes a property that was never set. On a browser without WebGL2, creating the map now fails: the controller future completes with an error and `onMapCreated` is not called, instead of handing out a blank map. The error report still says whether a maplibre-gl-js 5 build would work (#1081).
* **iOS**: MapLibre Native upgraded from 6.28.0 to 6.31.0 ([6.29.0](https://github.com/maplibre/maplibre-native/releases/tag/ios-v6.29.0), [6.30.0](https://github.com/maplibre/maplibre-native/releases/tag/ios-v6.30.0), [6.31.0](https://github.com/maplibre/maplibre-native/releases/tag/ios-v6.31.0)). It repaints symbol paint properties driven by feature state, fixes missing symbols and glyphs, and supports the `split` and `join` expressions like Android (#1082).
* **Android**: on devices without Google Play Services, high accuracy uses Android's own fused provider on Android 12 and later instead of GPS only, which adds network positioning where the device has a network location provider (#1102).
* **Android, iOS**: the plugin reaches native code through typed messages generated with [Pigeon](https://pub.dev/packages/pigeon) instead of hand-written method channels, starting with the plugin-wide calls: offline regions, the offline database, the ambient cache, HTTP headers and `preWarm`. `setOffline`, `setOfflineTileCountLimit` and `deleteOfflineRegion` return `Future<void>` instead of `Future<dynamic>`; their value was always `null` (#1114).
* **Android, iOS**: the calls and events of each map (taps, drags, camera moves, style loads, location updates) move to Pigeon too, which completes the switch of #465 (#1115, #1117, #1119).
* **Android, iOS, Web**: feature drags and taps work the same on every platform (#1044, #1051, #1077, #1079, #1149):
  * A drag starts only after the finger or mouse moves a little, so a tap or click on a draggable feature stays a tap, with no drag events, and `start` has a zero delta. On Android it no longer fires `onMapLongClick`.
  * A second finger ends the drag with an `end` event and lets the map pinch.
  * **Android, iOS**: taps and drags find a feature within 8 logical pixels of the finger, and the nearest one wins. Android used about 3 logical pixels and iOS the exact point.
  * **Web**: draggable features can be dragged with a finger on touch screens, not only with the mouse.
* Camera animations complete when the camera arrives, on every platform, so code after an awaited call runs after the animation (#1069, #1089, #1106, #1107, #1108):
  * **Web**: `animateCamera` and `easeCamera` used to complete when the camera started. `animateCamera` completes with `false` when another camera call or a gesture interrupts it.
  * **iOS**: `animateCamera` and `easeCamera` complete with `true`, or `false` when another camera call, a gesture or `setPadding` interrupts them. `animateCamera` used to complete with `null`, right away when no duration was given, and `easeCamera` always with `true`. `moveCamera` completes with `true` instead of `null`.
  * **Android, iOS**: when the map is disposed, or its Android activity destroyed, before the camera arrives, `animateCamera` and `easeCamera` complete with `false` instead of never completing. Check `mounted` or `controller.isDisposed` before using the controller or calling `setState` there.
* Calls that cannot run fail with an error that says why, instead of a `MissingPluginException` (#1111, #1114, #1115, #1143):
  * **iOS, Web**: `setOffline` throws an `UnsupportedError`. MapLibre iOS and maplibre-gl-js have no offline switch, so the call never had an effect there; call it on Android only.
  * **Web**: the offline region calls, `getOfflineDatabasePath`, `setHttpHeaders`, `installOfflineMapTiles` and `clearAmbientCache` throw an `UnsupportedError` that names the call. MapLibre GL JS has no offline storage (#937).
  * **Android, iOS**: a call on a map that is already disposed throws a `PlatformException` with code `MAP_DISPOSED`.
  * **Web**: `setCustomHeaders` and `getCustomHeaders` throw an `UnsupportedError` instead of an `UnimplementedError`. MapLibre GL JS has no per-URL headers.
* **Android, iOS**: fill annotations without a `fillOutlineColor` get an outline in their fill color instead of a transparent one; set `fillOutlineColor` to keep the old look (#1074).
* **Android, iOS**: `addSource` with a video source throws `UNSUPPORTED_SOURCE_TYPE`: only web can play video sources (#1119).
* **Android**: `resumeOfflineRegionDownload` resumes a region paused in an earlier app session, as iOS does. It sends no events: follow it with `getOfflineRegionStatus` (#1119).
* **iOS**: a hex color with alpha, `#rgba` or `#rrggbbaa`, reads the alpha last, as in CSS and on Android and web. An app that wrote `#aarrggbb` for iOS gets other colors: move the alpha to the end. The plugin's `UIColor(hexString:)` extension reads it the same way (#1123).
* **iOS**: `addBackgroundLayer` with a `belowLayerId` the style does not have puts the layer on top, as on Android and web, instead of throwing `LAYER_NOT_FOUND_ERROR` (#1123).
* An `iconImage` that names a Flutter asset with `2.0x` or `3.0x` variants is sized like `Image.asset` on every platform: the file nearest the screen, at its own ratio. iOS drew these icons up to 3 times smaller and web always used the main file. An asset without variants keeps the `addImage` default size (#1131).
* **iOS**: `getTelemetryEnabled` answers `false` and `setTelemetryEnabled` does nothing, as on Android and web: MapLibre collects no telemetry. iOS stored the flag and answered it back (#1142).
* **iOS, Web**: `updateManualLocation` works on every map created with `ManualLocationSource()`: with `myLocationEnabled` off the location is kept and the puck appears there when it is turned on, without `onUserLocationUpdated` meanwhile. Web throws `MANUAL_LOCATION_SOURCE_DISABLED` without the manual source, as Android and iOS (#1142).
* **Android**: `updateManualLocation` works on every map created with `ManualLocationSource()`: with `myLocationEnabled` off the location is kept and the puck appears there when it is turned on, instead of throwing `LOCATION_COMPONENT_NOT_READY` when the map was created with the location off (#1143).

### Fixed
* Disposing the map while its style is loading no longer throws an unhandled `MissingPluginException` from the annotation setup, also while the map is still being created (#1103, #1110).
* Layer filters now behave the same on Android, iOS and web (#1055):
  * `setLayerFilter` works on every filterable layer type. On web it threw `UnimplementedError`.
  * `null` removes a filter. Before, it was ignored or threw.
  * `getLayerFilter` returns `null` for a layer without a filter instead of failing.
  * A missing layer throws `LAYER_NOT_FOUND_ERROR`, and an invalid filter throws `INVALID_EXPRESSION` with the reason. Before, iOS crashed and Android and web ignored it.
  * **Android**: large numbers in a filter, such as feature ids, keep their exact value instead of being rounded.
* **Android**: `setCameraBounds` completes instead of never returning, and its `padding` is in logical pixels like on iOS and web: drop any scaling by the pixel ratio (#1067).
* **Android, iOS**: `takeSnapshot` works for a style set as JSON (#1067).
* **iOS**: `addImageLayer` completes, and `addImage` with bytes that are not an image throws `INVALID_IMAGE` instead of never returning (#1067).
* **iOS**: `addImage` before the style has loaded throws `STYLE_NOT_READY` like Android instead of silently adding nothing (#1067).
* **iOS**: the controller's `invalidateAmbientCache` and `clearAmbientCache` report a failure as `AMBIENT_CACHE_ERROR`, like Android. They answered with a raw native error the method channel cannot encode (#1111).
* **Android, iOS**: `getLayerVisibility` is implemented instead of throwing `MissingPluginException` (#1068).
* **Web**: `getLayerVisibility` answers `null` for a missing layer instead of `true` (#1068).
* `CameraUpdate.zoomBy` with a `focus` keeps that point fixed on screen instead of recentering on it (#1069).
* **Android**: camera calls with `CameraUpdate.scrollBy` complete with `true`, animate, and pan the same way as on iOS and web: positive `x` moves the view east, so remove any Android-only sign flip (#1069).
* **iOS**: `CameraUpdate.scrollBy` no longer changes the zoom when panning north or south (#1069).
* **iOS**: `initialCameraPosition` is applied in full instead of sometimes opening at zoom 0, and `CameraUpdate.newLatLngZoom` and `newLatLng` keep the requested zoom when the latitude changes (#1072).
* **Android, Web**: GeoJSON source data can be a FeatureCollection, a Feature or a bare geometry, as on iOS (#1073).
* **Web**: `querySourceFeatures`, `queryRenderedFeatures` and `queryRenderedFeaturesInRect` return features while tiles or a source update are loading, instead of failing or returning nothing (#1076).
* **Web**: `querySourceFeatures` applies its `filter` and returns Dart maps and lists instead of JS objects; drop any filtering or conversion you did on the result (#1064).
* **Web**: `removeFeatureState` with a `stateKey` removes only that key instead of the whole feature state (#1066).
* The `setSymbol*Overlap` and `setSymbol*IgnorePlacement` setters keep the symbol layer in its place instead of moving it on top (#1071).
* When two style loads overlap, `onStyleLoadedCallback` fires once, for the newer style, instead of once per load (#1088).
* **iOS**: `getStyle` returns the style JSON instead of `null` (#1070).
* **Android, iOS**: `setLight` rejects a value it cannot apply with `INVALID_ARGUMENT` and leaves the light unchanged (#1070).
* **Web**: `addImage` throws `INVALID_IMAGE` for bytes that are not an image, and replaces an image with the same name (#1070).
* **Android**: `getLayerProperties` and `getSourceProperties` find layers and sources added at runtime instead of returning `null` (#1070).
* **iOS**: a feature drag interrupted by the system (a call, Control Center, the app going to the background) now ends, instead of leaving the feature grabbed so the next pan drags it (#1054).
* **iOS**: a feature drag no longer turns scroll gestures back on when the app disabled them, and picks the feature where the finger came down, so a quick grab on a small feature no longer misses it (#1054).
* **Web**: fill annotations without a `fillOutlineColor` are drawn again (#1074).
* **iOS**: `updateOfflineRegionMetadata` works instead of throwing `MissingPluginException`, and fails with `REGION_NOT_FOUND` for an unknown id like Android (#1087).
* **iOS**: `getListOfRegions` returns the stored regions right after launch instead of an empty list, and the other offline calls no longer miss a stored region then (#1087).
* **Web**: changing another map option no longer moves the attribution control back to the bottom right (#1092).
* **Web**: removing an interactive layer also removes its hover and drag listeners, so a layer added again, or rebuilt by an annotation manager, fires each callback once instead of once per add (#1089).
* **Web**: removing a hovered layer, or setting a new style, reports a hover `leave` and resets the cursor (#1089).
* Camera updates and projections give the same result on every platform (#1090):
  * **iOS**: `CameraUpdate.tiltTo` keeps the zoom, instead of changing it along with the pitch.
  * **iOS**: `CameraUpdate.newLatLngBounds` with padding moves the center so the bounds sit in the middle of the padded area, instead of only zooming out.
  * **Android**: `CameraUpdate.newLatLngBounds` padding applies to that move only and no longer replaces the padding set with `updateContentInsets`.
  * **Web**: `CameraUpdate.newLatLngBounds` keeps the current bearing instead of turning the map north up.
  * **Android, iOS**: `moveCamera`, `animateCamera` and `easeCamera` throw `INVALID_ARGUMENT` for a camera update they cannot read, and `toScreenLocation`, `toScreenLocationBatch`, `toLatLng` and `getMetersPerPixelAtLatitude` for arguments they cannot read, instead of never completing on iOS or failing with a generic error on Android.
* `addLayer` applies `filter` to fill extrusion and heatmap layers, and `enableInteraction` to fill extrusion layers, instead of dropping them; `addHeatmapLayer` takes a `filter` too (#1088).
* **Android, iOS**: `addHeatmapLayer` applies `sourceLayer` instead of ignoring it (#1088).
* Removing a `MapLibreMap` before its platform view is created no longer throws `LateInitializationError` (#1088).
* The built-in annotation setup no longer throws an unhandled error when the style is not ready or is replaced while it runs (#1088).
* **Android, iOS**: tapping or dragging inside a polygon hole no longer selects the polygon (#1093).
* **Android**: with `myLocationEnabled`, the GPS no longer stays on after the app goes to the background, so `onUserLocationUpdated` stops there as on iOS; use a background location plugin if you need positions then. On Android and iOS, `pauseMap()` also stops location updates until `resumeMap()` (#1105).
* Updating or dragging one annotation sends only that feature instead of the whole source: about 5x faster with 1,000 circles on Android (#1113).
* **Android, iOS**: two offline downloads started together both run and each reports its own progress. The second one used to fail with `downloadOfflineRegion#setup NOT CALLED`, and the first one sent its events to the second one's `onEvent` (#1114).
* **iOS**: `downloadOfflineRegion` with a definition iOS cannot read fails with `INVALID_REGION_DEFINITION`, like Android, instead of a `TypeError` (#1114).
* **iOS**: `toScreenLocationBatch` with no points answers an empty list instead of crashing the app (#1140).
* Android, iOS and web give the same answer in more cases (#1119):
  * No crash on a query filter MapLibre rejects (Android, iOS), nor on an invalid property expression, a layer on a source it cannot draw or an image source with missing corners (iOS). Such queries throw `INVALID_EXPRESSION`.
  * **iOS**: `getLayerIds` and `getSourceIds` before the style loads, `editGeoJsonSource` and `editGeoJsonUrl` without a style, and the image source calls with bytes that are not an image answer instead of never completing.
  * `setLayerProperties` applies all the values or none.
  * `getSourceProperties` returns the same shape for image sources on every platform.
  * A layer added below a layer the style does not have goes on top.
  * `setGeoJsonFeature` works after `editGeoJsonSource` and on a source that holds a single Feature.
  * **Web**: `editGeoJsonSource` and `editGeoJsonUrl` work, `setGeoJsonSource` keeps GeometryCollections, null geometries and feature ids, and `updateImageSource` moves the corners at once.
  * **Android**: query filters keep their numbers exact, and camera values keep double precision.
* More fixes from the reviews of the Pigeon migration (#1123):
  * No crash on NaN or infinite coordinates and camera values, which throw `INVALID_ARGUMENT` (iOS), nor on `addSource` with malformed bounds, zoom levels or urls (iOS, and Android for bounds).
  * `takeSnapshot` answers `SNAPSHOT_ERROR` when a newer call cancels it and `MAP_DISPOSED` when the map goes away, instead of never completing.
  * **iOS**: camera calls made before the map has a size, now including `setCameraBounds`, `updateContentInsets` and the `cameraTargetBounds`, `minMaxZoomPreference` and `myLocationTrackingMode` options, wait for the first layout, and answer `MAP_DISPOSED` if the map goes away first. The other options apply at once.
  * **Web**: `editGeoJsonUrl` works in JavaScript builds; it threw a `TypeError` outside wasm.
  * GeoJSON holding objects with `toJson()` goes in again on Android and iOS, and now on web.
  * Writes to the same GeoJSON source keep their order. On Android and iOS a later call on that source or its layers waits for them, so an `addCircleLayer` made without `await` right after a large `addGeoJsonSource` or `addSource` no longer fails with `SOURCE_NOT_FOUND`.
  * **Android, iOS**: GeoJSON with a NaN or infinite number, properties included, throws `INVALID_GEOJSON`, since JSON cannot hold it, instead of a `JsonUnsupportedObjectError` or, for `addSource` on iOS, a crash. Web takes such a number.
  * A GeoJSON, image or raster-dem source url with a space or another character a url cannot hold, such as an iOS file path under `Library/Application Support`, loads on every platform: it is percent-encoded, as browsers and iOS 17 do. `editGeoJsonUrl` encodes its url the same way and answers `false` for an empty one.
  * Tile source `bounds` with west greater than east, which cross the antimeridian, take every longitude, so the tiles on both sides load. Android crashed, iOS loaded only the tiles away from the antimeridian, and web none.
  * `removeSource` keeps a source that a layer still uses, and a source added again with the same id no longer brings back old data in `setGeoJsonFeature`.
  * **Android**: pausing an offline region right after resuming it keeps it paused.
  * `setLayerProperties` converts each value once on Android and iOS instead of twice.
* Feature ids come back from the queries and the cluster calls as they are in the data on every platform, and `["id"]` filters and feature state find them by that id. On web `"2"` and `2.5` no longer turn into `2`, and string ids such as `"poi-12"` are no longer lost. A source added with `generateId` numbers its features on Android and iOS too. The drag and hover callbacks no longer throw a `TypeError` on a numeric id on iOS and web (#1124).
* **iOS**: `getLayerProperties()` and `getSourceProperties()` read layers and sources added at runtime instead of answering `null`, and a layer reads its current values instead of the ones the style loaded with. As on Android, colors read as `rgba(...)` text. On Android and iOS, a filter from `getLayerProperties()` or `getLayerFilter()` reads as the app or the style wrote it, where a legacy one came back with internal operators such as `filter-==` (#985, #1127).
* `onCameraMove` and moves without animation work the same on every platform (#1126):
  * **iOS**: `onCameraMove` fires for `moveCamera` and a zero duration `animateCamera`, which only reached `onCameraIdle`, and its last call before `onCameraIdle` has the position where the camera stopped instead of the frame before.
  * **Android**: `animateCamera` with a zero duration moves the camera at once, as on iOS and web, instead of failing with a generic error.
* **Android**: `takeSnapshot` shows the area the map shows, at the screen's pixel density, as on iOS and web. Without a size it covered an area about 3x larger than the map, and with a size the image came out at 1x (#1128).
* **iOS**: more fixes from the review of the Pigeon migration (#1142):
  * `downloadOfflineRegion` fails with `DATABASE_RESET` when `resetOfflineDatabase` runs before the region is created, instead of never completing.
  * `updateContentInsets` completes, and `setTrackingCameraOptions` completes with `false`, when the map goes away before the camera arrives, as on Android, instead of never completing.
  * A region whose stored metadata cannot be read is listed with empty metadata, as on Android, instead of left out, and `getListOfRegions` lists regions imported without plugin metadata, as `mergeOfflineRegions` does.
  * Offline download progress events come at most every 100 ms, as on Android, so a region served from the cache no longer floods the app with events.
  * After a hot restart, a map from before the restart no longer sends its events to the new map that took its view id.
* **Android**: fixes from the review of the switch to Pigeon (#1143):
  * `setHttpHeaders`, the controller's `setCustomHeaders` and `setOfflineMaxConcurrentRequests` apply together instead of undoing each other, so a header no longer disappears after `setOfflineMaxConcurrentRequests`. Setting headers keeps MapLibre's limit of 20 requests per host instead of lowering it to 5.
  * Changing the headers while tiles load can no longer crash the app, and a `setCustomHeaders` filter that is not a valid pattern matches no URL, as on iOS, instead of crashing on the next request.
  * Offline region metadata that is not a JSON object, for example from a database merged with `mergeOfflineRegions`, reads as an empty map, as on iOS, instead of crashing `getListOfRegions`, `mergeOfflineRegions` and `updateOfflineRegionMetadata`. A failure inside an offline call fails that call instead of crashing the app.
  * `setOfflineMaxConcurrentRequests` and `setMaximumFps` reject a value too large for a 32-bit int with `INVALID_ARGUMENT`.
  * In add-to-app, the offline downloads of a destroyed Flutter engine no longer send events to it.
* **iOS**: `CameraPosition.zoom` in `onCameraMove`, `onCameraIdle` and `cameraPosition` no longer drifts by floating point noise while the map pans. It is bit-identical between events, as on Android and web (#1155).
* **iOS, Web**: `animateCamera`, `easeCamera` or `moveCamera` during a fling or a running animation fires `onCameraIdle` once, when the camera settles, as on Android. It also fired where the earlier motion stopped, followed by a second `onCameraMoveStarted` (#1156, #1158).

### Docs
* A guide on [loading a local MBTiles file](https://maplibre.org/flutter-maplibre-gl/advanced/mbtiles/) on Android and iOS (#1031).

## [0.27.1](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.27.0...v0.27.1)

### Fixed
* **Android**: apps built with Flutter 3.44 or later no longer fail with `Could not find method kotlin()`. Those apps carry `android.builtInKotlin=false`, and the plugin took AGP 9 to mean AGP compiles Kotlin itself, so nothing did. The plugin now applies the Kotlin Gradle Plugin whenever AGP has not taken Kotlin over, and the `android.builtInKotlin=true` workaround can be removed (#1008).
* **iOS**: fixed random `EXC_BAD_ACCESS` crashes with a map on screen, introduced in 0.26.2 alongside custom headers. Every request got its own `URLSession`, and a tile cancelled at the moment it completed was released twice from two threads. Intercepted requests now share one session with a synchronized teardown, and apps that never set custom headers skip the interception altogether (#1009).
* **iOS**: a redirected tile, style or sprite is fetched once instead of twice, and `setOfflineMaxConcurrentRequests` now also limits requests that carry custom headers (#1009).
* **iOS**: `getListOfRegions`, `mergeOfflineRegions` and `downloadOfflineRegion` no longer throw `type 'int' is not a subtype of type 'double'` for a region whose bounds sit on whole degrees. iOS returns regions as JSON, where `60.0` is written `60`, so only regions with a fraction in every coordinate could be read (#241).
* **Android, Web**: `setCustomHeaders` logs header names instead of header values. An API key or `Authorization` header sent to a tile provider was written to Logcat and the browser console in plain text, in release builds too (#1015).

### Docs
* A guide on [local sprites and glyphs](https://maplibre.org/flutter-maplibre-gl/concepts/styles/#local-sprites-and-glyphs). A style loaded from Flutter assets cannot point `sprite` and `glyphs` at `asset://`, because the native engines fetch those themselves; copy the files to disk at startup and reference them with `file://` (#338).
* `setStyle` accepts a raw JSON string on all three platforms. The API docs said Android only (#1026).
* The [minimum versions](https://maplibre.org/flutter-maplibre-gl/getting-started/#minimum-versions) table names the JDK requirement: the Android build targets Java 21, so JDK 17 fails with `invalid source release: 21` (#1018).

## [0.27.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.26.2...v0.27.0)

The plugin has a **documentation site** now, at [**maplibre.org/flutter-maplibre-gl**](https://maplibre.org/flutter-maplibre-gl/): a guide for every part of the API, each with a live map you can pan and click.

This release regenerates the whole style property surface from the current MapLibre style spec, closes long-standing gaps between the three platforms, and cuts start-up time and the cost of large data updates. **Upgrading costs little**: the only compile-time change is `SourceProperties.copyWith` moving to named parameters, plus one small change for Android apps and one or two for web apps, all below.

### Actions needed
* **Android**: a map now survives its activity being destroyed and recreated, but your style content does not come back with it. Add sources, layers and images inside `onStyleLoadedCallback`, which fires again after every recreation, rather than in `onMapCreated` or `initState`. See the [migration guide](https://maplibre.org/flutter-maplibre-gl/migration/#android-style-content) (#805).
* **Web**: the plugin now loads MapLibre GL JS itself. Delete the `maplibre-gl.js` script tag and the `maplibre-gl.css` link tag from `web/index.html`: if they stay, your pinned copy silently overrides the version the plugin is tested against. See the [migration guide](https://maplibre.org/flutter-maplibre-gl/migration/#web-remove-the-script-and-stylesheet-tags) (#928).
* **Web**: MapLibre GL JS 6 requires WebGL2 and no longer falls back to WebGL1, so a browser without it (Safari and iOS before 15) shows no map. Point `MapLibreMap.webLibrarySource` at a version 5 build to keep those browsers working. Version 6 also slices vector tiles instead of overscaling them, so `queryRenderedFeatures` can return a different set of features. See the [migration guide](https://maplibre.org/flutter-maplibre-gl/migration/#web-the-engine-moves-to-maplibre-gl-js-6) (#943).
* `SourceProperties.copyWith` takes named parameters instead of a dozen required positional ones, so `props.copyWith(cluster: true)` works and future spec additions stop breaking every caller. Calls that passed values positionally need the parameter names added (#957).
* `Expressions.xor` never meant xor: `^` is the style spec's exponentiation operator, so the expression raised the first input to the power of the second. It is now `Expressions.power`, and `Expressions.modulo` replaces the misspelled `Expressions.precent`. The old names still work as deprecated aliases, so nothing stops compiling, but any style built with `xor` was doing something else (#957).
* **Android, iOS**: the two offline download errors that carried a vendor name are renamed, `mapboxTileCountLimitExceeded` to `tileCountLimitExceeded` and `mapboxInvalidRegionDefinition` to `invalidRegionDefinition`. When they fire does not change, but a `catch` matching either old `PlatformException` code needs the new one (#956).

### Added
* **Android, iOS, Web**: `addColorReliefLayer()` colours the terrain by elevation from a raster DEM source, the hypsometric tint of a physical map. The colour ramp is a `colorReliefColor` expression over `Expressions.elevation`, and `colorReliefOpacity` sets how strongly it covers what is below. See the [color relief guide](https://maplibre.org/flutter-maplibre-gl/layers/color-relief/) (#958).
* **Android, iOS, Web**: `addBackgroundLayer()` paints the whole map with `backgroundColor` or tiles it with `backgroundPattern`, the one layer type with no source. Pass `belowLayerId` to place it under the layers it backs. Most published styles already carry a layer called `background`, so reusing that id fails with `layerAlreadyExists`. Changing its properties after adding it can stop it drawing while the style's own background layer is still there ([maplibre-native#4502](https://github.com/maplibre/maplibre-native/issues/4502)). See the [background layer guide](https://maplibre.org/flutter-maplibre-gl/layers/background/) (#959).
* **Web**: `setProjection()` switches between the `mercator`, `globe` and `vertical-perspective` projections, or interpolates between them by zoom. `setTerrain()` raises the map by the elevation of a raster DEM source, with `null` to flatten it again, and `setSky()` draws the sky and the atmosphere above the horizon. All three throw an `UnsupportedError` on Android and iOS, where MapLibre Native implements none of them yet. See the [globe, terrain and sky guide](https://maplibre.org/flutter-maplibre-gl/advanced/globe-terrain-sky/) (#960).
* **Android, iOS, Web**: the style property surface is regenerated from the current MapLibre style spec instead of a four-year-old copy. New layer properties: `textVariableAnchorOffset` on symbols, `hillshadeMethod` and `hillshadeIlluminationAltitude` for multidirectional hillshading. New expressions: `Expressions.distance`, `within`, `indexOf`, `slice` and `elevation` (#957).
* `MapLibreMap.preWarm()` starts the map engine during app start-up, for apps whose first screen is a map. Saves roughly 170 to 480 ms on Android, 45 to 165 ms on iOS and 10 to 50 ms on web (#867).
* **Android**: feature state (`setFeatureState`, `getFeatureState`, `removeFeatureState`) works on Android as well as web, so single features can be restyled without re-feeding the source. iOS throws; its SDK does not expose the API yet. `promoteId` stays web-only, so Android features need a top-level `id` in the GeoJSON. See the [feature state guide](https://maplibre.org/flutter-maplibre-gl/advanced/feature-state/) (#889).
* **Android, iOS**: offline regions can move between devices. `exportOfflineDatabase()` writes a shareable copy, `mergeOfflineRegions()` imports one (now on iOS too), and `getOfflineDatabasePath()` locates the store. See the [offline regions guide](https://maplibre.org/flutter-maplibre-gl/advanced/offline-regions/) (#886).
* **Android, iOS, Web**: the location puck can be driven from your own position updates instead of the device GPS, with no location permission needed: `locationSource: ManualLocationSource()` plus `controller.updateManualLocation()`. See the [user location guide](https://maplibre.org/flutter-maplibre-gl/advanced/user-location/) (#840).
* **Android, iOS, Web**: `getClusterExpansionZoom()` gives the zoom at which a cluster splits, so a cluster tap can zoom to exactly that instead of guessing with `zoom + 2`. `getClusterLeaves()` and `getClusterChildren()` read the points behind a cluster. All three take the cluster feature's `cluster_id`. See the [cluster guide](https://maplibre.org/flutter-maplibre-gl/layers/cluster/) (#896).
* `getLayerProperties()` and `getSourceProperties()` read a layer's or source's properties by id, in the same shape on every platform, or `null` if the id is unknown. On iOS only what came with the style is readable, so a layer or source you added at runtime answers `null` there while Android and web answer normally (#513, #985).
* **Android, iOS, Web**: `setLight()` sets the style's light source, which shades extruded geometries: `anchor`, `position`, `color` and `intensity`. Android and iOS take constant values, web also accepts expressions; Android answers `INVALID_ARGUMENT` for a value it cannot take. See the [globe, terrain and sky guide](https://maplibre.org/flutter-maplibre-gl/advanced/globe-terrain-sky/) (#960).
* `setPadding()` keeps map content centred while a bottom sheet or side panel covers part of the map, instead of passing padding to every camera call (#258).
* `pauseMap()` and `resumeMap()` stop and restart rendering for a map that is alive but off screen, such as one on an inactive tab. No-op on web (#805).
* **Android, iOS**: `setTrackingCameraOptions()` pitches the camera without giving up the active tracking mode, for a navigation-style view that stays tilted while it keeps following the user. On web it throws an `UnsupportedError`. See the [user location guide](https://maplibre.org/flutter-maplibre-gl/advanced/user-location/) (#888).
* **Web**: `setGlobalStateProperty()` sets a value in the style's global state, which the `Expressions.globalState` expression reads, so one switch restyles any number of layers at once. Android and iOS throw an `UnsupportedError`. See the [expressions guide](https://maplibre.org/flutter-maplibre-gl/advanced/expressions/) (#960).
* **Web**: `MapLibreMap.webLibrarySource` chooses where MapLibre GL JS comes from: the build the plugin is tested against, a self-hosted copy, or one the page loads itself. `MapLibreMap.ensureWebLibraryLoaded()` completes once MapLibre GL JS is loaded, for calling into it directly, for example `addProtocol` (#928).
* **Android, iOS, Web**: `fillExtrusionRoundedCornerDistance` rounds the corners of extruded shapes. Its generated dartdoc still reads `not on js`, because the pinned style spec records MapLibre GL JS support for it as an open issue; it shipped in GL JS 6.2.0 and works on web (#957).
* **Android, iOS, Web**: `clusterMinPoints` on a GeoJSON source sets how many points have to fall together before they become a cluster, instead of the fixed default of two (#957, #981).
* **Android, iOS**: `attributionButtonColor` tints the attribution button, for styles where the default tint is hard to see. No effect on web (#805).
* **iOS**: `LocationEnginePlatforms.iOS` takes `intervalMs` and `pulseWindowMs` to pulse GPS instead of tracking continuously, easing battery use on maps that stay open a long time. The default keeps continuous tracking (#901).
* **Android**: `volatile` on vector, raster and raster-dem sources keeps their tiles out of the on-disk cache, for tiles that change often or must not be stored. The iOS SDK exposes no equivalent and MapLibre GL JS will not implement one, so it has no effect there (#957, #981).
* **Web**: properties MapLibre GL JS supports but MapLibre Native does not implement yet are exposed too: `iconOverlap` and `textOverlap` on symbols, `fillLayerOpacity` and `lineLayerOpacity`, `resampling` on raster and hillshade layers, `filter` on GeoJSON sources, the `custom` raster-dem encoding with its factors, and the `Expressions.globalState`, `join` and `split` expressions. Android and iOS ignore them, except the custom encoding, which now throws, and `join` and `split`, which work on Android since 13.5.0 (#957, #981).

### Fixed
* **Android**: a map no longer stays blank for good after its activity is recreated, whether by "Don't keep activities", memory pressure or rotation; the camera position comes back with it (#805).
* **Android**: icons added with `addImage` are visible again, at the right size on high-density screens. Since 0.26.0 they could be dropped whenever draggable annotations were in use, which is the default. Undecodable bytes now report a clear error instead of crashing (#866, #868).
* **Android, iOS**: symbols added with `addSymbol` are visible again on styles whose glyph server does not host the old default font; a missing font used to hide the whole symbol, icon included. The default is now `Noto Sans Regular`; for another font use `addSymbolLayer` with `textFont` (#940).
* **Android, iOS**: losing the network no longer cancels an offline region download, nor deletes the region with it on iOS. The SDK retries those failures itself once the connection is back; only the tile count limit stops a download now (#986).
* **Android, iOS**: adding or updating a GeoJSON source with a large payload no longer blocks the UI for the whole encode. Large payloads are encoded in the background, cutting the blocking time by a factor of two to three (#366).
* **Android**: a hillshade layer takes its colours again. `hillshadeShadowColor` and its three companions became arrays in MapLibre Native 6.24 for multidirectional hillshading, so a single value was rejected with `Expected array<color> but found string instead` and the layer silently kept the default black and white. A single value is now wrapped for you on Android and iOS, and a list is passed through (#957).
* **Android, iOS, Web**: `queryRenderedFeaturesInRect()` applies the `filter` it is given; no platform decoded it, so the answer held every feature in the rectangle. Note that this call takes the filter as a JSON string, unlike `queryRenderedFeatures()` (#949, #953).
* A map that fails to be created now reports the failure. Code awaiting the controller, `onMapCreated` included, used to wait forever for a map that never arrived, with only an unhandled error in the console (#943).
* **Android, iOS**: downloading an area that is already downloaded replaces its region instead of adding a duplicate. iOS keeps the region id the app already knows; Android assigns a new one, so read it back from the returned `OfflineRegion` (#886).
* **Android, iOS**: `setLayerProperties()` works on fill-extrusion and heatmap layers too; both used to answer `UNSUPPORTED_LAYER_TYPE` (#960).
* **Android**: `maxzoom` on a GeoJSON source is applied again. The converter read a camel-cased key the Dart side never sends, so the value was dropped on Android while iOS and web honoured it (#981).
* **Android**: `queryRenderedFeatures()` and `querySourceFeatures()` say what is wrong with a call they cannot answer: `STYLE_NOT_READY` before the style has loaded, `INVALID_ARGUMENT` for a missing `sourceId`, `layerIds` or query geometry. The failure used to arrive as a bare `error` carrying a `NullPointerException` message (#954).
* **Android**: merging an offline database whose regions carry no metadata, such as one produced by maplibre-native, no longer fails with `type 'Null' is not a subtype of type 'Map<String, dynamic>'` (#865).
* **iOS**: `queryRenderedFeatures()` and `querySourceFeatures()` no longer skip a feature that failed to serialize without telling you, and no longer hang on a call they cannot answer, such as one made before the style has loaded (#949).
* **iOS**: `queryCameraPosition()` returns the camera position even when `trackCameraPosition` is `false`, matching Android. It used to return `null` (#892).
* **iOS**: `controller.cameraPosition` no longer sticks on a `NaN` zoom from a camera event that arrived before the first layout, which misplaced camera-anchored content on maps the user had not touched (#903).
* **Web**: `onMapIdle` now fires, matching Android and iOS; code waiting on it never ran (#857).
* **Web**: `getFeatureState()` returns the state instead of throwing, and reports no state as null rather than an empty map. `removeFeatureState(sourceId)` with no feature id now resets the whole source instead of doing nothing. A `stateKey` with no `featureId` is rejected. Both match Android (#889).
* **Web**: `querySourceFeatures()` now reports an error when it is called before the style has loaded, matching Android and iOS. It answered with an empty list, which the caller cannot tell apart from a source holding no features (#952).
* **Web**: `queryCameraPosition()` is implemented; it used to throw `UnimplementedError` (#892).
* **Web**: `updateContentInsets` and the new `setPadding` no longer throw `UnimplementedError` (#258).
* The bundled LICENSE no longer breaks Flutter's license collector, which showed an untitled, truncated first entry on every dependent app's `showLicensePage()` (#895).

### Changed
* **Web**: MapLibre GL JS upgraded from 5 to 6.4.1; see Actions needed above. Over 6.2 this fixes a permanent frame-rate drop after a style switch, a rejected missing-image resolver taking the rest of its batch down with it, globe zoom drifting away from the pointer, globe panning stalling at the poles, and an attribute-sanitising hole in popup and marker HTML (#943).
* **Android**: MapLibre Native upgraded from 13.3.0 to 13.5.0 ([13.4.0](https://github.com/maplibre/maplibre-native/releases/tag/android-v13.4.0), [13.4.1](https://github.com/maplibre/maplibre-native/releases/tag/android-v13.4.1), [13.5.0](https://github.com/maplibre/maplibre-native/releases/tag/android-v13.5.0)), plus OkHttp 5.4.0, Play Services Location 21.4.0 and androidx.core-ktx 1.18.0. 13.5.0 repaints symbol paint properties driven by feature state, fixes a surface-changed ANR and works around a device-lost crash on Adreno GPUs (#877, #919, #929).
* **iOS**: MapLibre Native upgraded from 6.27.0 to 6.28.0 ([release notes](https://github.com/maplibre/maplibre-native/releases/tag/ios-v6.28.0)): the map view is no longer blurry in landscape on iPad (#929).
* **iOS**: the plugin supports Flutter's Swift Package Manager integration. The CocoaPods podspec still ships, so CocoaPods apps need no migration (#891).
* **Android, iOS**: a raster-dem source with `encoding: "custom"` now throws an `UnsupportedError` from `addSource()`. MapLibre Native decodes only the `mapbox` and `terrarium` formulas and used to read custom tiles as mapbox-encoded, drawing a plausible map from wrong elevations. Only `addSource()` is checked: the same encoding declared inside `MapLibreMap.styleString` is still decoded as mapbox without an error. Custom encoding keeps working on web (#981).
* **Android, iOS**: panning a pitched map no longer moves the camera past the horizon, and changing a layer's `source-layer` or `source-id` now takes effect (#929).
* The style spec the code is generated from is now a verbatim copy of a pinned upstream release (`@maplibre/maplibre-gl-style-spec`, currently 26.2.1). A weekly workflow reports what a newer release would bring to each platform and opens the update PR, and properties the native SDKs do not implement yet are generated for web only, so upgrading the SDKs unlocks them automatically (#957).
* Every generated layer property, source option and expression now documents which platforms implement it, from the spec's own `sdk-support` metadata: `iconOverlap` reads `basic functionality with js (not on android, ios)` instead of claiming all three. Where the spec credits a platform whose SDK exposes no such API, the docs say so rather than repeat the spec (#957, #981).
* The error from `addSymbol`, `addCircle`, `addLine` and `addFill` when the annotation manager is missing now names the type and both causes: the style has not finished loading, or that type is not in the widget's `annotationOrder` (#910).
* **Android**: the Kotlin Gradle Plugin is applied only below AGP 9, so builds on AGP 9 or later no longer break. Nothing changes on AGP 8 (#905).
* **Android**: the unused `android-plugin-annotation-v9` and `android-plugin-offline-v9` dependencies are dropped, so apps pull two fewer artifacts (#929).
* **Android**: the plugin builds against NDK 28.2.13676358, matching Flutter's default (#956).

### Docs
* New guides for [user location](https://maplibre.org/flutter-maplibre-gl/advanced/user-location/), [startup and performance](https://maplibre.org/flutter-maplibre-gl/advanced/performance/) and [feature state](https://maplibre.org/flutter-maplibre-gl/advanced/feature-state/) (#840, #867, #889).
* **Annotations**: the two conditions every annotation depends on, and the constraints of both APIs, are now stated in one place (#910).
* **Android**: `MapLibreMap.useHybridComposition` was documented with the wrong default; it has been `false` since 0.16.0. Its docs and the [performance page](https://maplibre.org/flutter-maplibre-gl/advanced/performance/#platform-view-mode-android) now say what each value selects (#816).
* **Example app**: new Manual Location Source and Feature State pages, and the Offline Regions demo now walks through the export and import round-trip (#840, #886, #889).
* **Example app**: the Data-Driven Expressions demo drew the USA as a triangle across the Atlantic, because one coordinate was missing its minus sign. Its polygon is now a bounding box over the contiguous states (#956).

## [0.26.2](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.26.1...v0.26.2)

> **Note:** This release enforces a minimum Flutter version of **3.29**, which was already required in practice since 0.26.0 but not reflected in the package constraints (#823).

### Added
* A live web demo of the example app is now available at [maplibre.org/flutter-maplibre-gl](https://maplibre.org/flutter-maplibre-gl/).

### Fixed
* Setting map options inside a widget that rebuilds frequently (e.g. with `setState`) no longer causes unnecessary map updates. Options containing nested lists such as `cameraTargetBounds` were always treated as changed, even when the value was identical (#849).
* **Android, iOS**: `doubleClickZoomEnabled: false` now works correctly. Previously this option was only respected on web, so single taps on Android and iOS always had a ~300 ms delay while the platform waited to rule out a double-tap (#829).
* **iOS**: `setCustomHeaders` and `setHttpHeaders` now correctly apply to all map network requests (tiles, styles, sprites, glyphs). Both APIs were previously silently ignored on iOS (#831).
* **iOS**: `setMapLanguage` now correctly changes map labels on non-Mapbox styles (e.g. OpenFreeMap Liberty). Previously, calling `setMapLanguage` on iOS had no effect and place names were displayed using the style's default language (#830). A new **Map Language** example in the example app demonstrates this across several languages.
* **iOS**: Layer color properties now accept any valid CSS color string (`rgb()`, `rgba()`, `hsl()`, `hsla()`, named colors). Previously only hex colors were supported and anything else rendered as transparent (#832).
* **iOS**: Fixed a crash that could occur when the app was sent to the background while using PMTiles sources (#833).
* **iOS**: Fixed a crash on cold launch when the map was first displayed at zero size (e.g. inside a hidden widget or during app startup) (#841).
* **iOS**: Fixed a memory leak where map resources were not fully released when the map widget was disposed (#837).
* **Android**: Fixed a crash when style API methods were called while the map style was still loading.

### Changed
* **Android**: MapLibre Android SDK upgraded from 13.1.0 to 13.3.0.
* **iOS**: MapLibre iOS upgraded from 6.26.0 to 6.27.0.

## [0.26.1](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.26.0...v0.26.1)

> **Note:** Several users reported crashes on a range of Android devices after upgrading to 0.26.0, particularly on older / less recent hardware. These issues are addressed in 0.26.1 (see the Android fixes below).

### Fixed
* **Android**: Hybrid composition now correctly enables `textureMode` when necessary, preventing crashes and rendering and issues with platform views (#816).
* **Android**: Null-check `mapView` inside the `onResume` repaint runnable to avoid `NullPointerException` when the map is disposed (e.g. dialogs/bottom sheets) before the posted runnable drains (#809).
* De-register the annotation drag callback on `AnnotationManager.dispose()` to prevent jumpy drags and `_idToAnnotation.containsKey` crashes after style reloads on Android and iOS (#806).

### Changed
* **Android**: MapLibre Android SDK upgraded from 13.0.2 to 13.1.0 (#811).
* **iOS**: MapLibre iOS upgraded from 6.25.1 to 6.26.0.

### Docs
* **Web**: Updated `maplibre-gl` JavaScript and CSS version to `5.24.0` in `README.md` to avoid `NoSuchMethodError` on `MapLibreMap` dispose with the previously referenced 4.3.0 version (#814).

## [0.26.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.25.0...v0.26.0)

**Version 0.26.0 is a milestone release for flutter-maplibre-gl.** \
This release addresses numerous long-standing bugs that have accumulated over the years and completes the transition to the **WASM compilation** for the web platform, ensuring full compatibility with Flutter's modern web toolchain.

### Breaking
* `initialCameraPosition` is now nullable to support style-defined camera options (#769).
* Removed `LocationEngineAndroidProperties`. All fields flattened into `LocationEnginePlatforms` with nullable platform-specific fields.\
Use Platform-specific constructors: `LocationEnginePlatforms.android()`, `.iOS()`, `.web()` instead.
* Removed deprecated typedefs: `MaplibreMapController`, `MaplibreMap`, `MaplibreStyles`. Use `MapLibreMapController`, `MapLibreMap`, `MapLibreStyles` instead.
* Removed deprecated callback: `onInfoWindowTapped` from `MapLibreMapController`.
* Removed deprecated methods: `removeImageSource` (use `removeSource`) and `addLayerBelow` (use `addImageLayerBelow`).

### Added
* Cross-platform map snapshot functionality via `takeSnapshot()` (#726).
* `featureTapsTriggersMapClick` option to control whether feature taps also trigger map click callbacks, defaults to `false` (#729).
* Fire `onMapClick` for all map taps, including after interactive features (#707).
* Unit tests for core packages (#765).
* **Offline Regions**: richer control and observability over downloads on Android and iOS (#795).
  * `pauseOfflineRegionDownload` / `resumeOfflineRegionDownload` to control in-progress downloads.
  * `getOfflineRegionStatus` returning `OfflineRegionStatus` with resource counts, bytes, progress and completion.
  * `InProgress` events now carry `completedResourceCount`, `requiredResourceCount`, and `completedResourceSize` for tile/byte progress in addition to the percentage.
  * `clearAmbientCache` and `resetOfflineDatabase` globals to evict unpinned tiles or fully reset the offline DB (in-flight downloads are terminated Dart-side before reset/deletion).
  * `setOfflineMaxConcurrentRequests` to cap tile concurrency (total on Android, per-host on both) and avoid upstream rate limiting.
* **clusterProperties**: Introduced native implementation of `clusterProperties` for clustered GeoJSON sources. Both the simple operator-string form (e.g. `{'sum': ['+', ['get', 'x']]}`) and the explicit reduce-expression form are now applied natively; previously the property was serialized from Dart but ignored by both native converters (#792).
* **easeCamera interpolation**: `easeCamera` accepts an optional `CameraAnimationInterpolation` to control the animation easing curve (`linear`, `easeInOut`, `easeOut`, `fastOutLinearIn`). Use `CameraAnimationInterpolation.linear` for smooth continuous tracking (e.g. following a moving GPS target) without velocity discontinuities between successive calls. Omitting the parameter preserves the previous default behavior (#789).
  * **iOS**: all four curves are supported exactly; `fastOutLinearIn` is implemented via `CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)` (Material Design cubic Bezier).
  * **Android**: MapLibre Android only exposes a boolean easing flag on `easeCamera`, so only `linear` is distinct — `easeInOut`, `easeOut`, and `fastOutLinearIn` all map to the native ease-in/ease-out. See `CameraAnimationInterpolation` dartdoc for per-value details.
  * **Web**: `easeCamera` is now fully implemented via MapLibre GL JS `map.easeTo({easing})`. Each interpolation value maps to a cubic-bezier callback (`easeInOut` → `(0.42, 0, 0.58, 1)`, `easeOut` → `(0, 0, 0.58, 1)`, `fastOutLinearIn` → `(0.4, 0, 1, 1)`). Previously threw `UnimplementedError`.
* **iOS**: Implemented `setMaximumFps` to control the preferred frame rate (#739).
* **Android**: Google Mobile Services (GMS) Location Engine support (#721).
* **Web**: Exposed `onMouseMove` and added feature state management (`setFeatureState`, `getFeatureState`, `removeFeatureState`) (#718).
* **Web**: Added `getLayerVisibility`, web snapshot, and map sizing features (#722).
* **Web**: Added Scale Control (#720).
* **iOS**: Location engine support — `enableHighAccuracy` and `displacement` configurable via `LocationEnginePlatforms.iOS()`.
* **Web**: Location engine properties (`enableHighAccuracy`, `maximumAge`, `timeout`) via `LocationEnginePlatforms.web()`.
* Platform-specific constructors for `LocationEnginePlatforms`: `.android()`, `.iOS()`, `.web()`.

### Changed
* **Android**: Reduced MapLibre SDK logging verbosity to minimize log spam (#752).
* **Android**: Enhanced GeoJSON source handling with type checks and error logging (#764).
* **Android**: Check style exists and is loaded before adding a Layer (#768).
* **Android**: Check source exists before adding (#734).
* **Android**: MapLibre Android SDK upgraded from 13.0.0 to 13.0.2, switched to OpenGL renderer variant (`android-sdk-opengl`) for better stability and performance on older devices.
* **iOS**: Updated project settings for UISceneDelegate compatibility (#767).
* **iOS**: MapLibre iOS SDK upgraded from 6.19.1 to 6.25.1.
* **Web**: Upgraded MapLibre GL JS from 4.7.1 to [5.24.0](https://github.com/maplibre/maplibre-gl-js/releases/tag/v5.21.0) (#761, #651).
* **Web**: Migrated `preserveDrawingBuffer`, `antialias`, and `failIfMajorPerformanceCaveat` from top-level `MapOptions` to `canvasContextAttributes`.
* **Web**: Updated `on()`/`off()`/`once()` event methods to handle v5's `Subscription` return type instead of map instance.
* **Web**: Removed obsolete `customAttribution` from `MapOptions` (now part of `AttributionControl` options in v5).
* **GitHub Actions**: `actions/upload-artifact` updated from v6 to v7 (#748).
* Bumped Dart and melos version to latest (#762).
* Minimum Dart SDK version bumped from `3.5.0` to `3.7.0` (#762).
* Gradle wrapper updated to 9.4.0, Kotlin to 2.3.10, Android Gradle Plugin to 9.1.0 (#753-#758).

### Fixed
* Fix data properties not being added to Annotation created in AnnotationManager (#770).
* Fix double JSON encoding in layer properties causing Android/iOS type errors (#747).
* **iOS**: `icon-text-fit-padding` insets now use the correct style-spec order `[top, right, bottom, left]` — `left` and `right` were previously swapped (#792).
* Fix `text-font` property handling on Android and iOS to correctly accept font stacks as string arrays instead of only expressions.
* Fix `textFont` in `SymbolManager` to pass font names as a simple string array, resolving rendering issues on native platforms.
* Add DEM encoding support (`terrarium`/`mapbox`) for raster-dem tile sources on Android and iOS.
* Fix heatmap color expressions in example app to use proper `Expressions.rgba`/`Expressions.rgb` syntax.
* **Android**: Fix map partially not responsive in split screen (#771).
* **Android**: GeoJSON source updates are now synchronous when drag is enabled, preventing stale feature positions during drag interactions and improved performance (#716).
* **Android**: Disabled texture mode by default and improved MapView lifecycle management (#723).
* **Android**: Removed unnecessary `OfflineActivity` from `AndroidManifest.xml` (#724).
* **Offline Regions**: retain download `StreamSubscription`s in a module-level map so Dart's GC can't drop native events while a download is paused (#795).
* **Android (Offline)**: throttle progress events to 100ms and discard non-monotonic counts so cache-served bursts don't starve the isolate and block pause taps; track in-flight downloads to support pause/resume/status (#795).
* **iOS (Offline)**: track active `MLNOfflinePack` instances so pause/resume/status operate on the live pack rather than reloading from storage (#795).
* **iOS**: Deferred `onStyleLoaded` callback to avoid race conditions (#719).
* **Web**: Improved `styleimagemissing` handling (#725).
* **Web**: Fixed JS Interop and WASM compilation in release mode (#714).
* **Web**: Fixed missing prototype on empty JS object created via interop.
* **Web**: `removeLayer` and `removeSource` no longer throw when the layer/source doesn't exist.
* **Web**: `setGeoJsonSource` returns early instead of crashing when the source doesn't exist.
* **Web**: `GeolocateControl` now respects `MyLocationTrackingMode` and triggers programmatically.
* **Example**: GPS location page. Fixed web permission check, wired `onUserLocationUpdated`, web-specific tracking modes.
* **Example**: GeoJSON cluster. Added `['has', 'point_count']` filter to fix null property errors on unclustered points.

**Full Changelog**: [v0.25.0...v0.26.0](https://github.com/maplibre/flutter-maplibre-gl/compare/v0.25.0...v0.26.0)

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
