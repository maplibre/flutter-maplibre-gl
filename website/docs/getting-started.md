# Installation & Setup

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
      maplibre_gl: ^0.26.2
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

## Web

On web, the plugin renders with [MapLibre GL JS](https://maplibre.org/maplibre-gl-js/docs/). Add its script and stylesheet to the `<head>` of `web/index.html`, before the Flutter bootstrap script:

```html title="web/index.html" hl_lines="5 6"
<!DOCTYPE html>
<html>
  <head>
    <!-- ...existing head tags (base href, meta, icons)... -->
    <script src='https://unpkg.com/maplibre-gl@^5.24.0/dist/maplibre-gl.js'></script>
    <link href='https://unpkg.com/maplibre-gl@^5.24.0/dist/maplibre-gl.css' rel='stylesheet'/>

    <title>My App</title>
  </head>
  <body>
    <script src="flutter_bootstrap.js" async></script>
  </body>
</html>
```

`^5.24.0` pins to a recent MapLibre GL JS v5 without jumping to a future breaking version.

### PMTiles on web

To read [PMTiles](advanced/pmtiles.md) sources on web, also load the `pmtiles` script and register the protocol. The registration must run **synchronously, after the `pmtiles` script and before `flutter_bootstrap.js`**, so the protocol exists by the time the map initializes:

```html title="web/index.html" hl_lines="3 6 7 8 9 10 11 12"
<head>
    <!-- ...maplibre-gl script and stylesheet from above... -->
    <script src="https://unpkg.com/pmtiles@4.4.0/dist/pmtiles.js"></script>

    <!-- Register the pmtiles:// protocol before Flutter boots -->
    <script>
      const protocol = new pmtiles.Protocol();
      maplibregl.addProtocol("pmtiles", protocol.tile);
      const PMTILES_URL = "https://demo-bucket.protomaps.com/v4.pmtiles";
      const source = new pmtiles.FetchSource(PMTILES_URL);
      protocol.add(new pmtiles.PMTiles(source));
    </script>
</head>
```

!!! note "Why the inline script, not a deferred one"
    `flutter_bootstrap.js` is `async`, so an inline script placed *after* it could run before the protocol is registered. Keeping the registration synchronous and above the bootstrap guarantees `pmtiles://` is ready when the map loads.

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
        styleString: MapLibreStyles.defaultStyle,
      ),
    );
  }
}
```

!!! tip "Style URL"
    Pass any MapLibre-compatible style URL to `styleString`. You can self-host styles
    with [MapTiler](https://www.maptiler.com/), [Protomaps](https://protomaps.com/),
    or your own tile server.
