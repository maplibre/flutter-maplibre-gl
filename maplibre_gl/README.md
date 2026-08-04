<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://maplibre.org/img/maplibre-logos/maplibre-logo-for-dark-bg.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://maplibre.org/img/maplibre-logos/maplibre-logo-for-light-bg.svg">
  <img alt="MapLibre Logo" src="https://maplibre.org/img/maplibre-logos/maplibre-logo-for-light-bg.svg" width="240">
</picture>

# Flutter MapLibre GL

Interactive, vector-tile, fully styleable maps for Flutter on <b>Android, iOS and Web</b>, powered by the open source <a href="https://github.com/maplibre">MapLibre</a> engines.<br>
<b>Vendor-neutral</b>: host your own tiles or mix providers, no proprietary token required.

<a href="https://pub.dev/packages/maplibre_gl"><img src="https://img.shields.io/pub/v/maplibre_gl?style=flat-square" alt="Pub Version"></a>
<a href="https://pub.dev/packages/maplibre_gl"><img src="https://img.shields.io/pub/likes/maplibre_gl?logo=flutter&style=flat-square" alt="Likes"></a>
<a href="https://pub.dev/packages/maplibre_gl/score"><img src="https://img.shields.io/pub/points/maplibre_gl?style=flat-square" alt="Pub Points"></a>
<a href="https://github.com/maplibre/flutter-maplibre-gl/stargazers"><img src="https://img.shields.io/github/stars/maplibre/flutter-maplibre-gl?style=flat-square&logo=github&color=green" alt="Stars"></a>
<a href="https://github.com/invertase/melos"><img src="https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square" alt="Melos"></a>

<b>✨ New:</b> try the package live in your browser and browse the full docs, no setup or API keys required.

<a href="https://maplibre.github.io/flutter-maplibre-gl/demo/"><img src="https://img.shields.io/badge/🌐%20Live%20demo-2A6BF2?style=for-the-badge" height="38" alt="Live demo"></a>
&nbsp;&nbsp;
<a href="https://maplibre.github.io/flutter-maplibre-gl/"><img src="https://img.shields.io/badge/📖%20Documentation-3FB950?style=for-the-badge" height="38" alt="Documentation"></a>

## 🚀 Quick start

```bash
flutter pub add maplibre_gl
```

```dart
import 'package:maplibre_gl/maplibre_gl.dart';

MapLibreMap(
  initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 2),
  styleString: 'https://demotiles.maplibre.org/style.json',
);
```

Then head to the [getting started guide](https://maplibre.github.io/flutter-maplibre-gl/getting-started/) for platform setup (iOS/Android permissions, the web `<script>` tag) and to learn how to add markers, layers, offline tiles and more.

> Migrating from [flutter-mapbox-gl](https://github.com/tobrun/flutter-mapbox-gl)? See the [migration guide](https://maplibre.github.io/flutter-maplibre-gl/migration/).

## 🗺️ Feature support

Engines: [maplibre-native](https://github.com/maplibre/maplibre-native) (Android/iOS), [maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js) (Web). Only a subset of native SDK APIs is exposed, PRs to extend coverage are welcome.

| Feature | Android | iOS | Web |
|---|:---:|:---:|:---:|
| Style, Camera, Gesture | ✅ | ✅ | ✅ |
| User Location | ✅ | ✅ | ✅ |
| Symbol / Circle / Line / Fill | ✅ | ✅ | ✅ |
| Fill Extrusion | ✅ | ✅ | ✅ |
| Heatmap Layer | ✅ | ✅ | ✅ |

See the full [feature matrix](https://maplibre.github.io/flutter-maplibre-gl/compare/feature-matrix/) for details.

## 🤓 Contributing

```bash
dart pub global activate melos
melos bootstrap
```

This is a melos workspace (`maplibre_gl`, `maplibre_gl_web`, `maplibre_gl_platform_interface`). Layer/source helpers are generated, don't edit them directly; run `melos run generate && melos format-all`. See [CONTRIBUTING.md](./CONTRIBUTING.md) before opening a PR, and the [architecture docs](https://maplibre.github.io/flutter-maplibre-gl/concepts/architecture/) for an overview.

This project is a fork of [flutter-mapbox-gl](https://github.com/tobrun/flutter-mapbox-gl). ❤️

## 🔗 Links

[Example app](./maplibre_gl_example) · [API reference](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/) · [Changelog](./CHANGELOG.md) · [Discussions](https://github.com/maplibre/flutter-maplibre-gl/discussions) · [Issues](https://github.com/maplibre/flutter-maplibre-gl/issues/new) · [Slack](https://slack.openstreetmap.us/)

## 💝 Contributors

A huge thanks to everyone who has contributed to this project!

<a href="https://github.com/maplibre/flutter-maplibre-gl/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=maplibre/flutter-maplibre-gl" alt="Contributors" />
</a>

## License

See [LICENSE](./LICENSE).
