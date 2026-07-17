# GeoJSON Source

A GeoJSON source is the data container that style layers read from. It holds a FeatureCollection of points, lines, or polygons, either inline in your Dart code or fetched from a URL.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/demo/?example=doc-geojson-source"
  title="GeoJSON source"
  loading="lazy"
></iframe>

South American capitals rendered from an inline FeatureCollection. Circle radius scales with population.

## The source + layer pattern

GeoJSON sources don't render anything by themselves. You always need at least one layer referencing the source:

```dart
// 1. Source: holds the data
await controller.addGeoJsonSource('capitals', featureCollection);

// 2. Layer: defines how to render the data
await controller.addCircleLayer(
  'capitals',         // source id
  'capitals-dots',   // layer id (must be unique)
  CircleLayerProperties(...),
);

// Multiple layers can reference the same source
await controller.addSymbolLayer(
  'capitals',
  'capitals-labels',
  SymbolLayerProperties(...),
);
```

## Adding the source

### Inline FeatureCollection

```dart
await controller.addGeoJsonSource('my-source', {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'id': 'f1',  // optional, needed for setGeoJsonFeature()
      'properties': {
        'name': 'Paris',
        'population': 2161000,
        'country': 'France',
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [2.3522, 48.8566],  // [lng, lat]
      },
    },
  ],
});
```

### Remote URL

```dart
await controller.addGeoJsonSource('rivers', {
  'type': 'geojson',
  'data': 'https://example.com/data/rivers.geojson',
});
```

MapLibre fetches and caches the URL. CORS headers must be present when running on web.

### With clustering enabled

```dart
await controller.addSource(
  'events',
  const GeojsonSourceProperties(
    cluster: true,
    clusterMaxZoom: 14,   // stop clustering above zoom 14
    clusterRadius: 50,    // pixel radius for clustering
  ),
);
await controller.setGeoJsonSource('events', featureCollection);
```

See [Cluster](cluster.md) for the full clustering setup.

## Updating data

### Replace all features

```dart
await controller.setGeoJsonSource('my-source', newFeatureCollection);
```

Use this for bulk updates: filtering, time-series playback, real-time data refresh.

### Update a single feature

```dart
await controller.setGeoJsonFeature('my-source', {
  'type': 'Feature',
  'id': 'f1',  // must match an existing feature id
  'properties': {'status': 'active', 'name': 'Paris'},
  'geometry': {
    'type': 'Point',
    'coordinates': [2.3522, 48.8566],
  },
});
```

Updating a single feature is more efficient than replacing the whole FeatureCollection when only one feature changes (e.g. tracking a moving vehicle).

## Filtering layers

Add a filter to a layer to show only features matching a condition:

```dart
await controller.addCircleLayer(
  'events',
  'events-active',
  const CircleLayerProperties(circleColor: '#2ecc71'),
  filter: ['==', ['get', 'status'], 'active'],
);

await controller.addCircleLayer(
  'events',
  'events-inactive',
  const CircleLayerProperties(circleColor: '#95a5a6'),
  filter: ['==', ['get', 'status'], 'inactive'],
);
```

Both layers use the same source but each shows a subset of features.

## Removing a source

```dart
// Remove all layers referencing the source first
await controller.removeLayer('my-layer');

// Then remove the source
await controller.removeSource('my-source');
```

## Key APIs

| Method | Description |
|---|---|
| `addGeoJsonSource(id, data)` | Add a source with inline or URL data |
| `addSource(id, GeojsonSourceProperties(...))` | Add a source with clustering options |
| `setGeoJsonSource(id, data)` | Replace all features |
| `setGeoJsonFeature(id, feature)` | Update one feature by id |
| `removeSource(id)` | Remove source (remove layers first) |
| `getSourceIds()` | List all source ids in the current style |

## Related

- [Working with GeoJSON](../concepts/geojson.md): the data format explained
- [Data-Driven Expressions](../advanced/expressions.md): style by feature properties
- [Cluster](cluster.md): group nearby points automatically
