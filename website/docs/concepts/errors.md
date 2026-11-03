# Errors

The plugin reports errors the same way on Android, iOS and web, so one `catch` works on every platform.

## How errors arrive

* `PlatformException`: the map could not carry out the call. Its `code` is the same on every platform, and its `message` says why.
* `UnsupportedError`: the platform cannot do this at all, such as `setOffline` on iOS and web.
* `ArgumentError`: the plugin rejected a Dart argument before reaching the map, such as a negative camera duration.

```dart
try {
  await controller.removeLayer('route');
} on PlatformException catch (e) {
  // Removed already, for example by a style change.
  if (e.code != 'LAYER_NOT_FOUND_ERROR') rethrow;
}
```

## Avoiding the common ones

* `STYLE_NOT_READY`: add sources, layers and images in `onStyleLoadedCallback`, which runs again after every style change.
* `MAP_DISPOSED`: after an `await`, check `mounted` or `controller.isDisposed` before using the controller again.
* `UnsupportedError`: guard the calls a platform does not have, such as the offline calls on web, with `kIsWeb`.

## Codes

| Code | When |
|---|---|
| `STYLE_NOT_READY` | A source, layer, image or snapshot call ran before the style loaded. |
| `LAYER_NOT_FOUND_ERROR` | No layer has that id. |
| `SOURCE_NOT_FOUND` | No source has that id. |
| `LAYER_ALREADY_EXISTS`, `SOURCE_ALREADY_EXISTS` | The id is already in use. |
| `INVALID_GEOJSON` | The data is not a valid GeoJSON FeatureCollection, Feature or geometry. |
| `INVALID_EXPRESSION` | MapLibre rejected a filter or an expression. |
| `INVALID_ARGUMENT` | Any other value the call cannot use, such as a property value, source properties or a NaN coordinate. |
| `INVALID_LAYER_TYPE` | The call does not apply to this layer type, such as a filter on a raster layer. |
| `UNSUPPORTED_SOURCE_TYPE` | The call does not work on this source type, such as `setGeoJsonSource` on a vector source. |
| `SOURCE_LAYER_REQUIRED` | A call on a vector source got no `sourceLayer`. |
| `INVALID_IMAGE` | The bytes are not an image. |
| `CLUSTER_NOT_FOUND` | No cluster has that id. |
| `SNAPSHOT_ERROR` | The snapshot failed, or a newer `takeSnapshot` cancelled it. |
| `MAP_DISPOSED` | The map was disposed before or during the call. |
| `MANUAL_LOCATION_SOURCE_DISABLED` | `updateManualLocation` on a map created without `ManualLocationSource()`. |

Some codes come only from some platforms:

| Code | Platform | When |
|---|---|---|
| `LOCATION_COMPONENT_NOT_READY` | Android, iOS | A location call on a map created with `myLocationEnabled: false`. |
| `LOCATION_UNAVAILABLE` | Android, iOS | `requestMyLocationLatLng` has no location yet. |
| `TRACKING_NOT_ACTIVE` | Android, iOS | `setTrackingCameraOptions` while `myLocationTrackingMode` is `none`. |
| `FEATURE_STATE_NOT_APPLIED` | Android, iOS | MapLibre rejected the feature state. |
| `UNSUPPORTED_LAYER_TYPE` | Android, iOS | `setLayerProperties` on a layer type the plugin cannot change. |
| `MAP_NOT_READY` | Android | The map view is being rebuilt after the activity was recreated. The call changed nothing. |
| `LOCATION_DISABLED`, `LOCATION_ENGINE_FAILURE` | Android | The device location is off, or failed to answer. |
| `LOCALIZATION_ERROR` | Android | `setMapLanguage` or `matchMapLanguageWithDeviceDefault` failed. |
| `HTTP_CLIENT_ERROR` | Android | Changing the HTTP headers or the request limit failed. |
| `FEATURE_ENCODING_FAILED` | iOS | A query found a feature it could not encode as GeoJSON. |
| `INVALID_LAYER` | Web | MapLibre GL JS did not add the layer. |

The offline calls have their own codes, listed in [Offline Regions](../advanced/offline-regions.md#errors).
