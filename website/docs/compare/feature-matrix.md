# Feature Matrix

What works on each platform. flutter-maplibre-gl uses MapLibre Native on Android and iOS, and MapLibre GL JS on the web. Desktop (Windows, macOS, Linux) is not a supported target for this package.

<span class="ic ic--yes">✔</span> supported &nbsp;·&nbsp; <span class="ic ic--no">✘</span> not available on this platform
{ .legend }

## Core

<div class="table-scroll" markdown>
<table class="comparison-table comparison-table--matrix">
  <thead>
    <tr><th>Feature</th><th>Android</th><th>iOS</th><th>Web</th></tr>
  </thead>
  <tbody>
    <tr><td>Map widget</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Map controller</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Camera control &amp; animation</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Gesture handling</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Tap / long-press events</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>User location</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Offline regions</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--no">✘</span></span></td></tr>
    <tr><td>Snapshot (static image)</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
  </tbody>
</table>
</div>

## Annotations

<div class="table-scroll" markdown>
<table class="comparison-table comparison-table--matrix">
  <thead>
    <tr><th>Feature</th><th>Android</th><th>iOS</th><th>Web</th></tr>
  </thead>
  <tbody>
    <tr><td>Symbol (markers)</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Circle</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Line</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Fill (polygon)</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Custom marker images</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Draggable annotations</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
  </tbody>
</table>
</div>

## Style layers

<div class="table-scroll" markdown>
<table class="comparison-table comparison-table--matrix">
  <thead>
    <tr><th>Feature</th><th>Android</th><th>iOS</th><th>Web</th></tr>
  </thead>
  <tbody>
    <tr><td>Symbol layer</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Circle layer</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Line layer</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Fill layer</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Fill extrusion (3D)</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Heatmap layer</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Hillshade layer</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Raster layer</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Data-driven expressions</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Clustering</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
  </tbody>
</table>
</div>

## Sources

<div class="table-scroll" markdown>
<table class="comparison-table comparison-table--matrix">
  <thead>
    <tr><th>Source type</th><th>Android</th><th>iOS</th><th>Web</th></tr>
  </thead>
  <tbody>
    <tr><td>GeoJSON</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Vector tiles</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Raster tiles</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Raster DEM</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>Image source</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
    <tr><td>PMTiles</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span></span></td></tr>
  </tbody>
</table>
</div>

!!! note "Web hover events"
    Pointer hover events are available only on the web build (MapLibre GL JS). On Android and iOS, use tap and long-press instead. Guard hover-only logic with `kIsWeb`.
