# Annotations vs Style Layers

This is the most important conceptual distinction in flutter-maplibre-gl. The library provides **two completely different APIs** for putting things on a map. Choosing the right one saves you from performance problems and unexpected limitations.

## The short version

<div class="table-scroll" markdown>
<table class="comparison-table">
  <thead>
    <tr><th>Capability</th><th>Annotations</th><th>Style Layers</th></tr>
  </thead>
  <tbody>
    <tr><td>API</td><td><code>addSymbol()</code>, <code>addCircle()</code>, <code>addFill()</code>, <code>addLine()</code></td><td><code>addGeoJsonSource()</code> + <code>addSymbolLayer()</code> etc.</td></tr>
    <tr><td>Complexity</td><td>Low</td><td>Medium</td></tr>
    <tr><td>Max features</td><td>~hundreds</td><td>100,000+</td></tr>
    <tr><td>Data-driven styling</td><td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes (expressions)</span></td></tr>
    <tr><td>Tap callbacks</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span> Built-in</span></td><td><span class="cell-ic"><span class="ic ic--mid">●</span> Manual (<code>queryRenderedFeatures</code>)</span></td></tr>
    <tr><td>Draggable</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span> Built-in</span></td><td><span class="cell-ic"><span class="ic ic--mid">●</span> Via onFeatureDrag</span></td></tr>
    <tr><td>Clustering</td><td><span class="cell-ic"><span class="ic ic--no">✘</span> No</span></td><td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td></tr>
    <tr><td>Live update</td><td><code>updateSymbol()</code></td><td><code>setGeoJsonSource()</code></td></tr>
    <tr><td><strong>Best for</strong></td><td>A few interactive pins</td><td>Datasets, heatmaps, clusters</td></tr>
  </tbody>
</table>
</div>

## Annotations: the simple API

Annotations are Flutter objects that represent individual features. You add them one at a time and get back a typed handle to update or remove later.

```dart
// Add a marker
final symbol = await controller.addSymbol(
  const SymbolOptions(
    geometry: LatLng(48.8566, 2.3522),
    iconImage: 'my-pin',
    textField: 'Paris',
  ),
);

// Update it later
await controller.updateSymbol(
  symbol,
  const SymbolOptions(textField: 'Paris, France'),
);

// Remove it
await controller.removeSymbol(symbol);

// React to taps
controller.onSymbolTapped.add((Symbol s) {
  print('Tapped: ${s.options.textField}');
});
```

**Annotation types:** `Symbol` (icons + text), `Circle`, `Fill` (polygon), `Line`

### What happens under the hood

`AnnotationManager` internally creates a hidden GeoJSON source and a style layer for each annotation type. When you call `addSymbol()`, the manager adds a feature to that source. **Annotations are a convenience wrapper over style layers.** They trade flexibility for simplicity.

## Style Layers: the powerful API

Style layers give you direct access to the MapLibre style specification. You manage the data yourself (as GeoJSON), and MapLibre renders it using data-driven expressions.

```dart
// 1. Add the data source
await controller.addGeoJsonSource('cities', {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'properties': {'name': 'Paris', 'population': 2161000},
      'geometry': {'type': 'Point', 'coordinates': [2.3522, 48.8566]},
    },
    // ... thousands more
  ],
});

// 2. Add a layer that renders the source
await controller.addSymbolLayer(
  'cities',           // source id
  'cities-labels',   // layer id
  SymbolLayerProperties(
    textField: [Expressions.get, 'name'],       // read from property
    textSize: [
      Expressions.interpolate, ['linear'],
      [Expressions.get, 'population'],
      100000, 10.0,   // small city → 10px
      5000000, 18.0,  // large city → 18px
    ],
  ),
);

// 3. Update all data at once
await controller.setGeoJsonSource('cities', newFeatureCollection);
```

### What you get that Annotations don't have

- **Data-driven expressions**: style any property based on feature data
- **Filters**: show/hide features based on properties: `filter: ['==', ['get', 'category'], 'park']`
- **Clustering**: group nearby points automatically at low zoom
- **Heatmaps**: density visualization
- **Performance at scale**: render hundreds of thousands of features natively

## Side-by-side: the same markers, two ways

<div class="code-compare" markdown="1">
<div markdown="1">

**Annotations**
```dart
// Simple, managed
await controller.addSymbol(
  const SymbolOptions(
    geometry: LatLng(48.8566, 2.3522),
    iconImage: 'my-pin',
    iconColor: '#E74C3C',
    textField: 'Paris',
  ),
);

// Built-in tap handling
controller.onSymbolTapped.add(
  (s) => print('Tapped!'),
);
```

</div>
<div markdown="1">

