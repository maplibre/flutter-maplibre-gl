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
[![stars](https://badgen.net/github/stars/maplibre/flutter-maplibre-gl?label=stars&color=green&icon=github)](https://github.com/maplibre/flutter-maplibre-gl/stargazers)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

Interactive, vector-tile, fully styleable maps for Flutter on **Android, iOS and Web**, powered by the open source [MapLibre](https://github.com/maplibre) engines. Vendor-neutral: host your own tiles or mix providers, no proprietary token required.

This project is a fork of [flutter-mapbox-gl](https://github.com/tobrun/flutter-mapbox-gl). If you're coming from it, see [Migration](#migration).

🚀 **[Launch the interactive demo](https://maplibre.github.io/flutter-maplibre-gl/)** — explore the full example app, interact with the map, and try MapLibre GL features instantly in your browser. No installation, setup, or API keys required.

## Platforms & feature support

Engines: [maplibre-native](https://github.com/maplibre/maplibre-native) (Android/iOS), [maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js) (Web). 
Only a subset of native SDK APIs is exposed, PRs to extend coverage are welcome.

| Feature | Android | iOS | Web |
|---|:---:|:---:|:---:|
| Style, Camera, Gesture | ✅ | ✅ | ✅ |
| User Location | ✅ | ✅ | ✅ |
| Symbol / Circle / Line / Fill | ✅ | ✅ | ✅ |
| Fill Extrusion | ✅ | ✅ | ✅ |
| Heatmap Layer | ✅ | ✅ | ✅ |

## Installation

```bash
flutter pub add maplibre_gl
```

### iOS

If you use location features, add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>[Explain why the app needs the user's location]</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>[Explain why the app needs the user's location in the background]</string>
```

`NSLocationAlwaysUsageDescription` is only required if you request always-on location access.

### Android

For location features, add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

The plugin does not request permissions at runtime — handle that yourself (e.g. with [`location`](https://pub.dev/packages/location)).

### Web

Add to the `<head>` of `web/index.html`:

```html
<script src='https://unpkg.com/maplibre-gl@^5.24.0/dist/maplibre-gl.js'></script>
<link href='https://unpkg.com/maplibre-gl@^5.24.0/dist/maplibre-gl.css' rel='stylesheet'/>
```

Always use the version that matches your installed `maplibre_gl_web` — check the example app's [`web/index.html`](./maplibre_gl_example/web/index.html) for the tag currently in use.

## Quick start

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
  final _controller = Completer<MapLibreMapController>();
  static const _initial = CameraPosition(target: LatLng(0, 0), zoom: 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        initialCameraPosition: _initial,
        onMapCreated: _controller.complete,
        styleString: 'https://demotiles.maplibre.org/style.json',
      ),
    );
  }
}
```

See the [example app](./maplibre_gl_example) for markers, layers, offline tiles and PMTiles.

## Usage

### Camera

```dart
await controller.animateCamera(
  CameraUpdate.newLatLngBounds(bounds, left: 24, top: 24, right: 24, bottom: 24),
);
```

Defer camera animations until the style is ready (`onStyleLoadedCallback`).

### Annotations

```dart
await controller.addSymbol(SymbolOptions(
  geometry: LatLng(37.7749, -122.4194),
  iconImage: 'assets/icon_pin.png', // register as a style image first
  iconSize: 1.2,
));
```

For lines/fills via a GeoJSON source, see the example app. Add sources before the layers that depend on them.

### Styles

`styleString` accepts any of: a remote URL, a bundled asset (registered in `pubspec.yaml`), an absolute file path, or a raw JSON string.

### Tiles requiring an API key

Embed the key in the tile URL:

```
https://tiles.example.com/{z}/{x}/{y}.vector.pbf?api_key=YOUR_KEY
```

Restrict keys at the provider (domain/referer, usage caps) and inject them at build time rather than committing them.

## Advanced topics
**Offline / mbtiles** — copy mbtiles, sprites and glyphs from assets to a writable directory, then point your style sources there. See issues [#338](https://github.com/maplibre/flutter-maplibre-gl/issues/338) and [#318](https://github.com/maplibre/flutter-maplibre-gl/issues/318).

**PMTiles** — load datasets via a custom protocol handler; see `pmtiles.dart` in the example app.

**Expressions** — data-driven styling follows the MapLibre style spec. For cross-platform safety use `["!", ["has", "field"]]` rather than `["!has", "field"]` (see FAQ).

**Code generation** — layer/source helpers are generated. Do not edit them directly; run `melos run generate && melos format-all`.

## Migration

Most APIs are source-compatible with `flutter-mapbox-gl`:

- Rename the dependency to `maplibre_gl`.
- Remove Mapbox token initialization — MapLibre uses open assets or your own endpoints.
- Replace Mapbox-specific style URLs with self-hosted or MapLibre-compatible ones.
- Audit filter expressions for iOS (`["!has", ...]` → `["!", ["has", ...]]`).

## Troubleshooting

**Loading mbtiles/sprites/glyphs from assets** — copy to a writable directory first, then reference the new path.

**Android `UnsatisfiedLinkError`** — make sure `abiFilters` covers the ABIs you ship:

```groovy
ndk { abiFilters 'armeabi-v7a','arm64-v8a','x86_64','x86' }
```

**iOS crash on location** — add `NSLocationWhenInUseUsageDescription` (see [iOS setup](#ios)).

**iOS `filter property must be a string`** — replace `["!has", "value"]` with `["!", ["has", "value"]]`.

## Architecture

Multi-package melos workspace:

- `maplibre_gl` — main plugin (mobile/native bindings)
- `maplibre_gl_web` — web implementation
- `maplibre_gl_platform_interface` — shared platform interface
- `scripts/` — code generation

Layer/source property helpers and expression utilities are generated. Don't edit generated files; run `melos run generate && melos format-all`.

## Contributing

```bash
dart pub global activate melos
melos bootstrap
```

Then run the example app to validate changes. See [CONTRIBUTING.md](./CONTRIBUTING.md) before opening a PR.

## Resources

- API docs: https://pub.dev/documentation/maplibre_gl/latest/
- [Changelog](./CHANGELOG.md) — always check before upgrading
- Help: [Discussions](https://github.com/maplibre/flutter-maplibre-gl/discussions), [Issues](https://github.com/maplibre/flutter-maplibre-gl/issues/new), [Slack](https://slack.openstreetmap.us/), [StackOverflow #maplibre](https://stackoverflow.com/search?q=maplibre)

## License

See [LICENSE](./LICENSE).