import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:maplibre_gl_web/src/geo/geojson.dart';
import 'package:maplibre_gl_web/src/interop/style/sources/geojson_source_interop.dart';
import 'package:maplibre_gl_web/src/style/sources/source.dart';

class GeoJsonSource extends Source<GeoJsonSourceJsImpl> {
  FeatureCollection get data => FeatureCollection.fromJsObject(jsObject.data);
  String? get promoteId => jsObject.promoteId;

  factory GeoJsonSource({required FeatureCollection data, String? promoteId}) =>
      GeoJsonSource.fromJsObject(
        GeoJsonSourceJsImpl(
          type: 'geojson',
          promoteId: promoteId,
          data: data.jsObject,
        ),
      );

  /// Replaces the source's data, completing once the worker has it.
  ///
  /// maplibre-gl-js 6 returns a promise here, where version 5 returned the
  /// source itself, so only a promise is awaited and a version 5 library on the
  /// page keeps working. Dropping it would report the data as applied before it
  /// is, and would turn a rejection, on invalid GeoJSON for example, into an
  /// unhandled one.
  Future<void> setData(FeatureCollection featureCollection) async {
    final result = jsObject.setData(featureCollection.jsObject);
    if (result.isA<JSPromise>()) await (result! as JSPromise).toDart;
  }

  /// Whether the underlying source carries the cluster-inspection methods.
  ///
  /// `MapLibreMap.getSource` wraps whatever it finds in a [GeoJsonSource],
  /// because casting to an extension type cannot fail, so this is what tells a
  /// GeoJSON source apart from a vector or raster one.
  bool get hasClusterInspection => jsObject.has('getClusterExpansionZoom');

  /// The three cluster-inspection calls, stopping at the JS boundary.
  ///
  /// They hand back the raw promise result rather than Dart values on purpose.
  /// Converting here would put the conversion inside the same future as the
  /// call, so a decoding bug would be indistinguishable from a rejected query
  /// and would be reported as one. The caller converts after the promise has
  /// settled.

  /// The zoom at which the cluster [clusterId] splits into its children.
  Future<JSNumber> getClusterExpansionZoom(int clusterId) =>
      jsObject.getClusterExpansionZoom(clusterId).toDart;

  /// The immediate children of the cluster [clusterId], on the next zoom level.
  Future<JSArray<JSObject>> getClusterChildren(int clusterId) =>
      jsObject.getClusterChildren(clusterId).toDart;

  /// The original points belonging to the cluster [clusterId], [limit] at a
  /// time from [offset].
  Future<JSArray<JSObject>> getClusterLeaves(
    int clusterId,
    int limit,
    int offset,
  ) => jsObject.getClusterLeaves(clusterId, limit, offset).toDart;

  /// Creates a new GeoJsonSource from a [jsObject].
  GeoJsonSource.fromJsObject(super.jsObject) : super.fromJsObject();

  @override
  get dict => {
    'type': 'geojson',
    'promoteId': promoteId,
    'data': data.jsObject,
  };
}