**Style Layers**
```dart
// Source + layer
await controller.addGeoJsonSource('pts', {
  'type': 'FeatureCollection',
  'features': [{
    'type': 'Feature',
    'properties': {'name': 'Paris'},
    'geometry': {
      'type': 'Point',
      'coordinates': [2.3522, 48.8566],
    },
  }],
});

await controller.addSymbolLayer('pts', 'pts-layer',
  SymbolLayerProperties(
    iconImage: 'my-pin',
    iconColor: '#E74C3C',
    textField: [Expressions.get, 'name'],
  ),
);
```

</div>
</div>

## Live demo

<div class="example-compare" markdown="1">
<div markdown="1">

**Annotations** (5 tappable landmarks via `addSymbol()`):

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/demo/?example=doc-annotation-markers"
  title="Annotation markers"
  loading="lazy"
></iframe>

</div>
<div markdown="1">

**Style Layers** (10 cities via `addGeoJsonSource` + `addSymbolLayer`):

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/demo/?example=doc-symbol-layer"
  title="Symbol layer"
  loading="lazy"
></iframe>

</div>
</div>

## Constraints and gotchas

Both APIs have rules that are easy to miss. Most support questions come from
this list.

### Both APIs

- **Wait for the style.** Nothing can be added before the style has finished
  loading. Do your setup in `onStyleLoadedCallback`, not in `onMapCreated`.
- **A style change wipes everything.** When the style is replaced (via
  `setStyle()` or a new `styleString`), all annotations, sources, layers and
  images registered with `addImage()` are gone. `onStyleLoadedCallback` fires
  again after the new style is ready: re-add everything there.
- **Every call is asynchronous** and crosses the platform channel. Await them,
  and prefer the batch variants (`addSymbols()`, `setGeoJsonSource()`) over
  loops of single calls.

### Annotations

- **The type must be enabled.** `MapLibreMap.annotationOrder` decides which
  annotation managers are created. The default enables all four types; an
  **empty list disables annotations completely** and any `addSymbol()` /
  `addCircle()` / `addLine()` / `addFill()` call throws. The value is read once
  when the map is created, so changing it later has no effect.
- **`annotationOrder` is also the z-order**, from bottom to top. Each type may
  appear at most once, so 0 to 4 entries.
- **Taps and drags need `annotationConsumeTapEvents`.** Only the layers of the
  types listed there are hit-tested, so a type left out of it never reports
  `onSymbolTapped` and friends, and cannot be dragged even with
  `draggable: true`. It defaults to all four types.
- **No data-driven styling.** Every option (`iconColor`, `circleRadius`, …) is a
  literal value applied to that one annotation. Expressions, filters, clustering
  and heatmaps are style-layer features only.
- **Adding or removing rewrites the whole source** for that annotation type.
  Adding 200 symbols one by one means 200 full rewrites; use `addSymbols()`.
  Updating an existing annotation is cheap by comparison, it patches a single
  feature.
- **`iconImage` must resolve to an image the map has**, either from the style's
  sprite or registered at runtime with `addImage()`. An unknown name renders
  nothing and only logs a warning. See
  [Markers](../annotations/markers.md#where-icons-come-from).

### Style layers

- **Ids must be unique** across the whole style, and the source must exist
  before the layer that renders it.
- **Annotation managers own hidden layers too.** They add their own sources and
  layers with generated ids, so do not assume your layer sits on top when you
  mix both APIs. Use `belowLayerId` to place your layer explicitly.
- **No built-in tap callbacks.** Add the layer with `enableInteraction: true`
  and listen to `onFeatureTapped`, or query the map yourself with
  `queryRenderedFeatures()`.
- **Expressions fail quietly.** A malformed expression usually renders nothing
  rather than throwing. Check the native logs when a layer stays invisible.
- **You own the data.** There are no per-feature handles: to change one feature
  you update the source, either with `setGeoJsonFeature()` for a single feature
  or `setGeoJsonSource()` for the whole collection.

## Decision guide

<div class="decision-grid" markdown>
<div class="decision-card" markdown>

#### Start with Annotations when

- You have fewer than ~50 features
- Each feature needs a tap callback
- Features need to be individually draggable
- You need quick prototyping

</div>
<div class="decision-card" markdown>

#### Switch to Style Layers when

- You have more than ~50 features
- You need clustering
- You need data-driven styling (color or size by property)
- You need heatmaps
- Performance matters (large datasets)
- You want to load GeoJSON from a URL

</div>
</div>

!!! tip "You can mix both"
    It's valid to use annotations for a few interactive pins *and* a style layer for a large GeoJSON dataset on the same map. They coexist independently.
