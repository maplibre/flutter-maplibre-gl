import 'package:js/js_util.dart';
import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/utils.dart';

class FeatureCollection extends JsObjectWrapper<FeatureCollectionJsImpl> {
  factory FeatureCollection({
    required List<Feature> features,
  }) {
    return FeatureCollection.fromJsObject(
      FeatureCollectionJsImpl(
        type: 'FeatureCollection',
        features: features.map((f) => f.jsObject).toList(),
      ),
    );
  }

  /// Creates a new FeatureCollection from a [jsObject].
  FeatureCollection.fromJsObject(super.jsObject) : super.fromJsObject();
  String get type => jsObject.type;

  List<Feature> get features =>
      jsObject.features.map(Feature.fromJsObject).toList();
}

class Feature extends JsObjectWrapper<FeatureJsImpl> {
  factory Feature({
    required Geometry geometry,
    dynamic id,
    Map<String, dynamic>? properties,
    String? source,
  }) =>
      Feature.fromJsObject(
        FeatureJsImpl(
          type: 'Feature',
          id: id,
          geometry: geometry.jsObject,
          properties: properties == null ? jsify({}) : jsify(properties),
          source: source,
        ),
      );

  /// Creates a new Feature from a [jsObject].
  Feature.fromJsObject(super.jsObject) : super.fromJsObject();
  dynamic get id => jsObject.id;

  set id(dynamic id) {
    jsObject.id = id;
  }

  String get type => jsObject.type;

  Geometry get geometry => Geometry.fromJsObject(jsObject.geometry);

  Map<String, dynamic> get properties => dartifyMap(jsObject.properties);

  String get source => jsObject.source;

  Feature copyWith({
    dynamic id,
    Geometry? geometry,
    Map<String, dynamic>? properties,
    String? source,
  }) =>
      Feature.fromJsObject(
        FeatureJsImpl(
          type: 'Feature',
          id: id ?? this.id,
          geometry:
              geometry != null ? geometry.jsObject : this.geometry.jsObject,
          properties:
              properties != null ? jsify(properties) : jsify(this.properties),
          source: source ?? this.source,
        ),
      );
}

class Geometry extends JsObjectWrapper<GeometryJsImpl> {
  factory Geometry({
    String? type,
    dynamic coordinates,
  }) =>
      Geometry.fromJsObject(
        GeometryJsImpl(
          type: type,
          coordinates: coordinates,
        ),
      );

  /// Creates a new Geometry from a [jsObject].
  Geometry.fromJsObject(super.jsObject) : super.fromJsObject();
  String get type => jsObject.type;

  dynamic get coordinates => jsObject.coordinates;
}
