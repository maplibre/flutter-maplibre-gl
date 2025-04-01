@JS('maplibregl')
library maplibre.style.interop.sources.geojson_source;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/geo/geojson_interop.dart';

@JS()
@anonymous
class GeoJsonSourceJsImpl {
  external factory GeoJsonSourceJsImpl({
    String? type,
    String? promoteId,
    FeatureCollectionJsImpl data,
  });
  external FeatureCollectionJsImpl get data;

  external String get promoteId;

  external GeoJsonSourceJsImpl setData(
    FeatureCollectionJsImpl featureCollection,
  );
}
