# Getting Started

Add `maplibre_gl` to a Flutter app and get a map on screen. Android and iOS need
one platform file each; web needs nothing to start. Later sections cover the web
setups that need more: a Content-Security-Policy, a self-hosted copy of the
library, or your own JS interop.

## Add the dependency

=== "Run command"

    Add `maplibre_gl` to your project by running this command:

    ```sh
    flutter pub add maplibre_gl
    ```

=== "Edit pubspec.yaml"

    Alternatively, add it directly as a dependency in your `pubspec.yaml` file:

    ```yaml title="pubspec.yaml"
    dependencies:
      maplibre_gl: ^0.27.0
    ```

    Then run `flutter pub get` to install the package.

??? info "Using the development version"

    To get the latest features and fixes before they are published, depend on
    the package directly from GitHub.

    !!! warning

        The development version is not considered stable and shouldn't be used
        in production.

    Use it as a normal dependency, or temporarily override it under
    `dependency_overrides:`:

    ```yaml title="pubspec.yaml"
    dependencies:
      maplibre_gl:
        git:
          url: https://github.com/maplibre/flutter-maplibre-gl
          ref: main # or a specific commit hash
    ```

## Android

If you want to show the user's location on the map, add location permissions to the application manifest:

```xml title="android/app/src/main/AndroidManifest.xml" hl_lines="3 5"
<manifest>
  <!-- Always include this permission -->
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <!-- Include only if your app benefits from precise location access -->
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
</manifest>
```

## iOS

Add a location usage description to your `Info.plist`:

```xml title="ios/Runner/Info.plist"
<key>NSLocationWhenInUseUsageDescription</key>
<string>Show your location on the map</string>
```

The plugin ships both a Swift package and a CocoaPods podspec, so it works with Flutter's [Swift Package Manager integration](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers) and with CocoaPods. Nothing to configure either way: apps already on CocoaPods need no migration, and apps with SPM enabled need no `Podfile` on account of this plugin.

## Web

On web, the plugin renders with [MapLibre GL JS](https://maplibre.org/maplibre-gl-js/docs/), and it loads that library itself: nothing needs to be added to `web/index.html`. The plugin imports the exact build it is tested against, stylesheet included, before the first map is built.

!!! warning "Upgrading from an older version"
    If your `index.html` still has the `maplibre-gl.js` script and `maplibre-gl.css` link tags from an earlier setup, remove them. An existing `maplibregl` global is reused as it is, so a manually pinned copy silently overrides the version the plugin is tested against.

## Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(51.5, -0.09),
          zoom: 11,
        ),
        styleString: MapLibreStyles.demo,
      ),
    );
  }
}
```

!!! tip "Style URL"
    Pass any MapLibre-compatible style URL to `styleString`. You can self-host styles
    with [MapTiler](https://www.maptiler.com/), [Protomaps](https://protomaps.com/),
    or your own tile server.

## Web: advanced setup

### Requirements

The browser has to provide **WebGL2**. MapLibre GL JS 6 draws with it and no longer falls back to WebGL1, so a browser without it shows no map at all. Two cases end differently:

* **The browser has no WebGL2 at all**, as on Safari and iOS before 15, and on Chrome and Firefox from before 2017. Flutter's own renderer asks for WebGL1 on such a browser, so the app around the map keeps working and only the map goes missing, which is what makes this easy to miss. The plugin logs the cause when this happens.
* **WebGL2 exists but no context can be created**, because the browser blocklists it for the GPU driver, or hardware acceleration is switched off. Flutter's renderer asks for WebGL2 there, and does not fall back either, so the whole app stays blank and the library version makes no difference.

Only the first case has a way out: MapLibre GL JS 5, the last major version with
the WebGL1 fallback. Point the plugin at a version 5 copy with
`MapLibreMap.webLibrarySource`, exactly as for
[self-hosting](#self-hosting-maplibre-gl-js). The plugin keeps working against
it, but you then stay off the version it is tested against.

### Content-Security-Policy

Skip this if your app has no CSP. If it does, three things need allowing: the
plugin imports the library, which a CSP governs like any other script; the style
and the tiles are fetched; and MapLibre GL JS runs its tile work in a Web Worker.
That worker is built from a `blob:` URL whenever the library is loaded
cross-origin, which is what a CDN is.

```
script-src 'self' https://unpkg.com ;
connect-src 'self' https://unpkg.com https://your.tile.host ;
worker-src 'self' blob: ;
img-src data: blob: 'self' ;
```

[Self-hosting](#self-hosting-maplibre-gl-js) the library makes the worker same-origin, so `blob:` is not needed in `worker-src` and the CDN host drops out of `script-src` and `connect-src`.

### Self-hosting MapLibre GL JS

If a Content-Security-Policy rules out the CDN, or you prefer serving the library yourself (for example as web assets), point the plugin at your copy before the first map is built:

```dart
void main() {
  MapLibreMap.webLibrarySource = const MapLibreJsSource.urls(
    scriptUrl: 'https://your.host/maplibre-gl.mjs',
    styleUrl: 'https://your.host/maplibre-gl.css',
  );
  runApp(const MyApp());
}
```

MapLibre GL JS 6 is an ES module, so `scriptUrl` points at the `.mjs` build. Serve the whole `dist` directory, not just that one file: the library resolves its worker relative to its own URL, so the worker build has to sit next to it. Check too that your server answers `.mjs` with a JavaScript MIME type, `text/javascript`: a module script is refused outright when the type is something else, such as the `application/octet-stream` some servers still default to.

If the page loads MapLibre GL JS itself, set `MapLibreMap.webLibrarySource = const MapLibreJsSource.preloaded()`: the plugin then imports nothing and waits for the `maplibregl` global. An ES module defines no global on its own, so the page has to publish one:

```html
<script type="module">
  globalThis.maplibregl = await import('/your/path/maplibre-gl.mjs');
