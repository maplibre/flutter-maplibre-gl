<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://maplibre.org/img/maplibre-logos/maplibre-logo-for-dark-bg.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://maplibre.org/img/maplibre-logos/maplibre-logo-for-light-bg.svg">
    <img alt="MapLibre Logo" src="https://maplibre.org/img/maplibre-logos/maplibre-logo-for-light-bg.svg" width="200">
  </picture>
</p>

# Flutter MapLibre GL

[![Pub Version](https://img.shields.io/pub/v/maplibre_gl)](https://pub.dev/packages/maplibre_gl)
[![likes](https://img.shields.io/pub/likes/maplibre_gl?logo=flutter)](https://pub.dev/packages/maplibre_gl)
[![Pub Points](https://img.shields.io/pub/points/maplibre_gl)](https://pub.dev/packages/maplibre_gl/score)
[![stars](https://badgen.net/github/stars/maplibre/flutter-maplibre-gl?label=stars&color=green&icon=github)](https://github.com/josxha/flutter-maplibre-gl/stargazers)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

Flutter MapLibre GL lets you embed **interactive, vector-tile based, fully styleable maps** directly inside your Flutter app across mobile & web.

This project is a fork of [flutter-mapbox-gl](https://github.com/tobrun/flutter-mapbox-gl), replacing its usage of Mapbox GL libraries with the open source [MapLibre GL](https://github.com/maplibre) libraries.

---

### Table of Contents

<details>
<summary>Click to expand</summary>

<!-- TOC (updated manually) -->
* [Features overview](#features-overview)
* [Why MapLibre?](#why-maplibre)
* [Supported Platforms & API Coverage](#supported-platforms--api-coverage)
* [Installation](#installation)
  * [Platform Setup](#platform-setup)
    * [iOS](#ios)
    * [Android](#android)
    * [Web](#web)
* [Quick Start](#quick-start)
* [Usage Highlights](#usage-highlights)
  * [Camera](#camera)
  * [Annotations & Layers](#annotations--layers)
  * [Map Styles](#map-styles)
  * [Sources needing API keys](#tile-sources-requiring-an-api-key)
* [Advanced Topics](#advanced-topics)
  * [Offline usage / mbtiles](#offline-usage--mbtiles)
  * [PMTiles](#pmtiles)
  * [Expressions & Styling](#expressions--styling)
  * [Generated Code](#generated-code)
  * [Architecture Overview](#architecture-overview)
* [Migration from flutter-mapbox-gl](#migration-from-flutter-mapbox-gl)
* [Performance Tips](#performance-tips)
* [Security & API Keys](#security--api-keys)
* [Troubleshooting / FAQ](#troubleshooting--faq)
* [Documentation & Examples](#documentation--examples)
* [Versioning & Changelog](#versioning--changelog)
* [Contributing](#contributing)
* [Getting Help](#getting-help)
* [License](#license)
<!-- /TOC -->

</details>

---

## Features overview

| Capability | Description |
|------------|-------------|
| Vector tile rendering | High quality, styleable vector maps via MapLibre engines |
| Dynamic styling | Swap or mutate styles at runtime, apply expressions |
| Camera control | Smooth programmatic & gesture driven map camera updates |
| User location | Native location indicator & tracking (permissions required) |
| Annotations | Symbols, circles, lines, fills, fill extrusions, heatmaps |
| Web support | Backed by `maplibre-gl-js` for web targets |
| Offline friendly | Patterns for mbtiles / cached assets (see advanced topics) |
| Extensible | Separate platform interface & web implementation packages |

---

## Why MapLibre?

MapLibre is a **vendor-neutral, open source** set of mapping libraries born from the community. Using MapLibre helps you:

* Avoid vendor lock-in & proprietary billing tie-ins
* Host your own tiles or mix commercial/open sources
* Keep transparent, auditable code in production
* Align with OSS licensing and long-term sustainability
* One of the fastest map SDKs available. Capable of drawing a large number of vector objects.

If you previously used `flutter-mapbox-gl`, you can migrate with minimal changes (see [migration guide](#migration-from-flutter-mapbox-gl)).

---

## Supported Platforms & API Coverage

Underlying engines:
* **Android / iOS** — [maplibre-native](https://github.com/maplibre/maplibre-native)
* **Web** — [maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js)

> **Note**: Only a subset of the native SDK APIs are currently exposed. PRs to extend surface area are welcome.

| Feature        | Android | iOS | Web |
|----------------|:-------:|:---:|:---:|
| Style          |   ✅    | ✅  | ✅  |
| Camera         |   ✅    | ✅  | ✅  |
| Gesture        |   ✅    | ✅  | ✅  |
| User Location  |   ✅    | ✅  | ✅  |
| Symbol         |   ✅    | ✅  | ✅  |
| Circle         |   ✅    | ✅  | ✅  |
| Line           |   ✅    | ✅  | ✅  |
| Fill           |   ✅    | ✅  | ✅  |
| Fill Extrusion |   ✅    | ✅  | ✅  |
| Heatmap Layer  |   ✅    | ✅  | ✅  |

---

## Installation

Add the dependency:

```yaml
dependencies:
  maplibre_gl: ^LATEST_VERSION
```

(See the current version badge above or on [pub.dev](https://pub.dev/packages/maplibre_gl)).

Then run:
```bash
flutter pub get
```

### Platform setup

#### iOS

Add permission usage description for location (if using location features) to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>[Explain why the app needs the user's location]</string>
```

#### Android

Minimum supported Kotlin version: `2.1.0`. In `android/settings.gradle`:

```groovy
plugins {
  id "org.jetbrains.kotlin.android" version "2.1.0" apply false
}
```

Add location permissions if required in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Request permissions at runtime yourself (e.g. via the [`location`](https://pub.dev/packages/location) plugin). The plugin does not prompt automatically.

#### Web

Include the following JavaScript and CSS files in the `<head>` of your `web/index.html` file:

```html
<script src="https://unpkg.com/maplibre-gl@^4.3/dist/maplibre-gl.js"></script>
<link href="https://unpkg.com/maplibre-gl@^4.3/dist/maplibre-gl.css" rel="stylesheet" />
```

---

## Quick Start

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class SimpleMapPage extends StatefulWidget {
  const SimpleMapPage({super.key});
  @override
  State<SimpleMapPage> createState() => _SimpleMapPageState();
}

class _SimpleMapPageState extends State<SimpleMapPage> {
  final _controllerCompleter = Completer<MapLibreMapController>();
  bool _styleLoaded = false;

  static const _initial = CameraPosition(target: LatLng(0, 0), zoom: 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MapLibre Quick Start')),
      floatingActionButton: _styleLoaded
          ? FloatingActionButton.small(
              onPressed: _goHome,
              child: const Icon(Icons.explore),
            )
          : null,
      body: MapLibreMap(
        initialCameraPosition: _initial,
        onMapCreated: (c) => _controllerCompleter.complete(c),
        onStyleLoadedCallback: () => setState(() => _styleLoaded = true),
      ),
    );
  }

  Future<void> _goHome() async {
    final c = await _controllerCompleter.future;
    await c.animateCamera(CameraUpdate.newCameraPosition(_initial));
  }
}
```

Check the [example project](./maplibre_gl_example) for richer demos (markers, layers, offline patterns, PMTiles, etc.).

---

## Usage Highlights

### Camera

```dart
await controller.animateCamera(
  CameraUpdate.newLatLngBounds(bounds, left: 24, top: 24, right: 24, bottom: 24),
);
```

### Annotations & Layers

Add symbols (markers):
```dart
await controller.addSymbol(SymbolOptions(
  geometry: LatLng(37.7749, -122.4194),
  iconImage: 'assets/icon_pin.png', // ensure added as style image first
  iconSize: 1.2,
));
```

Add line layer (via geojson source) – see example app for full workflow.

### Map Styles

Provide a `styleString`:
1. Remote URL (`https://.../style.json`)
2. App asset (`assets/map_style.json` with pubspec asset registration)
3. Local file system absolute path
4. Raw JSON string

### Tile sources requiring an API key

Embed the key directly in the vector tile URL:

```
https://tiles.example.com/{z}/{x}/{y}.vector.pbf?api_key=YOUR_KEY
```

---

## Advanced Topics

### Offline usage / mbtiles
Copy mbtiles (or sprites/glyphs) from bundled assets to a writable directory (e.g. cache) and point your style sources there. See issues [#338](https://github.com/maplibre/flutter-maplibre-gl/issues/338) & [#318](https://github.com/maplibre/flutter-maplibre-gl/issues/318) for community approaches.

### PMTiles
The example app includes a `pmtiles` usage sample demonstrating how to load datasets via a custom protocol handler / tile source. (Look for `pmtiles.dart` in `maplibre_gl_example`.)

### Expressions & Styling
Use data‑driven styling with expressions similar to Mapbox / MapLibre style spec. Some platform discrepancies exist (see FAQ around `!has`). For cross‑platform safety prefer form: `["!", ["has", "field"]]`.

### Generated Code
Layer/source property helpers & expression utilities are generated from templates under `scripts/`. Do **not** edit generated files directly—run:

```
melos run generate
melos format-all
```

### Architecture Overview

This repository is a multi-package workspace:
* `maplibre_gl` – main Flutter plugin (mobile/native bindings)
* `maplibre_gl_web` – web implementation
* `maplibre_gl_platform_interface` – shared platform interface (enables adding alternative implementations)
* `scripts/` – code generation templates & tooling

---

## Migration from flutter-mapbox-gl

Most APIs are source-compatible. Key differences to watch:
* Dependency name changes to `maplibre_gl`.
* Remove any Mapbox token initialization (MapLibre uses open assets or your own tile endpoints).
* If you referenced Mapbox-specific style endpoints, replace with self-hosted / MapLibre friendly ones.
* Audit expressions for iOS compatibility (`["!has", ...]` variant change noted in FAQ).

---

## Performance Tips

* Reuse a single `MapLibreMap` widget when possible instead of recreating it in tab/page switches.
* Batch style mutations (e.g. add sources before adding dependent layers) to avoid intermediate layout recalculations.
* Use simpler geometries or tiling strategies for very dense data.
* Avoid large uncompressed GeoJSON inline; host as a URL source if size is large.
* Defer camera animations until style load (`onStyleLoadedCallback`).

---

## Security & API Keys

If you embed API keys in style URLs for third-party tiles, ensure you:
* Restrict keys at the provider (domain / referer / usage caps).
* Avoid shipping unnecessary privileges (read-only tile scopes where possible).
Environment variable injection at build time is recommended for CI-driven apps—avoid committing raw secrets.

---

## Troubleshooting / FAQ

### Loading .mbtiles / sprites / glyphs from app assets
Copy them to a writable directory (cache/documents) first, then reference the new path in the style or source configuration. See issues [#338](https://github.com/maplibre/flutter-maplibre-gl/issues/338) & [#318](https://github.com/maplibre/flutter-maplibre-gl/issues/318).

### Android UnsatisfiedLinkError
Ensure `abiFilters` include the ABIs you intend to ship:
```gradle
buildTypes {
  release {
    ndk { abiFilters 'armeabi-v7a','arm64-v8a','x86_64','x86' }
  }
}
```

### iOS crash when using location features
Add `NSLocationWhenInUseUsageDescription` (see [iOS setup](#ios)).
<!-- 
### Layer not displayed on iOS but works on Android
Use hex colors like `#FFAA00` instead of CSS `rgba(...)` strings when passing color values. -->

### iOS filter expression error
Error: `Invalid filter value: filter property must be a string`. Replace `["!has", "value"]` with `["!", ["has", "value"]]`.

---

## Documentation & Examples

* Minimal example (for pub.dev & quick start): see [`example/lib/main.dart`](./example/lib/main.dart)
* Full featured example app: [`maplibre_gl_example`](./maplibre_gl_example)
* API docs: https://pub.dev/documentation/maplibre_gl/latest/
* MapLibre upstream projects: [maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js), [maplibre-native](https://github.com/maplibre/maplibre-native)

---

## Versioning & Changelog

Releases follow semantic versioning as practical; breaking changes are documented in the [CHANGELOG](./CHANGELOG.md) (root and per package). Always consult the changelog when upgrading.

---

## Contributing

This is a multi-package workspace managed by [melos](https://melos.invertase.dev/~melos-latest/getting-started).

Basic flow:
```
dart pub global activate melos  # activate melos package

melos bootstrap                 # initialize & link local packages
```
Then open & run the example app to validate and check changes.

Please read the full [CONTRIBUTING.md](./CONTRIBUTING.md) before submitting a PR.

> Generated code: Some API surface (layer/source property helpers, expression utilities) is produced via a generator under `scripts/`. Do not modify generated files directly — see [Code Generation & Formatting](#generated-code) section for workflow.

---

## Getting Help
* Join our [Slack](https://slack.openstreetmap.us/) channel
* StackOverflow tag: [#maplibre](https://stackoverflow.com/questions/tagged/maplibre)
* Discussions: https://github.com/maplibre/flutter-maplibre-gl/discussions
* Bugs / Features: [Open an issue](https://github.com/maplibre/flutter-maplibre-gl/issues/new) (include reproduction details/logs where possible)

---

## License

See [LICENSE](./LICENSE) for details.

---

\
If this plugin helps you build something cool, consider starring the repo to support visibility.
