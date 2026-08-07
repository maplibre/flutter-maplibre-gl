import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:maplibre_gl_web/src/geo/geojson.dart';
import 'package:maplibre_gl_web/src/interop/style/sources/geojson_source_interop.dart';
import 'package:maplibre_gl_web/src/style/sources/source.dart';
import 'package:maplibre_gl_web/src/utils.dart';

class GeoJsonSource extends Source<GeoJsonSourceJsImpl> {
  FeatureCollection get data => FeatureCollection.fromJsObject(jsObject.data);
  String? get promoteId => jsObject.promoteId;

  factory GeoJsonSource({
    required FeatureCollection data,
    String? promoteId,
  }) => GeoJsonSource.fromJsObject(
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

  /// The zoom at which the cluster [clusterId] splits into its children.
  Future<int> getClusterExpansionZoom(int clusterId) async {
    final zoom = await jsObject.getClusterExpansionZoom(clusterId).toDart;
    return zoom.toDartDouble.round();
  }

  /// The immediate children of the cluster [clusterId], on the next zoom level.
  Future<List<Map<String, dynamic>>> getClusterChildren(int clusterId) async {
    final features = await jsObject.getClusterChildren(clusterId).toDart;
    return features.toDart.map(dartifyMap).toList();
  }

  /// The original points belonging to the cluster [clusterId], [limit] at a
  /// time from [offset].
  Future<List<Map<String, dynamic>>> getClusterLeaves(
    int clusterId,
    int limit,
    int offset,
  ) async {
    final features =
        await jsObject.getClusterLeaves(clusterId, limit, offset).toDart;
    return features.toDart.map(dartifyMap).toList();
  }

  /// Creates a new GeoJsonSource from a [jsObject].
  GeoJsonSource.fromJsObject(super.jsObject) : super.fromJsObject();

  @override
  get dict => {
    'type': 'geojson',
    'promoteId': promoteId,
    'data': data.jsObject,
  };
}
