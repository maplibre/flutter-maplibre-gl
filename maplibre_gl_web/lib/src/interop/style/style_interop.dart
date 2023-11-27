@JS('maplibregl')
library maplibre.interop.style.style;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/style/evaluation_parameters_interop.dart';
import 'package:maplibre_gl_web/src/interop/style/style_image_interop.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/interop/util/evented_interop.dart';

@JS()
@anonymous
abstract class StyleSetterOptionsJsImpl {
  external bool get validate;
}

@JS('Style')
abstract class StyleJsImpl extends EventedJsImpl {
  loadURL(String url, dynamic options);

  loadJSON(dynamic json, StyleSetterOptionsJsImpl option);

  loaded();

  hasTransitions();

  ///  Apply queued style updates in a batch and recalculate zoom-dependent paint properties.
  update(EvaluationParametersJsImpl parameters);

  ///  Update this style's state to match the given style JSON, performing only
  ///  the necessary mutations.
  ///
  ///  May throw an Error ('Unimplemented: METHOD') if the maplibre-gl-style-spec
  ///  diff algorithm produces an operation that is not supported.
  ///
  ///  @returns {boolean} true if any changes were made; false otherwise
  ///  @private
  setState(dynamic nextState);

  addImage(String id, StyleImageJsImpl image);

  updateImage(String id, StyleImageJsImpl image);

  StyleImageJsImpl getImage(String id);

  removeImage(String id);

  listImages();

  addSource(String id, dynamic source, StyleSetterOptionsJsImpl options);

  ///  Remove a source from this stylesheet, given its id.
  ///  @param {string} id id of the source to remove
  ///  @throws {Error} if no source is found with the given ID
  removeSource(String id);

  ///  Set the data of a GeoJSON source, given its id.
  ///  @param {string} id id of the source
  ///  @param {GeoJSON|string} data GeoJSON source
  setGeoJSONSourceData(String id, dynamic data);

  ///  Get a source by id.
  ///  @param {string} id id of the desired source
  ///  @returns {Object} source
  dynamic getSource(String id);

  ///  Add a layer to the map style. The layer will be inserted before the layer with
  ///  ID `before`, or appended if `before` is omitted.
  ///  @param {string} [before] ID of an existing layer to insert before
  addLayer(dynamic layerObject,
      [String? before, StyleSetterOptionsJsImpl? options]);

  ///  Moves a layer to a different z-position. The layer will be inserted before the layer with
  ///  ID `before`, or appended if `before` is omitted.
  ///  @param {string} id  ID of the layer to move
  ///  @param {string} [before] ID of an existing layer to insert before
  moveLayer(String id, [String? before]);

  ///  Remove the layer with the given id from the style.
  ///
  ///  If no such layer exists, an `error` event is fired.
  ///
  ///  @param {string} id id of the layer to remove
  ///  @fires error
  removeLayer(String id);

  ///  Return the style layer object with the given `id`.
  ///
  ///  @param {string} id - id of the desired layer
  ///  @returns {?Object} a layer, if one with the given `id` exists
  dynamic getLayer(String id);

  setLayerZoomRange(String layerId, [num? minzoom, num? maxzoom]);

  setFilter(String layerId, dynamic filter, StyleSetterOptionsJsImpl options);

  ///  Get a layer's filter object
  ///  @param {string} layer the layer to inspect
  ///  @returns {*} the layer's filter, if any
  getFilter(String layer);

  setLayoutProperty(String layerId, String name, dynamic value,
      StyleSetterOptionsJsImpl options);

  ///  Get a layout property's value from a given layer
  ///  @param {string} layerId the layer to inspect
  ///  @param {string} name the name of the layout property
  ///  @returns {*} the property value
  getLayoutProperty(String layerId, String name);

  setPaintProperty(String layerId, String name, dynamic value,
      StyleSetterOptionsJsImpl options);

  getPaintProperty(String layer, String name);

  setFeatureState(dynamic target, dynamic state);

  removeFeatureState(dynamic target, [String? key]);

  getFeatureState(dynamic target);

  getTransition();

  serialize();

  querySourceFeatures(String sourceID, dynamic params);

  addSourceType(String name, dynamic sourceType, Function callback);

  getLight();

  setLight(dynamic lightOptions, StyleSetterOptionsJsImpl options);

  // Callbacks from web workers

  getImages(String mapId, dynamic params, Function callback);

  getGlyphs(String mapId, dynamic params, Function callback);

  getResource(String mapId, RequestParametersJsImpl params, Function callback);

  external List<dynamic> layers;
}

@JS()
@anonymous
class StyleFunctionJsImpl {
  external factory StyleFunctionJsImpl({
    dynamic base,
    dynamic stops,
  });
}
