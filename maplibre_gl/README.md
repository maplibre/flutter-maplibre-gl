<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://maplibre.org/img/maplibre-logos/maplibre-logo-for-dark-bg.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://maplibre.org/img/maplibre-logos/maplibre-logo-for-light-bg.svg">
    <img alt="MapLibre Logo" src="https://maplibre.org/img/maplibre-logos/maplibre-logo-for-light-bg.svg" width="240">
  </picture>
  <h1 align="center">Flutter MapLibre GL</h1>
  <p align="center">
    Interactive, fully styleable vector maps on <b>Android, iOS and Web</b>, powered by open source <a href="https://github.com/maplibre">MapLibre</a>.<br>
    <b>Vendor-neutral</b>: host your own tiles or mix providers, no account or API key required to get started.
  </p>
  <p align="center">
    <a href="https://pub.dev/packages/maplibre_gl"><img src="https://img.shields.io/pub/v/maplibre_gl?style=flat-square" alt="Pub Version"></a>
    <a href="https://pub.dev/packages/maplibre_gl"><img src="https://img.shields.io/pub/likes/maplibre_gl?logo=flutter&style=flat-square" alt="Likes"></a>
    <a href="https://pub.dev/packages/maplibre_gl/score"><img src="https://img.shields.io/pub/points/maplibre_gl?style=flat-square" alt="Pub Points"></a>
    <a href="https://github.com/maplibre/flutter-maplibre-gl/stargazers"><img src="https://img.shields.io/github/stars/maplibre/flutter-maplibre-gl?style=flat-square&logo=github&color=green" alt="Stars"></a>
    <a href="https://github.com/invertase/melos"><img src="https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square" alt="Melos"></a>
  </p>
  <p align="center"><b>✨ Try it before you install:</b> run the package live in your browser and read the full docs, no setup and no API keys.</p>
  <p align="center">
    <a href="https://maplibre.org/flutter-maplibre-gl/demo/"><img src="https://img.shields.io/badge/🌐%20Live%20demo-2A6BF2?style=for-the-badge" height="38" alt="Live demo"></a>
    &nbsp;&nbsp;
    <a href="https://maplibre.org/flutter-maplibre-gl/"><img src="https://img.shields.io/badge/📖%20Documentation-3FB950?style=for-the-badge" height="38" alt="Documentation"></a>
  </p>
</div>

## 🖼️ What it looks like

| **3D buildings** | **Clustering** | **Globe, on web** |
|:---:|:---:|:---:|
| ![Midtown Manhattan with the camera pitched and rotated](https://raw.githubusercontent.com/maplibre/flutter-maplibre-gl/v0.27.0/maplibre_gl/screenshots/buildings-3d.webp) | ![GeoJSON points clustered with live counts](https://raw.githubusercontent.com/maplibre/flutter-maplibre-gl/v0.27.0/maplibre_gl/screenshots/cluster.webp) | ![globe projection rendered by MapLibre GL JS](https://raw.githubusercontent.com/maplibre/flutter-maplibre-gl/v0.27.0/maplibre_gl/screenshots/globe.webp) |

| **Data-driven styling** | **Heatmaps** | **Annotations** |
|:---:|:---:|:---:|
| ![countries coloured and faded by their own properties](https://raw.githubusercontent.com/maplibre/flutter-maplibre-gl/v0.27.0/maplibre_gl/screenshots/expressions.webp) | ![point density drawn on the GPU](https://raw.githubusercontent.com/maplibre/flutter-maplibre-gl/v0.27.0/maplibre_gl/screenshots/heatmap.webp) | ![symbol markers with custom icons and labels](https://raw.githubusercontent.com/maplibre/flutter-maplibre-gl/v0.27.0/maplibre_gl/screenshots/annotations.webp) |

All of these are live in the [demo](https://maplibre.org/flutter-maplibre-gl/demo/), and every [guide](https://maplibre.org/flutter-maplibre-gl/) embeds an interactive map you can pan and click.

## 🚀 Quick start

```bash
flutter pub add maplibre_gl
```

```dart
import 'package:maplibre_gl/maplibre_gl.dart';

// Anywhere with bounded constraints, a Scaffold body for example:
MapLibreMap(
  initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 2),
  styleString: 'https://demotiles.maplibre.org/style.json',
  onStyleLoadedCallback: () {
    // Add sources, layers and images here.
  },
);
```

**Requires** Flutter 3.29+ · Dart 3.7+ · Android 5.0 (API 21)+ · iOS 13+ · a browser with WebGL2 (Safari 15+).

Then head to the [getting started guide](https://maplibre.org/flutter-maplibre-gl/getting-started/) for platform setup (location permissions on iOS/Android; web needs no `index.html` changes) and to learn how to add markers, layers, offline tiles and more.

> Upgrading from an earlier release? See the [migration guide](https://maplibre.org/flutter-maplibre-gl/migration/).

## 🗺️ Feature support

Engines: [maplibre-native](https://github.com/maplibre/maplibre-native) (Android/iOS), [maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js) (Web). Only a subset of native SDK APIs is exposed, PRs to extend coverage are welcome.

| Feature | Android | iOS | Web |
|---|:---:|:---:|:---:|
| Style, Camera, Gesture | ✅ | ✅ | ✅ |
| User Location | ✅ | ✅ | ✅ |
| Annotations | ✅ | ✅ | ✅ |
| All layer types (Symbol to Hillshade) | ✅ | ✅ | ✅ |
| GeoJSON, vector, raster & PMTiles sources | ✅ | ✅ | ✅ |
| Offline regions | ✅ | ✅ | ❌ |
| Feature state | ✅ | ❌ | ✅ |

See the full [feature matrix](https://maplibre.org/flutter-maplibre-gl/compare/feature-matrix/) for details.

**Not supported**: desktop targets (Windows, macOS, Linux), and Flutter widgets *inside* the map. The map is a
platform view rendered by the native engines, so your widgets go over it in a `Stack`, not between its layers.

## 🔗 Links

[Example app](https://github.com/maplibre/flutter-maplibre-gl/tree/main/maplibre_gl_example) · [API reference](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/) · [Changelog](./CHANGELOG.md) · [Discussions](https://github.com/maplibre/flutter-maplibre-gl/discussions) · [Issues](https://github.com/maplibre/flutter-maplibre-gl/issues/new) · [Slack (#maplibre-flutter)](https://slack.openstreetmap.us/)

## 🤝 Contributing

```bash
dart pub global activate melos
melos bootstrap
```

This is a melos workspace (`maplibre_gl`, `maplibre_gl_web`, `maplibre_gl_platform_interface` and the example app). Layer/source helpers are generated, don't edit them directly; run `melos run generate && melos run format-all`. See [CONTRIBUTING.md](https://github.com/maplibre/flutter-maplibre-gl/blob/main/CONTRIBUTING.md) before opening a PR, and the [architecture docs](https://maplibre.org/flutter-maplibre-gl/concepts/architecture/) for an overview.

This project is a fork of [flutter-mapbox-gl](https://github.com/tobrun/flutter-mapbox-gl). ❤️

## 💝 Contributors

A huge thanks to everyone who has contributed to this project!

<a href="https://github.com/maplibre/flutter-maplibre-gl/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=maplibre/flutter-maplibre-gl" alt="Contributors" />
</a>

Made with [contrib.rocks](https://contrib.rocks).

## 📄 License

See [LICENSE](./LICENSE).
