# Feature State

Feature state attaches key-value pairs to individual features at runtime, and paint properties read them back through the `["feature-state", ...]` expression. Selecting, highlighting or recoloring one feature becomes a single cheap call, and the source data stays untouched. The alternative, re-feeding the source with `setGeoJsonSource`, is expensive: the whole collection is re-encoded and re-built for the GPU even if only one color changed.

!!! note "Platform support"
    Feature state works on **web and Android**. On iOS the three methods throw an `UnsupportedError`, because the MapLibre iOS SDK does not expose the API yet.

## The three calls

```dart
// Attach state to one feature
await controller.setFeatureState('parcels', '42', {'selected': true});

// Read it back
final state = await controller.getFeatureState('parcels', '42');

// Remove it (three shapes, see below)
await controller.removeFeatureState('parcels', featureId: '42');
```

## A working example

### 1. A source whose features have an ID

Feature state is keyed by feature ID, which must be an integer or a string castable to an integer.

```dart
await controller.addGeoJsonSource('parcels', {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'id': 42, // required for feature state
      'properties': {'name': 'Parcel A'},
      'geometry': {
        'type': 'Point',
        'coordinates': [2.3522, 48.8566],
      },
    },
  ],
});
```

!!! warning "`promoteId` is web only"
    On web, [`promoteId`](../concepts/geojson.md#promoteid-web-only-caveat) can promote a property to be the feature ID. The Android SDK does not expose it, so on Android every feature must carry a top-level `id` member itself.

### 2. A layer whose paint reads the state

```dart
await controller.addFillLayer(
  'parcels',
  'parcel-fills',
  const FillLayerProperties(
    fillColor: [
      'case',
      // A feature with no state yet makes ["feature-state", "selected"]
      // return null, so the false fallback is required.
      ['boolean', ['feature-state', 'selected'], false],
      '#F39C12', // selected
      '#627BC1', // default
    ],
  ),
);
```

### 3. Set state on tap

```dart
MapLibreMap(
  // ...
  featureTapsTriggersMapClick: true, // otherwise fill taps never reach onMapClick
  onMapClick: (point, latLng) async {
    final features =
        await controller.queryRenderedFeatures(point, ['parcel-fills'], null);
    if (features.isEmpty) return;

    // Always use the ID the platform reports, never a hardcoded one:
    // with promoteId the web ID can differ from the Android one.
    final id = features.first['id'].toString();
    await controller.setFeatureState('parcels', id, {'selected': true});
  },
)
```

## Removing state

`removeFeatureState` has three shapes, picked by which arguments you pass:

```dart
// One key from one feature
await controller.removeFeatureState('parcels',
    featureId: '42', stateKey: 'selected');

// All keys from one feature
await controller.removeFeatureState('parcels', featureId: '42');

// All state in the whole source
await controller.removeFeatureState('parcels');
```

A `stateKey` needs the `featureId` that owns it: on Android, `stateKey` without `featureId` is rejected instead of silently resetting the whole source.

## Gotchas

- **No state is `null`**: a feature nobody touched yet has no state, so the expression returns `null`. Always give the paint a fallback, like the `false` in `["boolean", ["feature-state", "selected"], false]`.
- **IDs are integers**: feature IDs must be integers or strings castable to integers.
- **Vector sources need `sourceLayer`**: pass it to all three calls when the source is a vector tile source. GeoJSON sources ignore it.
- **Android needs a top-level `id`**: `promoteId` is web only, so on Android the ID must be in the GeoJSON itself.

See [Data-Driven Expressions](expressions.md) for the expression side of the picture, and the Feature State page in the example app for a full multi-selection demo.