</script>
```

### Calling MapLibre GL JS yourself

Because the library is loaded by the plugin, the `maplibregl` global no longer exists at page parse time. An app that calls into MapLibre GL JS with its own JS interop, for example to register a custom protocol with `addProtocol`, must await `MapLibreMap.ensureWebLibraryLoaded()` first:

```dart
Future<void> main() async {
  if (kIsWeb) {
    await MapLibreMap.ensureWebLibraryLoaded();
    // maplibregl is now usable from JS interop.
  }
  runApp(const MyApp());
}
```

On Android and iOS `MapLibreMap.ensureWebLibraryLoaded()` completes immediately, so it is safe to await unconditionally.

### PMTiles on web

To read [PMTiles](advanced/pmtiles.md) sources on web, load the `pmtiles` script in `index.html` and register the protocol from Dart. The registration used to be an inline script in `index.html`, but it needs the `maplibregl` global, which no longer exists at page parse time, so it moved into `main()` behind `MapLibreMap.ensureWebLibraryLoaded()`:

```html title="web/index.html" hl_lines="3"
<head>
    <!-- ...existing head tags... -->
    <script src="https://unpkg.com/pmtiles@4.4.0/dist/pmtiles.js"></script>
</head>
```

```dart title="lib/main.dart"
Future<void> main() async {
  if (kIsWeb) {
    await MapLibreMap.ensureWebLibraryLoaded();
    registerPmTilesProtocol('https://your.host/archive.pmtiles');
  }
  runApp(const MyApp());
}
```

`registerPmTilesProtocol` is a small piece of JS interop around `maplibregl.addProtocol` and the `pmtiles` global. See [`pmtiles_protocol_web.dart`](https://github.com/maplibre/flutter-maplibre-gl/blob/main/maplibre_gl_example/lib/pmtiles_protocol_web.dart) in the example app for a complete implementation, including the conditional import that keeps the app compiling for Android and iOS.

## Minimum versions

| Platform | Minimum version |
|----------|----------------|
| Flutter  | 3.29.0 |
| Dart     | 3.7.0 |
| Android  | API 21 (Android 5.0) |
| iOS      | iOS 13 |
| Web      | WebGL2, see [Requirements](#requirements) |
