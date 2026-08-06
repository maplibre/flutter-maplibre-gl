@JS('maplibregl')
library;

import 'dart:js_interop';
import 'package:maplibre_gl_web/src/interop/geo/geojson_interop.dart';

extension type GeoJsonSourceJsImpl._(JSObject _) implements JSObject {
  external FeatureCollectionJsImpl get data;

  external String get promoteId;

  external factory GeoJsonSourceJsImpl({
    String? type,
    String? promoteId,
    FeatureCollectionJsImpl data,
  });

  /// Returns a promise since maplibre-gl-js 6, which settles once the worker
  /// has the data; version 5 returned the source itself and took a second
  /// `waitForCompletion` argument. Typed loosely so both builds work, and
  /// unwrapped in `GeoJsonSource.setData`.
  external JSAny? setData(FeatureCollectionJsImpl featureCollection);
}
