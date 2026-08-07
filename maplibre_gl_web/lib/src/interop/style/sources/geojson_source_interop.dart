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

  /// The three cluster-inspection methods return promises as of maplibre-gl-js
  /// 6, where version 5 took a trailing callback and returned the source. They
  /// are typed as promises here, since a version 5 library on the page would
  /// need a different call shape and not just a different return value.
  ///
  /// The cluster is addressed by its `cluster_id` property, and the promise
  /// rejects if the source is not clustered or the id is unknown.
  external JSPromise<JSNumber> getClusterExpansionZoom(int clusterId);

  external JSPromise<JSArray<JSObject>> getClusterChildren(int clusterId);

  external JSPromise<JSArray<JSObject>> getClusterLeaves(
    int clusterId,
    int limit,
    int offset,
  );
}
