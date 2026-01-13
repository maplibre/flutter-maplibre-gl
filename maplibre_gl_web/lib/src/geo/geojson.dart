import 'dart:js_interop';
import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/utils.dart' as utils;

class FeatureCollection extends JsObjectWrapper<FeatureCollectionJsImpl> {
  String get type => utils.dartify(jsObject.type) as String;

  List<Feature> get features =>
      jsObject.features.toDart.map((f) => Feature.fromJsObject(f)).toList();

  factory FeatureCollection({
    required List<Feature> features,
  }) {
    return FeatureCollection.fromJsObject(FeatureCollectionJsImpl(
      type: 'FeatureCollection',
      features: features.map((f) => f.jsObject).toList().toJS,
    ));
  }

  /// Creates a new FeatureCollection from a [jsObject].
  FeatureCollection.fromJsObject(super.jsObject) : super.fromJsObject();
}

class Feature extends JsObjectWrapper<FeatureJsImpl> {
  dynamic get id => utils.dartify(jsObject.id);

  set id(dynamic id) {
    jsObject.id = utils.jsify(id);
  }

  String get type => utils.dartify(jsObject.type) as String;

  Geometry get geometry => Geometry.fromJsObject(jsObject.geometry);

  Map<String, dynamic> get properties => utils.dartifyMap(jsObject.properties);

  dynamic getProperty(String key) {
    final props = jsObject.properties;
    if (props == null) return null;
    final value = getJsProperty(props as JSObject, key);
    return utils.dartify(value);
  }

  String get source => utils.dartify(jsObject.source) as String;

  String get layerId => utils.dartify(jsObject.layer.id) as String;

  factory Feature({
    dynamic id,
    required Geometry geometry,
    Map<String, dynamic>? properties,
    String? source,
    String? layerId,
  }) =>
      Feature.fromJsObject(FeatureJsImpl(
        type: 'Feature',
        id: utils.jsify(id),
        geometry: geometry.jsObject,
        properties: utils.jsify(properties ?? {}),
        source: source,
        layer: layerId != null ? FeatureLayerJsImpl(id: layerId) : null,
      ));

  Feature copyWith({
    dynamic id,
    Geometry? geometry,
    Map<String, dynamic>? properties,
    String? source,
  }) =>
      Feature.fromJsObject(FeatureJsImpl(
        type: 'Feature',
        id: utils.jsify(id ?? this.id),
        geometry: geometry != null ? geometry.jsObject : this.geometry.jsObject,
        properties: utils.jsify(properties ?? this.properties),
        source: source ?? this.source,
      ));

  /// Creates a new Feature from a [jsObject].
  Feature.fromJsObject(super.jsObject) : super.fromJsObject();
}

class Geometry extends JsObjectWrapper<GeometryJsImpl> {
  String get type => utils.dartify(jsObject.type) as String;

  dynamic get coordinates => jsObject.coordinates;

  factory Geometry({
    String? type,
    dynamic coordinates,
  }) =>
      Geometry.fromJsObject(GeometryJsImpl(
        type: type,
        coordinates: utils.jsify(coordinates),
      ));

  /// Creates a new Geometry from a [jsObject].
  Geometry.fromJsObject(super.jsObject) : super.fromJsObject();
}
