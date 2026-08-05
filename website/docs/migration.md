# Migration Guide

## Upgrading to 0.27.0

No breaking API changes, so nothing stops compiling. Two platforms do need action: Android apps need one code change, described under [Android: style content](#android-style-content), and web apps should delete two tags from `web/index.html`, described under [Web: remove the script and stylesheet tags](#web-remove-the-script-and-stylesheet-tags).

Update your `pubspec.yaml`:

```yaml
dependencies:
  maplibre_gl: ^0.27.0
```

Then run `flutter pub upgrade maplibre_gl`. See the [CHANGELOG](https://github.com/maplibre/flutter-maplibre-gl/blob/main/CHANGELOG.md) for the full list of changes.

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

* **You have a Content-Security-Policy.** The library runs its tile work in a Web Worker, and loaded cross-origin from the CDN that worker comes from a `blob:` URL, so `worker-src` needs `blob:`. See [Content-Security-Policy](getting-started.md#content-security-policy). Without it the map stays blank.
* **You self-host the library.** Point `MapLibreJsSource.urls` at the `.mjs` build rather than `.js`, and serve the whole `dist` directory: the library resolves its worker relative to its own URL.
* **The page loads the library itself** (`MapLibreJsSource.preloaded`). An ES module defines no global, so the page has to publish `globalThis.maplibregl` explicitly.

`queryRenderedFeatures` can also return a different set of features. Version 6 slices vector tiles instead of overscaling them, which upstream turned on by default because it fixes label placement, and that changes both rendering and query results. The plugin follows that default; there is no per-app switch for it. If it costs you something concrete, please open an issue.

### Minimum SDK versions

Unchanged from 0.26.x.

| Platform | Minimum version |
|----------|----------------|
| Android  | API 21 (Android 5.0) |
| iOS      | iOS 12 |
| Flutter  | 3.29.0 |
| Dart     | 3.7.0 |

### Behaviour changes

None of these need a code change, but they are the places where code that worked before starts behaving differently.

* **Web**: `onMapIdle` now fires. If you worked around it never running on web, that workaround can go.
* **Web**: `queryCameraPosition()`, `updateContentInsets()` and the new `setPadding()` no longer throw `UnimplementedError`, so any guard you put around them for web is no longer needed.
* **Android, iOS**: symbol annotations now render their text in `Noto Sans Regular` instead of the old `Open Sans Regular,Arial Unicode MS Regular` default, which most glyph servers do not host. If your symbols were invisible, they appear now; if they were visible, the typeface changes. The font belongs to the annotation layer, so a different one means a symbol style layer with `textFont` set. See [Markers](annotations/markers.md).
* **Android**: [feature state](advanced/feature-state.md) works instead of throwing, so a `kIsWeb` guard around those calls can go. `promoteId` is still ignored outside web, so features must carry a top-level `id` in the GeoJSON for feature state to key off.
* **iOS**: `mergeOfflineRegions()` returns only the regions it imported, instead of every region already stored. If you used its return value as the full list, call `getListOfRegions()` for that.
* **Android, iOS**: downloading an area that is already downloaded replaces the existing region rather than adding a duplicate, and the replacement keeps the same region id.

### Android apps on AGP 9

The plugin no longer applies the Kotlin Gradle Plugin when your app builds with Android Gradle Plugin 9 or later, which is what broke that build before. Apps on AGP 8 are unaffected and need no change.

## Upgrading to 0.26.2

See the [CHANGELOG](https://github.com/maplibre/flutter-maplibre-gl/blob/main/CHANGELOG.md) for the full list of changes.

### Breaking changes

Check the CHANGELOG for any breaking changes introduced in 0.26.x. If you were on an earlier 0.26 release, the upgrade should be straightforward for most apps.

### Minimum SDK versions

| Platform | Minimum version |
|----------|----------------|
| Android  | API 21 (Android 5.0) |
| iOS      | iOS 12 |
| Flutter  | 3.29.0 |
| Dart     | 3.7.0 |

## Upgrading from earlier 0.26 releases

No structural changes to the public API. Run `flutter pub upgrade maplibre_gl` and check the CHANGELOG for any deprecation notices.
