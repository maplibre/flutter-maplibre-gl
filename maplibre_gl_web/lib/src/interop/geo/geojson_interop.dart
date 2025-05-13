@JS('maplibregl')
library maplibre.interop.geo.geojson;

import 'package:js/js.dart';

@JS()
@anonymous
class FeatureCollectionJsImpl {
  external factory FeatureCollectionJsImpl({
    String type,
    List<FeatureJsImpl> features,
  });
  external String get type;
  external List<FeatureJsImpl> get features;
}

@JS()
@anonymous
class FeatureJsImpl {
  external factory FeatureJsImpl({
    dynamic id,
    String? type,
    GeometryJsImpl geometry,
    dynamic properties,
    String? source,
  });
  external dynamic get id;
  external set id(dynamic id);
  external String get type;
  external GeometryJsImpl get geometry;
  external dynamic get properties;
  external String get source;
}

@JS()
@anonymous
class GeometryJsImpl {
  external factory GeometryJsImpl({
    String? type,
    dynamic coordinates,
  });
  external String get type;
  external dynamic get coordinates;
}
