import 'dart:js_interop';

import 'package:maplibre_gl_web/src/geo/geojson.dart';
import 'package:maplibre_gl_web/src/interop/style/sources/geojson_source_interop.dart';
import 'package:maplibre_gl_web/src/style/sources/source.dart';

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

  /// Creates a new GeoJsonSource from a [jsObject].
  GeoJsonSource.fromJsObject(super.jsObject) : super.fromJsObject();

  @override
  get dict => {
    'type': 'geojson',
    'promoteId': promoteId,
    'data': data.jsObject,
  };
}
