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
    iconImage: 'marker-15',
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
    iconImage: 'marker-15',
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
    iconImage: 'marker-15',
    iconColor: '#E74C3C',
    textField: [Expressions.get, 'name'],
  ),
);
```

</div>
</div>

## Live demo

**Annotations** (5 tappable landmarks via `addSymbol()`):

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/?example=doc-annotation-markers"
  title="Annotation markers"
  loading="lazy"
></iframe>

**Style Layers** (10 cities via `addGeoJsonSource` + `addSymbolLayer`):

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/?example=doc-symbol-layer"
  title="Symbol layer"
  loading="lazy"
></iframe>

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
