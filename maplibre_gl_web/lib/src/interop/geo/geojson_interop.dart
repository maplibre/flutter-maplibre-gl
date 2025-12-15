@JS('maplibregl')
library;

import 'dart:js_interop';

extension type FeatureCollectionJsImpl._(JSObject _) implements JSObject {
  external String get type;
  external JSArray<FeatureJsImpl> get features;
  external factory FeatureCollectionJsImpl({
    String type,
    JSArray<FeatureJsImpl> features,
  });
}

extension type FeatureJsImpl._(JSObject _) implements JSObject {
  external JSAny? get id;
  external set id(JSAny? id);
  external String get type;
  external GeometryJsImpl get geometry;
  external JSAny? get properties;
  external String get source;
  external FeatureLayerJsImpl get layer;
  external factory FeatureJsImpl({
    JSAny? id,
    String? type,
    GeometryJsImpl geometry,
    JSAny? properties,
    String? source,
    FeatureLayerJsImpl? layer,
  });
}

extension type GeometryJsImpl._(JSObject _) implements JSObject {
  external String get type;
  external JSAny? get coordinates;
  external factory GeometryJsImpl({
    String? type,
    JSAny? coordinates,
  });
}

extension type FeatureLayerJsImpl._(JSObject _) implements JSObject {
  external String get id;
  external factory FeatureLayerJsImpl({
    String id,
  });
}
