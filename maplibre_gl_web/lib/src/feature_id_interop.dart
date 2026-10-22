/// The maplibre-gl-js side of [featureIdProperty]: see feature_ids.dart.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:maplibre_gl_web/src/feature_ids.dart';

/// Copies the id of [feature], a GeoJSON Feature as maplibre-gl-js takes it,
/// into its [featureIdProperty]. A feature without an id is left as it is.
void copyFeatureId(JSObject feature) {
  final id = feature.getProperty<JSAny?>('id'.toJS);
  if (id == null) return;
  var properties = feature.getProperty<JSAny?>('properties'.toJS);
  if (properties == null || !properties.isA<JSObject>()) {
    properties = JSObject();
    feature.setProperty('properties'.toJS, properties);
  }
  (properties as JSObject).setProperty(featureIdProperty.toJS, id);
}

/// Makes [source], a GeoJSON source of maplibre-gl-js, take its feature ids
/// from [featureIdProperty] when [promote] is true, for data the plugin sets,
/// and from the data itself otherwise, for data loaded from a URL.
///
/// Answers whether the source now takes them from [featureIdProperty]. A
/// source that the app or the style gave a `promoteId` of its own keeps it.
bool promoteFeatureIds(JSObject source, {required bool promote}) {
  // serialize() answers the options the source was created with.
  final own = source
      .callMethod<JSObject?>('serialize'.toJS)
      ?.getProperty<JSAny?>('promoteId'.toJS);
  if (own != null &&
      !(own.isA<JSString>() && (own as JSString).toDart == featureIdProperty)) {
    return false;
  }
  // maplibre-gl-js has no setter: it reads promoteId when it loads a tile,
  // and hands the worker its geojsonVtOptions with the next setData.
  final value = promote ? featureIdProperty.toJS : null;
  source.setProperty('promoteId'.toJS, value);
  source
      .getProperty<JSObject?>('workerOptions'.toJS)
      ?.getProperty<JSObject?>('geojsonVtOptions'.toJS)
      ?.setProperty('promoteId'.toJS, value);
  return promote;
}
