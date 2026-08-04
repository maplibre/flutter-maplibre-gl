---
hide:
  - navigation
  - toc
---

<div class="hero">
  <span class="hero__eyebrow">Maps for Flutter</span>
  <h1>MapLibre, natively in Flutter</h1>
  <p class="hero__tagline">Open data, the full MapLibre style spec, and no proprietary tokens. One Dart API across Android, iOS, and web.</p>
  <div class="badge-row">
    <span class="platform-badge platform-badge--android">Android</span>
    <span class="platform-badge platform-badge--ios">iOS</span>
    <span class="platform-badge platform-badge--web">Web</span>
  </div>
  <div class="badge-row">
    <a href="https://pub.dev/packages/maplibre_gl"><img src="https://img.shields.io/pub/v/maplibre_gl.svg?style=flat-square" alt="pub.dev version" /></a>
    <a href="https://github.com/maplibre/flutter-maplibre-gl"><img src="https://img.shields.io/github/stars/maplibre/flutter-maplibre-gl?style=flat-square&logo=github" alt="GitHub Stars" /></a>
    <a href="https://github.com/maplibre/flutter-maplibre-gl/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-BSD--2-blue?style=flat-square" alt="License" /></a>
  </div>
  <div class="cta-row">
    <a href="getting-started/" class="cta-btn cta-btn--primary">Get started</a>
    <a href="demo/" class="cta-btn cta-btn--demo" target="_blank" rel="noopener"><span class="live-dot" aria-hidden="true"></span>Live demo<svg class="ext-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M14 3h7v7m0-7L10 14M19 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h6"/></svg></a>
    <a href="https://github.com/maplibre/flutter-maplibre-gl" class="cta-btn cta-btn--secondary" target="_blank" rel="noopener">GitHub<svg class="ext-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M14 3h7v7m0-7L10 14M19 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h6"/></svg></a>
  </div>
</div>

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/demo/?example=doc-full-map"
  title="flutter-maplibre-gl live preview"
  loading="lazy"
></iframe>

<div class="section-label">Why this library</div>

<div class="feature-grid">
  <div class="feature-card">
    <span class="feature-card__icon">⚡</span>
    <div class="feature-card__title">Native C++ rendering</div>
    <div class="feature-card__desc">MapLibre Native on Android and iOS. Hardware-accelerated, 60fps, GPU-powered tile rendering.</div>
  </div>
  <div class="feature-card">
    <span class="feature-card__icon">🔓</span>
    <div class="feature-card__title">Truly open source</div>
    <div class="feature-card__desc">BSD-2 license. Use OpenFreeMap, OpenMapTiles, or self-host with PMTiles. Zero vendor lock-in.</div>
  </div>
  <div class="feature-card">
    <span class="feature-card__icon">📴</span>
    <div class="feature-card__title">Offline maps</div>
    <div class="feature-card__desc">Download geographic regions on Android and iOS. Tiles, fonts, and sprites live on-device, no network needed.</div>
  </div>
  <div class="feature-card">
    <span class="feature-card__icon">🎨</span>
    <div class="feature-card__title">Full style spec</div>
    <div class="feature-card__desc">Every MapLibre layer type: symbol, circle, fill, line, heatmap, raster. Data-driven expressions included.</div>
  </div>
  <div class="feature-card">
    <span class="feature-card__icon">📍</span>
    <div class="feature-card__title">Dual-layer API</div>
    <div class="feature-card__desc">High-level Annotations for quick interactive pins. Low-level Style Layers for large datasets and expressions.</div>
  </div>
  <div class="feature-card">
    <span class="feature-card__icon">🌐</span>
    <div class="feature-card__title">Web via GL JS</div>
    <div class="feature-card__desc">The same Dart API renders with MapLibre GL JS on web. One codebase, three platforms.</div>
  </div>
</div>

<div class="section-label">Quick start</div>

<div class="quickstart-block" markdown="1">

**1. Add the dependency**

```yaml
dependencies:
  maplibre_gl: ^0.26.2
```

**2. Add the map widget**

```dart
import 'package:maplibre_gl/maplibre_gl.dart';

MapLibreMap(
  initialCameraPosition: const CameraPosition(
    target: LatLng(48.8566, 2.3522), // Paris
    zoom: 11,
  ),
  onMapCreated: (MapLibreMapController controller) {
    // Add symbols, layers, and more
  },
)
```

See [Installation & Setup](getting-started.md) for Android, iOS, and web platform configuration.

</div>

<div class="section-label">Explore the docs</div>

<div class="feature-grid">
  <div class="feature-card">
    <div class="feature-card__title"><a href="concepts/architecture/">Architecture</a></div>
    <div class="feature-card__desc">How the Flutter widget, platform bridge, and MapLibre engine connect across Android, iOS, and web.</div>
  </div>
  <div class="feature-card">
    <div class="feature-card__title"><a href="concepts/annotations-vs-layers/">Annotations vs Style Layers</a></div>
    <div class="feature-card__desc">The library's most distinctive feature. Understand the two APIs and when to use each.</div>
  </div>
  <div class="feature-card">
    <div class="feature-card__title"><a href="advanced/expressions/">Data-Driven Expressions</a></div>
    <div class="feature-card__desc">Style features by their properties. Interpolate colors, scale sizes, and match categories, all on the GPU.</div>
  </div>
  <div class="feature-card">
    <div class="feature-card__title"><a href="layers/cluster/">Clustering</a></div>
    <div class="feature-card__desc">Group nearby points into expanding clusters. Built into the GeoJSON source, no server needed.</div>
  </div>
  <div class="feature-card">
    <div class="feature-card__title"><a href="advanced/pmtiles/">PMTiles</a></div>
    <div class="feature-card__desc">Self-host vector tiles as a single file. No tile server, no infrastructure, works on all platforms.</div>
  </div>
  <div class="feature-card">
    <div class="feature-card__title"><a href="compare/why-maplibre/">Why MapLibre GL?</a></div>
    <div class="feature-card__desc">Honest comparison with flutter_map and google_maps_flutter: features, tradeoffs, and when to choose each.</div>
  </div>
</div>
