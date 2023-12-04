library maplibre.style.sources.geojson_source;

import 'package:maplibre_gl_web/src/geo/geojson.dart';
import 'package:maplibre_gl_web/src/interop/style/sources/geojson_source_interop.dart';
import 'package:maplibre_gl_web/src/style/sources/source.dart';

class GeoJsonSource extends Source<GeoJsonSourceJsImpl> {
  FeatureCollection get data => FeatureCollection.fromJsObject(jsObject.data);
  String? get promoteId => jsObject.promoteId;

  factory GeoJsonSource({
    required FeatureCollection data,
    String? promoteId,
  }) =>
      GeoJsonSource.fromJsObject(GeoJsonSourceJsImpl(
        type: 'geojson',
        promoteId: promoteId,
        data: data.jsObject,
      ));

  GeoJsonSource setData(FeatureCollection featureCollection) =>
      GeoJsonSource.fromJsObject(jsObject.setData(featureCollection.jsObject));

  /// Creates a new GeoJsonSource from a [jsObject].
  GeoJsonSource.fromJsObject(GeoJsonSourceJsImpl jsObject)
      : super.fromJsObject(jsObject);

  @override
  get dict => {
        'type': 'geojson',
        'promoteId': promoteId,
        'data': data.jsObject,
      };
}
