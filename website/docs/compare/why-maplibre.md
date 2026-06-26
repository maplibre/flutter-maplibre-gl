# Why MapLibre GL

There are three mainstream ways to put a map in a Flutter app. This page is an honest comparison, not a sales pitch, to help you pick the right one. If another library fits your project better, you should use it.

<div class="table-scroll" markdown>
<table class="comparison-table">
  <thead>
    <tr>
      <th>Capability</th>
      <th>flutter-maplibre-gl</th>
      <th>flutter_map</th>
      <th>google_maps_flutter</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Renderer</td>
      <td>MapLibre Native (C++/GPU)</td>
      <td>Flutter canvas</td>
      <td>Google Maps SDK</td>
    </tr>
    <tr>
      <td>Offline maps</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Android &amp; iOS</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
    </tr>
    <tr>
      <td>Custom vector styles</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Full spec</span></td>
      <td><span class="cell-ic"><span class="ic ic--mid">●</span> Limited</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
    </tr>
    <tr>
      <td>GeoJSON support</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Full + live update</span></td>
      <td><span class="cell-ic"><span class="ic ic--mid">●</span> Via plugins</span></td>
      <td><span class="cell-ic"><span class="ic ic--mid">●</span> Limited</span></td>
    </tr>
    <tr>
      <td>Data-driven styling</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Expressions</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
    </tr>
    <tr>
      <td>Clustering</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Native</span></td>
      <td><span class="cell-ic"><span class="ic ic--mid">●</span> Via plugin</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
    </tr>
    <tr>
      <td>Heatmaps</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
    </tr>
    <tr>
      <td>3D extrusion</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
      <td><span class="cell-ic"><span class="ic ic--mid">●</span> Limited</span></td>
    </tr>
    <tr>
      <td>PMTiles</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Built-in</span></td>
      <td><span class="cell-ic"><span class="ic ic--mid">●</span> Via plugin</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
    </tr>
    <tr>
      <td>Vector tiles</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
    </tr>
    <tr>
      <td>Open tile sources</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> Key required</span></td>
    </tr>
    <tr>
      <td>Web support</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> GL JS</span></td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
    </tr>
    <tr>
      <td>License</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> BSD-2</span></td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> BSD-2</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> Proprietary</span></td>
    </tr>
    <tr>
      <td>Tile cost</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Free options</span></td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Free options</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> Pay-per-use</span></td>
    </tr>
  </tbody>
</table>
</div>

<span class="ic ic--yes">✔</span> full support &nbsp;·&nbsp; <span class="ic ic--mid">●</span> partial / via plugin &nbsp;·&nbsp; <span class="ic ic--no">✘</span> not available
{ .legend }

## Choose flutter-maplibre-gl when

You need any of these, and they are hard or impossible elsewhere:

- **Offline maps.** Users download regions and keep using the map with no connection.
- **Custom styling.** White-label maps, dark mode, brand colors, show or hide individual layers.
- **Large datasets.** Tens of thousands of GeoJSON features rendered on the GPU without dropping frames.
- **Data-driven styling.** Color roads by speed limit, size circles by population, all evaluated per feature at render time.
- **PMTiles.** Self-host your tile data as a single file with no tile server.
- **An open stack.** No vendor lock-in and no API key when you use open tile providers.
- **Advanced cartography.** 3D buildings, hillshade, heatmaps, terrain.

## Choose flutter_map when

[flutter_map](https://pub.dev/packages/flutter_map) is the right call when:

- You want **pure Flutter rendering** with no native code, including smooth desktop support without platform-view overhead.
- You need to overlay **arbitrary Flutter widgets** directly inside the tile layer.
- Your map is simple: raster tiles plus a handful of markers.
- You target **Linux or Windows** desktop, where native MapLibre support is limited.
- Your team wants to avoid native iOS and Android setup.

flutter_map renders raster tiles (PNG/WebP) by default. It does not do vector styles, expressions, or GPU-accelerated vector rendering natively.

## Choose google_maps_flutter when

[google_maps_flutter](https://pub.dev/packages/google_maps_flutter) fits when:

- Users expect the **Google Maps look** and brand.
- You already run a **Google Maps Platform** billing account and key.
- You need **Google-specific features**: Street View, Places integration, Google traffic.
- Your organization mandates Google services.

Google Maps requires a paid key for production, has no offline support, and the style cannot be customized beyond basic color tweaks.

## Performance at scale

Rendering 10,000 point features is where the architectural difference shows:

<div class="table-scroll" markdown>
<table class="comparison-table">
  <thead>
    <tr>
      <th>Aspect</th>
      <th>flutter-maplibre-gl</th>
      <th>flutter_map</th>
      <th>google_maps_flutter</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Approach</td>
      <td>Vector tiles + GPU</td>
      <td>Raster tiles + canvas</td>
      <td>Raster tiles + SDK</td>
    </tr>
    <tr>
      <td>10k points</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Native cluster/layer</span></td>
      <td><span class="cell-ic"><span class="ic ic--mid">●</span> Plugin, may lag</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> Not designed for it</span></td>
    </tr>
    <tr>
      <td>Smooth at 60fps</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
      <td><span class="cell-ic"><span class="ic ic--mid">●</span> Depends on count</span></td>
      <td><span class="cell-ic"><span class="ic ic--mid">●</span> Depends</span></td>
    </tr>
    <tr>
      <td>Data-driven colors</td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Expressions</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
      <td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td>
    </tr>
  </tbody>
</table>
</div>

All rendering is delegated to the native MapLibre engine, which runs on the GPU. The Flutter layer only manages configuration. It never draws map tiles itself.

For the full platform-by-platform breakdown, see the [Feature Matrix](feature-matrix.md).
